📋 Ringkasan Lengkap Proyek Pascak VM

Tanggal: 12 Oktober 2026
Status: 6 commit clean, 29/29 PASS, 0 warning
Resume Point: commit aebe32a

---

🎯 Gambaran Proyek

Pascak VM — bahasa scripting Pascal-like dengan VM stack-based, target utama Termux/Android + Linux/macOS/Windows. Fitur inti:

· Bahasa: Pascal-like syntax (begin...end., var, function, lambda, class, record)
· Runtime: interpreter bytecode VM dengan generational GC
· Concurrency: coroutine + event loop + worker pool
· Networking: HTTP/HTTPS client+server, WebSocket server
· Interop: FFI ke shared library C, struct by value, callback bridge
· Security: sandbox filesystem + exec policy + memory quota

---

✅ YANG SUDAH BERHASIL DIKEMBANGKAN

Fondasi Awal (Sebelum Sesi Ini)

Fase 0 — Correctness & Security (8/8) ✅

# Patch
0.1 TLS context cache per verify flag
0.2 Sandbox symlink resolve via realpath(3)
0.3 FFI whitelist MD5 wiring (opt-in)
0.4 Rename AES_* → Obfuscate*
0.5 CallbackDispatcher context restore
0.6 DefineVar ownership contract
0.7 HTTP client socket double-close
0.8 TLS verify override working

Fase 1 — Hardening (5/5) ✅

# Patch
1.1 Context-aware memory quota (AllocateQuotaCtx)
1.2 Two-phase destruction TSymbolTable
1.3 Async File I/O (fs.readAsync + 6 siblings)
1.4 Env poisoning guard (--dev flag)
1.5 Worker exception markers (__worker_crash)

---

Sesi Ini (12 Oktober 2026)

Fase A — Dokumentasi ✅

· docs/pascak_api.md — Section Filesystem lengkap (sync + async API)
· docs/tutorial.md — Bab 23 (Async File I/O), Bab 24 (Parser Quirk)
· docs/CHANGELOG.md — File baru, cover v0.1.0 → v0.3.0

Fase C — Warning Cleanup ✅

Fix Detail
CRITICAL TDictValue.CompoundAssign — return Result := ResultVal; (sebelumnya return nil)
Hapus unused GSharedTLSContext, FragOpcode
Add gc_gen0 Ke runtimeStats() output
Silence 5 Managed-type warnings via Result := nil
Silence 1 Unreachable return di Native_SysExit

Git Setup ✅

· Repo aktif di ~/storage/downloads/termux/pascak/
· .gitignore lengkap: build artifacts, backups, scratch files
· Initial commit 6019a6d: 88 files, 61,130 insertions

Fase B.1 — Timer API ✅

```pascal
setTimeout(fn, ms) → timerID       // fire once
setInterval(fn, ms) → timerID      // fire repeatedly
clearTimeout(timerID) → bool
clearInterval(timerID) → bool
```

· TEventTask.TimerID field (Int64 monotonic)
· TEventLoop.SetTimer return unique ID
· Test: test/test_timer.pas — 4/4 PASS

Fase B.2 — jsonPath Helper ✅

```pascal
jsonPath(dict, "a.b.c") → value | null
```

· Traverse nested dict via dot-separated path
· Return null kalau segment missing
· Test: test/test_jsonpath.pas — 7/7 PASS

Fase B.6 — Docs Update ✅

· pascak_api.md: Timer + JSON Path sections
· tutorial.md: Bab 25 (Timer & JSON Path) dengan contoh praktis

Fase B.3 — Interactive REPL ✅

```bash
~/pascak_noASTnet --repl
```

· Expression vs statement auto-detection
· Multi-input state persistence
· Special: .exit, .help, .clear
· Refactor: EnsureGlobalsInit (extract global init)

Fase B.3b — REPL Background Event Loop ✅

· ReadLineWithTick — poll stdin + tick event loop setiap 50ms
· Timer fire saat idle (sebelumnya tidak)
· Unix select()-based; Windows fallback ke blocking

---

Fitur Yang Sudah Berfungsi

Bahasa

