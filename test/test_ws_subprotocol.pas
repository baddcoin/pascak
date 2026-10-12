var SRV := -1;
var LAST_PROTO := "";

function onOpen(conn) begin
  LAST_PROTO := conn["protocol"];
end;

function runClient() begin
  var py := "
import asyncio, websockets
async def main():
    async with websockets.connect(
        'ws://localhost:9120',
        subprotocols=['chat']
    ) as ws:
        print('client selected:', ws.subprotocol)
asyncio.run(main())
";
  var r := sys.exec("python3", ["-c", py], 10000);
  println(r["stdout"]);
end;

begin
  println("=== ws subprotocol test ===");

  SRV := ws.serve(9120, {
    "onOpen": onOpen,
    "subprotocols": ["chat", "json-v1"]
  });

  if SRV < 0 then begin
    println("FAIL: serve return -1");
    sys.exit(1);
  end;

  ws.listenAsync(SRV);
  sleep(300);

  thread(runClient);
  sleep(3000);

  println("server last_proto = ", LAST_PROTO);

  ws.stop(SRV);
  sleep(500);

  if LAST_PROTO == "chat" then begin
    println("PASS");
    sys.exit(0);
  end else begin
    println("FAIL: expected 'chat', got '", LAST_PROTO, "'");
    sys.exit(1);
  end;
end.