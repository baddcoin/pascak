// 100K arithmetic iterations
begin
  var i := 0;
  var sum := 0.0;
  while i < 100000 do
  begin
    sum := sum + (i * 2) - (i / 3);
    i := i + 1;
  end;
  println("sum =", sum);
end.
