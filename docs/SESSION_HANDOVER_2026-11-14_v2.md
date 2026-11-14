# 📋 Handover — v1.13.3 (2026-11-14)

Supersedes: `SESSION_HANDOVER_2026-11-14.md` (v1.13.0)
Main HEAD: (next commit)
Tags: 121+ (release)

## Delta Since v1.13.0 (3 releases)

| Version | Focus |
|---|---|
| **v1.13.1** | ProgressBar vertical orientation |
| **v1.13.2** | ScrollContainer auto-bounds + horizontal |
| **v1.13.3** | Horizontal milestone + docs |

## Horizontal Support — Complete

| Widget | Horizontal | Vertical |
|---|---|---|
| ProgressBar | ✅ (default) | ✅ (v1.13.1) |
| ScrollBar | ✅ (v1.12.5) | ✅ (default) |
| ScrollContainer | ✅ (v1.13.2 bounds) | ✅ (v1.12.6) |
| Wheel scroll | ✅ (wheelDX) | ✅ (wheelDY) |

## Visual Verification (X11)

**v1.13.3 combined verify (screenshot):**
- ProgressBar H 75% → 3/4 biru ✅
- ProgressBar V 60% → 3/5 biru dari bawah ✅
- ScrollBar H → thumb 20% di kiri, hover state berubah ✅
- ScrollContainer x=100 → Item 2 full, Item 3 partial, Item 1/4/5 clip ✅

## Widget Count: 13

Button, Edit, Memo, ComboBox, ListBox, Checkbox, Radio (v1.11.x)
Label, ProgressBar, ScrollBar, ScrollContainer (v1.12.x)
Alert, Confirm (modal)

## Publish Gate Status

- **Fast:** 75% (function parity, top-level 4.6x disclosed)
- **Safe:** 100% (5,604 lines audited, 0 P0/P1)
- **Easy:** 100% (error handling + 13 widget/modal)

## Known Issues (v1.13.4 backlog)

| # | Issue | Effort |
|---|---|---|
| 1 | Modal message truncation >25 chars (word wrap) | 30 min |
| 2 | Touch swipe scroll (SDL_FINGER*) | 1-2 jam |
| 3 | Modal box uses 800x600 fallback (window size) | 30 min |
| 4 | Auto-scrollbar for containers (manual wiring) | 1 jam |

## Publish Ready

All gates passed. Publish as v1.13.3.
