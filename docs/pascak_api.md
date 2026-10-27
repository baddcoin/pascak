# Pascak API Reference

Dokumentasi lengkap API standard library Pascak VM.

**Versi**: 1.0
**Target**: Termux/Android, Linux, macOS, Windows

---

## Daftar Isi

1. [Modul Global](#modul-global)
2. [Timers] ## Timers
3. [JSON Path] ## JSON Path
4. [FFI (Foreign Function Interface)](#ffi)
5. [Native Buffer](#native-buffer)
6. [Native Struct](#native-struct)
7. [HTTP Client](#http-client)
8. [HTTP Server](#http-server)
9. [Network (Level Rendah)](#network)
10. [TLS](#tls)
11. [SQLite](#sqlite)
12. [Crypto](#crypto)
13. [Filesystem](#filesystem)
14. [Linter](#linter)
15. [GUI (Browser-Based)](#gui-browser-based)
16. [Embedding (In-Process)](#embedding-in-process)
16. [Embedding (Subprocess)](#embedding-subprocess)
17. [Formatter](#formatter)
18. [Test Runner](#test-runner)
19. [Parser Tips](#parser-tips)
20. [Sandbox](#sandbox)
21. [Error Handling](#error-handling)
22. [Platform Notes](#platform-notes)
23. [Language Reference](#language-reference)
---

## Language Reference

Ringkasan sintaks dan operator inti Pascak. Untuk tutorial lengkap, lihat `docs/tutorial.md`.

### Operator Precedence (v1.1.0)

Dari lowest ke highest:

| Level | Operator | Keterangan |
|-------|----------|------------|
| 1 | `??` | null-coalescing |
| 2 | `or` | logical OR |
| 3 | `and` | logical AND |
| 4 | `==` `!=` `<` `>` `<=` `>=` `in` | comparison |
| 5 | `+` `-` | additive |
| 6 | `*` `/` `%` | multiplicative |
| 7 | `unary -` `not` | unary |
| 8 | `?.` `[]` `.` `()` | postfix |

### Optional Chaining `?.`

`a?.b` return `a.b` kalau `a` bukan null, selain itu `null`.

    var x := obj?.name;              // null-safe access
    var y := cfg?.db?.host;          // deep chain (short-circuit)

Tidak support: `obj?.method()` dan `obj?.prop := value`.

### Null-Coalescing `??`

`a ?? b` return `a` kalau `a` bukan `null`, selain itu `b`.

    var port := user_port ?? 8080;
    println(null ?? 42);    // 42
    println(0 ?? 42);       // 0 (0 bukan null)
    println(false ?? 42);   // false

Hanya cek `null`, bukan falsy value.

### Enum

    enum Color { Red, Green, Blue }

Desugar ke `const Color = {Red:0, Green:1, Blue:2}`. Auto-numbered 0..N-1. Top-level dan function scope (v1.2.0).

Akses: `Color.Red` atau `Color["Red"]`.

### Destructuring

    var {name, age} = {"name": "Alice", "age": 30};
    var [x, y]    = [10, 20];
    const {PI}    = {"PI": 3.14159};

Top-level dan statement-scope. Default values (v1.2.0):

    var {a = 10, b = 20} = {"a": 1};
    var [x = 0, y = 100] = [42];

Defaults fire on `null` only (0, "", false pass through).

Array rest (v1.2.1):

    var [first, ...tail] = [10, 20, 30, 40];   // first=10, tail=[20,30,40]

Rest must be last; no default; out-of-bounds -> empty array.

Nested destructuring (obj-root, v1.2.2):

    var {a: {b, c}} = {"a": {"b": 1, "c": 2}};
    var {p: [m, n]} = {"p": [30, 40]};

Supports mixed flat+nested, multi-nested, nested with default.
Restrictions: obj-root only, 1-level, no rest inside nested.
Arbitrary-depth + array-root nested (v1.2.4):

    var {a: {b: {c: {d}}}} = obj;      // unlimited obj depth
    var [x, {u, v}, y] = arr;           // array-root nested
    var [p, [q, r], s] = arr;           // array-in-array
    var [m, {n}, ...rest] = arr;        // nested + rest combined

Recursive ParsePattern helper; flat path ('a.b.c'). Emit iterates
dot-split and chains member/array access.

Object rest (v1.2.5):

    var {a, b, ...rest} = obj;                // rest = obj - {a,b}
    var {cfg: {h}, ...rest} = obj;            // rest excludes top-level 'cfg'
    var {...all} = obj;                       // rest = clone(obj)

Runtime method `dict.omit(keys_array)` also available standalone:

    var filtered := mydict.omit(["secret", "internal"]);

### Syntax Quirks

- `=` = assignment, `==` = comparison
- Type annotation hanya di `var`: `var x = 42` (bukan `var x: int = 42`)
- `for..to`/`downto` untuk numeric, `for..in` untuk iterable
- `div` bukan keyword — pakai `toInteger(a / b)`
- Lambda: `|x| x * 2`
- Ternary: `cond ? a : b`

Untuk tutorial lengkap: `docs/tutorial.md` Bab 1-31.

---

## Modul Global

| Nama | Deskripsi |
|---|---|
| `sys` | Environment, args, subprocess, memory |
| `math` | Matematika & statistik |
| `crypto` | Hash, HMAC, random secure |
| `time` | Date/time manipulation |
| `net` | TCP socket, DNS resolver |
| `http` | HTTP client & server |
| `fs` | Filesystem helpers |
| `dll` | Shared library loading & FFI |
| `tls` | TLS lifecycle management |
| `native` | Native buffer & struct system |
| `hardware` | Raw memory access (peek, poke, alloc) |

**Top-level builtins**:
`print`, `println`, `input`, `len`, `str`, `typeOf`, `toInteger`, `toFloat`, `toString`,
`push`, `pop`, `delete`, `clear`, `reverse`, `join`, `indexOf`, `map`, `filter`, `reduce`, `sort`,
`upper`, `lower`, `trim`, `replace`, `copy`, `pos`, `val`,
`jsonParse`, `jsonStringify`,
`regExMatch`, `regExReplace`, `base64Encode`, `base64Decode`, `sha1`,
`fileRead`, `fileWrite`, `fileAppend`, `fileExists`, `fileDelete`,
`fileWriteRecord`, `fileReadRecord`,
`getFiles`, `getDirs`, `makeDir`,
`thread`, `poolRun`, `coroutine_create`, `resume`, `coroutine_free`,
`on`, `emit`, `Worker`, `workerPost`, `workerGet`,
`range`, `eval`,
`assertEqual`, `assertTrue`, `assertFalse`, `assertThrows`,
`testBegin`, `testEnd`, `testSummary`,
`runtimeStats`, `profilerEnable`, `profilerDisable`, `profilerReport`

---
## Config

Config management — dotenv, JSON, env override, runtime set dengan precedence chain.

### `config.load(".env")`

Load dotenv file. Support:
- `KEY=value`
- `KEY="quoted value"` — quote di-strip
- `# comment` — di-skip
- `export KEY=value` — `export ` di-strip

```pascal
config.load(".env");
config.load("config.env");
```

### `config.loadJSON("config.json")`

Load JSON object — key-value di-flatten ke string.

```pascal
config.loadJSON("config.json");
```

**Nested JSON** di-store sebagai JSON string. Untuk parse nested, pakai `jsonPath`:

```pascal
config.loadJSON("config.json");
var dbHost := jsonPath(jsonParse(config.get("db")), "host");
```

### `config.get("KEY", [default]) → string | null`

Lookup dengan precedence:

1. **Runtime** (`config.set`)
2. **File** (dari `config.load` / `loadJSON`)
3. **Environment** (`sys.env`)
4. **Default** (arg ke-2)

```pascal
var port := config.get("PORT", "8080");        // string
var dbUrl := config.get("DATABASE_URL");       // null kalau tidak ada
```

Selalu return **string** — parsing manual untuk number/bool:

```pascal
var port := toInteger(config.get("PORT", "8080"));
var debug := config.get("DEBUG", "false") == "true";
```

### `config.set("KEY", value)`

Runtime override (prioritas tertinggi).

```pascal
config.set("PORT", "3000");
config.set("DEBUG", "true");
```

### `config.has("KEY") → bool`

Cek keberadaan di runtime + env.

```pascal
if config.has("DATABASE_URL") then
  connectDb(config.get("DATABASE_URL"));
```

### `config.all() → dict`

Snapshot semua key yang ada di runtime store.

```pascal
var all := config.all();
for k in all.keys() do
  log.debug("config: ", k, "=", all[k]);
```

### Pattern: Config + Log + Shutdown

```pascal
begin
  // 1. Load config
  config.load(".env");
  config.loadJSON("config.json");

  // 2. Setup log
  log.setLevel(config.get("LOG_LEVEL", "info"));
  log.setFormat(config.get("LOG_FORMAT", "plain"));

  log.info("app starting");

  // 3. Register cleanup
  var DB := sqliteConnect(config.get("DB_PATH", "app.db"));
  onShutdown(lambda : begin
    log.info("closing database...");
    sqliteClose(DB);
  end);

  // 4. Register signal
  signal.on("SIGTERM", lambda : begin
    log.info("received SIGTERM, shutting down");
    sys.exit(0);
  end);

  // ... main logic ...
end.
```
## Linter

Static analysis untuk script Pascak — detect unused variables, unreachable code, dll.

### Cara Pakai

```bash
# Report issues (warning = OK, exit 0)
pascak --lint script.pas
pascak --lint src/

# Strict mode — warning jadi error (exit 1)
pascak --lint --strict script.pas
pascak --lint --strict src/
```

### Output

```
═══ Pascak Linter ═══
Mode: lint

/path/to/script.pas
  W001:2:7 warning unused variable 'temp'
  W002:9:3 warning unreachable code after terminator

═══ Summary ═══
  Files checked   : 1
  Files w/issues  : 1
  Warnings        : 2
  Errors          : 0

RESULT: warnings present (no errors)
```

### Checks (v1)

| Code | Level | Deskripsi |
|---|---|---|
| **W001** | Warning | Unused variable (per scope) |
| **W002** | Warning | Unreachable code after `return`/`throw`/`break`/`continue` |
| **E001** | Error | Duplicate declaration in same scope |
| **E002** | Error | Const reassignment (detected at compile-time, akan muncul sebagai runtime error) |

### Output Format

Setiap issue:
```
<code>:<line>:<col> <level> <message>
```

Contoh:
```
W001:12:7 warning unused variable 'config'
W002:20:3 warning unreachable code after terminator
E001:8:3 error   duplicate declaration of 'x' (first at line 5)
```

### Exit Code

| Code | Mode | Arti |
|---|---|---|
| `0` | `--lint` | Clean atau hanya warning |
| `0` | `--lint --strict` | Clean |
| `1` | `--lint` | Ada error (E001) |
| `1` | `--lint --strict` | Ada error ATAU warning |
| `2` | — | Error (file tidak ada, tidak bisa parse) |

### Scope Tracking

Linter track variables di setiap scope:

| Scope type | Contoh |
|---|---|
| Top-level | `var x := 1;` di script body |
| Function body | Parameter + lokal di function |
| Class body | Fields + `self` |
| Loop body | `for i` + `for x in arr` |
| Catch body | `catch e` |
| List comprehension | `[x * 2 for x in arr]` |

**Unused variable check** dijalankan saat scope pop, kecuali:
- Parameter fungsi → tidak di-warn (bisa di-ignore di caller)
- Konstanta → tidak di-warn

### Contoh

**Input**:
```pascal
begin
  var unused := 42;
  var used := 10;
  println(used);

  if true then begin
    var inner_unused := "hi";
  end;

  return;
  println("never reached");
end.
```

**Output**:
```
W001:2:7 warning unused variable 'unused'
W001:7:9 warning unused variable 'inner_unused'
W002:9:3 warning unreachable code after terminator
```

### CI Integration

```bash
#!/bin/bash
# .github/workflows/ci.yml
pascak --lint --strict src/ || {
  echo "Linter found issues"
  exit 1
}
```

### Pre-commit Hook

Buat file `.git/hooks/pre-commit`:

```bash
#!/bin/bash
for f in $(git diff --cached --name-only | grep '\.pas$'); do
  pasCak --lint --strict "$f" || exit 1
done
```

(chmod +x file tersebut)

### Limitations (v1)

- **No cross-function analysis** — unused function tidak di-warn
- **No type checking** — hanya cek struktur
- **No dead store elimination** — `x := 1; x := 2;` tidak di-warn
- **No shadowing warnings** — local var shadow global OK tanpa warning
- **Order tidak always ascending** — scope pop terakhir bikin hasil keluar urutan

### Kombinasi dengan Formatter

**CI pipeline standard**:
```bash
#!/bin/bash
set -e

echo "1. Format check..."
pascak --fmt --check src/ || {
  echo "  FAILED. Run: pascak --fmt src/"
  exit 1
}

echo "2. Lint check..."
pascak --lint --strict src/ || {
  echo "  FAILED"
  exit 1
}

echo "3. Test..."
PASCAK_EXEC_POLICY=allow-all pascak --test || exit 1

echo "All checks passed"
```

---
## GUI (Browser-Based)

Browser-based GUI via local HTTP server + WebSocket RPC bridge.
No native window, no external dependencies — works on any device
with a browser.

### Quick Start

    begin
      sys.execWhitelist(["termux-open-url", "xdg-open"]);
      var h := gui.create(8080, 8081, "My App");
      gui.bind(h, "add", lambda args : args[0] + args[1]);
      gui.serve(h, "<html><button onclick='go()'>Add</button>
        <script>
        async function go(){
          var v = await window.pascak.call('add', [3, 4]);
          alert(v);
        }
        </script></html>");
      gui.start(h);
      gui.open(h);
      gui.run(h);
    end.

### API

#### `gui.create(port, [wsPort], [title]) → handle`

Create GUI app instance. `wsPort` default = `port + 1`. Returns handle ≥ 1,
or `-1` on error.

#### `gui.createTLS(port, certPath, keyPath, [wsPort], [title]) → handle`

Create GUI app dengan **HTTPS + WSS** (self-signed cert). Browser spawn ke
`https://localhost:{port}/`, auto-injected JS pakai `wss://localhost:{wsPort}/`.

**Parameter:**
- `certPath`, `keyPath` — PEM cert + key. Absolute path di `$HOME` diizinkan, atau sandbox-relative
- `wsPort` — default `port + 1`
- `title` — default `"Pascak GUI (TLS)"`

**Cert generation:**

    openssl req -x509 -newkey rsa:2048 \
      -keyout ~/server.key -out ~/server.crt \
      -days 365 -nodes -subj "/CN=localhost" \
      -addext "subjectAltName=DNS:localhost,IP:127.0.0.1"

**Behavior:**
- HTTP listener → TLS-wrapped (TLSContext shared dengan WS, refcounted)
- WS listener → WSS (wajib — browser block `ws://` dari HTTPS)
- Compression auto-enabled untuk WSS (payload encrypted, aman dari CRIME/BREACH)
- Self-signed cert → browser warning sekali per host, click Advanced > Proceed

**Kapan pakai:**
- Browser modern **wajib** HTTPS untuk `getUserMedia`, `serviceWorker`, `clipboard`
- Demo `wss://` production-like
- LAN access dari device lain (custom CA / self-signed trust)

**Return:** handle ≥ 1, atau `-1` on error.

**Limitations:**
- Localhost only (`127.0.0.1` bind, tidak bisa diakses network)
- Self-signed → warning sekali per browser
- Cert expired → handshake fail

#### `gui.serve(handle, html) → bool`

Set HTML content. The engine **auto-injects** a `<script>` block before
`</body>` that provides `window.pascak.call(method, argsArray)` returning
a `Promise`.

#### `gui.bind(handle, name, callback) → bool`

Register a server-side function callable from JS. `callback` receives
positional args from `window.pascak.call(name, [...])`.

#### `gui.start(handle) → bool`

Bind HTTP port + WS port. Non-blocking — HTTP accept loop driven by
engine's event loop timer (20ms poll), WS uses event-driven
`Native_WS_ListenAsync`.

#### `gui.open(handle) → bool`

Spawn browser via `termux-open-url` / `xdg-open`. Requires exec
whitelist:

    sys.execWhitelist(["termux-open-url", "xdg-open", "open"]);

Returns `false` if spawn failed (open URL manually).

#### `gui.run(handle)`

Blocking event loop — run until `gui.close` or `sys.exit`. Use
`setTimeout` + `gui.close` for graceful shutdown.

#### `gui.close(handle) → bool`

Stop HTTP + WS listeners, cancel poll timer, free app state.
Cleans up process cleanly (no hang from leftover timers).

### Example

See `examples/hello_gui.pas` — full counter demo with server-side
state, HTML buttons, JS↔Pascal RPC.

### Limitations (v1)

| Feature | Status |
|---------|--------|
| HTTP + WS RPC | yes |
| Auto JS injection | yes |
| Browser spawn | yes (with exec whitelist) |
| HTTPS | no (localhost only) |
| Multi-window | no (one GUI per process) |
| Native window | no (browser only) |

---

## Embedding (In-Process)

**Library-level** embedding: host Pascal code `uses pascak_engine` to
invoke the VM directly (not via subprocess). ~microseconds per call.

### Quick Start

    program my_host;

    {$MODE OBJFPC}{$H+}

    uses
      {$IFDEF UNIX}
        cthreads,       { MANDATORY on Unix — must be first }
      {$ENDIF}
      SysUtils, pascak_engine;

    var
      R: TPascakResult;
    begin
      R := ExecuteEngine('begin return 6 * 7; end.');
      if R.Success then
        WriteLn('Result: ', R.ValueAsString);   { 42 }
    end.

**Build**: `fpc -Mobjfpc -Sh -Fu. my_host.pas`

### `TPascakResult`

| Field | Type | Description |
|-------|------|-------------|
| `Success` | Boolean | `False` if runtime error, `True` otherwise |
| `ValueType` | string | `numeric` / `string` / `boolean` / `null` / `other` |
| `ValueAsString` | string | String representation |
| `ValueAsNum` | Double | Numeric value (iff `ValueType=numeric`) |
| `ValueAsBool` | Boolean | Boolean value (iff `ValueType=boolean`) |
| `Error` | string | `EClassName: message` on failure |

### `ExecuteEngine(source: string): TPascakResult`

Execute script source, return result. **Thread-safe** (serialized via
internal CriticalSection). **Singleton** engine — one engine instance
shared across calls for arena stability.

### `ShutdownEngine`

Release the singleton engine. Auto-called at program exit
(`finalization` block). Explicit call optional.

### `RegisterNative(name, func)`

Register a Pascal function callable from script. Handled at two
dispatch points (`opcCall` + `opcTailCall`) that route `dtDict` with
`__native_simplified` marker to host callback.

**Types**:

| Type | Purpose |
|------|---------|
| `TNativeValueKind` | `(nvkNull, nvkNumber, nvkString, nvkBoolean)` |
| `TNativeValue` | record `{Kind, Num, Str, Bool}` |
| `TNativeValueArray` | `array of TNativeValue` |
| `TPascakNativeFunc` | `function(const Args: TNativeValueArray): TNativeValue` |

**Helper constructors**:

- `NVNull` — null value
- `NVNum(V: Double)` — numeric
- `NVStr(S: string)` — string
- `NVBool(B: Boolean)` — boolean

**Example**:

    function MyAdd(const Args: TNativeValueArray): TNativeValue;
    begin
      if Length(Args) < 2 then Exit(NVNull);
      Result := NVNum(Args[0].Num + Args[1].Num);
    end;

    RegisterNative('add', @MyAdd);

    R := ExecuteEngine('begin return add(10, 20); end.');
    { R.ValueAsNum = 30 }

Full demo: `examples/embed_inproc.pas` (6 tests including native).

### Comparison: In-Process vs Subprocess

| Aspect | In-Process | Subprocess |
|--------|-----------|------------|
| Overhead/call | microseconds | ~2 seconds |
| State isolation | shared engine | full (new process) |
| Native callback | yes | no |
| Requires binary | no (linked in) | yes |
| Failure isolation | none (host crash risk) | safe |
| Use case | trusted scripting | untrusted plugins |

### Requirements

- **`cthreads` MUST be first unit on Unix.** Without it, FPC's
  `SysUtils` initialization may use thread primitives before
  `cthreads` initializes → runtime error 211.
- **`pascak_engine.ppu`** must exist (build `pascak_engine.pas` first).
- **All `pascak_*.pas` units** must be reachable via `-Fu` path.

### Limitations (v1)

| Feature | Status |
|---------|--------|
| Singleton engine | yes |
| Thread-safe (mutex) | yes |
| Native callback | yes |
| Structured error object | no (string only) |
| Multi-engine instance | no (singleton) |
| Stdout capture from script | no |

---

## Embedding (Subprocess)

Public API untuk embed Pascak VM di aplikasi Pascal host (Lazarus, Delphi, FPC).

**Unit**: `pascak_embed.pas` — subprocess-based wrapper.

### Quick Start

```pascal
program my_host;

{$MODE OBJFPC}{$H+}

uses SysUtils, pascak_embed;

var
  Engine: TPascakEmbed;
  R: TPascakResult;
begin
  Engine := TPascakEmbed.Create('/path/to/pascak_noASTnet');
  try
    Engine.SetDevMode(True);
    Engine.SetExecPolicy('allow-all');
    
    R := Engine.ExecuteString('begin println("Hello from host!"); end.');
    
    if R.ExitCode = 0 then
      Writeln('Output: ', Trim(R.Stdout))
    else
      Writeln('Error: ', R.Stderr);
  finally
    Engine.Free;
  end;
end.
```

**Compile**:
```bash
fpc -Mobjfpc -Sh -Fu/path/to/pascak my_host.pas
```

---

### `TPascakEmbed.Create(binaryPath) → TPascakEmbed`

Constructor. Validasi binary exists — raise `EPascakEmbedError` kalau tidak.

```pascal
var E := TPascakEmbed.Create(ExpandFileName('~/pascak_noASTnet'));
```

**Default config**:
- ExecPolicy: `"none"` (deny-all)
- MemoryQuota: 256 MB
- Timeout: 60000 ms (60 detik)
- DevMode: `false`
- TempDir: `$TMPDIR` → `$HOME` → cwd

---

### `ExecuteString(source) → TPascakResult`

Execute script dari source string. Ditulis ke file temp, dijalankan, hasil di-capture.

```pascal
R := E.ExecuteString(
  'begin'#10 +
  '  var name := "World";'#10 +
  '  println("Hello, ", name);'#10 +
  'end.');
```

**Return `TPascakResult`**:
| Field | Tipe | Deskripsi |
|---|---|---|
| `ExitCode` | Integer | 0 = success, 1 = script error, 2 = config error |
| `Stdout` | string | Output dari script (`println`, dll) |
| `Stderr` | string | Output error |
| `DurationMs` | QWord | Wall-clock time |
| `TimedOut` | Boolean | True kalau timeout di-kill |

---

### `ExecuteFile(path) → TPascakResult`

Execute script dari file. Sama seperti `ExecuteString` tapi tidak buat file temp.

```pascal
R := E.ExecuteFile('/path/to/script.pas');
```

---

### Configuration Methods

Semua config method **tidak langsung apply** — di-apply pada `Execute*` berikutnya.

#### `SetEnv(key, value)`

Set env var untuk child process.

```pascal
E.SetEnv('DATABASE_URL', 'postgres://localhost/mydb');
E.SetEnv('API_KEY', 'secret');
E.SetEnv('MY_VAR', 'hello');
```

**Default passthrough** (inherit dari parent otomatis): `PATH`, `HOME`, `TMPDIR`, `LANG`, `LC_ALL`, `PREFIX`, `TERM`, `USER`.

**Catatan**: setelah `SetEnv` dipanggil minimal 1×, custom env **menggantikan** default. Kalau butuh var lain dari parent, set manual.

#### `ClearEnv`

Hapus semua custom env var. Kembali ke inherit-all dari parent.

```pascal
E.ClearEnv;
```

#### `SetExecPolicy(policy)`

Control child process exec policy.

```pascal
E.SetExecPolicy('none');             // deny all (default)
E.SetExecPolicy('allow-all');        // development
E.SetExecPolicy('whitelist:git,ls'); // specific binaries
```

Setara dengan `PASCAK_EXEC_POLICY` env + `--dev` flag.

#### `SetMemoryQuota(mb)`

Set memory quota untuk child dalam MB.

```pascal
E.SetMemoryQuota(64);    // 64 MB
E.SetMemoryQuota(1024);  // 1 GB
```

#### `SetTimeout(ms)`

Timeout per `Execute*`. 0 = unlimited.

```pascal
E.SetTimeout(30000);   // 30s
E.SetTimeout(0);       // no limit
```

Child di-kill via SIGTERM kalau melebihi timeout.

#### `SetDevMode(enabled)`

Enable `--dev` flag ke child. Wajib untuk:
- `sys.exec` (exec policy dari env)
- `sys.env` untuk baca env var
- TLS override via env

```pascal
E.SetDevMode(True);
```

#### `SetTempDir(dir)`

Override folder untuk temp file (default: `$TMPDIR`).

```pascal
E.SetTempDir('/data/data/com.termux/files/home/tmp');
```

---

### Diagnostics

#### `BinaryExists → Boolean`

Cek binary engine ada.

#### `BinaryVersion → string`

Spawn engine untuk dapat versi. Return `"Pascak VM"` atau empty string.

```pascal
Writeln('Engine: ', E.BinaryVersion);
```

---

### Error Handling

Semua error structural di-raise sebagai `EPascakEmbedError`:
- Binary path kosong
- Binary tidak ditemukan
- Script file tidak ditemukan (untuk `ExecuteFile`)

**Script runtime errors** tidak raise — masuk ke `R.ExitCode` + `R.Stderr`.

```pascal
try
  E := TPascakEmbed.Create('/nonexistent/binary');
except
  on E: EPascakEmbedError do
    Writeln('Config error: ', E.Message);
end;

// Runtime error — tidak raise
R := E.ExecuteString('begin undefined(); end.');
if R.ExitCode <> 0 then
  Writeln('Script error: ', R.Stderr);
```

---

### Use Cases

#### Plugin System

```pascal
// Host app: load plugin dari folder
function RunPlugin(const Path: string): Boolean;
var
  E: TPascakEmbed;
  R: TPascakResult;
begin
  E := TPascakEmbed.Create(GetEnginePath);
  try
    E.SetDevMode(True);
    E.SetExecPolicy('allow-all');
    E.SetEnv('PLUGIN_DIR', ExtractFilePath(Path));
    
    R := E.ExecuteFile(Path);
    Result := R.ExitCode = 0;
    
    if not Result then
      Writeln('Plugin failed: ', R.Stderr);
  finally
    E.Free;
  end;
end;
```

#### Rule Engine

```pascal
function EvaluateRule(const RuleSource, JsonData: string): string;
var
  E: TPascakEmbed;
  Script: string;
  R: TPascakResult;
begin
  E := TPascakEmbed.Create(GetEnginePath);
  try
    E.SetDevMode(True);
    E.SetEnv('RULE_INPUT', JsonData);
    
    Script :=
      'begin'#10 +
      '  var data := jsonParse(sys.env("RULE_INPUT"));'#10 +
      RuleSource + #10 +
      'end.';
    
    R := E.ExecuteString(Script);
    Result := Trim(R.Stdout);
  finally
    E.Free;
  end;
end;
```

#### Scripting Layer untuk Game / Tools

```pascal
// Game host: load level logic dari script
procedure LoadLevel(const LevelName: string);
var
  E: TPascakEmbed;
  R: TPascakResult;
begin
  E := TPascakEmbed.Create('engine');
  try
    E.SetDevMode(True);
    E.SetExecPolicy('whitelist:ffmpeg,convert');
    E.SetEnv('LEVEL', LevelName);
    
    R := E.ExecuteFile('levels/' + LevelName + '.pas');
    if R.ExitCode <> 0 then
      raise Exception.Create('Level load failed: ' + R.Stderr);
  finally
    E.Free;
  end;
end;
```

---

### Performance

| Metrik | Nilai |
|---|---|
| **Startup overhead** | ~2 detik per `Execute*` (spawn process, parse, compile) |
| **Throughput** | ~0.5 script/detik untuk short script |
| **Memory** | Isolated — parent tidak terpengaruh |

**Optimization**:
- Untuk batch, gabung jadi 1 script
- Untuk interaktif, gunakan `--repl` mode via `TProcess` langsung
- In-process embed (done — see `## Embedding (In-Process)` above)

---

### Limitations (v1)

| Feature | Status |
|---|---|
| Subprocess isolation | ✅ |
| Config env / exec policy / memory / timeout | ✅ |
| Stdout / stderr capture | ✅ |
| Exit code normalized | ✅ |
Native callback dari host | ✅ (B.7b Session 3)
Shared memory / FFI bidirectional | ❌ (backlog)
| Streaming stdout (live) | ❌ |
| Windows signal handling | ⚠️ (Partial) |

---

## Formatter

Auto-formatter untuk script Pascak — standardisasi style, whitespace, indent.

### Cara Pakai

```bash
# Format in-place (ubah file)
pascak --fmt script.pas
pascak --fmt src/                      # semua *.pas di folder

# Dry-run (CI mode) — exit 1 kalau perlu reformat
pascak --fmt --check script.pas
pascak --fmt --check src/
```

### Output

```
═══ Pascak Formatter ═══
Mode: format (in-place)

  FORMAT /path/to/script.pas
  OK     /path/to/another.pas

═══ Summary ═══
  Checked  : 2
  Changed  : 1
  Errors   : 0
```

### Exit Code

| Code | Arti |
|---|---|
| `0` | Semua OK, atau format sukses |
| `1` | `--check` mode + ada file perlu reformat |
| `2` | Error (file tidak ada, format crash) |

### Rules

**Indent**:
- 2 spasi per level
- Block opener: `begin`, `try`, `repeat`, `record`, `case..of`, `{` (dict literal)
- Block closer: `end`, `until`, `}`
- Middle keywords (`else`, `except`, `finally`): dedent untuk baris sendiri

**Whitespace**:
- Trim trailing whitespace di setiap baris
- Collapse multiple blank lines → 1
- Tambah trailing newline di EOF

**Continuation**:
- Baris yang tidak diakhiri terminator (`;`, `end`, `begin`, `{`) → indent +1
- **Kecuali** di dalam dict literal — sudah di-indent otomatis

### Contoh

**Before**:
```pascal
begin
var x := 10;


   if x > 5 then begin
println("big");
   end else begin
       println("small");
   end;
end.
```

**After**:
```pascal
begin
  var x := 10;

  if x > 5 then begin
    println("big");
  end else begin
    println("small");
  end;
end.
```

### Dict Literal

```pascal
// Input
begin
var d := {
"a": 1,
"b": {"nested": true},
"c": [1,2,3]
};
println(d);
end.

// Output
begin
  var d := {
    "a": 1,
    "b": {"nested": true},
    "c": [1,2,3]
  };
  println(d);
end.
```

### CI Integration

```bash
#!/bin/bash
# .github/workflows/ci.yml (contoh)
pascak --fmt --check src/ || {
  echo "Code tidak ter-format. Jalankan: pascak --fmt src/"
  exit 1
}
```

### Limitations (v1)

- **No operator spacing normalization** — `a+b` tetap `a+b`
- **No comment reflow** — comment tidak di-reindent
- **Continuation line loses alignment** — multi-line expression di-indent +1, bukan align ke `(`
- **No string content formatting** — string literal tidak diubah

---

## Test Runner

CLI mode untuk auto-discover dan menjalankan test suite.

### Cara Pakai

```bash
# Discover + run semua test di test/
pascak --test

# Run satu file spesifik
pascak --test test/test_json.pas

# Discover di folder tertentu
pascak --test path/to/tests/
```

**Catatan**: butuh `PASCAK_EXEC_POLICY=allow-all` di env (atau `--dev` flag) supaya subprocess spawn diizinkan:

```bash
PASCAK_EXEC_POLICY=allow-all ~/pascak_noASTnet --test
```

### Discovery

**Primary**: baca whitelist dari `test/test_all.pas`.

File `test_all.pas` yang sudah ada mendaftar test resmi dengan dua fungsi:

```pascal
// Hard test — fail berarti exit 1
runScriptTest("test_json.pas");

// Soft test — fail karena network di-skip, bukan fail
runScriptTestEx("test_tls_cache.pas", true);
```

Runner parse file ini dan skip file yang bukan bagian dari official suite.

**Fallback**: kalau `test_all.pas` tidak ada, flat scan `test/*.pas`.

### Output

```
═══ Pascak Test Runner ═══
Engine : /path/to/pascak_noASTnet

Ditemukan 29 file test

[1/29] test_json.pas ... PASS (1963ms)
[2/29] test_crypto.pas ... PASS (1972ms)
...
[12/29] test_phase_t2a_2.pas ... SOFT-SKIP (network)
...
[29/29] test_ws_tls_nbs.pas ... PASS (3606ms)

═══ Summary ═══
  Passed  : 27
  Failed  : 0
  Skipped : 2

RESULT: PASS
```

### Exit Code

| Code | Arti |
|---|---|
| `0` | Semua test PASS (atau soft-skip) |
| `1` | Ada minimal 1 test FAIL |
| `2` | Tidak ada file test ditemukan, atau error target |

Cocok untuk CI:

```bash
PASCAK_EXEC_POLICY=allow-all ~/pascak_noASTnet --test || exit 1
```

### Behaviour Detail

**Isolasi**: setiap test dijalankan di **subprocess terpisah**. Isolated state, tidak ada leakage antar test.

**Timeout**: 60 detik per test. Test yang hang akan di-kill.

**Env propagation**: runner set `PASCAK_EXEC_POLICY=allow-all` untuk child supaya test bisa spawn subprocess sendiri (mis. Python WS client).

**Skip rule**:
- File FPC-unit style (dimulai `{` atau `unit X;`) → skip
- Subfolder `.git`, `.pascak_tmp`, `testError`, `builLibTest` → skip
- File `test_all.pas` sendiri → skip (ini manifest)

**Diagnostic**: kalau fail, runner cetak 2KB terakhir dari output test.

### Menulis Test yang Compatible

Test harus berupa **script Pascak valid**:

```pascal
// test_myfeature.pas — Ok
begin
  testBegin("My Feature");

  assertEqual(2, 1 + 1, "basic math");
  assertTrue(true, "always pass");

  testEnd();
  sys.exit(testSummary());
end.
```

**Bukan**:

```pascal
// test_myfeature.pas — Runner akan skip (FPC unit style)
{ ====================================
  FPC Test Unit — not runnable by --test
  ==================================== }
unit TestMyFeature;
interface
...
```

**Test template**:

```pascal
begin
  testBegin("<category — name>");

  // ... assertions ...

  testEnd();
  sys.exit(testSummary());
end.
```

`testSummary()` return jumlah failed. `sys.exit(N)` propagate ke runner.

### Register ke Official Suite

Untuk menambahkan test ke suite resmi, edit `test/test_all.pas`:

```pascal
// Hard test (harus pass)
runScriptTest("test_myfeature.pas");

// Soft test (network dependent)
runScriptTestEx("test_myfeature_network.pas", true);
```

Runner akan otomatis menemukan test di run berikutnya.

### Known Limitations

- **Sequential**: test jalan satu per satu. Untuk suite besar (>50 test), bisa jadi lambat.
- **Network soft-skip**: test yang fail karena network di-mark skip, tapi tidak ada retry.
- **Parallel mode**: belum ada (backlog).

**Cocok untuk**: pre-commit check, CI step, before-release validation.

---

## Metrics

Prometheus-compatible metrics module — counter, gauge, histogram.

### `metrics.define(name, type, [help])`

Register metric.

```pascal
metrics.define("http_requests_total", "counter", "Total HTTP requests");
metrics.define("queue_size", "gauge", "Current queue size");
metrics.define("request_duration_ms", "histogram", "Request latency");
```

**Types**: `counter` (monotonic), `gauge` (arbitrary), `histogram` (buckets).

### `metrics.increment(name, [labels])` / `metrics.add(name, value, [labels])`

Counter operations.

```pascal
metrics.increment("http_requests_total");
metrics.increment("http_requests_total", {"method": "GET", "path": "/api"});
metrics.add("bytes_sent_total", 1024, {"host": "example.com"});
```

### `metrics.set(name, value, [labels])`

Gauge set.

```pascal
metrics.set("queue_size", 42);
metrics.set("memory_mb", 128.5, {"pool": "worker"});
```

### `metrics.observe(name, value, [labels])`

Histogram observe — auto-update buckets + sum + count.

```pascal
metrics.observe("request_duration_ms", 42.5);
metrics.observe("request_duration_ms", 15.2, {"endpoint": "/users"});
```

**Buckets**: `[1, 5, 10, 25, 50, 100, 250, 500, 1000, 2500, 5000]`.

### `metrics.expose() → string`

Prometheus text format.

```pascal
http.serve(9090, lambda req : begin
  if req["path"] == "/metrics" then
    return {"status": 200, "body": metrics.expose()};
  return {"status": 404};
end);
```

**Output**:
```
# HELP http_requests_total Total HTTP requests
# TYPE http_requests_total counter
http_requests_total{method="GET",path="/api"} 1234

# HELP request_duration_ms Request latency
# TYPE request_duration_ms histogram
request_duration_ms_bucket{le="10"} 100
request_duration_ms_bucket{le="50"} 500
request_duration_ms_bucket{le="+Inf"} 1234
request_duration_ms_sum 56789
request_duration_ms_count 1234
```

### `metrics.reset() / metrics.list()`

Reset values (definitions tetap) / list nama metric.

---

## Health

Health check module — untuk Kubernetes/Docker readiness probes.

### `health.register(name, fn)`

Register check function. Return:
- **bool** → `true` = ok, `false` = fail
- **dict** → `{"ok": bool, ...extra}` — extra fields dipass-through
- **other** → treated as ok, wrapped in `{ok: true, info: value}`
- **exception** → caught, marked failed

```pascal
health.register("db", lambda : sqliteQuery(DB, "SELECT 1") != null);
health.register("cache", lambda : {"ok": redis.ping(), "version": "1.0"});
health.register("external_api", lambda : http.get("https://api.example.com/health").status == 200);
```

### `health.check() → dict`

Run all checks, return aggregated status.

```pascal
var s := health.check();
println(s["status"]);       // "ok" | "degraded" | "down"
println(s["checks"]["db"]); // {ok: true, ms: 2}
```

**Status logic**:
- Semua ok → `"ok"`
- Sebagian fail → `"degraded"`
- Semua fail → `"down"`
- Tidak ada check → `"ok"`

### `health.list() / health.unregister(name)`

List nama check / hapus check.

### Contoh — HTTP Health Endpoint

```pascal
health.register("db", lambda : sqliteQuery(DB, "SELECT 1") != null);

var srv := http.serve(8081, lambda req : begin
  if req["path"] == "/health" then begin
    var s := health.check();
    var code := s["status"] == "ok" ? 200 : 503;
    return {"status": code, "headers": {"Content-Type": "application/json"},
            "body": jsonStringify(s)};
  end
  if req["path"] == "/ready" then begin
    var s := health.check();
    return {"status": s["status"] == "ok" ? 200 : 503};
  end
  return {"status": 404};
end);
```

---

## Request Logging

Auto-log HTTP requests — method, path, status, latency, size.

### `http.logRequests(config)`

Enable auto-logging. Hook di `Worker_HandleClient`.

```pascal
http.logRequests({
  "enabled": true,
  "slowMs": 1000,                      // warn threshold
  "excludePaths": ["/health", "/metrics"]  // skip log untuk path ini
});

http.logRequests();   // disable
```

**Output**:
```
2026-10-13 20:29:36 [INFO] GET /api/users 200 12ms 45b
2026-10-13 20:29:36 [WARN] GET /slow 200 1234ms 89b (SLOW)
```

**Integrasi** dengan A.8 request ID:
```
2026-10-13 20:29:36 [INFO] [req-abc12345-000001] GET /api/users 200 12ms 45b
```

---

## Request ID Tracking

Distributed tracing — propagate/generate unique request ID.

### `http.traceRequests(config)`

```pascal
http.traceRequests({
  "enabled": true,
  "header": "X-Request-ID",   // default
  "responseHeader": true,     // echo back
  "prefix": "req-"            // auto-gen prefix
});

http.traceRequests();   // disable
```

**Behavior**:
1. Extract ID dari incoming header `X-Request-ID`
2. Kalau tidak ada → generate `req-XXXX-YYYYYY` (4 random bytes hex + counter)
3. Inject ke req dict: `req["requestId"]`
4. Echo balik di response header (kalau `responseHeader`)
5. Auto-tag di log A.6

### Contoh — Distributed Tracing

```pascal
http.traceRequests({"prefix": "order-"});

function handler(req) begin
  var rid := req["requestId"];
  log.info("processing order, rid=", rid);

  // Propagate ke downstream service
  var downstream := http.post("https://payment.example.com/charge", {
    "X-Request-ID": rid
  }, jsonStringify(data));

  return {"status": 200, "body": "OK"};
end;
```

**Gunakan**:
- **Log correlation** — `grep "req-abc123"` untuk trace satu request
- **Debug user issue** — ask user untuk request ID dari error message
- **Distributed tracing** — propagate ID via HTTP header antar service
- **Sampling** — log semua request ID, sample 10% untuk full trace

---

---

## Logging

Structured logging module — plain atau JSON output, level filter, multiple sink.

### `log.debug(msg, ...) / log.info(msg, ...) / log.warn(msg, ...) / log.error(msg, ...)`

Log pesan dengan level tertentu. Multi-arg di-concat (seperti `println`).

```pascal
log.debug("debug detail: x=", x);
log.info("user login: ", userId);
log.warn("retry attempt ", n, " of 3");
log.error("db connection failed: ", err);
```

**Level** (dari rendah ke tinggi): `debug` (0) → `info` (1) → `warn` (2) → `error` (3).

Default level = `info` — pesan `debug` di-skip sampai `setLevel("debug")`.

**Format output**:
```
2026-10-13 07:06:20 [INFO] user login: 42
2026-10-13 07:06:20 [ERROR] db connection failed: timeout
```

### `log.setLevel(level)`

Filter pesan di bawah level ini.

```pascal
log.setLevel("debug");   // semua muncul
log.setLevel("error");   // hanya error
```

**Level**: `"debug"`, `"info"`, `"warn"`, `"error"`.

### `log.setFormat(format)`

Ubah format output.

```pascal
log.setFormat("plain");   // default: '2026-10-13 07:06:20 [INFO] message'
log.setFormat("json");    // '{"ts":"...","level":"info","msg":"message"}'
```

JSON escape otomatis untuk `"`, `\`, newline, tab.

### `log.setOutput(sink, [path])`

Ubah tujuan output.

```pascal
log.setOutput("stdout");                    // default
log.setOutput("stderr");
log.setOutput("file", "./app.log");         // append mode
```

**Path** file: sandbox-relative. File di-append (tidak truncate). Fail-silent kalau write error.

### Best Practices

```pascal
// ✅ Development
log.setLevel("debug");
log.setFormat("plain");

// ✅ Production
log.setLevel("info");
log.setFormat("json");              // JSON untuk log aggregator
log.setOutput("file", "./app.log"); // persist

// ✅ Error trace
try
  riskyOperation();
catch e do
  log.error("operation failed: ", e.message);
end;
```

**Thread-safe**: internal lock, aman dipanggil dari callback worker.


---
## Signal

Signal handling — graceful shutdown dari `kill`, Docker stop, Ctrl+C.

### `signal.on(signalName, fn)`

Register callback yang fire saat signal diterima.

```pascal
signal.on("SIGTERM", lambda : begin
  log.info("graceful shutdown");
  cleanup();
  sys.exit(0);
end);

signal.on("SIGINT", handler);   // Ctrl+C
```

**Supported**: `"SIGINT"`, `"SIGTERM"`.

**Behavior**:
- Handler fire di **main thread** via event loop (safe TValue access)
- Multiple handler per signal fire **berurutan** (urutan registrasi)
- **No handler** → exit code POSIX standard:
  - `SIGINT` → 130
  - `SIGTERM` → 143

### `signal.off(signalName)`

Hapus **semua** handler untuk signal.

```pascal
signal.off("SIGTERM");
```

### `signal.raise(signalName)`

Raise signal ke diri sendiri — untuk test.

```pascal
signal.raise("SIGTERM");   // trigger handler SIGTERM
```

**Catatan**: ini mengirim signal asli via `kill(getpid(), sig)`, bukan simulasi.

### Contoh: Graceful HTTP Server

```pascal
var SRV := -1;

function handler(req) begin
  return {"status": 200, "body": "ok"};
end;

begin
  SRV := http.serve(8080, handler);

  signal.on("SIGTERM", lambda : begin
    log.info("SIGTERM received");
    http.stop(SRV);
  end);

  signal.on("SIGINT", lambda : begin
    log.info("Ctrl+C pressed");
    http.stop(SRV);
  end);

  log.info("server listening on :8080");
  http.listenAsync(SRV);
end.
```

### Catatan Platform

- **Unix/Android**: pakai POSIX `fpSignal()`
- **Windows**: belum diimplementasikan (limitasi OS — beda API)

---
## Shutdown Hooks

Register callback yang fire saat script exit (`sys.exit()`) atau engine shutdown.

### `onShutdown(fn)`

Register cleanup callback.

```pascal
onShutdown(lambda : begin
  log.info("closing database...");
  sqliteClose(DB);
end);

onShutdown(flushLogs);
```

**Behavior**:
- **LIFO order** — hook terakhir didaftarkan = fire pertama (stack semantics)
- Fire **sebelum** engine teardown → DB/network/socket masih usable
- **5 detik timeout** per hook — cegah hang
- Error di satu hook **tidak** stop hook lain
- Re-entrancy guard — hook tidak bisa trigger dirinya sendiri

### Contoh: Cleanup Chain

```pascal
begin
  var DB := sqliteConnect("app.db");
  var LOG := fileAppend("audit.log", "session start\n");
  var SOCK := net.connect("api.example.com", 443);

  onShutdown(lambda : net.close(SOCK));
  onShutdown(lambda : log.info("closing db"));
  onShutdown(lambda : sqliteClose(DB));

  // Fire order saat exit: sqliteClose → log → net.close (LIFO)

  // ... main logic ...
end.
```

### Best Practices

| Cleanup | Order (LIFO) |
|---------|-------------|
| Register pertama | Fire terakhir |
| Register terakhir | Fire pertama |

**Aturan**: register yang **paling dasar** dulu (network, DB), lalu yang **paling specific** kemudian.

Contoh:
```pascal
onShutdown(lambda : net.close(SOCK));   // register 1 → fire terakhir
onShutdown(lambda : sqliteClose(DB));   // register 2 → fire kedua
onShutdown(lambda : log.info("bye"));   // register 3 → fire pertama
```

Kalau cleanup butuh DB, register DB **terakhir** supaya DB di-close **pertama** saat shutdown.

### Kombinasi dengan Signal

```pascal
begin
  var DB := sqliteConnect("app.db");

  onShutdown(lambda : begin
    log.info("shutting down");
    sqliteClose(DB);
  end);

  signal.on("SIGTERM", lambda : sys.exit(0));
  signal.on("SIGINT", lambda : sys.exit(0));

  // SIGTERM → handler fire → sys.exit → onShutdown fire → DB closed
end.
```
## Coroutine Scheduler

Cooperative coroutine scheduler — task interleaving dengan timer-based wake.

**Konsep**: spawn N coroutine, `coSleep(ms)` yield, scheduler resume otomatis setelah `ms`.

### `coSpawn(fn) → taskID`

Spawn coroutine, register ke scheduler.

```pascal
var tid := coSpawn(lambda : begin
  println("start");
  coSleep(1000);
  println("1 detik kemudian");
  coSleep(500);
  println("500ms lagi");
  return 42;
end);
```

**Return**: `taskID` (integer ≥ 1) atau `-1` kalau argumen invalid.

**Behavior**:
- Coroutine **tidak** langsung jalan — scheduler jalan setelah `coWait` / `coWaitAll` / event loop tick
- Task state disimpan di global map (thread-safe)
- Return value dari coroutine di-capture, di-return oleh `coWait`

### `coSleep(ms)`

Yield dari coroutine, minta scheduler resume setelah `ms` milidetik.

**Compiler built-in** — bukan fungsi runtime biasa. Emit `{"__co_sleep": ms} + opcYield`.

```pascal
function myTask() begin
  println("phase 1");
  coSleep(2000);        // yield, scheduler resume dalam 2s
  println("phase 2");
end;
```

**Batasan**:
- Harus dipanggil di dalam coroutine (spawn via `coSpawn`)
- Kalau dipanggil di top-level script → script exit early (yield tidak di-handle)

### `coWait(taskID, [timeoutMs]) → value | null`

Blocking wait sampai coroutine selesai. **Drive scheduler** selama menunggu.

```pascal
var tid := coSpawn(myTask);
var result := coWait(tid, 5000);   // timeout 5s

if result == null then
  println("timeout atau error")
else
  println("hasil: ", result);
```

**Parameter**:
- `taskID` — return dari `coSpawn`
- `timeoutMs` — opsional, 0 atau omit = wait forever

**Return**:
- **value** — coroutine selesai, return value dari `return`
- **null** — timeout, error, atau taskID invalid

**Auto-cleanup**: task di-free setelah `coWait` return.

### `coWaitAll([timeoutMs])`

Blocking wait sampai **semua** coroutine selesai.

```pascal
coSpawn(task1);
coSpawn(task2);
coSpawn(task3);

coWaitAll(30000);   // tunggu semua, max 30s
println("semua selesai");
```

**Behavior**: driver scheduler selama menunggu. Task yang error tidak block task lain.

### `coCount() → int`

Jumlah coroutine aktif (state: pending, running, atau sleeping).

```pascal
coSpawn(t1);
coSpawn(t2);
println("active: ", coCount());   // 2

coWaitAll();
println("active: ", coCount());   // 0
```

### `coCancel(taskID) → bool`

Force-kill coroutine. Free VM instance + hapus dari registry.

```pascal
var tid := coSpawn(longRunningTask);
coSleep(100);   // kasih waktu start
var ok := coCancel(tid);
println("cancel: ", ok);   // true
```

**Return**: `True` kalau berhasil, `False` kalau taskID invalid / sudah done.

**Behavior**:
- VM di-free tanpa eksekusi cleanup (defer di dalam coroutine **tidak** jalan)
- Untuk graceful shutdown, pakai flag internal + cek di dalam coroutine

---

### Contoh — Parallel Timer

3 timer berjalan paralel dengan interval berbeda:

```pascal
function timer1() begin
  var i := 0;
  while i < 5 do begin
    println("[T1] tick ", i);
    coSleep(1000);
    i := i + 1;
  end;
end;

function timer2() begin
  var i := 0;
  while i < 10 do begin
    println("[T2] tick ", i);
    coSleep(500);
    i := i + 1;
  end;
end;

begin
  coSpawn(timer1);
  coSpawn(timer2);
  coWaitAll();
end.
```

**Output** (interleaved):
```
[T1] tick 0
[T2] tick 0
[T2] tick 1
[T1] tick 1
[T2] tick 2
[T2] tick 3
[T1] tick 2
...
```

### Contoh — Fetch Parallel + Collect

Fetch 3 URL paralel, tunggu semua:

```pascal
var RESULTS := {};

function fetchAndStore(name, url) begin
  println("fetching ", name);
  var r := http.get(url);
  lock begin
    RESULTS[name] = r.status;
  end;
  return r.status;
end;

begin
  coSpawn(lambda : fetchAndStore("gh", "https://api.github.com/"));
  coSpawn(lambda : fetchAndStore("hn", "https://hacker-news.firebaseio.com/"));
  coSpawn(lambda : fetchAndStore("httpbin", "https://httpbin.org/get"));

  coWaitAll(30000);

  for key in RESULTS.keys() do
    println(key, ": ", RESULTS[key]);
end.
```

**Catatan**: HTTP sudah async via worker pool. Coroutine di sini untuk orchestration kalau ada blocking calls.

### Contoh — Timeout Pattern

```pascal
function slowTask() begin
  coSleep(10000);
  return "done";
end;

begin
  var tid := coSpawn(slowTask);
  var result := coWait(tid, 3000);

  if result == null then begin
    println("timeout, cancel task");
    coCancel(tid);
  end else
    println("ok: ", result);
end.
```

### Kombinasi dengan Event Loop

Event loop tick (`TickOnce`) juga drive scheduler. Jadi kalau ada timer aktif:

```pascal
var tid := coSpawn(myTask);

setTimeout(lambda : println("timer fired"), 500);
coWait(tid, 5000);   // coroutine + timer sama-sama progress
```

**Kapan pakai coroutine vs timer**:

| Skenario | Pakai |
|---|---|
| Polling periodic | `setInterval` |
| Sequential delay + kerja | **`coSpawn` + `coSleep`** |
| Parallel tasks + wait | **`coSpawn` + `coWaitAll`** |
| Chain async ops (CPS) | **`coSpawn` + `coSleep`** |
| One-shot delayed action | `setTimeout` |

### Best Practices

**✅ Gunakan coroutine untuk orchestration**:
```pascal
function loadUserData(userId) begin
  coSleep(100);   // simulated fetch delay
  return {"id": userId, "name": "Alice"};
end;

function loadSettings(userId) begin
  coSleep(150);
  return {"theme": "dark"};
end;

begin
  var u := coSpawn(lambda : loadUserData(42));
  var s := coSpawn(lambda : loadSettings(42));

  var user := coWait(u, 5000);
  var settings := coWait(s, 5000);

  println("loaded: ", user["name"], " + ", settings["theme"]);
end.
```

**❌ Jangan pakai `coSleep` di luar coroutine**:
```pascal
// ❌ SALAH — top-level
begin
  coSleep(1000);   // yield di root → script exit
  println("never");
end.
```

**✅ Shared state antar coroutine** — pakai `lock`:
```pascal
var COUNTER := 0;

function incrementer() begin
  var i := 0;
  while i < 100 do begin
    lock begin
      COUNTER := COUNTER + 1;
    end;
    coSleep(10);
    i := i + 1;
  end;
end;

begin
  coSpawn(incrementer);
  coSpawn(incrementer);
  coWaitAll();
  println("counter: ", COUNTER);   // 200
end.
```

### Limitations (v1)

| Fitur | Status |
|---|---|
| Cooperative scheduling | ✅ |
| Timer-based sleep | ✅ |
| Return value capture | ✅ |
| Parallel tasks | ✅ |
| Timeout pada `coWait` | ✅ |
| Cancel | ✅ |
| Priority scheduling | ❌ (backlog) |
| `coJoin([taskIDs])` — wait subset | ❌ (backlog) |
| Callback saat task done | ❌ (backlog) |
| True preemption | ❌ (cooperative only) |
| Cross-thread resume | ❌ (main thread only) |

**Catatan**:
- Coroutine adalah **cooperative** — task hanya yield di `coSleep`, bukan preempt
- Tidak ada paralelisme CPU — single-threaded scheduler
- Untuk CPU-bound parallelism, pakai `thread()` atau `poolRun()`

---

---

## Timers

Timer API publik — non-blocking, berbasis event loop internal.

### `setTimeout(fn, ms) → timerID`

Fire `fn` sekali setelah `ms` milidetik.

```pascal
setTimeout(lambda : println("fired!"), 1000);
```

setInterval(fn, ms) → timerID

Fire fn berulang setiap ms milidetik.

```pascal
var t := setInterval(lambda : println("tick"), 500);
// ... kemudian ...
clearInterval(t);
```

clearTimeout(timerID) → bool

clearInterval(timerID) → bool

Cancel timer. Kedua nama adalah alias — pakai yang sesuai konteks.

```pascal
var t := setTimeout(cleanup, 5000);
// user selesai lebih cepat:
clearTimeout(t);
```

Catatan:

· Callback jalan di main event loop thread — aman akses state script
· setInterval dengan ms < 1 di-clamp ke 1ms
· Timer auto-cancel saat engine shutdown
· Return -1 kalau argument invalid

```
## JSON Path

### `jsonPath(dict, "a.b.c") → value | null`

Ekstrak nilai dari nested dict via dot-separated path.

```pascal
var data := jsonParse('{"user":{"profile":{"name":"Alice"}}}');
println(jsonPath(data, "user.profile.name"));   // "Alice"
println(jsonPath(data, "user.missing"));        // null
println(jsonPath(data, "nonexistent.deep"));    // null
```

Behavior:

· Traverse dict layer per layer
· Return null kalau segment tidak ada
· Return null kalau intermediate bukan dict (mis. string/number)
· Empty segment ("..") di-skip otomatis
· Hanya support dict (array indexing belum)

Kapan pakai:

· Config berlapis: jsonPath(config, "database.host")
· Response API nested: jsonPath(resp, "data.user.id")
· Safe access tanpa cek hasKey manual berlapis

## FFI

### `dll.load(path) → dllHandle`

Load shared library. Dedup otomatis — library dengan canonical path sama
hanya di-load sekali.

```pascal
var lib := dll.load("libm.so.6");
```

**Path resolution**:
- **Bare name** (tanpa `/`): coba sandbox-relative dulu (sebelah script), fallback ke linker
- **Absolute path**: harus di whitelist sistem (`/system/lib64/`, `/usr/lib/`, `$PREFIX/lib/`)
- **Relative path**: sandbox-relative saja

### `lib.func(name, sig [, structTypes]) → functionWrapper`

Ambil fungsi dari library dan bungkus jadi callable.

```pascal
// Simple
var sqrtFn := lib.func("sqrt", "f->f");
println(sqrtFn(2.0));

// Dengan struct (butuh array structType)
var translate := lib.func("point_translate", "Sii->S", [PointType, PointType]);
```

**Argumen ke-3** (opsional): array `structType` untuk setiap `S` di signature.
Urutan: argumen struct dulu (kiri ke kanan), lalu return struct (kalau ada).

### `lib.symbol(name) → pointer`

Ambil alamat symbol mentah (variabel global, fungsi tanpa wrapper).

```pascal
var counterPtr := lib.symbol("global_counter");
```

### `lib.isValid() / lib.path() / lib.close()`

Lifecycle management.

```pascal
if lib.isValid() then println(lib.path());
lib.close();
```

### `lib.closureAvailable() → bool`

Cek apakah libffi tersedia untuk callback bridge.

```pascal
if dll.closureAvailable() then
  println("Callback bridge OK");
```

### `lib.closureInfo() → dict`

Informasi detail tentang status libffi.

```pascal
var info := dll.closureInfo();
println(info.status);       // "libffi loaded"
println(info.available);    // true
```

### `lib.callback(sig, fn) → pointer`

Bungkus fungsi script jadi C-compatible callback.

```pascal
function cmpAsc(a, b) begin
  if a < b then return -1;
  if a > b then return 1;
  return 0
end;

var cmp := dll.callback("ii->i", cmpAsc);
qsortFn(native.bufferPtr(buf), native.bufferSize(buf), cmp);
dll.freeCallback(cmp);
```

### `lib.freeCallback(ptr) → bool`

Bebaskan callback eksplisit. Kalau tidak dipanggil, auto-cleanup di shutdown.

### `lib.callbackCount() → int`

Jumlah callback aktif (diagnostik).

---

### FFI Signature Syntax

Format: `<args>-><return>`

| Huruf | C Type | Pascal VM |
|---|---|---|
| `i` | `int64_t` | `TValue` numeric |
| `f` | `double` | `TValue` numeric |
| `s` | `char*` | `string` (UTF-8) |
| `p` | `void*` | `dtPointer` |
| `I` | `size_t` | `int64_t` (semantik) |
| `S` | `struct` | `TNativeStructValue` |
| `C` | alias `p` (callback) | `dtPointer` |
| `v` | `void` (return only) | `null` |

**Contoh:**

| Signature | Arti |
|---|---|
| `i->i` | `int64(int64)` |
| `ii->i` | `int64(int64, int64)` |
| `f->f` | `double(double)` |
| `s->i` | `int64(const char*)` |
| `ss->s` | `char*(const char*, const char*)` |
| `pIp->v` | `void(void*, size_t, void*)` |
| `pip->v` | `void(void*, int64_t, void*)` — qsort style |
| `Sii->S` | `Point(Point, int64, int64)` |
| `SS->i` | `int64(Point, Point)` |

**Penting — `pIp` vs `pip`**:

Keduanya ABI-identik (8-byte register), tapi **marshalling berbeda**:

| Signature | Stub perlakukan arg ke-2 sebagai |
|---|---|
| `pIp->v` | `Pointer` (`memcpy` style: dst, src, count) |
| `pip->v` | `Int64` (qsort style: buf, count, cmp) |

Gunakan `pip` untuk fungsi dengan `(pointer, count, ...)`.
Gunakan `pIp` untuk `(dst, src, count)` seperti `memcpy`.

---

## Native Buffer

Buffer int64 linear untuk interop C array.

### `native.fromArray(arr) → buffer`

Buat buffer dari array script.

```pascal
var buf := native.fromArray([10, 20, 30]);
```

Elemen non-numeric (string, null) di-coerce ke 0.

### `native.bufferPtr(buf) → pointer`

Ambil pointer ke backing storage (`int64[]`).

```pascal
qsortFn(native.bufferPtr(buf), native.bufferSize(buf), cmp);
```

### `native.bufferSize(buf) → int`

Jumlah elemen.

### `native.bufferToArray(buf) → array`

Baca balik buffer sebagai array baru.

```pascal
var sorted := native.bufferToArray(buf);
```

### `native.bufferFree(buf) → bool`

Free eksplisit. Idempotent — double-free return `false`.

---

## Native Struct

Struct dengan layout C-compatible (POSIX alignment).

### `native.structType(name, fields) → structType`

Deklarasi tipe struct.

```pascal
var PointType := native.structType("Point", [
  ["x", "i32"],
  ["y", "i32"]
]);

var EntryType := native.structType("Entry", [
  ["id",     "i64"],
  ["score",  "f64"],
  ["active", "bool"],
  ["rank",   "i32"]
]);
```

**Field kinds:**

| Kind | Size | Align | C Type |
|---|---|---|---|
| `i8` | 1 | 1 | `int8_t` |
| `i16` | 2 | 2 | `int16_t` |
| `i32` | 4 | 4 | `int32_t` |
| `i64` | 8 | 8 | `int64_t` |
| `f32` | 4 | 4 | `float` |
| `f64` | 8 | 8 | `double` |
| `ptr` | 8 | 8 | `void*` |
| `bool` | 1 | 1 | `_Bool` |

### `native.newStruct(type) → structValue`

Instantiate struct, zero-initialized.

```pascal
var p := native.newStruct(PointType);
```

### `native.structGet(value, fieldName) → any`

Baca field.

```pascal
var x := native.structGet(p, "x");
```

### `native.structSet(value, fieldName, val) → bool`

Tulis field.

```pascal
native.structSet(p, "x", 10);
```

### `native.structSize(value) → int`

Total size (dengan padding).

### `native.structTypeName(value) → string`

Nama type.

### `native.structFree(value) → bool`

Free struct value. Idempotent.

### `native.structTypeFree(type) → bool`

Free struct type.

### `native.structFFITypeInfo(type) → dict`

Diagnostik `ffi_type` construction:

```pascal
var info := native.structFFITypeInfo(PointType);
println(info.totalSize);      // 8
println(info.ffiTypeTag);     // 13 (FFI_TYPE_STRUCT)
println(info.elementCount);   // 2
```

**Contoh lengkap**:

```pascal
// 1. Deklarasi struct Point
var PointType := native.structType("Point", [
  ["x", "i32"],
  ["y", "i32"]
]);

// 2. Load library
var lib := dll.load("libgeom.so");

// 3. Ambil fungsi yang terima/kembalikan struct
var translate := lib.func("point_translate", "Sii->S", [PointType, PointType]);

// 4. Buat instance
var p := native.newStruct(PointType);
native.structSet(p, "x", 10);
native.structSet(p, "y", 20);

// 5. Panggil
var r := translate(p, 5, 7);
println(native.structGet(r, "x"));   // 15
println(native.structGet(r, "y"));   // 27

// 6. Cleanup
native.structFree(p);
native.structFree(r);
native.structTypeFree(PointType);
lib.close();
```

---

## HTTP Client

### `http.get(url [, headers]) → dict`

Sync HTTPS request.

```pascal
var res := http.get("https://example.com");
println(res.status);      // 200
println(res.headers);     // dict header
println(res.body);        // string body
println(res.tls_verify);  // true (default)
```

### `http.post(url [, headers] [, body]) → dict`

POST request.

### `http.request(method, url [, headers] [, body]) → dict`

Request dengan method custom.

### `http.getAsync(url, callback) → null`

Async request. Callback dipanggil di main thread via event loop.

```pascal
http.getAsync("https://example.com", lambda res : begin
  if res.hasKey("error") then
    println("FAIL: ", res.error)
  else
    println("OK: ", res.status);
end);
```

**Callback menerima**:
- **Sukses**: `{status, headers, body, tls_verify}`
- **Error**: `{error: "message"}`

**Batasan**: max 8 concurrent request (worker pool size). Request ke-9 antri.

### http.get2(url [, headers] [, body]) -> dict

HTTP/2 request via TLS ALPN. Requires server support for h2.

Example:

    var r := http.get2("https://httpbin.org/get");
    println(r["status"]);    // 200
    println(r["version"]);   // "h2"

Return dict: status (int), version (string "h2"), headers (dict), body (string).

Requirements: https only, server must negotiate h2 via ALPN.

Error handling: server without h2 raises; TLS failure raises; timeout raises.

Scope v1: single-stream, GET primary, no pooling.

http.get2 vs http.get:
- Server h2-only          -> http.get2
- Sequential same host    -> http.get (pooling faster)
- Verify h2 version       -> http.get2
- Need h1 fallback        -> http.get

Note: http.get (h1) with pooling is faster for sequential requests.
http.get2 (v1) opens new connection per request. Main use: h2-only
server compat + version verification. Multiplexing + pooling planned v2.

---

### Connection Pooling (Fase A.1)

HTTP client otomatis reuse TCP + TLS connection ke host yang sama.
Efek: request ke API yang sama jadi **10-20× lebih cepat** karena
tidak ada handshake ulang.

**Enable/disable**: pooling aktif by default. Tidak perlu setup.

**Contoh**:

```pascal
// 100 request ke host sama — hanya 1 TCP+TLS handshake
var start := time.now();
for i := 1 to 100 do
  var r := http.get("https://api.example.com/data");
println("Elapsed: ", time.now() - start);   // ~0.5s dengan pool
```

#### `http.poolStats() → dict`

Statistik runtime pool.

```pascal
var s := http.poolStats();
println("hits: ", s.hits);           // request yang reuse conn
println("misses: ", s.misses);       // request yang buka conn baru
println("idle: ", s.idle);           // conn idle di pool
println("maxPerHost: ", s.maxPerHost);
println("idleMs: ", s.idleMs);
```

**Hit ratio** = `hits / (hits + misses)`. Target > 0.9 untuk workload API-heavy.

#### `http.poolConfig(maxPerHost, [idleMs])`

Tuning runtime pool.

```pascal
http.poolConfig(16, 60000);   // max 16 conn/host, idle timeout 60s
```

| Parameter | Default | Deskripsi |
|---|---|---|
| `maxPerHost` | 8 | Max idle conns per `(host,port,scheme,verify)` |
| `idleMs` | 30000 | Close conn kalau idle > N ms |

#### `http.poolClear()`

Force close semua idle connection. Berguna untuk reset setelah error atau test.

```pascal
http.poolClear();
```

#### Kapan Pooling Aktif

Pool reuse connection HANYA kalau response memenuhi:

| Requirement | Kenapa |
|---|---|
| Header `Content-Length` ada | Tahu batas body → bisa kirim request berikutnya di socket sama |
| Tidak ada `Connection: close` | Server setuju keep socket |
| Tidak `Transfer-Encoding: chunked` | Chunked perlu decoder khusus (belum diimplementasi) |

Kalau salah satu tidak terpenuhi → socket di-close setelah response
(fallback, tetap benar, hanya tidak di-pool).

**Server yang compatibility**:
- ✅ REST API modern (GitHub, Stripe, custom API)
- ✅ `http.listenAsync` server (Pascak sendiri)
- ⚠️ `http.listen` blocking server (tutup socket per request)
- ❌ Server dengan chunked encoding (Belum di-pool, tracked A.1b)

#### Contoh: Configure untuk High-Throughput

```pascal
http.poolConfig(32, 60000);   // 32 conn/host untuk paralel tinggi

var URLs := [
  "https://api.github.com/users/octocat",
  "https://api.github.com/repos/octocat/Hello-World",
  // ... 100 more
];

for url in URLs do begin
  var res := http.get(url);
  // ... process ...
end;

var stats := http.poolStats();
log.info("pool hit ratio: ", stats.hits, "/", stats.hits + stats.misses);
```

**Output** (setelah 100 request):
```
pool hit ratio: 99/100
```

#### Troubleshooting

**Pool hit ratio rendah (< 0.5)**:

1. Check response header — apakah server kirim `Content-Length`?
   ```pascal
   var res := http.get(url);
   println("Content-Length: ", res.headers["Content-Length"]);
   println("Connection: ", res.headers["Connection"]);
   println("Transfer-Encoding: ", res.headers["Transfer-Encoding"]);
   ```

2. Kalau `Transfer-Encoding: chunked` → known limitation (A.1b).

3. Kalau `Content-Length` ada tapi tetap miss → bug, report.

**Memory growth karena banyak idle connections**:

```pascal
// Turunkan maxPerHost dan idleMs
http.poolConfig(4, 10000);   // 4 conn/host, 10s idle
```

Atau clear manual setelah workload burst:

```pascal
// Batch heavy workload
for url in heavyBatch do
  http.get(url);

// Done — free pool
http.poolClear();
```

**Pool reset di test**:

```pascal
http.poolClear();   // reset state sebelum assertion
var s := http.poolStats();
assertEqual(0, s.idle, "pool empty");
```

---
### Transfer-Encoding: Chunked

HTTP client **otomatis decode** chunked response (RFC 7230 §4.1). Tidak perlu setup — transparan.

```pascal
// Server yang kirim chunked (banyak CDN, API gateway)
var r := http.get("https://example.com/");
println("body len: ", len(r.body));              // decoded body
println("Transfer-Encoding: ", r.headers["Transfer-Encoding"]);  // "chunked"
println("Content-Length: ", r.headers["Content-Length"]);        // null
```

**Coverage**:
- ✅ `Content-Length` response → pool reuse
- ✅ `Transfer-Encoding: chunked` → pool reuse
- ✅ Chunk extension (`;` setelah size) → skip otomatis
- ✅ Incomplete chunked → fallback close (no pool)

**Chunked + pooling**: server yang pakai chunked sekarang **bisa di-pool** — tidak perlu new connection per request.

### Server Keep-Alive

HTTP server (`http.listen` **dan** `http.listenAsync`) support HTTP/1.1 keep-alive otomatis:

| Config | Default |
|---|---|
| `KEEPALIVE_MAX_REQUESTS` | 100 request per connection |
| `KEEPALIVE_TIMEOUT_MS` | 30000 ms (30 detik idle) |

**Server** kirim header otomatis:
```
Connection: keep-alive
Keep-Alive: timeout=30, max=100
```

**Client** (pool) deteksi + reuse socket — 1 handshake untuk 100 request.

**Test**:
```pascal
// 100 request sequential ke server keep-alive
var start := time.now();
for i := 1 to 100 do
  http.get("http://127.0.0.1:8080/api");
println("Elapsed: ", time.now() - start);
// ~1s dengan keep-alive, ~10s tanpa
```

**Behavior**:
- HTTP/1.0 → default close (keep-alive hanya kalau client minta)
- HTTP/1.1 → default keep-alive
- Client kirim `Connection: close` → server tutup setelah response
- Server idle 30s → tutup otomatis
- Max 100 request → tutup untuk hindari resource leak

---


### Env override untuk TLS verify

```bash
PASCAK_TLS_NO_VERIFY=1 ./pascak_noASTnet script.pas
```

Atau per-request via header:
```pascal
http.get("https://self-signed.example.com", {
  "X-Pascak-No-Verify": "1"
});
```

---

## HTTP Server

### `http.serve(port, handler) → serverHandle`

Handler = `lambda(req) → resDict`.

```pascal
function handler(req) begin
  var method := req["method"];    // ← indexing (method = keyword)
  var path := req["path"];        // ← indexing (bisa juga req.path)
  var body := req["body"];
  
  if path == "/" and method == "GET" then
    return {
      "status": 200,
      "headers": {"Content-Type": "text/html"},
      "body": "<h1>Hello!</h1>"
    };
  
  return {
    "status": 404,
    "body": "Not Found"
  };
end;

var server := http.serve(8080, handler);
http.listen(server);   // blocking
```

### `http.listen(serverHandle) → int`

Blocking serve loop. Return jumlah request yang di-serve.

Serve loop non-blocking — accept di main thread, eksekusi handler di worker pool (8 concurrent). Mendukung plain HTTP dan HTTPS.

```markdown
### `http.listenAsync(serverHandle) → int`

Serve loop non-blocking — accept di main thread, eksekusi handler di worker pool (8 concurrent). Mendukung plain HTTP dan HTTPS.

```pascal
var server := http.serve(8080, handler);
var n := http.listenAsync(server);
println("Total dispatched: ", n);
```

Aspek http.listen http.listenAsync
Handler execution Main thread (serial) Worker pool (8 concurrent)
Throughput 1× ~5-8×
Blocking Ya Tidak (accept timeout 500ms)
TLS support Tidak Ya (via serveTLS)
Cocok untuk Prototype Production

Benchmark — handler sleep(100), 10 concurrent request:

Setup Waktu total
http.listen ~1.8s
http.listenAsync ~0.35s
Speedup ~5×

Graceful shutdown: http.stop(server).

### `http.serveTLS(port, certPath, keyPath, handler) → serverHandle`

HTTPS server. Butuh certificate + private key format PEM.

```pascal
var home := sys.env("HOME");
var server := http.serveTLS(8443,
  home + "/server.crt",
  home + "/server.key",
  handler);

http.listenAsync(server);
```

Generate self-signed cert:

```bash
openssl req -x509 -newkey rsa:2048 -keyout server.key -out server.crt \
    -days 365 -nodes -subj "/CN=localhost"
```

Test:

```bash
curl -sk https://localhost:8443/health
```

Cert validation di startup: cert readable, private key readable, key cocok dengan cert.

Sandbox: absolute path di $HOME diizinkan. Path lain relative terhadap direktori script.

Protokol: TLS 1.3 dengan forward secrecy.

Contoh: examples/rest_api_tls.pas.

```

### `http.stop(serverHandle) → bool`

Graceful shutdown — selesaikan request aktif, lalu exit loop.

### `http.closeServer(serverHandle) → bool`

Close server paksa.

---
```markdown
### Keep-Alive (HTTP/1.1 persistent connections)

Server yang dibuat via `http.serve` + `http.listen` atau `http.listenAsync` otomatis mendukung HTTP/1.1 keep-alive. Satu TCP connection melayani hingga **100 request** atau sampai client idle **30 detik**, mana yang lebih dulu.

**Manfaat:**
- Throughput ~21× lebih tinggi dari serial-close per request
- Hemat TLS handshake pada HTTPS (1 handshake untuk 100 request)
- Mengurangi latensi round-trip pada client-side HTTP pipelining

**Headers otomatis:**
```

Connection: keep-alive
Keep-Alive: timeout=30, max=100

```

Client yang mengirim `Connection: close` akan dipaksa disconnect setelah request itu selesai.

**Tuning (constant di `pascak_http.pas`):**
- `KEEPALIVE_MAX_REQUESTS = 100`
- `KEEPALIVE_TIMEOUT_MS = 30000`

**Catatan:** `http.listenAsync` menggunakan worker pool untuk handler, tapi TLS handshake tetap di-accept thread. Setelah handshake, satu worker melayani seluruh lifecycle connection (semua request dalam satu keep-alive session).

---
```
```markdown
## Module: ws — WebSocket Server

WebSocket (RFC 6455) server dengan dukungan penuh text/binary frame, fragmentasi, ping/pong, close handshake. Plain (`ws://`) dan TLS (`wss://`).

### `ws.connect(url, [config]) → handle`

**WebSocket client** — connect ke server WS external.

```pascal
var c := ws.connect("ws://echo.example.com/", {
  "onOpen":    lambda conn : println("connected: ", conn.id),
  "onMessage": lambda conn, msg : println("recv: ", msg),
  "onClose":   lambda conn, code : println("closed: ", code),
  "onError":   lambda conn, err : println("error: ", err)
});
```

**Config keys** (semua optional):

| Key | Tipe | Deskripsi |
|---|---|---|
| `onOpen` | function | Fire saat handshake sukses. Signature: `fn(conn)` |
| `onMessage` | function | Fire saat frame text/binary diterima. `fn(conn, msg)` |
| `onClose` | function | Fire saat koneksi tutup. `fn(conn, code)` |
| `onError` | function | Fire saat error (connect/handshake/runtime). `fn(conn, err)` |
| `verify` | bool | Verify TLS certificate (default `true`). Set `false` untuk self-signed. |

**Return**: handle dict dengan field + method.

**Handle fields**:

| Field | Tipe | Deskripsi |
|---|---|---|
| `id` | string | Connection ID (format: `wscl-NNNNNNNN`) |
| `url` | string | Full URL koneksi |
| `host` | string | Hostname |
| `port` | number | Port |
| `tls` | bool | `true` kalau `wss://` |

**Handle methods**:

| Method | Return | Deskripsi |
|---|---|---|
| `c.send(msg)` | bool | Kirim text frame |
| `c.sendBytes(data)` | bool | Kirim binary frame |
| `c.close([code])` | bool | Kirim close frame (default `1000`) |
| `c.isOpen()` | bool | Cek state koneksi |
| `c.state()` | string | `connecting`\|`handshake`\|`open`\|`closing`\|`closed` |

**Contoh — Client Sederhana**:

```pascal
var messages := [];

begin
  var c := ws.connect("wss://echo.websocket.events/", {
    "onOpen": lambda conn : begin
      log.info("connected: ", conn.id);
      conn.send("hello");
    end,
    "onMessage": lambda conn, msg : begin
      log.info("recv: ", msg);
      push(messages, msg);
    end,
    "onClose": lambda conn, code : log.info("closed: ", code)
  });

  // Tunggu 3 detik untuk receive echo
  sleep(3000);
  c.close();

  log.info("received ", len(messages), " messages");
end.
```

**Contoh — Multi-Client**:

```pascal
var clients := [];

begin
  for i := 1 to 5 do begin
    var c := ws.connect("ws://127.0.0.1:9001/", {
      "onMessage": lambda conn, msg : println(conn.id, ": ", msg)
    });
    push(clients, c);
  end;

  sleep(2000);

  // Broadcast ke semua client (via server side)
  for c in clients do
    c.send("ping " + c.id);

  sleep(2000);
  for c in clients do
    c.close();
end.
```

**Contoh — Bridge REST → WS**:

```pascal
var WS := nil;

begin
  WS := ws.connect("wss://feed.example.com/stream", {
    "onOpen": lambda c : log.info("stream connected"),
    "onMessage": lambda c, msg : begin
      var data := jsonParse(msg);
      var price := jsonPath(data, "price");
      var symbol := jsonPath(data, "symbol");
      log.info(symbol, ": ", price);
    end
  });

  // Keep alive
  sleep(60000);
  WS.close();
end.
```

**Batasan v1**:
- ❌ Subprotocol negotiation (belum)
- ❌ Permessage-deflate compression (belum)
- ❌ Auto-reconnect (manual via onClose)
- ⚠️ 1 connection = 1 OS thread

**Close codes** (RFC 6455 §7.4):

| Code | Nama |
|---|---|
| 1000 | Normal Close |
| 1001 | Going Away |
| 1002 | Protocol Error |
| 1007 | Invalid Payload |
| 1008 | Policy Violation |
| 1009 | Too Large |
| 1011 | Internal Error |

**Best practices**:

```pascal
// ✅ Simpan handle untuk close nanti
var conn := ws.connect(...);
onShutdown(lambda : conn.close());   // cleanup

// ✅ Reconnect manual di onClose
function reconnectLoop() begin
  var c := ws.connect(url, {
    "onClose": lambda conn, code : begin
      log.warn("disconnected (", code, "), reconnecting in 5s...");
      setTimeout(reconnectLoop, 5000);
    end
  });
end;

// ❌ Jangan block di callback — pakai async
function onMessage(conn, msg) begin
  // ❌ http.get(url);  // blocking, freeze client thread
  // ✅ spawn worker atau timer
end;
```

### Auto-Reconnect

WS client bisa otomatis reconnect setelah disconnect. Backoff exponential, capped.

```pascal
var c := ws.connect("wss://api.example.com/ws", {
  "onOpen":         lambda conn : println("connected"),
  "onMessage":      lambda conn, msg : println("recv: ", msg),
  "onClose":        lambda conn, code : println("closed: ", code),
  "autoReconnect":  true,        // ← enable
  "reconnectMinMs": 1000,        // ← backoff awal (default 1000)
  "reconnectMaxMs": 30000        // ← backoff cap (default 30000)
});
```

**Backoff pattern**:
```
Attempt 1: wait 1000ms  (min)
Attempt 2: wait 2000ms
Attempt 3: wait 4000ms
Attempt 4: wait 8000ms
Attempt 5: wait 16000ms
Attempt 6: wait 30000ms (capped at max)
...
```

**Trigger**:
- Connect gagal (DNS, TCP, TLS)
- Handshake gagal (401, accept mismatch)
- Server tutup koneksi (`onClose` fire)
- Network error mid-stream

**Setiap (re)connect sukses**:
- `onOpen` fire ulang
- Client handshake baru (Sec-WebSocket-Key regenerate)

**Setiap disconnect**:
- `onClose` fire dengan close code

**Matikan auto-reconnect**:
```pascal
c.close();   // explicit close → disable + stop retry
```

**Runtime counter**:
```pascal
println("attempts: ", c.attempts());   // jumlah retry sejauh ini
```

**Use case**:
- Microservice di mobile network (WiFi ↔ 4G handoff)
- Long-lived feed dari remote server
- Auto-recover setelah server restart
- Resilient connector untuk tidak-managed network

**Best practice**:
```pascal
function onOpen(conn) begin
  log.info("WS connected: ", conn.id);
  // Re-subscribe / re-auth setelah reconnect
  conn.send(jsonStringify({"action": "subscribe", "channel": "updates"}));
end;

var c := ws.connect(url, {
  "onOpen": onOpen,
  "onMessage": onMessage,
  "autoReconnect": true,
  "reconnectMinMs": 500,
  "reconnectMaxMs": 10000
});
```

**Catatan**:
- Auto-reconnect **disabled** by default (`false`)
- Untuk production, set `reconnectMaxMs` sesuai SLA server (mis. 30s untuk API publik)
- Untuk development, `reconnectMinMs: 200` bikin iterasi cepat

### Subprotocol Negotiation

WS client bisa offer daftar subprotocol; server pilih satu.

```pascal
var c := ws.connect("wss://api.example.com/ws", {
  "onOpen":    lambda conn : println("proto: ", conn.protocol()),
  "onMessage": lambda conn, msg : println("recv: ", msg),
  "subprotocols": ["chat", "json-v1", "binary"]
});

// Setelah handshake, cek hasilnya
println("negotiated: ", c.protocol());   // "chat" atau ""
```

**Behavior**:
- Client kirim `Sec-WebSocket-Protocol: chat, json-v1, binary` di handshake
- Server pilih satu dari daftar → response `Sec-WebSocket-Protocol: chat`
- Client **verifikasi** hasil — kalau server pilih yang tidak di-offer → handshake gagal
- Kalau server tidak pilih apapun → `c.protocol()` return empty string
- Kalau tidak ada di `subprotocols` config → tidak kirim header → server boleh require atau tidak

**Use case**:
- Server multi-dialek (chat + json-v1 + binary protocol)
- Negotiate versi schema (v1, v2)
- Feature detection (subprotocol yang compatible dengan client ini)

**Best practice**:
```pascal
function onOpen(conn) begin
  var proto := conn.protocol();
  if proto == "json-v1" then
    sendMode := "json"
  else if proto == "binary" then
    sendMode := "binary"
  else begin
    log.warn("server tidak pilih subprotocol");
    conn.close(1002);   // protocol error
  end;
end;
```

**Error handling**:
```pascal
// Server bisa reject handshake kalau tidak ada match
// Client akan throw EPascakError, atau state jadi 'closed'
try
  var c := ws.connect(url, {"subprotocols": ["only-this-one"]});
  if not c.isOpen() then
    log.error("handshake gagal");
except
  on E: Exception do
    log.error("connect error: ", E.Message);
end;
```

### Compression (permessage-deflate)

WS client bisa negosiasi permessage-deflate — kompresi per-message (RFC 7692).

```pascal
var c := ws.connect("wss://api.example.com/ws", {
  "onMessage": lambda conn, msg : println("recv: ", len(msg), " bytes"),
  "compression": "on",           // default: off
  "compressionThreshold": 128    // byte (default 128)
});

// Client kirim payload besar → otomatis compress
var payload := "";
var i := 0;
while i < 10000 do begin
  payload := payload + "X";
  i := i + 1;
end;
c.send(payload);   // ~200 bytes di wire setelah kompresi
```

**Behavior**:
- Client kirim `Sec-WebSocket-Extensions: permessage-deflate; client_max_window_bits` saat enabled
- Server response negotiate → `Sec-WebSocket-Extensions: permessage-deflate; ...`
- Client set `RSV1` di frame header untuk frame yang dikompresi
- Frame dengan `RSV1=1` dari server → client decompress otomatis
- Fallback: kalau compressed ≥ original → kirim uncompressed (no RSV1)
- Fallback: kalau inflate error saat terima → treat as raw (fail-silent)

**Threshold**:
- Payload < `compressionThreshold` → **tidak** dikompresi (overhead tidak worth)
- Default 128 byte — cocok untuk chat/API
- Untuk data binary besar (image/video), set higher (mis. 1024) — compression tidak efektif
- Untuk data text (JSON, log), set lower (mis. 64)

**Bandwidth saving** (untuk JSON chat):
| Payload | Uncompressed | Compressed | Saving |
|---|---|---|---|
| 500 bytes | 500 | ~250 | 50% |
| 2 KB | 2048 | ~700 | 66% |
| 10 KB | 10240 | ~800 | 92% |

**Kombinasi dengan subprotocol**:
```pascal
var c := ws.connect("wss://api.example.com/ws", {
  "subprotocols": ["json-v1"],
  "compression": "on",
  "compressionThreshold": 256,   // JSON kecil sering < 256 byte
  "onMessage": onMessage
});
```

**Compatibility**:
- ✅ Server `pascak_websocket` (dengan `compression: "on"`)
- ✅ Python `websockets` library
- ✅ Browser WebSocket API (native support)
- ✅ Node.js `ws` library
- ⚠️ Server tanpa permessage-deflate → client fallback ke uncompressed

**Catatan penting**:
- Compression **opt-in** — default off
- Client & server **wajib** negotiate via extension header — tidak boleh asal kirim RSV1
- Kalau client kirim RSV1 tanpa negotiate → server RFC-compliant **harus** close dengan 1002
- Untuk **SECURITY**: **jangan** aktifkan compression untuk data sensitif (session token, password) — bisa kena **CRIME/BREACH attack**

**Anti-pattern**:
```pascal
// ❌ JANGAN — compression + sensitive data di request yang sama
ws.connect(url, {"compression": "on"});
conn.send("Bearer " + sessionToken);
conn.send("password=" + userPassword);

// ✅ Pattern aman — pisah channel, atau disable compression
var control := ws.connect(url, {"compression": "off"});
control.send("Authorization: Bearer " + token);
```

**Untuk production**:
- **Public API** → `compression: "off"` (hindari attack surface)
- **Internal service** (trusted network) → `compression: "on"` untuk bandwidth
- **Chat/log feed** (tidak sensitif) → `compression: "on"` + threshold 128

---
### Handle Methods

| Method | Return | Deskripsi |
|---|---|---|
| `c.send(msg)` | bool | Kirim text frame |
| `c.sendBytes(data)` | bool | Kirim binary frame |
| `c.close([code])` | bool | Close + disable auto-reconnect |
| `c.isOpen()` | bool | Cek state |
| `c.attempts()` | int | Reconnect attempts sejauh ini |
| `c.state()` | string | `connecting\|handshake\|open\|closing\|closed` |

---

### `ws.serve(port, config) → serverHandle`

Sama seperti sebelumnya — WS server.
### `ws.serve(port: int, config: dict) → int`

Buat WebSocket server plain.

**Config keys:**

| Key | Tipe | Default | Keterangan |
|-----|------|---------|------------|
| `onOpen` | function | `nil` | Callback saat client connect. Signature: `fn(conn)` |
| `onMessage` | function | `nil` | Callback saat frame text/binary diterima. Signature: `fn(conn, msg)` |
| `onClose` | function | `nil` | Callback saat client disconnect. Signature: `fn(conn, code)` |
| `onError` | function | `nil` | Opsional. Callback saat protocol error. Signature: `fn(conn, msg)` |
| `pingInterval` | int (ms) | `30000` | Interval auto-ping. `0` = disabled |
| `maxPayload` | int (byte) | `16777216` (16 MB) | Batas fragmentasi payload |

**Return:** server handle (≥ 0) atau `-1` jika gagal.

**Contoh:**
```pascal
var srv := ws.serve(9001, {
  "onOpen":    onOpen,
  "onMessage": onMessage,
  "onClose":   onClose
});
```

### `ws.serveTLS(port: int, cert: str, key: str, config: dict) → int`

Sama seperti `ws.serve` tapi dengan TLS 1.2/1.3. Format `cert` dan `key`: PEM.

**Return:** server handle (≥ 0) atau `-1` jika gagal.

**Contoh:**

```pascal
var home := sys.env("HOME");
var srv := ws.serveTLS(9443,
  home + "/server.crt",
  home + "/server.key",
  {"onMessage": onMessage});
```

**Batasan event mode:** `ws.serveTLS` **tidak bekerja** dengan `ws.listenAsync` (B.1 belum support TLS event loop). Gunakan `ws.listenThreads` untuk `wss://`.

### `ws.listenAsync(handle: int) → bool`

**Event-driven mode (B.1+)** — non-blocking, event loop internal di main thread. Skala 10.000+ concurrent di 1 thread.

```pascal
var srv := ws.serve(9001, {"onMessage": onMessage});
ws.listenAsync(srv);
println("event-driven");
while true do sleep(1000);   // main loop tick event
```

**Batasan:** `wss://` (TLS) tidak didukung di event mode. Pakai `ws.listenThreads` untuk TLS.

**Return:** `True` jika berhasil register ke event loop.

**Stop:** `ws.stop(handle)` untuk remove dari event loop.

**Catatan penting:** Setelah `ws.listenAsync`, thread utama **harus tetap tick** event loop. Pattern standar: `while true do sleep(1000);`. `sleep()` otomatis tick event loop.

### `ws.listenThreads(handle: int) → bool`

**Legacy thread-per-connection** — kompatibel dengan A.2.1, mendukung `wss://`.

```pascal
ws.listenThreads(srv);   // spawn listener thread internal
```

**Kapan pakai:**
- Butuh `wss://` (TLS) — event mode belum support (B.2 nanti)
- Butuh isolasi penuh per connection
- Concurrent < 500 (thread overhead signifikan di atas itu)

**Return:** `True` jika listener thread berhasil di-spawn.

**Perbandingan performa:**

| Concurrent | Event mode | Thread mode |
|------------|------------|-------------|
| 10 | ✓ | ✓ |
| 100 | ✓ | ✓ |
| 500 | ✓ (1 thread) | ⚠ (~4 GB RAM) |
| 1000+ | ✓ | ✗ |

### `ws.listen(handle: int) → int`

**Blocking accept loop** — klasik. Cocok untuk script simple tanpa event loop.

Setiap connection dijalankan di worker thread dedicated.

**Cara pakai:** jalankan di thread terpisah via `thread()`:

```pascal
function serverThread() begin
  ws.listen(SRV);
end;

begin
  var SRV := ws.serve(9001, {...});
  thread(serverThread);
  // main thread lanjut
end.
```

**Return:** jumlah connection yang diterima selama lifetime server.

**Stop:** `ws.listen` keluar dalam ≤ 500ms setelah `ws.stop(handle)` dipanggil.

### `ws.broadcast(handle: int, msg) → int`

Kirim `msg` (dikonversi ke string jika bukan string) ke **semua** client yang sedang connect ke server `handle`.

**Return:** jumlah client yang berhasil dikirimi.

**Thread-safe:** internal lock per-connection menjamin frame tidak interleave saat broadcast bertemu worker send.

### `ws.stop(handle: int) → bool`

Graceful shutdown. Listen loop keluar pada iterasi berikutnya (≤ 500ms). Semua client aktif menerima close frame `1001 Going Away`.

**Return:** `True` jika handle valid.

### `ws.clients(handle: int) → array`

Return array `ConnID` (string) yang sedang aktif di server `handle`.

**ConnID format:**
- Thread mode: `ws-NNNNNNNN`
- Event mode: `nbs-NNN`

Connection Object (conn)

Object yang di-pass ke callback. Bertipe dict dengan field berikut.

Field (read-only):

Field Tipe Keterangan
conn["id"] string ConnID unik (format ws-NNNNNNNN)
conn["path"] string Request path (/chat, /ws, ...)
conn["query"] string Query string
conn["version"] string HTTP version (HTTP/1.1)
conn["peerIP"] string Alamat IP client
conn["peerPort"] number Port client
conn["protocol"] string Subprotocol yang dinegosiasikan (biasanya '')
conn["headers"] dict Semua request header

Method:

Method Return Keterangan

| `conn.send(msg)` | bool | Kirim text frame. `msg` dikonversi ke string |
| `conn.sendBytes(data)` | bool | Kirim binary frame. `data` harus string (raw byte) |
| `conn.close(code)` | bool | Kirim close frame dengan code (default `1000`) |

Contoh:

```pascal
function onMessage(conn, msg) begin
  if msg == "/whoami" then
    conn.send("id=" + conn["id"] + " peer=" + conn["peerIP"]);
    return;
  end;
  if msg == "/quit" then
    conn.close(1000);
    return;
  end;
  ws.broadcast(SRV, conn["id"] + ": " + msg);
end;
```

Close Codes (RFC 6455 §7.4)

Code Nama Keterangan
1000 Normal Close normal
1001 Going Away Server/client shutdown
1002 Protocol Error Frame malformed
1003 Unsupported Data Frame type tidak didukung
1007 Invalid Payload Payload text bukan UTF-8 valid
1008 Policy Violation Message melanggar policy
1009 Too Large Frame > maxPayload
1011 Internal Error Server error

Code 1005 dan 1006 reserved — tidak boleh dikirim di wire (hanya muncul secara implisit).

Catatan Implementasi

· Threading model: setiap connection dijalankan di worker thread dedicated. Bukan worker pool — karena WS connection long-lived, akan memblok pool jika pakai 8-slot pool.
· Fragmentasi: frame FIN=0 diikuti frame wsContinuation diakumulasi sampai FIN=1. Batas akumulasi = maxPayload.
· Ping/pong: server otomatis balas pong saat terima ping. Auto-ping dari server datang setiap pingInterval ms.
· Race condition pada variabel bersama: callback dijalankan di worker thread yang berbeda. Untuk counter bersama, gunakan lock block:
  ```pascal
  function onMessage(conn, msg) begin
    lock begin
      COUNTER := COUNTER + 1;
    end;
    conn.send("msg #" + str(COUNTER));
  end;
  ```
· Broadcast thread-safe: internal SendLock per connection mencegah frame interleave.
· Bukan scope v1: permessage-deflate compression, subprotocol negotiation response, HTTP/2 WebSocket.

Contoh Lengkap

Lihat examples/ws_echo.pas dan examples/ws_chat.pas.

---

### Request dict

> ⚠️ **Penting**: `method`, `in`, `class`, `record`, dan keyword lain tidak
> bisa diakses via dot notation. Pakai **indexing** atau ekstrak ke lokal.

```pascal
// ✅ Pakai indexing untuk keyword
var method := req["method"];
var path := req["path"];
var body := req["body"];

// ✅ Atau dot notation untuk non-keyword
println(req.status);
println(req.path);
// println(req.method);  // ✗ ERROR — 'method' adalah keyword
```

**Isi dict**:

```pascal
{
  "method": "GET",              // keyword — pakai req["method"]
  "path": "/api/users",         // non-keyword — req.path OK
  "query": "?page=1",           // non-keyword
  "version": "HTTP/1.1",
  "headers": {...},
  "cookies": {...},
  "body": "..."
}
```

**Daftar keyword yang tidak bisa diakses via dot**:
`if`, `then`, `else`, `case`, `of`, `while`, `do`, `begin`, `end`,
`var`, `const`, `function`, `method`, `class`, `record`, `new`, `and`,
`or`, `for`, `to`, `in`, `return`, `break`, `continue`, `not`, `mod`,
`try`, `catch`, `finally`, `true`, `false`, `null`, `nil`, `import`,
`repeat`, `until`, `lambda`, `lock`, `yield`, `defer`, `downto`,
`step`, `throw`.

### Response dict

```pascal
{
  "status": 200,                         // default 200
  "headers": {"Content-Type": "..."},   // auto Content-Type kalau kosong
  "body": "response body",
  "cookies": {"session": "abc123"},      // auto Set-Cookie; Path=/
  "file": "path/to/file.html"            // static file (opsional, override body)
}
```

---

## Network

### `net.listen(host, port) → socketHandle`

Bind dan listen TCP.

```pascal
var srv := net.listen("0.0.0.0", 8080);
```

### `net.accept(serverHandle [, timeoutMs]) → clientHandle`

Accept connection. Return -1 kalau timeout.

### `net.connect(host, port [, timeoutMs]) → socketHandle`

Connect TCP. DNS resolution via **pure Pascal resolver** (bypass libc
kalau libc gagal).

```pascal
var sock := net.connect("example.com", 443);
```

### `net.send(sock, data) → int`

Kirim raw bytes.

### `net.recv(sock [, maxBytes]) → string`

Terima raw bytes.

### `net.recvTimeout(sock, maxBytes, timeoutMs) → string`

Terima dengan timeout.

### `net.close(sock) / net.isOpen(sock)`

Lifecycle.

### `net.peerIP(sock) / net.peerPort(sock)`

Peer info.

### `net.setNoDelay(sock, enabled)`

Set `TCP_NODELAY`.

### `net.diagnoseDNS(host) → string`

Diagnostik resolver.

---

## TLS

### `tls.init() / tls.shutdown() / tls.isLoaded() / tls.version()`

Lifecycle manual. Biasanya otomatis saat `http.get` dipanggil.

```pascal
if not tls.isLoaded() then
  tls.init();
println("OpenSSL ", tls.version());
```

**Default verify**: aktif. Chain + hostname verify via `SSL_set1_host`.
Override via `PASCAK_TLS_NO_VERIFY=1` + flag `--dev` (lihat
"Env Variable Override" untuk detail security).


**Shutdown safety**: library tidak di-unload saat exit (mencegah crash
kalau ada koneksi aktif).

---

## SQLite

### `sqliteConnect(path) → handle`

Buka atau buat database SQLite.

```pascal
var db := sqliteConnect("example.db");
```

**Path resolution**: sandbox-relative. `libsqlite3.so` auto-configured
dari `$PREFIX/lib/` di Termux.

### `sqliteExec(handle, sql [, params]) → bool`

Eksekusi SQL (INSERT, UPDATE, DELETE, CREATE).

```pascal
sqliteExec(db, "CREATE TABLE IF NOT EXISTS users (id INTEGER PRIMARY KEY, name TEXT)");
sqliteExec(db, "INSERT INTO users (name) VALUES (?)", ["Alice"]);
```

**Param binding**: positional `?`, array `[...]`.

### `sqliteQuery(handle, sql [, params]) → array of dict`

SELECT query.

```pascal
var rows := sqliteQuery(db, "SELECT id, name FROM users WHERE id > ?", [0]);
var i := 0;
while i < len(rows) do
begin
  var r := rows[i];
  println(r.id, ": ", r.name);
  i := i + 1;
end;
```

**Batas**: 10.000 baris per query.

### `sqliteClose(handle) → bool`

Tutup koneksi.

**Contoh lengkap**:

```pascal
var db := sqliteConnect("example.db");

sqliteExec(db, "CREATE TABLE IF NOT EXISTS users (" +
               "id INTEGER PRIMARY KEY AUTOINCREMENT, " +
               "name TEXT NOT NULL, email TEXT UNIQUE, age INTEGER)");

sqliteExec(db, "DELETE FROM users");
sqliteExec(db, "INSERT INTO users (name, email, age) VALUES (?, ?, ?)",
           ["Alice", "alice@example.com", 30]);

var rows := sqliteQuery(db, "SELECT * FROM users");
println("Total: ", len(rows));

sqliteClose(db);
```

---

## Crypto

Kriptografi modern, zero external dependency. Semua di `pascak_crypto.pas`.

### Hashing

```pascal
crypto.sha256(data) → string       // 64 char hex, lowercase
crypto.sha256Bytes(data) → string  // 32 byte raw
crypto.sha1Hex(data) → string      // 40 char hex (legacy, prefer SHA-256)
crypto.hmacSha256(key, msg) → string  // 64 char hex
```

**Contoh:**
```pascal
var h := crypto.sha256("hello");
// "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"

var mac := crypto.hmacSha256("secret-key", "message");
```

### AES (Symmetric Encryption)

```pascal
crypto.aesEncrypt(data, key, [iv], [mode]) → string
crypto.aesDecrypt(ciphertext, key, [iv], [mode]) → string
```

- **Key:** 16 byte (AES-128), 24 byte (AES-192), atau 32 byte (AES-256)
- **IV:** 16 byte (wajib untuk CBC, diabaikan untuk ECB)
- **Mode:** `"cbc"` (default, aman) atau `"ecb"` (jangan pakai untuk data baru)
- **Padding:** PKCS#7 otomatis

**Contoh AES-256-CBC:**
```pascal
var key := "0123456789abcdef0123456789abcdef";  // 32 byte
var iv := "abcdef0123456789";                    // 16 byte

var ct := crypto.aesEncrypt("Rahasia!", key, iv, "cbc");
var pt := crypto.aesDecrypt(ct, key, iv, "cbc");
// pt = "Rahasia!"
```

**Catatan:** ECB **tidak butuh IV**, tapi **tidak recommended** — pola berulang plaintext tetap berulang di ciphertext. Pakai CBC atau CTR (belum ada, backlog).

### PBKDF2 — Password Hashing

```pascal
crypto.pbkdf2Sha256(password, salt, iterations, keyLen) → string
```

- **iterations:** minimal 1000, recommended 100.000+ untuk password storage
- **keyLen:** panjang output (byte)
- Return: raw bytes (bukan hex)

**Contoh:**
```pascal
// Password storage
var salt := crypto.randomBytes(16);
var hash := crypto.pbkdf2Sha256("user-password", salt, 100000, 32);
// Simpan: { salt: base64Encode(salt), hash: base64Encode(hash) }

// Verify
var derived := crypto.pbkdf2Sha256("user-password", stored_salt, 100000, 32);
if crypto.constantTimeEqual(derived, stored_hash) then
  println("OK")
else
  println("Invalid");
```

**RFC 7914 §11 test vector:**
```pascal
var v := crypto.pbkdf2Sha256("password", "salt", 1, 32);
// hex: 120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b
```

### Secure Random

```pascal
crypto.randomBytes(n) → string     // n byte raw
crypto.randomHex(n) → string       // 2n char hex
```

**Source:** `/dev/urandom` (Unix) atau `CryptGenRandom` (Windows).

**Contoh:**
```pascal
var token := crypto.randomHex(32);   // 64 char hex, untuk session token
var salt := crypto.randomBytes(16);  // 16 byte raw, untuk PBKDF2
```

### Utilities

```pascal
crypto.constantTimeEqual(a, b) → bool   // timing-safe compare
crypto.hexToBytes(hex) → string          // "deadbeef" → 4 raw bytes
```

`constantTimeEqual` — pakai untuk bandingkan password hash / MAC. Mencegah timing attack yang bisa bocorkan informasi via perbedaan waktu compare.

### Base64

```pascal
crypto.base64Encode(data) → string
crypto.base64Decode(s) → string
```

Standard RFC 4648. Padding `=` included.

### Best Practices

| Skenario | Algoritma |
|----------|-----------|
| Password hash | **PBKDF2-SHA256**, iter ≥ 100.000 |
| Session token | `randomHex(32)` |
| Symmetric encryption | **AES-256-CBC**, random IV per message |
| Data integrity | `hmacSha256` |
| Hash umum | **SHA-256** (jangan MD5, SHA-1) |
| Legacy compat | SHA-1 (read-only) |

**Anti-pattern:**
```pascal
// JANGAN — password tanpa salt
var h := crypto.sha256(password);

// JANGAN — ECB untuk data multi-block
var ct := crypto.aesEncrypt(data, key, "", "ecb");

// JANGAN — IV reuse antar message
var ct1 := crypto.aesEncrypt(msg1, key, iv, "cbc");
var ct2 := crypto.aesEncrypt(msg2, key, iv, "cbc");
```

**Pattern yang aman:**
```pascal
// Password storage
var salt := crypto.randomBytes(16);
var hash := crypto.pbkdf2Sha256(password, salt, 100000, 32);

// Per-message encryption dengan IV acak
var iv := crypto.randomBytes(16);
var ct := crypto.aesEncrypt(msg, key, iv, "cbc");
// Simpan (iv || ct) atau (iv, ct) terpisah
```

## Filesystem

Filesystem operations — sinkron (`fs.*`) dan asinkron (`fs.*Async`).
Semua operasi melewati **sandbox**: path absolut & `..` ditolak kecuali
relative terhadap direktori script.

### Sandbox Rules

| Path pattern | Behaviour |
|---|---|
| `"data.txt"` | Relative ke direktori script — ✅ OK |
| `"sub/file.txt"` | Relative — ✅ OK |
| `"../secret"` | Escape sandbox — ❌ Raised |
| `"/etc/passwd"` | Absolute — ❌ Raised |
| `"file\x00.txt"` | Control chars stripped | 
| `$HOME/...` | Diizinkan HANYA untuk cert path di `serveTLS` |

Symlink di dalam sandbox yang menunjuk ke luar → **di-resolve via
`realpath()`** dulu, baru boundary check. Jadi `ln -s /etc escape`
akan ditolak saat diakses via `fs.read(escape/passwd)`.

---

### Sync API

#### `fs.glob(baseDir, pattern) → array`

Cari file dengan glob pattern.

**Pattern wildcards:**

| Wildcard | Match |
|---|---|
| `*` | Semua karakter kecuali `/` |
| `?` | Satu karakter kecuali `/` |
| `**` | Semua karakter termasuk `/` (recursive) |

```pascal
// Semua .pas di direktori script
var pasc := fs.glob(".", "*.pas");
println(pasc);   // ["main.pas", "utils.pas", ...]

// Recursive semua .txt di subfolder
var txts := fs.glob(".", "**/*.txt");

// Satu karakter wildcard
var single := fs.glob(".", "file?.txt");   // file1.txt, fileA.txt, ...
```

Return: array string relative ke baseDir. Empty array kalau baseDir tidak ada.

Catatan: . dan .. di-skip otomatis. Direktori di-include kalau pattern match (bukan cuma file).

---

fs.walkDir(path, [maxDepth]) → array

Recursive listing — semua entry (file + directory).

Parameter:

· path (string) — direktori root
· maxDepth (int, opsional) — 0 = unlimited, N = stop di kedalaman N

```pascal
// Semua file + dir recursive
var all := fs.walkDir(".", 0);

// Cuma 2 level pertama
var shallow := fs.walkDir(".", 2);

for entry in all do
  println(entry);
```

Return: array path relative ke path. Direktori berakhiran / (mis. "src/", "src/sub/").

Ordering: tidak dijamin — implementasi pakai OS directory iteration order.

---

fs.stat(path) → dict | null

Metadata file/directory.

```pascal
var info := fs.stat("main.pas");
if info != null then begin
  println("size: ", info.size);           // byte
  println("mtime: ", info.mtime);         // Unix timestamp (sec)
  println("isDir: ", info.isDir);         // bool
  println("isFile: ", info.isFile);       // bool
  println("perm: ", info.permissions);    // 0..0777 (Unix-style)
end;
```

Return: dict atau null kalau tidak ada.

Permissions:

· Unix: raw st_mode & 0777 (mis. 0644 = rw-r--r--)
· Windows: 0444 untuk readonly, 0755 untuk directory, 0666 untuk file

---

fs.copy(src, dst, [recursive]) → bool

Copy file atau directory.

```pascal
// Copy file
fs.copy("input.txt", "output.txt");

// Copy directory (harus recursive=true)
fs.copy("src", "backup/src", true);
```

Parameter:

· recursive (bool, opsional) — default false. Directory copy butuh true, kalau tidak akan return false.

Return: True kalau sukses, False kalau gagal.

Behaviour: file di-copy dengan fmCreate (overwrite). Directory target dibuat otomatis.

---

fs.move(src, dst) → bool

Rename / move file atau directory.

```pascal
fs.move("old.txt", "new.txt");
fs.move("src", "src-backup");
```

Return: True kalau sukses.

Catatan: ini rename atomik (syscall rename(2)), bukan copy+delete. Cross-filesystem move akan gagal — pakai fs.copy + fs.rmDir manual.

---

fs.chmod(path, mode) → bool

Ubah permission.

```pascal
fs.chmod("script.sh", 493);   // 493 = 0755 (rwxr-xr-x)
fs.chmod("data.txt", 420);    // 420 = 0644 (rw-r--r--)
```

Parameter:

· mode (int) — permission dalam bentuk decimal dari octal Unix
  · 0644 octal = 420 decimal
  · 0755 octal = 493 decimal
  · 0600 octal = 384 decimal

Return: True kalau sukses.

Windows: hanya readonly bit yang di-honor — mode & 0x80 = 0 → readonly; selain itu writable.

Helper octal → decimal:

```pascal
// Kalau mau pakai literal octal, hitung manual:
// 0o755 = 7*64 + 5*8 + 5 = 448 + 40 + 5 = 493
var mode755 := 493;
```

---

fs.tempFile([prefix]) → string

Buat file temporary yang kosong dan aman (unique nama).

```pascal
var path := fs.tempFile("upload_");
println(path);   // ".pascak_tmp/upload_A3F2B1C8_00000001.tmp"

fileWrite(path, "data sementara");
// ... gunakan ...
fileDelete(path);
```

Parameter:

· prefix (string, opsional) — default "pascak_"

Return: path relative ke direktori script. File sudah dibuat (empty) dengan fmCreate or fmShareExclusive.

Lokasi: <scriptDir>/.pascak_tmp/. Folder dibuat otomatis.

Unique: gabungan tick count + counter atomik. Retry sampai 100× kalau collision (sangat jarang).

---

fs.rmDir(path, [recursive]) → bool

Hapus file atau directory.

```pascal
// Hapus file
fs.rmDir("temp.txt");

// Hapus directory kosong
fs.rmDir("empty-folder");

// Hapus directory recursive
fs.rmDir("old-project", true);
```

Parameter:

· recursive (bool, opsional) — default false. Directory non-kosong butuh true.

Return: True kalau sukses.

Naming note: meski namanya rmDir, fungsi ini juga menghapus file. Kalau path adalah file → DeleteFile. Kalau directory → RemoveDir (atau recursive kalau flag true).

Retry logic: file yang di-lock (mobile filesystem) akan di-retry 3× dengan delay 20ms.

---

Async API (Fase 1.3)

Non-blocking filesystem I/O. Untuk file besar atau batch operation
yang tidak boleh block event loop.

Kapan pakai async FS:

· Baca/tulis file > 1 MB
· Batch > 10 file
· Di dalam WS/HTTP callback (jangan block event loop)

Kapan pakai sync FS:

· Script top-level, one-shot
· File kecil (< 100 KB)
· Setup/init code

---

fs.readAsync(path, [callback]) → taskID

Baca file di worker thread, return immediately.

```pascal
// Pattern callback — auto-cleanup
fs.readAsync("big.log", lambda r : begin
  if r["ok"] then
    println("read ", r["bytesRead"], " bytes")
  else
    println("error: ", r["error"]);
end);

// Script lanjut — callback fire saat selesai
println("reading in background...");
```

Parameter:

· path (string) — path sandbox-relative
· callback (function, opsional) — dipanggil di main event loop saat selesai

Return: taskID (integer ≥ 1).

Callback argument (dict):

Field Tipe Kapan ada
ok bool Selalu
data string Kalau ok = true
bytesRead int Kalau ok = true
path string Kalau ok = true
error string Kalau ok = false

Batasan: max 64 MB per file. File lebih besar → {ok: false, error: "file too large..."}.

Tanpa callback — pakai poll pattern:

```pascal
var t := fs.readAsync("data.txt");
while true do begin
  var r := fs.pollAsync(t);
  if r != null then begin
    if r["ok"] then println(r["data"]);
    fs.freeAsync(t);   // ← WAJIB
    break;
  end;
  sleep(10);
end;
```

---

fs.writeAsync(path, data, [callback]) → taskID

Tulis file (overwrite).

```pascal
fs.writeAsync("out.txt", "Hello, world!", lambda r : begin
  if r["ok"] then
    println("wrote ", r["bytesWritten"], " bytes")
  else
    println("error: ", r["error"]);
end);
```

Callback fields: {ok, bytesWritten, path} atau {ok: false, error}.

File mode: fmCreate or fmShareDenyWrite — file lama di-truncate.

---

fs.appendAsync(path, data, [callback]) → taskID

Append ke file (buat kalau belum ada).

```pascal
fs.appendAsync("log.txt", "[INFO] started\n");
fs.appendAsync("log.txt", "[INFO] ready\n");
```

Callback fields: {ok, bytesWritten, path} atau {ok: false, error}.

Fallback: kalau file belum ada → open dengan fmCreate.

---

fs.pollAsync(taskID) → dict | null

Non-blocking poll hasil task.

```pascal
var r := fs.pollAsync(t);
if r == null then
  println("masih jalan...")
else
  println("selesai: ", r["ok"]);
```

Return:

· dict — task selesai
· null — masih pending/running, atau taskID invalid

Catatan: pollAsync tidak auto-free task. Panggil fs.freeAsync(t) setelah selesai (kalau task dibuat tanpa callback).

---

fs.waitAsync(taskID, [timeoutMs]) → dict | null

Blocking wait — untuk script top-level.

```pascal
var t := fs.readAsync("config.json");
var r := fs.waitAsync(t, 5000);   // timeout 5 detik

if r != null then
  println(r["data"])
else
  println("timeout");

fs.freeAsync(t);
```

Return:

· dict — selesai dalam timeout
· null — timeout, atau taskID invalid

Timeout = 0 → tunggu tanpa batas.

⚠️ Jangan pakai di callback — blocking akan freeze event loop.

---

fs.cancelAsync(taskID) → bool

Batalkan task yang masih PENDING (belum mulai).

```pascal
var t := fs.readAsync("huge.dat");
if fs.cancelAsync(t) then
  println("cancelled")
else
  println("sudah jalan, tidak bisa cancel");
```

Return: True kalau berhasil cancel, False kalau task sudah running/done.

Batasan: task yang sudah RUNNING (worker sudah mulai baca/tulis) tidak bisa di-cancel. Cancel hanya bekerja pada window kecil antara Enqueue dan worker start.

---

fs.freeAsync(taskID) → bool

Free task dari registry. Wajib untuk task tanpa callback.

```pascal
var t := fs.readAsync("file.txt");   // tanpa callback
var r := fs.waitAsync(t);
fs.freeAsync(t);   // ← cleanup
```

Return: True kalau task valid, False kalau sudah free.

Auto-free: task dengan callback auto-free setelah callback dipanggil. Task tanpa callback → manual free.

---

Contoh Lengkap — Batch Read

Baca 20 file log paralel, agregasi total baris.

```pascal
var totalLines := 0;
var done := 0;
var files := fs.glob("./logs", "*.log");

function onResult(r) begin
  lock begin
    done := done + 1;
  end;

  if r["ok"] then begin
    var lines := len(r["data"].split("\n"));
    lock begin
      totalLines := totalLines + lines;
    end;
    println("[", done, "/", len(files), "] ", r["path"], ": ", lines, " lines");
  end else
    println("[", done, "/", len(files), "] FAIL: ", r["error"]);
end;

begin
  println("reading ", len(files), " files...");

  for f in files do
    fs.readAsync("./logs/" + f, onResult);

  // Event loop tunggu semua callback
  while done < len(files) do
    sleep(100);

  println("Total: ", totalLines, " lines");
end.
```

Contoh Lengkap — Copy Recursive Async

```pascal
var queue := fs.glob("./src", "**/*.txt");
var pending := len(queue);
var copied := 0;

function onWrite(r) begin
  lock begin
    pending := pending - 1;
    if r["ok"] then copied := copied + 1;
  end;
end;

begin
  for src in queue do begin
    var data := fileRead("./src/" + src);      // sync read — atau readAsync
    var dst := "./backup/" + src;
    makeDir(extractDirName(dst));               // helper manual
    fs.writeAsync(dst, data, onWrite);
  end;

  while pending > 0 do sleep(50);
  println("Copied ", copied, "/", len(queue), " files");
end.
```

Lihat juga: examples/fs_async_demo.pas untuk demo lengkap.

---
## Coroutine Scheduler
```

## Parser Tips

### `if...then...else` adalah STATEMENT, bukan expression

```pascal
// ❌ Tidak valid di lambda expression body:
lambda a, b : if a < b then -1 else 1

// ✅ Pakai ternary:
lambda a, b : a < b ? -1 : 1

// ✅ Atau pakai named function:
function cmp(a, b) begin
  if a < b then return -1;
  return 1
end;
```

### Tidak ada `elif`

Gunakan sequential `if`:

```pascal
// ❌ elif bukan keyword
if x = 1 then ... elif x = 2 then ...

// ✅ Sequential if
if x = 1 then begin ... end;
if x = 2 then begin ... end;
```

### Tidak ada `var` inline di tengah blok

Deklarasi di awal function:

```pascal
// ❌ Tidak valid
if x > 0 then var y := 2;

// ✅
var y := 0;
if x > 0 then y := 2;
```

### F-String

```pascal
var name := "Pascak";
var version := 3;
println(f"Hello {name} v{version}!");
println(f"2 + 2 = {2 + 2}");
```

### Dictionary Access

Dot notation tidak bisa dipakai untuk keyword. Pakai indexing:

```pascal
var d := {"method": "GET", "path": "/"};
var m := d["method"];       // ✅
var p := d.path;             // ✅ (non-keyword)
```

### Named Function vs Lambda

Keduanya bisa dipakai di `dll.callback`:

```pascal
function cmpAsc(a, b) begin
  if a < b then return -1;
  return 1
end;

// Named
var cb1 := dll.callback("ii->i", cmpAsc);

// Lambda
var cb2 := dll.callback("ii->i", lambda a, b : a < b ? -1 : 1);
```

---

## Sandbox

Script dibatasi:

- File I/O hanya di direktori script dan subdirektori
- Tidak bisa akses path absolut (kecuali whitelist sistem lib untuk `dll.load`)
- Tidak bisa akses `/etc/passwd`, `/proc/self/environ`, dll
- FFI quota: max 10 library loaded
- Memory quota: default 256 MB


**Bypass** (development — membutuhkan `--dev`):

```bash
PASCAK_TLS_NO_VERIFY=1 ./pascak --dev script.pas     # skip TLS cert verify
``````
⚠️ Sejak Fase 1.4, bypass env hanya berlaku dengan --dev. Ini
mencegah production deployment tidak sengaja mem-bypass security.

---



## Package Manager

Sistem package manager untuk modul ecosystem. Mirip `npm` / `cargo` / `pub` — tapi sederhana.

### Manifest — `pascak.json`

Setiap project/module punya manifest di root:

```json
{
  "name": "@myorg/utils",
  "version": "1.2.3",
  "description": "Utility functions",
  "main": "src/index.pas",
  "author": "you@example.com",
  "license": "MIT",
  "dependencies": {
    "@pascak/crypto": "^2.0.0",
    "@pascak/http": "~1.5.0"
  },
  "scripts": {
    "test": "pascak test.pas"
  }
}
```

**Field wajib:** `name`, `version`.
**Field opsional:** `main` (default `main.pas`), `description`, `author`, `license`, `dependencies`, `scripts`.

**Nama package** — lowercase, alfanumerik, `-`, `_`. Optional scope `@scope/name`.

### Version Constraint — Semver

| Constraint | Arti |
|------------|------|
| `1.2.3` | Exact |
| `^1.2.3` | `>=1.2.3 <2.0.0` (compatible) |
| `~1.2.3` | `>=1.2.3 <1.3.0` (patch only) |
| `>=1.2.0` | Range |
| `<=2.0.0` | Range |
| `1.x` | `>=1.0.0 <2.0.0` |
| `1.2.x` | `>=1.2.0 <1.3.0` |
| `*` | Any |
| `^1.0.0 \|\| >=2.0.0` | OR |

### Registry Structure (Local)

```
<registry>/
  @scope/name/
    1.0.0/
      pascak.json
      main.pas
    1.5.0/
      pascak.json
  simple-pkg/
    1.0.0/
      pascak.json
```

Registry bisa folder lokal, atau HTTP server (implementasi v2). Untuk sekarang, folder lokal.

### Lockfile — `pascak.lock`

Auto-generated saat `pkg.install`. Berisi resolusi pinned:

```json
{
  "lockfileVersion": 1,
  "resolved": {
    "@a/lib": {
      "version": "1.0.0",
      "resolved": "file:///path/to/registry/@a/lib/1.0.0",
      "integrity": "sha256-..."
    }
  }
}
```

**Commit lockfile ke VCS** untuk reproducibility.

### Native API

#### `pkg.resolve(registryDir, manifestPath) → dict`

Resolve dependency graph tanpa install. Return:
```pascal
{
  "ok": true,
  "resolved": {
    "@a/lib": {
      "version": "1.0.0",
      "url": "file://...",
      "integrity": "sha256-..."
    }
  }
}
```

#### `pkg.install([registryDir], [projectDir]) → dict`

Resolve + copy packages ke `projectDir/packages/` + write `pascak.lock`.

Default `projectDir` = cwd. Default `registryDir` = `./registry/` (relatif).

Return:
```pascal
{"ok": true, "installed": ["@a/lib@1.0.0", ...], "projectDir": "..."}
```

#### `pkg.list([projectDir]) → dict`

Read `pascak.lock`, return list installed packages:

```pascal
{"ok": true, "packages": ["@a/lib@1.0.0"], "projectDir": "..."}
```

### Import Resolution

Setelah `pkg.install`, script bisa `import("@scope/name")`:

```pascal
begin
  var lib := import("@a/lib");
  println(lib["version"]);
  println(lib["greet"]("World"));
end.
```

Engine resolve `@scope/name`:
1. Cari project root (walk up dari file caller, cari `pascak.json` + `packages/`)
2. Load `packages/@scope/name/pascak.json`
3. Resolve ke `main` field (default `main.pas`)
4. Import sebagai module normal

**Subpath:** `import("@a/lib/utils/format")` → load `packages/@a/lib/utils/format.pas`.

### Workflow

```bash
# 1. Inisialisasi project
mkdir my-app && cd my-app
cat > pascak.json << 'EOF'
{"name":"my-app","version":"1.0.0","dependencies":{"@a/lib":"^1.0.0"}}
EOF

# 2. Install (via script)
cat > install.pas << 'EOF'
begin
  var r := pkg.install("/path/to/registry");
  if r["ok"] then
    println("installed: ", jsonStringify(r["installed"]))
  else
    println("error: ", r["error"]);
end.
EOF

PASCAK_EXEC_POLICY=allow-all ~/pascak_noASTnet --dev install.pas

# 3. Gunakan
cat > main.pas << 'EOF'
begin
  var lib := import("@a/lib");
  println(lib["greet"]("World"));
end.
EOF

PASCAK_EXEC_POLICY=allow-all ~/pascak_noASTnet --dev main.pas
```

### Design Notes

- **Local-first**: v1 fokus folder lokal. HTTP registry v2.
- **Semver**: cukup untuk ecosystem kecil. DFS+backtracking, bukan SAT solver.
- **Full trust**: package code punya akses penuh engine API. Sandbox v2.
- **Lockfile integrity**: SHA-256 dari manifest file (v2: Merkle tree folder).

---

## Security — Exec Policy

`sys.exec` di-deny by default. Semua subprocess harus lulus **exec policy** sebelum spawn.

### Konsep

| Layer | Fungsi |
|-------|--------|
| **Whitelist** | Binary harus terdaftar |
| **Path resolve** | Search di PATH aman, bukan PATH attacker |
| **rlimit** | CPU / mem / fd / subprocess bounded |
| **Env sanitize** | Strip `LD_PRELOAD`, `PYTHONPATH`, dll |
| **Concurrent limit** | Max subprocess paralel |
| **Output limit** | Max byte stdout+stderr |
| **Force kill** | SIGTERM → tunggu 1s → SIGKILL |
| **Audit log** | Opsional — log tiap exec |
| **Shutdown cleanup** | SIGKILL semua child saat engine exit |

### Default Policy

Deny-all. Tidak ada satu binary pun yang boleh exec sampai host / script mengizinkan.

```
mode               = "none"
binaries           = []
maxConcurrent      = 8
maxOutputBytes     = 10 MB
cpuSec             = 60
memoryBytes        = 512 MB
fileSizeBytes      = 50 MB
openFiles          = 256
subprocesses       = 64
envAllow           = HOME, LANG, LC_ALL, PATH, PREFIX, TERM, TMPDIR, USER
envDeny            = LD_PRELOAD, LD_LIBRARY_PATH, LD_AUDIT,
                     PYTHONPATH, PYTHONSTARTUP,
                     NODE_OPTIONS, NODE_PATH, RUBYOPT
auditLog           = ""
```

### Host-Level API

```pascal
// Set policy
Engine.SetExecPolicy({
  "mode":           "whitelist",
  "binaries":       ["git", "ls", "python3", "pandoc"],
  "envAllow":       ["HOME", "PATH", "TMPDIR", "LANG"],
  "envSet":         {"PATH": "/usr/bin:/bin"},
  "cwd":            "/sandbox",
  "maxConcurrent":  8,
  "maxOutputBytes": 10485760,
  "limits": {
    "enabled":       true,
    "cpuSec":        30,
    "memoryBytes":   268435456,
    "fileSizeBytes": 10485760,
    "openFiles":     64,
    "subprocesses":  16
  },
  "auditLog":       "/var/log/pascak-exec.log"
});

// Setelah SetExecPolicy, script tidak bisa override
Engine.LockExecPolicy;
```

```pascal
// Set policy dari JSON
Engine.SetExecPolicyFromJson(
  '{"mode": "whitelist", "binaries": ["git"]}');
```

**`Engine.SetExecPolicy` otomatis set `ExecScriptPolicyLocked`.** Kalau script memanggil `sys.execPolicy`, akan raise error "host telah mengunci policy".

### Script-Level API

Untuk dev/test. Hanya bekerja kalau host belum panggil `LockExecPolicy`.

```pascal
// Convenience: mode=whitelist + daftar binary
sys.execWhitelist(["python3", "git"]);

// Dev only — disables policy. Warning ke stderr.
sys.execAllowAll();

// Full config (dict — sama format dengan SetExecPolicy)
sys.execPolicy({
  "mode":     "whitelist",
  "binaries": ["python3"]
});

// Query policy aktif
var info := sys.execInfo();
// info = {
//   mode: "whitelist",
//   binaries: [...],
//   activeProcesses: N,
//   maxConcurrent: N,
//   maxOutputBytes: N,
//   auditLog: ""
// }
```

### `sys.exec` Behavior

**Binary di-whitelist:**
```pascal
var r := sys.exec("echo", ["hello"]);
// r = { exitCode: 0, stdout: "hello\n", stderr: "", denied: false }
```

**Binary di-deny:**
```pascal
var r := sys.exec("cat", ["/etc/passwd"]);
// r = {
//   exitCode: -1,
//   stdout: "",
//   stderr: "",
//   denied: true,
//   error: "exec denied: binary \"cat\" tidak ada di whitelist"
// }
```

`sys.exec` **tidak raise** saat policy denial — return error dict. Script harus cek `r["denied"]`.

**Kalau binary not found, fork fail, timeout, dll** → tetap raise (bukan policy issue).


### `sys.execAsync(cmd, args, [callback], [timeoutMs]) → taskID`

Non-blocking exec. Spawn subprocess di worker thread, return **immediately** dengan taskID (integer ≥ 1).

Callback (opsional) dipanggil dari **main event loop thread** saat subprocess selesai — aman untuk akses TValue.

**Parameter:**
- `cmd` (string) — binary name
- `args` (array) — argumen
- `callback` (function, opsional) — dipanggil dengan result dict saat selesai
- `timeoutMs` (int, opsional) — timeout dalam ms. `0` = tanpa batas

**Return:** taskID integer.

```markdown
**Error contract:**

Callback menerima dict dengan field standar:

| Field | Tipe | Deskripsi |
|-------|------|-----------|
| `exitCode` | int | -1 kalau di-deny / crash, 0+ untuk exit normal |
| `stdout` | string | Output stdout (mungkin truncated kalau > maxOutputBytes) |
| `stderr` | string | Output stderr |
| `denied` | bool | true kalau exec policy menolak |
| `error` | string | Pesan error (optional) |

**Crash marker (Fase 1.5):**

Kalau worker thread crash (exception di luar subprocess normal), dict
berisi marker tambahan:

| Field | Tipe | Deskripsi |
|-------|------|-----------|
| `__worker_crash` | bool | true kalau worker crash |
| `__worker_kind` | string | Nama kelas exception (mis. `EScriptRuntimeError`) |

**Cara pakai:**

```pascal
sys.execAsync("git", ["status"], lambda r : begin
  if r.hasKey("__worker_crash") then
    println("worker crash: ", r["__worker_kind"], ": ", r["error"])
  else if r["denied"] then
    println("denied: ", r["error"])
  else
    println("exit: ", r["exitCode"]);
end);
```

Marker ini juga di-set oleh poolRun dan http.getAsync saat worker
crash.

```

---

**Mode 1 — Callback (recommended):**
```pascal
sys.execWhitelist(["git"]);

sys.execAsync("git", ["status"], lambda r : begin
  if r["denied"] then
    println("security block: ", r["error"])
  else
    println(r["stdout"]);
end);

// Script lanjut eksekusi tanpa block.
// Callback dipanggil saat subprocess selesai.
```

**Mode 2 — Poll (tanpa callback):**
```pascal
var t := sys.execAsync("git", ["status"]);

while true do begin
  var r := sys.execPoll(t);
  if r != nil then begin
    println(r["stdout"]);
    sys.execFree(t);   // WAJIB — free task
    break;
  end;
  sleep(50);
end;
```

### `sys.execPoll(taskID) → dict|null`

Polling non-blocking. Return:
- **dict** — task selesai, hasil
- **null** — task masih jalan

**Catatan:** `execPoll` **tidak** auto-free task. Script harus panggil `sys.execFree(t)` setelah selesai.

### `sys.execWait(taskID, [timeoutMs]) → dict|null`

Blocking wait. Return:
- **dict** — task selesai dalam timeout
- **null** — timeout atau taskID invalid

**Catatan:** Jangan pakai di callback yang sering — blocking. Untuk script top-level saja.

### `sys.execCancel(taskID) → bool`

Cancel pending task. Hanya bekerja kalau task masih `PENDING` (belum mulai dieksekusi).

**Return:** `True` kalau berhasil cancel, `False` kalau task sudah running/done.

### `sys.execFree(taskID) → bool`

Free task resources. **Wajib** dipanggil untuk task yang dibuat **tanpa callback**.

Task dengan callback auto-free setelah callback dipanggil.

**Return:** `True` kalau task valid, `False` kalau sudah free.

### `sys.execPending() → int`

Jumlah task aktif (pending + running). Berguna untuk backpressure.

```pascal
while sys.execPending() >= 8 do
  sleep(50);
sys.execAsync("worker", []);
```

### Kapan Pakai `execAsync` vs `exec`

| Skenario | Pakai |
|----------|-------|
| Script top-level, blocking OK | `sys.exec` |
| Event loop aktif (WS, HTTP) | **`sys.execAsync`** |
| Butuh capture output + wait | `sys.exec` |
| Fire-and-forget dengan callback | `sys.execAsync` |
| Parallel N subprocess | `sys.execAsync` × N |

**Jangan** pakai `sys.exec` di callback WS/HTTP — freeze event loop.

**Jangan** pakai `sys.execAsync` di script simple tanpa event loop — overhead thread tidak worth.

### Best Practices

```pascal
// ✅ BAIK — callback, auto-cleanup
sys.execAsync("git", ["pull"], lambda r : begin
  if r["exitCode"] != 0 then
    println("git pull failed: ", r["stderr"]);
end);

// ✅ BAIK — parallel dengan pending counter
var tasks := [];
var i := 0;
while i < 10 do begin
  push(tasks, sys.execAsync("worker", [str(i)]));
  i := i + 1;
end;
// Wait all
var j := 0;
while j < len(tasks) do begin
  sys.execWait(tasks[j], 5000);
  sys.execFree(tasks[j]);
  j := j + 1;
end;

// ❌ BURUK — poll tanpa free → memory leak
var t := sys.execAsync("echo", ["x"]);
var r := sys.execPoll(t);
println(r["stdout"]);
// lupa sys.execFree(t) — task nyangkut di registry

// ❌ BURUK — exec (blocking) di callback WS
function onMessage(conn, msg) begin
  var r := sys.exec("git", ["status"]);   // ← freeze event loop
  conn.send(r["stdout"]);
end;
```

### Lifecycle

| Event | Yang Terjadi |
|-------|--------------|
| `execAsync` dipanggil | Task dibuat, worker thread spawn, status = PENDING |
| Worker mulai | Status = RUNNING |
| Subprocess selesai | Status = DONE, ResultVal diset |
| Event loop tick | `ProcessExecCallbacks` cek task DONE dengan callback → invoke + auto-free |
| `execFree` manual | Task dihapus dari registry + di-free (untuk task tanpa callback) |
| Engine shutdown | `FreeExecTasks` cancel + free semua task |

### Thread Safety

- Task dijalankan di **worker thread** (isolated)
- Callback dijalankan di **main event loop thread** (aman TValue)
- Registry `GExecTasks` dilindungi critical section
- Result TValue di-`Clone` sebelum di-pass ke callback → ownership caller

---

### Env Sanitization

Default: 8 env var di-allow, 8 di-strip.

**Allow** (pass through parent):
```
HOME, LANG, LC_ALL, PATH, PREFIX, TERM, TMPDIR, USER
```

**Deny** (strip):
```
LD_PRELOAD, LD_LIBRARY_PATH, LD_AUDIT,
PYTHONPATH, PYTHONSTARTUP,
NODE_OPTIONS, NODE_PATH, RUBYOPT
```

`EnvDeny` **prioritas di atas** `EnvAllow` — kalau variabel ada di dua list, di-strip.

`EnvSet` **force set** di child — override inherit.


```markdown
### Env Variable Override

> ⚠️ **Sejak versi 2.4 (Fase 1.4):** env override hanya berlaku bila
> `--dev` di-pass sebagai CLI flag. Tanpa flag ini, `PASCAK_EXEC_POLICY`
> dan `PASCAK_TLS_NO_VERIFY` **diabaikan total** (production default).

**Alasan:** mencegah privilege escalation via env poisoning. Attacker
yang bisa mengontrol environment variable (mis. via systemd unit,
wrapper script, atau parent process) tidak bisa bypass exec policy
atau TLS verify tanpa juga bisa mengontrol argv proses.

**Cara pakai:**

```bash
# Development
PASCAK_EXEC_POLICY=none ./pascak --dev script.pas                     # deny all (default aman)
PASCAK_EXEC_POLICY=allow-all ./pascak --dev script.pas                # dev mode
PASCAK_EXEC_POLICY=whitelist:python3,git,ls ./pascak --dev test.pas   # whitelist
PASCAK_TLS_NO_VERIFY=1 ./pascak --dev debug_https.pas                 # skip TLS verify

# Production (env diabaikan, hanya host-level API yang berlaku)
./pascak script.pas                                # policy = none
```

Untuk production/embedded: gunakan Engine.SetExecPolicy +
Engine.LockExecPolicy dari host code. Ini tidak bisa di-override
oleh script maupun env.

```

### Exit Code Propagation

`sys.exit(code)` propagate ke OS exit code:

| Statement | `$?` |
|-----------|------|
| `sys.exit(0)` | 0 |
| `sys.exit(1)` | 1 |
| `sys.exit(42)` | 42 |
| Unhandled exception | 1 |

### Audit Log Format

```
[2025-10-07 20:15:30] pid=12345 cmd=git args=status allowed=yes reason=ok
[2025-10-07 20:15:31] pid=12345 cmd=rm args=-rf / allowed=no reason=binary "rm" tidak ada di whitelist
```

Log file di-flush per entry. Error saat menulis log tidak block exec.

### Limit Detail

| Limit | Enforcement | Fallback |
|-------|-------------|----------|
| CPU time | `setrlimit(RLIMIT_CPU)` | Tidak ada |
| Memory | `setrlimit(RLIMIT_AS)` | Tidak ada |
| File size | `setrlimit(RLIMIT_FSIZE)` | Tidak ada |
| Open files | `setrlimit(RLIMIT_NOFILE)` | Tidak ada |
| Subprocesses | `setrlimit(RLIMIT_NPROC)` + parent counter | Parent counter |
| Core dump | `setrlimit(RLIMIT_CORE)` = 0 | Tidak ada |

Semua limit di-apply **di child** antara `fork()` dan `execvp()`.

### Shutdown Cleanup

Saat engine shutdown (`runScript` finally block):
1. SIGTERM ke semua subprocess aktif
2. Sleep 200ms untuk graceful exit
3. Reap + close semua slot

Script yang pakai `sys.exec` tidak akan meninggalkan orphan process.

### Best Practices

| Rule | Alasan |
|------|--------|
| Selalu `LockExecPolicy` di production | Script tidak bisa override |
| Whitelist minimum, just-in-time | Reduce attack surface |
| Set `cwd` ke sandbox | Prevent access `/` |
| Aktifkan `auditLog` | Forensik |
| Handle `r["denied"]` di script | Fail gracefully |
| Jangan interpolate user input ke `sh -c` | Classic RCE vector |

**Anti-pattern:**
```pascal
// DANGEROUS — lewat shell
sys.exec("sh", ["-c", "cat " + userInput]);

// SAFE — arg terpisah
sys.exec("cat", [userInput]);
```

### Threat Model

Dicegah:
- Arbitrary binary exec → whitelist
- Sandbox escape → path restrict
- Fork bomb → concurrent + rlimit
- Output OOM → size limit
- Env poisoning (LD_PRELOAD) → sanitize
- Orphan process → shutdown SIGKILL
- Zombie accumulation → reap on demand
- Argument injection → argv (no shell)

**Bukan scope:**
- Kernel sandbox (chroot/namespace) — butuh root
- Binary hash verification — Phase 3
- Network namespace isolation — Phase 3

### Ringkasan API

| API | Return | Keterangan |
|-----|--------|------------|
| `Engine.SetExecPolicy(dict)` | void | Host-level config |
| `Engine.SetExecPolicyFromJson(str)` | void | JSON variant |
| `Engine.LockExecPolicy` | void | Lock dari script override |
| `sys.execPolicy(dict)` | bool | Script-level (dev) |
| `sys.execWhitelist(array)` | bool | Convenience whitelist |
| `sys.execAllowAll` | bool | Disable policy (dev) |
| `sys.execInfo()` | dict | Query state |

---

## Error Handling

Semua error dilempar sebagai exception:

```pascal
try
  var lib := dll.load("nonexistent.so");
catch e do
  if typeOf(e) = "dictionary" then
  begin
    println("Error: ", e.message);
    println("Trace: ", e.trace);
  end else
    println("Error: ", e.message);
end;
```

**Error dict** (runtime error): `{message, trace}`.
**User throw** dengan dict: tetap dict aslinya.
**User throw** dengan non-dict: wrapped dalam exception object.

**HTTP async error**: return dict `{error: "..."}` — tidak raise.

### Error codes (internal, muncul di banner)

- 1–148: parser/runtime errors
- 149–160: DLL/FFI errors
- 161+: (reserved untuk T-series)

---

## Platform Notes

### Termux (Android)

- **DNS**: Pure Pascal resolver (libc `getaddrinfo` gagal karena netd socket)
- **FFI**: system library via bare name (`liblog.so`, `libsqlite3.so`)
- **TLS**: OpenSSL via `pkg install openssl`
- **CA bundle**: `/data/data/com.termux/files/usr/etc/tls/cert.pem`
- **Install dependencies**: `pkg install openssl ca-certificates libffi clang`

### Linux

- **DNS**: libc `getaddrinfo` (fallback ke pure resolver kalau gagal)
- **FFI**: semua library system via bare name
- **TLS**: OpenSSL system (`libssl.so.3` atau `.so.1.1`)
- **CA bundle**: `/etc/ssl/certs/ca-certificates.crt`

### Build

```bash
fpc -Mobjfpc -Sh pascak_noASTnet.pas
```

**Debug flags**:
- `-dHTTP_DEBUG` — log HTTP request/response
- `-dCALLBACK_DEBUG` — log callback lifecycle
- `-dTLS_DEBUG` — log SNI/handshake

---

## Referensi Test

Direktori `tests/`:

| File | Fokus |
|---|---|
| `test_phase_f1.pas` | DLL load, FFI basics, memory, string |
| `test_phase_f3a3.pas` | Callback dispatch |
| `test_phase_f3a4.pas` | Callback alias, string return |
| `test_qshort.pas` | qsort integration |
| `test_struct.pas` | Struct type system |
| `test_struct_ffi.pas` | `ffi_type` construction |
| `test_struct_call.pas` | Struct by value |
| `test_phase_t2a_2.pas` | TLS security (chain + hostname) |
| `test_async.pas` | Async HTTPS |
| `test_net_diag.pas` | TLS + DNS diagnostic |
| `test_json.pas` | JSON stringify/parse |
| `test_ws_fragmentation.pas` | WebSocket fragmentation (`Conn.FragBuf` fix) |
| `test_sandbox_symlink.pas` | Sandbox symlink escape detection (Fase 0.2) |
| `test_env_guard.pas` | Env poisoning guard `--dev` (Fase 1.4) |
| `test_tls_cache.pas` | TLS context cache per-verify-flag (Fase 0.1+0.8) |
| `test_fs_async.pas` | Async file I/O (Fase 1.3) |
| `test_engine_leak.pas` | Engine destruction robustness (Fase 1.2) |
---

## Contoh Praktis

Direktori `examples/`:

| File | Fokus |
|---|---|
| `hello_ffi.pas` | FFI dasar (strlen) |
| `parallel_fetch.pas` | 4 HTTPS request paralel via async |
| `sqlite_client.pas` | SQLite CRUD |
| `http_server.pas` | HTTP server 3 endpoint |


---

## License

(Diisi oleh pemilik proyek)