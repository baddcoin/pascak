// ============================================================
// Tahap F-1 — DLL/FFI Object Test
// ============================================================

function testDLLLoad() begin
  println("[T1] DLL load + refcount");
  
  // Load A
  var libA := dll.load("libpascak_test.so");
  assertTrue(libA.isValid(), "libA valid");
  
  // Load B ke path yang SAMA — harus dedup, return handle equivalent
  var libB := dll.load("libpascak_test.so");
  assertTrue(libB.isValid(), "libB valid (dedup)");
  
  // Symbol harus tetap resolve dari kedua handle
  var addA := libA.func("add_ints", "ii->i");
  var addB := libB.func("add_ints", "ii->i");
  assertEqual(7, addA(3, 4), "addA works");
  assertEqual(7, addB(3, 4), "addB works");
  
  // Close satu — library harus masih hidup
  libA.close();
  assertTrue(libB.isValid(), "libB masih valid setelah libA.close");
  assertEqual(7, addB(3, 4), "addB masih works setelah libA.close");
  
  // Close kedua — refcount = 0
  libB.close();
  
  println("  registry refcount verified");
end;

function testDLLFunc() begin
  println("[T2] DLL function call");
  
  var lib := dll.load("libpascak_test.so");
  
  // add_ints(int, int) → int
  var add := lib.func("add_ints", "ii->i");
  var sum := add(3, 4);
  println("  add(3, 4) = ", sum);
  assertEqual(7, sum, "add");
  
  // triple(int) → int
  var triple := lib.func("triple", "i->i");
  var t := triple(14);
  println("  triple(14) = ", t);
  assertEqual(42, t, "triple");
  
  lib.close();
end;

function testDLLSymbol() begin
  println("[T3] DLL symbol access");
  
  var lib := dll.load("libpascak_test.so");
  
  var counterPtr := lib.symbol("global_counter");
  assertTrue(counterPtr <> null, "counter symbol found");
  println("  counter pointer: ", typeOf(counterPtr));
  
  // Baca nilai via hardware.peek (1 byte) — global_counter = 100 = 0x64
  // Note: endianness dependent, tapi karena int, kita baca 4 byte
  // Simplifikasi — kita hanya cek pointer tidak null
  
  lib.close();
end;

function testDLLMissingFunc() begin
  println("[T4] DLL missing function");
  
  var lib := dll.load("libpascak_test.so");
  var caught := false;
  
  try
    var missing := lib.func("nonexistent_function", "i->i");
    println("  warning: missing func tidak raise");
  catch e do
    caught := true;
    println("  correctly rejected: ", e.message);
  end;
  
  assertTrue(caught, "missing func harus raise exception");   // ← fix
  
  lib.close();
end;

function testDLLMissingFile() begin
  println("[T5] DLL missing file");
  
  var caught := false;
  try
    var lib := dll.load("nonexistent_library.so");
  catch e do
    caught := true;
    println("  correctly rejected: ", e.message);
  end;
  
  assertTrue(caught, "missing file rejected");
end;

function testDLLMemoryFFI() begin
  println("[T6] FFI memory ops");
  
  var lib := dll.load("libpascak_ffi_test.so");
  
  // I->p : alloc(64)
  var allocFn := lib.func("pascak_alloc", "I->p");
  var buf := allocFn(64);
  assertTrue(buf <> null, "alloc(64) non-null");
  println("  alloc(64) -> ", typeOf(buf));
  
  // pI->p : realloc(buf, 128)
  var reallocFn := lib.func("pascak_realloc", "pI->p");
  var buf2 := reallocFn(buf, 128);
  assertTrue(buf2 <> null, "realloc non-null");
  println("  realloc -> ", typeOf(buf2));
  
  // p->v : free(buf2)
  var freeFn := lib.func("pascak_free", "p->v");
  freeFn(buf2);
  println("  free(buf2) — ok");
  
  lib.close();
end;

function testDLLStringFFI() begin
  println("[T7] FFI string ops");
  
  var lib := dll.load("libpascak_ffi_test.so");
  
  // s->i : strlen
  var strlenFn := lib.func("pascak_strlen", "s->i");
  assertEqual(5, strlenFn("hello"), "strlen('hello')");
  assertEqual(9, strlenFn("pascak vm"), "strlen('pascak vm')");
  assertEqual(0, strlenFn(""), "strlen('')");
  println("  strlen OK");
  
  // ss->i : strcmp
  var strcmpFn := lib.func("pascak_strcmp", "ss->i");
  assertEqual(0, strcmpFn("abc", "abc"), "strcmp eq");
  assertTrue(strcmpFn("abc", "abd") <> 0, "strcmp neq");
  println("  strcmp OK");
  
  // ss->s : concat
  var concatFn := lib.func("pascak_concat", "ss->s");
  var result := concatFn("hello ", "world");
  assertEqual("hello world", result, "concat");
  println("  concat -> '", result, "'");
  
  lib.close();
end;

function testDLLMultiArgFFI() begin
  println("[T8] FFI multi-arg & conversion");
  
  var lib := dll.load("libpascak_ffi_test.so");
  
  // iiii->i : add4
  var add4 := lib.func("pascak_add4", "iiii->i");
  assertEqual(10, add4(1, 2, 3, 4), "add4(1,2,3,4)");
  println("  add4(1,2,3,4) = ", add4(1, 2, 3, 4));
  
  // fff->f : avg3
  var avg3 := lib.func("pascak_avg3", "fff->f");
  assertEqual(2.0, avg3(1.0, 2.0, 3.0), "avg3(1,2,3)");
  println("  avg3(1,2,3) = ", avg3(1.0, 2.0, 3.0));
  
  // i->f : int_to_double
  // i->f : int_to_double
  var i2d := lib.func("pascak_int_to_double", "i->f");
  assertEqual(3.0, i2d(3), "int->double: 3 -> 3.0");
  assertEqual(7.0, i2d(7), "int->double: 7 -> 7.0");
  println("  i->f: 3 -> ", i2d(3));
  
  // f->i : double_to_int (truncate ke integer)
  var d2i := lib.func("pascak_double_to_int", "f->i");
  assertEqual(3, d2i(3.9), "double->int truncates");
  println("  f->i: 3.9 -> ", d2i(3.9));  
  
  // i->v, ->i : store & retrieve
  var storeFn := lib.func("pascak_store", "i->v");
  var retrieveFn := lib.func("pascak_retrieve", "->i");
  storeFn(42);
  assertEqual(42, retrieveFn(), "store/retrieve roundtrip");
  println("  i->v / ->i roundtrip: 42");
  
  lib.close();
end;

// ============================================================
begin
  println("=== Tahap F-1: DLL/FFI Object Test ===");
  
  testDLLLoad();
  println("--- T1 done ---");
  
  testDLLFunc();
  println("--- T2 done ---");
  
  testDLLSymbol();
  println("--- T3 done ---");
  
  testDLLMissingFunc();
  println("--- T4 done ---");
  
  testDLLMissingFile();
  println("--- T5 done ---");
  
  testDLLMemoryFFI();
  println("--- T6 done ---");
  
  testDLLStringFFI();
  println("--- T7 done ---");

  testDLLMultiArgFFI();
  println("--- T8 done ---");
    println("=== Semua test selesai ===");
    println("Summary: failed = ", testSummary());
end.