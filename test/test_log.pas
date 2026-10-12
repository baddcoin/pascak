// test_log.pas — A.2 Structured Logging
begin
  testBegin("A.2 — Structured Logging");

  // Default level: info (debug akan di-skip)
  log.info("plain info message");
  log.warn("plain warning message");
  log.error("plain error message");

  // Test setLevel
  log.setLevel("debug");
  log.debug("debug now visible");

  log.setLevel("error");
  log.debug("NOT visible");
  log.info("NOT visible");
  log.warn("NOT visible");
  log.error("only error visible");

  // Test json format
  log.setLevel("info");
  log.setFormat("json");
  log.info("json message");
  log.error("json with quote \" and newline \n inside");

  // Test multi-arg concat
  log.setFormat("plain");
  log.info("multi-arg: ", 42, " and ", true, " and ", "string");

  // Test output to stderr
  log.setOutput("stderr");
  log.warn("this goes to stderr");

  testEnd();
  sys.exit(testSummary());
end.