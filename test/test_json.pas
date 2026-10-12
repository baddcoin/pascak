begin
  println("=== JSON Stringify Test ===");
  println("");
  
  var d1 := {"a": 1, "b": 2, "c": 3};
  println("[1] ", jsonStringify(d1));
  
  var d2 := {"user": {"name": "Alice", "age": 30}, "active": true};
  println("[2] ", jsonStringify(d2));
  
  var d3 := [{"id": 1}, {"id": 2}, {"id": 3}];
  println("[3] ", jsonStringify(d3));
  
  var d4 := {
    "status": "ok",
    "data": {"items": [1, 2, 3], "count": 3},
    "meta": {"ts": 1234567890}
  };
  println("[4] ", jsonStringify(d4));
  
  var jsonStr := jsonStringify(d4);
  var parsed := jsonParse(jsonStr);
  println("[5] round-trip: ", parsed.data.count);
  
  println("");
  println("=== Selesai ===");
end.