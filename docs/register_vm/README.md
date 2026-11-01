# Register VM — Design & Planning

**Status:** PLANNING (no implementation yet)
**Target:** Tier 3 (full register VM) — optional, high effort
**Baseline:** v1.11.12 (see `benchmarks/results_v1.11.12.md`)

## TL;DR

Pascak sudah punya **Tier 1 (superinstructions)** dan **Tier 2 (adaptive
specialization)**. Tier 3 (full register VM) adalah **optional next step**,
15-20 sessions effort, 1.3-1.5x realistic win (bukan 2-5x seperti klaim umum).

**Rekomendasi:** Jangan implement Tier 3 kecuali ada user report konkret soal
perf yang tidak bisa diselesaikan oleh Tier 2.5 (extend superinstructions).

Remaining bottleneck (TValue alloc, string concat, dict hash) **tidak**
diselesaikan oleh register VM.

## Documents

- [`current_state.md`](current_state.md) — current VM architecture recap
- [`phase_plan.md`](phase_plan.md) — 8-12 phase implementation plan
- [`risks.md`](risks.md) — risk assessment + decision matrix

## Recommendation Summary

| Path | Effort | Win | Risk |
|---|---|---|---|
| Tier 2.5 (extend superinstructions) | 2-3 sessions | 1.2-1.4x | LOW |
| Tier 3 (full register VM) | 15-20 sessions | 1.3-1.5x | HIGH |
| Arena allocator (TValue) | 5-8 sessions | 1.3-1.5x (targeted) | MEDIUM |

**Saran:** Try Tier 2.5 first. Escalate to Tier 3 only if user reports
specific hot-path that superinstructions cannot solve.

## Status Log

- **2026-10-31:** Phase 0 planning doc created (no implementation).

