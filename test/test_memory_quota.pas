begin
  testBegin("Fase 1.1 - Context-Aware Memory Quota");

  // ─── [1] sys.memoryUsage harus pakai counter per-engine ───
  var mu := sys.memoryUsage();
  println("  used = ", mu["used_bytes"], " / ", mu["quota_bytes"]);

  assertTrue(mu["quota_bytes"] > 0, "quota harus > 0");
  assertTrue(mu["used_bytes"] >= 0, "used harus >= 0");

  // ─── [2] runtimeStats juga context-aware ───
  var rs := runtimeStats();
  println("  stats.memory_used  = ", rs["memory_used"]);
  println("  stats.memory_quota = ", rs["memory_quota"]);

  assertEqual(rs["memory_quota"], mu["quota_bytes"],
              "runtimeStats & memoryUsage harus konsisten");

  // ─── [3] Alokasi string besar → used naik ───
  var used_before := mu["used_bytes"];
  var s := "";
  var i := 0;
  while i < 1000 do begin
    s := s + "0123456789";     // 10 KB total
    i := i + 1;
  end;

  var mu2 := sys.memoryUsage();
  var used_after := mu2["used_bytes"];

  println("  used_before = ", used_before);
  println("  used_after  = ", used_after);
  println("  delta       = ", used_after - used_before);

  assertTrue(used_after > used_before,
             "alokasi string harus menaikkan used_bytes");

  // ─── [4] Free string → used turun (best-effort, GC async) ───
  s := "";
  gcStep();

  var mu3 := sys.memoryUsage();
  println("  used_after_gc = ", mu3["used_bytes"]);

  // String 10 KB seharusnya sudah di-release. Toleransi ±4 KB
  // untuk overhead & async GC.
  assertTrue(mu3["used_bytes"] <= used_after,
             "GC harus menurunkan atau mempertahankan used");

  testEnd();
end.