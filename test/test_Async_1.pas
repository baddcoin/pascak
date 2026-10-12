begin
  http.getAsync("https://1.1.1.1", lambda res : begin
    if typeOf(res) == "dictionary" and res.hasKey("error") then
      println("FAIL: ", res.error)
    else
      println("OK: status=", res.status);
  end);
end.