var SRV := -1;
var OPEN_COUNT := 0;
var ECHO_COUNT := 0;
var CLIENT_DONE := 0;
var CLIENT_EXIT := -999;
var CLIENT_STDERR := "";

function onOpen(conn) begin
  OPEN_COUNT := OPEN_COUNT + 1;
end;

function onMessage(conn, msg) begin
  ECHO_COUNT := ECHO_COUNT + 1;
  conn.send("tls-nbs:" + msg);
end;

function runClient() begin
  println("[client] thread start");
  var py := "
import asyncio, websockets, ssl, sys
ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

async def main():
    try:
        async with websockets.connect(
            'wss://localhost:9450',
            ssl=ctx,
            open_timeout=10
        ) as ws:
            print('connected', flush=True)
            for i in range(3):
                await ws.send('tls-msg-' + str(i))
                print('recv:', await ws.recv(), flush=True)
    except Exception as e:
        print('python-error:', type(e).__name__, ':', e, file=sys.stderr, flush=True)
        raise

asyncio.run(main())
print('done', flush=True)
";
  var r := sys.exec("python3", ["-c", py], 25000);
  println("[client] python exit=", r["exitCode"]);
  println("[client] stdout = [", r["stdout"], "]");
  if len(r["stderr"]) > 0 then begin
    println("[client] stderr = [");
    println(r["stderr"]);
    println("]");
  end;
  CLIENT_EXIT := r["exitCode"];
  CLIENT_STDERR := r["stderr"];
  CLIENT_DONE := 1;
end;

begin
  println("=== wss:// event mode test ===");

  var home := sys.env("HOME");
  SRV := ws.serveTLS(9450,
    home + "/server.crt",
    home + "/server.key",
    {
      "onOpen": onOpen,
      "onMessage": onMessage
    });

  if SRV < 0 then begin
    println("FAIL: serveTLS return -1");
    sys.exit(1);
  end;

  var ok := ws.listenAsync(SRV);
  println("listenAsync(TLS) = ", ok);
  sleep(300);

  thread(runClient);

  // Tunggu sampai client selesai (max ~28s)
  var waited := 0;
  while (CLIENT_DONE == 0) and (waited < 28000) do begin
    sleep(100);
    waited := waited + 100;
  end;

  println("waited = ", waited, "ms");
  println("open=", OPEN_COUNT, " echo=", ECHO_COUNT, " client_done=", CLIENT_DONE);

  ws.stop(SRV);
  sleep(500);

  if (OPEN_COUNT == 1) and (ECHO_COUNT == 3) and (CLIENT_EXIT == 0) then begin
    println("PASS");
    sys.exit(0);
  end else begin
    println("FAIL");
    sys.exit(1);
  end;
end.