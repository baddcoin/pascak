// ============================================================
// Stabilisasi Test — S-1, S-2
// ============================================================

// ─── S-1: banyak siklus create/destroy engine-like pattern ───
function testManyCycles() begin
  var i;
  var total := 0;
  for i := 0 to 99 do begin
    var d := {a: 1, b: 2, c: i};
    total := total + d.c;
  end;
  return total;   // 0+1+...+99 = 4950
end;

// ─── S-2: concurrent assign + free ───
var SHARED := 0;

function churner() begin
  var i;
  for i := 0 to 999 do begin
    SHARED := {v: i, w: i * 2};
    SHARED := null;
  end;
end;

function testConcurrentAssign() begin
  SHARED := 0;
  var i;
  for i := 0 to 3 do
    thread(churner);
  sleep(1500);
  return true;
end;

// ─── S-1+S-2 combined: HTTP server dengan banyak request ───
function rapidServer() begin
  var srv := http.serve(19400, lambda req : begin
    var d := {count: 42, msg: "ok"};
    return {status: 200, body: d.msg};
  end);
  http.listen(srv);
end;

function rapidClient() begin
  sleep(300);
  var i;
  var ok := 0;
  for i := 0 to 49 do begin
    var res := http.get("http://127.0.0.1:19400/");
    if res.status == 200 then ok := ok + 1;
  end
  return ok;   // expect 50
end;

// ============================================================
begin
  println("=== Stabilisasi Test ===");
  
  var r1 := testManyCycles();
  println("[S-1] many cycles: ", r1);
  assertEqual(4950, r1, "S-1 cycles");
  
  testConcurrentAssign();
  println("[S-2] concurrent churn done");
  
  thread(rapidServer);
  var r2 := rapidClient();
  println("[S-1+S-2] rapid HTTP: ", r2);
  assertEqual(50, r2, "50 requests");
  
  println("=== Stabilisasi selesai ===");
  println("Summary: failed = ", testSummary());
end.