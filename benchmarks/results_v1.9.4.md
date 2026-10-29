# Benchmark Baseline — v1.9.4 (2026-10-29)

**Device**: Termux on Android (aarch64)
**Method**: bash date +%s%N wall clock, 1 warm-up + 3 runs, median
**Binary**: pascak_noASTnet

## Regression fix — no perf impact

v1.9.4 is a **bug fix**, not a perf milestone. Benchmark numbers stable
vs v1.9.3 (all within noise range).

| Benchmark | v1.9.3 | v1.9.4 | Delta |
|---|---|---|---|
| VM arith 100K | 1393 | 1398 | noise |
| Function calls 100K | 1798 | 1768 | -1.7% |
| Dict set+get 200K | 3929 | 3931 | noise |
| Array push+iter 20K | 334 | 319 | -4.5% |
| String concat 10K | 1091 | 1089 | noise |
| JSON roundtrip 1K | 193 | 204 | noise |
| Parser 47K lines | 60 | 68 | noise |

Startup: 45ms (unchanged).

## What changed in v1.9.4

Bug fix: **server script hang on shutdown**.

### Symptom
Script using `gui.start(); sleep(N);` (without `gui.run()`) hung indefinitely
after script body completed. User had to Ctrl+C or `timeout` kill.

### Root cause
Two compounding issues:

1. `runScript` unconditionally called `Engine.RunEventLoop` after script
   exec. `RunLoop` is `repeat..until(IsShuttingDown=1)` — never breaks
   because shutdown signal is set only AFTER this call. Chicken-and-egg.

2. `gui.start()` sets an interval GUI poll timer, so `HasPendingTasks`
   would be True even if user didn't request async processing.

### Fix
- **v1.9.4 patch 1**: `RunEventLoop` now skips `RunLoop` when
  `FEventLoop.HasPendingTasks = false` (avoids the chicken-and-egg
  for pure CLI scripts with no timers).
- **v1.9.4 patch 2**: `runScript` no longer implicitly enters event loop.
  Scripts that want live event processing must call `gui.run()` or
  `Engine.RunEventLoop` explicitly. This matches user expectation — if
  script didn't ask for event loop, don't run one.

### Verification
| Scenario | Before | After |
|---|---|---|
| `gui.start(); sleep(1)` | infinite hang | exit=0 (~3s incl 1.5s cleanup) |
| `gui.run()` + watcher | works | works |
| async `http.get2Async` | works | works |
| Pure CLI `hi.pas` | 45ms | 42-60ms (unchanged) |
| 17/18 language tests | PASS | PASS (v129/v130 need mock server) |

Cleanup for server scripts still runs (~1.5s = HTTP listener thread join +
accept timeout). Fast-exit is skipped correctly because `GGuiApps.Count > 0`.

### Behavior change (intentional)
- `gui.start() + sleep()` pattern: script exits after sleep, no implicit
  event loop. Server is torn down during cleanup.
- If user wants live server: use `gui.run()` (blocks, drives event loop).

## Reproduce

    cp pascak_noASTnet ~/pascak_test
    chmod +x ~/pascak_test
    PASCAK_BIN=~/pascak_test bash benchmarks/run_all.sh

    # Bug fix verification
    cat > server_test.pas << 'EOF'
    var h := gui.create(18100, "Test");
    begin
      gui.serve(h, "<html><body>Hi</body></html>");
      gui.start(h);
      sleep(1000);
    end.
    EOF
    ~/pascak_test --dev server_test.pas
    # Before v1.9.4: hangs
    # After v1.9.4: exits cleanly

## Change history

- **v1.9.4 (2026-10-29)** — Fix server script hang on shutdown. No perf
  change (still 45ms startup, all benchmark medians stable within noise).
- **v1.9.3 (2026-10-29)** — Conditional WS poll (startup 68 -> 45ms).
- **v1.9.2 (2026-10-29)** — Fast CLI exit (startup 277 -> 68ms).
- **v1.9.1 (2026-10-29)** — Lazy worker pool (startup 489 -> 277ms).
- **v1.9.0 (2026-10-29)** — Remove Sleep(1500) + script fallback.
- **v1.8.0 (2026-10-29)** — Initial baseline.
