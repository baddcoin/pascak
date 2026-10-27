📋 Ringkasan Lengkap Proyek Pascak VM — Untuk Sesi Chat Baru

---

🎯 Identitas Proyek

Pascak VM — platform scripting full-stack dalam FreePascal. Interpreter + VM + stdlib lengkap, cross-platform (Termux/Linux/Windows/macOS).

Repo GitHub: https://github.com/baddcoin/pascak
Remote: SSH (git@github.com:baddcoin/pascak.git)
Lokal: ~/storage/downloads/termux/pascak (work dir utama) + /storage/emulated/0/Download/termux/pascak (clone cadangan)
Binary: pascak_noASTnet (~3 MB)

---

🚨 Setup Wajib di Awal Sesi Baru

```bash
# 1. Clone / update dari GitHub
cd ~/storage/downloads/termux/pascak
git pull origin main --tags
git log --oneline --decorate -15
git status --short
git tag --list | sort -V

# 2. Baca struktur proyek
ls *.pas
wc -l pascak_engine.pas   # ~46,000 baris (monolith utama)

# 3. Install dependencies (kalau belum)
pkg install sdl2 sdl2-ttf sdl2-image sdl2-mixer x11-repo \
            termux-x11-nightly x11-utils ttf-dejavu ffmpeg

# 4. Setup GUI testing (kalau perlu)
# Terminal 1:
termux-x11 :0 -ac &
# Terminal 2:
export DISPLAY=:0
export SDL_AUDIODRIVER=dummy    # jika no audio hardware
```

Untuk test binary di Termux: /storage/ = noexec → wajib copy:

```bash
cp pascak_noASTnet "$HOME/pascak_test"
chmod +x "$HOME/pascak_test"
cd "$HOME"
timeout 20 env PASCAK_EXEC_POLICY=allow-all ./pascak_test --dev test.pas
```

---

✅ Status Terkini (v1.0.2)

Item Status
HEAD 5dbcb8c (tag: v1.0.2)
Remote sync ✅ 0 ahead
Tags 22 total (v0.4.0 → v1.0.2)
Native GUI (SDL2) ✅ 100% (48 API)
HTTP/2 client ✅ Multiplexing + async (3-5 concurrent reliable)
Browser GUI ✅ HTTP + HTTPS
Network/WS/TLS/SQLite ✅ Complete
Docs ✅ 27 bab tutorial + 11 cookbook + API reference
Working tree Clean

Milestone Chain (22 tags)

```
v0.4.0  VSCode LSP client
v0.5.0  B.7b (embedding) + elif
v0.6.0  Browser GUI
v0.6.1  Tutorial Bab 26/27 + Cookbook #11
v0.7.0  GUI HTTPS
v0.7.1  GUI HTTPS docs
v0.8.0  H2 Session 1 (reader thread + TLS context fix)
v0.8.1  DCE for..in fix
v0.9.0  H2 Session 2 (true multiplexing)
v0.9.1  Tutorial 24.7 clarity
v0.10.0 Native GUI foundation (SDL2 window)
v0.10.1 Drawing primitives
v0.10.2 Keyboard + mouse
v0.10.3 Text rendering (SDL_ttf)
v0.10.4 Silent exit bug fix
v0.11.0 Tutorial Bab 28 + examples
v0.11.1 Image textures (SDL_image)
v0.11.2 Audio (SDL_mixer)
v0.11.3 Music metadata (pos/duration/seek/volume)
v1.0.0  Multi-window
v1.0.1  http.get2Async
v1.0.2  H2 async reliability ← HEAD
```

---

🚧 WORK IN PROGRESS — v1.1.0 Phase 1 (UNCOMMITTED)

Sesi terakhir = debug 4 fitur bahasa baru:

Fitur Target Status
?. optional chaining user?.name, cfg?.db?.host ⚠️ BUG — stack underflow
?? null-coalescing null ?? 42 ✅ Build OK, belum fully verified
enum enum Color { Red, Green, Blue } 🔲 Belum dimulai
Destructuring var {a,b} = obj, var [x,y] = arr 🔲 Belum dimulai

Current Bug (CRITICAL — next session priority)

Symptom: n?.name saat n = null → Stack Underflow saat pemanggilan fungsi/method.

File yang dimodifikasi (belum commit):

· pascak_engine.pas — patch sudah applied tapi ada bug runtime

Yang sudah diimplementasi:

· ✅ Tokens ttOptionalDot, ttNullCoalesce
· ✅ Opcodes opcJumpIfNull, opcJumpIfNotNull
· ✅ TOpKind opNullCoalesce
· ✅ Lexer handle ?. dan ??
· ✅ Parser TMemberAccessNode.IsOptional field
· ✅ Parser ParseNullCoalesce (di antara ParseLogicalAnd dan ParseLogicalOr)
· ✅ Compiler emit ?. dan ??
· ✅ VM handlers opcJumpIfNull / opcJumpIfNotNull
· ✅ Helper_GetNativeProperty dict nil-wrap
· ✅ Optimizer recognize new jump opcodes (jump-target marking + offset remap)
· ⚠️ Runtime masih stack underflow di null?.name

