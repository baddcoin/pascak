// examples/lang_v123.pas
// Pascak v1.2.3: 2-level nested destructuring

begin
  println("=== Pure 2-Level ===");
  var {p: {q: {r, s}}} = {"p": {"q": {"r": 10, "s": 20}}};
  println("r = ", r);
  println("s = ", s);

  println("");
  println("=== Mixed 1+2 Level ===");
  var {u: {v}, w: {x: {y, z}}} =
    {"u": {"v": 100}, "w": {"x": {"y": 200, "z": 300}}};
  println("v = ", v);
  println("y = ", y);
  println("z = ", z);

  println("");
  println("=== 2-Level with Default ===");
  var {m: {n: {o = 42, p2}}} = {"m": {"n": {"p2": 7}}};
  println("o  = ", o);
  println("p2 = ", p2);

  println("");
  println("=== 2-Level + Array ===");
  var {cfg: {coords: [cx, cy]}} = {"cfg": {"coords": [1, 2]}};
  println("cx = ", cx);
  println("cy = ", cy);
end.
