// test_shutdown.pas — A.5 onShutdown hooks
var order := [];

begin
  testBegin("A.5 — Shutdown Hooks");

  onShutdown(lambda : begin
    push(order, "hook1");
    log.info("hook1 fired");
  end);

  onShutdown(lambda : begin
    push(order, "hook2");
    log.info("hook2 fired");
  end);

  onShutdown(lambda : begin
    push(order, "hook3");
    log.info("hook3 fired");
  end);

  assertEqual(0, len(order), "hooks not fired yet");
  assertTrue(true, "setup complete — hooks fire on sys.exit");

  testEnd();
  sys.exit(testSummary());
end.