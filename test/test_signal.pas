// test_signal.pas — B.2 Signal Handling
var intCount := 0;
var termCount := 0;

begin
  testBegin("B.2 — Signal Handling");

  // Test 1: SIGTERM handler fire
  signal.on("SIGTERM", lambda : begin
    lock begin
      termCount := termCount + 1;
    end;
  end);

  signal.raise("SIGTERM");
  sleep(100);   // give event loop time
  assertEqual(1, termCount, "SIGTERM handler fired once");

  // Test 2: multiple raise
  signal.raise("SIGTERM");
  sleep(100);
  assertEqual(2, termCount, "SIGTERM handler fired twice");

  // Test 3: SIGINT handler
  signal.on("SIGINT", lambda : begin
    lock begin
      intCount := intCount + 1;
    end;
  end);

  signal.raise("SIGINT");
  sleep(100);
  assertEqual(1, intCount, "SIGINT handler fired");

  // Test 4: off
  signal.off("SIGTERM");
  signal.raise("SIGTERM");
  sleep(100);
  assertEqual(2, termCount, "SIGTERM off — no more fires");

  testEnd();
  sys.exit(testSummary());
end.