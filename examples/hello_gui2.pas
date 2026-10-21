// examples/hello_gui2.pas — Minimal SDL2 window (Pascak gui2)
//
// Prereq:
//   pkg install sdl2 x11-repo termux-x11-nightly x11-utils
//   Termux:X11 APK installed (Android, from GitHub nightly)
//   termux-x11 :0 -ac &
//   export DISPLAY=:0
//
// Run:
//   PASCAK_EXEC_POLICY=allow-all ./pascak_noASTnet --dev examples/hello_gui2.pas
//
// This example: opens 800x600 window, solid blue background, auto-close 5s
// or press ESC / click X to close early.

begin
  println("gui2 hello — SDL2 window demo");

  if not gui2.init() then begin
    println("❌ gui2.init failed");
    sys.exit(1);
  end;

  if not gui2.window("Hello SDL2 (Pascak gui2)", 800, 600) then begin
    println("❌ gui2.window failed");
    sys.exit(1);
  end;

  println("Window 800x600. Auto-close 5s (ESC / X to close early).");

  var start := gui2.getTicks();
  var frames := 0;

  while gui2.isOpen() do begin
    // Auto-close 5s
    if (gui2.getTicks() - start) > 5000 then begin
      println("  auto-close (5s)");
      break;
    end;

    // Event handling
    var ev := gui2.poll();
    if ev == "quit" then begin
      println("  window closed");
      break;
    end;
    if ev == "key:ESC" then begin
      println("  ESC pressed");
      break;
    end;

    // Render — solid blue background (RGB 30,100,200)
    gui2.clear(30, 100, 200);
    gui2.present();

    gui2.delay(16);   // ~60 FPS
    frames := frames + 1;
  end;

  var elapsed := gui2.getTicks() - start;
  println("Frames: " + str(frames) + " | Elapsed: " + str(elapsed) + "ms");

  gui2.close();
  gui2.quit();
  println("✅ Clean exit");
end.
