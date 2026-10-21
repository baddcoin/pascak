// examples/text_demo_gui2.pas — gui2 text rendering demo
//
// Prereq:
//   pkg install sdl2 sdl2-ttf x11-repo termux-x11-nightly x11-utils
//   Termux:X11 APK installed
//   termux-x11 :0 -ac & ; export DISPLAY=:0
//
// Run: PASCAK_EXEC_POLICY=allow-all ./pascak_noASTnet --dev examples/text_demo_gui2.pas
//
// Shows: colored text, text on colored background, centered text via measureText.
// Auto-close 10s or ESC / X.

begin
  if not gui2.init() then begin println("init failed"); sys.exit(1); end;
  if not gui2.window("Text Demo (gui2)", 800, 600) then
  begin println("window failed"); sys.exit(1); end;

  // Try fonts in priority order (absolute path — no sandbox check)
  var loaded := false;
  if not loaded then loaded := gui2.setFont("/system/fonts/Roboto-Regular.ttf", 24);
  if not loaded then loaded := gui2.setFont(
    "/data/data/com.termux/files/usr/share/fonts/TTF/DejaVuSans-Bold.ttf", 24);
  if not loaded then begin
    println("no font available (try: pkg install ttf-dejavu)");
    gui2.close(); gui2.quit(); sys.exit(1);
  end;

  println("Font loaded. Close in 10s or press ESC.");

  var start := gui2.getTicks();
  while gui2.isOpen() do begin
    if (gui2.getTicks() - start) > 10000 then break;
    var ev := gui2.poll();
    if ev == "quit" or ev == "key:ESC" then break;

    gui2.clear(30, 40, 80);

    // Title
    gui2.text(50, 50, "Pascak gui2", 250, 250, 100);
    gui2.text(50, 100, "Press ESC to quit", 200, 200, 200);

    // Color row
    gui2.text(50, 160, "Red",   220, 60, 60);
    gui2.text(150, 160, "Green", 60, 220, 60);
    gui2.text(280, 160, "Blue",  60, 60, 220);

    // Text on colored box
    gui2.rect(50, 240, 300, 60, 60, 100, 200);
    gui2.text(70, 255, "On blue box", 255, 255, 255);

    // Center via measureText
    var m := gui2.measureText("Centered");
    var cx := (800 - toInteger(m["w"])) / 2;
    gui2.text(toInteger(cx), 400, "Centered", 250, 250, 250);

    gui2.present();
    gui2.delay(16);
  end;

  gui2.close();
  gui2.quit();
  println("✅ clean exit");
end.
