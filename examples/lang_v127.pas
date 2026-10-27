// examples/lang_v127.pas
// Pascak v1.2.7: optional method call ?.()

begin
  println("=== Basic ?.() ===");
  var d := {"name": "Alice", "age": 30};
  println("hasKey name = ", d?.hasKey("name"));
  println("hasKey zzz  = ", d?.hasKey("zzz"));

  println("");
  println("=== Null Target -> null ===");
  var n := null;
  println("n?.hasKey('x') = ", n?.hasKey("x"));

  println("");
  println("=== Chain Property + Method ===");
  var cfg := {"db": {"x": 1, "y": 2}};
  println("cfg?.db?.hasKey('x') = ", cfg?.db?.hasKey("x"));
  println("cfg?.db?.hasKey('z') = ", cfg?.db?.hasKey("z"));

  var cfg2 := {"db": null};
  println("cfg2?.db?.hasKey('x') = ", cfg2?.db?.hasKey("x"));

  println("");
  println("=== Short-Circuit Args Proof ===");
  var r := n?.hasKey(n.undefined());
  println("n?.hasKey(n.undefined()) = ", r);
  println("(args were short-circuited — no crash)");

  println("");
  println("=== Regression ===");
  println("d.hasKey('name')    = ", d.hasKey("name"));
  println("n?.missing_prop     = ", n?.missing_prop);
end.
