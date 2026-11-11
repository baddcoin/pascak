# Benchmark — v1.11.48: Global For-Loop Fusion (Structural Only)

**Status:** Structural improvement, no runtime win
**Date:** 2026-11-11
**Baseline:** v1.11.47 (local for-loop fused, 685ms function / 3.2s top-level)

## What Changed

Fused 8 opcodes → 3 opcodes for global for-loop:
- `opcForLoopCheckGlobal` (replaces `GetGlobal + GetLocal + LtEq + JumpIfFalse`)
- `opcForLoopIncGlobal` (replaces `GetGlobal + GetLocal + Equal + JumpIfFalse + Jump + IncrGlobal + Jump`)
- Added inline cache (reused pattern from `opcGetGlobal`)

## Benchmark Results

| Metric | v1.11.47 | v1.11.48 | Delta |
|---|---|---|---|
| Top-level arith 1M | 3,207 ms | 3,198 ms | **0%** (no win) |
| Function arith 1M | 693 ms | 689 ms | unchanged |
| Top-level opcode count | ~15M (est) | 7,000,014 | **-53%** |
| Regression | 17/17 | 17/17 | PASS |
| Behavior (6 tests) | 6/6 | 6/6 | PASS |

## Why No Runtime Win?

**Primary bottleneck: Generation counter invalidation.**

Body `s := s + i` per iteration:
1. `opcGetGlobal s` — CACHE MISS (gen bumped by prior SetGlobal)
2. `opcGetGlobal i` — CACHE MISS
3. `opcAdd`
4. `opcSetGlobal s` — **BUMPS root Generation counter**
5. Next iter: all cache invalid again

Every `SetGlobal` increments generation → cache miss on every read.

**Secondary bottlenecks:**
- TValue.Clone() per `opcGetGlobal` push (allocation + GC pressure)
- AtomicAddNumeric() locking per `opcForLoopIncGlobal` (1M locks)
- Hash lookup ~200-500ns per miss

## What Fusion DOES Help

Even though wall-clock runtime is unchanged:
1. **Bytecode size:** .pasc cache files ~50% smaller for top-level loops
2. **I-cache pressure:** 3 opcodes vs 8 = better instruction cache locality at scale
3. **Foundation:** fused opcode framework ready for register VM (Phase 1)
4. **Consistency:** global for-loop now uses same fusion pattern as local

## What Would Actually Fix Runtime

Based on profiling + this experiment:

1. **Register VM (Phase 1)** — eliminates GetGlobal/SetGlobal entirely for loop vars
2. **Arena allocator** — reduces TValue allocation cost
3. **Generation bypass** — separate read-only vs write-heavy globals
4. **Escape analysis** — hoist globals to stack if provably local

All require significant architecture work (see ROADMAP_PERFORMANCE.md).

## Reproduce

    PASCAK_BIN=~/pascak_test bash benchmarks/cross_lang/run.sh

## Version History

- **v1.11.48 (2026-11-11)** — Global for-loop fusion (structural, no runtime win)
- **v1.11.47 (2026-11-10)** — Local for-loop redundancy fix (5.2x speedup)
- **v1.11.46 (2026-11-09)** — Phase 0 measurement infrastructure
