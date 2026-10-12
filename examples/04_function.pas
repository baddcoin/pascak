// Named functions, default parameter, lambda, closure

function add(a, b) begin
  return a + b;
end;

function greet(name, greeting := "Halo") begin
  return greeting + ", " + name;
end;

function factorial(n) begin
  if n <= 1 then return 1;
  return n * factorial(n - 1);
end;

// Lambda
var double := lambda x : x * 2;
var square := lambda x : x * x;

// Lambda dengan block body
var process := lambda x : begin
  var y := x + 10;
  var z := y * 2;
  return z;
end;

// Closure counter
function makeCounter() begin
  var count := 0;
  return lambda : begin
    count += 1;
    return count;
  end;
end;

begin
  println("add(3, 4) = ", add(3, 4));
  println(greet("Alice"));
  println(greet("Bob", "Hi"));
  println("factorial(5) = ", factorial(5));
  
  println("double(21) = ", double(21));
  println("square(7) = ", square(7));
  println("process(5) = ", process(5));
  
  var counter := makeCounter();
  println("counter() = ", counter());  // 1
  println("counter() = ", counter());  // 2
  println("counter() = ", counter());  // 3
end.