begin
  println("=== crypto test ===");

  // ── SHA-256 (existing) ──
  var h := crypto.sha256("hello");
  println("sha256('hello') = ", h);
  if h != "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824" then begin
    println("FAIL: sha256 mismatch");
    sys.exit(1);
  end;

  // ── SHA-1 (new) ──
  var h1 := crypto.sha1Hex("hello");
  println("sha1Hex('hello') = ", h1);
  if h1 != "aaf4c61ddcc5e8a2dabede0f3b482cd9aea9434d" then begin
    println("FAIL: sha1 mismatch");
    sys.exit(1);
  end;

  // ── Base64 (new) ──
  var b64 := crypto.base64Encode("Hello, World!");
  println("b64 = ", b64);
  if b64 != "SGVsbG8sIFdvcmxkIQ==" then begin
    println("FAIL: base64 encode mismatch");
    sys.exit(1);
  end;
  var decoded := crypto.base64Decode(b64);
  if decoded != "Hello, World!" then begin
    println("FAIL: base64 decode mismatch");
    sys.exit(1);
  end;

  // ── AES-256-CBC (new) ──
  var key := "0123456789abcdef0123456789abcdef";  // 32 byte
  var iv := "abcdef0123456789";                    // 16 byte
  var plain := "Ini pesan rahasia yang harus dilindungi!";
  var ct := crypto.aesEncrypt(plain, key, iv, "cbc");
  println("ciphertext len = ", byteLen(ct), " bytes");  
  var pt := crypto.aesDecrypt(ct, key, iv, "cbc");
  if pt != plain then begin
    println("FAIL: aes roundtrip mismatch");
    sys.exit(1);
  end;
  println("AES-256-CBC roundtrip OK");

  // ── AES-128-CBC ──
  var key128 := "0123456789abcdef";  // 16 byte
  var ct128 := crypto.aesEncrypt(plain, key128, iv, "cbc");
  var pt128 := crypto.aesDecrypt(ct128, key128, iv, "cbc");
  if pt128 != plain then begin
    println("FAIL: aes-128 roundtrip mismatch");
    sys.exit(1);
  end;
  println("AES-128-CBC roundtrip OK");

  // ── PBKDF2 (new) ──
  var derived := crypto.pbkdf2Sha256("password", "salt", 1, 32);
  var expected := crypto.hexToBytes(
    "120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b");
  
  if byteLen(derived) != 32 then begin
    println("FAIL: pbkdf2 length wrong, got ", byteLen(derived), " expected 32");
    sys.exit(1);
  end;
  
  if derived != expected then begin
    println("FAIL: pbkdf2 RFC 7914 vector mismatch");
    sys.exit(1);
  end;
  println("PBKDF2-SHA256 OK (RFC 7914 vector)");  

  println();
  println("ALL PASSED");
end.