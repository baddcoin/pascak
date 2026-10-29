// ── Phase A1: Default values (top-level) ──
var {a = 10, b = 20} = {"a": 1};
var [x = 0, y = 100] = [42];
var {c = 99} = {};
var {d = 99, e = 99} = {"d": 0, "e": ""};

// ── Phase A2: Enum in function scope ──
function getOK() begin
  enum S { OK, ERR }
  return S.OK;
end;

function getC() begin
  enum S2 { A, B, C }
  return S2.C;
end;

begin
  println("1: a =", a);       // 1
  println("2: b =", b);       // 20
  println("3: x =", x);       // 42
  println("4: y =", y);       // 100
  println("5: c =", c);       // 99
  println("6: d =", d);       // 0 (0 bukan null)
  println("7: e =", e);       // (empty string, bukan null)
  println("8: getOK =", getOK());   // 0
  println("9: getC =", getC());     // 2

  // Enum in statement-scope
  enum Local { L0, L1, L2 }
  println("10: L2 =", Local.L2);    // 2
end.
