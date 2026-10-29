function f({a, b}) begin
  return a + b;
end;

function g([x, y]) begin
  return x + y;
end;

function h({cfg: {port}, u, v = 5}) begin
  return port + u + v;
end;

function two({x}, {y}) begin
  return x + y;
end;

function mixed(a, {b, c}, d) begin
  return a + b + c + d;
end;

begin
  println("f({a:1,b:2}) =", f({"a": 1, "b": 2}));
  println("g([10,20]) =", g([10, 20]));
  println("h(nested+default) =", h({"cfg": {"port": 80}, "u": 10}));
  println("two(patterns) =", two({"x": 100}, {"y": 200}));
  println("mixed(1,{b:2,c:3},4) =", mixed(1, {"b": 2, "c": 3}, 4));
end.
