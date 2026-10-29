begin
  var {a: {b, c}} = {"a": {"b": 1, "c": 2}};
  println("L1: b =", b);
  println("L2: c =", c);

  var {p: {q: {r, s}}} = {"p": {"q": {"r": 10, "s": 20}}};
  println("L3: r =", r);
  println("L4: s =", s);

  var {u: {v}, w: {x: {y, z}}} =
    {"u": {"v": 100}, "w": {"x": {"y": 200, "z": 300}}};
  println("L5: v =", v);
  println("L6: y =", y);
  println("L7: z =", z);

  var {m: {n: {o = 42, p2}}} = {"m": {"n": {"p2": 7}}};
  println("L8: o =", o);
  println("L9: p2 =", p2);

  var {cfg: {coords: [cx, cy]}} = {"cfg": {"coords": [1, 2]}};
  println("L10: cx =", cx);
  println("L11: cy =", cy);

  var {x1, y1} = {"x1": 5, "y1": 6};
  println("R1: x1 =", x1);

  var [a1, ...tail1] = [100, 200, 300];
  println("R2: a1 =", a1);
  println("R3: tail1 =", tail1);
end.
