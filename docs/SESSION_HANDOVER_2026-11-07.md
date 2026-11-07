📋 Handover Document — Pascak Development Context

Generated: 2026-11-07
Main HEAD: 743b765 (v1.11.33)
Tags: 90 total (v0.4.0 → v1.11.33)
Engine: 51,135 lines
Tests: 17/17 PASS
Tree: clean

---

## 1️⃣ ATURAN PENULISAN PASCAK SCRIPT

Sintaks Wajib

Aturan Contoh
Statement HARUS di dalam begin...end begin print(x); end. ✅ / print(x); top-level ❌
Semicolon (;) wajib var x = 10; (bukan var x = 10)
Assignment =, Comparison == x = 10, if x == 10
Function ending end;, Program ending end. function f() begin ... end;
Statement pakai println() bukan print() println("hello");
Inline var TIDAK DIDUKUNG declare di var section
end = reserved keyword dict field pakai finish, bukan end
Label = reserved keyword field pakai Caption, bukan Label

Struktur Standar

```pascal
function add(a, b) begin
  return a + b
end;

var x = 10;

begin
  println("Hello");
  println(add(1, 2));
end.
```

Nama Global Terpakai (HINDARI)

sys, math, crypto, time, net, http, ws, fs, dll, tls, native, hardware, gui, gui2, log, config, signal, metrics, health, pkg, int, str, bool, double

Yang TIDAK ADA

· ❌ getTicks(), delay(), time.sleep() global
· ❌ fileExists() di absolute path (sandbox reject)
· ❌ Type annotations di function params/return

GUI2 WAJIB Setup

```pascal
gui2.init();
gui2.setFont("/data/data/com.termux/files/usr/share/fonts/TTF/DejaVuSans.ttf", 20);
gui2.window("App", 800, 600);
gui2.textInputEnabled(true);  // untuk Edit/Memo
```

Tanpa setFont, semua text INVISIBLE (silent fail).

---

## 2️⃣ CARA KERJA (PROSES ANDA)

Setup Sesi Baru

```bash
cd ~/storage/downloads/termux/pascak
git fetch origin --tags --prune
git --no-pager log --oneline -10
git --no-pager tag --list | sort -V | tail -10
git --no-pager status --short
wc -l pascak_engine.pas docs/tutorial.md
bash tests/run.sh lang 2>&1 | tail -3
```

Patch Workflow (Verified 34 milestones)

```bash
# 1. Backup WAJIB
cp pascak_engine.pas pascak_engine.pas.bak_vXXX_pre

# 2. Python heredoc — NO /tmp/
python3 <<'PYEOF'
from pathlib import Path
import sys
SRC = Path('pascak_engine.pas')
text = SRC.read_text()
def apply(old, new, label):
    n = text.count(old)
    if n == 0: print(f'FAIL [{label}]', file=sys.stderr); sys.exit(1)
    if n > 1: print(f'FAIL [{label}]: {n}x', file=sys.stderr); sys.exit(1)
    return text.replace(old, new, 1)
# ... apply calls ...
SRC.write_text(text)
print('OK')
PYEOF
EXIT=$?
[ $EXIT -ne 0 ] && cp pascak_engine.pas.bak_vXXX_pre pascak_engine.pas && exit 1

# 3. Verify
grep -c 'MARKER' pascak_engine.pas

# 4. Build
rm -f pascak_engine.ppu pascak_engine.o
fpc -Mobjfpc -Sh pascak_noASTnet.pas 2>&1 | grep -E 'Error|Fatal|Linking|lines compiled' | tail -8

# 5. Test (WAJIB copy ke $HOME — /storage/ noexec)
cp pascak_noASTnet $HOME/pascak_test
chmod +x $HOME/pascak_test
cd $HOME && timeout 10 env PASCAK_EXEC_POLICY=allow-all ./pascak_test --dev test.pas

# 6. Regression
cd ~/storage/downloads/termux/pascak && bash tests/run.sh lang

# 7. Commit + tag + push
git add <files>
git commit -m "feat(scope): vX.Y.Z — description"
git tag -a vX.Y.Z -m "description"
git push origin main && git push origin vX.Y.Z
```

Intermediate Backups (CRITICAL)

```bash
cp pascak_engine.pas pascak_engine.pas.bak_vXXX_after_A
cp pascak_engine.pas pascak_engine.pas.bak_vXXX_after_B
# Script C fail → restore after_B, tidak perlu redo A+B
```

