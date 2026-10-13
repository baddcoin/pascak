// test_pool_server.pas — A.1 HTTP Pool dengan server lokal
var SRV := -1;

function handler(req) begin
  return {
    "status": 200,
    "headers": {
      "Content-Type": "text/plain",
      "Content-Length": "5"
    },
    "body": "hello"
  };
end;

function serverThread() begin
  http.listenAsync(SRV);
end;

begin
  testBegin("A.1 — HTTP Pool (local server)");

  // Start server di port 18080
  SRV := http.serve(18080, handler);
  if SRV < 0 then begin
    println("FAIL: server tidak bisa start");
    sys.exit(1);
  end;

  thread(serverThread);
  sleep(200);   // tunggu server ready

  // Reset pool
  http.poolClear();

  // Test 1: Request 1 — MISS (fresh connect)
  var r1 := http.get("http://127.0.0.1:18080/");
  assertEqual(200, r1.status, "r1 status");
  assertEqual("hello", r1.body, "r1 body");

  var s1 := http.poolStats();
  assertEqual(1, s1.misses, "r1 is miss");
  assertEqual(0, s1.hits, "r1 no hits yet");

  // Test 2: Request 2 — HIT (reuse pool)
  var r2 := http.get("http://127.0.0.1:18080/");
  assertEqual(200, r2.status, "r2 status");
  assertEqual("hello", r2.body, "r2 body");

  var s2 := http.poolStats();
  assertTrue(s2.hits >= 1, "r2 is hit");
  assertEqual(2, s2.misses + s2.hits, "total requests = 2");

  // Test 3: Config API
  http.poolConfig(4, 10000);
  var s3 := http.poolStats();
  assertEqual(4, s3.maxPerHost, "poolConfig maxPerHost");
  assertEqual(10000, s3.idleMs, "poolConfig idleMs");

  // Test 4: poolClear
  http.poolClear();
  var s4 := http.poolStats();
  assertEqual(0, s4.idle, "poolClear resets idle");

  // Cleanup
  http.stop(SRV);
  sleep(200);

  testEnd();
  sys.exit(testSummary());
end.