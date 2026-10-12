// ============================================================
// F-3a-3 — Real Callback Dispatch
// ============================================================

function testInvokeII() begin
  println("[F3a-3] invoke ii->i");
  
  var lib := dll.load("libpascak_ffi_test.so");
  var invoke := lib.func("pascak_invoke_ii", "iip->i");
  
  // Callback: (a, b) -> a + b
  var cbAdd := dll.callback("ii->i", lambda a, b : a + b);
  var r1 := invoke(3, 4, cbAdd);
  println("  add(3,4) = ", r1);
  assertEqual(7, r1, "add via callback");
  
  // Callback: (a, b) -> a * b
  var cbMul := dll.callback("ii->i", lambda a, b : a * b);
  var r2 := invoke(5, 6, cbMul);
  println("  mul(5,6) = ", r2);
  assertEqual(30, r2, "mul via callback");
  
  dll.freeCallback(cbAdd);
  dll.freeCallback(cbMul);
  lib.close();
end;

function testInvokeFF() begin
  println("[F3a-3] invoke ff->f");
  
  var lib := dll.load("libpascak_ffi_test.so");
  var invoke := lib.func("pascak_invoke_ff", "ffp->f");
  
  var cbAvg := dll.callback("ff->f", lambda a, b : (a + b) / 2.0);
  var r := invoke(4.0, 8.0, cbAvg);
  println("  avg(4,8) = ", r);
  assertEqual(6.0, r, "avg via callback");
  
  dll.freeCallback(cbAvg);
  lib.close();
end;

function testInvokeVoid() begin
  println("[F3a-3] invoke ->i (closure tanpa argumen)");
  
  var lib := dll.load("libpascak_ffi_test.so");
  var invoke := lib.func("pascak_invoke_void", "p->i");
  
  var cbConst := dll.callback("->i", lambda : 42);
  var r := invoke(cbConst);
  println("  const() = ", r);
  assertEqual(42, r, "constant closure");
  
  dll.freeCallback(cbConst);
  lib.close();
end;

function testInvoke3Reentrant() begin
  println("[F3a-3] re-entrancy (3x callback)");
  
  var lib := dll.load("libpascak_ffi_test.so");
  var invoke3 := lib.func("pascak_invoke3", "ip->i");
  
  // Callback: x -> x * 2, dipanggil 3x: ((1*2)*2)*2 = 8
  var cbDouble := dll.callback("i->i", lambda x : x * 2);
  var r := invoke3(1, cbDouble);
  println("  double^3 (start=1) = ", r);
  assertEqual(8, r, "3x doubling");
  
  // Callback: x -> x + 10, dipanggil 3x: 0+10+10+10 = 30
  var cbAdd10 := dll.callback("i->i", lambda x : x + 10);
  var r2 := invoke3(0, cbAdd10);
  println("  +10^3 (start=0) = ", r2);
  assertEqual(30, r2, "3x add10");
  
  dll.freeCallback(cbDouble);
  dll.freeCallback(cbAdd10);
  lib.close();
end;

function testInvokeCountMetrics() begin
  println("[F3a-3] invoke count metrics");
  
  var lib := dll.load("libpascak_ffi_test.so");
  var invoke := lib.func("pascak_invoke_ii", "iip->i");
  
  var cb := dll.callback("ii->i", lambda a, b : a - b);
  
  invoke(10, 3, cb);
  invoke(20, 5, cb);
  invoke(100, 1, cb);
  
  println("  after 3 invocations — no crash");
  
  dll.freeCallback(cb);
  lib.close();
end;

// ============================================================
begin
  println("=== F-3a-3: Callback Dispatch ===");
  
  testInvokeII();
  println("--- ii->i ok ---");
  
  testInvokeFF();
  println("--- ff->f ok ---");
  
  testInvokeVoid();
  println("--- ->i ok ---");
  
  testInvoke3Reentrant();
  println("--- re-entrancy ok ---");
  
  testInvokeCountMetrics();
  println("--- metrics ok ---");
  
  println("=== Selesai ===");
  println("Summary: failed = ", testSummary());
end.