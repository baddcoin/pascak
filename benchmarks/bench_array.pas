// 10K array push + sum — arrMax = 10000 engine limit
begin
  var arr := [];
  var i := 0;
  while i < 10000 do
  begin
    arr.push(i);
    i := i + 1;
  end;
  var sum := 0;
  for x in arr do sum := sum + x;
  println("array sum =", sum, " len =", len(arr));
end.
