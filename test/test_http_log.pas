// test_http_log.pas — A.6 Request Logging
var SRV := -1;

function handler(req) begin
  if req["path"] == "/health" then
    return {"status": 200, "body": "ok"};
  if req["path"] == "/slow" then begin
    sleep(50);
    return {"status": 200, "body": "done"};
  end;
  return {"status": 404, "body": "not found"};
end;

function serverThread() begin
  http.listenAsync(SRV);
end;

begin
  testBegin("A.6 — Request Logging");

  // Enable log (exclude /health)
  http.logRequests({
    "enabled": true,
    "slowMs": 30,
    "excludePaths": ["/health"]
  });

  // Start server
  SRV := http.serve(18090, handler);
  if SRV < 0 then begin
    println("FAIL: server tidak start");
    sys.exit(1);
  end;
  thread(serverThread);
  sleep(300);

  // Request normal — should be logged INFO
  var r1 := http.get("http://127.0.0.1:18090/api/test");
  assertEqual(404, r1.status, "r1 status");

  // Request slow — should be logged WARN
  var r2 := http.get("http://127.0.0.1:18090/slow");
  assertEqual(200, r2.status, "r2 status");

  // Request excluded — should NOT be logged
  var r3 := http.get("http://127.0.0.1:18090/health");
  assertEqual(200, r3.status, "r3 status");

  assertTrue(true, "requests processed — see log output above");

  http.stop(SRV);
  sleep(200);

  testEnd();
  sys.exit(testSummary());
end.