· Variabel, konstanta, tipe data (numeric, string, bool, null, array, dict, object, function, class, pointer)
· Control flow: if/else, while, repeat/until, for (to/downto/step), for...in, case, try/catch/finally, lock, ternary ?:
· Fungsi named + lambda + closure
· F-string interpolation
· Exception handling dengan type filter

Standard Library

Modul Isi
Global print, println, len, str, typeOf, toInteger, toFloat, toString, push, pop, sort, join, map, filter, reduce, dll
math sin/cos/tan, sqrt, pow, log, factorial, permutation, combination, statSum/Mean/Median/Mode, EMA, RSI
crypto SHA-256, HMAC-SHA256, SHA-1, AES-128/192/256, PBKDF2, secure random, base64
time now, format, iso8601, parseISO, diff, add, startOfDay/Month/Year, zoneOffset
net TCP socket (listen/accept/connect/send/recv), DNS resolver pure Pascal
http Client (sync/async), Server (plain + TLS), REST helper
fs glob, walkDir, stat, copy, move, chmod, tempFile, rmDir + async variants
sqlite Connect, exec, query, close
dll load, func, symbol, callback, closure info
native fromArray, bufferPtr, structType, newStruct, structGet/Set
tls init, shutdown, version, isLoaded
ws serve, serveTLS, listen, listenAsync, listenThreads, broadcast, stop, clients
sys args, env, exit, exec, memoryUsage, threadErrors
pkg install, list, resolve
hardware peek, poke, alloc, free
Timers (B.1) setTimeout, setInterval, clearTimeout, clearInterval
JSON Path (B.2) jsonPath

FFI

· Load shared library (dll.load)
· Call typed function (lib.func dengan signature)
· Raw symbol access (lib.symbol)
· Native callback bridge (lib.callback)
· Native buffer (native.fromArray, bufferPtr, bufferToArray)
· Struct by value (native.structType, newStruct, structGet/Set)
· Support signature: i (Int64), f (Double), s (string), p (pointer), I (size_t), S (struct), v (void), C (callback)

Concurrency

· thread(fn) — spawn script thread
· poolRun(fn) — worker pool (8 concurrent)
· coroutine_create / resume / coroutine_free
· on / emit — event emitter
· Worker / workerPost / workerGet — isolated worker dengan message queue

Security

· Sandbox: filesystem path restriction, symlink resolve, control char strip
· Exec policy: whitelist, rlimit (CPU/mem/file/subprocess), env sanitize, audit log
· Memory quota per engine
· --dev flag gate untuk env override
· FFI whitelist (opt-in)

---

🚧 YANG BELUM DIKERJAKAN

Fase 2 — Performance & Fitur (Backlog)

# Task Effort Prioritas Dampak
B.4 WebSocket client (ws.connect) 3-4 jam 🟠 High Script bisa jadi WS client
B.5 HTTP client connection pooling 3-4 jam 🟠 High Perf: 5-10× untuk banyak request
B.7 Export public API (pascak_api unit) 2-3 jam 🟡 Medium Embed di Pascal host
B.8 CHANGELOG update B.3/B.3b 10 min 🟢 Low Sync docs
D.1 Coroutine scheduler (yield-based) 2-3 jam 🟡 Medium Async/await style
D.2 HTTP/2 support 6-8 jam 🟡 Medium Modern protocol
D.3 ChaCha20-Poly1305 cipher 2-3 jam 🟡 Medium Modern AEAD
D.4 JSON Schema validation 2-3 jam 🟢 Low Schema validation
D.5 Package manager HTTP registry 4-6 jam 🟡 Medium Remote install

Fase 3 — Advanced (Jangka Panjang)

# Task Effort Alasan
E.1 Register-based VM 2-3 minggu Performance fundamental
E.2 JIT-lite tier-2 3-4 minggu Hot path optimization
E.3 Concurrent GC 1-2 minggu Multi-engine safety
E.4 WASM target 4-6 minggu Cross-platform compile
E.5 Kernel sandbox (namespace/chroot) 1-2 minggu Butuh root
E.6 Binary hash verification 3-5 hari Exec policy hardening

Known Issues / Gaps

