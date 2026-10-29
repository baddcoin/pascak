begin
  // ── READ: non-null array ──
  var arr := [10, 20, 30];
  println("T1: arr?.[0] =", arr?.[0]);   // 10
  println("T2: arr?.[2] =", arr?.[2]);   // 30

  // ── READ: null ──
  var n := null;
  println("T3: n?.[0] =", n?.[0]);       // null

  // ── READ: nested (obj → arr → idx) ──
  var obj := {"list": [1, 2, 3]};
  println("T4: obj?.list?.[1] =", obj?.list?.[1]);    // 2

  var obj2 := {"list": null};
  println("T5: obj2?.list?.[0] =", obj2?.list?.[0]);  // null

  // ── WRITE: non-null array ──
  var arr2 := [10, 20, 30];
  arr2?.[0] := 99;
  println("T6: arr2[0] =", arr2[0]);     // 99

  // ── WRITE: null ──
  var n2 := null;
  n2?.[0] := 42;                          // no crash
  println("T7: passed (no crash on null assign)");

  // ── WRITE: side-effect (RHS not evaluated when null) ──
  var cnt := 0;
  function bump() begin
    cnt := cnt + 1;
    return 1;
  end;
  var n3 := null;
  n3?.[0] := bump();
  println("T8: cnt =", cnt);              // 0 (bump not called)

  var arr3 := [0];
  arr3?.[0] := bump();
  println("T9: cnt =", cnt);              // 1 (bump called)
  println("T10: arr3[0] =", arr3[0]);     // 1
end.
