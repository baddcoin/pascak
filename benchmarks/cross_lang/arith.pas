begin
  var s := 0;
  var i := 0;
  while i < 1000000 do begin
    s := s + i;
    i := i + 1;
  end;
  println("arith_done " + str(s));
end.
