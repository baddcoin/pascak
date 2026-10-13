// test_http_trace.pas — A.8 Request ID Tracking
var SRV := -1;
var receivedIds := [];

function handler(req) begin
  var rid := req["requestId"];
  lock begin
    push(receivedIds, rid);
  end;
  return {
    "status": 200,
    "headers": {"Content-Type": "text/plain"},
    "body": "rid=" + rid
  };
end;

function serverThread() begin
  http.listenAsync(SRV);
end;

begin
  testBegin("A.8 — Request ID Tracking");

  // Enable trace
  http.traceRequests({
    "enabled": true,
    "header": "X-Request-ID",
    "responseHeader": true,
    "prefix": "test-"
  });

  // Enable log also to see combined
  http.logRequests({"enabled": true, "slowMs": 5000});

  SRV := http.serve(18100, handler);
  if SRV < 0 then begin
    println("FAIL: server tidak start");
    sys.exit(1);
  end;
  thread(serverThread);
  sleep(300);

  // Test 1: Request without ID → auto-generated
  var r1 := http.get("http://127.0.0.1:18100/");
  assertEqual(200, r1.status, "r1 status");
  assertTrue(len(receivedIds) >= 1, "server received ID");

  var genId := receivedIds[0];
  assertTrue(pos("test-", genId) == 1, "auto-generated ID has prefix");
  assertTrue(len(genId) >= 15, "auto-generated ID has sufficient length");

  // Test 2: Echo back in response header
  assertTrue(r1.headers.hasKey("X-Request-ID"), "response has request ID header");
  var echoed := r1.headers["X-Request-ID"];
  assertEqual(genId, echoed, "echoed ID matches");

  // Test 3: Client-provided ID preserved
  var r2 := http.get("http://127.0.0.1:18100/", {
    "X-Request-ID": "custom-id-12345"
  });
  assertEqual(200, r2.status, "r2 status");
  assertTrue(len(receivedIds) >= 2, "server received second ID");
  assertEqual("custom-id-12345", receivedIds[1], "client ID preserved");

  // Test 4: Response echoes client ID
  var echoed2 := r2.headers["X-Request-ID"];
  assertEqual("custom-id-12345", echoed2, "client ID echoed");

  // Test 5: Different requests get different auto IDs
  var r3 := http.get("http://127.0.0.1:18100/");
  sleep(50);
  assertTrue(len(receivedIds) >= 3, "server received third ID");
  assertTrue(receivedIds[2] <> genId, "each auto ID unique");

  http.stop(SRV);
  sleep(200);

  testEnd();
  sys.exit(testSummary());
end.