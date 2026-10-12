// ============================================================
// Tahap T-2a — Verifikasi TLS Security (FINAL)
//
// Klasifikasi hasil:
//   "accept"         → handshake + verify sukses (BUG kalau harusnya reject)
//   "reject-cert"    → verify chain/hostname menolak cert (BENAR)
//   "reject-network" → TCP/DNS error (test tidak valid)
//   "reject-other"   → error lain, perlu investigasi
// ============================================================

function classifyGet(url) begin
  try
    var res := http.get(url);
    return "accept";
  catch e do
    var msg := lower(e.message);
    
    if pos("cert", msg) > 0 then return "reject-cert";
    if pos("verif", msg) > 0 then return "reject-cert";
    if pos("ssl_connect", msg) > 0 then return "reject-cert";
    if pos("handshake", msg) > 0 then return "reject-cert";
    if pos("tls", msg) > 0 then return "reject-cert";
    
    if pos("socket", msg) > 0 then return "reject-network";
    if pos("connect gagal", msg) > 0 then return "reject-network";
    if pos("resolve", msg) > 0 then return "reject-network";
    if pos("timeout", msg) > 0 then return "reject-network";
    
    return "reject-other";
  end;
end;

function testBaselineHTTPS() begin
  println("[T2a-1] Baseline: HTTPS normal");
  var r := classifyGet("https://example.com");
  println("  result = ", r);
  assertEqual("accept", r, "example.com harus sukses");
end;

function testExpiredCert() begin
  println("[T2a-2] Expired cert harus REJECT");
  var r := classifyGet("https://expired.badssl.com");
  println("  result = ", r);
  if r == "reject-cert" then begin
    println("  ✓ chain verify working");
    assertTrue(true, "expired rejected");
  end else if r == "accept" then
    assertTrue(false, "BUG: expired diterima!")
  else
    assertTrue(false, "unexpected: " + r);
end;

function testWrongHost() begin
  println("[T2a-3] Wrong host cert harus REJECT (SSL_set1_host)");
  var r := classifyGet("https://wrong.host.badssl.com");
  println("  result = ", r);
  if r == "reject-cert" then begin
    println("  ✓ hostname verify working — SSL_set1_host OK");
    assertTrue(true, "wrong.host rejected");
  end else if r == "accept" then begin
    println("  ✗✗✗ BUG KRITIS: MITM possible!");
    assertTrue(false, "BUG: wrong.host diterima!");
  end else
    assertTrue(false, "unexpected: " + r);
end;

function testSelfSigned() begin
  println("[T2a-4] Self-signed cert harus REJECT");
  var r := classifyGet("https://self-signed.badssl.com");
  println("  result = ", r);
  if r == "reject-cert" then
    assertTrue(true, "self-signed rejected")
  else if r == "accept" then
    assertTrue(false, "BUG: self-signed diterima!")
  else
    assertTrue(false, "unexpected: " + r);
end;

function testUntrustedRoot() begin
  println("[T2a-5] Untrusted root harus REJECT");
  var r := classifyGet("https://untrusted-root.badssl.com");
  println("  result = ", r);
  if r == "reject-cert" then
    assertTrue(true, "untrusted root rejected")
  else if r == "accept" then
    assertTrue(false, "BUG: untrusted root diterima!")
  else
    assertTrue(false, "unexpected: " + r);
end;

function testShutdownSafety() begin
  println("[T2a-6] Shutdown safety (3 koneksi hidup)");
  var r1 := classifyGet("https://example.com");
  var r2 := classifyGet("https://example.org");
  var r3 := classifyGet("https://httpbin.org/get");
  println("  ", r1, " ", r2, " ", r3);
  assertTrue(r1 == "accept" and r2 == "accept" and r3 == "accept", 
             "3 koneksi sukses");
end;

// ============================================================
begin
  println("=== Tahap T-2a: TLS Security Verification ===");
  println("");
  
  testBaselineHTTPS();
  println("--- T2a-1 done ---");
  testExpiredCert();
  println("--- T2a-2 done ---");
  testWrongHost();
  println("--- T2a-3 done ---");
  testSelfSigned();
  println("--- T2a-4 done ---");
  testUntrustedRoot();
  println("--- T2a-5 done ---");
  testShutdownSafety();
  println("--- T2a-6 done ---");
  
  println("");
  println("=== Selesai ===");
  println("Summary: failed = ", testSummary());
end.