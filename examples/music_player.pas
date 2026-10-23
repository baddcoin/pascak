// examples/music_player.pas — full music player with progress + seek + volume
//
// Prereq: v0.11.3+ (musicPos, musicDuration, seekMusic, musicVolume)
//         OGG/MP3 file (M4A not supported — convert via ffmpeg)
//
// Run:
//   pascak_noASTnet --dev examples/music_player.pas <file.ogg>
//
// Controls:
//   SPACE = play/pause toggle
//   R = restart from 0
//   UP/DOWN = volume +/- 8
//   Click bar = seek to position
//   ESC = quit

var MUSIC_PATH := "";
var IS_PLAYING := false;
var DRAGGING := false;

function fmtTime(sec) begin
  if sec < 0 then sec := 0;
  var m := toInteger(sec / 60);
  var s := sec - m * 60;
  if s < 10 then return str(m) + ":0" + str(s);
  return str(m) + ":" + str(s);
end;

function pointInRect(px, py, rx, ry, rw, rh) begin
  return px >= rx and px < rx + rw and py >= ry and py < ry + rh;
end;

function tryFonts() begin
  if gui2.setFont("C:/Windows/Fonts/arial.ttf", 20) then return true;
  if gui2.setFont("C:/Windows/Fonts/segoeui.ttf", 20) then return true;
  if gui2.setFont("/system/fonts/Roboto-Regular.ttf", 20) then return true;
  if gui2.setFont("/data/data/com.termux/files/usr/share/fonts/TTF/DejaVuSans-Bold.ttf", 20) then return true;
  if gui2.setFont("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 20) then return true;
  return false;
end;

begin
  // Parse CLI: look for .ogg/.mp3/.wav
  var args := sys.args();
  var i := 0;
  while i < len(args) do begin
    var a := args[i];
    var la := lower(a);
    if (pos(".ogg", la) > 0) or (pos(".mp3", la) > 0)
       or (pos(".wav", la) > 0) or (pos(".m4a", la) > 0) then
    begin
      MUSIC_PATH := a;
      break;
    end;
    i := i + 1;
  end;

  if MUSIC_PATH == "" then begin
    var home := sys.env("HOME");
    MUSIC_PATH := home + "/testMusic.ogg";
  end;

  println("Music Player");
  println("  File: " + MUSIC_PATH);

  if not gui2.init() then begin println("init failed"); sys.exit(1); end;
  if not gui2.window("Music Player", 900, 500) then
  begin println("window failed"); sys.exit(1); end;

  var mus := gui2.loadMusic(MUSIC_PATH);
  if mus == 0 then begin
    println("Cannot load: " + MUSIC_PATH);
    if pos(".m4a", lower(MUSIC_PATH)) > 0 then
      println("M4A unsupported. Convert: ffmpeg -i " + MUSIC_PATH + " -c:a libvorbis out.ogg");
    gui2.close(); gui2.quit(); sys.exit(1);
  end;

  var fontOK := tryFonts();
  println("  Font: " + str(fontOK));

  var duration := gui2.musicDuration();
  println("  Duration: " + fmtTime(toInteger(duration)) + " (" + str(toInteger(duration)) + "s)");

  var vol := gui2.musicVolume();
  println("  Volume: " + str(vol));

  gui2.playMusic(0);
  IS_PLAYING := true;

  var barX := 60;
  var barY := 220;
  var barW := 780;
  var barH := 32;
  var testStart := gui2.getTicks();

  while gui2.isOpen() do begin
    // Auto-close 8s for test — remove for production
    if (gui2.getTicks() - testStart) > 8000 then break;

    var ev := gui2.poll();
    if ev == "quit" or ev == "key:ESC" then break;

    if ev == "key:SPACE" then begin
      if IS_PLAYING then begin
        gui2.pauseMusic();
        IS_PLAYING := false;
      end else begin
        gui2.resumeMusic();
        IS_PLAYING := true;
      end;
    end;

    if ev == "key:R" then begin
      gui2.stopMusic();
      gui2.playMusic(0);
      IS_PLAYING := true;
    end;

    if ev == "key:UP" then begin
      vol := gui2.musicVolume();
      vol := vol + 8;
      if vol > 128 then vol := 128;
      gui2.musicVolume(vol);
    end;

    if ev == "key:DOWN" then begin
      vol := gui2.musicVolume();
      vol := vol - 8;
      if vol < 0 then vol := 0;
      gui2.musicVolume(vol);
    end;

    if ev == "mousedown:1" then begin
      var mx := gui2.mouseX();
      var my := gui2.mouseY();
      if pointInRect(mx, my, barX, barY, barW, barH) then begin
        var frac := (mx - barX) / barW;
        var tgt := frac * duration;
        if tgt < 0 then tgt := 0;
        if tgt > duration then tgt := duration;
        gui2.seekMusic(tgt);
        DRAGGING := true;
      end;
    end;

    if ev == "mouseup:1" then
      DRAGGING := false;

    if ev == "mousemove" and DRAGGING then begin
      var mx2 := gui2.mouseX();
      if mx2 < barX then mx2 := barX;
      if mx2 > barX + barW then mx2 := barX + barW;
      var frac2 := (mx2 - barX) / barW;
      var tgt2 := frac2 * duration;
      if tgt2 < 0 then tgt2 := 0;
      if tgt2 > duration then tgt2 := duration;
      gui2.seekMusic(tgt2);
    end;

    gui2.clear(22, 24, 38);

    if fontOK then begin
      gui2.text(60, 40, "Music Player", 240, 220, 100);
      gui2.text(60, 80, MUSIC_PATH, 160, 170, 200);
    end;

    var pos := gui2.musicPos();
    if pos < 0 then pos := 0;
    if pos > duration then pos := duration;

    var filledW := 0;
    if duration > 0 then
      filledW := toInteger((barW * pos) / duration);
    if filledW > barW then filledW := barW;

    gui2.rect(barX, barY, barW, barH, 50, 55, 80);
    if filledW > 0 then
      gui2.rect(barX, barY, filledW, barH, 90, 200, 130);
    gui2.outlineRect(barX, barY, barW, barH, 180, 190, 220);

    if filledW > 0 then
      gui2.rect(barX + filledW - 2, barY - 4, 4, barH + 8, 250, 250, 250);

    if fontOK then begin
      gui2.text(barX, barY + 45,
        fmtTime(toInteger(pos)) + " / " + fmtTime(toInteger(duration)),
        220, 220, 220);
    end;

    if fontOK then begin
      if IS_PLAYING then
        gui2.text(60, 320, "[PLAYING]", 100, 220, 100)
      else
        gui2.text(60, 320, "[PAUSED]", 220, 180, 100);

      vol := gui2.musicVolume();
      gui2.text(60, 360, "Volume: " + str(vol) + "/128", 180, 200, 220);
    end;

    var volBarX := 250;
    var volBarW := 300;
    var volFilled := toInteger((volBarW * vol) / 128);
    gui2.rect(volBarX, 360, volBarW, 20, 50, 55, 80);
    gui2.rect(volBarX, 360, volFilled, 20, 100, 180, 240);
    gui2.outlineRect(volBarX, 360, volBarW, 20, 180, 190, 220);

    if fontOK then
      gui2.text(60, 440,
        "SPACE=play/pause  R=restart  UP/DOWN=volume  Click bar=seek  ESC=quit",
        140, 140, 160);

    gui2.present();
    gui2.delay(16);

    if IS_PLAYING and (duration > 0) and (pos >= duration - 0.1) then begin
      gui2.stopMusic();
      IS_PLAYING := false;
    end;
  end;

  gui2.stopMusic();
  gui2.freeMusic();
  gui2.close();
  gui2.quit();
  println("clean exit");
end.
