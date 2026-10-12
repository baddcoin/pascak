// ═══════════════════════════════════════════════════════════════
//  Fase 1.2: Engine Destruction Robustness
// ═══════════════════════════════════════════════════════════════

begin
  testBegin("Fase 1.2 - Engine Destruction Robustness");

  // ─── [1] eval() loop sederhana ───
  var i := 0;
  while i < 500 do begin
    eval("begin end.");
    i := i + 1;
  end;
  assertTrue(i == 500, "500 eval kosong selesai");

  // ─── [2] eval() dengan function (cycle risk) ───
  i := 0;
  while i < 200 do begin
    var nm := "f_" + str(i);
    eval("function " + nm + "() begin return 42 end; begin " + nm + "(); end.");
    i := i + 1;
  end;
  assertTrue(i == 200, "200 eval function selesai");

  // ─── [3] eval() nested function ───
  i := 0;
  while i < 100 do begin
    var nm := "outer_" + str(i);
    eval("function " + nm + "() begin function inner_() begin return 1 end; return inner_() end; begin " + nm + "(); end.");
    i := i + 1;
  end;
  assertTrue(i == 100, "100 eval nested function selesai");

  // ─── [4] eval() recursive ───
  i := 0;
  while i < 100 do begin
    var nm := "fact_" + str(i);
    eval("function " + nm + "(n) begin if n <= 1 then return 1; return n * " + nm + "(n - 1) end; begin " + nm + "(5); end.");
    i := i + 1;
  end;
  assertTrue(i == 100, "100 eval recursive selesai");

  // ─── [5] Verifikasi return value eksplisit ───
  // `return` di top-level di-emit sebagai opcReturn → Result di-set
  var r := eval("begin return 6 * 7; end.");
  assertEqual(r, 42, "eval return value correctly");

  println("  semua loop selesai tanpa crash");
  testEnd();
end.