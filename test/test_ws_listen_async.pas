var SRV := -1;
var OPEN_COUNT := 0;
var ECHO_COUNT := 0;

function onOpen(conn) begin
  OPEN_COUNT := OPEN_COUNT + 1;
end;

function onMessage(conn, msg) begin
  ECHO_COUNT := ECHO_COUNT + 1;
  conn.send("async:" + msg);
end;

// B.SEC: spawn client di thread terpisah supaya main thread
// bisa tick event loop selama Python client connect.
function runClient() begin
  var py := "
import asyncio, websockets
async def main():
    async with websockets.connect('ws://localhost:9110') as ws:
        for i in range(3):
            await ws.send('msg-' + str(i))
            print('recv:', await ws.recv())
asyncio.run(main())
print('done')
";
  var r := sys.exec("python3", ["-c", py], 15000);
  println(r["stdout"]);
end;

begin
  println("=== ws.listenAsync test ===");

  SRV := ws.serve(9110, {
    "onOpen": onOpen,
    "onMessage": onMessage
  });

  if SRV < 0 then begin
    println("FAIL: serve return -1");
    sys.exit(1);
  end;

  var ok := ws.listenAsync(SRV);
  println("listenAsync return: ", ok);
  sleep(300);

  // Thread client → main thread tick event loop via sleep
  thread(runClient);
  sleep(5000);

  println("open=", OPEN_COUNT, " echo=", ECHO_COUNT);

  ws.stop(SRV);
  sleep(500);

  if (OPEN_COUNT == 1) and (ECHO_COUNT == 3) then begin
    println("PASS");
    sys.exit(0);
  end else begin
    println("FAIL");
    sys.exit(1);
  end;
end.