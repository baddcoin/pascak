📋 Handover Document — Pascak Development Context

Generated: 2026-11-01
Session arc: 5 consecutive sessions
Main HEAD: 82c68b8 (v1.11.12)
Planning branch: feat/register-vm @ d84172d (v1.12.0-plan)
Total tags: 68 (v0.4.0 → v1.12.0-plan)

---

1️⃣ ATURAN PENULISAN PASCAK SCRIPT

Sintaks Wajib

Aturan Contoh
Statement HARUS di dalam begin...end begin print(x); end. ✅ / print(x); (top-level) ❌
Top-level hanya deklarasi var, const, enum, function
Semicolon (;) wajib di akhir statement & declaration var x = 10; (bukan var x = 10)
Assignment = (single) x = 10
Comparison == (double) if x == 10 then ...
Function ending end; (with semicolon at top-level) function f() begin return 1 end;
Program ending end. (with period) Last end in file

Struktur File Standar

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

Nama Variable Global yang HARUS DIHINDARI

sys, math, crypto, time, net, http, ws, fs, dll, tls, native, hardware, gui, gui2, log, config, signal, metrics, health, pkg, int, str, bool, double

Module Built-in

· sys, math, crypto, time, net, http, ws, fs, dll, tls, native, hardware
· gui (browser), gui2 (SDL2 native), log, config, signal, metrics, health, pkg

Yang TIDAK ADA / Bukan Global

· ❌ print() — pakai println()
· ❌ getTicks() global — hanya gui2.getTicks() (setelah gui2.init())
· ❌ delay() global — tidak ada
· ❌ time.sleep() — tidak ada (pakai sleep(ms) jika tersedia, atau loop sibuk)
· ❌ fileExists() di absolute path — sandbox reject; pakai relative atau try/catch

Type Annotations

· ❌ TIDAK didukung di function params/return: function f(x: Integer): string ← error
· ✅ Dynamic typing: function f(x) begin ... end

Gotchas Khusus

· div bukan keyword — pakai toInteger(a / b)
· Nama reserved FPC: Packed, Absolute, Override, Property
· var A, B: TValue; — kalau multiple var dalam satu line dengan tipe eksplisit, semua jadi tipe yg sama

---

2️⃣ PROSES KERJA (PATTERN SAYA)

Setup Sesi Baru (WAJIB)

```bash
cd ~/storage/downloads/termux/pascak
git fetch origin --tags --prune
git --no-pager log --oneline -10
git --no-pager tag --list | sort -V | tail -10
git --no-pager status --short | grep -v '\.bak_' || echo "(clean)"
wc -l pascak_engine.pas docs/tutorial.md
```

Patch Workflow Standard (Verified 15+ milestones)

```bash
# 1. Backup WAJIB
cp pascak_engine.pas pascak_engine.pas.bak_vXXX_pre

# 2. Python heredoc — NO /tmp/ (tidak ada), pakai $HOME atau relative
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

# 3. Fail-safe rollback
[ $EXIT -ne 0 ] && cp pascak_engine.pas.bak_vXXX_pre pascak_engine.pas && exit 1

# 4. Verify anchors
grep -c 'MARKER' pascak_engine.pas

# 5. Build
fpc -Mobjfpc -Sh pascak_noASTnet.pas 2>&1 | grep -E 'Error|Fatal|Linking|lines compiled' | tail -5

# 6. Test (WAJIB copy ke $HOME — /storage/ noexec)
cp pascak_noASTnet $HOME/pascak_test
chmod +x $HOME/pascak_test
cd $HOME && timeout 20 env PASCAK_EXEC_POLICY=allow-all ./pascak_test --dev test.pas

# 7. Regression
cd ~/storage/downloads/termux/pascak && bash tests/run.sh lang

# 8. Commit + tag + push
git add <files>
git commit -m "feat(scope): vX.Y.Z — description"
git tag -a vX.Y.Z -m "description"
git push origin main --tags
```

Intermediate Backups (CRITICAL — Lesson Sesi Ini)

Untuk patch multi-tahap, simpan snapshot antar-script:

```bash
cp pascak_engine.pas pascak_engine.pas.bak_vXXX_pre     # sebelum apa2
# → Script A → verify → 
cp pascak_engine.pas pascak_engine.pas.bak_vXXX_after_A
# → Script B → verify → 
cp pascak_engine.pas pascak_engine.pas.bak_vXXX_after_B
# → Script C fail → restore ke after_B, tidak perlu redo A+B
```

Termux-Specific Lessons

1. /tmp TIDAK ADA — jangan pernah pakai /tmp/*
2. Paste limit ~1KB per chunk — heredoc >2KB sering stuck di > prompt
3. Untuk file baru, split 3-4 chunk kecil (header + body + tail)
4. pkill -f name > kill $(cat pid) — lebih reliable
5. stdbuf -oL untuk line-buffered output (test fixtures)
6. wc -l untuk verify line count setelah file dibuat

Commit Convention

· feat(scope): — fitur baru
· fix(scope): — bug fix
· docs(scope): — dokumentasi
· chore(scope): — cleanup
· perf(scope): — optimasi performa
· test(scope): — test infrastructure

Tag Annotation (SELALU -a)

```bash
git tag -a vX.Y.Z -m "description"
git push origin vX.Y.Z
```

---

3️⃣ TAHAPAN YANG SUDAH SELESAI

Sesi Arc Terakhir (5 sesi berturut): 22 commits, 13 tags di main + 1 branch planning

A. Docs Housekeeping (base commits)

· 44c693e — README badge v1.8.0 → v1.10.4 + LSP overclaim removed
· 3d984dc — SESSION_CONTEXT_UPDATE_2026-10-30.md overlay

B. Feature Releases

Tag Deliverable Type
v1.11.0 gui.watch(handle, path) — asset hot-reload feature
v1.11.1 gui.serveDir(handle, path) — static serving + recursive walk feature
v1.11.2 Tutorial 27.20/27.21 + TOC Bab 29-31 docs
v1.11.3 Tutorial Bab 32 restructure + Bab 33 (HTTP/2) docs
v1.11.4 Mock server fix (MOCK_ENHANCE_N env) + H2 4c verified test infra
v1.11.5 Tutorial 28.12 — 52 API reference (was 19) docs
v1.11.6 LSP 4 verified (signatureHelp, 5 scenarios) verify
v1.11.7 ETag + If-None-Match + 304 caching feature
v1.11.8 SIGPIPE exit 141 fix (process kill on closed socket) bug fix
v1.11.9 304 RFC 7232 compliance (no CT, no CL) bug fix
v1.11.10 Last-Modified + If-Modified-Since (RFC 7232 §3.3/§3.4) feature
v1.11.11 Worker pool sleep cap 60s → 5s (12× starvation reduction) perf
v1.11.12 JIT deopt fallback for polymorphic arith (errors 96-99) bug fix

C. Planning Branch

Tag Branch Deliverable
v1.12.0-plan feat/register-vm @ d84172d 306 lines design doc (Phase 0)

Cumulative State (5 sesi)

Metric Start (v1.10.4) Current (v1.11.12) Delta
Tags total 55 68 +13
pascak_engine.pas 47,328 47,833 +505
pascak_http.pas 782 783 +1
docs/tutorial.md 5,161 5,338 +177
docs/register_vm/ — 306 lines new
Lang tests 17/17 17/17 stable

Verified Backlog Items (5× "pending" ternyata "done")

Backlog Claim Reality Verified In
v1.2.6 rest-in-nested ✅ Done Sesi awal — runtime T4 PASS
v1.2.7 ?.() method call ✅ Done Sesi awal — runtime T2 PASS
H2 4c rate limiter ✅ Done Sesi H2 — retry proven via mock log
LSP 4 signatureHelp ✅ Done Sesi LSP — 5 scenarios PASS
Register VM Tier 1+2 ✅ Done (only Tier 3 pending) Sesi planning — code grep verified

Lesson: Backlog context sering 6–9 versi stale. Verify runtime > percaya label backlog.

---

4️⃣ TAHAPAN YANG SEDANG DIKERJAKAN

Status Sekarang: IDLE — Sesi Closed

· ✅ Main branch production-ready di v1.11.12
· ✅ Planning branch feat/register-vm pushed, ready for future
· ✅ Zero known bugs
· ✅ All "easy" backlog cleared
· ✅ Zero debt kecuali yang tracked (architectural)

Tidak ada yang sedang dikerjakan. Sesi berikutnya = pilihan fresh.

---

5️⃣ TAHAPAN PENGEMBANGAN SELURUHNYA

Prioritas Rekomendasi (Urut)

🟢 Option 1 — User Feedback Cycle (RECOMMENDED)

Effort: ongoing
Win: organic direction — apa yang user benar-benar butuhkan
Risk: zero

Cara mulai:

· Publish benchmarks (link ke benchmarks/results_v1.11.12.md)
· Buat blog post / devlog tentang fitur baru (hot-reload, RFC 7232 caching)
· Tanya user: apa pain point? Fitur apa yang hilang?
· Kalau ada user report konkret, itu jadi priority

---

🟡 Option 2 — Tier 2.5 (Extend Superinstructions)

Effort: ~2-3 sessions
Win: 1.2-1.4× untuk hot paths
Risk: LOW (additive, no rewrite)

Scope:

· Tambah superinstructions: opcCmpAndJump, opcBuildArrayN, opcStringConcatN, opcDictGetOrNull
· Extended adaptive: re-specialize after deopt (currently one-way patch)
· Benchmark per-opcode, ship incrementally

Kapan pilih ini: kalau mau perf win tanpa rewrite risk, atau kalau user report "X lambat" tapi tidak spesifik.

---

🟡 Option 3 — Register VM Tier 3 (Full Rewrite)

Effort: 15-20 sessions (3-4 weeks)
Win: 1.3-1.5× realistic (bukan 2-5× tanpa JIT+arena)
Risk: HIGH

Design doc sudah ada: docs/register_vm/ di branch feat/register-vm

Kapan pilih ini: HANYA kalau:

· User report konkret perf bottleneck
· Tier 2.5 sudah dicoba dan tidak cukup
· Ada komitmen 15-20 sesi maraton

Phase plan (singkat):

1. Infrastructure (3-4 sesi)
2. Migrate arithmetic (2-3 sesi)
3. Migrate loops (2 sesi)
4. Migrate locals (2 sesi)
5. Function calls via registers (2-3 sesi)
6. Deopt framework (1 sesi)
7. Benchmark sweep (1 sesi)
8. 17/17 lang re-verify (1 sesi)
9. Integration tests (1 sesi)
10. Merge decision (1 sesi)
    11-12. Buffer

---

🟡 Option 4 — Arena Allocator (Targeted TValue Perf)

Effort: 5-8 sessions
Win: 1.3-1.5× targeted (TValue allocation cost)
Risk: MEDIUM

Scope:

· Pool allocator for TValue
· Bump allocator per-scope (freed at scope exit)
· Doesn't touch VM dispatch — orthogonal to register VM

Kapan pilih ini: kalau profiling menunjukkan TValue alloc = dominant cost.

---

🟢 Option 5 — Async Timer-Deferral (Deferred)

Effort: ~2-3 jam
Win: marginal (currently capped at 5s, acceptable)
Risk: LOW

Scope: Full non-blocking rate limiter (worker never sleeps, timer re-enqueues)

Kapan pilih ini: HANYA kalau user report "worker starvation >5s" di production.

---

Backlog yang Sudah Obsolete

· ~~v1.2.6 rest-in-nested~~ → done
· ~~v1.2.7 ?.()~~ → done
· ~~H2 4c rate limiter~~ → done
· ~~LSP Phase 4 signatureHelp~~ → done
· ~~Register VM Tier 1+2~~ → done
· ~~SIGPIPE exit 141~~ → fixed (v1.11.8)
· ~~304 RFC compliance~~ → fixed (v1.11.9)
· ~~Worker sleep 60s starvation~~ → fixed (v1.11.11)
· ~~JIT deopt polymorphic arith~~ → fixed (v1.11.12)
· ~~GUI caching (ETag+Last-Modified)~~ → done (v1.11.7 + v1.11.10)

---

🔍 KODE UTAMA — Line References (v1.11.12)

Feature File Line (approx)
Lexer ?/?? pascak_engine.pas ~11,235
Token ttOptionalDot/ttNullCoalesce pascak_engine.pas ~516
Parser ParseFactor postfix ?. pascak_engine.pas ~11,844
Parser ParseNullCoalesce pascak_engine.pas ~11,910
Parser ParsePattern (destructure) pascak_engine.pas ~12,310
Compiler opcJumpIfNull emit pascak_engine.pas ~15,726, 16,261+
VM opcJumpIfNull impl pascak_engine.pas ~18,821
Native BuiltIn_Dict_Omit pascak_engine.pas ~10,515
VM dispatch loop TVM.Run pascak_engine.pas 17,065
Adaptive specialization block pascak_engine.pas ~19,488-19,512
opcAddNum / SubNum / MulNum / DivNum pascak_engine.pas ~19,011-19,180
opcAdd generic (reference) pascak_engine.pas 17,626
opcSub/Mul/Div/Mod generic pascak_engine.pas ~17,670
TInstruction record pascak_engine.pas ~2xx
TVMOpCode enum pascak_engine.pas ~221
TVM class fields pascak_engine.pas ~1,700
TChunk.SaveToStream pascak_engine.pas 13,969
TChunk.LoadFromStream pascak_engine.pas 14,080
Native_HTTP_Get2 (rate limiter) pascak_engine.pas ~29,820
Native_HTTP_Get2Async pascak_engine.pas 29,905
Native_HTTPSync2 (worker) pascak_engine.pas 29,861
RateGetWaitMs / RateRecordError / RateReset pascak_engine.pas ~29,700-29,800
InstallSignalHandlers (SIGINT/TERM) pascak_engine.pas 35,154
HandleSigPipeIgnoreCdecl pascak_engine.pas 35,150
RunCLI (SIGPIPE install) pascak_engine.pas 47,430, 47,449
Native_GUI_HttpHandler pascak_engine.pas ~39,900
Static branch (ETag/Last-Modified) pascak_engine.pas ~39,945
GetFileETag pascak_engine.pas ~39,890
GetFileMTime / FormatRFC1123 / ParseRFC1123 pascak_engine.pas ~39,860
ApplyResponseDict (304 CT guard) pascak_engine.pas ~26,705
Worker loop CT guard (304) pascak_engine.pas ~27,084
IsBodyless (304 in HTTP builder) pascak_http.pas 621
TEventLoop.SetTimer pascak_engine.pas 19,836
TWorkerPool.EnqueueTask pascak_engine.pas 19,041 / 41,918
H2 connection pascak_h2_conn.pas —
H2 frame/HPACK pascak_h2.pas, pascak_h2_hpack.pas —
Mock server tests/fixtures/mock_server.py —

---

🧪 TEST INFRASTRUCTURE

Language Tests (tests/lang/) — 17 files PASS

```
phase1_optchain_nullcoalesce.pas
phase2_enum.pas
phase3_destructure.pas
v1102_optional_index.pas
v120_defaults_enumscope.pas
v121_array_rest.pas
v121_enum_iter.pas
v122_nested_1level.pas
v123_nested_2level.pas
v124_arbitrary_depth.pas
v124_array_root_nested.pas
v125_object_rest.pas
v126_rest_in_nested.pas
v127_optional_method.pas
v160_param_destructure.pas
v161_rest_in_param.pas
v162_nullsafe_assign.pas
```

Runner: bash tests/run.sh lang

Integration Tests (tests/integration/)

· h2_sequential.pas, h2_auto_retry.pas, h2_bigbody_flowctl.pas, h2_ratelimit_backoff.pas
· hotreload_basic.pas, hotreload_gui.pas
· lsp_sighelp.py

Runner: bash tests/run.sh integration (needs manual setup — mock server)

Mock server: tests/fixtures/mock_server.py — controlled by MOCK_ENHANCE_N env var (default 3)

Benchmarks (benchmarks/)

· bench_arith.pas, bench_calls.pas, bench_dict.pas, bench_array.pas, bench_string.pas, bench_json.pas, bench_push.pas, bench_parser.sh
· run_all.sh — runner
· results_v1.11.12.md — current baseline

---

🎯 CARA MEMULAI SESI BARU

Copy-paste template

```
Konteks: repo pascak di https://github.com/baddcoin/pascak.
HEAD main = 82c68b8 (v1.11.12), HEAD planning = d84172d (v1.12.0-plan, branch feat/register-vm).

Baca dulu:
1. CHANGELOG.md entries [1.11.x] (13 entries)
2. SESSION_CONTEXT_UPDATE_2026-10-30.md
3. docs/register_vm/README.md (Phase 0 planning)

Verify dulu sebelum percaya backlog:
- git --no-pager tag --list | sort -V | tail -15
- wc -l pascak_engine.pas docs/tutorial.md
- bash tests/run.sh lang

Target sesi ini: [sebutkan pilihan dari 5 options di atas]

Jangan percaya klaim "pending" di backlog context lama — 5× hari ini "pending" ternyata "done". Verify runtime dulu.
```

Setup verification commands

```bash
cd ~/storage/downloads/termux/pascak
git fetch origin --tags --prune
git --no-pager log --oneline -10
git --no-pager tag --list | sort -V | tail -15
git --no-pager status --short
wc -l pascak_engine.pas pascak_http.pas docs/tutorial.md
git --no-pager branch -a
```

---

⚠️ ANTI-DRIFT (Jangan Lakukan)

Yang HARUS Konsisten

1. Binary name: pascak_noASTnet (bukan pascak atau pascak.exe)
2. Repo: github.com/baddcoin/pascak (bukan cilox)
3. Remote: SSH git@github.com:baddcoin/pascak.git (bukan HTTPS — minta password)
4. Test pattern: copy binary ke $HOME dulu (karena /storage/ noexec)
5. Patch workflow: backup → python script → verify → build → test → commit → tag → push
6. FPC flags: -Mobjfpc -Sh (jangan ubah)
7. Tag annotation: git tag -a (bukan git tag)

Yang JANGAN Lakukan

· ❌ Commit tanpa test
· ❌ Skip tag annotation (-a wajib)
· ❌ Push ke HTTPS (pakai SSH)
· ❌ Taruh file di /tmp (tidak ada di Termux)
· ❌ Pakai nama variable reserved (Packed, ws, int, dll)
· ❌ Pipe output test dengan | head (exit code jadi punya head)
· ❌ Paste heredoc >2KB ke Termux (stuck di > prompt)
· ❌ Percaya komentar kode = fitur berfungsi (verify runtime dulu)
· ❌ Percaya backlog "pending" tanpa verify (5× hari ini "pending" = "done")

Test File Gotchas (Lesson Sesi Ini)

· ✅ println() (bukan print())
· ✅ Semicolon wajib (var x = 10; bukan var x = 10)
· ✅ Multiple var di top-level butuh format tertentu
· ✅ Function declaration butuh ; setelah end
· ✅ Tidak ada getTicks(), delay(), time.sleep() global
· ✅ time.now() juga tidak ada — pakai sys.now() atau skip timing

---

📊 RINGKASAN EKSEKUTIF

Current state: Production-ready Pascak VM di v1.11.12. 17/17 language tests PASS. 68 tags total. Zero known bugs.

Yang baru (5 sesi): 3 production features (watch, serveDir, caching), 4 bug fixes (SIGPIPE, 304 headers, worker sleep, JIT deopt), 2 verifications (H2, LSP), docs overhaul (tutorial 1–33, 52 API), 1 planning doc (Register VM Phase 0).

Next recommendation: User feedback cycle atau Tier 2.5 (extend superinstructions). Register VM Tier 3 defer — butuh user report konkret dulu. Full design doc siap di feat/register-vm branch kapan pun dibutuhkan.

Lesson kunci: Backlog context 6–9 versi stale — verify runtime > percaya label. Patch workflow dengan intermediate backups + fail-safe rollback = zero broken commits across 22 releases.

---

Simpan dokumen ini sebagai 
SESSION_HANDOVER_2026-11-01.md 
di repo (branch main, docs commit terpisah) jika ingin permanent reference. Untuk chat baru, cukup copy section 1–5 + anti-drift.