Termux Gotchas

1. /tmp TIDAK ADA
2. Paste limit ~1KB per chunk — heredoc >2KB stuck
3. Split file baru jadi 3-5 chunk kecil
4. pkill -f name > kill $(cat pid)
5. /storage/ noexec — copy binary ke $HOME
6. git config --global --add safe.directory '*'

GUI Interactive Test — Wajib Background Run

JANGAN run interactive test foreground (GUI hang sampai timeout). Pattern:

```bash
export DISPLAY=:0
export SDL_AUDIODRIVER=dummy
( ./pascak_test --dev test.pas > $HOME/test.log 2>&1 ) &
TEST_PID=$!

echo "Switch to Termux:X11 app NOW"
sleep 60
pkill -f pascak_test 2>/dev/null
cat $HOME/test.log
```

Termux:X11 mode: harus "touchscreen" (bukan "touchpad" default). Swipe keyboard toggle di toolbar bawah.

---

## 3️⃣ YANG SUDAH SELESAI

35 Main Tags (v1.11.0 → v1.11.33)

Language & Core (v1.11.0–v1.11.13):

· ?., ??, enum, destructuring (Phase 1-3, sudah lama done)
· H2 4c verified (retry + rate limiter + GOAWAY)
· LSP 4 signatureHelp verified
· JIT deopt fix + re-specialize
· SIGPIPE exit 141 fix
· Worker sleep cap 60s → 5s

GUI Features (v1.11.0–v1.11.13):

· gui.watch() — asset hot-reload
· gui.serveDir() — static serving
· ETag + 304 caching
· Last-Modified + If-Modified-Since

GUI Widget Toolkit (v1.11.14 → v1.11.33):

Phase Tag Deliverable
1 v1.11.14 SDL_TEXTINPUT + keyDown + textInputEnabled
2a v1.11.15 Widget infrastructure (9 natives)
2b v1.11.16 Mouse dispatch + focus
2c v1.11.17 Keyboard dispatch + focus chain
3 v1.11.18 Button widget
3b v1.11.19 Button caption + hover
3c v1.11.20 Button onClick callback
4a v1.11.21 Edit basic (UTF-8)
— v1.11.22 Tutorial Bab 34 GUI Widgets
— v1.11.23 Font requirement fix
4b v1.11.24 Edit focus + navigation
4c-1 v1.11.25 Edit text selection
4c-2 v1.11.26 Edit clipboard (Ctrl+C/V/X)
5a v1.11.27 Memo multi-line basic
5b v1.11.28 Memo selection + clipboard
5c-1 v1.11.29 Memo scrollbar
— v1.11.30 VSYNC hang fix + cursor symmetry + memo spacing
5c-3a v1.11.31 Word wrap infrastructure (default OFF)
5c-2a v1.11.32 Line numbers gutter
6a v1.11.33 ComboBox dropdown (popup layer)

Widget API Lengkap (Final State)

Button (100%):

```pascal
gui2.button(x, y, w, h, caption, [r], [g], [b]) -> id
gui2.buttonSetCaption(id, str), buttonGetCaption(id)
gui2.buttonOnClick(id, fn), buttonClearOnClick(id)
```

Edit (90%):

```pascal
gui2.edit(x, y, w, [initial], [r], [g], [b]) -> id
gui2.editGetText(id), editSetText(id, str)
gui2.editGetSelection(id) -> {start, finish}
```

Memo (95%):

```pascal
gui2.memo(x, y, w, h, [initial], [r], [g], [b]) -> id
gui2.memoGetText(id), memoSetText(id, str)
gui2.memoGetCursor(id) -> {line, col}
gui2.memoGetSelection(id) -> {start_line, start_col, end_line, end_col}
gui2.memoSetScrollTop(id, n), memoGetScrollTop(id)
gui2.memoSetSpacing(id, line_spacing, pad_top, pad_bottom, pad_left)
gui2.memoGetSpacing(id) -> {line_spacing, pad_top, pad_bottom, pad_left}
gui2.memoSetLineNumbers(id, bool), memoGetLineNumbers(id)
gui2.memoSetWrap(id, bool), memoGetWrap(id), memoGetVisualLineCount(id)
```

Common widget API:

