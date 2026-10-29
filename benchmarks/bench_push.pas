// 10K push only (arrMax = 10000)
begin
  var arr := [];
  var i := 0;
  while i < 10000 do
  begin
    arr.push(i);
    i := i + 1;
  end;
  println("len =", len(arr));
end.
