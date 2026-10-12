// test 0.1: TLS context cache harus dibedakan per verify flag
begin
  var URL := "https://self-signed.badssl.com/";

  testBegin("Fase 0.1 - TLS Context Cache");

  // ─── [1] no-verify → harus SUKSES ───
  try
    var r1 := http.get(URL, {"X-Pascak-No-Verify": "1"});
    assertEqual(r1.status, 200, "step[1] status");
    assertFalse(r1.tls_verify, "step[1] tls_verify harus false");
  catch e do
    assertTrue(false, "step[1] exception: " + e.message);
  end;

  // ─── [2] verify aktif → harus GAGAL (cert self-signed) ───
  // Kalau step ini SUKSES = context no-verify dari step [1] masih bocor.
  var Step2Raised := false;
  try
    var r2 := http.get(URL);
    // Kalau sampai sini, bug 0.1 masih ada
  catch e do
    Step2Raised := true;
  end;
  assertTrue(Step2Raised, "step[2] harus raise (verify self-signed)");

  // ─── [3] no-verify lagi → harus SUKSES ───
  try
    var r3 := http.get(URL, {"X-Pascak-No-Verify": "1"});
    assertEqual(r3.status, 200, "step[3] status");
    assertFalse(r3.tls_verify, "step[3] tls_verify harus false");
  catch e do
    assertTrue(false, "step[3] exception: " + e.message);
  end;

  testEnd();
end.