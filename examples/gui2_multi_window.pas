// examples/gui2_multi_window.pas — two windows side-by-side
//
// Prereq: v1.0.0+ (multi-window API)
//         Termux:X11 or desktop with SDL2
//
// Run: PASCAK_EXEC_POLICY=allow-all ./pascak_noASTnet --dev examples/gui2_multi_window.pas
//
// Controls:
//   1 = focus window 1
//   2 = focus window 2
//   ESC = quit (auto-close 15s)
//
// Demonstrates: newWindow, focusWindow, listWindows, getFocusedWindow,
// closeWindow. Each window has independent renderer + color.

begin
  println("gui2 multi-window demo");
  if not gui2.init() then begin println("init failed"); sys.exit(1); end;

  var w1 := gui2.newWindow("Window 1 (RED)", 400, 300);
  var w2 := gui2.newWindow("Window 2 (GREEN)", 400, 300);
  if w1 == 0 or w2 == 0 then begin
    println("newWindow failed");
    gui2.quit();
    sys.exit(1);
  end;

  println("Windows created: w1=" + str(w1) + " w2=" + str(w2));
  println("List: " + jsonStringify(gui2.listWindows()));

  var fontOK := false;
  if not fontOK then fontOK := gui2.setFont("/system/fonts/Roboto-Regular.ttf", 28);
  if not fontOK then fontOK := gui2.setFont(
    "/data/data/com.termux/files/usr/share/fonts/TTF/DejaVuSans-Bold.ttf", 28);

  var start := gui2.getTicks();
  while gui2.isOpen() do begin
    if (gui2.getTicks() - start) > 15000 then break;

    var ev := gui2.poll();
    if ev == "quit" or ev == "key:ESC" then break;
    if ev == "key:1" then gui2.focusWindow(w1);
    if ev == "key:2" then gui2.focusWindow(w2);

    // Window 1: red theme
    gui2.focusWindow(w1);
    gui2.clear(180, 40, 40);
    if fontOK then begin
      gui2.text(30, 40, "Window 1", 255, 255, 255);
      gui2.text(30, 90, "RED theme", 255, 220, 220);
      gui2.text(30, 240, "[1] focus | [ESC] quit", 200, 200, 200);
    end;
    gui2.rect(30, 130, 100, 60, 255, 200, 0);
    gui2.present();

    // Window 2: green theme
    gui2.focusWindow(w2);
    gui2.clear(40, 180, 40);
    if fontOK then begin
      gui2.text(30, 40, "Window 2", 255, 255, 255);
      gui2.text(30, 90, "GREEN theme", 220, 255, 220);
      gui2.text(30, 240, "[2] focus | [ESC] quit", 200, 200, 200);
    end;
    gui2.rect(30, 130, 100, 60, 200, 100, 255);
    gui2.present();

    gui2.delay(16);
  end;

  gui2.close();
  gui2.quit();
  println("clean exit");
end.
