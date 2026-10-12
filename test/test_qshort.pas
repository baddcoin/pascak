// ============================================================
// B-2: qsort Integration Test
//
// Validasi end-to-end F-3a dengan workload nyata:
//   - Native buffer (B-1) menyediakan int64[] linear
//   - Callback dispatch (F-3a-3) menyediakan comparator
//   - FFI signature pIp->v (F-2b) memanggil C function
// ============================================================

// Comparator ascending: -1 kalau a<b, 1 kalau a>b, 0 kalau sama
function cmpAscending(a, b) begin
  if a < b then return -1;
  if a > b then return 1;
  return 0
end;

function cmpDescending(a, b) begin
  if a > b then return -1;
  if a < b then return 1;
  return 0
end;

function testQSortAscending() begin
  println("[B-2a] qsort ascending");
  
  var lib := dll.load("libpascak_ffi_test.so");
  var qsortFn := lib.func("pascak_qsort_ints", "pip->v");  
  
  var arr := [42, 17, 93, 8, 56, 3, 71, 25, 88, 12];
  println("  before: ", arr);
  
  var buf := native.fromArray(arr);
  var cmpAsc := dll.callback("ii->i", cmpAscending);
  
  qsortFn(native.bufferPtr(buf), native.bufferSize(buf), cmpAsc);
  
  var sorted := native.bufferToArray(buf);
  println("  after:  ", sorted);
  
  assertEqual(10, len(sorted), "length preserved");
  assertEqual(3,  sorted[0], "sorted[0]");
  assertEqual(8,  sorted[1], "sorted[1]");
  assertEqual(12, sorted[2], "sorted[2]");
  assertEqual(17, sorted[3], "sorted[3]");
  assertEqual(25, sorted[4], "sorted[4]");
  assertEqual(42, sorted[5], "sorted[5]");
  assertEqual(56, sorted[6], "sorted[6]");
  assertEqual(71, sorted[7], "sorted[7]");
  assertEqual(88, sorted[8], "sorted[8]");
  assertEqual(93, sorted[9], "sorted[9]");
  
  dll.freeCallback(cmpAsc);
  native.bufferFree(buf);
  lib.close();
end;

function testQSortDescending() begin
  println("[B-2b] qsort descending (custom comparator)");
  
  var lib := dll.load("libpascak_ffi_test.so");
  var qsortFn := lib.func("pascak_qsort_ints", "pIp->v");
  
  var arr := [10, 50, 30, 70, 20, 90, 40];
  println("  before: ", arr);
  
  var buf := native.fromArray(arr);
  var cmpDesc := dll.callback("ii->i", cmpDescending);
  
  qsortFn(native.bufferPtr(buf), native.bufferSize(buf), cmpDesc);
  
  var sorted := native.bufferToArray(buf);
  println("  after:  ", sorted);
  
  assertEqual(90, sorted[0], "sorted[0]");
  assertEqual(70, sorted[1], "sorted[1]");
  assertEqual(50, sorted[2], "sorted[2]");
  assertEqual(40, sorted[3], "sorted[3]");
  assertEqual(30, sorted[4], "sorted[4]");
  assertEqual(20, sorted[5], "sorted[5]");
  assertEqual(10, sorted[6], "sorted[6]");
  
  dll.freeCallback(cmpDesc);
  native.bufferFree(buf);
  lib.close();
end;

function testQSortBubbleSort() begin
  println("[B-2c] bubble sort — cross-check");
  
  var lib := dll.load("libpascak_ffi_test.so");
  var bubbleFn := lib.func("pascak_bubble_sort_ints", "pip->v");
  
  var arr := [5, 2, 8, 1, 9, 3];
  var buf := native.fromArray(arr);
  var cmpAsc := dll.callback("ii->i", cmpAscending);
  
  bubbleFn(native.bufferPtr(buf), native.bufferSize(buf), cmpAsc);
  
  var sorted := native.bufferToArray(buf);
  println("  sorted: ", sorted);
  
  assertEqual(1, sorted[0], "s[0]");
  assertEqual(2, sorted[1], "s[1]");
  assertEqual(3, sorted[2], "s[2]");
  assertEqual(5, sorted[3], "s[3]");
  assertEqual(8, sorted[4], "s[4]");
  assertEqual(9, sorted[5], "s[5]");
  
  dll.freeCallback(cmpAsc);
  native.bufferFree(buf);
  lib.close();
end;

// Helper untuk callback yang selalu return 1
function cbAlwaysOne(x) begin
  return 1
end;

function testCallbackInvocationCount() begin
  println("[B-2d] banyak invocation callback (metrics)");
  
  var lib := dll.load("libpascak_ffi_test.so");
  var countFn := lib.func("pascak_count_calls", "pIp->i");
  
  // Array 100 elemen
  var arr := [];
  var i := 0;
  while i < 100 do
  begin
    push(arr, i);
    i := i + 1;
  end;
  
  var buf := native.fromArray(arr);
  var cb := dll.callback("i->i", cbAlwaysOne);
  var count := countFn(native.bufferPtr(buf), native.bufferSize(buf), cb);
  
  println("  count = ", count);
  assertEqual(100, count, "semua 100 elemen dihitung");
  
  dll.freeCallback(cb);
  native.bufferFree(buf);
  lib.close();
end;

function testQSortEmptyAndSingle() begin
  println("[B-2e] edge cases — empty dan single");
  
  var lib := dll.load("libpascak_ffi_test.so");
  var qsortFn := lib.func("pascak_qsort_ints", "pip->v");
  var cmpAsc := dll.callback("ii->i", cmpAscending);
  
  // Empty
  var empty := [];
  var bufE := native.fromArray(empty);
  qsortFn(native.bufferPtr(bufE), native.bufferSize(bufE), cmpAsc);
  var sortedE := native.bufferToArray(bufE);
  assertEqual(0, len(sortedE), "empty preserved");
  println("  ✓ empty array OK");
  native.bufferFree(bufE);
  
  // Single element
  var single := [42];
  var bufS := native.fromArray(single);
  qsortFn(native.bufferPtr(bufS), native.bufferSize(bufS), cmpAsc);
  var sortedS := native.bufferToArray(bufS);
  assertEqual(1, len(sortedS), "single preserved");
  assertEqual(42, sortedS[0], "single value preserved");
  println("  ✓ single element OK");
  native.bufferFree(bufS);
  
  dll.freeCallback(cmpAsc);
  lib.close();
end;

// ============================================================
begin
  println("=== B-2: qsort Integration Test ===");
  println("");
  
  testQSortAscending();
  println("--- B-2a done ---");
  
  testQSortDescending();
  println("--- B-2b done ---");
  
  testQSortBubbleSort();
  println("--- B-2c done ---");
  
  testCallbackInvocationCount();
  println("--- B-2d done ---");
  
  testQSortEmptyAndSingle();
  println("--- B-2e done ---");
  
  println("");
  println("=== Selesai ===");
  println("Summary: failed = ", testSummary());
end.