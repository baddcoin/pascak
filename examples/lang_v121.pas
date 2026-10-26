// examples/lang_v121.pas
// Pascak v1.2.1: array rest element

begin
  println("=== Array Rest ===");
  var [first, ...tail] = [10, 20, 30, 40];
  println("first = ", first);
  println("tail  = ", tail);

  println("");
  println("Only rest:");
  var [...all] = [5, 6, 7];
  println("all   = ", all);

  println("");
  println("Multi leading + rest:");
  var [a, b, ...rest] = [1, 2, 3, 4, 5];
  println("a     = ", a);
  println("b     = ", b);
  println("rest  = ", rest);

  println("");
  println("Short array (empty slice):");
  var [x, ...tail2] = [100];
  println("x     = ", x);
  println("tail2 = ", tail2);

  println("");
  println("Regression (no rest):");
  var [p, q] = [1, 2];
  println("p     = ", p);
  println("q     = ", q);
end.
