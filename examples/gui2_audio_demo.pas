// examples/gui2_audio_demo.pas — audio playback demo
//
// Prereq:
//   pkg install sdl2 sdl2-ttf sdl2-mixer x11-repo termux-x11-nightly
//   Termux:X11 APK installed
//   termux-x11 :0 -ac &  ;  export DISPLAY=:0
//   Audio hardware (or SDL_AUDIODRIVER=dummy for headless test)
//
// Run:
//   PASCAK_EXEC_POLICY=allow-all ./pascak_noASTnet --dev examples/gui2_audio_demo.pas <sound.wav>
//
// Demonstrates: load music, play/pause/resume/stop, load sound, click to play SFX.
// ESC or X to exit (auto-close 30s).

var MUSIC_PATH := "";
var SOUND_PATH := "";

begin
  println("gui2 audio demo");
  if not gui2.init() then begin println("init failed"); sys.exit(1); end;
  if not gui2.window("Audio Demo (gui2)", 800, 500) then
  begin println("window failed"); sys.exit(1); end;

  var loaded := false;
  if not loaded then loaded := gui2.setFont("/system/fonts/Roboto-Regular.ttf", 22);
  if not loaded then loaded := gui2.setFont(
    "/data/data/com.termux/files/usr/share/fonts/TTF/DejaVuSans-Bold.ttf", 22);

  // CLI: 1st arg with .wav/.ogg/.mp3
  var args := sys.args();
  var i := 0;
  while i < len(args) do begin
    var a := args[i];
    if a != "" and (pos(".wav", lower(a)) > 0 or pos(".ogg", lower(a)) > 0 or pos(".mp3", lower(a)) > 0) then begin
      SOUND_PATH := a;
      break;
    end;
    i := i + 1;
  end;

  // Fallback: try $HOME/test_beep.wav directly (no fileExists — sandbox rejects absolute paths)
  var home := sys.env("HOME");
  if SOUND_PATH == "" then begin
    var tryPath := home + "/test_beep.wav";
    if gui2.loadSound(tryPath) > 0 then begin
      SOUND_PATH := tryPath;
    end;
  end;

  if SOUND_PATH == "" then begin
    println("no sound file (pass WAV/OGG/MP3 as arg, or place $HOME/test_beep.wav)");
    gui2.close(); gui2.quit(); sys.exit(1);
  end;

  MUSIC_PATH := SOUND_PATH;
  println("Loading: " + SOUND_PATH);

  var mus := gui2.loadMusic(MUSIC_PATH);
  var snd := gui2.loadSound(SOUND_PATH);
  println("music handle: " + str(mus));
  println("sound handle: " + str(snd));

  var musicPlaying := false;
  var sndPlays := 0;

  var start := gui2.getTicks();
  while gui2.isOpen() do begin
    if (gui2.getTicks() - start) > 30000 then break;
    var ev := gui2.poll();
    if ev == "quit" or ev == "key:ESC" then break;

    // Space: toggle music
    if ev == "key:SPACE" then begin
      if musicPlaying then begin
        gui2.stopMusic();
        musicPlaying := false;
        println("stopMusic");
      end else begin
        gui2.playMusic(0);
        musicPlaying := true;
        println("playMusic");
      end;
    end;

    // P: pause / R: resume
    if ev == "key:P" then begin gui2.pauseMusic(); println("pauseMusic"); end;
    if ev == "key:R" then begin gui2.resumeMusic(); println("resumeMusic"); end;

    // Click: play sound effect
    if ev == "mousedown:1" and snd > 0 then begin
      gui2.playSound(snd, 0);
      sndPlays := sndPlays + 1;
      println("playSound (" + str(sndPlays) + ")");
    end;

    // Render
    gui2.clear(40, 50, 90);

    if loaded then begin
      gui2.text(40, 40, "Audio Demo", 250, 250, 100);
      gui2.text(40, 100, "Music: " + str(mus), 200, 200, 200);
      gui2.text(40, 140, "Sound: " + str(snd), 200, 200, 200);
      gui2.text(40, 200, "SPACE = toggle music", 180, 220, 180);
      gui2.text(40, 240, "P = pause  R = resume", 180, 220, 180);
      gui2.text(40, 280, "Click = play sound", 180, 220, 180);
      if musicPlaying then
        gui2.text(40, 360, "[MUSIC PLAYING]", 60, 250, 60)
      else
        gui2.text(40, 360, "[STOPPED]", 200, 100, 100);
      gui2.text(40, 400, "Sound plays: " + str(sndPlays), 200, 200, 200);
    end;

    // Big button visual
    gui2.rect(600, 200, 150, 150, 200, 60, 60);
    gui2.rect(620, 220, 110, 110, 250, 80, 80);

    gui2.present();
    gui2.delay(16);
  end;

  // Cleanup
  if mus > 0 then begin gui2.stopMusic(); gui2.freeMusic(); end;
  if snd > 0 then gui2.freeSound(snd);

  gui2.close();
  gui2.quit();
  println("clean exit (snd plays=" + str(sndPlays) + ")");
end.
