// ============================================================
// B-1: Native Buffer Lifecycle Test
// ============================================================

function testBufferBasic() begin
  println("[B-1a] buffer basic lifecycle");
  
  var arr := [42, 17, 93, 8, 56];
  println("  source arr = ", arr);
  
  var buf := native.fromArray(arr);
  assertTrue(buf <> null, "buffer created");
  println("  buf type = ", typeOf(buf));
  
  var sz := native.bufferSize(buf);
  println("  size = ", sz);
  assertEqual(5, sz, "size matches");
  
  var dataPtr := native.bufferPtr(buf);
  assertTrue(dataPtr <> null, "data ptr non-null");
  println("  data ptr = ", typeOf(dataPtr));
  
  var freed := native.bufferFree(buf);
  assertTrue(freed, "buffer freed");
  println("  ✓ lifecycle complete");
end;

function testBufferRoundTrip() begin
  println("[B-1b] buffer round-trip");
  
  var arr := [100, 200, 300, 400];
  var buf := native.fromArray(arr);
  var back := native.bufferToArray(buf);
  
  println("  original = ", arr);
  println("  roundtrip = ", back);
  
  assertEqual(4, len(back), "length matches");
  assertEqual(100, back[0], "back[0]");
  assertEqual(200, back[1], "back[1]");
  assertEqual(300, back[2], "back[2]");
  assertEqual(400, back[3], "back[3]");
  
  native.bufferFree(buf);
  println("  ✓ round-trip verified");
end;

function testBufferEdgeCases() begin
  println("[B-1c] edge cases");
  
  // Empty array
  var empty := [];
  var bufEmpty := native.fromArray(empty);
  assertTrue(bufEmpty <> null, "empty buffer created");
  assertEqual(0, native.bufferSize(bufEmpty), "empty size");
  native.bufferFree(bufEmpty);
  println("  ✓ empty array OK");
  
  // Non-numeric elements → coerced to 0
  var mixed := [1, "text", 3, null, 5];
  var bufMixed := native.fromArray(mixed);
  assertEqual(5, native.bufferSize(bufMixed), "mixed size");
  var back := native.bufferToArray(bufMixed);
  assertEqual(1, back[0], "back[0]=1");
  assertEqual(0, back[1], "back[1]=0 (non-numeric)");
  assertEqual(3, back[2], "back[2]=3");
  assertEqual(0, back[3], "back[3]=0 (null)");
  assertEqual(5, back[4], "back[4]=5");
  native.bufferFree(bufMixed);
  println("  ✓ mixed types coerced to 0");
end;

function testBufferInvalidAccess() begin
  println("[B-1d] invalid access protection");
  
  var arr := [1, 2, 3];
  var buf := native.fromArray(arr);
  native.bufferFree(buf);
  
  // Double-free → harus return false, tidak crash
  var refreed := native.bufferFree(buf);
  assertTrue(not refreed, "double-free prevented");
  println("  ✓ double-free safely rejected");
  
  // Access freed buffer → harus raise error, tidak crash
  var caught := false;
  try
    var _ := native.bufferSize(buf);
  catch e do
    caught := true;
    println("  correctly rejected: ", e.message);
  end;
  assertTrue(caught, "freed buffer access rejected");
end;

// ============================================================
begin
  println("=== B-1: Native Buffer Test ===");
  println("");
  
  testBufferBasic();
  println("--- B-1a done ---");
  
  testBufferRoundTrip();
  println("--- B-1b done ---");
  
  testBufferEdgeCases();
  println("--- B-1c done ---");
  
  testBufferInvalidAccess();
  println("--- B-1d done ---");
  
  println("");
  println("=== Selesai ===");
  println("Summary: failed = ", testSummary());
end.