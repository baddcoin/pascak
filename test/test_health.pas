// test_health.pas — A.7 Health Checks
begin
  testBegin("A.7 — Health Checks");

  // Register 3 checks
  health.register("always_ok",  lambda : true);
  health.register("always_fail", lambda : false);
  health.register("dict_ok",    lambda : {"ok": true, "version": "1.0"});

  // 1. List
  var names := health.list();
  assertTrue(len(names) >= 3, "list has >= 3 checks");

  // 2. Check all
  var status := health.check();
  assertTrue(status.hasKey("status"), "result has status");
  assertTrue(status.hasKey("checks"), "result has checks");

  var checks := status.checks;
  assertTrue(checks.hasKey("always_ok"), "checks has always_ok");
  assertTrue(checks.hasKey("always_fail"), "checks has always_fail");
  assertTrue(checks.hasKey("dict_ok"), "checks has dict_ok");

  // 3. Verify individual results
  assertEqual(true, checks["always_ok"]["ok"], "always_ok ok=true");
  assertEqual(false, checks["always_fail"]["ok"], "always_fail ok=false");
  assertEqual(true, checks["dict_ok"]["ok"], "dict_ok ok=true");
  assertEqual("1.0", checks["dict_ok"]["version"], "dict_ok version");

  // 4. Status should be "degraded" (mixed)
  assertEqual("degraded", status["status"], "status=degraded");

  // 5. Unregister failing check → status ok
  var removed := health.unregister("always_fail");
  assertTrue(removed, "unregister returns true");

  var status2 := health.check();
  assertEqual("ok", status2["status"], "status=ok after unregister");

  // 6. All fail → status down
  health.unregister("always_ok");
  health.unregister("dict_ok");
  health.register("fail1", lambda : false);
  health.register("fail2", lambda : false);

  var status3 := health.check();
  assertEqual("down", status3["status"], "status=down all fail");

  testEnd();
  sys.exit(testSummary());
end.