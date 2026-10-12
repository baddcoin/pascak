// ============================================================
// F-3a-5b: ffi_type Construction Test
// ============================================================

function testFFITypePoint() begin
  println("[F-1] ffi_type untuk Point {i32,i32}");
  
  var PointType := native.structType("Point", [
    ["x", "i32"],
    ["y", "i32"]
  ]);
  
  var info := native.structFFITypeInfo(PointType);
  println("  name         = ", info.name);
  println("  totalSize    = ", info.totalSize);
  println("  maxAlignment = ", info.maxAlignment);
  println("  ffiTypeNonNull = ", info.ffiTypeNonNull);
  println("  elementCount = ", info.elementCount);
  println("  ffiSize      = ", info.ffiSize);
  println("  ffiAlignment = ", info.ffiAlignment);
  println("  ffiTypeTag   = ", info.ffiTypeTag);
  
  assertEqual("Point", info.name, "name");
  assertEqual(8, info.totalSize, "totalSize");
  assertEqual(4, info.maxAlignment, "maxAlignment");
  assertEqual(true, info.ffiTypeNonNull, "ffiType allocated");
  assertEqual(2, info.elementCount, "elementCount");
  assertEqual(8, info.ffiSize, "ffi size");
  assertEqual(4, info.ffiAlignment, "ffi alignment");
  assertEqual(13, info.ffiTypeTag, "ffi type = FFI_TYPE_STRUCT");
  
  native.structTypeFree(PointType);
end;

function testFFITypeEntry() begin
  println("[F-2] ffi_type untuk Entry {i64,f64,bool,i32}");
  
  var EntryType := native.structType("Entry", [
    ["id", "i64"],
    ["score", "f64"],
    ["active", "bool"],
    ["rank", "i32"]
  ]);
  
  var info := native.structFFITypeInfo(EntryType);
  println("  totalSize    = ", info.totalSize, "  (harus 24)");
  println("  maxAlignment = ", info.maxAlignment, "  (harus 8)");
  println("  elementCount = ", info.elementCount, "  (harus 4)");
  println("  ffiTypeTag   = ", info.ffiTypeTag, "  (harus 13)");
  
  assertEqual(24, info.totalSize, "totalSize");
  assertEqual(8, info.maxAlignment, "maxAlignment");
  assertEqual(4, info.elementCount, "elementCount");
  assertEqual(13, info.ffiTypeTag, "FFI_TYPE_STRUCT");
  
  native.structTypeFree(EntryType);
end;

function testFFITypeVec3() begin
  println("[F-3] ffi_type untuk Vec3 {f32,f32,f32}");
  
  var Vec3Type := native.structType("Vec3", [
    ["x", "f32"],
    ["y", "f32"],
    ["z", "f32"]
  ]);
  
  var info := native.structFFITypeInfo(Vec3Type);
  assertEqual(12, info.totalSize, "Vec3 size");
  assertEqual(4, info.maxAlignment, "align");
  assertEqual(3, info.elementCount, "elements");
  assertEqual(13, info.ffiTypeTag, "tag");
  
  println("  ✓ Vec3 = 12 byte, align 4");
  native.structTypeFree(Vec3Type);
end;

function testFFITypeMixed() begin
  println("[F-4] ffi_type untuk Mixed {ptr, i8, i16, i64}");
  
  var MixedType := native.structType("Mixed", [
    ["p", "ptr"],
    ["a", "i8"],
    ["b", "i16"],
    ["c", "i64"]
  ]);
  
  var info := native.structFFITypeInfo(MixedType);
  // Layout: ptr di offset 0, i8 di offset 8, i16 di offset 10, i64 di offset 16
  // Total: 24 byte (align 8)
  println("  size = ", info.totalSize, "  (harus 24)");
  println("  align = ", info.maxAlignment, "  (harus 8)");
  
  assertEqual(24, info.totalSize, "Mixed size");
  assertEqual(8, info.maxAlignment, "Mixed align");
  assertEqual(4, info.elementCount, "elements");
  
  native.structTypeFree(MixedType);
end;

// ============================================================
begin
  println("=== F-3a-5b: ffi_type Construction Test ===");
  println("");
  
  testFFITypePoint();
  println("--- F-1 done ---");
  
  testFFITypeEntry();
  println("--- F-2 done ---");
  
  testFFITypeVec3();
  println("--- F-3 done ---");
  
  testFFITypeMixed();
  println("--- F-4 done ---");
  
  println("");
  println("=== Selesai ===");
  println("Summary: failed = ", testSummary());
end.