var gCnt := 0;

function bump() begin
  gCnt := gCnt + 1;
  return 1;
end;

begin
  var o := {"x": 1};
  o?.x := 42;
  println("T1: o.x =", o.x);

  var n := null;
  n?.x := 99;
  println("T2: passed (no crash)");

  var cfg := {"db": null};
  cfg?.db?.host := "localhost";
  println("T3: passed (no crash)");

  var cfg2 := {"db": {"host": "old"}};
  cfg2?.db?.host := "new";
  println("T4: cfg2.db.host =", cfg2.db.host);

  var nn := null;
  nn?.y := bump();
  println("T5: gCnt =", gCnt);

  var o2 := {"y": 0};
  o2?.y := bump();
  println("T6: gCnt =", gCnt);
  println("T6: o2.y =", o2.y);
end.
