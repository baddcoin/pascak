// ═══════════════════════════════════════════════════════════════
//  Fase Regression: WS Fragmentation
// ═══════════════════════════════════════════════════════════════
//  Bug yang diuji: wsContinuation dispatch `Payload` (uninitialized)
//  bukan `Conn.FragBuf` (buffer akumulasi fragmentasi).
//
//  Cara test: kirim payload besar (50000 byte) → Python websockets
//  fragmentasi jadi ~50 frame → server harus akumulasi dan dispatch
//  1 message dengan payload utuh.
//
//  Tanpa fix: dispatch akan berisi data rusak / kosong.
// ═══════════════════════════════════════════════════════════════

var SRV := -1;
var MSG_COUNT := 0;
var LAST_LEN := 0;
var ALL_X := true;

function onMessage(conn, msg) begin
  MSG_COUNT := MSG_COUNT + 1;
  LAST_LEN := len(msg);

  // Verifikasi semua karakter adalah 'X'
  var i := 0;
  while i < len(msg) do begin
    if msg[i] != "X" then begin
      ALL_X := false;
      break;
    end;
    i := i + 1;
  end;
end;

function runClient() begin
  var py := "
import asyncio, websockets
async def main():
    async with websockets.connect(
        'ws://localhost:9157',
        write_limit=1024
    ) as ws:
        payload = 'X' * 50000
        await ws.send(payload)
        r = await ws.recv()
        print('recv len:', len(r))
asyncio.run(main())
print('done')
";
  var r := sys.exec("python3", ["-c", py], 30000);
  println("--- python stdout ---");
  println(r["stdout"]);
  if len(r["stderr"]) > 0 then begin
    println("--- python stderr ---");
    println(r["stderr"]);
  end;
end;

begin
  testBegin("Fase Regression - WS Fragmentation");

  SRV := ws.serve(9157, {
    "onMessage": onMessage
  });

  if SRV < 0 then begin
    assertTrue(false, "serve return -1");
    testEnd();
    sys.exit(1);
  end;

  var ok := ws.listenAsync(SRV);
  assertTrue(ok, "listenAsync");

  sleep(300);

  thread(runClient);
  sleep(10000);

  println("msg_count=", MSG_COUNT, " last_len=", LAST_LEN, " all_x=", ALL_X);

  assertEqual(MSG_COUNT, 1, "1 message dari 1 payload fragmented");
  assertEqual(LAST_LEN, 50000, "payload length intact");
  assertTrue(ALL_X, "payload content intact (semua 'X')");

  ws.stop(SRV);
  sleep(300);
  testEnd();
end.