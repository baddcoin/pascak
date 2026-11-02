# GUI Widget Toolkit — Design & Planning

**Status:** PLANNING (no implementation yet)
**Target:** High-level widget library on top of `gui2` (SDL2)
**Baseline:** v1.11.13 (see benchmarks/results_v1.11.12.md)
**Effort estimate:** 18-22 sessions (3-5 weeks part-time)

## TL;DR

`gui2` saat ini = low-level drawing primitives (rect, line, text, texture).
Tidak ada widget high-level seperti Edit, Memo, ComboBox, Button.

Goal: tambah widget library mirip Lazarus/FPC form components, tapi
build di atas `gui2` existing (SDL2) tanpa dependency baru.

## Critical Prerequisite Discovered

**`SDL_TEXTINPUT` event TIDAK di-bind** di v1.11.13. Ini hard blocker:
- `gui2.poll()` return `'key:<name>'` untuk keydown, tapi tidak ada
  event `'textinput:<char>'` untuk actual text
- Edit/Memo/ComboBox filter butuh raw UTF-8 character input
- Tanpa `SDL_TEXTINPUT`: tidak bisa input `'é'`, `'中'`, IME, compose
- ASCII basic bisa hack (map keycode ke char), tapi fragile & locale-dependent

**Phase 1 harus bind `SDL_TEXTINPUT` + `SDL_StartTextInput` sebelum widget apapun.**

## Documents

- [`architecture.md`](architecture.md) — widget base class, event dispatch, focus chain
- [`prerequisites.md`](prerequisites.md) — SDL_TEXTINPUT + keyboard state (Phase 1)
- [`widget_specs.md`](widget_specs.md) — spec per widget (Button, Edit, Memo, Combo, List, Checkbox)
- [`phase_plan.md`](phase_plan.md) — 15 phase plan + success criteria

## Recommendation Summary

| Approach | Effort | Value | Risk |
|---|---|---|---|
| MVP (Button + Foundation) | 4-5 sesi | Medium | Medium |
| Full toolkit | 18-22 sesi | High | High |
| Defer until user report | 0 sesi | Unknown | None |

**Saran:** Try MVP first (Phase 1+2+3) → validate pattern → expand.

## Status Log

- **2026-11-01:** Phase 0 planning doc created (no implementation).
