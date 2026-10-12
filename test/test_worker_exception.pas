begin
  testBegin("Fase 1.5 - Worker Exception Propagation");

  // ─── [1] Worker crash harus set marker ───
  var Received := false;
  var WasCrash := false;
  var WasKind := "";
  var WasError := "";

  var dummy := poolRun(
    lambda : begin
      throw("boom from worker");
    end,
    null,
    lambda res : begin
      Received := true;
      if res.hasKey("__worker_crash") then
      begin
        WasCrash := true;
        WasKind := res["__worker_kind"];
        WasError := res["error"];
      end;
    end
  );

  var W := 0;
  while (not Received) and (W < 200) do begin
    sleep(10);
    W := W + 1;
  end;

  assertTrue(Received, "callback crash harus terpanggil");
  assertTrue(WasCrash, "harus ada marker __worker_crash");
  assertTrue(len(WasKind) > 0, "harus ada __worker_kind");
  assertTrue(len(WasError) > 0, "harus ada error message");

  println("  crash kind : ", WasKind);
  println("  error msg  : ", WasError);

  // ─── [2] Worker sukses TIDAK boleh set marker ───
  var Received2 := false;
  var Crashed2 := false;
  var Value2 := null;

  var dummy2 := poolRun(
    lambda : 42,
    null,
    lambda res : begin
      Received2 := true;
      // ✅ defensif: cek tipe dulu
      if typeOf(res) == "dictionary" then
      begin
        if res.hasKey("__worker_crash") then
          Crashed2 := true;
      end;
      Value2 := res;
    end
  );

  W := 0;
  while (not Received2) and (W < 200) do begin
    sleep(10);
    W := W + 1;
  end;

  assertTrue(Received2, "callback sukses harus terpanggil");
  assertFalse(Crashed2, "sukses tidak boleh ada marker crash");
  assertEqual(Value2, 42, "return value harus intact");

  testEnd();
end.