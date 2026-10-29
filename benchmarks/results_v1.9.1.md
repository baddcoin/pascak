# Benchmark Baseline — v1.9.1 (2026-10-29)

**Device**: Termux on Android (aarch64)
**Method**: bash date +%s%N wall clock, 1 warm-up + 3 runs, median
**Binary**: pascak_noASTnet

## Cumulative comparison (v1.8.0 -> v1.9.1)

| Benchmark | v1.8.0 | v1.9.0 | v1.9.1 | vs v1.9.0 | vs v1.8.0 |
|---|---|---|---|---|---|
| VM arith 100K | 3340 | 1866 | 1650 | -12% | 2.0x |
| Function calls 100K | 3712 | 2213 | 1973 | -11% | 1.9x |
| Dict set+get 200K | 5908 | 4456 | 4174 | -6% | 1.4x |
| Array push+iter 20K | 2259 | 795 | 549 | -31% | 4.1x |
| String concat 10K | 3023 | 1553 | 1318 | -15% | 2.3x |
| JSON roundtrip 1K | 2146 | 632 | 424 | -33% | 5.1x |
| Parser 47K lines | 60 | 61 | 61 | 0% | 1.0x |

Startup (empty.pas): 2000 -> 489 -> **277 ms** (7.2x cumulative)
Startup (no args):   2000 ->   30 ->   30 ms (preserved from v1.9.0)

## What changed in v1.9.1

Lazy worker pool creation. `TPascakEngine.InitializeRuntime` no longer creates
8 eager worker threads at startup. Instead:

- Default: `FWorkerPool := nil` (no threads spawned)
- First async operation (`http.get2Async`, `http.listenAsync`, spawn)
  triggers `EnsureWorkerPoolForCtx(Ctx)` which lazily creates pool
- Opt-in eager: `PASCAK_WORKER_POOL=eager` env var (for production servers
  that want pre-warmed pool)

Behavior preserved:
- Async paths auto-create pool on first use
- Teardown frees lazy-created pool via else-branch
- Compute scripts (no async) never spawn threads

## Impact

- Startup: 489ms -> 277ms (-43%) for scripts without async
- Async scripts: pool created lazily on first call, ~50ms one-time cost
- Benchmark improvement: 6-33% additional speedup (startup amortized)
- Cumulative v1.8.0 -> v1.9.1: **2-5x speedup** on compute workloads

## Remaining overhead (target for v1.9.2)

Fixed per-exec cost now ~277ms (down from 489ms). Breakdown estimate:

- **Engine.Create / InitializeRuntime** — ~100ms
  - 25 TTypeDefinition + TInstanceValue module registrations
  - ~50 TCriticalSection creates
  - Global dict/TList registries
- **Script parse + compile** — ~30ms (small scripts)
- **Shutdown / GC sweep** — ~140ms
  - FContext.Release walks Gen0/Gen1 lists
  - Thread joins, pool cleanup

Next optimization candidates (v1.9.2):

1. **Defer module registration** — register natives on first access
   (est 40-60ms savings)
2. **Faster shutdown for CLI** — `libc__exit(0)` after script for non-LSP/non-GUI
   modes (skip full GC sweep, OS reclaims) — est 100ms savings, but requires
   careful mode detection
3. **Parse cache warm-up** — compile once on first run, cache bytecode for
   repeated invocations — est 20-30ms savings on warm runs

Combined potential: 277ms -> ~120-150ms (2x more improvement possible).

## Reproduce

    cp pascak_noASTnet ~/pascak_test
    chmod +x ~/pascak_test
    PASCAK_BIN=~/pascak_test bash benchmarks/run_all.sh

Startup test:

    time ( env PASCAK_EXEC_POLICY=allow-all ~/pascak_test --dev hi.pas >/dev/null )
    # expected ~280ms (lazy) / ~490ms (PASCAK_WORKER_POOL=eager)

## Change history

- **v1.9.1 (2026-10-29)** — Lazy worker pool. Startup 489 -> 277ms (-43%).
  Async paths auto-create on first use. Opt-in eager via PASCAK_WORKER_POOL=eager.
  Cumulative vs v1.8.0: 2-5x speedup on benchmarks.
- **v1.9.0 (2026-10-29)** — Removed unconditional Sleep(1500) + script fallback
  test suite. ~2x average speedup.
- **v1.8.0 (2026-10-29)** — Initial baseline.
