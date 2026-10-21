// examples/gui2_image_viewer.pas — image viewer with 1x + 2x + 4x
//
// Prereq:
//   pkg install sdl2 sdl2-ttf sdl2-image x11-repo termux-x11-nightly
//   Termux:X11 APK installed
//   termux-x11 :0 -ac &  ;  export DISPLAY=:0
//
// Run:
//   PASCAK_EXEC_POLICY=allow-all ./pascak_noASTnet --dev examples/gui2_image_viewer.pas <image.png>
//
// Or hardcode: edit IMG_PATH below.
//
// Shows: texture at native size, 2x, 4x scale + metadata labels.
// ESC or X to close (auto-close 30s).

var IMG_PATH := "";

function pickImage() begin
  // CLI: 1st arg is image path (before --dev, or after)
  var args := sys.args();
  var i := 0;
  while i < len(args) do begin
    var a := args[i];
    if a != "" and (pos(".png", lower(a)) > 0 or pos(".jpg", lower(a)) > 0) then
      return a;
    i := i + 1;
  end;

  // Fallback: try common paths
  var home := sys.env("HOME");
  var candidates := [
    home + "/test_tex.png",
    "/data/data/com.termux/files/usr/share/icons/hicolor/48x48/apps/freedroid.png"
  ];
  for p in candidates do begin
    if fileExists(p) then return p;
  end;
  return null;
end;

begin
  println("gui2 image viewer");
  if not gui2.init() then begin println("init failed"); sys.exit(1); end;
  if not gui2.window("Image Viewer (gui2)", 900, 700) then
  begin println("window failed"); sys.exit(1); end;

  var loaded := false;
  if not loaded then loaded := gui2.setFont("/system/fonts/Roboto-Regular.ttf", 20);
  if not loaded then loaded := gui2.setFont(
    "/data/data/com.termux/files/usr/share/fonts/TTF/DejaVuSans-Bold.ttf", 20);

  if IMG_PATH = "" then
    IMG_PATH := pickImage();

  if IMG_PATH == null then begin
    println("no image found (pass path as arg or place test_tex.png in $HOME)");
    gui2.close(); gui2.quit(); sys.exit(1);
  end;

  println("Loading: " + IMG_PATH);
  var tex := gui2.loadTexture(IMG_PATH);
  if tex == 0 then begin
    println("loadTexture failed: " + IMG_PATH);
    gui2.close(); gui2.quit(); sys.exit(1);
  end;

  var sz := gui2.texSize(tex);
  var tw := toInteger(sz["w"]);
  var th := toInteger(sz["h"]);
  println("Loaded " + str(tw) + "x" + str(th));

  var start := gui2.getTicks();
  while gui2.isOpen() do begin
    if (gui2.getTicks() - start) > 30000 then break;
    var ev := gui2.poll();
    if ev == "quit" or ev == "key:ESC" then break;

    gui2.clear(20, 25, 40);

    if loaded then begin
      gui2.text(30, 20, "Image: " + IMG_PATH, 200, 200, 200);
      gui2.text(30, 50, "Native: " + str(tw) + " x " + str(th), 250, 250, 100);
    end;

    // Row 1: 1x at (30, 100)
    gui2.drawTexture(tex, 30, 100);
    if loaded then gui2.text(30, 100 + th + 5, "1x", 250, 250, 250);

    // Row 1: 2x at (30 + tw + 30, 100)
    gui2.drawTextureScaled(tex, 30 + tw + 30, 100, tw * 2, th * 2);
    if loaded then gui2.text(30 + tw + 30, 100 + th * 2 + 5, "2x", 250, 250, 250);

    // Row 2: 4x at (30, 100 + max(th*2, 150) + 40)
    var y2 := 100 + th * 2 + 60;
    if y2 + th * 4 < 700 then begin
      gui2.drawTextureScaled(tex, 30, y2, tw * 4, th * 4);
      if loaded then gui2.text(30, y2 - 25, "4x", 250, 250, 250);
    end;

    gui2.present();
    gui2.delay(16);
  end;

  gui2.freeTexture(tex);
  gui2.close();
  gui2.quit();
  println("clean exit");
end.
