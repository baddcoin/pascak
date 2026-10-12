// ============================================================
// TLS Diagnostic — dump pesan error mentah
// ============================================================

begin
  println("=== TLS Diagnostic ===");
  println("");
  
  // ─── Test 1: TLS tersedia? ───
  println("[1] tls.isLoaded = ", tls.isLoaded());
  println("    tls.version  = ", tls.version());
  println("");
  
  // ─── Test 2: TLS init manual ───
  println("[2] tls.init() = ", tls.init());
  println("    tls.isLoaded = ", tls.isLoaded());
  println("");
  
  // ─── Test 3: HTTPS request — dump raw error ───
  println("[3] http.get('https://example.com')");
  try
    var res := http.get("https://example.com");
    println("    status = ", res.status);
    println("    body length = ", len(res.body));
    println("    ✓ SUCCESS");
  catch e do
    println("    ✗ ERROR:");
    // `e` bisa jadi dict {message, trace} atau exception object
    if typeOf(e) == "dictionary" then
    begin
      println("    message = [", e.message, "]");
      println("    trace   = [", e.trace, "]");   // ← INI YANG PALING PENTING
    end else
    begin
      println("    message = [", e.message, "]");
      println("    class   = [", typeOf(e), "]");
    end;
  end;
  println("");
  
  // ─── Test 4: HTTPS request ke Cloudflare (IP publik) ───
  println("[4] http.get('https://1.1.1.1')");
  try
    var res := http.get("https://1.1.1.1");
    println("    status = ", res.status);
    println("    ✓ SUCCESS");
  catch e do
    println("    ✗ ERROR: [", e.message, "]");
  end;
  println("");
  
  // ─── Test 5: HTTPS ke example.org (site berbeda, tapi cert valid) ───
  println("[5] http.get('https://example.org')");
  try
    var res := http.get("https://example.org");
    println("    status = ", res.status);
    println("    body length = ", len(res.body));
  catch e do
    if typeOf(e) == "dictionary" then
    begin
      println("    ✗ message = [", e.message, "]");
      println("    ✗ trace   = [", e.trace, "]");
    end;
  end;
  println("");
  
  // ─── Test 6: HTTPS ke httpbin (response JSON) ───
  println("[6] http.get('https://httpbin.org/get')");
  try
    var res := http.get("https://httpbin.org/get");
    println("    status = ", res.status);
    println("    body length = ", len(res.body));
  catch e do
    if typeOf(e) == "dictionary" then
    begin
      println("    ✗ message = [", e.message, "]");
      println("    ✗ trace   = [", e.trace, "]");
    end;
  end;
  println("");  
  
  println("=== Done ===");
end.