// examples/lang_v124.pas
// Pascak v1.2.4: arbitrary depth + array-root nested

begin
  println("=== 3+ Level Object ===");
  var {m: {n: {o: {u, v}}}} =
    {"m": {"n": {"o": {"u": 100, "v": 200}}}};
  println("u = ", u);
  println("v = ", v);

  println("");
  println("=== Array-Root Nested Obj ===");
  var [a, {u2, v2}, c] = [10, {"u2": 20, "v2": 30}, 40];
  println("a  = ", a);
  println("u2 = ", u2);
  println("v2 = ", v2);
  println("c  = ", c);

  println("");
  println("=== Array-in-Array ===");
  var [p, [q, r], s] = [1, [2, 3], 4];
  println("p = ", p);
  println("q = ", q);
  println("r = ", r);
  println("s = ", s);

  println("");
  println("=== Array Nested + Rest ===");
  var [mm, {nn}, ...rest] = [100, {"nn": 200}, 300, 400];
  println("mm   = ", mm);
  println("nn   = ", nn);
  println("rest = ", rest);

  println("");
  println("=== Array + 2-Level Obj ===");
  var [x, {cfg: {h, pt}}] = [1, {"cfg": {"h": "host", "pt": 8080}}];
  println("x  = ", x);
  println("h  = ", h);
  println("pt = ", pt);
end.
