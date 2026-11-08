# Cross-Language Benchmark — v1.11.44 (2026-11-08)

**Device**: Termux on Android (aarch64)
**Method**: `date +%s%N` wall clock, single run, includes shell spawn
**Binary**: pascak_noASTnet (3MB static)
**Others**: Python 3.14.8, Node v26.13.0, Lua 5.4.9

## Test 1: Startup Time (minimal "hello" script)

| Language | Time | vs Pascak |
|---|---|---|
| **Pascak** | **63 ms** | baseline |
| Python | 373 ms | 5.9x slower |
| Node | 1,279 ms | **20.3x slower** |
| Lua | 39 ms | 1.6x faster |

**Key insight**: Pascak cold start = 63ms. Node's V8 bootstrap = 1,279ms.
For CLIs, serverless, and one-shot scripts, this 20x latency win compounds.

## Test 2: Arithmetic Loop (1M iterations)

| Language | Time | vs Pascak |
|---|---|---|
| Pascak (`for` loop) | 3,568 ms | baseline |
| Python 3.14 | 687 ms | 5.2x faster |
| Node 26 | 657 ms | 5.4x faster |
| Lua 5.4 | 82 ms | 43.5x faster |

**Key insight**: Using idiomatic `for` loops (fused `opcForLoopCond`),
Pascak closes the gap vs JIT VMs to ~5.4x. Naive top-level `while` loops
run 2.7x slower (9.6s), so for-loop is the documented recommendation.

## Optimization Tiers (Numeric Loop, 1M iter)

| Pattern | Time | Speedup |
|---|---|---|
| Top-level `while` | 9,605 ms | 1.0x (baseline) |
| Local `while` (function) | 6,347 ms | 1.5x |
| Local `for` (idiomatic) | 3,568 ms | 2.7x |

Root cause: superinstruction emit (`TryEmit*`) only fires for local vars
in function scope. `for` loops use fused `opcForLoopCond` (increment +
condition check + jump in one opcode) regardless of scope.

## Honest Positioning

Pascak wins when:
1. **Cold start matters** — 63ms vs Node 1,279ms (20x faster)
2. **Batteries matter** — HTTP/2, WS, TLS, SQLite, crypto in 3MB binary
3. **Native GUI matters** — 7 widgets, layouts, theming
4. **Deployment simplicity** — `scp` one binary, run anywhere

Pascak loses when:
1. **Numeric loop speed matters** — 5.4x slower than Node JIT
2. **Long-running compute** — tree-walking VM has no JIT (Register VM planned)

## Future: Register VM Tier 3

Design documented in `feat/register-vm` branch. Expected 5-10x speedup
for raw compute, but requires 15-20 sessions of refactor work. Deferred
until user feedback confirms compute bottleneck is a blocker.

## Reproduce

    PASCAK_BIN=~/pascak_test bash benchmarks/cross_lang/run.sh

## Version History

- **v1.11.44 (2026-11-08)** — First cross-language baseline
- **v1.11.45 (2026-11-08)** — Idiomatic for-loop benchmark (2.7x vs top-level while)
