// ============================================================
// Stabilisasi Test — S-4 (graceful shutdown) + S-5 (thread errors)
// ============================================================

// ─── S-4: Graceful shutdown ───
function slowHandler(req) begin
  sleep(500);   // simulasikan pekerjaan berat
  return {status: 200, body: "done: " + req.path};
end;

function s4_server() begin
  var srv := http.serve(19500, slowHandler);
  println("[S-4 srv] listening on 19500, handle=", srv);
  var count := http.listen(srv);
  println("[S-4 srv] exited cleanly, served ", count, " requests");
end;

function s4_client() begin
  sleep(300);
  
  // Kirim request yang butuh 500ms untuk selesai
  var res := http.get("http://127.0.0.1:19500/slow");
  println("[S-4 cli] got: ", res.status, " ", res.body);
  assertEqual(200, res.status, "request completed");
  assertEqual("done: /slow", res.body, "body correct");
end;

// ─── S-5: Thread error capture ───
function crashingThread() begin
  // Akan raise karena division by zero
  var x := 10;
  var y := 0;
  var z := x / y;
end;

function healthyThread() begin
  sleep(200);
end;

function testThreadErrors() begin
  println("[S-5] Thread error capture");
  
  sys.clearThreadErrors();
  sys.setVerboseThreadErrors(false);   // default silent
  
  var errsBefore := sys.threadErrors();
  assertEqual(0, len(errsBefore), "clean start");
  
  thread(crashingThread);
  thread(healthyThread);
  thread(crashingThread);
  
  sleep(800);
  
  var errsAfter := sys.threadErrors();
  println("  errors captured: ", len(errsAfter));
  var i;
  for i := 0 to len(errsAfter) - 1 do
    println("    - ", errsAfter[i]);
  
  assertTrue(len(errsAfter) >= 2, "at least 2 errors");
  
  // Verifikasi prefix tidak dobel
  assertTrue(errsAfter[0].indexOf("Interpreter Halted: Interpreter Halted:") < 0,
             "no double prefix");
  
  sys.clearThreadErrors();
  var errsCleared := sys.threadErrors();
  assertEqual(0, len(errsCleared), "cleared");
end;

// ============================================================
begin
  println("=== Stabilisasi Test S-4 + S-5 ===");
  
  // S-4: graceful shutdown
  thread(s4_server);
  s4_client();
  println("--- S-4 done ---");
  
  // S-5: thread error capture
  testThreadErrors();
  println("--- S-5 done ---");
  
  println("=== Semua test selesai ===");
  println("Summary: failed = ", testSummary());
end.