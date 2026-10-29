begin
  // Regression: 1-level nested
  var {a: {b, c}} = {"a": {"b": 1, "c": 2}};
  println("L1: b =", b);      // 1
  println("L2: c =", c);      // 2

  // Regression: 2-level nested
  var {p: {q: {r, s}}} = {"p": {"q": {"r": 10, "s": 20}}};
  println("L3: r =", r);      // 10

  // New: 3-level nested
  var {m: {n: {o: {u, v}}}} = {"m": {"n": {"o": {"u": 100, "v": 200}}}};
  println("L4: u =", u);      // 100
  println("L5: v =", v);      // 200

  // New: 4-level nested
  var {w: {x: {y: {z: {q4}}}}} = {"w": {"x": {"y": {"z": {"q4": 999}}}}};
  println("L6: q4 =", q4);    // 999

  // 3-level with default
  var {d1: {d2: {d3 = 42, d4}}} = {"d1": {"d2": {"d4": 7}}};
  println("L7: d3 =", d3);    // 42
  println("L8: d4 =", d4);    // 7

  // Regression: flat + array + rest
  var {x1, y1} = {"x1": 5, "y1": 6};
  println("R1: x1 =", x1);    // 5
  var [f1, ...tl] = [100, 200, 300];
  println("R2: f1 =", f1);    // 100
  println("R3: tl =", tl);    // [200, 300]
end.
