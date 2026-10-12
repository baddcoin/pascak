// test_timer.pas — Fase B.1 regression
var counter := 0;
var interval_counter := 0;

begin
  testBegin("Fase B.1 — Timer API");

  // Test 1: setTimeout fires once
  setTimeout(lambda : begin
    lock begin
      counter := counter + 1;
    end;
  end, 50);

  sleep(150);
  assertEqual(1, counter, "setTimeout fires once");

  // Test 2: clearTimeout cancels
  var t := setTimeout(lambda : begin
    lock begin
      counter := counter + 100;
    end;
  end, 100);

  clearTimeout(t);
  sleep(200);
  assertEqual(1, counter, "clearTimeout prevents fire");

  // Test 3: setInterval fires multiple times
  var intv := setInterval(lambda : begin
    lock begin
      interval_counter := interval_counter + 1;
    end;
  end, 30);

  sleep(200);
  clearInterval(intv);
  var snap := interval_counter;
  sleep(100);

  assertTrue(snap >= 4, "setInterval fires >=4 times in 200ms/30ms");
  assertEqual(snap, interval_counter, "clearInterval stops firing");

  testEnd();
  sys.exit(testSummary());
end.