var CALLBACK_FIRED := 0;
var CALLBACK_STDOUT := "";

function onDone(r) begin
  CALLBACK_FIRED := CALLBACK_FIRED + 1;
  if typeOf(r) == "dictionary" then begin
    if r.hasKey("stdout") then
      CALLBACK_STDOUT := r["stdout"];
  end;
end;

begin
  println("=== execAsync test ===");

  // Whitelist echo untuk test
  sys.execWhitelist(["echo", "sleep"]);

  // ── Test 1: callback-based ──
  println("Test 1: callback-based");
  var t1 := sys.execAsync("echo", ["hello async"], onDone);
  println("task id = ", t1);

  // Main thread sibuk dengan tick event loop
  sleep(2000);

  println("callback fired = ", CALLBACK_FIRED);
  println("stdout = [", CALLBACK_STDOUT, "]");

  if CALLBACK_FIRED < 1 then begin
    println("FAIL: callback tidak dipanggil");
    sys.exit(1);
  end;
  if pos("hello async", CALLBACK_STDOUT) == 0 then begin
    println("FAIL: stdout mismatch");
    sys.exit(1);
  end;

  // ── Test 2: polling-based ──
  println();
  println("Test 2: polling-based");
  var t2 := sys.execAsync("echo", ["poll test"]);
  var got := false;
  var tries := 0;
  var result := nil;
  while tries < 100 do begin
    result := sys.execPoll(t2);
    if result != nil then begin
      got := true;
      break;
    end;
    sleep(50);
    tries := tries + 1;
  end;

  if not got then begin
    println("FAIL: poll timeout");
    sys.exit(1);
  end;

  println("poll result stdout = [", result["stdout"], "]");
  if pos("poll test", result["stdout"]) == 0 then begin
    println("FAIL: poll stdout mismatch");
    sys.exit(1);
  end;
  sys.execFree(t2);

  // ── Test 3: pending count ──
  println();
  println("Test 3: execPending");
  var p := sys.execPending();
  println("pending tasks = ", p);

  println();
  println("ALL PASSED");
  sys.exit(0);
end.