Issue Severity Catatan
REPL Windows: blocking Readln 🟢 Low Hanya Unix yang bg-tick
eval("begin 6*7; end.") return null 🟢 Low By design — butuh return
FPC warning dari fgl.pp ⚪ Info Bukan kode kita
REPL .help minim 🟡 Medium Bisa diperluas
Parser quirk: try..catch di loop 🟡 Medium Butuh begin..end — sudah didokumentasikan
CompoundAssign untuk -/*// masih lewat strategi B 🟢 Low Bisa dioptimasi lebih lanjut
HTTP pooling belum ada 🟠 High Setiap request = new TCP

---

🎯 RENCANA PENGEMBANGAN BERIKUTNYA

Roadmap 3 Sesi Berikutnya

Sesi #2 (4 jam):

1. B.4 WebSocket client (ws.connect)
   · Buka koneksi ke server WS eksternal
   · Handler callback (onOpen, onMessage, onClose)
   · Kirim text/binary frame
   · Test: konek ke wss://echo.websocket.org atau server sendiri
2. B.8 CHANGELOG update (10 min)

Sesi #3 (4 jam):

1. B.5 HTTP client connection pooling
   · Reuse socket untuk multiple request ke host yang sama
   · Max pool size + idle timeout
   · Bench: 100 request sequential (dengan vs tanpa pool)
   · Target: 5-10× improvement
2. B.7 Export public API (2-3 jam)
   · Unit pascak_api.pas yang bisa di-uses dari Pascal host
   · Interface: TPascakEngine sebagai lib
   · Contoh: embed di aplikasi Lazarus

Sesi #4 (4 jam):

1. D.1 Coroutine scheduler
   · async function + await style
   · Task queue + scheduler
   · Contoh: fetch 10 URL paralel dengan syntax sync
2. D.3 ChaCha20-Poly1305 (optional)
   · Modern AEAD cipher
   · Untuk TLS 1.3, file encryption

Long-Term Vision (6-12 bulan)

1. Standard library expansion
   · Regex lebih lengkap
   · Date/Time timezone database
   · Compression: zstd
   · YAML parsing
   · HTTP/2 + WebSocket client
2. Tooling
   · Package registry server (HTTP)
   · Formatter (seperti gofmt)
   · Linter + static analyzer
   · VSCode syntax highlighting
3. Performance
   · Register-based VM (transisi dari stack-based)
   · Tier-2 JIT untuk hot loops
   · Profile-driven optimization
4. Interop
   · WASM target (compile ke WebAssembly)
   · C API untuk embedding
   · Python/Rust binding
5. Ecosystem
   · Package marketplace
   · Documentation website
   · Tutorial video
   · Community forum

---

💡 SARAN REKOMENDASI — WAJIB ADA

Kategori A — Kritikal (Harus Ada untuk Production)

# Fitur Alasan Effort
A.1 HTTP client pooling Setiap http.get() sekarang buka TCP baru — lambat untuk API yang sama dipanggil 100× 3-4 jam
A.2 Structured logging Tidak ada logger.debug/info/warn/error — sulit trace production issue 1-2 jam
A.3 Config management Baca .env, config.json, env override dengan precedence 2 jam
A.4 Health check + metrics endpoint Production service butuh /health dan /metrics 1-2 jam
A.5 Graceful shutdown hooks onShutdown(fn) — cleanup DB, tutup koneksi WS 1 jam

Kategori B — Sangat Direkomendasikan

# Fitur Alasan Effort
B.1 HTTP client pooling (lihat A.1) — —
B.2 Signal handling (SIGTERM, SIGINT) Untuk graceful shutdown via kill 1-2 jam
B.3 Log rotation File log bisa tumbuh tak terbatas 1 jam
B.4 Rate limiting helper Untuk API server, cegah abuse 2 jam
B.5 Request ID tracking Trace request lintas async boundary 1 jam
B.6 WebSocket client (B.4 roadmap) Untuk microservice-to-microservice 3-4 jam
B.7 Timeout helper withTimeout(fn, ms) untuk async ops 1 jam
B.8 Retry helper retry(fn, maxAttempts, backoffMs) 1 jam

Kategori C — Nice to Have (Bisa Nanti)

# Fitur Alasan Effort
C.1 Regex dengan named group Parsing lebih kompleks 2 jam
C.2 Date/Time DST support Zona waktu dengan DST 3 jam
C.3 CLI argument parser --help, --version otomatis 1-2 jam
C.4 Template engine HTTP response HTML rendering 2-3 jam
C.5 YAML parser Config files lebih readable 2 jam
C.6 Compression: zstd Lebih cepat dari gzip 3-4 jam

Kategori D — Wajib untuk Production Service

Kalau Pascak VM akan dipakai untuk production HTTP/WS service, ini wajib:

# Fitur Kenapa Wajib
D.1 HTTP keep-alive client 21× throughput (sudah ada di server)
D.2 Connection pool dengan health check Cegah koneksi mati
D.3 Structured error response Debug production issue
D.4 Metrics: request count, latency P50/P95/P99, error rate Observability
D.5 Graceful shutdown: tunggu request aktif selesai Zero-downtime deploy
D.6 Request timeout global Cegah request lambat block worker
D.7 Body size limit (sudah ada di HTTP parser — 10 MB) DoS prevention
D.8 Rate limiting per IP DoS prevention
D.9 Circuit breaker untuk dependency down Resilience
D.10 Audit log semua exec + FFI Forensik

Kategori E — Wajib untuk Developer Experience

# Fitur Kenapa Wajib
E.1 Formatter (pascak fmt) Konsistensi style antar developer
E.2 Linter (pascak lint) Catch bug sebelum runtime
E.3 Language server (LSP) Autocomplete + go-to-def di editor
E.4 Debugger via DAP Debug step-by-step (sudah ada stub D-1)
E.5 Test runner proper pascak test — jalan semua *_test.pas
E.6 Package manager registry server pkg.install remote

Prioritas Eksekusi (Rekomendasi)

Kalau fokus Production Service (HTTP/WS):

```
1. A.1 (HTTP client pooling)      ← bottleneck #1
2. D.5 (Graceful shutdown)
3. D.4 (Metrics)
4. D.6 (Request timeout)
5. B.2 (Signal handling)
6. A.5 (onShutdown hooks)
```

Kalau fokus Embedding (Pascal host):

```
1. B.7 (Export public API)
2. E.4 (DAP debugger completion)
3. A.2 (Structured logging)
4. A.3 (Config management)
```

Kalau fokus Developer Experience:

```
1. E.1 (Formatter)
2. E.2 (Linter)
3. E.5 (Test runner)
4. E.3 (Language server)
```

Kalau fokus Feature Lengkap:

```
1. B.4 (WebSocket client)
2. D.1 (Coroutine scheduler)
3. C.5 (YAML parser)
4. D.2 (HTTP/2)
```

---

📌 Catatan Penting untuk Sesi Berikutnya

Setup Cepat

```bash
cd ~/storage/downloads/termux/pascak
git log --oneline -5              # lihat posisi
git status                        # cek clean

# Rebuild
fpc -Mobjfpc -Sh pascak_noASTnet.pas 2>&1 | grep -E "Error|Warning.*pascak"
cp pascak_noASTnet ~/pascak_noASTnet

# Test
PASCAK_EXEC_POLICY=allow-all ~/pascak_noASTnet --dev test/test_all.pas 2>&1 | grep RESULT
```

Aturan Development

1. Selalu commit sebelum task baru — checkpoint
2. Test suite harus PASS sebelum commit
3. 0 warning target setiap build
4. Backup via git — bukan .bak-* manual
5. --dev flag untuk env override di development

Parser Quirk yang Perlu Diingat

· try..catch di dalam loop butuh begin..end di catch body
· eval() return null kalau tidak ada return eksplisit
· Tidak ada elif — pakai sequential if
· Dot notation untuk keyword (req.method) error — pakai req["method"]

---

🏁 Kesimpulan

Sesi ini: 6 commit clean, semua test PASS, dokumentasi sync.

Kekuatan proyek saat ini:

· Foundation yang kuat (Fase 0 + 1 selesai)
· FFI + Native Struct bekerja
· HTTP/WS server + TLS production-ready
· Async I/O (FS + exec)
· Security: sandbox + exec policy

Gap utama untuk production:

· HTTP client pooling
· Structured logging + metrics
· Graceful shutdown
· Signal handling

Gap utama untuk DX:

· Formatter + linter
· Package registry server
· Better error messages

Resume point: aebe32a — tinggal git pull atau git log --oneline untuk lanjut.

---

