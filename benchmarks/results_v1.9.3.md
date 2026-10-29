# Benchmark Baseline — v1.9.3 (2026-10-29)

**Device**: Termux on Android (aarch64)
**Method**: bash date +%s%N wall clock, 1 warm-up + 3 runs, median
**Binary**: pascak_noASTnet

## Cumulative (v1.8.0 -> v1.9.3)

| Benchmark | v1.8.0 | v1.9.0 | v1.9.1 | v1.9.2 | v1.9.3 | vs v1.8.0 |
|---|---|---|---|---|---|---|
| VM arith 100K | 3340 | 1866 | 1650 | 1431 | 1393 | 2.4x |
| Function calls 100K | 3712 | 2213 | 1973 | 1772 | 1798 | 2.1x |
| Dict set+get 200K | 5908 | 4456 | 4174 | 3972 | 3929 | 1.5x |
| Array push+iter 20K | 2259 | 795 | 549 | 348 | 334 | 6.8x |
| String concat 10K | 3023 | 1553 | 1318 | 1098 | 1091 | 2.8x |
| JSON roundtrip 1K | 2146 | 632 | 424 | 215 | 193 | 11.1x |
| Parser 47K lines | 60 | 61 | 61 | 61 | 60 | 1.0x |

Startup: 2000 -> 489 -> 277 -> 68 -> **45 ms** (44x cumulative)

## What changed in v1.9.3

Conditional WS poll in `TEventLoop.RunLoop`. Line 19858:

    // Before:
    if Assigned(GWSEventLoop) then
      GWSEventLoop.Tick(20);   // 20ms blocking poll always

    // After:
    if Assigned(GWSEventLoop) then
    begin
      if (GWSEventLoop.ActiveConns > 0) or (FTasks.Count > 0) then
        GWSEventLoop.Tick(20)  // block if clients/tasks need waiting
      else
        GWSEventLoop.Tick(0);  // non-blocking poll for idle CLI scripts
    end;

Impact: `event_loop: 21ms -> 0ms` per exec. Startup 68ms -> 45ms.

Behavior preserved:
- GUI scripts (`gui.run()` + WS clients): Tick(20) blocks properly
- Async scripts (`http.get2Async`): FTasks.Count > 0 -> Tick(20)
- Pure CLI scripts: Tick(0), no wait

## Phase breakdown (PASCAK_TIMING=1 hi.pas)

Final v1.9.3:

    globals_init:      0-1ms
    engine_create:     2ms
    exec:              5ms
    event_loop:        0ms   (was 21ms)
    engine_shutdown:   0ms
    engine_free:       0ms
    fast_exit:         0ms
    ---------------
    internal total:    ~8ms
    + OS spawn:        ~37ms
    = wall clock:      ~45ms

`engine_free: 0ms` — fast-exit skips ~200ms cleanup.

`engine_free: 202ms` — only when PASCAK_WORKER_POOL=eager (thread join).

## Diminishing returns

~45ms is near-optimal for interpreter. Breakdown:
- OS process spawn: ~37ms (floor)
- Internal engine: ~8ms (near-optimal, all phases <5ms)

Further optimization unrealistic without:
- Static binary linking (remove dynamic loader overhead)
- Faster cold-start IPC/mmap (OS-level)
- Compiler-level: reduce binary size for faster load

Recommendation: shift focus to feature work / bug fixes.

## Remaining known limitations

- Server script without `gui.run()` (e.g., `gui.start(); sleep(N)`) hangs
  on shutdown (pre-existing, not v1.9.3 regression)
- `PASCAK_WORKER_POOL=eager` still costs ~200ms (thread join, opt-in)

## Reproduce

    cp pascak_noASTnet ~/pascak_test
    chmod +x ~/pascak_test
    PASCAK_BIN=~/pascak_test bash benchmarks/run_all.sh
    PASCAK_TIMING=1 ~/pascak_test --dev hi.pas

## Change history

- **v1.9.3 (2026-10-29)** — Conditional WS poll (Tick(0) idle). Startup
  68 -> 45ms. Cumulative v1.8.0 -> v1.9.3: 44x startup, 11x JSON,
  6.8x Array, 2-3x others.
- **v1.9.2 (2026-10-29)** — Fast CLI exit (skip ~200ms global cleanup).
  Startup 277 -> 68ms.
- **v1.9.1 (2026-10-29)** — Lazy worker pool (277ms startup).
- **v1.9.0 (2026-10-29)** — Remove Sleep(1500) + script fallback test.
- **v1.8.0 (2026-10-29)** — Initial baseline.
