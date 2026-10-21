// examples/gui2_paint.pas — mouse drawing canvas
//
// Prereq: same as gui2_counter.pas
//
// Run: PASCAK_EXEC_POLICY=allow-all ./pascak_noASTnet --dev examples/gui2_paint.pas
//
// Hold left mouse to draw. Click palette (bottom) to change color.
// Click CLR (top-right) to clear. ESC to quit (auto-close 60s).

var COLORS := [
  {"r": 220, "g": 60,  "b": 60},
  {"r": 60,  "g": 220, "b": 60},
  {"r": 60,  "g": 60,  "b": 220},
  {"r": 250, "g": 250, "b": 100},
  {"r": 255, "g": 255, "b": 255}
];

var STROKES := [];

begin
  println("gui2 paint demo");
  if not gui2.init() then begin println("init failed"); sys.exit(1); end;
  if not gui2.window("Paint (gui2)", 800, 600) then
  begin println("window failed"); sys.exit(1); end;

  var loaded := false;
  if not loaded then loaded := gui2.setFont("/system/fonts/Roboto-Regular.ttf", 18);
  if not loaded then loaded := gui2.setFont(
    "/data/data/com.termux/files/usr/share/fonts/TTF/DejaVuSans-Bold.ttf", 18);
  if not loaded then begin println("no font"); gui2.quit(); sys.exit(1); end;

  println("Draw with left mouse. Palette at bottom. CLR top-right. ESC to quit.");

  var colorIdx := 0;
  var lastX := -1;
  var lastY := -1;
  var drawing := false;

  var start := gui2.getTicks();
  while gui2.isOpen() do begin
    if (gui2.getTicks() - start) > 60000 then break;

    var ev := gui2.poll();
    if ev == "quit" or ev == "key:ESC" then break;

    var mx := gui2.mouseX();
    var my := gui2.mouseY();

    if ev == "mousedown:1" then begin
      if my >= 550 then begin
        var i := 0;
        while i < len(COLORS) do begin
          var bx := 20 + i * 60;
          if mx >= bx and mx < bx + 50 and my >= 560 and my < 590 then begin
            colorIdx := i;
            break;
          end;
          i := i + 1;
        end;
      end
      else if mx >= 720 and mx < 780 and my >= 10 and my < 40 then begin
        STROKES := [];
      end
      else if my < 540 then begin
        drawing := true;
        lastX := mx;
        lastY := my;
      end;
    end;

    if ev == "mouseup:1" then begin
      drawing := false;
      lastX := -1;
      lastY := -1;
    end;

    if ev == "mousemove" and drawing and lastX >= 0 then begin
      if len(STROKES) < 10000 then begin
        var col := COLORS[colorIdx];
        push(STROKES, {"x1": lastX, "y1": lastY, "x2": mx, "y2": my,
                       "r": col["r"], "g": col["g"], "b": col["b"]});
        lastX := mx;
        lastY := my;
      end;
    end;

    gui2.clear(30, 30, 40);

    var i := 0;
    while i < len(STROKES) do begin
      var s := STROKES[i];
      gui2.line(s["x1"], s["y1"], s["x2"], s["y2"],
                s["r"], s["g"], s["b"]);
      i := i + 1;
    end;

    var j := 0;
    while j < len(COLORS) do begin
      var col := COLORS[j];
      var bx := 20 + j * 60;
      if j == colorIdx then
        gui2.rect(bx - 3, 557, 56, 36, 255, 255, 255);
      gui2.rect(bx, 560, 50, 30, col["r"], col["g"], col["b"]);
      j := j + 1;
    end;

    gui2.rect(720, 10, 60, 30, 180, 60, 60);
    gui2.text(730, 12, "CLR", 255, 255, 255);

    gui2.present();
    gui2.delay(16);
  end;

  gui2.close();
  gui2.quit();
  println("clean exit (" + str(len(STROKES)) + " strokes)");
end.
