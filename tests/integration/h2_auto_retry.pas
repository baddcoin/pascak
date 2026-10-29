begin
  println("=== Request 1: expect GOAWAY retry → success ===");
  var r := http.get2("https://localhost:8443/test");
  println("status =", r.status);
  println("version =", r.version);
  println("body =", r.body);

  println("");
  println("=== Request 2: fresh conn direct success ===");
  var r2 := http.get2("https://localhost:8443/test2");
  println("status2 =", r2.status);
  println("body2 =", r2.body);

  println("");
  println("=== Pool stats ===");
  var s := http.get2PoolStats();
  println("hits =", s.hits);
  println("misses =", s.misses);
end.
