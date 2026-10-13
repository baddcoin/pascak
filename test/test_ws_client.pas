// test_ws_client.pas — Bundle C WebSocket Client
var SRV := -1;
var serverReceived := [];
var clientReceived := [];
var opened1 := false;
var opened2 := false;
var closed1 := false;

// ── Server callbacks ──
function onServerMessage(conn, msg) begin
  lock begin
    push(serverReceived, msg);
  end;
  println("[server] recv: ", msg);
  // Echo back
  conn.send("echo:" + msg);
end;

function serverThread() begin
  ws.listen(SRV);
end;

// ── Client 1 callbacks ──
function onC1Open(c) begin
  lock begin opened1 := true; end
  println("[client1] connected: ", c.id);
end;

function onC1Message(c, msg) begin
  lock begin push(clientReceived, msg); end
  println("[client1] recv: ", msg);
end;

function onC1Close(c, code) begin
  lock begin closed1 := true; end
  println("[client1] closed code=", code);
end;

// ── Client 2 callbacks ──
function onC2Open(c) begin
  lock begin opened2 := true; end
  println("[client2] connected: ", c.id);
end;

begin
  testBegin("Bundle C — WebSocket Client v2");

  // 1. Start server
  SRV := ws.serve(19101, {
    "onMessage": onServerMessage
  });
  if SRV < 0 then begin
    println("FAIL: server tidak start");
    sys.exit(1);
  end;
  thread(serverThread);
  sleep(300);

  // 2. Connect client 1
  var c1 := ws.connect("ws://127.0.0.1:19101/", {
    "onOpen":    onC1Open,
    "onMessage": onC1Message,
    "onClose":   onC1Close
  });

  assertEqual("dictionary", typeOf(c1), "ws.connect returns handle dict");
  assertTrue(c1.hasKey("__ws_id"), "handle has __ws_id");

  sleep(500);
  assertTrue(opened1, "client1 onOpen fired");

  // 3. Client sends message → server receives + echoes back
  var sent := c1.send("hello");
  assertTrue(sent, "c1.send returns true");

  sleep(500);
  assertEqual(1, len(serverReceived), "server received 1 msg");
  if len(serverReceived) >= 1 then
    assertEqual("hello", serverReceived[0], "server got 'hello'");

  assertEqual(1, len(clientReceived), "client got echo");
  if len(clientReceived) >= 1 then
    assertEqual("echo:hello", clientReceived[0], "echo content match");

  // 4. Connect client 2
  var c2 := ws.connect("ws://127.0.0.1:19101/", {
    "onOpen": onC2Open
  });
  sleep(300);
  assertTrue(opened2, "client2 onOpen fired");

  // 5. Client 1 close
  c1.close();
  sleep(500);
  assertTrue(closed1, "client1 onClose fired");

  testEnd();
  sys.exit(testSummary());
end.