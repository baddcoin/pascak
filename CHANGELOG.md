# Changelog

## [1.2.8] - 2026-10-27

### Added
- **GOAWAY classification** — `http.get2` error message now distinguishes retryable vs fatal failures with H2 error code.
- `TH2Response.ErrorCode` + `TH2Response.Retryable` fields (public API for programmatic retry).
- `TH2Connection.FGoAwayErrCode` tracks RFC 7540 error code from GOAWAY frame.

### Behavior
- No change for happy path (http.get2 success -> status 200, pool reuse works).
- On failure, error message format:
  - Retryable: `request gagal (retryable, code=N) - <detail> — hint: retry on fresh connection`
  - Fatal: `request gagal (fatal, code=N) - <detail>`
- Retryable classification:
  - `H2_ERR_NO_ERROR` / `H2_ERR_ENHANCE_YOUR_CALM` -> retryable
  - Connection closed / reader thread unavailable -> retryable
  - Other H2 protocol errors -> fatal

### Deferred (v1.2.9)
- Auto-retry loop (needs mock GOAWAY server test infra)
- Rate limiter backoff on `H2_ERR_ENHANCE_YOUR_CALM`

### Regression
- 130/130 prior tests PASS + happy path verified.

## [1.2.7] - 2026-10-27

### Added
- **Optional method call** — `obj?.method()` and `obj?.method(args)` short-circuit on null target. Args not evaluated on null (short-circuit). Chains with property access: `obj?.prop?.method()`.

### Implementation
- `TMethodCallNode` extended with `IsOptional: Boolean`.
- Compiler emits `opcJumpIfNull` before method call when optional.
- VM unchanged — `opcJumpIfNull` already peek-only since v1.1.0.

### Regression
- 130/130 tests PASS (9 new v1.2.7 + 121 prior).

## [1.2.6] - 2026-10-27

### Added
- **Rest in nested destructuring** — `var {cfg: {host, ...rest}} = obj`, 2+ level `var {a: {b: {x, ...r}}} = obj`, array+obj mixed `var [first, {u, ...v}, last] = arr`.
- Emit path-aware: numeric rest leaf → slice, string rest leaf → omit siblings at that nesting level only.

### Refactored
- Unified rest emit logic (root and nested share one code path).
- Backward compatible: root-level rest identical to v1.2.5 behavior.

### Regression
- 121/121 tests PASS (18 new v1.2.6 + 103 prior).

## [1.2.5] - 2026-10-27

### Added
- **Object rest destructuring** — `var {a, b, ...rest} = obj` captures remaining keys into new dict. Combines with nested: `var {cfg: {h}, ...rest} = obj` excludes `cfg` top-level key from `rest`.

### Added (runtime)
- `dict.omit(keys_array)` native method — returns clone of dict excluding specified keys.

### Notes
- Object rest uses TMethodCallNode emit calling `__tmp.omit([known_keys])`.
- Array rest (v1.2.1) unchanged — still uses slice.
- Rest inside nested (`var {a: {b, ...r}}`): deferred to v1.2.6.

### Regression
- 103/103 tests PASS (18 new v1.2.5 + 85 prior).

## [1.2.4] - 2026-10-27

### Added
- **Arbitrary-depth nested destructuring** — `var {a: {b: {c: {d}}}} = obj` and beyond. Parser refactored to recursive `ParsePattern`.
- **Array-root nested** — `var [a, {u, v}, c] = arr`, `var [p, [q, r], s] = arr`, combined with rest `var [a, {b}, ...rest] = arr`.

### Refactored
- `TParser.ParsePattern` recursive helper replaces inline 2-level logic.
- Emit path iterator uses `StrToInt(path)` for array index; backward-compat.

### Notes
- Object rest (`var {a, ...rest} = obj`) still deferred (needs `dict.omit()`): v1.2.5.

### Regression
- 85/85 tests PASS (29 new v1.2.4 + 56 prior).

## [1.2.3] - 2026-10-26

### Added
- **2-level nested destructuring** — `var {a: {b: {c, d}}} = obj` and `var {a: {b: [x, y]}} = obj`. Extends v1.2.2 (1-level obj-root) up to 2 levels.

