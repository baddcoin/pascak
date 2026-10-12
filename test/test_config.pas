// test_config.pas — A.3 Config Management
begin
  testBegin("A.3 — Config Management");

  // Setup test files
  fileWrite(".env.test", "APP_NAME=TestApp\n" +
                         "PORT=3000\n" +
                         "DEBUG=true\n" +
                         "QUOTED=\"hello world\"\n" +
                         "# comment line\n" +
                         "export EXPORTED_VAR=exported\n");

  fileWrite("config.json.test", '{"db_host":"localhost","db_port":5432,"nested":{"a":1}}');

  // Test 1: load .env
  config.load(".env.test");
  assertEqual("TestApp", config.get("APP_NAME"), "dotenv basic");
  assertEqual("3000", config.get("PORT"), "dotenv number");
  assertEqual("true", config.get("DEBUG"), "dotenv bool");
  assertEqual("hello world", config.get("QUOTED"), "dotenv quoted strip");
  assertEqual("exported", config.get("EXPORTED_VAR"), "dotenv export prefix");

  // Test 2: load JSON
  config.loadJSON("config.json.test");
  assertEqual("localhost", config.get("db_host"), "json string");
  assertEqual("5432", config.get("db_port"), "json number");

  // Test 3: default fallback
  assertEqual("default-val", config.get("NOT_EXIST", "default-val"), "default fallback");

  // Test 4: has
  assertTrue(config.has("APP_NAME"), "has existing");
  assertFalse(config.has("NOT_EXIST"), "has missing");

  // Test 5: set runtime override
  config.set("APP_NAME", "Overridden");
  assertEqual("Overridden", config.get("APP_NAME"), "runtime override");

  // Test 6: all()
  var all := config.all();
  assertTrue(all.hasKey("APP_NAME"), "all() contains APP_NAME");
  assertTrue(all.hasKey("db_host"), "all() contains db_host");

  // Cleanup
  fileDelete(".env.test");
  fileDelete("config.json.test");

  testEnd();
  sys.exit(testSummary());
end.