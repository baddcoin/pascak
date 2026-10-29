var [a1, {u1, v1}, c1] = [10, {"u1": 20, "v1": 30}, 40];

begin
  println("A1: a1 =", a1);
  println("A2: u1 =", u1);
  println("A3: v1 =", v1);
  println("A4: c1 =", c1);

  var [p, [q, r], s] = [1, [2, 3], 4];
  println("A5: p =", p);
  println("A6: q =", q);
  println("A7: r =", r);
  println("A8: s =", s);

  var [m, {n}, ...rest] = [100, {"n": 200}, 300, 400];
  println("A9: m =", m);
  println("A10: n =", n);
  println("A11: rest =", rest);

  var [x, {cfg: {h, pt}}] = [1, {"cfg": {"h": "host", "pt": 8080}}];
  println("A12: x =", x);
  println("A13: h =", h);
  println("A14: pt =", pt);

  var {fx, fy} = {"fx": 5, "fy": 6};
  println("R1: fx =", fx);
  var [af, ...atl] = [10, 20, 30];
  println("R2: af =", af);
  println("R3: atl =", atl);
  var {n1: {n2: {n3}}} = {"n1": {"n2": {"n3": 42}}};
  println("R4: n3 =", n3);
end.
