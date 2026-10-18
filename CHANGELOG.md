# Changelog

Semua perubahan penting pada Pascak VM dicatat di sini.

Format mengikuti [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versi mengikuti [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

### Planned
- Register-based VM (tier-2 JIT)
- Concurrent GC
- HTTP/2 multiplexing (parallel requests via 1 connection)
- ChaCha20-Poly1305 cipher
- JSON Schema validation
- In-process embedding (B.7b, zero-cost callback)

### Backlog
- WebSocket client bidirectional bridge (B.7b extension)
- WASM target
- Package manager: HTTP registry

---

## [0.4.0] — 2026-10-18

**Fase D + E.4 — HTTP/2 Client + Full IDE Stack**

Full IDE support untuk VSCode: syntax highlight + LSP (diagnostics, hover,
completion, go-to-definition). HTTP/2 client single-stream (multiplexing
di backlog). Formatter + linter improved.

### Added

#### E.4 — Full IDE Stack (VSCode Extension)

- **E.4 Phase 1** — TextMate grammar (`vscode/syntaxes/pascak.tmLanguage.json`):
  keyword, string, comment, number, operator, F-string interpolation.
  Extension mapping: `.pascak`, `.psk` (tidak claim `.pas`).
- **E.4 Phase 2a** — LSP server lifecycle + diagnostics + hover:
  - `initialize`, `shutdown`, `didOpen`, `didChange`, `didClose` handlers
  - Diagnostics: W001 unused var, W002 unreachable, E001 duplicate decl
  - Hover: type hint untuk variable/const/function/class
- **E.4 Phase 2b** — LSP completion + go-to-definition:
  - Autocomplete: keyword (43), module (12), builtin (38), local vars/func/class
  - `textDocument/definition` — jump ke declaration
- **E.4 Phase 3** — VSCode client (`vscode/extension.js`):
  - `LanguageClient` spawn `pascak_noASTnet --lsp` (stdio transport)
  - Config: `pascak.serverPath`, `pascak.enableLSP`
  - File watcher `**/*.{pascak,psk}`

#### D.2 — HTTP/2 Client (`pascak_h2*.pas`)

- **D.2.1** — Frame layer (`pascak_h2.pas`, 489 lines): 10 frame types
  (DATA, HEADERS, PRIORITY, RST_STREAM, SETTINGS, PUSH_PROMISE, PING,
  GOAWAY, WINDOW_UPDATE, CONTINUATION). Incremental parser + builder.
- **D.2.2** — HPACK Huffman decoder (`pascak_h2_huffman.pas`, 181 lines):
  257-symbol code table (RFC 7541 App. B), bit-level tree walk, EOS
  detection.
- **D.2.3** — HPACK decoder (`pascak_h2_hpack.pas`): 61-entry static
  table, dynamic table FIFO eviction, 5 header field patterns
  (Indexed, Literal+Incremental, Literal+Never, Literal+NoIdx,
  Size Update).
- **D.2.4** — HPACK encoder: 3-tier strategy (exact static match →
  name-only static match → full literal). 17/17 round-trip assertions.
- **D.2.5** — TLS ALPN extension (`pascak_tls.pas`): `TLSConnectALPN`,
  `SSL_set_alpn_protos`, `SSL_get0_alpn_selected`. Verified 'h2'
  negotiation vs httpbin.org (Cloudflare).
- **D.2.6** — `TH2Connection` state machine (`pascak_h2_conn.pas`,
  377 lines): client preface, SETTINGS handshake, single-stream HEADERS
  + DATA, frame dispatch, response accumulation.
- **D.2.7** — Engine integration: `http.get2(url, [headers], [body])`
  native. Full TLS+ALPN+H2 handshake + HPACK round-trip. Returns
  `{status, version: 'h2', headers, body}`.

#### D.2b — HTTP/2 Connection Pool

- `TH2Pool` with max-per-host (default 8), idle timeout (30s),
  hit/miss counters, LRU eviction.
- Engine integration: `http.get2PoolStats()`, `http.get2PoolConfig()`,
  `http.get2PoolClear()`.
- Scope: single-stream (serial) pooling — connection reuse untuk
  sequential requests. Multiplexing di backlog.

#### E.1b + E.2b — Formatter + Linter Improvements

- **E.1b** — Formatter operator spacing: `+`, `-`, `*`, `/`, `%`,
  comparison operators auto-spaced. Compound assignment (`+=`, `-=`,
  dll) preserved. Unary `+`/`-` detection (tidak di-space).
- **E.2b** — Linter function detection: unused function (W003) tidak
  lagi warn jika function dipanggil dari function lain. Function
  tracking di scope stack (`IsFunction` flag).

---

## [0.3.0] — 2026-10-10

**Fase 1 — Hardening**: context isolation, async I/O, production hardening.

### Added
- **Fase 1.1** — Context-aware memory quota (`AllocateQuotaCtx`).
  Per-`TEngineContext` `MemUsage` + `MemQuota`. Fallback global untuk CLI.
- **Fase 1.3** — Async File I/O lengkap (`fs.readAsync`,
  `fs.writeAsync`, `fs.appendAsync`, `fs.pollAsync`, `fs.waitAsync`,
  `fs.cancelAsync`, `fs.freeAsync`). Batas baca 64 MB.
- **Fase 1.5** — Worker exception markers (`__worker_crash`,
  `__worker_kind`) di-set oleh `sys.execAsync`, `poolRun`,
  `http.getAsync`, `fs.readAsync` saat worker crash.
- **CLI flag** `--dev` — membuka env override `PASCAK_EXEC_POLICY` +
  `PASCAK_TLS_NO_VERIFY`. Tanpa `--dev`, kedua env diabaikan.

### Changed
- **Fase 1.2** — Two-phase destruction `TSymbolTable`: cut semua
  reference dulu (di dalam lock), baru free `TValue` (di luar lock).
  Cegah cascade AV saat engine shutdown.
- **Fase 1.4** — Env override hanya di-honor bila `--dev` di-pass.
  Pertahanan terhadap privilege escalation via env poisoning.

### Fixed
- `pascak_poller.pas` — retry `EINTR` di `epoll_wait`.
- `pascak_wsevloop.pas` — hapus blok duplikat di `ProcessFramesInBuf`
  (WS message dispatched 2×); fragmentation buffer dispatch `FragBuf`
  bukan `Frame.Payload`.
- `pascak_noASTnet.pas` — `Native_Sleep` tick per-engine `EventLoop`
  via `TickOnce`, bukan hanya `GWSEventLoop`.

---

## [0.2.0] — 2026-10-08

**Fase 0 — Correctness & Security**: 8 patch audit mendalam.

### Added
- **Fase 0.3** — FFI whitelist MD5 wiring (opt-in, default off).
- **Fase 0.4** — Rename `AES_EncryptString`/`AES_DecryptString` →
  `ObfuscateString`/`DeobfuscateString`.

### Changed
- **Fase 0.1** — TLS context cache dipisah per verify flag.
- **Fase 0.6** — Dokumentasi ownership `TSymbolTable.DefineVar`.

### Fixed
- **Fase 0.2** — Sandbox symlink resolve (`realpath(3)` /
  `GetFinalPathNameByHandleW`).
- **Fase 0.5** — `CallbackDispatcher` restore `GCurrentContext` di
  `finally`.
- **Fase 0.7** — HTTP client socket double-close race.
- **Fase 0.8** — TLS verify override via `PASCAK_TLS_NO_VERIFY` +
  `X-Pascak-No-Verify` header.

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

**MAJOR.MINOR.PATCH** — [Semantic Versioning](https://semver.org/)

- **MAJOR** — breaking change di API publik
- **MINOR** — fitur baru backward-compatible
- **PATCH** — bug fix backward-compatible

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
