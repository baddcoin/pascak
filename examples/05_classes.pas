// Class, inheritance, methods

class Animal begin
  var name := "";
  var sound := "";
  
  function create(n) begin
    self.name := n;
  end;
  
  function speak() begin
    return self.name + " says " + self.sound;
  end;
end;

class Dog(Animal) begin
  function create(n) begin
    self.name := n;
    self.sound := "Woof";
  end;
end;

class Cat(Animal) begin
  function create(n) begin
    self.name := n;
    self.sound := "Meow";
  end;
  
  function purr() begin
    return self.name + " purrs";
  end;
end;

// Record (value type, no methods)
record Point begin
  x;
  y;
end;

begin
  var d := new Dog("Rex");
  var c := new Cat("Whiskers");
  
  println(d.speak());
  println(c.speak());
  println(c.purr());
  
  // Record
  var p := new Point();
  p.x := 3;
  p.y := 4;
  var dist := math.sqrt(p.x * p.x + p.y * p.y);
  println("Point distance: ", dist);
  
  // isInstance check
  println("d is Dog? ", isInstance(d, "Dog"));
  println("d is Animal? ", isInstance(d, "Animal"));
  println("d is Cat? ", isInstance(d, "Cat"));
end.