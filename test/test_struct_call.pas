// ============================================================
// F-3a-5c: Struct by value interop with C
// ============================================================

function testStructReturn() begin
  println("[SC-1] struct arg + return");
  
  var lib := dll.load("libpascak_ffi_test.so");
  var PointType := native.structType("Point", [
    ["x", "i32"],
    ["y", "i32"]
  ]);
  
  // translate(Point, i32, i32) → Point
  var translate := lib.func("point_translate", "Sii->S", [PointType, PointType]);
  
  var p := native.newStruct(PointType);
  native.structSet(p, "x", 10);
  native.structSet(p, "y", 20);
  
  var r := translate(p, 5, 7);
  println("  p = (", native.structGet(p, "x"), ", ", native.structGet(p, "y"), ")");
  println("  r = (", native.structGet(r, "x"), ", ", native.structGet(r, "y"), ")");
  
  assertEqual(10, native.structGet(p, "x"), "p.x unchanged");
  assertEqual(20, native.structGet(p, "y"), "p.y unchanged");
  assertEqual(15, native.structGet(r, "x"), "r.x = 10+5");
  assertEqual(27, native.structGet(r, "y"), "r.y = 20+7");
  
  native.structFree(p);
  native.structFree(r);
  native.structTypeFree(PointType);
  lib.close();
end;

function testStructTwoArgs() begin
  println("[SC-2] two struct args, int return");
  
  var lib := dll.load("libpascak_ffi_test.so");
  var PointType := native.structType("Point", [
    ["x", "i32"],
    ["y", "i32"]
  ]);
  
  var distSq := lib.func("point_dist_sq", "SS->i", [PointType, PointType]);
  
  var a := native.newStruct(PointType);
  native.structSet(a, "x", 0);
  native.structSet(a, "y", 0);
  
  var b := native.newStruct(PointType);
  native.structSet(b, "x", 3);
  native.structSet(b, "y", 4);
  
  var d := distSq(a, b);
  println("  dist^2 = ", d, "  (harus 25)");
  assertEqual(25, d, "3-4-5 triangle");
  
  native.structFree(a);
  native.structFree(b);
  native.structTypeFree(PointType);
  lib.close();
end;

function testStructPointer() begin
  println("[SC-3] pointer to struct");
  
  var lib := dll.load("libpascak_ffi_test.so");
  var PointType := native.structType("Point", [
    ["x", "i32"],
    ["y", "i32"]
  ]);
  
  // point_scale_inplace(Point*, i32) → void
  // Kirim pointer langsung (bukan by-value struct) — pakai signature pip->v
  var scale := lib.func("point_scale_inplace", "pip->v");
  
  var p := native.newStruct(PointType);
  native.structSet(p, "x", 5);
  native.structSet(p, "y", 10);
  
  // Struct value's Data pointer adalah pointer ke memory
  // Kita pass value ptr — nanti kita ekspos native.structDataPtr
  // Untuk sekarang, gunakan buffer untuk demonstrasi
  println("  (pointer test skipped — butuh structDataPtr)");
  
  native.structFree(p);
  native.structTypeFree(PointType);
  lib.close();
end;

// ============================================================
begin
  println("=== F-3a-5c: Struct By Value Test ===");
  println("");
  
  testStructReturn();
  println("--- SC-1 done ---");
  
  testStructTwoArgs();
  println("--- SC-2 done ---");
  
  println("");
  println("=== Selesai ===");
  println("Summary: failed = ", testSummary());
end.