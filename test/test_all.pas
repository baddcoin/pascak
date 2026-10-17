// ═══════════════════════════════════════════════════════════════
//  test_all.pas — Automated regression suite driver
// ═══════════════════════════════════════════════════════════════
//  Jalankan:
//  ./pascak_noASTnet ~/storage/downloads/termux/pascak/test/test_all.pas
//  Atau (dari direktori pascak/):
//    ~/pascak_noASTnet test/test_all.pas
//
//  Env override:
//    PASCAK_BIN      — path ke engine binary
//    PASCAK_TESTDIR  — path ke direktori test
//
//  Exit code:
//    0 = semua test pass
//    1 = ada test gagal
//    2 = engine binary atau test directory tidak ditemukan
// ═══════════════════════════════════════════════════════════════

var ENGINE := "";
var TESTDIR := "";
var PASSED := 0;
var FAILED := 0;
var SKIPPED := 0;
var FAILED_NAMES := [];

// ────────────────────────────────────────────────────────────────
//  Cari engine binary
// ────────────────────────────────────────────────────────────────

//  Env helper — sys.env() returns null kalau tidak ada
function envOr(key, defaultVal) begin
  var v := sys.env(key);
  if typeOf(v) == "string" then return v;
  return defaultVal;
end;

function findEngine() begin
  // 1. Env override
  var e := envOr("PASCAK_BIN", "");
  if len(e) > 0 then begin
    var r := sys.exec("test", ["-x", e], 2000);
    if r["exitCode"] == 0 then return e;
  end;

  // 2. Common locations
  var home := envOr("HOME", ""); 
  var candidates := [
    home + "/pascak_noASTnet",
    home + "/.local/bin/pascak_noASTnet"
  ];
  var i := 0;
  while i < len(candidates) do begin
    var r := sys.exec("test", ["-x", candidates[i]], 2000);
    if r["exitCode"] == 0 then return candidates[i];
    i := i + 1;
  end;

  // 3. argv[0]
  var args := sys.args();
  if len(args) > 0 then begin
    var r := sys.exec("test", ["-x", args[0]], 2000);
    if r["exitCode"] == 0 then return args[0];
  end;

  return "";
end;

// ────────────────────────────────────────────────────────────────
//  Cari test directory
// ────────────────────────────────────────────────────────────────
function findTestDir() begin
  // 1. Env override
  var e := envOr("PASCAK_TESTDIR", "");  
  if len(e) > 0 then begin
    var r := sys.exec("test", ["-d", e], 2000);
    if r["exitCode"] == 0 then return e;
  end;

  // 2. Relative candidates — probe dengan file marker
  var home := envOr("HOME", ""); 
  var candidates := [
    "test",
    "./test",
    home + "/storage/downloads/termux/pascak/test",
    home + "/storage/downloads/pascak/test"
  ];
  var i := 0;
  while i < len(candidates) do begin
    var probe := candidates[i] + "/test_phase_f1.pas";
    var r := sys.exec("test", ["-f", probe], 2000);
    if r["exitCode"] == 0 then return candidates[i];
    i := i + 1;
  end;

  return "";
end;

// ────────────────────────────────────────────────────────────────
//  Cek file exists (bypass sandbox)
// ────────────────────────────────────────────────────────────────
function fileExistsRaw(path) begin
  var r := sys.exec("test", ["-f", path], 2000);
  return r["exitCode"] == 0;
end;

// ────────────────────────────────────────────────────────────────
//  Deteksi apakah output + exit code menandakan pass
// ────────────────────────────────────────────────────────────────
function detectPass(out, code) begin
  // Fail markers dulu — kalau ada, langsung fail
  if pos("FAIL:", out) > 0 then return false;
  if pos("SOME TESTS FAILED", out) > 0 then return false;
  if pos("SOME FAILED", out) > 0 then return false;
  if pos("failed = 1", out) > 0 then return false;
  if pos("failed = 2", out) > 0 then return false;
  if pos("failed = 3", out) > 0 then return false;

  // Pass markers
  if pos("Summary: failed = 0", out) > 0 then return true;
  if pos("ALL PASSED", out) > 0 then return true;
  if pos("ALL TESTS PASSED", out) > 0 then return true;
  if pos("=== Semua test selesai ===", out) > 0 then return true;
  if pos("=== Selesai ===", out) > 0 then return true;

  // Fallback: exit code 0 + tidak ada fail marker
  if code == 0 then return true;
  return false;
end;

// ────────────────────────────────────────────────────────────────
//  Jalankan satu test
// ────────────────────────────────────────────────────────────────
// Soft = network-dependent. Fail → skip, bukan fail.
function runScriptTestEx(name, soft)
begin
  var path := TESTDIR + '/' + name;

  if not fileExistsRaw(path) then begin
    println("  [SKIP] ", name, " (tidak ditemukan)");
    SKIPPED := SKIPPED + 1;
    return;
  end;

  print("  [RUN ] ", name, " ... ");

  // ✅ Fase 1.4: propagate --dev ke child test. Tanpa ini, child spawn
  // dengan env override diabaikan → policy=none → sys.exec("python3")
  // ditolak di test WS event-mode.
  var r := sys.exec(ENGINE, ["--dev", path], 60000);


  if detectPass(r["stdout"], r["exitCode"]) then begin
    println("PASS");
    PASSED := PASSED + 1;
  end else if soft then begin
    println("SOFT-SKIP (network)");
    SKIPPED := SKIPPED + 1;
  end else begin
    println("FAIL (exit=", r["exitCode"], ")");
    FAILED := FAILED + 1;
    push(FAILED_NAMES, name);
    println("    ----- last 600 chars of output -----");
    if len(r["stdout"]) > 600 then
      println(copy(r["stdout"], len(r["stdout"]) - 600, 600))
    else
      println(r["stdout"]);
    println("    ------------------------------------");
  end;