### Notes
- Deeper than 2 level, array-root nested, object rest, rest-inside-nested: deferred to v1.2.4.
- Emit refactored to iterate-all-dots path (backward compatible).

### Regression
- 14/14 v1.2.3 tests + 69/69 prior tests PASS.

## [1.2.2] - 2026-10-26

### Added
- **Nested destructuring (obj-root)** — `var {a: {b, c}} = obj` and `var {a: [x, y]} = obj`. Supports mixed flat+nested, multi-nested, nested with default, statement + top-level scope.

### Notes
- Array-root nested (`var [a, {b}] = arr`), rest inside nested, and deeper than 1 level: deferred to v1.2.3.

### Regression
- 19/19 nested tests PASS + 41/41 prior tests PASS.

## [1.2.1] - 2026-10-26

### Added
- **Array rest element** — `var [first, ...tail] = arr` captures remaining elements as array slice (reuses existing slice syntax `arr[start:]`). Rest must be last, no default allowed. Out-of-bounds → empty array.

### Notes
- Object rest (`var {a, ...rest} = obj`) and nested destructuring (`var {a: {b}} = obj`): planned for v1.2.2.

### Regression
- 10/10 new tests PASS + 31/31 prior tests PASS (Phase 1/2/3 + v1.2.0 defaults).

## [1.2.0] - 2026-10-26

### Added
- **Destructure defaults** — `var {a = 10, b = 20} = obj` (dan array equivalent `var [x = 0, y = 100] = arr`) provide fallback when key missing / index out-of-bounds. Defaults apply on `null` only; `0`, `""`, `false` pass through.
- **Enum in function scope** — `enum Status { OK, ERR }` now allowed inside function body or `begin` block (previously top-level only). Same desugar as top-level (dict + const).

### Notes
- Nested destructuring (`var {a: {b}} = obj`) and rest element (`var {a, ...rest} = obj`): planned for v1.2.1.

### Regression
- 21/21 v1.1.x tests PASS (Phase 1/2/3 unchanged) + 10/10 new v1.2.0 tests PASS.

## [1.1.1] - 2026-10-26

### Fixed
- **Optimizer hardening** — `TChunk.OptimizeBytecode` now recognizes `opcJumpIfNull`/`opcJumpIfNotNull` as jump opcodes in both jump-target marking and operand-remap phases. Prevents stack underflow recurrence if future features emit dead code that triggers useless-jump removal. Synergistic with Fix A (v1.1.0) which prevents the trigger, this Fix B hardens the optimizer for any future recurrence.

### Regression
- 21/21 tests PASS (Phase 1: 8, Phase 2: 5, Phase 3: 8) — zero behavior change for existing features.

## [1.1.0] - 2026-10-25

### Added
- **Optional chaining `?.`** — `user?.name`, `cfg?.db?.host`
- **Null-coalescing `??`** — `null ?? 42` = 42, `0 ?? 42` = 0
- **Enum** — `enum Color { Red, Green, Blue }` (auto-numbered 0..N-1, immutable)
- **Destructuring** — `var {a,b} = obj`, `var [x,y] = arr` (top-level + statement)

### Fixed
- Stack underflow on `null?.name` — stale `opcJumpIfNull` operand after optimizer dead-code removal
- Dict property access on missing key returns null (nil-safe)
- VM nil-safe guards on `opcJumpIfNull` / `opcJumpIfNotNull`


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
- GUI: HTTPS localhost (self-signed)

### Backlog
- WebSocket client bidirectional bridge
- WASM target
- Package manager: HTTP registry
- GUI: dev-mode file watcher

---

## [0.6.0] — 2026-10-20

**Browser-Based GUI — HTTP + WS RPC bridge**

New `gui` module brings GUI to any Pascak app via local browser.
Zero external deps: HTML served from engine HTTP, JS bridges back
via WebSocket JSON-RPC. Works on Termux, Linux, macOS, Windows.
### Added

