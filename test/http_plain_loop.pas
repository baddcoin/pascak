begin
  var r := http.get("http://example.com");
  println("status=", r["status"]);
end.
