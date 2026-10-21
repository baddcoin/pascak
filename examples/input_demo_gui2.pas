// examples/input_demo_gui2.pas — gui2 input demo (mouse + keyboard)
//
// Prereq: SDL2 + Termux:X11 (see hello_gui2.pas)
//
// Run: PASCAK_EXEC_POLICY=allow-all ./pascak_noASTnet --dev examples/input_demo_gui2.pas
//
// Try:
//   - Move mouse (red crosshair follows)
//   - Click left/right (button indicator top-left)
//   - Press keys (console logs event)
//   - Hold SHIFT/CTRL/ALT (modifier indicator top-right)
//   - ESC or X to close (15s auto-close)

var DONE := false;

begin
  if not gui2.init() then begin println("init failed"); sys.exit(1); end;
  if not gui2.window("Input Demo (gui2)", 800, 600) then
  begin println("window failed"); sys.exit(1); end;

  println("Move mouse / click / press keys. ESC or X to exit. Auto-close 15s.");

  var start := gui2.getTicks();
  while gui2.isOpen() and not DONE do begin
    if (gui2.getTicks() - start) > 15000 then break;

    var ev := gui2.poll();
    if ev == "quit" then break;
    if ev != "none" and
       (ev.startsWith("key:") or ev.startsWith("mousedown:") or
        ev.startsWith("mouseup:")) then
      println("event: " + ev);

    // Background
    gui2.clear(30, 40, 80);

    // Crosshair
    var mx := gui2.mouseX();
    var my := gui2.mouseY();
    gui2.line(0, my, 800, my, 200, 60, 60);
    gui2.line(mx, 0, mx, 600, 200, 60, 60);
    gui2.point(mx, my, 250, 250, 80);

    // Button indicators (top-left)
    if gui2.mouseButton(1) then
      gui2.rect(10, 10, 30, 30, 60, 220, 60)
    else
      gui2.outlineRect(10, 10, 30, 30, 100, 100, 100);
    if gui2.mouseButton(3) then
      gui2.rect(50, 10, 30, 30, 220, 60, 60)
    else
      gui2.outlineRect(50, 10, 30, 30, 100, 100, 100);

    // Modifier indicators (top-right)
    if gui2.keyMod("SHIFT") then gui2.rect(720, 10, 20, 20, 250, 250, 80);
    if gui2.keyMod("CTRL")  then gui2.rect(745, 10, 20, 20, 80, 250, 250);
    if gui2.keyMod("ALT")   then gui2.rect(770, 10, 20, 20, 250, 80, 250);

    gui2.present();
    gui2.delay(16);
  end;

  gui2.close();
  gui2.quit();
  println("✅ clean exit");
end.
