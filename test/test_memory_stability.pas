// ═══════════════════════════════════════════════════════════════
//  test_memory_stability.pas — Leak detection via repeated open/close
// ═══════════════════════════════════════════════════════════════
//  1000× buka + tutup koneksi WS. Cek:
//    - count open = count close
//    - event loop tidak leak (active_conns = 0 di akhir)
//    - no crash pada stress berulang
// ═══════════════════════════════════════════════════════════════

var SRV := -1;
var OPENS := 0;
var CLOSES := 0;
var MSGS := 0;

function onOpen(conn) begin
  OPENS := OPENS + 1;
end;

function onMessage(conn, msg) begin
  MSGS := MSGS + 1;
end;

function onClose(conn, code) begin
  CLOSES := CLOSES + 1;
end;

function runClients() begin
  // Python: 1000× connect-disconnect berurutan
  var py := "
import asyncio, websockets, sys

N = 1000
OK = 0
ERR = 0

async def one():
    try:
        async with websockets.connect(
            'ws://localhost:9180',
            ping_interval=None,
            open_timeout=5
        ) as ws:
            await ws.send('x')
            return True
    except Exception as e:
        return False

async def main():
    global OK, ERR
    # Batch 50 concurrent — realistic load
    for batch_start in range(0, N, 50):
        tasks = [asyncio.create_task(one()) for _ in range(50)]
        results = await asyncio.gather(*tasks)
        ok = sum(1 for r in results if r)
        OK = OK + ok
        ERR = ERR + (50 - ok)
    print(f'done: ok={OK} err={ERR}', flush=True)

asyncio.run(main())
";
  var r := sys.exec("python3", ["-c", py], 60000);
  println(r["stdout"]);
end;

begin
  println("=== Memory stability test ===");
  println("target: 1000 connect-disconnect cycles");

  SRV := ws.serve(9180, {
    "onOpen":    onOpen,
    "onMessage": onMessage,
    "onClose":   onClose,
    "pingEnabled": false
  });

  if SRV < 0 then begin
    println("FAIL: serve return -1");
    sys.exit(1);
  end;

  println("server handle: ", SRV);
  ws.listenAsync(SRV);
  sleep(500);

  var t0 := getTick();
  thread(runClients);
  sleep(35000);
  var t1 := getTick();

  var info := ws.clients(SRV);
  var active := len(info);

  println();
  println("=== Results ===");
  println("duration:  ", t1 - t0, " ms");
  println("opens:     ", OPENS);
  println("closes:    ", CLOSES);
  println("messages:  ", MSGS);
  println("still active: ", active);

  ws.stop(SRV);
  sleep(1000);

  // Checks
  var pass := true;

  if OPENS < 900 then begin
    println("FAIL: opens too few (", OPENS, " < 900)");
    pass := false;
  end;

  if CLOSES < OPENS - 10 then begin
    println("FAIL: closes mismatch (", CLOSES, " vs opens ", OPENS, ")");
    pass := false;
  end;

  if active > 5 then begin
    println("FAIL: leak suspected — ", active, " active conns still open");
    pass := false;
  end;

  if pass then begin
    println();
    println("PASS: no obvious leak");
    sys.exit(0);
  end else begin
    println();
    println("FAIL");
    sys.exit(1);
  end;
end.
