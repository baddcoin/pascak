// examples/gui2_hidpi.pas
// Pascak v1.10.0: Hi-DPI scaling for native GUI (SDL2)
//
// On high-DPI displays (Retina, 4K, Android 2-3x scale), gui2.window(400,300)
// creates physically 400x300 window that appears tiny. With autoScale:
//   - logical size stays 400x300 (drawing coords unaffected)
//   - physical window scales to (400*scale) x (300*scale)
//   - mouse coords divide by scale → return logical

begin
  gui2.init();

  // Detect current DPI scale (env override: PASCAK_GUI2_SCALE=2/3)
  println("Detected DPI scale: ", gui2.getScale());

  // Opt-in auto-scale
  gui2.setAutoScale(true);

  // Draw logical 640x480 — physically scaled to (640*scale) x (480*scale)
  var win := gui2.newWindow("Hi-DPI Demo", 640, 480);
  if win <= 0 then begin
    println("Failed to create window (no X11?)");
    gui2.quit();
    exit;
  end;

  gui2.setFont("/data/data/com.termux/files/usr/share/fonts/TTF/DejaVuSans.ttf", 16);

  var running := true;
  var frame := 0;
  while running and gui2.isOpen(win) do begin
    gui2.clear(20, 20, 30);

    // Title text
    gui2.text(20, 20, "Hi-DPI Test — scale=" + str(gui2.getScale()), 255, 255, 255);
    gui2.text(20, 60, "Logical 640x480, physical scaled", 200, 200, 200);
    gui2.text(20, 100, "Frame: " + str(frame), 200, 200, 200);

    // Colored rect (draws at logical 100x100 box at 50,150)
    gui2.rect(50, 150, 100, 100, 100, 200, 100);
    gui2.outlineRect(50, 150, 100, 100, 255, 255, 255);

    // Mouse position (returns logical coords)
    var mx := gui2.mouseX();
    var my := gui2.mouseY();
    gui2.text(20, 300, "Mouse (logical): " + str(mx) + ", " + str(my), 255, 200, 0);
    gui2.point(mx, my);

    gui2.present(win);

    if not gui2.poll() then running := false;
    gui2.delay(16);
    frame := frame + 1;
  end;

  gui2.close(win);
  gui2.quit();
end.
