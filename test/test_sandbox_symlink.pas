// ═══════════════════════════════════════════════════════════════
//  Fase Regression: Sandbox Symlink Escape (Fase 0.2)
// ═══════════════════════════════════════════════════════════════
//  Setup sandbox di $HOME (ext4, izinkan symlink), spawn subprocess
//  probe dari dalam sandbox. Verifikasi symlink escape ditolak.
//
//  Prereq:
//    - $HOME writable
//    - file test/probe_symlink.pas ada (cwd = project root)
// ═══════════════════════════════════════════════════════════════

function envOr(key, defaultVal) begin
  var v := sys.env(key);
  if typeOf(v) == "string" then return v;
  return defaultVal;
end;

begin
  testBegin("Fase Regression - Sandbox Symlink Escape");

  sys.execWhitelist(["bash", "mkdir", "rm", "ln", "echo", "cp", "test"]);

  var home := envOr("HOME", "");
  if home == "" then begin
    println("SKIP: HOME not set");
    testEnd();
    sys.exit(0);
  end;

  var sbxBase := home + "/.pascak_sbx_regression";
  var targetDir := sbxBase + "/target";
  var runDir := sbxBase + "/run";

  // ─── Cleanup + setup ───
  sys.exec("bash", ["-c", "rm -rf " + sbxBase], 5000);

  var r := sys.exec("bash", ["-c", "mkdir -p " + targetDir + " " + runDir], 5000);
  if r["exitCode"] != 0 then begin
    println("SKIP: mkdir failed");
    testEnd();
    sys.exit(0);
  end;

  sys.exec("bash", ["-c", "echo -n SECRET_CANARY > " + targetDir + "/secret.txt"], 5000);

  // Buat symlink: run/escape → target/
  r := sys.exec("bash", ["-c", "ln -s " + targetDir + " " + runDir + "/escape"], 5000);
  if r["exitCode"] != 0 then begin
    println("SKIP: ln -s failed (FUSE mount restriction?)");
    println(r["stderr"]);
    sys.exec("bash", ["-c", "rm -rf " + sbxBase], 5000);
    testEnd();
    sys.exit(0);
  end;

  // Verify symlink exists
  r := sys.exec("bash", ["-c", "test -L " + runDir + "/escape"], 2000);
  if r["exitCode"] != 0 then begin
    println("SKIP: symlink not created");
    sys.exec("bash", ["-c", "rm -rf " + sbxBase], 5000);
    testEnd();
    sys.exit(0);
  end;

  // ─── Copy probe dari test/ (asumsi cwd = project root) ───
  var probeSrc := "test/probe_symlink.pas";
  r := sys.exec("bash", ["-c", "test -f " + probeSrc], 2000);
  if r["exitCode"] != 0 then begin
    println("SKIP: " + probeSrc + " not found (run from project root)");
    sys.exec("bash", ["-c", "rm -rf " + sbxBase], 5000);
    testEnd();
    sys.exit(0);
  end;

  sys.exec("bash", ["-c", "cp " + probeSrc + " " + runDir + "/probe.pas"], 5000);

  // ─── Spawn subprocess dengan cwd = run/ ───
  var engineBin := envOr("PASCAK_BIN", home + "/pascak_noASTnet");
  var spawnCmd := "cd " + runDir + " && " + engineBin + " probe.pas";
  r := sys.exec("bash", ["-c", spawnCmd], 30000);

  var stdout := r["stdout"];
  println("--- subprocess stdout ---");
  println(stdout);

  // ─── Verifikasi ───
  var leaked := (pos("VERDICT:LEAKED", stdout) > 0);
  var denied := (pos("VERDICT:DENIED", stdout) > 0);

  assertFalse(leaked, "symlink escape harus DITOLAK");
  assertTrue(denied, "harus DENIED");

  // ─── Cleanup ───
  sys.exec("bash", ["-c", "rm -rf " + sbxBase], 5000);

  testEnd();
end.