begin
  println("=== Fetch 128KB body ===");
  var r := http.get2("https://localhost:8443/big");
  println("status =", r.status);
  println("body_len =", len(r.body));
end.
