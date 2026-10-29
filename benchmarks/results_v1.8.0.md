# Benchmark Baseline — v1.8.0 (2026-10-29)

**Device**: Termux on Android (aarch64)
**Method**: bash date +%s%N wall clock, 1 warm-up + 3 runs, median
**Binary**: pascak_noASTnet

## Results

| Benchmark | Workload | Median (ms) | Throughput | Verdict |
|---|---|---|---|---|
| VM arithmetic | 100K loops | 3340 | 30 Kops/s | Slow |
| Function calls | 100K calls | 3712 | 27 Kcalls/s | Slow |
| Dict set+get | 200K ops | 5908 | 34 Kops/s | Slow |
| Array push+iter | 20K ops | 2259 | 8.8 Kops/s | Very slow |
| String concat | 10K appends | 3023 | 3.3 Kappends/s | O(n^2) expected |
| JSON roundtrip | 1K ops | 2146 | 466 roundtrips/s | Slow |
| Parser | 47K lines | 60 | 780 Klines/s | FAST |

## Analysis

### Parser (healthy)
- 780K lines/sec on 1.4MB source file
- Production-grade, no optimization needed

### VM core (slow - optimization backlog)
- 33 us/iteration for simple arithmetic
- Reasonable target: 0.3-3 us/iteration (10-100x faster)
- Likely causes: watchdog check per instruction, TValue allocation per op, GC pressure

### Array push (very slow)
- 113 us/op
- Likely causes: per-op F.lock, per-element Clone, arrMax check
- Quick win: skip lock + skip clone for primitives

### String concat (O(n^2) expected)
- Cumulative append rebuilds full string each iter
- Not a bug - pattern inherently quadratic
- Alternative: array + join for linear

### JSON (slow)
- 2.1 ms per parse+stringify roundtrip
- Not yet profiled

## Baseline usage

**Reference snapshot**, not target. Absolute numbers vary by device, load, thermal.

**Primary use: relative trend detection** (future vs baseline on same device).

    cp pascak_noASTnet ~/pascak_test
    chmod +x ~/pascak_test
    PASCAK_BIN=~/pascak_test bash benchmarks/run_all.sh > future.log
    # diff medians against this file

## Future optimization targets

Ranked by impact x effort:

1. **Array push** - skip lock + skip clone for primitives (est 2-3x)
2. **VM core** - profile watchdog interval + TValue alloc path
3. **JSON** - profile parser; consider compiled schema cache
4. **String** - document array+join alternative (skip micro-opt)

## Change history

- **v1.8.0 (2026-10-29)** - Initial baseline.
  - Arith reduced 10M -> 100K (10M = 131s, impractical)
  - Array reduced 1M -> 10K (arrMax = 10000 limit)
  - JSON replaces coroutine (yield for/in buggy)