Hipotesis bug terbaru: kemungkinan optimizer menghapus opcJump +0 (useless jump) tapi tidak remap operand opcJumpIfNull dengan benar, atau masalah IsJumpTarget marking setelah dead-code elimination.

Lokasi kode terkait:

· Lexer: sekitar line 11100 ('?': case)
· ParseFactor postfix: sekitar line 11630-11750
· ParseNullCoalesce: sekitar line 11895
· Compiler ?.: sekitar line 15520
· Compiler ??: sekitar line 15550+
· VM opcJumpIfNull/NotNull: sekitar line 17940
· Optimizer jump target: sekitar line 13608
· Optimizer jump remap: sekitar line 13880
· Helper_GetNativeProperty: line 3466

Backup tersedia:

```bash
# Kalau mau rollback ke v1.0.2 sebelum Phase 1:
cd ~/storage/downloads/termux/pascak
git reset --hard HEAD
# Semua patch Phase 1 hilang, mulai bersih
```

Test script Phase 1 (jalankan dengan binary hasil build):

```pascal
begin
  var u := {"name": "Alice"};
  var n := null;
  println(u?.name);         // harusnya "Alice"
  println(n?.name);         // harusnya null — BUG: crash di sini
  println(null ?? 42);      // harusnya 42
  println(false ?? 42);     // harusnya false
end.
```

Plan Phase Lanjutan (setelah Phase 1 fix)

· Phase 2: enum Color { Red, Green, Blue } → dict via opcBuildDict + opcDefineConstGlobal. Top-level only, immutable.
· Phase 3: Destructuring var {a,b} = obj, var [x,y] = arr → reuse opcDup + opcGetIndex + opcSetLocal.
· Phase 4: Commit + tag v1.1.0 milestone.

---

📋 Backlog Prioritas (post-v1.0.2)

Priority Task Effort
🔴 Urgent Fix Phase 1 bug — ?. stack underflow ~1-2 jam
🟡 Medium Phase 2 (enum) + Phase 3 (destructuring) ~2 jam
🟡 Medium H2 Session 4c — client rate limiter + auto-retry GOAWAY ~2-3 jam
🟡 Medium GUI hot-reload — browser file watcher ~2 jam
🟡 Medium LSP Phase 4 — signature help ~3 jam
🟢 Low H2 flow control WINDOW_UPDATE (>64KB body) ~3-4 jam
🟢 Low Tutorial Bab 28.14 (audio control section) ~1 jam
🟢 Low Tutorial 28.12 rewrite (48 API summary) ~30 menit
🟢 Low GUI2-R — raylib backend alternative (parallel gui3 namespace) ~10-13 jam

---

🏗️ Arsitektur Proyek

Monolith utama

· pascak_engine.pas (~46,000 lines) — lexer, parser, compiler, VM, semua natives, GUI modules, GC, worker pool, H2 helpers, dst. Semua di sini.

Modul terpisah (uses clause)

File Purpose
pascak_h2.pas HTTP/2 frame layer (RFC 7540)
pascak_h2_hpack.pas HPACK encoder/decoder (RFC 7541)
pascak_h2_huffman.pas Huffman codec
pascak_h2_conn.pas H2 multiplexed connection + singleflight pool
pascak_http.pas HTTP/1.1 parse + build
pascak_tls.pas libssl binding (verify, SNI, ALPN)
pascak_net.pas TCP + pure Pascal DNS resolver
pascak_crypto.pas SHA/AES/HMAC/PBKDF2/random
pascak_proc.pas Exec policy + rlimit + env sanitize
pascak_fs.pas FS helpers (glob, walkDir, stat)
pascak_time.pas Date/time manipulation
pascak_websocket.pas WS server/client (RFC 6455)
pascak_wsevloop.pas WS event loop (10K concurrent)
pascak_pkg.pas + pascak_pkg_registry.pas Package manager
pascak_embed.pas Subprocess embedding helper

Docs

· docs/pascak_api.md (~5,045 lines) — API reference
· docs/tutorial.md (~4,369 lines, 27 bab) — tutorial lengkap
· docs/cookbook.md (~1,276 lines, 11 recipes) — production patterns
· CHANGELOG.md — Keep a Changelog + SemVer

Examples (examples/)

· hello_ffi.pas, parallel_fetch.pas, sqlite_client.pas, http_server.pas (base)
· hello_gui.pas, todo_gui.pas, chat_gui.pas, todo_gui_tls.pas (browser GUI)
· hello_gui2.pas, drawing_demo_gui2.pas, input_demo_gui2.pas, text_demo_gui2.pas, gui2_counter.pas, gui2_paint.pas, gui2_image_viewer.pas, gui2_audio_demo.pas, music_player.pas, gui2_multi_window.pas (native GUI)

---

🔑 Fitur Bahasa Pascak (yang Sudah Ada)

Basic: var, const, if/then/else, case/of, while, repeat/until, for/to/downto/step, for/in, break, continue, return, defer, yield, lock, throw

Types: numeric (double), string, boolean, null, array, dict, object, function, native, class, record, pointer, DLL handle, coroutine

