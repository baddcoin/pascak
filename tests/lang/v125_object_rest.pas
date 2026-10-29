begin
  // 1-2: Basic obj rest
  var {a, b, ...rest} = {"a": 1, "b": 2, "c": 3, "d": 4};
  println("O1: a =", a);
  println("O2: b =", b);
  println("O3: rest.c =", rest.c);
  println("O4: rest.d =", rest.d);

  // 3: Only rest — all keys
  var {...all} = {"x": 10, "y": 20};
  println("O5: all.x =", all.x);
  println("O6: all.y =", all.y);

  // 4: Empty rest (all consumed) — check via key access
  var {p, q, ...empty} = {"p": 1, "q": 2};
  println("O7: p =", p);
  println("O8: q =", q);
  println("O9: empty.p =", empty.p);      // should be null (key omitted)

  // 5: Nested-then-rest
  var {cfg: {h}, ...rest2} = {"cfg": {"h": "localhost"}, "port": 8080, "debug": true};
  println("O10: h =", h);
  println("O11: rest2.port =", rest2.port);
  println("O12: rest2.debug =", rest2.debug);

  // 6: Statement-scope
  var {x, y, ...others} = {"x": 1, "y": 2, "z": 3, "w": 4};
  println("O13: x =", x);
  println("O14: others.z =", others.z);
  println("O15: others.w =", others.w);

  // ── Regression ──
  var [first, ...tail] = [10, 20, 30];
  println("R1: first =", first);
  println("R2: tail =", tail);

  var {m: {n: {o}}} = {"m": {"n": {"o": 42}}};
  println("R3: o =", o);
end.
