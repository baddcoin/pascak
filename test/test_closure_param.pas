// test_closure_param.pas — Regression guard for compiler closure
// param capture fix (commit 7399d25).
//
// Before fix: params allocated as stack slots (opcGetLocal) but
// nested lambdas capture env (opcGetGlobal). Outer frame teardown
// recycled slot → captured param dangling/null.
//
// After fix: params exist in BOTH stack slot AND env. Nested lambda
// walks env chain → finds param in outer env.

begin
  testBegin("Closure Param Capture");

  // ═══════════════════════════════════════════════════════════════
  //  Case 1: Direct param capture (was: null/AV before fix)
  // ═══════════════════════════════════════════════════════════════
  function makeTask(n) begin
    return lambda : n;
  end;

  var t1 := makeTask(42);
  assertEqual(42, t1(), "direct param capture");

  // ═══════════════════════════════════════════════════════════════
  //  Case 2: Param used inside expression
  // ═══════════════════════════════════════════════════════════════
  function makeTaskAdd(n) begin
    return lambda : (n + 0);
  end;

  var t2 := makeTaskAdd(99);
  assertEqual(99, t2(), "param in expression");

  // ═══════════════════════════════════════════════════════════════
  //  Case 3: Multiple params
  // ═══════════════════════════════════════════════════════════════
  function makePair(a, b) begin
    return lambda : [a, b];
  end;

  var p := makePair(10, 20);
  var pr := p();
  assertEqual(10, pr[0], "multi-param: first");
  assertEqual(20, pr[1], "multi-param: second");

  // ═══════════════════════════════════════════════════════════════
  //  Case 4: Nested closure chain (closure of closure)
  // ═══════════════════════════════════════════════════════════════
  function makeCurry(a) begin
    return lambda b : lambda : (a + b);
  end;

  var c1 := makeCurry(5);
  var c2 := c1(7);
  assertEqual(12, c2(), "curry across two closures");

  // ═══════════════════════════════════════════════════════════════
  //  Case 5: Repeated closure creation (per-frame env)
  // ═══════════════════════════════════════════════════════════════
  var counter := 0;
  while counter < 3 do begin
    var t := makeTask(counter * 100);
    assertEqual(counter * 100, t(), "repeated closure #" + str(counter));
    counter := counter + 1;
  end;

  // ═══════════════════════════════════════════════════════════════
  //  Case 6: Param + local var mixed (both captured)
  // ═══════════════════════════════════════════════════════════════
  function makeMixed(n) begin
    var x := n * 2;
    return lambda : (n + x);
  end;

  var m := makeMixed(10);
  assertEqual(30, m(), "param + local: 10 + 20");

  // ═══════════════════════════════════════════════════════════════
  //  Case 7: Closure path (env) + direct param path (stack)
  //          Both must yield consistent value
  // ═══════════════════════════════════════════════════════════════
  function makeAndUse(n) begin
    var f := lambda : n;
    var doubled := n + n;
    return [f(), doubled];
  end;

  var au := makeAndUse(5);
  assertEqual(5, au[0], "closure path (opcGetGlobal)");
  assertEqual(10, au[1], "direct path (opcGetLocal)");

  testEnd();
  sys.exit(testSummary());
end.
