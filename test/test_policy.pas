// ═══════════════════════════════════════════════════════════════
//  test_policy.pas — Exec policy regression test
// ═══════════════════════════════════════════════════════════════
//  Default: DENY ALL. Test ini set whitelist dari script.
//  Jalankan: ~/pascak_noASTnet test/test_policy.pas
// ═══════════════════════════════════════════════════════════════

var PASSED := 0;
var FAILED := 0;

function check(name, cond) begin
  if cond then begin
    println("  [OK]   ", name);
    PASSED := PASSED + 1;
  end else begin
    println("  [FAIL] ", name);
    FAILED := FAILED + 1;
  end;
end;

begin
  println("=== exec policy test ===");
  println();

  // ─── 1. Reset ke default (test_all mungkin spawn dengan allow-all) ───
  println("Test 1: explicit reset to none");
  sys.execPolicy({"mode": "none"});
  var info1 := sys.execInfo();
  check("mode = none", info1["mode"] == "none");

  // ─── 2. Default DENY: exec raise error dict ───
  println();
  println("Test 2: default DENY blocks exec");
  var r1 := sys.exec("ls", ["-la"]);
  check("exitCode = -1", r1["exitCode"] == -1);
  check("denied = true", r1["denied"] == true);
  check("error mention policy", pos("policy", r1["error"]) > 0);

  // ─── 3. Set whitelist dari script ───
  println();
  println("Test 3: set whitelist");
  var ok1 := sys.execWhitelist(["ls", "echo"]);
  check("setWhitelist return true", ok1 == true);

  var info2 := sys.execInfo();
  check("mode now whitelist", info2["mode"] == "whitelist");
  check("binaries count 2", len(info2["binaries"]) == 2);

  // ─── 4. Allowed binary berjalan ───
  println();
  println("Test 4: allowed binary runs");
  var r2 := sys.exec("echo", ["hello policy"]);
  check("echo exit 0", r2["exitCode"] == 0);
  check("stdout has hello", pos("hello policy", r2["stdout"]) > 0);

  // ─── 5. Non-whitelisted binary ditolak ───
  println();
  println("Test 5: non-whitelisted denied");
  var r3 := sys.exec("cat", ["/etc/hostname"]);
  check("cat exit -1", r3["exitCode"] == -1);
  check("denied = true", r3["denied"] == true);

  // ─── 6. Multi-args + whitelist ───
  println();
  println("Test 6: ls with args");
  var r4 := sys.exec("ls", ["-1"]);
  check("ls exit 0", r4["exitCode"] == 0);

  // ─── 7. Absolute path masih di whitelist check ───
  println();
  println("Test 7: absolute path check");
  var prefix := sys.env("PREFIX");
  if prefix == nil then prefix := "/data/data/com.termux/files/usr";
  var r5 := sys.exec(prefix + "/bin/echo", ["abs path"]);
  // echo ada di whitelist (nama "echo" di-extract dari path)
  check("abs path allowed (name in whitelist)", r5["exitCode"] == 0);

  // ─── 8. execInfo konsisten ───
  println();
  println("Test 8: execInfo consistency");
  var info3 := sys.execInfo();
  check("activeProcesses = 0", info3["activeProcesses"] == 0);

  println();
  println("=================================================");
  println("  Passed: ", PASSED);
  println("  Failed: ", FAILED);

  if FAILED == 0 then begin
    println("RESULT: PASS");
    sys.exit(0);
  end else begin
    println("RESULT: FAIL");
    sys.exit(1);
  end;
end.