// ============================================================
// Tahap T-2a — Verifikasi TLS Security
//
// KUNCI: membedakan antara:
//   - reject-cert   : TLS handshake ditolak karena cert invalid
//   - reject-network: TCP/network error (bukan TLS)
//   - accept        : TLS handshake sukses (BUG kalau seharusnya ditolak)
//
// Hanya 'reject-cert' yang valid sebagai bukti TLS verify bekerja.
// ============================================================

// Klasifikasi hasil request
// Return: 'accept' | 'reject-cert' | 'reject-network' | 'reject-other'
function classifyGet(url) begin
  try
    var res := http.get(url);
    return "accept";
  catch e do
    var msg := lower(e.message);
    
    // Deteksi error cert-related
    if pos("cert", msg) > 0 then return "reject-cert";
    if pos("verif", msg) > 0 then return "reject-cert";
    if pos("ssl_connect", msg) > 0 then return "reject-cert";
    if pos("tls", msg) > 0 then return "reject-cert";
    if pos("handshake", msg) > 0 then return "reject-cert";
    
    // Deteksi error network
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
  
  assertEqual("accept", r, "example.com harus connect sukses");
end;

function testExpiredCert() begin
  println("[T2a-2] Expired cert harus REJECT");
  
  var r := classifyGet("https://expired.badssl.com");
  println("  result = ", r);
  
  if r == "reject-cert" then
  begin
    println("  ✓ chain verify working");
    assertTrue(true, "expired rejected via cert");
  end else if r == "accept" then
    assertTrue(false, "BUG: expired cert diterima!")
  else if r == "reject-network" then
  begin
    println("  ⚠ network error — test tidak valid");
    assertTrue(false, "network error, bukan cert error");
  end else
    assertTrue(false, "unexpected: " + r);
end;

function testWrongHost() begin
  println("[T2a-3] Wrong host cert harus REJECT (SSL_set1_host test)");
  
  var r := classifyGet("https://wrong.host.badssl.com");
  println("  result = ", r);
  
  if r == "reject-cert" then
  begin
    println("  ✓ hostname verify working (SSL_set1_host OK)");
    assertTrue(true, "wrong.host rejected via cert");
  end else if r == "accept" then
  begin
    println("  ✗✗✗ BUG KRITIS: MITM possible!");
    println("  SSL_set1_host TIDAK aktif.");
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

function testOverrideViaEnv() begin
  println("[T2a-6] Override via env var PASCAK_TLS_NO_VERIFY=1");
  
  // Ini test info saja — apakah env var bisa dimatikan.
  // Kita tidak set di sini, hanya cek nilai default.
  var envVal := sys.env("PASCAK_TLS_NO_VERIFY");
  println("  PASCAK_TLS_NO_VERIFY = ", envVal);
  
  if envVal == "1" then
    println("  ⚠ WARNING: verify dimatikan via env!")
  else
    println("  ✓ verify aktif (default secure)");
  
  assertTrue(true, "env check done");
end;

function testShutdownSafety() begin
  println("[T2a-7] Shutdown safety");
  
  var r1 := classifyGet("https://example.com");
  var r2 := classifyGet("https://example.com");
  var r3 := classifyGet("https://example.com");
  
  println("  3 sequential requests: ", r1, " ", r2, " ", r3);
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
  
  testOverrideViaEnv();
  println("--- T2a-6 done ---");
  
  testShutdownSafety();
  println("--- T2a-7 done ---");
  
  println("");
  println("=== Selesai ===");
  println("Summary: failed = ", testSummary());
end.