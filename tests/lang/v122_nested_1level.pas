var {th: {ti, tj}} = {"th": {"ti": "x", "tj": "y"}};
var {tk: [tl, tm]} = {"tk": [10, 20]};

begin
  println("T1: ti =", ti);
  println("T2: tj =", tj);
  println("T3: tl =", tl);
  println("T4: tm =", tm);

  var {a: {b, c}} = {"a": {"b": 1, "c": 2}};
  println("N1: b =", b);
  println("N2: c =", c);

  var {p: [m, n]} = {"p": [30, 40]};
  println("N3: m =", m);
  println("N4: n =", n);

  var {q: {r}, s} = {"q": {"r": 100}, "s": 200};
  println("N5: r =", r);
  println("N6: s =", s);

  var {u: [i, j], v: {k, l}} = {"u": [1, 2], "v": {"k": 3, "l": 4}};
  println("N7: i =", i);
  println("N8: j =", j);
  println("N9: k =", k);
  println("N10: l =", l);

  var {w: {z = 42}} = {"w": {}};
  println("N11: z =", z);

  var {x, y} = {"x": 5, "y": 6};
  println("R1: x =", x);
  println("R2: y =", y);

  var [first, ...tail] = [100, 200, 300];
  println("R3: first =", first);
  println("R4: tail =", tail);
end.
