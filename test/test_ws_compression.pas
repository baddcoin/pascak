var SRV := -1;
var MSG_RECV_LEN := 0;

function onMessage(conn, msg) begin
  MSG_RECV_LEN := len(msg);
  conn.send(msg);
end;

function runClient() begin
  var py := "
import asyncio, websockets
async def main():
    async with websockets.connect('ws://localhost:9140') as ws:
        print('extensions:', list(ws.protocol.extensions))
        big_msg = 'A' * 1000
        await ws.send(big_msg)
        print('sent:', len(big_msg), 'bytes')
        reply = await ws.recv()
        print('recv:', len(reply), 'bytes')
        print('match:', reply == big_msg)
asyncio.run(main())
";
  var r := sys.exec("python3", ["-c", py], 15000);
  println(r["stdout"]);
  if len(r["stderr"]) > 0 then
    println("stderr: ", r["stderr"]);
end;

begin
  println("=== ws permessage-deflate test ===");

  SRV := ws.serve(9140, {
    "onMessage": onMessage,
    "compression": "on",
    "compressionThreshold": 128
  });

  if SRV < 0 then begin
    println("FAIL: serve return -1");
    sys.exit(1);
  end;

  ws.listenAsync(SRV);
  sleep(300);

  thread(runClient);
  sleep(4000);

  println("server received: ", MSG_RECV_LEN, " bytes");

  ws.stop(SRV);
  sleep(500);

  if MSG_RECV_LEN == 1000 then begin
    println("PASS");
    sys.exit(0);
  end else begin
    println("FAIL: expected 1000 bytes, got ", MSG_RECV_LEN);
    sys.exit(1);
  end;
end.