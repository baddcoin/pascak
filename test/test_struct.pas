// ============================================================
// F-3a-5a: Native Struct Type System Test
// ============================================================

function testStructBasic() begin
  println("[S-1] struct basic");
  
  var PointType := native.structType("Point", [
    ["x", "i32"],
    ["y", "i32"]
  ]);
  assertTrue(PointType <> null, "type created");
  println("  type created");
  
  var p := native.newStruct(PointType);
  assertTrue(p <> null, "value created");
  println("  struct type = ", native.structTypeName(p));
  println("  struct size = ", native.structSize(p), "  (harus 8)");
  
  native.structSet(p, "x", 10);
  native.structSet(p, "y", 20);
  
  var x := native.structGet(p, "x");
  var y := native.structGet(p, "y");
  println("  x = ", x);
  println("  y = ", y);
  assertEqual(10, x, "x");
  assertEqual(20, y, "y");
  
  native.structFree(p);
  native.structTypeFree(PointType);
end;

function testStructMixedTypes() begin
  println("[S-2] mixed field types");
  
  // Entry: {i64 id, f64 score, bool active, i32 rank}
  // Layout:
  //   offset 0:  i64 id     (8 byte, align 8)
  //   offset 8:  f64 score  (8 byte, align 8)
  //   offset 16: bool active (1 byte, align 1)
  //   offset 17: i32 rank   (align 4 → offset 20)
  //   total: 24 (align 8)
  var EntryType := native.structType("Entry", [
    ["id", "i64"],
    ["score", "f64"],
    ["active", "bool"],
    ["rank", "i32"]
  ]);
  
  var e := native.newStruct(EntryType);
  println("  Entry size = ", native.structSize(e), "  (harus 24)");
  assertEqual(24, native.structSize(e), "Entry alignment");
  
  native.structSet(e, "id", 1234567890);
  native.structSet(e, "score", 98.5);
  native.structSet(e, "active", true);
  native.structSet(e, "rank", 5);
  
  assertEqual(1234567890, native.structGet(e, "id"), "id");
  assertEqual(98.5, native.structGet(e, "score"), "score");
  assertEqual(true, native.structGet(e, "active"), "active");
  assertEqual(5, native.structGet(e, "rank"), "rank");
  println("  all fields verified");
  
  native.structFree(e);
  native.structTypeFree(EntryType);
end;

function testStructFloats() begin
  println("[S-3] float fields (Vec3)");
  
  var Vec3Type := native.structType("Vec3", [
    ["x", "f32"],
    ["y", "f32"],
    ["z", "f32"]
  ]);
  
  var v := native.newStruct(Vec3Type);
  assertEqual(12, native.structSize(v), "Vec3 = 12 byte (no pad)");
  
  native.structSet(v, "x", 1.5);
  native.structSet(v, "y", -2.25);
  native.structSet(v, "z", 3.125);
  
  var x := native.structGet(v, "x");
  var y := native.structGet(v, "y");
  var z := native.structGet(v, "z");
  println("  x = ", x, ", y = ", y, ", z = ", z);
  
  // f32 presisi terbatas — cukup tolerance
  assertTrue(x > 1.49 and x < 1.51, "x ~1.5");
  assertTrue(y > -2.26 and y < -2.24, "y ~-2.25");
  assertTrue(z > 3.124 and z < 3.126, "z ~3.125");
  
  native.structFree(v);
  native.structTypeFree(Vec3Type);
end;

function testStructErrors() begin
  println("[S-4] error handling");
  
  // Duplicate field — function call sebagai statement, tidak perlu assign
  var caught := false;
  try
    native.structType("Bad", [["x", "i32"], ["x", "i32"]]);
  catch e do
    caught := true;
    println("  ✓ duplicate rejected: ", e.message);
  end;
  assertTrue(caught, "duplicate field rejected");
  
  // Unknown kind
  caught := false;
  try
    native.structType("Bad2", [["x", "unknown"]]);
  catch e do
    caught := true;
    println("  ✓ unknown kind rejected");
  end;
  assertTrue(caught, "unknown kind rejected");
  
  // Field tidak ada saat set
  var T := native.structType("Tiny", [["a", "i32"]]);
  var v := native.newStruct(T);
  caught := false;
  try
    native.structSet(v, "b", 1);
  catch e do
    caught := true;
    println("  ✓ missing field rejected");
  end;
  assertTrue(caught, "missing field rejected");
  
  // Invalid access setelah free
  caught := false;
  try
    native.structFree(v);
    native.structGet(v, "a");   // ← harus raise karena magic=0
  catch e do
    caught := true;
    println("  ✓ freed value rejected");
  end;
  assertTrue(caught, "freed value rejected");
  
  native.structTypeFree(T);
end;

function testStructPointerField() begin
  println("[S-5] pointer field (opaque)");
  
  var HolderType := native.structType("Holder", [
    ["data", "ptr"],
    ["size", "i64"]
  ]);
  
  var h := native.newStruct(HolderType);
  assertEqual(16, native.structSize(h), "Holder size");
  
  // Simpan dummy pointer
  var arr := [1, 2, 3];
  var buf := native.fromArray(arr);
  var dataPtr := native.bufferPtr(buf);
  
  native.structSet(h, "data", dataPtr);
  native.structSet(h, "size", 3);
  
  var recovered := native.structGet(h, "data");
  assertTrue(recovered <> null, "pointer recovered");
  println("  pointer field OK");
  
  native.structFree(h);
  native.structTypeFree(HolderType);
  native.bufferFree(buf);
end;

// ============================================================
begin
  println("=== F-3a-5a: Struct Test ===");
  println("");
  
  testStructBasic();
  println("--- S-1 done ---");
  
  testStructMixedTypes();
  println("--- S-2 done ---");
  
  testStructFloats();
  println("--- S-3 done ---");
  
  testStructErrors();
  println("--- S-4 done ---");
  
  testStructPointerField();
  println("--- S-5 done ---");
  
  println("");
  println("=== Selesai ===");
  println("Summary: failed = ", testSummary());
end.