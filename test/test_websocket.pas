// ═══════════════════════════════════════════════════════════════
//  test_websocket.pas — End-to-end test (fully automated)
// ═══════════════════════════════════════════════════════════════
//  Jalankan:
//    ~/pascak_noASTnet test/test_websocket.pas
//
//  Prasyarat: python3 dengan modul 'websockets'
//    pip install websockets
// ═══════════════════════════════════════════════════════════════

var SRV := -1;
var OPEN_COUNT := 0;
var ECHO_COUNT := 0;
var CLOSE_COUNT := 0;

function onOpen(conn) begin
  OPEN_COUNT := OPEN_COUNT + 1;
end;

function onMessage(conn, msg) begin
  ECHO_COUNT := ECHO_COUNT + 1;
  conn.send("echo:" + msg);
end;

function onClose(conn, code) begin
  CLOSE_COUNT := CLOSE_COUNT + 1;
end;

// Wrapper — thread() hanya menerima script function, bukan native.
function serverThread() begin
  ws.listen(SRV);
end;

function hasWebSocketsLib() begin
  var r := sys.exec("python3", ["-c", "import websockets; print('ok')"], 5000);
  // B.SEC: kalau policy deny, exitCode = -1 → return false (skip)
  if r["exitCode"] <> 0 then return false;
  return pos("ok", r["stdout"]) > 0;
end;

begin
  println("=== WebSocket E2E Test ===");
  println();

  if not hasWebSocketsLib() then begin
    var info := sys.execInfo();
    if info["mode"] == "none" then begin
      println("SKIP: exec policy DENY ALL (mode=none)");
      println("  Set env: PASCAK_EXEC_POLICY=whitelist:python3");
      println("  Atau:    PASCAK_EXEC_POLICY=allow-all");
    end else begin
      println("SKIP: python3 websockets tidak tersedia");
      println("  Install: pip install websockets");
    end;
    sys.exit(0);
  end;

  // ─── Start server ───
  SRV := ws.serve(9100, {
    "onOpen":    onOpen,
    "onMessage": onMessage,
    "onClose":   onClose
  });

  if SRV < 0 then begin
    println("FAIL: ws.serve return -1");
    sys.exit(1);
  end;
  println("server handle = ", SRV, " di port 9100");

  // ─── Spawn listen thread ───
  thread(serverThread);
  sleep(300);

  // ─── Jalankan Python client ───
  var py := "
import asyncio, websockets
async def main():
    async with websockets.connect('ws://localhost:9100') as ws:
        for i in range(5):
            await ws.send('msg-' + str(i))
            r = await ws.recv()
            print('client recv: ' + r)
asyncio.run(main())
print('client done')
";
  println("menjalankan Python client...");
  var r := sys.exec("python3", ["-c", py], 15000);

  println();
  println("--- python stdout ---");
  println(r["stdout"]);
  println("--- python stderr ---");
  println(r["stderr"]);
  println("exit code: ", r["exitCode"]);

  // Beri waktu worker thread selesai cleanup + onClose
  sleep(500);

  // ─── Verifikasi ───
  println();
  println("=== Stats ===");
  println("onOpen:    ", OPEN_COUNT);
  println("onMessage: ", ECHO_COUNT);
  println("onClose:   ", CLOSE_COUNT);

  var pass := true;

  if r["exitCode"] <> 0 then begin
    println("FAIL: python client exit != 0");
    pass := false;
  end;

  if OPEN_COUNT < 1 then begin
    println("FAIL: onOpen tidak dipanggil");
    pass := false;
  end;

  if ECHO_COUNT < 5 then begin
    println("FAIL: expected 5 echo, got ", ECHO_COUNT);
    pass := false;
  end;

  // ─── Graceful stop ───
  ws.stop(SRV);
  sleep(800);   // beri listen thread waktu exit

  println();
  if pass then begin
    println("ALL PASSED");
    sys.exit(0);
  end else begin
    println("SOME FAILED");
    sys.exit(1);
  end;
end.