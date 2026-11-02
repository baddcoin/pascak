# Widget Toolkit Implementation Plan

## 15 Phase Rollout

Each phase: sub-branch, tested, merged to feat/gui-widgets after green.

## Phase 1: Foundation (~1-2 sesi)

- Bind SDL_TEXTINPUT, SDL_StartTextInput, SDL_StopTextInput
- Bind SDL_GetKeyboardState
- poll() handles SDL_TEXTINPUT -> 'textinput:<utf8>'
- Persistent keyDown state (array[0..512] of Boolean)
- API: gui2.textInputEnabled(), gui2.keyDown(name)
Success: test input unicode (é, ñ, 中), IME, key repeat, hotkeys

## Phase 2: Widget base class (~2-3 sesi)

- TGuiWidget abstract class (ID, bounds, visible, focused)
- TGuiSDLWindow extended: Widgets list, FocusedWidgetID, MouseCaptureID
- Event dispatch: poll() events -> hit test -> dispatch to widget
- Focus chain: FocusNext() via Tab/Shift+Tab
- Draw pipeline: call each widget's Draw after primitive calls
Success: dummy widget draws rect + handles click, 17/17 PASS

## Phase 3: Button MVP (~1 sesi)

- TGuiButton: rect + text + hover + pressed states
- onClick callback support
- Keyboard activation (Enter/Space when focused)
- gui2.button() API
Success: clickable button, keyboard activation works

## Phase 4: Edit single-line (~2 sesi)

- Text buffer, cursor position, selection
- textinput:<char> insert at cursor
- BACKSPACE/DELETE/LEFT/RIGHT/HOME/END
- SHIFT+LEFT/RIGHT selection, Ctrl+A select all
- Cursor blink (500ms when focused)
- gui2.edit(), gui2.editSetText(), gui2.editGetText()
Success: type text, move cursor, select, delete

## Phase 5: Memo multi-line (~2-3 sesi)

- Lines array, cursor (line, col), scroll_y
- ENTER inserts newline, UP/DOWN move line
- PageUp/PageDown jump visible_height
- Viewport culling (only render visible lines)
- Optional word-wrap
- gui2.memo(), gui2.memoSetText(), gui2.memoGetText()
Success: type multi-line text, scroll, navigate

## Phase 6: Checkbox + Radio (~1 sesi)

- TGuiCheckbox: box + checkmark + label
- TGuiRadio: circle + dot + label + group_id
- Mutually exclusive selection for radios in same group
- gui2.checkbox(), gui2.radio()
Success: toggle states, group radio selection

## Phase 7: ComboBox (~2 sesi)

- TGuiComboBox: rect + text + arrow + dropdown
- Popup layer (rendered top-most)
- Click toggle, click item select
- Click-outside-to-close (global mouse handler)
- gui2.combobox(), gui2.comboSetItems(), gui2.comboGetSelected()
Success: dropdown opens, item selects, outside click closes

## Phase 8: ListBox (~1-2 sesi)

- TGuiListBox: items + selected_idx + scroll_y
- UP/DOWN keyboard nav (auto-scroll)
- Click selection with onSelect callback
- gui2.listbox(), gui2.listSetItems(), gui2.listGetSelected()
Success: scroll, select, callbacks fire

## Phase 9: Scrollbar + Layout (~2 sesi)

- TGuiScrollbar reusable (used by Memo/ListBox/Combo)
- gui2.widgetSetPos(), widgetSetSize(), widgetDestroy()
- gui2.widgetGetBounds()
Success: scrollbar drag works, layout APIs operate correctly

## Phase 10: Theming (~1 sesi)

- Color palette per widget (normal, hover, pressed, focused)
- Font size per widget
- gui2.themeSetColor(key, color), gui2.themeSetFont(size)
- Default theme: light gray + blue accent
Success: all widgets respect theme colors

## Phase 11: Tab Navigation (~1 sesi)

- Tab / Shift+Tab cycles focusable widgets
- Focus indicator (dashed border or highlight)
- Auto-skip disabled/invisible widgets
Success: keyboard-only navigation of all widgets

## Phase 12: Clipboard (~1 sesi)

- Bind SDL_GetClipboardText / SDL_SetClipboardText
- Ctrl+C/V/X in Edit/Memo
- gui2.clipboardGet(), gui2.clipboardSet(str)
Success: copy/paste between pascak app and external

## Phase 13: Integration Tests (~1-2 sesi)

- 10+ test cases: click, keyboard, focus, popup, scrollbar
- Manual GUI test (visual verification)
- Benchmark: widget draw overhead < 1ms per frame
Success: all tests PASS, no regression in gui2 core

## Phase 14: Docs + Examples (~1 sesi)

- Tutorial chapter: "Bab 34 — GUI Widgets"
- 3 examples: login form, todo list, settings panel
- API reference update (pascak_api.md)
Success: user can build form-based GUI from docs alone

## Phase 15: Buffer (~2 sesi)

- Edge cases discovered during implementation
- Performance tuning if needed
- Polish + bug fixes

## Total Estimate

| Category | Sesi |
|---|---|
| Prerequisites (Phase 1) | 1-2 |
| Foundation (Phase 2-3) | 3-4 |
| Widgets (Phase 4-9) | 9-12 |
| Polish (Phase 10-15) | 5-8 |
| **Total** | **18-26 sesi** |

Realistic: **20-24 sesi** (3-5 weeks part-time).

## Go / No-Go Decision

**GO if:**
- User report concrete GUI need (form, settings, editor)
- MVP approach validated (Phase 1-3 first, ~4-5 sesi)
- Commit to 20-24 sesi total

**NO-GO if:**
- No user report
- Uncertain about 3-5 weeks commitment
- Current gui2 primitives sufficient for use case

**Recommendation:** MVP (Phase 1-3, 4-5 sesi) as proof of concept.
Expand to full toolkit only after user validation.
