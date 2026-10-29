begin
  // ── Regression v1.2.5 root cases ──
  var {a, b, ...rest} = {"a": 1, "b": 2, "c": 3, "d": 4};
  println("R1: a =", a);
  println("R2: rest.c =", rest.c);

  var [p, ...q] = [10, 20, 30];
  println("R3: p =", p);
  println("R4: q =", q);

  // ── New: obj-nested rest 1-level ──
  var {cfg: {host, ...cfg_rest}} =
    {"cfg": {"host": "h", "port": 80, "user": "u"}};
  println("N1: host =", host);
  println("N2: cfg_rest.port =", cfg_rest.port);
  println("N3: cfg_rest.user =", cfg_rest.user);
  println("N4: cfg_rest.host =", cfg_rest.host);   // null (excluded)

  // ── New: 2-level nested rest ──
  var {a2: {b2: {x, ...deep_r}}} =
    {"a2": {"b2": {"x": 100, "y": 200, "z": 300}}};
  println("N5: x =", x);
  println("N6: deep_r.y =", deep_r.y);
  println("N7: deep_r.z =", deep_r.z);

  // ── New: array-nested in obj + rest ──
  var {cfg2: {items, ...cfg2_rest}} =
    {"cfg2": {"items": [1, 2], "keep": true}};
  println("N8: items =", items);
  println("N9: cfg2_rest.keep =", cfg2_rest.keep);

  // ── New: obj-nested in arr + rest ──
  var [first, {u, ...v}, last] = [10, {"u": 20, "w": 30}, 40];
  println("N10: first =", first);
  println("N11: u =", u);
  println("N12: v.w =", v.w);
  println("N13: last =", last);

  // ── Regression flat nested ──
  var {m: {n: {o}}} = {"m": {"n": {"o": 42}}};
  println("R5: o =", o);
end.
