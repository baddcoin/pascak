// 100K function calls
function addOne(x) begin
  return x + 1;
end;

begin
  var i := 0;
  var acc := 0;
  while i < 100000 do
  begin
    acc := addOne(acc);
    i := i + 1;
  end;
  println("acc =", acc);
end.
