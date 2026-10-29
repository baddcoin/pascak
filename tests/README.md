# Pascak VM Test Suite

Unified test infrastructure for the Pascak VM.

## Quick start

**Termux**: repo is in `/storage/` (noexec) → invoke via `bash`:

    bash tests/run.sh lang
    bash tests/run.sh tests/lang/phase1_optchain_nullcoalesce.pas
    PASCAK_BIN=/path/to/pascak_noASTnet bash tests/run.sh lang

**Linux/macOS** (exec enabled): `./tests/run.sh lang` works.

The runner copies `pascak_noASTnet` to `$HOME/pascak_test` automatically
(because scripts run from `$HOME`, not from `/storage/`).

## Structure

    tests/
    ├── run.sh                 # Main runner
    ├── helpers.sh             # Shared helpers (copy binary to $HOME)
    ├── lang/                  # Language feature tests (16 files, PASS/FAIL)
    ├── integration/           # Integration tests (network, GUI, LSP)
    └── fixtures/              # Mock servers, certs, test data

## Language tests

All 16 language feature tests are deterministic (no network, no display) and
run with PASS/FAIL markers:

| File | Feature |
|---|---|
| phase1_optchain_nullcoalesce | ?. + ?? operators (v1.1.0) |
| phase2_enum | enum declarations (v1.1.0) |
| phase3_destructure | basic destructuring (v1.1.0) |
| v120_defaults_enumscope | destructure defaults + enum function scope (v1.2.0) |
| v121_array_rest | `var [a, ...rest] = arr` (v1.2.1) |
| v121_enum_iter | enum iteration via for/in |
| v122_nested_1level | `var {a: {b, c}} = obj` (v1.2.2) |
| v123_nested_2level | `var {a: {b: {c}}}` (v1.2.3) |
| v124_arbitrary_depth | recursive parser, 3+ level (v1.2.4) |
| v124_array_root_nested | array-root + nested obj (v1.2.4) |
| v125_object_rest | `var {a, ...rest} = obj` (v1.2.5) |
| v126_rest_in_nested | nested obj-rest (v1.2.6) |
| v127_optional_method | `obj?.method()` (v1.2.7) |
| v160_param_destructure | `function f({a,b})` (v1.6.0) |
| v161_rest_in_param | `function f({a, ...rest})` (v1.6.1) |
| v162_nullsafe_assign | `obj?.prop := value` (v1.6.2) |
| v1102_optional_index | `obj?.[idx]` read + `:= val` assign (v1.10.2) |

## Integration tests (manual)

Integration tests need external setup:

### H2 mock server tests

    cd "$HOME"
    python3 tests/fixtures/mock_server.py &
    ./tests/run.sh tests/integration/h2_auto_retry.pas
    # or use PASCAK_TLS_NO_VERIFY=1 for self-signed cert
    PASCAK_TLS_NO_VERIFY=1 ./tests/run.sh tests/integration/h2_bigbody_flowctl.pas

Mock server supports: sequential (h2_sequential), GOAWAY retry
(h2_auto_retry), big body flow control (h2_bigbody_flowctl), rate-limit
backoff (h2_ratelimit_backoff).

### Hot-reload tests

    cd "$HOME"
    ( sleep 2; touch tests/fixtures/hotreload_app.pas ) &
    ./tests/run.sh tests/integration/hotreload_basic.pas

Verifies `--watch` and `--hot` behavior (file change → exit; GUI auto-reload).

### LSP signature help

    python3 tests/integration/lsp_sighelp.py

Spawns `--lsp` server, sends signatureHelp requests, verifies responses.

### GUI2 DPI tests

    PASCAK_GUI2_SCALE=2 ./tests/run.sh tests/integration/gui2_dpi_api.pas

Need X11 (Termux:X11 or xvfb). Tests scale detection + autoScale toggle.

## Adding a new test

1. Create `tests/lang/feature_name.pas` (deterministic test with unique print marker)
2. Add marker to `markers` array in `run.sh` if new
3. Add row to table above
4. Commit

Language tests must not need network, GUI, or external process.

## Termux notes

- Binary is copied to `$HOME/pascak_test` automatically (avoids `/storage/` noexec)
- Scripts run with cwd=`$HOME` (safe sandbox)
- `PASCAK_EXEC_POLICY=allow-all` is set for test scripts

## CI integration

    # .github/workflows/test.yml
    - name: Run language tests
      run: PASCAK_BIN=./pascak_noASTnet ./tests/run.sh lang
