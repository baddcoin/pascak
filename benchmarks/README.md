# Pascak VM Benchmarks

Performance baseline suite for measuring VM throughput. Not micro-optimization targets — **relative trend detection** across versions.

## Quick start

    cp pascak_noASTnet ~/pascak_test
    chmod +x ~/pascak_test
    PASCAK_BIN=~/pascak_test bash benchmarks/run_all.sh

Total runtime: ~10-15 seconds (7 benchmarks, 1 warm-up + 3 runs each).

## What's measured

| Benchmark | Workload | What it exercises |
|---|---|---|
| bench_arith.pas | 100K loop iterations | VM arithmetic opcodes |
| bench_calls.pas | 100K function calls | Call overhead, frame setup |
| bench_dict.pas | 100K set + 100K get | Hash table, TValue boxing |
| bench_array.pas | 10K push + for-in | Array ops, lock, clone |
| bench_string.pas | 10K cumulative appends | String concat (O(n^2)) |
| bench_json.pas | 1K parse + stringify | JSON parser, allocator |
| bench_parser.sh | Parse pascak_engine.pas (47K lines) | Lexer, parser, bytecode gen |

## Baseline

See results files:
- [results_v1.8.0.md](results_v1.8.0.md) — initial baseline
- [results_v1.9.0.md](results_v1.9.0.md) — after Sleep(1500) + script fallback fixes (~2x speedup)

Key findings:
- Parser: **fast** (780K lines/sec)
- VM core: **slow** (33 us/op — optimization backlog)
- Array push: **very slow** (113 us/op — lock + clone overhead)


## Methodology

- **Wall clock**: bash `date +%s%N` (nanosecond resolution, portable on Termux)
- **Warm-up**: 1 run (primes bytecode cache, OS file cache)
- **Measure**: 3 runs, report median (robust to outliers)
- **No /usr/bin/time**: not available on Termux (toybox `time` lacks `-f` flag)
- **No internal `time.now()`**: epoch seconds resolution too coarse

## Interpreting results

**Absolute numbers vary by**:
- Device CPU (ARMv8, cores, frequency)
- Termux thermal state (throttling under load)
- OS memory pressure

**Compare like-for-like**:
- Same device + same binary
- Cold start vs warm cache
- Relative trend (v1.8.0 vs v1.9.0) is meaningful
- Cross-device comparison is NOT meaningful

**Example trend detection**:
    # Record baseline
    bash benchmarks/run_all.sh > baseline_v1.8.0.log

    # After optimization
    bash benchmarks/run_all.sh > after_opt.log

    # Compare medians
    diff <(grep 'median:' baseline_v1.8.0.log) \
         <(grep 'median:' after_opt.log)

## Adding a new benchmark

1. Create `benchmarks/bench_<name>.pas`
2. Keep workload 1-3 seconds (single run) on low-end device
3. Print a deterministic checksum/sum to verify correctness
4. Register in `run_all.sh` with `run_bench "Name" path "workload description"`
5. Measure baseline, add to `results_v*.md`

**Example structure**:
    // 100K <what> — one-line description
    begin
      // ... work ...
      println("checksum =", result);  // verify not optimized away
    end.

## Known limitations

- **arrMax = 10000** — array benchmark capped at 10K elements (engine limit)
- **coroutine for/in** — broken (hangs); JSON benchmark used instead
- **Network benchmarks** — skipped (httpbin flaky, H2 pool slow warm-up in Termux)
- **GC overhead** — not isolated; measured as part of overall workload
- **Parser benchmark** — uses `--check` (syntax only), not full execute
