function bench(n) begin
  var s := 0;
  for i := 0 to n - 1 do begin
    s := s + i;
  end;
  return s;
end;

begin
  var r := bench(1000000);
  println("arith_done " + str(r));
end.
