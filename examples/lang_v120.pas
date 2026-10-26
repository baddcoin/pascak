// examples/lang_v120.pas
// Pascak v1.2.0 language features:
// - Destructure defaults (obj + array)
// - Enum in function scope

// ── Phase A1: Defaults (top-level) ──
var {greeting = "Hello", name = "World"} = {"name": "Pascak"};
var [first = 1, second = 2, third = 3] = [10, 20];

// ── Phase A2: Enum in function scope ──
function classify(score) begin
  enum Grade { Fail, Pass, Distinction }
  if score < 50 then return Grade.Fail;
  if score < 75 then return Grade.Pass;
  return Grade.Distinction;
end;

begin
  println("=== Destructure Defaults ===");
  println("greeting = ", greeting);  // "Hello" (key missing → default)
  println("name     = ", name);      // "Pascak" (key present)

  println("");
  println("Array defaults:");
  println("first    = ", first);     // 10
  println("second   = ", second);    // 20
  println("third    = ", third);     // 3 (index missing → default)

  println("");
  println("Falsy pass-through:");
  var {zero = 999, empty = "fallback", flag = true} = {"zero": 0, "empty": "", "flag": false};
  println("zero     = ", zero);      // 0   (bukan 999)
  println("empty    = '", empty, "'");  // '' (bukan "fallback")
  println("flag     = ", flag);      // false (bukan true)

  println("");
  println("=== Enum in Function Scope ===");
  println("classify(30) = ", classify(30));   // 0 (Fail)
  println("classify(60) = ", classify(60));   // 1 (Pass)
  println("classify(90) = ", classify(90));   // 2 (Distinction)

  println("");
  println("=== Enum in Statement Scope ===");
  enum Local { Low, Mid, High }
  println("Low  = ", Local.Low);   // 0
  println("Mid  = ", Local.Mid);   // 1
  println("High = ", Local.High);  // 2
end.
