begin
  println("=== Request 1 (expect fail after 3 ENHANCE) ===");
  try
    var r1 := http.get2("https://localhost:8443/test");
    println("UNEXPECTED success:", r1.status);
  catch e
    println("err1:", e.message);
  end;

  println("");
  println("=== Request 2 (expect sleep ~4s then success) ===");
  try
    var r2 := http.get2("https://localhost:8443/test");
    println("r2 status:", r2.status);
    println("r2 body:", r2.body);
  catch e
    println("err2:", e.message);
  end;
end.
