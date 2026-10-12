var SRV := -1;
var OPEN_COUNT := 0;
var ECHO_COUNT := 0;

function onOpen(conn) begin
  OPEN_COUNT := OPEN_COUNT + 1;
end;

function onMessage(conn, msg) begin
  ECHO_COUNT := ECHO_COUNT + 1;
  conn.send("nbs:" + msg);
end;

// Client runner — dijalankan di thread terpisah supaya main thread
// bisa tick event loop selama Python connect.
function runClient() begin
  var py := "
import asyncio, websockets
async def main():
    async with websockets.connect('ws://localhost:9150') as ws:
        for i in range(3):
            await ws.send('msg-' + str(i))
            print('recv:', await ws.recv())
asyncio.run(main())
print('done')
";
  var r := sys.exec("python3", ["-c", py], 15000);
  println("--- python stdout ---");
  println(r["stdout"]);
  if len(r["stderr"]) > 0 then
    println("--- python stderr ---");
    println(r["stderr"]);
end;

begin
  println("=== ws event-mode test ===");

  SRV := ws.serve(9150, {
    "onOpen": onOpen,
    "onMessage": onMessage
  });

  if SRV < 0 then begin
    println("FAIL: serve return -1");
    sys.exit(1);
  end;

  var ok := ws.listenAsync(SRV);
  println("listenAsync: ", ok);
  sleep(300);

  // Spawn client di thread terpisah, main thread tick event loop via sleep
  thread(runClient);
  sleep(5000);

  println();
  println("open=", OPEN_COUNT, " echo=", ECHO_COUNT);

  ws.stop(SRV);
  sleep(500);

  if OPEN_COUNT == 1 and ECHO_COUNT == 3 then begin
    println("PASS");
    sys.exit(0);
  end else begin
    println("FAIL");
    sys.exit(1);
  end;
end.