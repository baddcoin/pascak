begin
  // ── Basic rest ──
  var [first, ...tail] = [10, 20, 30, 40];
  println("1: first =", first);     // 10
  println("2: tail =", tail);       // [20, 30, 40]

  // ── Only rest ──
  var [...all] = [5, 6, 7];
  println("3: all =", all);         // [5, 6, 7]

  // ── Two leading + rest ──
  var [a, b, ...rest] = [1, 2, 3, 4, 5];
  println("4: a =", a);             // 1
  println("5: b =", b);             // 2
  println("6: rest =", rest);       // [3, 4, 5]

  // ── Rest on short array → empty slice ──
  var [x, ...tail2] = [100];
  println("7: x =", x);             // 100
  println("8: tail2 =", tail2);     // []

  // ── No rest (regression) ──
  var [p, q] = [1, 2];
  println("9: p =", p);             // 1
  println("10: q =", q);            // 2
end.
