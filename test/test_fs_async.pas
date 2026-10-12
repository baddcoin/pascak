// ═══════════════════════════════════════════════════════════════
//  Fase 1.3: Async File I/O
// ═══════════════════════════════════════════════════════════════

begin
  testBegin("Fase 1.3 - Async File I/O");

  // ─── [1] writeAsync → waitAsync ───
  var wID := fs.writeAsync("test_async_out.txt", "Hello async!");
  assertTrue(wID > 0, "writeAsync return taskID");

  var wRes := fs.waitAsync(wID, 5000);
  assertTrue(wRes != null, "waitAsync result not null");
  if wRes != null then begin
    assertTrue(wRes["ok"], "writeAsync ok");
    assertEqual(wRes["bytesWritten"], 12, "12 bytes written");
  end;
  fs.freeAsync(wID);

  // ─── [2] readAsync → waitAsync ───
  var rID := fs.readAsync("test_async_out.txt");
  assertTrue(rID > 0, "readAsync return taskID");

  var rRes := fs.waitAsync(rID, 5000);
  assertTrue(rRes != null, "readAsync result not null");
  if rRes != null then begin
    assertTrue(rRes["ok"], "readAsync ok");
    assertEqual(rRes["bytesRead"], 12, "12 bytes read");
    assertEqual(rRes["data"], "Hello async!", "content match");
  end;
  fs.freeAsync(rID);

  // ─── [3] appendAsync ───
  var aID := fs.appendAsync("test_async_out.txt", " more");
  var aRes := fs.waitAsync(aID, 5000);
  assertTrue(aRes != null, "appendAsync result");
  if aRes != null then
    assertTrue(aRes["ok"], "appendAsync ok");
  fs.freeAsync(aID);

  // Verify appended content
  var rID2 := fs.readAsync("test_async_out.txt");
  var rRes2 := fs.waitAsync(rID2, 5000);
  assertEqual(rRes2["data"], "Hello async! more", "appended content");
  fs.freeAsync(rID2);

  // ─── [4] readAsync non-existent → ok:false ───
  var eID := fs.readAsync("does_not_exist_xyz.txt");
  var eRes := fs.waitAsync(eID, 5000);
  assertTrue(eRes != null, "error result");
  if eRes != null then
    assertFalse(eRes["ok"], "non-existent file → ok:false");
  fs.freeAsync(eID);

  // ─── [5] callback mode (auto-free) ───
  var CBReceived := false;
  var CBBytes := 0;

  var cID := fs.writeAsync("test_cb.txt", "callback test",
    lambda r : begin
      CBReceived := true;
      CBBytes := r["bytesWritten"];
    end);

  var W := 0;
  while (not CBReceived) and (W < 100) do begin
    sleep(20);
    W := W + 1;
  end;

  assertTrue(CBReceived, "callback fired");
  assertEqual(CBBytes, 13, "13 bytes via callback");
  // Auto-free — tidak perlu fs.freeAsync

  // ─── [6] Large file (1 MB) ───
  var BigData := "";
  var i := 0;
  while i < 10000 do begin
    BigData := BigData + "0123456789";
    i := i + 1;
  end;

  var bigW := fs.writeAsync("test_big.txt", BigData);
  var bigWRes := fs.waitAsync(bigW, 10000);
  assertEqual(bigWRes["bytesWritten"], 100000, "100 KB written");
  fs.freeAsync(bigW);

  var bigR := fs.readAsync("test_big.txt");
  var bigRRes := fs.waitAsync(bigR, 10000);
  assertEqual(bigRRes["bytesRead"], 100000, "100 KB read");
  assertEqual(len(bigRRes["data"]), 100000, "content length match");
  fs.freeAsync(bigR);

  // Cleanup
  fileDelete("test_async_out.txt");
  fileDelete("test_cb.txt");
  fileDelete("test_big.txt");

  testEnd();
end.