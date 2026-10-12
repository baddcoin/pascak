begin
  http.getAsync("https://example.com", lambda r : println("1: ", r.status));
  http.getAsync("https://example.com", lambda r : println("2: ", r.status));
  http.getAsync("https://example.com", lambda r : println("3: ", r.status));
  http.getAsync("https://example.com", lambda r : println("4: ", r.status));
end.