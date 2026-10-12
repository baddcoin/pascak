
var SRV := -1;
var OPEN_COUNT := 0;
var CLOSE_COUNT := 0;
var MSG_COUNT := 0;
var PEAK_ACTIVE := 0;

function onOpen(conn) begin
  OPEN_COUNT := OPEN_COUNT + 1;
  if OPEN_COUNT > PEAK_ACTIVE then
    PEAK_ACTIVE := OPEN_COUNT;
end;

function onMessage(conn, msg) begin
  MSG_COUNT := MSG_COUNT + 1;
end;

function onClose(conn, code) begin
  CLOSE_COUNT := CLOSE_COUNT + 1;
end;

// Client runner — dijalankan di thread terpisah.
// Buka N koneksi paralel via asyncio, hold 5 detik, close semua.
function runStress() begin
  var py := "
import asyncio, websockets

N = 500
HOLD_SEC = 5

async def one_client(i):
    try:
        async with websockets.connect(
            'ws://localhost:9160',
            ping_interval=None,
            open_timeout=10
        ) as ws:
            await asyncio.sleep(HOLD_SEC)
    except Exception as e:
        print(f'client {i} error: {type(e).__name__}: {e}')

async def main():
    tasks = [asyncio.create_task(one_client(i)) for i in range(N)]
    await asyncio.gather(*tasks, return_exceptions=True)
    print('all clients done')

asyncio.run(main())
";
  var r := sys.exec('python3', ['-c', py], 30000);
  println('--- python stdout ---');
  println(r['stdout']);
  if len(r['stderr']) > 0 then begin
    println('--- python stderr (first 500 chars) ---');
    var err := r['stderr'];
    if len(err) > 500 then err := copy(err, 1, 500);
    println(err);
  end;
end;

begin
  println('=== ws stress test ===');
  println('target: 500 concurrent connections');

  SRV := ws.serve(9160, {
    'onOpen':    onOpen,
    'onMessage': onMessage,
    'onClose':   onClose,
    'pingEnabled': false
  });

  if SRV < 0 then begin
    println('FAIL: serve return -1');
    sys.exit(1);
  end;

  var ok := ws.listenAsync(SRV);
  println('listenAsync: ', ok);

  // Baseline memory
  var mem := sys.memoryUsage();
  println('mem before: ', mem['used_bytes'], ' bytes');

  // Spawn client di thread, main tick event loop
  thread(runStress);
  sleep(12000);

  // Force stop dulu untuk trigger close semua
  ws.stop(SRV);
  sleep(2000);

  var mem2 := sys.memoryUsage();
  println('mem after: ', mem2['used_bytes'], ' bytes');

  println();
  println('=== Results ===');
  println('opened:      ', OPEN_COUNT);
  println('closed:      ', CLOSE_COUNT);
  println('messages:    ', MSG_COUNT);
  println('peak active: ', PEAK_ACTIVE);

  // Assert
  if (OPEN_COUNT >= 450) and (PEAK_ACTIVE >= 450) then begin
    println();
    println('PASS: >= 450 of 500 concurrent');
    sys.exit(0);
  end else begin
    println();
    println('FAIL: expected >= 450, got open=', OPEN_COUNT,
            ' peak=', PEAK_ACTIVE);
    sys.exit(1);
  end;
end.