
Semua perubahan penting pada Pascak VM dicatat di sini.

Format mengikuti [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
Versi mengikuti [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased] — Fase 2 (WIP)

### Planned
- HTTP client connection pooling
- Public `setInterval` / `setTimeout` API
- WebSocket client (`ws.connect`)
- Public `jsonPath()` helper
- Interactive REPL
- Coroutine scheduler

### Backlog
- Register-based VM (tier-2 JIT)
- Concurrent GC
- HTTP/2
- ChaCha20-Poly1305 cipher
- JSON Schema validation

---

## [0.3.0] — 2026-10-10

**Fase 1 — Hardening**: context isolation, async I/O, production hardening.

### Added
- **Fase 1.1** — Context-aware memory quota (`AllocateQuotaCtx`).
  Setiap `TEngineContext` punya `MemUsage` + `MemQuota` sendiri.
  Fallback ke global quota kalau context nil (mode CLI).
- **Fase 1.3** — Async File I/O lengkap:
  - `fs.readAsync(path, [callback])`
  - `fs.writeAsync(path, data, [callback])`
  - `fs.appendAsync(path, data, [callback])`
  - `fs.pollAsync(taskID)`
  - `fs.waitAsync(taskID, [timeoutMs])`
  - `fs.cancelAsync(taskID)`
  - `fs.freeAsync(taskID)`
  Batas baca 64 MB. Auto-free dengan callback.
- **Fase 1.5** — Worker exception markers (`__worker_crash`,
  `__worker_kind`) di-set oleh `sys.execAsync`, `poolRun`,
  `http.getAsync`, `fs.readAsync` saat worker crash.
- **CLI flag** `--dev` — membuka env override `PASCAK_EXEC_POLICY` +
  `PASCAK_TLS_NO_VERIFY`. Tanpa `--dev`, kedua env var ini diabaikan.
- **Regression test suite**: 29/29 PASS (test_all.pas driver).
- **Test regresi baru**:
  - `test_sandbox_symlink.pas` — Fase 0.2
  - `test_env_guard.pas` — Fase 1.4
  - `test_tls_cache.pas` — Fase 0.1 + 0.8
  - `test_fs_async.pas` — Fase 1.3 (19 assertions)
  - `test_engine_leak.pas` — Fase 1.2 (5 assertions)

### Changed
- **Fase 1.2** — Two-phase destruction `TSymbolTable`. Cut semua
  reference dulu (di dalam lock), baru free TValue (di luar lock).
  Cegah cascade AV saat engine shutdown.
- **Fase 1.4** — Env override `PASCAK_EXEC_POLICY` +
  `PASCAK_TLS_NO_VERIFY` hanya di-honor bila `--dev` di-pass.
  Ini pertahanan terhadap privilege escalation via env poisoning.

### Fixed
- **`pascak_poller.pas`** — retry loop untuk `EINTR` di `epoll_wait`.
  Sebelumnya signal dari `sys.exec` subprocess / socket lain bisa
  matikan event loop.
- **`pascak_wsevloop.pas`** — hapus blok duplikat di
  `ProcessFramesInBuf` yang menyebabkan pesan WS di-dispatch 2×.
- **`pascak_wsevloop.pas`** — fragmentation buffer: dispatch
  `Conn.FragBuf` (akumulasi), bukan `Frame.Payload` (frame terakhir).
- **`pascak_noASTnet.pas`** — `Native_Sleep` sekarang tick per-engine
  `Ctx.EventLoop` via `TickOnce`, bukan hanya `GWSEventLoop`.
  Worker pool / HTTP async / timer callback fire selama `sleep()`.
- **`test/test_all.pas`** — propagate `--dev` ke child subprocess.
  Tanpa ini, test WS event-mode skip karena `sys.exec` di-deny.

---

## [0.2.0] — 2026-10-08

**Fase 0 — Correctness & Security**: 8 patch audit mendalam.

### Added
- **Fase 0.3** — FFI whitelist MD5 wiring (opt-in, default off).
  Set `FFIModuleWhitelist` dari host code untuk aktifkan.
- **Fase 0.4** — Rename `AES_EncryptString` / `AES_DecryptString` →
  `ObfuscateString` / `DeobfuscateString`. Hapus kebingungan dengan
  AES cipher sebenarnya.

### Changed
- **Fase 0.1** — TLS context cache dipisah per verify flag:
  `GSharedTLSContextVerify` + `GSharedTLSContextNoVerify`. Sebelumnya
  satu context di-share → verify mode bocor antar request.
- **Fase 0.6** — Dokumentasi ownership contract `TSymbolTable.DefineVar`.
  Caller menyerahkan ownership `TValue` — kalau error, `DefineVar`
  yang `Free`.

### Fixed
- **Fase 0.2** — Sandbox symlink resolve via `realpath(3)` (Unix) +
  `GetFinalPathNameByHandleW` (Windows). Sebelumnya symlink di dalam
  sandbox bisa escape ke luar.
- **Fase 0.5** — `CallbackDispatcher` restore `GCurrentContext` di
  `finally` block. Sebelumnya context leak antar callback.
- **Fase 0.7** — HTTP client socket double-close. Race antar
  `TLSConn.Release` dan `NetClose(Sock)`.
- **Fase 0.8** — TLS verify override via `PASCAK_TLS_NO_VERIFY`
  env + header `X-Pascak-No-Verify`. Sebelumnya flag di-ignore
  karena `SSL_get_verify_result` selalu dipanggil.

---

## [0.1.0] — 2026-10-01

**Baseline**: versi stabil pertama sebelum audit mendalam.

### Added
- Core VM: lexer, parser, compiler, stack-based interpreter.
- Type system: numeric, string, boolean, null, array, dict, object,
  function, native function, class, pointer, DLL handle.
- GC: generational (Gen0 + Gen1) dengan zombie queue.
- Coroutine support (`coroutine_create`, `resume`, `coroutine_free`).
- Event loop dengan timer + I/O wait.
- Worker pool (8 thread) untuk task paralel.
- WebSocket server (RFC 6455) — plain + TLS, thread + event mode.
- HTTP client + server (sync + async).
- TLS binding via libssl 1.1.x / 3.x.
- SQLite via `sqlite3conn` FFI.
- FFI: `dll.load`, `lib.func`, `lib.callback`, native buffer, struct
  by value.
- Crypto: SHA-256, HMAC-SHA256, AES-128/192/256, PBKDF2, secure random.
- Package manager: local registry, semver resolver, lockfile.
- Exec policy: whitelist, rlimit, env sanitize, audit log.
- Sandbox: filesystem path restriction, control char strip.
- DEFLATE/zlib/gzip standalone (`paszlib.pas`).

---

## Format Versi

**MAJOR.MINOR.PATCH**

- **MAJOR** — breaking change di API publik (parser, VM, stdlib)
- **MINOR** — fitur baru backward-compatible
- **PATCH** — bug fix backward-compatible

Contoh:
- `0.1.0` → `0.2.0`: fitur baru (Fase 0 security patches)
- `0.2.0` → `0.3.0`: fitur baru (Fase 1 hardening)
- `0.3.0` → `0.3.1`: bug fix saja
- `0.x` → `1.0.0`: stabil, siap production

---

## Kategori

- **Added** — fitur baru
- **Changed** — perubahan behaviour existing
- **Deprecated** — fitur yang akan dihapus
- **Removed** — fitur yang sudah dihapus
- **Fixed** — bug fix
- **Security** — vulnerability fix

---

## Kontribusi

Setiap PR yang mengubah API / behaviour **wajib** update CHANGELOG.
Entry ditulis dengan gaya imperatif: "Tambah X", "Perbaiki Y",
"Rename Z".

Tambahkan entry di section `[Unreleased]` sebelum release.
Saat release, pindahkan ke section versi baru + update tanggal.
```

---

✅ Verifikasi

Setelah semua langkah di atas, jalankan cek cepat:

```bash
cd ~/storage/downloads/termux/pascak/docs

# 1. Cek section Filesystem ada di API
grep -n "^## Filesystem" pascak_api.md
# Expected: baris dengan "## Filesystem"

# 2. Cek Bab 23 + 24 ada di tutorial
grep -n "^## Bab 23" tutorial.md
grep -n "^## Bab 24" tutorial.md
# Expected: masing-masing 1 baris

# 3. Cek CHANGELOG baru
ls -la CHANGELOG.md
# Expected: file ada, size > 5 KB

# 4. Cek TOC update
grep -n "Filesystem" pascak_api.md | head -3
grep -n "Async File I/O" tutorial.md | head -3
```

## [Unreleased]

### Added
- **B.1** — Public Timer API:
  - `setTimeout(fn, ms) → timerID` — fire callback once after delay
  - `setInterval(fn, ms) → timerID` — fire callback repeatedly
  - `clearTimeout(timerID)` / `clearInterval(timerID)` — cancel pending timer
  - Auto-cleanup via existing RunLoop dead-task sweep
- **B.2** — Public `jsonPath(dict, "a.b.c") → value | null` helper:
  - Traverse nested dict via dot-separated path
  - Returns `null` if segment missing or intermediate not a dict
  - Thread-safe via GetValueClone ownership

### Notes
- Git repository initialized. Initial baseline commit: `6019a6d`
- Test suite: 27/29 PASS + 2 soft-skip (network-dependent)



Semua 4 langkah di atas selesai → Fase A selesai ✅

---

🎯 Langkah Selanjutnya

Setelah Fase A selesai, lanjut Fase C (Backlog Fixes) — cleanup warning + parser quirk. Effort ~1 jam. Kalau Anda mau saya siapkan langkah-langkah Fase C juga, tinggal bilang.

Tidak ada perubahan kode di Fase A ini — hanya dokumentasi. Aman untuk commit langsung ke main tanpa testing tambahan.