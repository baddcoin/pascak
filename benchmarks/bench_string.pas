// 10K string append + split — measures string perf
begin
  var s := "";
  var i := 0;
  while i < 10000 do
  begin
    s := s + "item" + str(i) + ",";
    i := i + 1;
  end;
  var parts := s.split(",");
  println("parts =", len(parts), " len =", len(s));
end.
