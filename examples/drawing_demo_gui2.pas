// examples/drawing_demo_gui2.pas — gui2 drawing primitives demo
//
// Prereq: SDL2 + Termux:X11 (see examples/hello_gui2.pas)
//
// Run:
//   PASCAK_EXEC_POLICY=allow-all ./pascak_noASTnet --dev examples/drawing_demo_gui2.pas
//
// Shows: blue bg, red filled rect, green outline, yellow line, magenta dots.
// Auto-close 8s or ESC / X to close.

begin
  println("gui2 drawing demo");

  if not gui2.init() then begin println("❌ init"); sys.exit(1); end;
  if not gui2.window("Drawing Demo (gui2)", 800, 600) then begin println("❌ window"); sys.exit(1); end;

  println("Window 800x600. Auto-close 8s (ESC / X to close early).");

  var start := gui2.getTicks();
  var frames := 0;

  while gui2.isOpen() do begin
    if (gui2.getTicks() - start) > 8000 then break;

    var ev := gui2.poll();
    if ev == "quit" or ev == "key:ESC" then break;

    // Background — visible blue (not too dark)
    gui2.clear(60, 80, 200);

    // Grid — light gray/blue
    var i := 0;
    while i <= 800 do begin
      gui2.line(i, 0, i, 600, 100, 120, 220);
      i := i + 50;
    end;
    var j := 0;
    while j <= 600 do begin
      gui2.line(0, j, 800, j, 100, 120, 220);
      j := j + 50;
    end;

    // Red filled rect (top-left)
    gui2.rect(100, 100, 200, 150, 220, 60, 60);

    // Green outline rect (top-right)
    gui2.outlineRect(500, 100, 200, 150, 60, 220, 60);

    // Yellow X cross (bottom-center)
    gui2.line(400, 400, 550, 500, 250, 250, 80);
    gui2.line(550, 400, 400, 500, 250, 250, 80);

    // Magenta diagonal dots (bottom-left)
    var k := 0;
    while k < 100 do begin
      gui2.point(50 + k, 550 - k, 250, 80, 250);
      k := k + 2;
    end;

    gui2.present();
    gui2.delay(16);
    frames := frames + 1;
  end;

  println("Frames: " + str(frames));
  gui2.close();
  gui2.quit();
  println("✅ clean exit");
end.
