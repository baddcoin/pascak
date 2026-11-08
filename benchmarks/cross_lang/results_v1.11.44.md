# Cross-Language Benchmark — v1.11.44 (2026-11-08)

**Device**: Termux on Android (aarch64)
**Method**: `date +%s%N` wall clock, single run, includes shell spawn
**Binary**: pascak_noASTnet (3MB static)
**Others**: Python 3.14.8, Node v26.13.0, Lua 5.4.9

## Test 1: Startup Time (minimal "hello" script)

| Language | Time | vs Pascak |
|---|---|---|
| **Pascak** | **112 ms** | baseline |
| Python | 208 ms | 1.9x slower |
| Node | 1,206 ms | **10.8x slower** |
| Lua | 50 ms | 2.2x faster |

**Interpretation**: Pascak trades raw compute speed for startup latency.
Node startup (1.2s) is dominated by V8 bootstrap; Pascak (110ms) parses
bytecode and executes immediately. Lua remains fastest (no stdlib, no FFI).

## Test 2: Arithmetic Loop (1M iterations)

| Language | Time | vs Pascak |
|---|---|---|
| Pascak | 9,805 ms | baseline |
| Python 3.14 | 670 ms | 14.6x faster |
| Node 26 | 660 ms | 14.9x faster |
| Lua 5.4 | 85 ms | 115x faster |

**Interpretation**: Pascak is a tree-walking interpreter. Node (V8 JIT),
Python (3.14 loop specialization), and Lua (register VM) all use mature
optimizations. Expect ~15x slowdown vs mainstream VMs for numeric loops.

## Honest Positioning

Pascak is not designed to win numeric benchmarks. It wins when:

1. **Cold start matters** — CLIs, one-shot scripts, serverless handlers
2. **Batteries matter** — HTTP/2, WS, TLS, SQLite, crypto built-in (single 3MB binary)
3. **Native GUI matters** — 7 widgets, layouts, theming, no Electron
4. **Deployment simplicity matters** — `scp` one binary, run anywhere

## Reproduce

    PASCAK_BIN=~/pascak_test bash benchmarks/cross_lang/run.sh

## Version History

- **v1.11.44 (2026-11-08)** — First cross-language baseline (Pascak/Py/Node/Lua)