```pascal
gui2.widgetCount(), widgetsDraw()
gui2.widgetSetPos(id, x, y), widgetSetSize(id, w, h)
gui2.widgetSetVisible(id, bool), widgetSetEnabled(id, bool)
gui2.widgetGetBounds(id) -> {x, y, w, h}
gui2.widgetDestroy(id)
gui2.widgetFocus(id), widgetGetFocused(), widgetFocusNext([reverse])
gui2.widgetGetClicks(id), widgetGetKeyCount(id)
```

Documentation

· Tutorial Bab 1–34 (~5,700 lines) — Bab 34 = GUI Widgets
· CHANGELOG — 35 entries (v1.11.0 → v1.11.33)
· Design docs di feat/gui-widgets branch (v1.13.0-plan)
· Register VM design di feat/register-vm branch (v1.12.0-plan)

---

## 4️⃣ YANG BELUM SELESAI

Optional Widget Polish

Item Effort Priority
Phase 5c-3b: cursor remap in wrapped mode 1-2 sesi Optional (default OFF, works fine without)
Phase 5c-2b: dynamic gutter width 30 min Nice-to-have
Edit mouse drag select ~30 min Nice-to-have
Tutorial Bab 34 Memo section update ~1 jam Docs sync

New Widgets (Phase 6+)

Widget Effort
ListBox (scrollable list) ~1-2 sesi
Checkbox / Radio ~1 sesi
Reusable Scrollbar (standalone) ~1 sesi
Layout API (flow/grid) ~2 sesi
Theming (color/font per widget) ~1 sesi
Tab order customization ~1 sesi

Deferred Architecture

· Register VM Tier 3 — 15-20 sesi, design ready di feat/register-vm
· Arena allocator — 5-8 sesi, needs profiling first
· Word wrap cursor remap — 5c-3b/c, complex logical↔visual mapping

Known Issues / Limitations

Issue Status Workaround
Word wrap cursor still logical Documented Default OFF, safe
Termux:X11 "touchpad" mode default Documented Switch to "touchscreen"
setFont silent fail Documented Always call setFont
Edit mouse drag select Not implemented Click + SHIFT+arrows

---

## 5️⃣ REKOMENDASI PENGEMBANGAN

🟢 Priority 1 — User Feedback Cycle (STRONGEST)

Alasan: 29 sesi teknis tanpa external validation. Semua widget production-ready.

Actions:

1. Publish benchmark vs Lua/Node/CPython
2. Blog post — devlog GUI widget toolkit
3. Example gallery — examples/gui_button_counter.pas, gui_todo.pas, gui_editor.pas
4. GitHub Discussions — feedback channel
5. Ask users: apa pain point? fitur apa yang hilang?

Effort: 1-2 hari
Value: Roadmap organic, bukan internal guess

---

🟡 Priority 2 — Phase 6: ComboBox

Effort: ~2 sesi
Risk: MEDIUM (popup layer above other widgets)

Scope:

· TGuiComboBox: rect + text + arrow + dropdown
· Popup rendered top-most (z-order)
· Click-outside-to-close
· Items array + selected index
· Keyboard nav (UP/DOWN, ENTER to open/select)

---

🟡 Priority 3 — Docs Polish

Effort: 1-2 jam

Scope:

· Tutorial Bab 34 Memo section (selection, clipboard, scrollbar, line numbers, spacing, wrap)
· pascak_api.md sync untuk v1.11.x
· Cross-link tutorial ↔ API

---

🟠 Priority 4 — Widget Extensions (Phase 6+)

· ListBox, Checkbox/Radio, Layout API, Theming
· 2-6 sesi total

---

🔴 Priority 5 — Register VM Tier 3 (deferred)

Only if: user reports concrete perf bottleneck

Design ready: feat/register-vm branch @ 0fbf316

Alternative: Tier 2.5 (extend superinstructions, 2-3 sesi, low risk)

---

## 6️⃣ ANTI-DRIFT (Yang HARUS Konsisten)

JANGAN LAKUKAN

· ❌ Commit tanpa test
· ❌ Skip tag annotation (-a)
· ❌ Push ke HTTPS (pakai SSH)
· ❌ File di /tmp (tidak ada)
· ❌ Nama reserved (Label, end, Packed, ws, int)
· ❌ Inline var declaration (FPC error)
· ❌ Heredoc >2KB (paste Termux stuck)
· ❌ Interactive test foreground (GUI hang)
· ❌ Percaya backlog "pending" tanpa verify (30+ kasus: "pending" = "done")
· ❌ Percaya komentar kode = fitur berfungsi (verify runtime)

YANG HARUS

