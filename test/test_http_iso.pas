begin
  println("=== HTTP Isolation Test v2 ===");
  println("");
  
  // httpbin.org/get — JSON response, tapi dengan header standard
  println("[A] httpbin.org/get:");
  try
    var r := http.get("https://httpbin.org/get");
    println("    status=", r.status, " len=", len(r.body));
  catch e do
    println("    ✗ ", e.message);
  end;
  println("");
  
  // httpbin.org/headers — return header dict, tapi response-nya
  // berisi ALL header yang kita kirim, termasuk User-Agent dll
  println("[B] httpbin.org/headers:");
  try
    var r := http.get("https://httpbin.org/headers");
    println("    status=", r.status, " len=", len(r.body));
  catch e do
    println("    ✗ ", e.message);
  end;
  println("");
  
  // httpbin.org/redirect-to?url=... — return 302 ke URL
  println("[C] httpbin.org/redirect-to:");
  try
    var r := http.get("https://httpbin.org/redirect-to?url=https://example.com");
    println("    status=", r.status, " len=", len(r.body));
  catch e do
    println("    ✗ ", e.message);
  end;
  println("");
  
  // www.example.com — subdomain, berbeda dari example.com
  println("[D] www.example.com:");
  try
    var r := http.get("https://www.example.com");
    println("    status=", r.status, " len=", len(r.body));
  catch e do
    println("    ✗ ", e.message);
  end;
  println("");
  
  println("=== Done ===");
end.