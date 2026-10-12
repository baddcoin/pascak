var SRV := -1;
var ECHO_COUNT := 0;

function onMessage(conn, msg) begin
  ECHO_COUNT := ECHO_COUNT + 1;
  conn.send("pong-test:" + msg);
end;

function runClient() begin
  var py := "
import asyncio, websockets
async def main():
    async with websockets.connect('ws://localhost:9130') as ws:
        print('connected')
        await asyncio.sleep(3)
        print('still alive after 3s idle')
        await ws.send('after-idle')
        print('recv:', await ws.recv())
        print('done')
asyncio.run(main())
";
  var r := sys.exec("python3", ["-c", py], 15000);
  println(r["stdout"]);
end;

begin
  println("=== ws ping/pong test ===");

  SRV := ws.serve(9130, {
    "onMessage": onMessage,
    "pingInterval": 500,
    "pongTimeout": 2000
  });

  if SRV < 0 then begin
    println("FAIL: serve return -1");
    sys.exit(1);
  end;

  ws.listenAsync(SRV);
  sleep(300);

  thread(runClient);
  sleep(6000);

  println("echo_count = ", ECHO_COUNT);

  ws.stop(SRV);
  sleep(500);

  if ECHO_COUNT == 1 then begin
    println("PASS");
    sys.exit(0);
  end else begin
    println("FAIL: expected 1 echo, got ", ECHO_COUNT);
    sys.exit(1);
  end;
end.