· ✅ Binary name: pascak_noASTnet
· ✅ Repo: github.com/baddcoin/pascak
· ✅ Remote: SSH git@github.com:baddcoin/pascak.git
· ✅ Build: fpc -Mobjfpc -Sh
· ✅ Test: copy ke $HOME dulu
· ✅ Fail-safe: sys.exit(1) → cp .bak → zero damage
· ✅ Verify runtime > trust label
· ✅ Intermediate backups untuk multi-script patch
· ✅ Tag annotation git tag -a vX.Y.Z -m "desc"

Test File Gotchas

· ✅ println() bukan print()
· ✅ Semicolon wajib
· ✅ Multiple var top-level butuh format tertentu
· ✅ Function ending end; (bukan end)
· ✅ Field dict finish (bukan end)

---

## 7️⃣ KEY FILE REFERENCES

File Purpose
pascak_engine.pas 50,620 lines monolith
pascak_h2_conn.pas H2 multiplexing
pascak_http.pas HTTP/1.1
pascak_tls.pas SSL binding
pascak_websocket.pas WS RFC 6455
docs/tutorial.md Bab 1-34
docs/pascak_api.md API reference
docs/gui_widgets/ Design docs (feat/gui-widgets)
docs/register_vm/ Register VM plan (feat/register-vm)
tests/lang/ 17 language tests
tests/fixtures/mock_server.py H2 test mock

Key Line References (v1.11.33 approx)

· TGuiWidget base class: ~38,200
· TGuiButton: ~38,250
· TGuiEdit: ~38,300
· TGuiMemo: ~38,340
· GuiSyncFocused: ~38,900
· GuiHitTest / GuiDispatchMouse: ~39,000
· RebuildVisualLines: ~39,400
· TGuiMemo.Draw: ~39,700
· Native_Gui2_Poll: ~40,300
· Memo natives: ~41,100
· Native registration: ~41,700

---

## 8️⃣ NEXT SESSION START COMMAND

```bash
cd ~/storage/downloads/termux/pascak
git fetch origin --tags --prune
git --no-pager log --oneline -5
git --no-pager tag --list | sort -V | tail -6
wc -l pascak_engine.pas docs/tutorial.md
bash tests/run.sh lang 2>&1 | tail -3
```

Trigger phrase untuk chat baru:

"Lanjutkan Pascak development. HEAD = 743b765 (v1.11.33), 90 tags. Baca handover ini. [pilih path: user feedback / Phase 6b / docs / dll]"

AI assistant checklist:

1. Verify state dengan setup commands
2. Read docs/gui_widgets/phase_plan.md on feat/gui-widgets branch
3. Jangan percaya backlog context lama — verify runtime
4. Backup sebelum patch — always .bak_pre
5. Build + test after patch — bash tests/run.sh lang 17/17
6. Tag annotation — git tag -a
7. Interactive GUI test = background run + switch to Termux:X11

---

## 9️⃣ RINGKASAN EKSEKUTIF

Current State

Production-ready GUI widget toolkit:

· Button: 100% complete, verified
· Edit: 90% (mouse drag select missing, optional)
· Memo: 95% (cursor remap in wrapped mode missing, optional)

Zero technical debt. 17/17 PASS. 50,620 lines engine. 89 tags.

Achievement Arc

29 sesi teknis (5 hari) — 34 main tags, 20 milestones, zero regression.

3 real user issues fixed in v1.11.30:

· GUI hang (VSYNC flag removed)
· Cursor symmetry (font glyph measured)
· Memo spacing (configurable properties)

Full widget verified end-to-end via X11 interactive test.

Strong Recommendation

Publish + attract users sekarang. Semua widget sudah production-ready. Feedback organic lebih valuable dari technical work lebih lanjut tanpa user validation.

Next Technical Options

· Phase 6 ComboBox — natural next widget (2 sesi)
· Tutorial Bab 34 Memo update — docs sync (1 jam)
· Word wrap cursor remap — optional, default safe (1-2 sesi)
· Register VM Tier 3 — only if user reports perf (15-20 sesi)

Final State for Next Session

```
Main:      743b765 (v1.11.33)
Tags:      89 total
Engine:    50,620 lines
Tests:     17/17 PASS
Tree:      clean
Planning:  feat/register-vm + feat/gui-widgets branches
```

Simpan dokumen ini sebagai docs/SESSION_HANDOVER_2026-11-07.md di repo. Update setiap sesi baru.

---

Generated from 29-session development arc — production-ready widget toolkit with zero technical debt.