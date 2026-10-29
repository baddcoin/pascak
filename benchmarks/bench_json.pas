// 1000 JSON parse+stringify round-trips — measures JSON perf
begin
  var i := 0;
  var acc := 0;
  while i < 1000 do
  begin
    var raw := '{"id":' + str(i) + ',"name":"item","tags":["a","b","c"]}';
    var obj := jsonParse(raw);
    var out := jsonStringify(obj);
    acc := acc + len(out);
    i := i + 1;
  end;
  println("json acc =", acc);
end.
