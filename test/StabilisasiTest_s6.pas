// ============================================================
// Stabilisasi S-6 — Memory Leak Regression
// ============================================================

var GC_BASELINE := 0;
var GC_SAMPLE_SIZE := 10000;

// Warmup: priming cache, JIT, freelist, dst.
function warmup() begin
  var i;
  for i := 0 to 999 do begin
    var d := {a: i, b: i + 1, c: "test"};
    var arr := [i, i + 1, i + 2];
    var s := "warmup_" + str(i);
    // discard
  end;
end;

// Ambil snapshot memory
function snap() begin
  var m := sys.memoryUsage();
  return m.used_bytes;
end;

// ------------------------------------------------------------
// L1: Dict create/destroy loop
// ------------------------------------------------------------
function leak_dict() begin
  println("[L1] dict churn");
  
  var i;
  var before := snap();
  
  for i := 0 to GC_SAMPLE_SIZE - 1 do begin
    var d := {k1: i, k2: "val" + str(i), k3: [i, i+1]};
    // d fall out of scope — should be GC'd
  end;
  
  var after := snap();
  var delta := after - before;
  println("  before=", before, " after=", after, " delta=", delta);
  
  // Setelah warmup, delta harus kecil — bukan linear terhadap GC_SAMPLE_SIZE
  // Ambang longgar: 1 MB untuk 10k iterasi
  assertTrue(delta < 1048576, "dict loop leak-free");
end;

// ------------------------------------------------------------
// L2: Array create/destroy loop
// ------------------------------------------------------------
function leak_array() begin
  println("[L2] array churn");
  
  var before := snap();
  var i;
  for i := 0 to GC_SAMPLE_SIZE - 1 do begin
    var a := [i, i*2, i*3, i*4, i*5];
  end;
  var after := snap();
  var delta := after - before;
  println("  before=", before, " after=", after, " delta=", delta);
  
  assertTrue(delta < 1048576, "array loop leak-free");
end;

// ------------------------------------------------------------
// L3: String concat + parse loop
// ------------------------------------------------------------
function leak_string() begin
  println("[L3] string churn");
  
  var before := snap();
  var i;
  for i := 0 to GC_SAMPLE_SIZE - 1 do begin
    var s := "prefix_" + str(i) + "_suffix_" + str(i * 2);
    var parts := s.split("_");
    var joined := parts.join("-");
  end;
  var after := snap();
  var delta := after - before;
  println("  before=", before, " after=", after, " delta=", delta);
  
  assertTrue(delta < 1048576, "string loop leak-free");
end;

// ------------------------------------------------------------
// L4: Nested structure churn
// ------------------------------------------------------------
function leak_nested() begin
  println("[L4] nested structure churn");
  
  var before := snap();
  var i;
  for i := 0 to 5000 do begin
    var d := {
      id: i,
      meta: {name: "user_" + str(i), age: i mod 100},
      tags: ["a", "b", "c"],
      scores: [i, i+1, i+2]
    };
  end;
  var after := snap();
  var delta := after - before;
  println("  before=", before, " after=", after, " delta=", delta);
  
  assertTrue(delta < 2097152, "nested loop leak-free");
end;

// ------------------------------------------------------------
// L5: Closure capture loop
// ------------------------------------------------------------
function leak_closure() begin
  println("[L5] closure capture churn");
  
  var before := snap();
  var i;
  for i := 0 to 2000 do begin
    var counter := i;
    var fn := lambda : counter + 1;
    var r := fn();
  end;
  var after := snap();
  var delta := after - before;
  println("  before=", before, " after=", after, " delta=", delta);
  
  assertTrue(delta < 1048576, "closure loop leak-free");
end;

// ------------------------------------------------------------
// L6: Repeated function calls (no leak per call)
// ------------------------------------------------------------
function compute(x, y) begin
  var acc := 0;
  var i;
  for i := 0 to 9 do
    acc := acc + x * i + y;
  return acc;
end;

function leak_calls() begin
  println("[L6] function call churn");
  
  var before := snap();
  var i;
  var total := 0;
  for i := 0 to 20000 do
    total := total + compute(i, i + 1);
  var after := snap();
  var delta := after - before;
  println("  before=", before, " after=", after, " delta=", delta);
  println("  total (sanity): ", total);
  
  assertTrue(delta < 1048576, "function call loop leak-free");
end;

// ------------------------------------------------------------
// L7: HTTP request churn (with server)
// ------------------------------------------------------------
function leak_http_server() begin
  var srv := http.serve(19600, lambda req : begin
    return {status: 200, body: "pong"};
  end);
  http.listen(srv);
end;

function leak_http() begin
  println("[L7] HTTP request churn");
  sleep(300);
  
  // Warmup 10 requests
  var i;
  for i := 0 to 9 do
    http.get("http://127.0.0.1:19600/");
  
  var before := snap();
  
  var ok := 0;
  for i := 0 to 99 do begin
    var res := http.get("http://127.0.0.1:19600/");
    if res.status == 200 then ok := ok + 1;
  end;
  
  var after := snap();
  var delta := after - before;
  println("  ok=", ok, " delta=", delta);
  
  assertEqual(100, ok, "all requests ok");
  assertTrue(delta < 5242880, "http loop leak-free");   // 5 MB threshold (network buffers)
end;

// ------------------------------------------------------------
// L8: Recursive calls
// ------------------------------------------------------------
function fib(n) begin
  if n <= 1 then return n;
  return fib(n-1) + fib(n-2);
end;

function leak_recursion() begin
  println("[L8] recursion churn");
  
  var before := snap();
  var i;
  var total := 0;
  for i := 0 to 500 do
    total := total + fib(15);
  var after := snap();
  var delta := after - before;
  println("  before=", before, " after=", after, " delta=", delta);
  
  assertTrue(delta < 1048576, "recursion loop leak-free");
end;

// ============================================================
// Runner
// ============================================================
begin
  println("=== Stabilisasi S-6: Memory Leak Regression ===");
  
  // Warmup dulu agar tidak false positive
  println("Warmup...");
  warmup();
  gcStep();
  sleep(100);
  println("Warmup done. Baseline=", snap());
  
  leak_dict();
  gcStep(); sleep(50);
  println("--- L1 done ---");
  
  leak_array();
  gcStep(); sleep(50);
  println("--- L2 done ---");
  
  leak_string();
  gcStep(); sleep(50);
  println("--- L3 done ---");
  
  leak_nested();
  gcStep(); sleep(50);
  println("--- L4 done ---");
  
  leak_closure();
  gcStep(); sleep(50);
  println("--- L5 done ---");
  
  leak_calls();
  gcStep(); sleep(50);
  println("--- L6 done ---");
  
  thread(leak_http_server);
  leak_http();
  gcStep(); sleep(50);
  println("--- L7 done ---");
  
  leak_recursion();
  gcStep(); sleep(50);
  println("--- L8 done ---");
  
  println("=== Semua test selesai ===");
  println("Summary: failed = ", testSummary());
end.