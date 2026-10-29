begin
  var n := null;
  println("1: n?.name =", n?.name);

  var u := {"name": "Alice"};
  println("2: u?.name =", u?.name);

  var c := {"db": null};
  println("3: c?.db?.host =", c?.db?.host);

  var d := {"db": {"host": "localhost"}};
  println("4: d?.db?.host =", d?.db?.host);

  var m := null;
  println("5: m?.name ?? fallback =", m?.name ?? "fallback");

  println("6: null ?? 42 =", null ?? 42);
  println("7: 0 ?? 42 =", 0 ?? 42);
  println("8: false ?? 42 =", false ?? 42);
end.
