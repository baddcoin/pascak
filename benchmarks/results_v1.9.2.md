# Benchmark Baseline — v1.9.2 (2026-10-29)

**Device**: Termux on Android (aarch64)
**Method**: bash date +%s%N wall clock, 1 warm-up + 3 runs, median
**Binary**: pascak_noASTnet

## Cumulative (v1.8.0 -> v1.9.2)

| Benchmark | v1.8.0 | v1.9.0 | v1.9.1 | v1.9.2 | vs v1.8.0 |
|---|---|---|---|---|---|
| VM arith 100K | 3340 | 1866 | 1650 | 1431 | 2.3x |
| Function calls 100K | 3712 | 2213 | 1973 | 1772 | 2.1x |
| Dict set+get 200K | 5908 | 4456 | 4174 | 3972 | 1.5x |
| Array push+iter 20K | 2259 | 795 | 549 | 348 | 6.5x |
| String concat 10K | 3023 | 1553 | 1318 | 1098 | 2.8x |
| JSON roundtrip 1K | 2146 | 632 | 424 | 215 | 10.0x |
| Parser 47K lines | 60 | 61 | 61 | 61 | 1.0x |

Startup (empty.pas): 2000 -> 489 -> 277 -> **68** ms = 29x cumulative
Startup (no args): 2000 -> 30 -> 30 -> 30 ms (preserved)

## What changed in v1.9.2

Fast CLI exit. After `Engine.Free` completes (line 44990 in runScript),
if no servers/GUI apps are active, skip the ~200ms global cleanup:

- `RunGarbageCollection` full sweep
- `FreeBuiltInRegistries` (~25 module defs)
- `TLSShutdown`, `NetShutdown`, `ProcShutdown`
- 10+ TCriticalSection frees, DLL registry, buffer registry, struct registry

OS reclaims memory on process exit. Much faster for CLI scripts that
finished naturally.

Opt-in full cleanup: `PASCAK_FULL_CLEANUP=1`.

Timing breakdown (PASCAK_TIMING=1 hi.pas):
  globals_init:      0ms
  engine_create:     2ms
  exec:              4ms
  event_loop:       21ms  (fixed cost, possibly minimal timer resolution)
  engine_shutdown:   0ms
  engine_free:       0ms
  fast_exit:         0ms  (skipped ~202ms of global cleanup)
  ---------------
  total:            27ms internal + ~40ms OS process spawn = ~68ms wall

## Safety

Fast-exit guarded by checks:
- `PASCAK_FULL_CLEANUP=1` env opt-out
- `GHTTPServers.Count = 0`
- `GWSServers.Count = 0`
- `GGuiApps.Count = 0`

Server/GUI scripts still do full cleanup (needed for graceful WS close,
HTTP connection drain, shutdown hooks).

Shutdown hooks (`RunShutdownHooks`) already executed inside
`if Assigned(Engine)` block *before* fast-exit — user hooks not skipped.

## Remaining overhead (v1.9.3 target)

~27ms engine + ~40ms OS spawn = ~68ms. Further gains:

- `event_loop: 21ms` — worth profiling. `RunEventLoop` may poll once
  with a fixed wait even when no tasks pending.
- Startup: process spawn ~40ms is OS floor.

Realistic v1.9.3 target: 68ms -> ~45-50ms.

## Reproduce

    cp pascak_noASTnet ~/pascak_test
    chmod +x ~/pascak_test
    PASCAK_BIN=~/pascak_test bash benchmarks/run_all.sh

    # Timing breakdown
    PASCAK_TIMING=1 ~/pascak_test --dev hi.pas

## Change history

- **v1.9.2 (2026-10-29)** — Fast CLI exit (skip ~200ms global cleanup).
  Startup 277 -> 68ms. Cumulative v1.8.0->v1.9.2: 10x JSON, 6.5x Array,
  2-3x others, 29x startup.
- **v1.9.1 (2026-10-29)** — Lazy worker pool (277ms startup).
- **v1.9.0 (2026-10-29)** — Remove Sleep(1500) + script fallback test.
- **v1.8.0 (2026-10-29)** — Initial baseline.
