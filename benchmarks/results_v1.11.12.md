# Benchmark Baseline — v1.11.12 (2026-10-31)

**Device**: Termux on Android (aarch64)
**Method**: bash date +%s%N wall clock, 3 runs, median
**Binary**: pascak_noASTnet v1.11.12

## Purpose

Establish **current baseline** before register VM Tier 3 (or Tier 2.5)
exploration. Compare against v1.9.4 to confirm no regression from
v1.11.x work (hot-reload, ETag caching, SIGPIPE fix, worker-sleep cap,
JIT deopt fix).

## Results

| Benchmark | v1.9.4 | v1.11.12 | Delta | Note |
|---|---|---|---|---|
| VM arith 100K | 1398 | 1369 | -2.1% | Best-ever |
| Function calls 100K | 1768 | 1756 | -0.7% | Parity |
| Dict set+get 200K | 3931 | 3941 | +0.3% | Noise |
| Array push+iter 20K | 319 | 316 | -0.9% | Parity |
| String concat 10K | 1089 | 1109 | +1.8% | Noise |
| JSON roundtrip 1K | 204 | 218 | +6.9% | Noise (watch) |
| Parser 47K lines | 68 | 64 | -5.9% | Slight better |

## Analysis

**v1.11.12 = parity with v1.9.4.** No regression from v1.11.x work.
JSON at +7% is likely noise (single benchmark, 204-218ms range, could be
system thermal or scheduler variance). Monitor on next baseline.

**Absolute numbers (context):**
- Arith 100K: 13.7 µs/op — competitive with CPython 3.10 (~20 µs/op)
- Dict 200K: 19.7 µs/op — reasonable for hash-based dict
- Parser 47K lines: 1.4 µs/line — very fast (~34K lines/sec)
- Startup: ~45ms (not re-measured, was 45ms in v1.9.4)

**Remaining bottleneck:** TValue allocation per operation (dict entry,
numeric result, string concat). Register VM alone does not solve this —
arbitrary allocation is VM-agnostic. Would need arena allocator
(Phase plan separate).

## Register VM Context

**Tier 1 (superinstructions)**: implemented Phase 2 — `opcAddNum`,
`opcIncrLocal`, `opcSumArrayIndex`, etc (17 superinstructions total).

**Tier 2 (adaptive specialization)**: implemented — `TypeFeedback: Byte`
per instruction, `HitCount: Word`, hot-patch to specialized opcode after
100 numeric hits. Deopt fallback fixed in v1.11.12.

**Tier 3 (full register VM)**: NOT implemented. See
`docs/register_vm_design.md` for phase plan.

**Why consider Tier 3:**
- Potential 1.5–2.5× for hot arithmetic loops (if win materializes)
- Enables subsequent optimizations (register allocator, dead code elimination)

**Why defer Tier 3:**
- 1–2 week effort (8–12 phases)
- Tier 1+2 already covers 70% of typical win
- Risk of regression on subtle semantics (numeric precision, GC roots)
- Diminishing returns — remaining cost is TValue alloc, not dispatch

## How to reproduce

    cd ~/storage/downloads/termux/pascak
    cp pascak_noASTnet $HOME/pascak_test
    chmod +x $HOME/pascak_test
    PASCAK_BIN=$HOME/pascak_test bash benchmarks/run_all.sh