- **GUI (Browser-Based)** — new `gui` module, zero external deps:
  - `gui.create(port, [wsPort], [title]) -> handle`
  - `gui.serve(handle, html) -> bool` (auto-injects JS bridge script)
  - `gui.bind(handle, name, callback) -> bool` (register Pascal callback)
  - `gui.start(handle) -> bool` (bind HTTP + WS ports)
  - `gui.open(handle) -> bool` (spawn browser via termux-open-url/xdg-open)
  - `gui.run(handle)` (blocking event loop)
  - `gui.close(handle) -> bool` (cancels timer, clean shutdown)
  - Architecture: `http.serve` + auto `<script>` with
    `window.pascak.call(method, args) -> Promise`, JS↔Pascal via
    WebSocket JSON-RPC on separate port
  - HTTP accept driven by event-loop timer (poll), not blocking
  - `examples/hello_gui.pas` — counter demo with state in closure
  - `docs/pascak_api.md` §GUI (Browser-Based)

- **Handler type relaxations** — accept `dtNative` alongside `dtFunction`:
  - `http.serve` / `http.serveTLS` handler arg
  - `ws.serve` callbacks (`WSExtractHandlers`: onOpen/onMessage/onClose/onError)
  - WS client handlers (4×)
  - `Worker_HandleClient` (HTTP worker)
  - `CallWSCallback` (WS dispatch)
  - `TEventLoop.SetTimer` (for poll callback)

- **`NetAcceptTimeout` non-blocking** — `timeout=0` now uses 1ms poll
  (was blocking on `fpAccept`); GUI poll timer relies on this.

- **`gui.close` timer cleanup** — `PollTimerID` field cancels event-loop
  timer on close, prevents hang when script exits with active poll.

- **`gui.start` binds `127.0.0.1` explicitly** — `0.0.0.0` listen may
  not accept loopback on Termux.


## [0.5.0] — 2026-10-19

**B.7b milestone — In-Process Embedding + `elif`/`elseif` sugar**

Host Pascal code can now `uses pascak_engine` and register native
callbacks callable from script. Alternative `elif`/`elseif` spelling
shipped as pure lexer sugar. Full API docs added.


### Added
- **B.7b Session 1** — engine extraction to `pascak_engine.inc`
  (42,386 lines). Binary identical 2,940,840 bytes. Zero behavioral
  change verified (LSP 6/6 + full suite 30/30 PASS).
- **B.7b Session 2** — `pascak_engine.inc` converted to proper
  `pascak_engine.pas` unit (42,672 lines). Exposes `ExecuteEngine()`
  and `TPascakResult` to host Pascal code via `uses pascak_engine`.
  Binary identical 2,940,840 bytes (pre-patch). Full verification:
  LSP 6/6, full suite 30/30 PASS.
- **B.7b Session 2b** — persistent engine singleton fix:
  - `ExecuteEngine()` bug fixed: 2nd+ call AV'd due to arena
    freelist corruption when engine was freed per call.
  - Fix: `GEmbedEngine` singleton + `GEmbedLock` critical section.
  - `ShutdownEngine()` exposed for explicit release (also called
    at `finalization`).
  - Host verification: 5/5 tests PASS (numeric/string/boolean/null/
    multi-call 10×).
  - See `examples/embed_inproc.pas` for canonical template.
  - Binary size 2,944,952 bytes (was 2,940,840 — added ~4KB for
    singleton + finalization code).


- **B.7b Session 3** — `RegisterNative` for host->script callbacks:
  - `TPascakNativeFunc` type: `function(const Args: TNativeValueArray): TNativeValue`
  - `TNativeValue` record (Kind/Num/Str/Bool) — simplified, no cascade
  - Helper constructors: `NVNull`, `NVNum`, `NVStr`, `NVBool`
  - `RegisterNative(name, func)` — stores dict with `__native_simplified`
    marker in GlobalEnv
  - Two dispatch points: `opcCall` + `opcTailCall` (native branch
    before `dtNative`/FFI branches)
  - Host verification: 6/6 tests PASS (add, greet, isPositive, echo,
    script-loop call, non-native regression)
  - CLI regression: A1/A2/A3 all PASS, 30/30 suite
  - See `examples/embed_inproc.pas` Test 6 for full demo

- **Language: `elif` / `elseif`** — alternative spelling for `else if`:
  - Both keywords recognized by lexer, translated to `ttElse` + `ttIf`
  - Zero parser changes — pure syntactic sugar
  - Backward compat: `else if` (two tokens) still works
  - LSP autocomplete keywords expanded (44 total, +2)
  - Test: T5 else-if, T6 elif, T7 elseif, T8 elif chain — all PASS

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