Advanced: lambda, ternary ?:, F-string f"...", spread ..., list comprehension [x*2 for x in arr if x>0], multi-assignment a, b = [1,2], class inheritance, try/catch/finally + type filter

Built-in modules: sys, math, crypto, time, net, http, ws, fs, dll, tls, native, hardware, gui (browser), gui2 (SDL2 native), log, config, signal, metrics, health, pkg

Embedding: subprocess (pascak_embed.pas) + in-process (pascak_engine.pas → ExecuteEngine, RegisterNative)

Dev tools: --lint, --fmt, --test, --repl, --lsp + VSCode extension

---

⚠️ Gotchas & Workarounds (WAJIB INGAT)

Termux

1. /storage/ noexec — binary wajib copy ke $HOME untuk run
2. /tmp tidak ada — pakai $HOME atau $TMPDIR ($PREFIX/tmp)
3. X11 socket di $PREFIX/tmp/.X11-unix/, bukan /tmp/.X11-unix/
4. Termux:X11 APK harus di-install terpisah dari GitHub nightly
5. SDL2 loading — pakai absolute path /data/data/com.termux/files/usr/lib/libSDL2-2.0.so (bare name gagal karena whitelist resolver)
6. Package names: sdl2-ttf, sdl2-image, sdl2-mixer (hyphen, bukan underscore)
7. MESA warning (ZINK: failed to choose pdev) — harmless, software render fallback
8. SDL_AUDIODRIVER=dummy untuk audio testing tanpa hardware

Code/Pascal

1. Nama reserved: Packed, Absolute, Override, Property, dll — jangan pakai nama variable
2. Declaration group: var A, B: TValue; — both jadi TValue. Untuk tipe beda, pisah line
3. = vs == — = = assignment, == = comparison. Salah tulis → syntax error atau logic bug
4. div bukan keyword — pakai toInteger(a / b) untuk division
5. Type annotations tidak didukung di function params/return:
   · ❌ function f(x: Integer): string
   · ✅ function f(x) begin ... end

Sandbox

1. fileExists() di absolute path → sandbox reject. Untuk load file absolut, langsung try gui2.setFont() / gui2.loadTexture() / gui2.loadMusic() — mereka bypass sandbox
2. Error banner sekarang visible (v0.10.4 fix) — kalau silent exit, cek ulang

Nama variable global terpakai (HINDARI)

sys, math, crypto, time, net, http, ws, fs, dll, tls, native, hardware, gui, gui2, log, config, signal, metrics, health, pkg, int, str, bool, double, dll.

---

🧪 Pola Testing (Verified)

Build:

```bash
cd ~/storage/downloads/termux/pascak
fpc -Mobjfpc -Sh pascak_noASTnet.pas 2>&1 | grep -E 'Error|Fatal|Linking' | tail -10
```

Run test:

```bash
cat > "$HOME/test.pas" << 'EOF'
begin
  println("hello");
end.
EOF

cp pascak_noASTnet "$HOME/pascak_test"
chmod +x "$HOME/pascak_test"
cd "$HOME"
timeout 20 env PASCAK_EXEC_POLICY=allow-all ./pascak_test --dev test.pas
```

Commit convention:

```
feat(scope): description
fix(scope): description
docs(scope): description
```

Tag annotation (always):

```bash
git tag -a vX.Y.Z -m "description"
```

Push (SSH):

```bash
git push origin main --tags
```

---

📊 Project State — Capability Matrix

Area Status
Core VM ✅ 95%
Stdlib ✅ 98%
Network (HTTP/1 + H2 multiplexed + async + WS + TLS) ✅ 99%
Browser GUI (HTTP + HTTPS) ✅ 80%
Native GUI (SDL2, 48 API) ✅ 100%
Embedding (subprocess + in-process) ✅ 90%
Dev Tools (LSP, VSCode, linter, fmt, test) ✅ 85%
Docs ✅ 99%
Security (sandbox + exec policy) ✅ 85%

Known limitations (documented):

· H2 async N=8+ concurrent: server rate limit (not engine bug)
· H2 body >64KB: no WINDOW_UPDATE flow control (backlog)
· Native GUI per-window font/texture: shared (documented in tutorial)
· Native GUI hi-DPI: no auto-scaling

---

🎯 Prioritas Sesi Berikutnya

Rekomendasi kuat: Fix Phase 1 bug dulu (v1.1.0 dalam keadaan setengah jadi, tidak bisa release).

Langkah:

1. Diagnose stack underflow — isolate dengan minimal test case (n?.name dengan n=null)
2. Inspect bytecode — tambah debug print untuk melihat hasil optimization (instruction sequence)
3. Fix optimizer atau compiler — kemungkinan besar opcJump +0 tidak cleanly handled
4. Retest 12 case Phase 1
5. Lanjut Phase 2+3 (enum + destructuring) dalam 1 sesi
6. Tag v1.1.0

Kalau stuck > 1 jam: rollback Phase 1 (git reset --hard HEAD), commit dulu ke fix/lang-phase1 branch, fokus fitur lain (GUI hot-reload, LSP Phase 4, dll), kembali lagi nanti.

---

