function f({a, b, ...rest}) begin
  return a + b + rest.c + rest.d;
end;

function g([x, ...tail]) begin
  return x + len(tail);
end;

function h({cfg: {port, ...other}}) begin
  return port + other.host;
end;

function reg({x, y}) begin
  return x + y;
end;

begin
  println("f(obj rest) =", f({"a": 1, "b": 2, "c": 3, "d": 4}));       // 1+2+3+4=10
  println("g(arr rest) =", g([10, 20, 30, 40]));                        // 10+3=13
  println("h(nested rest) =", h({"cfg": {"port": 80, "host": 100}}));   // 80+100=180
  println("reg(no rest) =", reg({"x": 5, "y": 7}));                     // 12
end.
