# Benchmark Baseline — v1.11.40 (2026-11-08)

**Device**: Termux on Android (aarch64)
**Method**: bash date +%s%N wall clock, 1 warm-up + 3 runs, median
**Binary**: pascak_noASTnet

## Zero regression across 10 versions

v1.11.40 is the 41st tag since v1.9.4 baseline. Benchmark numbers
stable vs v1.9.4 (all within noise except parser — see below).

| Benchmark | v1.9.4 | v1.11.40 | Delta |
|---|---|---|---|
| VM arith 100K | 1398 | 1385 | -0.9% |
| Function calls 100K | 1768 | 1727 | -2.3% |
| Dict set+get 200K | 3931 | 3899 | -0.8% |
| Array push+iter 20K | 319 | 323 | +1.3% |
| String concat 10K | 1089 | 1088 | -0.1% |
| JSON roundtrip 1K | 204 | 194 | -4.9% |
| Parser 52K lines | 68 (47K) | 63 | -7.4% (bigger input) |

Startup: ~45ms (unchanged).

### Parser improvement
Parser runs 7% faster despite engine.pas growing from 47K -> 52,033
lines (+10%). Net throughput improvement ~17% (per-line cost). No
conscious parser optimization applied — likely incidental from native
hot-path cleanup during GUI widget toolkit work.

## What changed since v1.9.4

10 minor versions (v1.10.x -> v1.11.39), 34 tags. Major additions:

- **GUI widget toolkit** (v1.11.14-v1.11.35): Button, Edit, Memo,
  ComboBox, ListBox, Checkbox, Radio — all production-ready
- **Language features** (v1.11.0-v1.11.13): ?., ??, enum,
  destructuring, JIT deopt fix
- **GUI assets**: hot-reload (gui.watch), static serve (gui.serveDir),
  ETag/304 caching
- **SQLite** (v1.11.38): last_insert_id, changes

See CHANGELOG.md for full history.

## Reproduce

    cp pascak_noASTnet ~/pascak_test
    chmod +x ~/pascak_test
    PASCAK_BIN=~/pascak_test bash benchmarks/run_all.sh

## Change history

- **v1.11.40 (2026-11-08)** — Zero regression at 10-version milestone.
  Parser -7.4% on 10% larger input.
- **v1.9.4 (2026-10-29)** — Fix server script hang on shutdown.
- **v1.9.3 (2026-10-29)** — Conditional WS poll (startup 68 -> 45ms).
- **v1.9.2 (2026-10-29)** — Fast CLI exit (startup 277 -> 68ms).
- **v1.9.1 (2026-10-29)** — Lazy worker pool (startup 489 -> 277ms).
- **v1.9.0 (2026-10-29)** — Remove Sleep(1500) + script fallback.
- **v1.8.0 (2026-10-29)** — Initial baseline.
