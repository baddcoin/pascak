// Top-level destructure (ParseMainProgram) — sebelum begin
var {name, age} = {"name": "Alice", "age": 30};

begin
  println("1: name =", name);
  println("2: age =", age);

  // Statement-scope destructure (ParseStatement) — di dalam begin
  var {a, b} = {"a": 1, "b": 2};
  println("3: a =", a);
  println("4: b =", b);

  var [x, y, z] = [10, 20, 30];
  println("5: x =", x);
  println("6: z =", z);

  var {missing} = {"other": 1};
  println("7: missing =", missing);

  const {pi_val} = {"pi_val": 3.14};
  println("8: pi_val =", pi_val);
end.
