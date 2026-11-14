# 📋 Handover — v1.13.0 (2026-11-14)

Supersedes: `SESSION_HANDOVER_2026-11-13.md` (v1.11.54)
Main HEAD: (next commit)
Tags: 119+ (release)
Engine: 53,754+ lines

## Delta Since v1.12.0 (8 releases, 1 day)

| Version | Focus | Result |
|---|---|---|
| **v1.12.1** | **Label widget** | Widget #8, static text |
| **v1.12.2** | **ProgressBar widget** | Widget #9, 0-100 value + clamp |
| **v1.12.3** | **Alert modal** | Overlay + box + OK button |
| **v1.12.4** | **Confirm dialog** | Yes/No callbacks |
| **v1.12.5** | **Scrollbar standalone** | Widget #10, drag + track-jump |
| **v1.12.6** | **Scroll container** | Widget #11, clip + offset + ScrollManaged |
| **v1.12.7** | **Mouse wheel scroll** | SDL_MOUSEWHEEL routed to hovered container |
| **v1.12.8** | **ScrollContainer fix** | Children offset by container pos (visual bug) |

## Visual Verification (X11 Interactive)

| Widget | API | Build | Visual |
|---|---|---|---|
| Label (left/center/right) | ✅ | ✅ | ✅ |
| ProgressBar 50% | ✅ | ✅ | ✅ |
| ScrollBar thumb | ✅ | ✅ | ✅ |
| ScrollContainer clip | ✅ | ✅ | ✅ |
| Alert overlay | ✅ | ✅ | ✅ |
| Confirm callbacks | ✅ | ✅ | ✅ (tap Yes = callback) |

**Known issues (v1.13.1 planned):**
- Modal message text truncation for long messages (>25 chars) — word wrap needed
- Touch swipe scroll (SDL_FINGER* events) not handled — wheel only
- Auto-scrollbar integration (user adds scrollbar manually)

## Widget Count: 7 → 13

- Button, Edit, Memo, ComboBox, ListBox, Checkbox, Radio (v1.11.x)
- Label, ProgressBar, ScrollBar, ScrollContainer (v1.12.x)
- Alert, Confirm (modal, not widgets but production features)

## Publish Gate Status

- **Fast:** 75% (function parity, top-level 4.6x disclosed)
- **Safe:** 100% (5,604 lines audited, 0 P0/P1)
- **Easy:** 100% (error handling + 13 widget/modal)
