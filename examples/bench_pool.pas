var SRV := -1;

function handler(req) begin
  return {
    "status": 200,
    "headers": {"Content-Length": "5"},
    "body": "hello"
  };
end;

function serverThread() begin
  http.listenAsync(SRV);
end;

begin
  SRV := http.serve(18082, handler);
  thread(serverThread);
  sleep(300);

  // WITH pool
  println("=== WITH pool ===");
  var i;
  var start := time.now();
  for i := 1 to 100 do begin
    var r := http.get("http://127.0.0.1:18082/");
  end;
  var elapsed := time.now() - start;
  println("100 requests: ", elapsed, "s");
  var s := http.poolStats();
  println("hits: ", s.hits, " misses: ", s.misses);

  // Reset & clear pool for no-pool test
  http.poolClear();
  http.poolConfig(0, 0);   // disable pool

  println("");
  println("=== WITHOUT pool (disabled) ===");
  start := time.now();
  for i := 1 to 100 do begin
    var r := http.get("http://127.0.0.1:18082/");
  end;
  elapsed := time.now() - start;
  println("100 requests: ", elapsed, "s");

  http.stop(SRV);
end.
