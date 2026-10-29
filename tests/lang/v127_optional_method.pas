begin
  // ── Basic ?.() with native method ──
  var d := {"x": 1, "y": 2};
  println("B1: d?.hasKey('x') =", d?.hasKey("x"));
  println("B2: d?.hasKey('zz') =", d?.hasKey("zz"));

  // ── Null target → null (no crash) ──
  var n := null;
  println("B3: n?.hasKey('x') =", n?.hasKey("x"));

  // ── Non-null nested chain ──
  var chain := {"inner": {"x": 1}};
  println("B4: chain?.inner?.hasKey('x') =", chain?.inner?.hasKey("x"));

  // ── Null nested chain ──
  var chain2 := {"inner": null};
  println("B5: chain2?.inner?.hasKey('x') =", chain2?.inner?.hasKey("x"));

  // ── Short-circuit proof: n null → args NOT evaluated ──
  // If not short-circuit: n.undefined_method() would crash
  var r := n?.hasKey(n.undefined_method());
  println("B6: short-circuit r =", r);

  // ── Regression: normal method call ──
  println("R1: d.hasKey('x') =", d.hasKey("x"));

  // ── Regression: ?. property (no call) ──
  println("R2: n?.foo =", n?.foo);

  // ── ?.property?.method() combined ──
  var obj := {"meta": {"keys_fn": null}};
  println("R3: obj?.meta?.hasKey('keys_fn') =", obj?.meta?.hasKey("keys_fn"));
end.
