// examples/lang_v126.pas
// Pascak v1.2.6: rest in nested destructuring

begin
  println("=== Nested Obj + Rest ===");
  var {cfg: {host, ...cfg_rest}} =
    {"cfg": {"host": "prod.example.com", "port": 443, "user": "admin"}};
  println("host          = ", host);
  println("cfg_rest.port = ", cfg_rest.port);
  println("cfg_rest.user = ", cfg_rest.user);

  println("");
  println("=== 2-Level Nested + Rest ===");
  var {a: {b: {x, ...deep}}} =
    {"a": {"b": {"x": 100, "y": 200, "z": 300}}};
  println("x        = ", x);
  println("deep.y   = ", deep.y);
  println("deep.z   = ", deep.z);

  println("");
  println("=== Array + Nested + Rest ===");
  var [first, {u, ...v}, last] = [10, {"u": 20, "w": 30}, 40];
  println("first = ", first);
  println("u     = ", u);
  println("v.w   = ", v.w);
  println("last  = ", last);

  println("");
  println("=== Array-Nested in Obj + Rest ===");
  var {cfg2: {items, ...others}} =
    {"cfg2": {"items": [1, 2, 3], "keep": true, "hint": "x"}};
  println("items       = ", items);
  println("others.keep = ", others.keep);
  println("others.hint = ", others.hint);

  println("");
  println("=== Sibling Isolation Test ===");
  var {a2: {x2, ...r2}, b2} = {"a2": {"x2": 1, "y2": 2}, "b2": 3};
  println("x2      = ", x2);
  println("b2      = ", b2);
  println("r2.y2   = ", r2.y2);
end.
