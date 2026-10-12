// ============================================================
// Tahap F-3a-2 — Callback Lifecycle
// ============================================================

function testClosureAvailability() begin
  println("[F3a-1] libffi detection");
  
  var available := dll.closureAvailable();
  println("  closureAvailable = ", available);
  
  var info := dll.closureInfo();
  println("  status = ", info.status);
  
  assertTrue(available, "libffi harus tersedia");
end;

function testCallbackLifecycle() begin
  println("[F3a-2] callback lifecycle");
  
  var startCount := dll.callbackCount();
  println("  start count = ", startCount);
  
  // Buat callback trivial: (int, int) -> int
  var cb := dll.callback("ii->i", lambda a, b : a + b);
  assertTrue(cb <> null, "callback allocated");
  println("  cb type = ", typeOf(cb));
  
  var afterAlloc := dll.callbackCount();
  assertEqual(startCount + 1, afterAlloc, "registry +1");
  println("  after alloc = ", afterAlloc);
  
  // Free eksplisit
  var ok := dll.freeCallback(cb);
  assertTrue(ok, "freeCallback returned true");
  
  var afterFree := dll.callbackCount();
  assertEqual(startCount, afterFree, "registry kembali ke awal");
  println("  after free = ", afterFree);
end;

function testCallbackSignatureErrors() begin
  println("[F3a-2] callback error handling");
  
  // Signature invalid
  var caught := false;
  try
    var cb := dll.callback("XX->Z", lambda : 0);
  catch e do
    caught := true;
    println("  correctly rejected: ", e.message);
  end;
  assertTrue(caught, "invalid sig harus raise");
  
  // Non-function second arg
  caught := false;
  try
    var cb := dll.callback("i->i", 42);
  catch e do
    caught := true;
    println("  correctly rejected: ", e.message);
  end;
  assertTrue(caught, "non-function harus raise");
end;

function testCallbackMultiInstance() begin
  println("[F3a-2] multiple callback instances");
  
  var base := dll.callbackCount();
  
  var cb1 := dll.callback("i->i", lambda x : x + 1);
  var cb2 := dll.callback("i->i", lambda x : x * 2);
  var cb3 := dll.callback("ff->f", lambda a, b : a + b);
  
  assertEqual(base + 3, dll.callbackCount(), "3 callback terdaftar");
  println("  count = ", dll.callbackCount());
  
  // Free semua
  dll.freeCallback(cb1);
  dll.freeCallback(cb2);
  dll.freeCallback(cb3);
  
  assertEqual(base, dll.callbackCount(), "semua freed");
  println("  cleanup verified");
end;

// ============================================================
begin
  println("=== Tahap F-3a-2: Callback Lifecycle ===");
  
  testClosureAvailability();
  println("--- F3a-1 ok ---");
  
  testCallbackLifecycle();
  println("--- F3a-2 lifecycle ok ---");
  
  testCallbackSignatureErrors();
  println("--- F3a-2 errors ok ---");
  
  testCallbackMultiInstance();
  println("--- F3a-2 multi ok ---");
  
  println("=== Selesai ===");
  println("Summary: failed = ", testSummary());
end.