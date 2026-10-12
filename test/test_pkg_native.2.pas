// Package manager native binding test
// Prasyarat:
//   ~/.cache/pkg_reg_test/@a/lib/1.0.0/ (registry)
//   ~/.cache/pkg_proj_test/pascak.json (project)

var REGISTRY := "/data/data/com.termux/files/home/.cache/pkg_reg_test";
var PROJECT := "/data/data/com.termux/files/home/.cache/pkg_proj_test";
var PASS := 0;
var FAIL := 0;

function check(name, cond) begin
  if cond then begin
    println("  [OK]   ", name);
    PASS := PASS + 1;
  end else begin
    println("  [FAIL] ", name);
    FAIL := FAIL + 1;
  end;
end;

begin
  println("=== pkg native test ===");

  // Verify dirs exist
  if not fileExists(REGISTRY + "/@a/lib/1.0.0/pascak.json") then begin
    println("SKIP: registry tidak ada");
    sys.exit(0);
  end;
  if not fileExists(PROJECT + "/pascak.json") then begin
    println("SKIP: project tidak ada");
    sys.exit(0);
  end;

  // ─── pkg.resolve ───
  var r := pkg.resolve(REGISTRY, PROJECT + "/pascak.json");
  check("pkg.resolve ok", r["ok"]);
  if r["ok"] then begin
    var resolved := r["resolved"];
    check("resolved contains @a/lib", resolved.hasKey("@a/lib"));
    if resolved.hasKey("@a/lib") then
      check("version = 1.0.0", resolved["@a/lib"]["version"] == "1.0.0");
  end;

  // ─── pkg.install ───
  var inst := pkg.install(REGISTRY, PROJECT);
  check("pkg.install ok", inst["ok"]);
  if inst["ok"] then
    check("installed non-empty", len(inst["installed"]) > 0);

  // ─── pkg.list ───
  var l := pkg.list(PROJECT);
  check("pkg.list ok", l["ok"]);
  if l["ok"] then
    check("has @a/lib@1.0.0",
          indexOf(l["packages"], "@a/lib@1.0.0") >= 0);

  println();
  println("Passed: ", PASS, "  Failed: ", FAIL);
  if FAIL == 0 then begin
    println("RESULT: PASS");
    sys.exit(0);
  end else begin
    println("RESULT: FAIL");
    sys.exit(1);
  end;
end.