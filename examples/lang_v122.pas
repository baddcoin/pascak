// examples/lang_v122.pas
// Pascak v1.2.2: nested destructuring (obj-root, 1-level)

var {app: {name, ver}} = {"app": {"name": "Pascak", "ver": "1.2.2"}};
var {coords: [x, y]} = {"coords": [100, 200]};

begin
  println("=== Nested Object ===");
  println("name = ", name);
  println("ver  = ", ver);

  println("");
  println("=== Nested Array ===");
  println("x    = ", x);
  println("y    = ", y);

  println("");
  println("=== Mixed Flat + Nested ===");
  var {user: {uid}, role} = {"user": {"uid": 42}, "role": "admin"};
  println("uid  = ", uid);
  println("role = ", role);

  println("");
  println("=== Multiple Nested ===");
  var {a: [p, q], b: {r, s}} = {"a": [1, 2], "b": {"r": 3, "s": 4}};
  println("p    = ", p);
  println("q    = ", q);
  println("r    = ", r);
  println("s    = ", s);

  println("");
  println("=== Nested with Default ===");
  var {cfg: {port = 8080, host = "localhost"}} = {"cfg": {}};
  println("host = ", host);
  println("port = ", port);

  println("");
  println("=== Nested + flat default mix ===");
  var {svc: {name2 = "api", retry = 3}, env} =
    {"svc": {"retry": 5}, "env": "prod"};
  println("name2 = ", name2);
  println("retry = ", retry);
  println("env   = ", env);
end.
