// test_jsonpath.pas — Fase B.2 regression
begin
  testBegin("Fase B.2 — jsonPath");

  // Test 1: single-level path
  var d1 := {"name": "Alice", "age": 30};
  assertEqual("Alice", jsonPath(d1, "name"), "single-level string");
  assertEqual(30, jsonPath(d1, "age"), "single-level number");

  // Test 2: nested path
  var d2 := jsonParse('{"user":{"profile":{"name":"Bob","id":42}}}');
  assertEqual("Bob", jsonPath(d2, "user.profile.name"), "nested string");
  assertEqual(42, jsonPath(d2, "user.profile.id"), "nested number");

  // Test 3: missing path → null
  var r := jsonPath(d2, "user.missing");
  assertEqual("null", typeOf(r), "missing key → null");

  // Test 4: partial missing path → null
  var r2 := jsonPath(d2, "user.profile.nonexistent.deep");
  assertEqual("null", typeOf(r2), "partial missing → null");

  // Test 5: non-dict at intermediate → null
  var d3 := {"a": "string-not-dict"};
  var r3 := jsonPath(d3, "a.b.c");
  assertEqual("null", typeOf(r3), "non-dict intermediate → null");

  testEnd();
  sys.exit(testSummary());
end.