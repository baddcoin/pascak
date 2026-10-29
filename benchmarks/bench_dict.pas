// 100K dict set + get
begin
  var d := {};
  var i := 0;
  while i < 100000 do
  begin
    d[str(i)] := i;
    i := i + 1;
  end;
  var sum := 0;
  i := 0;
  while i < 100000 do
  begin
    sum := sum + d[str(i)];
    i := i + 1;
  end;
  println("dict sum =", sum);
end.
