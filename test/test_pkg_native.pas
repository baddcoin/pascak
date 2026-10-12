// Test native pkg.* bindings
// Prasyarat: registry + project dir prep di luar script

var REGISTRY := "/data/data/com.termux/files/home/.cache/pkg_reg_test";
var PROJECT := "/data/data/com.termux/files/home/.cache/pkg_proj_test";

begin
  println("=== pkg native test ===");
  println("registry: ", REGISTRY);
  println("project:  ", PROJECT);

  // List before install (should fail — no lockfile)
  var l1 := pkg.list(PROJECT);
  println("list ok: ", l1["ok"]);
  if not l1["ok"] then
    println("  error: ", l1["error"]);

  // Resolve
  var r1 := pkg.resolve(REGISTRY, PROJECT + "/pascak.json");
  println("resolve ok: ", r1["ok"]);
  if r1["ok"] then
    println("  resolved: ", jsonStringify(r1["resolved"]))
  else
    println("  error: ", r1["error"]);

  // Install
  var inst := pkg.install(REGISTRY, PROJECT);
  println("install ok: ", inst["ok"]);
  if inst["ok"] then
    println("  installed: ", jsonStringify(inst["installed"]))
  else
    println("  error: ", inst["error"]);

  // List after install
  var l2 := pkg.list(PROJECT);
  println("list after install ok: ", l2["ok"]);
  if l2["ok"] then
    println("  packages: ", jsonStringify(l2["packages"]));
end.
