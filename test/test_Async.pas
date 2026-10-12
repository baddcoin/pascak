// ============================================================
// T-2b: Async HTTPS Client Test
//
// Catatan: callback dipanggil setelah script selesai, dari
// RunEventLoop. Output muncul setelah "waiting" baris.
// ============================================================

begin
  println("=== T-2b: Async HTTPS Client ===");
  println("");

  // Kasus 1: HTTPS sukses (example.com — stabil)
  http.getAsync("https://example.com", lambda res : begin
    if typeOf(res) == "dictionary" and res.hasKey("error") then
      println("[1] FAIL: ", res.error)
    else
      println("[1] OK: status=", res.status, " len=", len(res.body));
  end);

  // Kasus 2: HTTPS ke domain yang tidak ada (harus return error)
  http.getAsync("https://this-domain-does-not-exist-xyz123.com", lambda res : begin
    if typeOf(res) == "dictionary" and res.hasKey("error") then
      println("[2] OK (expected error): ", res.error)
    else
      println("[2] FAIL: seharusnya error tapi sukses");
  end);

  println("");
  println("2 requests enqueued. Waiting for event loop...");
end.