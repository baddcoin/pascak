enum Color { Red, Green, Blue }

begin
  println("1: Color.Red =", Color.Red);
  println("2: Color.Green =", Color.Green);
  println("3: Color.Blue =", Color.Blue);
  println("4: Color.Red + Color.Blue =", Color.Red + Color.Blue);
  var c := Color;
  println("5: alias c.Red =", c.Red);
end.
