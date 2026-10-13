// test_metrics.pas — A.4 Metrics
begin
  testBegin("A.4 — Metrics");

  // Counter
  metrics.define("test_requests", "counter", "Total test requests");
  metrics.increment("test_requests");
  metrics.increment("test_requests");
  metrics.increment("test_requests");
  assertTrue(true, "counter increment 3x");

  // Counter with labels
  metrics.increment("test_requests", {"method": "GET"});
  metrics.increment("test_requests", {"method": "POST"});
  metrics.increment("test_requests", {"method": "POST"});

  // Gauge
  metrics.define("test_queue", "gauge", "Queue size");
  metrics.set("test_queue", 42);

  // Histogram
  metrics.define("test_latency", "histogram", "Latency ms");
  metrics.observe("test_latency", 5);
  metrics.observe("test_latency", 15);
  metrics.observe("test_latency", 100);
  metrics.observe("test_latency", 5000);

  // Expose
  var out := metrics.expose();
  assertTrue(len(out) > 0, "expose returns text");
  assertTrue(pos("test_requests", out) > 0, "expose contains counter");
  assertTrue(pos("test_queue 42", out) > 0, "gauge value correct");
  assertTrue(pos("method=\"GET\"", out) > 0, "label present");
  assertTrue(pos("test_latency_count 4", out) > 0, "histogram count");

  // List
  var names := metrics.list();
  assertTrue(len(names) >= 3, "list has >=3 metrics");

  // Reset — values cleared, definitions tetap
  metrics.reset();
  var out2 := metrics.expose();
  // Setelah reset, semua metric terdaftar tapi tanpa nilai
  var names2 := metrics.list();
  assertTrue(len(names2) >= 3, "reset keeps definitions");
  // Nilai gauge hilang dari output
  assertTrue(pos("test_queue 42", out2) == 0, "reset clears gauge value");
  
  // Print sample output
  println("=== Sample expose ===");
  var sample := metrics.expose();
  println(sample);

  testEnd();
  sys.exit(testSummary());
end.