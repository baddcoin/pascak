// ============================================================
// F-3a-4 — Alias C & String Return
// ============================================================

function testCallbackAliasC() begin
  println("[F3a-4] alias C di signature");
  
  var lib := dll.load("libpascak_ffi_test.so");
  
  // iiC->i sama dengan iip->i
  var invoke := lib.func("pascak_invoke_ii", "iiC->i");
  
  var cb := dll.callback("ii->i", lambda a, b : a + b);
  var r := invoke(10, 20, cb);
  println("  add via C alias: ", r);
  assertEqual(30, r, "alias C works");
  
  dll.freeCallback(cb);
  lib.close();
end;

function testCallbackStringReturn() begin
  println("[F3a-4] string return dari callback");
  
  var lib := dll.load("libpascak_ffi_test.so");
  var invokeStrlen := lib.func("pascak_invoke_strlen", "p->i");
  
  // Callback: () -> "hello"
  var cbHello := dll.callback("->s", lambda : "hello");
  var n1 := invokeStrlen(cbHello);
  println("  strlen('hello') via cb = ", n1);
  assertEqual(5, n1, "hello length");
  
  // Callback: () -> "pascak vm is awesome" (20 chars)
  var cbLong := dll.callback("->s", lambda : "pascak vm is awesome");
  var n2 := invokeStrlen(cbLong);
  println("  strlen(long) via cb = ", n2);
  assertEqual(20, n2, "long string length");
  
  // Callback: () -> "" (empty)
  var cbEmpty := dll.callback("->s", lambda : "");
  var n3 := invokeStrlen(cbEmpty);
  println("  strlen('') via cb = ", n3);
  assertEqual(0, n3, "empty string length");
  
  dll.freeCallback(cbHello);
  dll.freeCallback(cbLong);
  dll.freeCallback(cbEmpty);
  lib.close();
end;

function testCallbackStringGrowth() begin
  println("[F3a-4] buffer growth across sizes");
  
  var lib := dll.load("libpascak_ffi_test.so");
  var invokeStrlen := lib.func("pascak_invoke_strlen", "p->i");
  
  // 3 callback dengan panjang berbeda — memicu buffer growth
  var cb1 := dll.callback("->s", lambda : "a");
  var cb3 := dll.callback("->s", lambda : "abc");
  var cb9 := dll.callback("->s", lambda : "abcdefghi");
  
  // Urutan: kecil → sedang → besar → kembali kecil
  // Buffer harus reuse tanpa crash, hasil harus konsisten
  var n1 := invokeStrlen(cb1);
  var n2 := invokeStrlen(cb3);
  var n3 := invokeStrlen(cb9);
  var n4 := invokeStrlen(cb1);
  
  println("  lengths: ", n1, " ", n2, " ", n3, " ", n4);
  assertEqual(1, n1, "short");
  assertEqual(3, n2, "mid");
  assertEqual(9, n3, "long");
  assertEqual(1, n4, "short again");
  
  dll.freeCallback(cb1);
  dll.freeCallback(cb3);
  dll.freeCallback(cb9);
  lib.close();
end;

function testCallbackStringReuse() begin
  println("[F3a-4] same callback, 10x invocations");
  
  var lib := dll.load("libpascak_ffi_test.so");
  var invokeStrlen := lib.func("pascak_invoke_strlen", "p->i");
  
  // Satu callback yang selalu return string sama
  var cb := dll.callback("->s", lambda : "consistent");
  
  // Panggil 10× — buffer yang sama di-reuse setiap invokasi.
  // "consistent" = 10 char, 10× = 100.
  var total := 0;
  var i := 0;
  while i < 10 do
  begin
    total := total + invokeStrlen(cb);
    i := i + 1;
  end;
  
  println("  sum of 10x invocations = ", total);
  assertEqual(100, total, "10 * len('consistent')");
  
  dll.freeCallback(cb);
  lib.close();
end;

function testCallbackStringInvalidSig() begin
  println("[F3a-4] invalid signature fallback");
  
  var caught := false;
  try
    var cb := dll.callback("->Z", lambda : 0);
  catch e do
    caught := true;
    println("  correctly rejected: ", e.message);
  end;
  assertTrue(caught, "invalid return type rejected");
end;

// ============================================================
begin
  println("=== F-3a-4: Alias C & String Return ===");
  
  testCallbackAliasC();
  println("--- alias C ok ---");
  
  testCallbackStringReturn();
  println("--- string return ok ---");
  
  testCallbackStringGrowth();
  println("--- buffer growth ok ---");
  
  testCallbackStringReuse();
  println("--- buffer reuse ok ---");
  
  testCallbackStringInvalidSig();
  println("--- invalid sig ok ---");
  
  println("=== Selesai ===");
  println("Summary: failed = ", testSummary());
end.