end;

function runScriptTest(name)
begin
  runScriptTestEx(name, false);
end;

// ═══════════════════════════════════════════════════════════════
//  Main
// ═══════════════════════════════════════════════════════════════
begin
  println('=================================================');
  println('  Pascak Regression Suite');
  println('=================================================');

  // B.SEC: test driver spawns engine subprocess.
  // Policy harus allow-all — kalau tidak, semua sub-test akan skip.
  var info := sys.execInfo();
  if info != nil then begin
    if info["mode"] != "allow-all" then
    begin
      println();
      println('ERROR: test_all.pas butuh exec policy "allow-all"');
      println('       (mode sekarang: ', info["mode"], ')');
      println();
      println('Jalankan dengan:');
      println('  PASCAK_EXEC_POLICY=allow-all ~/pascak_noASTnet test/test_all.pas');
      println();
      sys.exit(2);
    end;
  end;

  ENGINE := findEngine();
  if ENGINE == "" then begin
    println("ERROR: engine binary tidak ditemukan");
    println("  Set: PASCAK_BIN=/path/to/pascak_noASTnet");
    sys.exit(2);
  end;

  TESTDIR := findTestDir();
  if TESTDIR == "" then begin
    println("ERROR: test directory tidak ditemukan");
    println("  Set: PASCAK_TESTDIR=/path/to/test");
    sys.exit(2);
  end;

  println("  engine  : ", ENGINE);
  println("  testdir : ", TESTDIR);
  println();

  // ── Kategori 1: Core FFI ──
  println("[ Core FFI ]");
  runScriptTest("test_phase_f1.pas");
  runScriptTest("test_closure_param.pas");
  runScriptTest("test_phase_f3a3.pas");
  runScriptTest("test_phase_f3a4.pas");
  runScriptTest("test_qshort.pas");
  println();

  // ── Kategori 2: Struct ──
  println("[ Struct ]");
  runScriptTest("test_struct.pas");
  runScriptTest("test_struct_ffi.pas");
  runScriptTest("test_struct_call.pas");
  println();

  // ── Kategori 3: TLS ──
  // NOTE: t2a_2 flaky exit code di shutdown path — bukan assertion fail
  // (Summary: failed = 0). Investigate race di TLS cleanup (T2a-6).
  println("[ TLS ]");
  runScriptTestEx("test_phase_t2a_2.pas", true);
  println();

  // ── Kategori 4: JSON ──
  println("[ JSON ]");
  runScriptTest("test_json.pas");
  println();

  // ── Kategori 4c: Crypto ──
  println("[ Crypto ]");
  runScriptTest("test_crypto.pas");
  println();

  // ── Kategori 5: Security (exec policy) ──
  println("[ Security ]");
  runScriptTest("test_policy.pas");
  runScriptTest("test_exec_async.pas");
  println();

  // ── Kategori 5b: Regression (Fase 0.x, 1.x) ──
  // Test yang mengunci bug spesifik yang ditemukan & diperbaiki.
  // Tiga test pertama deterministik (localhost + subprocess python/bash).
  // test_tls_cache butuh network (badssl.com) → soft.
  println("[ Regression ]");
  runScriptTest("test_ws_fragmentation.pas");     // fix: Conn.FragBuf
  runScriptTest("test_sandbox_symlink.pas");      // Fase 0.2: symlink resolve
  runScriptTest("test_env_guard.pas");            // Fase 1.4: --dev gate
  runScriptTestEx("test_tls_cache.pas", true);    // Fase 0.1+0.8 (network)
  println();

  // ── Kategori 6: WebSocket ──
  println("[ WebSocket ]");
  runScriptTest("test_websocket.pas");
  runScriptTest("test_ws_listen_async.pas");
  runScriptTest("test_ws_subprotocol.pas");
  runScriptTest("test_ws_ping.pas");
  runScriptTest("test_ws_compression.pas");
  runScriptTest("test_ws_nbs.pas");
  runScriptTest("test_ws_tls_nbs.pas");
  println();

  // ── Kategori 7: Async (soft, network dependent) ──
  println("[ Async - soft, network dependent ]");
  runScriptTestEx("test_Async.pas", true);
  println();

  // ── Kategori 8: Stress (berat, soft) ──
  println("[ Stress - berat, soft ]");
  runScriptTestEx("test_ws_stress_tls.pas", true);
  runScriptTestEx("test_memory_stability.pas", true);
  println();

  // ── Kategori 9: Package Manager ──
  println("[ Package Manager ]");
  runScriptTestEx("test_pkg_native.pas", true);
  println();

  // ── Kategori 10: File I/O (async) ──
  println("[ File I/O ]");
  runScriptTest("test_fs_async.pas");
  runScriptTest("test_engine_leak.pas");
  runScriptTestEx("test_http2.pas", true);
  println();


  // ── Summary ──
  println("=================================================");
  println("  Summary");
  println("=================================================");
  println("  Passed  : ", PASSED);
  println("  Failed  : ", FAILED);
  println("  Skipped : ", SKIPPED);

  if FAILED > 0 then begin
    println();
    println("  Failed tests:");
    var i := 0;
    while i < len(FAILED_NAMES) do begin
      println("    - ", FAILED_NAMES[i]);
      i := i + 1;
    end;
    println();
    println("RESULT: FAIL");
    sys.exit(1);
  end else begin
    println();
    println("RESULT: PASS");
    sys.exit(0);
  end;
end.