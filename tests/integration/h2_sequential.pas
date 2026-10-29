begin
  // ── Happy path: no GOAWAY, normal flow ──
  var r := http.get2("https://httpbin.org/get");
  println("status    =", r.status);
  println("version   =", r.version);
  println("body len  =", len(r.body));

  // ── Second call (pool reuse) ──
  var r2 := http.get2("https://httpbin.org/headers");
  println("status2   =", r2.status);

  // ── Pool stats (classification shouldn't break stats) ──
  var s := http.get2PoolStats();
  println("hits      =", s.hits);
  println("misses    =", s.misses);
  println("idle      =", s.idle);
end.
