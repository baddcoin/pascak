// examples/gui2_counter.pas — interactive counter (click buttons)
//
// Prereq: pkg install sdl2 sdl2-ttf x11-repo termux-x11-nightly x11-utils
//         Termux:X11 APK installed
//         termux-x11 :0 -ac &  ;  export DISPLAY=:0
//
// Run: PASCAK_EXEC_POLICY=allow-all ./pascak_noASTnet --dev examples/gui2_counter.pas
//
// Click [-] [+] [RESET]. ESC to quit (or auto-close 60s).

var COUNT := 0;

function pointInRect(px, py, rx, ry, rw, rh) begin
  return px >= rx and px < rx + rw and py >= ry and py < ry + rh;
end;

begin
  println("gui2 counter demo");
  if not gui2.init() then begin println("init failed"); sys.exit(1); end;
  if not gui2.window("Counter (gui2)", 800, 600) then
  begin println("window failed"); sys.exit(1); end;

  var loaded := false;
  if not loaded then loaded := gui2.setFont("/system/fonts/Roboto-Regular.ttf", 40);
  if not loaded then loaded := gui2.setFont(
    "/data/data/com.termux/files/usr/share/fonts/TTF/DejaVuSans-Bold.ttf", 40);
  if not loaded then begin println("no font"); gui2.quit(); sys.exit(1); end;

  println("Click [-] [+] [RESET]. ESC to quit.");

  var start := gui2.getTicks();
  while gui2.isOpen() do begin
    if (gui2.getTicks() - start) > 60000 then break;

    var ev := gui2.poll();
    if ev == "quit" or ev == "key:ESC" then break;

    if ev == "mousedown:1" then begin
      var mx := gui2.mouseX();
      var my := gui2.mouseY();

      if pointInRect(mx, my, 200, 400, 150, 80) then
        COUNT := COUNT - 1
      else if pointInRect(mx, my, 450, 400, 150, 80) then
        COUNT := COUNT + 1
      else if pointInRect(mx, my, 325, 500, 150, 60) then
        COUNT := 0;
    end;

    gui2.clear(40, 50, 90);
    gui2.text(30, 30, "Counter Demo", 250, 250, 200);

    var countStr := str(COUNT);
    var m := gui2.measureText(countStr);
    var cx := toInteger((800 - toInteger(m["w"])) / 2);
    gui2.text(cx, 150, countStr, 250, 250, 100);

    gui2.rect(200, 400, 150, 80, 180, 60, 60);
    gui2.text(250, 415, "-", 255, 255, 255);

    gui2.rect(450, 400, 150, 80, 60, 180, 60);
    gui2.text(510, 415, "+", 255, 255, 255);

    gui2.rect(325, 500, 150, 60, 80, 80, 180);
    gui2.text(340, 515, "RESET", 255, 255, 255);

    gui2.present();
    gui2.delay(16);
  end;

  gui2.close();
  gui2.quit();
  println("clean exit (count=" + str(COUNT) + ")");
end.
