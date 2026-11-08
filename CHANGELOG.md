# Changelog

## [Unreleased] — Session Handover Maintenance Convention

### Docs
- **`docs/SESSION_HANDOVER_2026-11-07.md`** — living handover document
  (502 lines, 9 sections). Reference untuk new chat / new session.

### Convention (NEW — must follow each phase completion)
Setiap phase selesai:
1. Update `docs/SESSION_HANDOVER_YYYY-MM-DD.md` (current date)
2. Update `Main HEAD`, `Tags count`, `Engine lines` di header
3. Move completed items ke section "YANG SUDAH SELESAI"
4. Update section "YANG BELUM SELESAI" (hapus done items)
5. Commit handover file bersama phase commit
6. **JANGAN hapus** — permanent reference

---

## [1.11.37] - 2026-11-08

### Docs (API reference)
- pascak_api.md: new section "GUI2 Widgets" (was 0 mentions)
- Coverage: Common widget API (12 methods) + 7 widget types:
  - Button (v1.11.18-20) -- click, callback
  - Edit (v1.11.21-26) -- UTF-8, selection, clipboard
  - Memo (v1.11.27-32) -- scrollbar, line numbers, spacing, wrap
  - ComboBox (v1.11.33) -- dropdown popup
  - ListBox (v1.11.34) -- scrollable list
  - Checkbox (v1.11.35) -- independent toggle
  - Radio (v1.11.35) -- mutually exclusive
- Widget comparison table + anti-patterns
- Full example: Registration form (all 7 widgets)
- Focus chain documentation
- API ref now 5,578 lines (+260). Sync with tutorial Bab 34.

### Documentation completion
- Tutorial Bab 34: 12 sections, all 7 widgets (v1.11.36)
- API reference: GUI2 Widgets section (this release)
- Handover: living document, updated 5x

### Next docs
- Cookbook widget patterns (recipes)
- Examples gallery examples/gui_*.pas

## [1.11.36] - 2026-11-08

### Docs (tutorial)
- Bab 34 rewrite -- cover all 7 widgets (was 3):
  - 34.1-34.6 preserved (existing content)
  - 34.7 Edit Widget Advanced (focus + navigation + selection + clipboard)
  - 34.8 Memo Widget (multi-line + scrollbar + line numbers + spacing + wrap)
  - 34.9 ComboBox Widget (dropdown popup layer)
  - 34.10 ListBox Widget (scrollable list with scrollbar)
  - 34.11 Checkbox + Radio Widget (toggles with mutual exclusion)
  - 34.12 Widget Comparison & Use Cases (decision matrix + anti-patterns)
- Update "Available" head list: 3 widgets -> 7 widgets (v1.11.21 -> v1.11.35)
- Remove "Coming (Phase 4b+)" block (all shipped)
- Update 34.6 Limitations (v1.11.21 -> v1.11.35)
- Tutorial now 6,111 lines (+267)

### Widgets covered in Bab 34
- Button (v1.11.18-20)
- Edit (v1.11.21-26) -- selection, clipboard
- Memo (v1.11.27-32) -- scrollbar, line numbers, wrap, spacing
- ComboBox (v1.11.33)
- ListBox (v1.11.34)
- Checkbox + Radio (v1.11.35)

### Next docs
- pascak_api.md widget section sync
- Cookbook recipes for widget patterns

## [1.11.35] - 2026-11-08

### Added (feature) -- GUI Widget Toolkit Phase 6c (Checkbox + Radio)
- TGuiCheckbox widget -- independent toggle with caption
- TGuiRadio widget -- mutually exclusive within same GroupId
- Both: box + caption, focus indicator (yellow border), click anywhere in bounds
- SPACE/ENTER when focused toggles
- Checked state rendered: green checkmark (Checkbox), green dot (Radio)
- Radio auto-uncheck siblings via SelectSelf loop

### Natives (6)
- gui2.checkbox(x, y, caption, [checked], [r], [g], [b]) -> id
- gui2.checkboxGetChecked(id) -> bool
- gui2.checkboxSetChecked(id, bool) -> bool
- gui2.radio(x, y, caption, [group_id], [checked], [r], [g], [b]) -> id
- gui2.radioGetChecked(id) -> bool
- gui2.radioSetChecked(id, bool) -> bool (auto-uncheck siblings)

### Verified (interactive X11 test)
- 3 checkboxes + 3 radios, 10 state changes in 60s
- Checkbox independent toggle (CB2 no effect on CB1/CB3)
- Radio mutual exclusion (click any -> siblings auto-unchecked)
- No crash, clean exit
- Regression: 17/17 lang tests PASS

### Next phase
- Phase 6d: Layout API (flow/grid)
- Phase 7: Theming
- Or: user feedback cycle (STRONGEST)

## [1.11.34] - 2026-11-08

### Added (feature) -- GUI Widget Toolkit Phase 6b (ListBox)
- TGuiListBox widget -- scrollable list with selection
- Items, SelectedIdx, ScrollTop, HoveredItemIdx
- Scrollbar (proportional thumb, drag) -- reuse Memo pattern
- Click item select, hover highlight (mousemove)
- Click scrollbar track jump, drag thumb scroll
- Keyboard: UP/DOWN, PageUp/PageDown, HOME/END, ENTER/SPACE
- Auto-scroll EnsureSelectedVisible
- Focus indicator (yellow border), selected blue + yellow, hover light blue

### Natives (6)
- gui2.listbox(x, y, w, h, [initial], [r], [g], [b]) -> id
- gui2.listSetItems(id, arr) -> bool
- gui2.listGetItems(id) -> arr
- gui2.listGetSelected(id) -> num (-1 if none)
- gui2.listSetSelected(id, n) -> bool
- gui2.listGetSelectedText(id) -> str

### Verified (interactive X11 test)
- 26 items, initial Item 01
- 14 selection changes in 60s (click + UP/DOWN + PgUp/PgDn)
- Final: Item 06, index 5
- Screenshot: selected highlight blue, hover visible, scrollbar proportional
- No crash, clean exit
- Regression: 17/17 lang tests PASS

### Next phase
- Phase 6c: Checkbox + Radio
- Phase 6d: Layout API
- Or: user feedback cycle (STRONGEST)

## [1.11.33] - 2026-11-07

### Added (feature) -- GUI Widget Toolkit Phase 6a (ComboBox)
- TGuiComboBox widget -- dropdown selection
- Items list, SelectedIdx, DropdownOpen, HoveredItemIdx
- Dropdown popup layer (DrawPopup virtual, rendered above others)
- Click combo -> toggle; Click item -> select + close; Click outside -> close
- Keyboard: UP/DOWN, ENTER, SPACE, ESC
- Focus indicator (yellow border), selected prefix + yellow, hover blue

### Architecture
- TGuiWidget.DrawPopup virtual (default no-op)
- widgetsDraw two-pass (Draw all, then DrawPopup all)
- GuiComboPopupHitTest + GuiDispatchMouse routing
- Popup at Y+H, height = Items.Count * ItemHeight

### Natives (7)
- gui2.combobox, comboSetItems, comboGetItems
- comboGetSelected, comboSetSelected, comboGetSelectedText, comboIsOpen

### Verified (interactive X11)
- 15 selection changes in 60s
- Final: Option E, click/hover/keyboard all working
- No hang, clean exit
- Regression: 17/17 lang tests PASS

## [1.11.32] - 2026-11-07

### Added (feature) -- GUI Widget Toolkit Phase 5c-2a (Line Numbers)
- **Memo line numbers gutter** -- configurable via gui2.memoSetLineNumbers
- **LineNumbersEnabled** flag (default False -- no behavior change)
- **GutterWidth** field (default 50px)
- Draw: dark gutter background + line numbers, text/cursor/selection
  shifted right by GutterWidth
- Click position adjusted (MX - (X + PadLeft + GutterWidth))
- Wrap WAvail reduced by GutterWidth when line numbers ON

### Behavior
- Line numbers rendered only for FIRST visual line of each logical line
  (wrap-aware -- when wrap ON, one number per logical block)
- Numbers 1-indexed, color yellow-ish (180, 180, 100)
- Gutter background dark (30, 30, 40)
- Gutter auto-updates when lines added/removed (drawn each frame from current Lines.Count)
- Click in text area positions cursor correctly (gutter excluded)

### Implementation
- TGuiMemo fields: LineNumbersEnabled, GutterWidth
- Draw: gutter bg + number render + TextX offset for text/cursor/selection
- RebuildVisualLines: WAvail -= GutterWidth when LineNumbersEnabled
- HandleMouse: MX offset for text click when LineNumbersEnabled
- Natives: gui2.memoSetLineNumbers(id, bool) / memoGetLineNumbers(id)

### Verified (interactive X11 test)
- Initial 5 lines: gutter 1-5 visible, text shifted right ~50px
- After editing (3 new empty lines + text added):
  - Gutter auto-updated to 1-9
  - Numbers aligned with text rows
  - Empty lines still get their number (4, 5, 8)
  - Cursor in text area (not gutter)
  - Click position accurate
- Both natives exist, round-trip confirmed
- Regression: 17/17 lang tests PASS

### Deferred to Phase 5c-2b (optional)
- Dynamic gutter width (based on digit count of last line)
- Wrap-aware scrollbar count (currently uses logical count)

### Next phase
- Phase 5c-3b: cursor/selection remap in wrapped mode
- Phase 6: ComboBox widget
- Tutorial Bab 34: Memo section update

## [1.11.31] - 2026-11-07

### Added (feature) -- GUI Widget Toolkit Phase 5c-3a (Word Wrap Infrastructure)
- **Word wrap toggle** -- gui2.memoSetWrap(id, enabled) / memoGetWrap(id)
- **Wrap calculation** -- long lines split at word boundaries based on
  available width (W - PadLeft - ScrollBarWidth - 8)
- **Visual lines cache** -- VisualLines: TStringList + VisualToLogical +
  VisualStartCol (parallel arrays)
- **RebuildVisualLines** -- called at Draw start, cheap when wrap OFF (1:1)
- **gui2.memoGetVisualLineCount(id)** -- debug count of wrapped lines
- **TGuiMemo.VisualLineCount** -- method returning cache count
- Draw renders VisualLines instead of Lines (wrap-aware rendering)

### Behavior (Phase 5c-3a scope)
- Wrap OFF (default): 1:1 logical-to-visual mapping, zero behavior change
- Wrap ON: long logical lines split into visual lines by word boundary
- Word-break at last space before overflow, char-break as fallback
- Toggle is per-widget, no global state

### Known limitations (deferred to Phase 5c-3b/c)
- Cursor navigation (UP/DOWN/LEFT/RIGHT) still uses LOGICAL lines
  - Wrapped text with cursor may look "off" visually
  - Default OFF protects existing behavior
- Click position (MY -> line) uses logical line
- Selection highlight uses logical lines (could span wrong visual rows)
- Scrollbar uses logical line count (Lines.Count), not visual
- EnsureCursorVisible uses logical line
- These need logical<->visual mapping helpers (Phase 5c-3b)

### Implementation
- TGuiMemo fields: WrapEnabled, VisualLines, VisualToLogical, VisualStartCol
- RebuildVisualLines method (wrap algorithm with TTF_SizeText measure)
- VisualLineCount method
- Draw: calls RebuildVisualLines, renders VisualLines loop
- Natives: memoSetWrap, memoGetWrap, memoGetVisualLineCount

### Verified
- Build: 50550 lines (+140 vs v1.11.30), EXIT 0
- Smoke test:
  - Single long string (no \n), memoSetText -> 1 logical line
  - wrap=false -> 1 visual line (initial)
  - wrap=true + draw -> 4 visual lines (word-boundary split)
  - wrap=false + draw -> 1 visual line (back to 1:1)
  - All 3 natives exist
- Regression: 17/17 lang tests PASS
- Visual confirmation deferred (user can test in X11)

### Next phase
- Phase 5c-3b: Cursor + selection remap (logical<->visual)
- Phase 5c-3c: Click + scrollbar + EnsureCursorVisible remap
- Phase 5c-2: Line numbers (simpler, can be before or after 5c-3)

## [1.11.30] - 2026-11-07

### Fixed (critical)
- **GUI hang after typing** -- root cause: SDL_RENDERER_PRESENTVSYNC flag.
  Termux:X11 doesn't emit VSYNC signals, so SDL_RenderPresent blocked
  indefinitely. Removed VSYNC flag; gui2.delay(16) provides pacing.
- **Cursor not symmetric with text** -- cursor height was H - 8 (widget)
  or LineHeight - 4 (hardcoded 16px). Now measures font glyph height
  once via TTF_SizeText('Ag') -> FontHeight field.
  - Edit cursor: aligned to text vertical center, height = FontHeight
  - Memo cursor: aligned to text vertical center, height = FontHeight
  - Selection highlight: height = FontHeight

### Added (feature)
- **Memo spacing configuration** -- configurable line spacing + padding
  - LineSpacing: extra space between lines (default 4)
  - PadTop: space above first line (default 4)
  - PadBottom: space below last line (default 4)
  - PadLeft: space at left edge (default 4)
  - gui2.memoSetSpacing(id, line_spacing, pad_top, pad_bottom, pad_left) -> bool
  - gui2.memoGetSpacing(id) -> {line_spacing, pad_top, pad_bottom, pad_left}
- Recompute LineHeight when spacing changes (if FontHeight known)
- VisibleLineCount uses (H - PadTop - PadBottom) instead of hardcoded H-8

### Implementation
- TGuiEdit.FontHeight field
- TGuiMemo.FontHeight, LineSpacing, PadTop, PadBottom, PadLeft fields
- Edit.Draw: TextY centered (Y + (H - FontHeight) div 2)
- Memo.Draw: text centered in LineHeight band, cursor aligned
- Memo.HandleMouse: MY - Y - PadTop, MX adjusted for PadLeft
- memoSetSpacing recomputes LineHeight

### Verified
- Build: 50410 lines (+59 vs v1.11.29), EXIT 0
- Interactive test on Termux:X11:
  - Typing without hang (VSYNC fix)
  - Cursor symmetric with glyph height
  - 230 events processed, no crash, clean shutdown
- Spacing smoke test: tight (spacing=0) vs loose (spacing=24)
  values set/get correctly
- Regression: 17/17 lang tests PASS

## [1.11.29] - 2026-11-06

### Added (feature) -- GUI Widget Toolkit Phase 5c-1 (Scrollbar)
- **Memo scrollbar** -- visual vertical scrollbar on right edge
  (only when content overflows visible area)
- **Scrollbar drag** -- click thumb/track to scroll, drag to navigate
- **Proportional thumb** -- height reflects visible/total ratio
- **ScrollTop API** -- gui2.memoSetScrollTop(id, n) / memoGetScrollTop(id)

### Behavior
- Track: dark gray (60, 60, 60), full height at right edge (12px wide)
- Thumb: light gray (150, 150, 150), proportional height, min 20px
- Click track position -> jump scroll to that position + start drag
- Drag (mousedown + mousemove) -> continuous scroll
- Release (mouseup) -> end drag
- Only renders when Lines.Count > VisibleLineCount

### Implementation
- TGuiMemo fields: ScrollBarWidth (12), DraggingScroll, DragStartY, DragStartTop
- HandleMouse: scrollbar click area detection (MX >= X + W - ScrollBarWidth)
- Drag state machine: DraggingScroll flag, DragStartY/DragStartTop for delta
- Delta calculation: NewTop := DragStartTop + (DeltaY * TotalLines) div H
- Draw: track + proportional thumb (ThumbH based on VisibleCount/Lines.Count)
- Natives: memoSetScrollTop, memoGetScrollTop (with clamping)

### Safety
- Clamp: NewTop in [0, Lines.Count - VisibleLineCount]
- Division guard: only divide if Lines.Count > VisibleLineCount
- Min thumb height 20px (prevents unreachable tiny thumb)

### Deferred to Phase 5c-2 / 5c-3
- Line numbers (gutter + offset)
- Word wrap (hard: affects cursor/selection/scroll)
- Horizontal scroll

### Verified
- Build: 50277 lines (+114 vs v1.11.28), EXIT 0
- Smoke test:
  - 20-line memo, height 120 (5 visible lines)
  - setScrollTop/getScrollTop work
  - Clamping: setScrollTop(100) -> 15 (max = 20-5)
  - widgetsDraw() no crash (scrollbar rendered)
  - Both natives exist
- Regression: 17/17 lang tests PASS
- Interactive drag test deferred to X11 session

## [1.11.28] - 2026-11-06

### Added (feature) -- GUI Widget Toolkit Phase 5b (Memo selection)
- **Cross-line text selection** -- SHIFT+arrows extend, plain arrows clear
- **Selection visual** -- blue highlight across line boundaries
- **Ctrl+A/C/X/V** -- select all, copy, cut, paste (multi-line)
- **Delete range** -- BACKSPACE/DELETE deletes selection if exists
- **Replace selection** -- typing replaces selected range
- **Selection API** -- gui2.memoGetSelection(id) -> {start_line, start_col,
  end_line, end_col} or {-1}* when no selection

### Keyboard behavior
- SHIFT+LEFT/RIGHT/UP/DOWN: extend selection from anchor
- SHIFT+HOME/END: extend to line start/end
- Plain arrows/HOME/END: clear selection, move cursor
- Ctrl+A: anchor (0,0) -> cursor (last_line, length)
- Ctrl+C: copy selection (includes \n for multi-line) to clipboard
- Ctrl+X: copy + delete selection
- Ctrl+V: paste clipboard (splits by \n, inserts as new lines)
- BACKSPACE/DELETE: delete selection if exists, else single char / merge
- Text input: replace selection if exists, else insert at cursor

### Implementation
- TGuiMemo.SelAnchorLine / SelAnchorCol fields (-1 = no selection)
- MemoPosLess: (line, col) comparison
- MemoHasSelection / MemoSelRange / MemoClearSelection
- MemoGetSelectionText: joins lines with \n between
- MemoDeleteSelection: replaces range with joined first/last lines
- Draw: per-line highlight (clip to start_col on first line, end_col on last)
- Fixed VC assignment order (was after highlight loop, skipped first frame)

### UTF-8 awareness
- Col positions respect codepoint boundaries (inherited from Phase 5a)

### Deferred to Phase 5c
- Word wrap (long lines)
- Line numbers
- Horizontal scroll
- Reusable scrollbar visual
- Mouse drag selection

### Verified
- Build: 50163 lines (+291 vs v1.11.27), EXIT 0
- Smoke test:
  - 4-line memo created, text round-trip correct
  - memoGetSelection returns {-1,-1,-1,-1} initially
  - Cursor {line:3, col:6} accurate
  - widgetsDraw() no crash (VC order fix)
- Regression: 17/17 lang tests PASS
- Interactive multi-line selection test deferred to X11 keyboard session

## [1.11.27] - 2026-11-06

### Added (feature) -- GUI Widget Toolkit Phase 5a (Memo basic)
- **TGuiMemo** widget -- multi-line text editor
- Multi-line buffer via TStringList (one entry per line)
- Cursor (Line, Col) tracking with auto-scroll
- ENTER: split line at cursor
- BACKSPACE: delete prev char OR merge with previous line
- DELETE: delete next char OR merge with next line
- LEFT/RIGHT: wrap across line boundaries
- UP/DOWN: change line, clamp col to line length
- HOME/END: col to 0 / line length
- Click: line from MY, col from MX (UTF-8 aware)
- Vertical scroll (ScrollTop) with auto-visible cursor

### Natives (4)
- **gui2.memo(x, y, w, h, [initial], [r], [g], [b])** -> widget id
- **gui2.memoGetText(id)** -> str (lines joined by \n)
- **gui2.memoSetText(id, str)** -> bool (split by \n, cursor to end)
- **gui2.memoGetCursor(id)** -> {line, col}

### Implementation
- TGuiMemo class (Lines, CursorLine, CursorCol, ScrollTop, LineHeight)
- SplitFromText / JoinToText helpers
- EnsureCursorVisible / VisibleLineCount helpers
- GuiMemoCursorColFromX helper (measure prefix widths per line)
- Draw: viewport culling (only visible lines), cursor only when focused

### UTF-8 awareness
- Col position uses codepoint boundaries
- Verified: multi-line unicode round-trip (accented + CJK)

### Deferred to Phase 5b/5c
- Selection across lines
- Clipboard for multi-line
- Word wrap, line numbers, scrollbar visual

### Verified
- Build: 49872 lines (+474 vs v1.11.26), EXIT 0
- Smoke test: 2 memos, multi-line round-trip, cursor accuracy,
  unicode preserved, all 4 natives exist
- Regression: 17/17 lang tests PASS
- Interactive multi-line editing test deferred to X11 keyboard session

## [1.11.26] - 2026-11-06

### Added (feature) -- GUI Widget Toolkit Phase 4c-2 (Clipboard)
- **Ctrl+C / Ctrl+V / Ctrl+X** -- copy, paste, cut in Edit widget
- **Ctrl+A** -- select all
- **SDL clipboard bindings** -- SDL_GetClipboardText, SDL_SetClipboardText,
  SDL_free (loaded in GuiSDLLoadLib)

### Behavior
- Ctrl+A: select entire text (SelAnchor=0, CursorPos=Length)
- Ctrl+C: copy selection to system clipboard (no-op if no selection)
- Ctrl+X: copy selection + delete it (no-op if no selection)
- Ctrl+V: paste clipboard at cursor (replaces selection if exists)
- Ctrl+letter skips HandleText path (prevents "c" being typed when Ctrl+C pressed)

### Implementation
- TGuiSDLState fields: pGetClipboardText, pSetClipboardText, pSDLFree
- GuiClipboardGet(St): read + free (SDL_free after) + 1MB safety cap
- GuiClipboardSet(St, S): write to system clipboard
- TGuiEdit.HandleKey: CtrlHeld check + Ctrl+A/C/X/V handlers
- TGuiEdit.HandleText: skip when Ctrl held (avoid double-typing)

### Safety
- GuiClipboardGet: 1MB cap (prevent runaway), SDL_free in finally
- Empty clipboard: no-op (no cursor advance)
- No selection on C/X: no-op (return true, no action)
- Exception safety: try/except in Set (false on error)

### Deferred to Phase 4c-3 / 5
- Mouse drag selection
- Multi-line clipboard (Phase 5 Memo)
- Undo/redo history
- Cut visual feedback

### Verified
- Build: 49398 lines (+98 vs v1.11.25), EXIT 0
- Smoke test (X11 ZINK):
  - Edit widget created, text get/set works
  - Selection API returns {-1, -1} initial
  - widgetsDraw() no crash
  - Native clipboard functions compiled (bindings loaded)
- Regression: 17/17 lang tests PASS
- Interactive Ctrl+C/V/X test deferred to X11 keyboard session

## [1.11.25] - 2026-11-06

### Added (feature) -- GUI Widget Toolkit Phase 4c (Selection)
- **Text selection** -- SHIFT+LEFT/RIGHT extends selection
- **Selection visual** -- blue highlight behind selected text
- **Delete range** -- BACKSPACE/DELETE deletes whole selection if exists
- **Replace selection** -- typing replaces selected range
- **Selection API** -- gui2.editGetSelection(id) -> {start, finish} or
  {start: -1, finish: -1} when no selection
- **SelAnchor field** -- TGuiEdit.SelAnchor: Integer (-1 = no selection)

### Keyboard behavior
- Plain LEFT/RIGHT: clear selection, move cursor
- SHIFT+LEFT/RIGHT: extend selection from anchor
- HOME/END: clear selection, jump to start/end
- SHIFT+HOME/END: extend selection to start/end
- BACKSPACE: delete selection if exists, else delete previous char
- DELETE: delete selection if exists, else delete next char
- Text input: replace selection if exists, else insert at cursor

### Implementation
- TGuiEdit.SelAnchor field (init -1)
- GuiEditSelStart / GuiEditSelEnd / GuiEditHasSelection / GuiEditDeleteSelection
- TGuiEdit.HandleKey: ShiftHeld := (ModState and KMOD_SHIFT) <> 0
- TGuiEdit.HandleText: GuiEditDeleteSelection before insert
- TGuiEdit.Draw: blue highlight (50, 100, 180) before text render

### Naming note
- Field named "finish" not "end" in dict return -- "end" is Pascal reserved
  keyword, cannot be used in sel.end expression.

### Deferred to Phase 4c-2
- Clipboard (Ctrl+C/V/X) -- needs SDL_GetClipboardText /
  SDL_SetClipboardText bindings + Ctrl modifier handling
- Mouse drag selection
- Multi-line selection (Phase 5 Memo)

### Verified
- Build: ~49,300 lines (+~70 vs v1.11.24), EXIT 0
- Smoke test (X11 ZINK):
  - Edit created with initial text
  - editGetSelection returns {-1, -1} initially (no selection)
  - widgetsDraw() no crash (highlight code path inactive when no selection)
  - API exists
- Regression: 17/17 lang tests PASS
- Interactive selection test (SHIFT+arrow, delete range, replace) deferred to
  next X11 keyboard session

## [1.11.24] - 2026-11-05

### Added (feature) -- GUI Widget Toolkit Phase 4b (Edit Polish)
- **Click-to-focus + cursor positioning** -- click anywhere in Edit widget,
  cursor jumps to nearest codepoint (UTF-8 aware)
- **Per-widget Focused field** -- TGuiWidget.Focused: Boolean, synced from
  Window.FocusedWidgetID via GuiSyncFocused helper
- **Focus indicator** -- Button shows brighter yellow border when focused
  (visual feedback for Tab navigation)
- **Cursor gated by focus** -- Edit cursor bar only visible when focused
  (was always visible Phase 4a workaround)
- **DELETE key** -- delete codepoint AFTER cursor
- **HOME key** -- cursor to start of text
- **END key** -- cursor to end of text

### Implementation
- GuiSyncFocused(W) -- iterate widgets, set Focused := (ID = W.FocusedWidgetID)
  - Called from GuiFocusNext, Native_Gui2_WidgetFocus, GuiDispatchMouse
- GuiEditCursorFromX(St, Edit, MX) -- measure prefix widths, pick closest
  codepoint boundary from click X
- TGuiEdit.HandleMouse override -- mousedown sets cursor from MX, auto-focus
  via existing GuiDispatchMouse path
- GuiKeyName: HOME (1073741898), END (1073741901) added
- TGuiEdit.HandleKey: DELETE, HOME, END handlers (UTF-8 aware)

### Verified
- Build: 49126 lines, EXIT 0
- Smoke test (X11 ZINK):
  - 2 edits + 1 button created
  - Focus chain: 0 -> 1 -> 2 -> 3 -> 1 (wrap)
  - widgetsDraw() no crash (focus gate, focus indicator)
- Regression: 17/17 lang tests PASS
- Interactive visual test (click cursor position, DELETE, HOME/END) deferred
  to next session with X11

### Known limitations (Phase 4c)
- No text selection (SHIFT+arrow)
- No clipboard (Ctrl+C/V/X)
- No horizontal scroll (long text)
- No cursor blink animation

## [1.11.23] - 2026-11-05

### Fixed (docs)
- **Bab 34 font requirement missing** -- manual visual test revealed that
  all text rendering (button caption, edit text, `gui2.text()`) is
  invisible without `gui2.setFont()`. Docs did not mention this.
- Fixed `gui2.text()` arg order in 34.6 Todo example (was
  `text("- " + t, 50, y, ...)` -- string as first arg instead of x,y).
- Added warning section after 34.1 -- "Wajib: setup font sebelum render
  apapun" with required order: `init` -> `setFont` -> `window`.
- Added `gui2.setFont(...)` to all code examples in Bab 34:
  - 34.2 Button click counter
  - 34.3 Edit minimal example (var inp = ...)
  - 34.3 Edit callback example (inp = ...)
  - 34.5 Focus form
  - 34.6 Todo full example

### Verified
- Manual visual test with X11 (Termux:X11) confirmed:
  - Window renders (500x400 dark background)
  - Edit field visible with cursor bar (after setFont)
  - Button visible with caption centered
  - Typing into edit works (text visible + cursor advance)
  - Click Add button -> callback fires -> edit clears -> task appears
  - "hello hello dog" full round-trip: typed -> captured -> added -> cleared
- Grep verify: 6 setFont instances in Bab 34 (1 warning + 5 examples)

### Backlog
- Production fix idea (Phase 4b): `gui2.init` should warn/error if
  setFont not called before widget creation, OR auto-load default font.
- Edit click-to-focus bug confirmed (requires widgetFocus workaround) --
  Phase 4b will add TGuiEdit.HandleMouse override for click positioning.

## [1.11.22] - 2026-11-04

### Docs (tutorial)
- **Bab 34 -- GUI Widgets** added (351 lines):
  - 34.1 Konsep: Primitives vs Widgets
  - 34.2 Button Widget (click counter example, onClick callback)
  - 34.3 Edit Widget (UTF-8 text input, focus, get/set)
  - 34.4 Event Loop Pattern (poll -> dispatch -> draw -> present)
  - 34.5 Focus Navigation (Tab/Shift+Tab cycling)
  - 34.6 Limitations v1 + Todo GUI full example

Covers all shipped widget APIs (v1.11.14 -> v1.11.21):
- gui2.button / buttonSetCaption / buttonGetCaption / buttonOnClick
  / buttonClearOnClick
- gui2.edit / editGetText / editSetText
- gui2.widgetsDraw / widgetCount / widgetFocus / widgetGetFocused
  / widgetFocusNext / widgetDestroy / widgetSetPos / widgetSetSize
  / widgetSetVisible / widgetSetEnabled / widgetGetBounds
  / widgetGetClicks / widgetGetKeyCount
- gui2.textInputEnabled / keyDown

Full example: Todo GUI (button + edit + list rendering via primitives).

Tutorial now 5,692 lines (was 5,338) with Bab 1-34 complete.

### Next phases
- Phase 4b: Edit selection + clipboard + navigation
- Phase 5: Memo (multi-line)
- Phase 6+: ComboBox, ListBox, Checkbox, Radio, Scrollbar, Layout

See docs/gui_widgets/phase_plan.md on feat/gui-widgets.

## [1.11.21] - 2026-11-04

### Added (feature) -- GUI Widget Toolkit Phase 4a (Edit Basic)
- **TGuiEdit** widget -- single-line text input
- UTF-8 aware text buffer (EditText: string)
- Cursor position (CursorPos: byte index)
- Typing via HandleText (SDL_TEXTINPUT dispatched to focused Edit)
- BACKSPACE deletes previous UTF-8 codepoint
- LEFT/RIGHT arrow moves cursor by UTF-8 codepoint
- Visual: background rect + border + text render + cursor line

### Natives (3)
- **gui2.edit(x, y, w, [initial], [r], [g], [b])** -> widget id
- **gui2.editGetText(id)** -> str
- **gui2.editSetText(id, str)** -> bool (cursor at end)

### UTF-8 Helpers
- Utf8PrevChar(S, Pos) -- byte position of previous codepoint
- Utf8NextChar(S, Pos) -- byte position of next codepoint
- Multibyte safe: backspace/arrow respect UTF-8 boundaries
- Verified with "héllo 中文" (mixed ASCII + accented + CJK)

### Cursor rendering
- Phase 4a: always visible (2px white vertical bar)
- Uses pRenderFillRect (avoid missing pRenderDrawLine binding)
- Position: after rendered prefix text width (TTF_SizeText measure)
- Focus-based visibility deferred to Phase 4b

### Deferred to Phase 4b+
- DELETE key (delete at cursor)
- HOME/END (cursor to start/end)
- Mouse click to position cursor
- Text selection (SHIFT+arrow)
- Clipboard (Ctrl+C/V/X)
- Horizontal scroll (long text)
- Cursor blink animation
- Focus-based cursor visibility

### Verified
- Build: 48995 lines (+144 vs v1.11.20), EXIT 0
- Smoke test (X11 ZINK):
  - 2 Edit widgets created
  - Text storage: initial + editSetText work
  - Unicode preserved: "héllo 中文" round-trip
  - widgetsDraw() renders background + text + cursor (no crash)
  - All natives exist
- Regression: 17/17 lang tests PASS

### Next phase
- Phase 4b: navigation (DELETE, HOME/END, mouse position, selection)
- Phase 5: Memo (multi-line)

See docs/gui_widgets/phase_plan.md on feat/gui-widgets.

## [1.11.20] - 2026-11-04

### Added (feature) -- GUI Widget Toolkit Phase 3c (onClick Callback)
- **Button onClick callback** -- user Pascal function fires on click or
  Enter/Space activation. Optional per button.
- **gui2.buttonOnClick(id, fn)** -> bool -- attach callback
- **gui2.buttonClearOnClick(id)** -> bool -- detach callback

### Architecture (mini-VM invoke pattern)
- GuiInvokeCallback(Cb, CallEnv) -- extracted from InvokeSignalCallbacks
  pattern:
  - Create mini-VM with Cb.ClosureEnv or CallEnv.GetGlobal
  - Build 3-instruction chunk: opcConstant(Cb), opcCall(0), opcReturn
  - Run mini-VM, free result
  - Exceptions swallowed (GUI loop must not crash on callback error)
- GGuiPollCallEnv: TSymbolTable -- global set by poll(), read by
  HandleMouse/HandleKey for callback invocation
- TGuiButton.OnClick: TValue -- stored via Clone, freed in destructor
- Callback fires from: HandleMouse (on click), HandleKey (Enter/Space)

### Safety
- Callback errors caught + swallowed (no GUI crash)
- Mini-VM created fresh per invocation (no state leak)
- TValue.Clone on store (survives source frame lifetime)
- Cleared + freed in destructor + buttonClearOnClick

### Deferred
- onClick with arguments (currently 0-arg callback)
- onClick return value handling

### Verified
- Build: 48851 lines (+151 vs v1.11.19), EXIT 0
- API smoke test (X11 ZINK):
  - 2 buttons created
  - buttonOnClick returns true for both (callback stored)
  - buttonClearOnClick returns true (callback cleared)
  - All natives exist
  - No crash
- Regression: 17/17 lang tests PASS
- Full click test (actual mouse trigger) deferred to manual X11 verification

### Next phase
- Manual visual verification (caption rendering + actual click callback)
- Phase 4: Edit widget (2 sesi)
- Phase 5: Memo widget

See docs/gui_widgets/phase_plan.md on feat/gui-widgets.

## [1.11.19] - 2026-11-03

### Added (feature) -- GUI Widget Toolkit Phase 3b (Polish)
- **Button caption rendering** -- TGuiButton.Draw renders Caption text
  centered on button (was deferred in Phase 3)
- **Hover state tracking** -- Hovered flag updated on mousemove for all
  widgets (moved from TGuiButton-specific to TGuiWidget base)
- **GuiDrawTextAt helper** -- extracted from Native_Gui2_Text for reuse
  by widgets (TTF render + texture + present, self-contained)

### Architecture
- GuiDrawTextAt(St, X, Y, Text, R, G, B) -- reusable text render helper
  - Creates texture from surface, renders at (X, Y), frees texture/surface
  - Forward declared for use by TGuiButton.Draw (defined later in file)
- GuiUpdateHover(MX, MY) -- iterate widgets in focused window, set
  Hovered flag based on hit-test
  - Called from SDL_MOUSEMOTION poll hook
  - Skips invisible/disabled widgets (Hovered := False)
- Hovered: Boolean moved to TGuiWidget base class (all widgets can react)
- Button Draw state colors: normal / hover (lighter) / pressed (darker)

### Refactor
- Native_Gui2_Text simplified -- delegates to GuiDrawTextAt (removed ~30
  lines of duplicate texture/surface logic)
- TGuiButton no longer has Hovered field (inherited from base)

### Verified
- Build: 48700+ lines (~70 vs v1.11.18), EXIT 0
- Smoke test (X11 ZINK):
  - 2 buttons created, widgetsDraw() calls caption render (no crash)
  - Captions intact: 'Submit', 'Cancel'
  - Click counts still work
- Regression: 17/17 lang tests PASS
- Visual verification deferred to manual test (screenshot/visible window)

### Deferred to Phase 3c
- onClick callback (needs VM context design -- complex, separate session)

### Next phase
- Phase 3c: onClick callback (~1-2 sesi)
- Phase 4: Edit widget (2 sesi)
See docs/gui_widgets/phase_plan.md on feat/gui-widgets.

## [1.11.18] - 2026-11-03

### Added (feature) -- GUI Widget Toolkit Phase 3 (MVP MILESTONE)
- **TGuiButton** widget -- first visually actionable widget
- Click tracking (Pressed state, ClickCount)
- Hover state (Hovered field, updated via mousemove)
- Keyboard activation (Enter/Space when focused -> ClickCount)
- Caption text (display deferred to Phase 3b for TTF helper extraction)

### Natives (3)
- **gui2.button(x, y, w, h, caption, [r], [g], [b])** -> widget id
- **gui2.buttonSetCaption(id, str)** -> bool
- **gui2.buttonGetCaption(id)** -> str

### Implementation
- TGuiButton extends TGuiWidget with Caption, Hovered, Pressed state
- Draw: rect fill + border, state-based color (normal/hover/pressed)
- HandleMouse: press on mousedown, click on mouseup within bounds
- HandleKey: Enter/Space activation when focused
- Naming note: Caption (not Label) -- Pascal reserved word

### Verified
- Build: 48629 lines (+60 vs v1.11.17), EXIT 0
- Smoke test: 3 buttons created, captions, set/getCaption work,
  click counts 0 (no hardware input), bounds correct, all natives exist
- Regression: 17/17 lang tests PASS

### MVP STATUS: COMPLETE
Phase 1 (foundation) + 2a (infrastructure) + 2b (mouse) + 2c (keyboard)
+ 3 (Button) = working widget toolkit MVP.

User can now:
- Create clickable buttons with captions
- Detect clicks via gui2.widgetGetClicks(id)
- Navigate focus via Tab
- Activate buttons via Enter/Space

### Deferred
- Button caption text display (needs TTF helper refactor)
- onClick callback (needs VM context design -- Phase 3b)
- Hover detection (mousemove tracking to set Hovered flag)
- Edit widget (Phase 4)
- Memo widget (Phase 5)

See docs/gui_widgets/phase_plan.md on feat/gui-widgets.

## [1.11.17] - 2026-11-03

### Added (feature) -- GUI Widget Toolkit Phase 2c
- **Keyboard event dispatch** -- KEYDOWN/KEYUP route to FocusedWidgetID
- **Text input dispatch** -- SDL_TEXTINPUT routes to FocusedWidgetID
- **Focus chain** -- Tab / Shift+Tab navigation via gui2.widgetFocusNext()
- **Programmatic focus** -- gui2.widgetFocus(id)
- **Focus query** -- gui2.widgetGetFocused() -> focused id (0 = none)
- **Key tracking** -- gui2.widgetGetKeyCount(id), TGuiWidget.KeyCount field
- **TGuiWidget.Focusable: Boolean** (default True, widgets can opt-out)

### Architecture
- GuiFocusNext(Reverse) -- cycle focusable/visible/enabled widgets
  - Handles wrap-around (last -> first, first -> last for reverse)
  - Skips non-focusable widgets automatically
- GuiDispatchKey(Key, Down) -- route to focused widget HandleKey
- GuiDispatchText(UTF8) -- route to focused widget HandleText
- TAB key triggers GuiFocusNext (Shift+TAB = reverse), also dispatched
- TGuiPlaceholderWidget.HandleKey/HandleText -- increment KeyCount for testing

### poll() hooks
- SDL_KEYDOWN: track pressed keys + Tab navigation + GuiDispatchKey
- SDL_KEYUP: release pressed key + GuiDispatchKey(down=False)
- SDL_TEXTINPUT: GuiDispatchText to focused widget

### Verified
- Build: 48500+ lines (~174 vs v1.11.16), EXIT 0
- Phase 2c smoke test (X11 ZINK):
  - 3 placeholders created (ids 1, 2, 3)
  - Focus chain: 0 -> 1 -> 2 -> 3 -> 1 (wrap) -> 3 (reverse)
  - All 4 natives exist (widgetFocusNext, widgetFocus, widgetGetFocused, widgetGetKeyCount)
  - Key counts 0 (no hardware input in script test)
- Regression: 17/17 lang tests PASS

### MVP Status
Phase 1 + 2a + 2b + 2c = foundation complete. Next phase:
- Phase 3: Button widget (1 sesi) -- first visually actionable widget
- Then Edit (Phase 4), Memo (Phase 5), etc.

See docs/gui_widgets/phase_plan.md on feat/gui-widgets.

## [1.11.16] - 2026-11-03

### Added (feature) -- GUI Widget Toolkit Phase 2b
- **Mouse event dispatch** -- poll() mouse events now route to widgets
- **TGuiWidget.HandleMouse(MX, MY, Btn, Down): Boolean** virtual method
- **TGuiWidget.HandleKey(Key, Down): Boolean** virtual (declaration only)
- **TGuiWidget.HandleText(UTF8): Boolean** virtual (declaration only)
- **TGuiSDLWindow.FocusedWidgetID** + **MouseCaptureID** event state
- **TGuiWidget.ClickCount** tracking field
- **gui2.widgetGetClicks(id)** -> num -- read click count

### Architecture (Phase 2b scope)
- `GuiHitTest(MX, MY)` -- topmost widget at position (reverse z-order)
- `GuiDispatchMouse(MX, MY, Btn, Down)` -- route to captured widget first,
  else hit-test
- Mouse capture: mousedown inside widget sets MouseCaptureID; mouseup
  releases (enables drag semantics for future widgets)
- `FocusedWidgetID` set on mousedown (foundation for keyboard routing)
- `TGuiPlaceholderWidget.HandleMouse` -- increments ClickCount on mouseup
  within bounds (mimics onClick, used for testing)

### poll() hooks
- SDL_MOUSEMOTION: dispatches to captured widget (Down=true, drag path)
- SDL_MOUSEBUTTONDOWN: dispatch + capture
- SDL_MOUSEBUTTONUP: dispatch + release capture

### Deferred to Phase 2c (next session)
- Keyboard event dispatch (HandleKey routing to FocusedWidgetID)
- Text input dispatch (HandleText routing)
- Focus chain (Tab/Shift+Tab navigation via FocusNext)
- onClick callback wiring (currently only ClickCount for testing)

### Verified
- Build: 48326 lines (+133 vs v1.11.15), EXIT 0
- Phase 2b smoke test:
  - 2 placeholders created (ids 1, 2)
  - Fresh click counts = 0 (correct initial state)
  - widgetGetClicks API exists (not null)
  - Invalid id 999 returns 0 (graceful)
- Regression: 17/17 lang tests PASS
- Full interactive click test deferred to Phase 3 (Button, when visually actionable)

### Next phase
Phase 2c: keyboard dispatch + focus chain (1-2 sesi)
Phase 3: Button widget (1 sesi)
See docs/gui_widgets/phase_plan.md on feat/gui-widgets.

## [1.11.15] - 2026-11-02

### Added (feature) — GUI Widget Toolkit Phase 2a
- **TGuiWidget** abstract base class (ID, bounds, visible, enabled, Draw virtual)
- **TGuiPlaceholderWidget** minimal concrete widget (colored rect) for Phase 2a validation
- **TGuiSDLWindow.Widgets: TObjectList** per-window widget storage, auto-freed
- **gui2.placeholder(x, y, w, h, [r, g, b, a])** -> widget ID
- **gui2.widgetCount()** -> count in focused window
- **gui2.widgetsDraw()** -- call Draw on all widgets (visual)
- **gui2.widgetSetPos / widgetSetSize / widgetSetVisible / widgetSetEnabled**
- **gui2.widgetGetBounds(id)** -> {x, y, w, h} or null
- **gui2.widgetDestroy(id)** -> bool

### Architecture (Phase 2a scope)
- Global widget ID counter (NextWidgetID in TGuiSDLState)
- Per-window TObjectList owns widgets (auto-free on window destroy)
- GuiFindWidget(ID) helper -- cross-window lookup by ID
- Forward declaration for FPC reference-order requirement

### Deferred to Phase 2b (next session)
- Event dispatch: poll() -> hit-test -> HandleMouse/HandleKey/HandleText
- Focus chain (Tab/Shift+Tab navigation)
- Mouse capture state for drag
- These require TGuiWidget virtual methods for events (currently only Draw)

### Verified
- Build: 48193 lines (+197 vs v1.11.14), EXIT 0
- Widget API smoke test (X11 with ZINK software fallback):
  - widgetCount: 0 -> 2 -> 1 -> 0 (correct lifecycle)
  - bounds: x=10 y=10 w=100 h=50 initial, x=50 y=60 w=200 h=100 after setPos/Size
  - destroy returns true, count decrements
- Regression: 17/17 lang tests PASS

### Next phase
Phase 2b: event dispatch (2-3 sesi)
Phase 3: Button widget (1 sesi)
See docs/gui_widgets/phase_plan.md on feat/gui-widgets.

## [1.11.14] - 2026-11-02

### Added (feature) — GUI Widget Toolkit Phase 1 Foundation
- **SDL_TEXTINPUT event binding** — poll() now returns 'textinput:<utf8>'
  for actual character input (unicode, IME, compose). Previously only
  'key:<name>' events available, insufficient for text input widgets.
- **gui2.keyDown(name) -> bool** — persistent key state tracking.
  PressedKeys TStringList maintained in poll() via KEYDOWN/KEYUP events.
  Enables key repeat detection, hotkeys (Ctrl+S), game-like WASD input.
- **gui2.textInputEnabled(bool) -> bool** — toggle SDL_StartTextInput /
  SDL_StopTextInput. Controls on-screen keyboard on mobile (Termux).

### Root cause for adding
Probe for GUI widget toolkit (v1.13.0-plan) revealed SDL_TEXTINPUT not
bound in v1.11.13. Hard blocker for Edit/Memo/ComboBox widgets. Without
it: no unicode text, no IME, no compose input.

### Implementation
- TGuiSDLState: PressedKeys (TStringList, Sorted+dupIgnore), TextInputActive
- Bindings: pStartTextInput, pStopTextInput (loaded in EnsureInit)
- SDL_TEXTINPUT = $303 constant
- poll(): SDL_TEXTINPUT case reads UTF-8 from offset 12 (32 byte max)
- poll(): KEYDOWN tracks KeyName in PressedKeys, KEYUP releases
- Native_Gui2_KeyDown: case-insensitive lookup
- Native_Gui2_TextInputEnabled: calls SDL_StartTextInput/StopTextInput
- Registration: gui2.keyDown, gui2.textInputEnabled

### Verified
- Build: 47928 lines, EXIT 0
- API smoke test (no window):
  - gui2.init() -> true (SDL2 loaded)
  - gui2.keyDown('A') -> false (no keys pressed, native works)
  - gui2.textInputEnabled != null -> true (native exists)
- Regression: 17/17 lang tests PASS
- Full interactive text input test deferred to Phase 4 (needs X11 setup)

### Next phase
Phase 2: Widget base class + event dispatch (2-3 sesi)
See docs/gui_widgets/phase_plan.md on feat/gui-widgets branch.

## [1.11.13] - 2026-11-01

### Fixed (perf)
- **Re-specialization after JIT deopt**. Once a superinstruction hot-patched
  (e.g. opcAddNum) and deoptimized on type change, it stayed on opcAddNum
  forever -- every subsequent call went through the fallback duplicate
  code path (slower than generic opcAdd + type check).

### Root cause
- v1.11.12 deopt fix added fallback logic but did not reset OpCode. HitCount
  was already >= 200 so re-specialization block never triggers.

### Fix
- On deopt, reset OpCode to generic:
  - opcAddNum -> opcAdd
  - opcSubNum -> opcSub
  - opcMulNum -> opcMul
  - opcDivNum -> opcDiv
- Future executions take generic fast path instead of specialized-fallback
- HitCount >= 200 prevents re-specialization loop

### Verified
- Despec test: add(1, 2) 150x warmup -> add("a","b") triggers deopt,
  subsequent add("x","y") + add("p","q") use generic opcAdd (fast path)
- Regression: 17/17 lang tests PASS

### Backlog status
- Tier 2.5 full (fused cmp+jump) still deferred. Assessment this session:
  - opcLess runtime supports mixed types (numeric, string, coercion)
  - Fused variant would need deopt framework (fixed-size Code array,
    cannot re-expand 1 -> 2 instructions)
  - Risk medium-high (jump offset remap subtle bugs)
  - Effort 1.5-2h, needs fresh session
- This release is the **low-risk subset** of Tier 2.5: re-specialization
  fix (20 min, zero deopt risk).

## [1.11.12] - 2026-10-31

### Fixed
- **JIT deopt fatal error** in adaptive specialization path. Once
  hot-patch activated (100+ numeric hits), polymorphic arithmetic crashed
  with error 96/97/98/99 instead of gracefully falling back.

### Root cause
- opcAddNum / opcSubNum / opcMulNum / opcDivNum (superinstructions,
  Phase 2) assume both operands numeric. On type change, they called
  errMSG.callerror (fatal) instead of deoptimizing to generic path.
- Reachability: any function called 100+ times with numbers, then once
  with strings/objects/mixed -> FATAL.

### Implementation
- Replaced 4 fatal errMSG.callerror in else-branches with generic
  fallback (replicating opcAdd / opcSub, opcMul, opcDiv, opcMod
  generic logic):
  - opcAddNum -> fallback: string concat / array merge / __add__ magic
  - opcSubNum -> fallback: __sub__ magic
  - opcMulNum -> fallback: string multiply / __mul__ magic
  - opcDivNum -> fallback: __div__ magic

### Verified
- Deopt test: add(1, 2) called 150x (hot-patch) then add("hello", "world")
  and add("x=", 42) -- previously FATAL, now returns expected results
- Numeric path still works (specialized opcAddNum: add(1, 2) = 3)
- Regression: 17/17 lang tests PASS

### Backlog status
- **Register VM: OBSOLETE** for Tier 1+2. Superinstructions (Phase 2)
  and adaptive specialization (TypeFeedback + HitCount hot-patch) already
  implemented. Deopt bug was the only correctness gap -- now fixed.
- Tier 3 (full register VM) would be 1-2 weeks, 2-5x potential -- only
  worth pursuing if user reports specific perf bottleneck that
  superinstructions cannot solve.

## [1.11.11] - 2026-10-31

### Changed (perf)
- **Worker pool sleep cap reduced from 60s to 5s** in Native_HTTP_Get2
  rate-limiter path. Under concurrent get2Async to rate-limited hosts,
  workers were blocked up to 60s each by Sleep(WaitMs), causing worker
  pool starvation for WS/GUI/timer tasks.

### Behavior
- Backoff > 5s: fast-fail with clear error message
  ("rate limited (backoff Ns > 5s cap) -- retry from caller with backoff")
- Backoff <= 5s: worker sleeps, retries (existing behavior)
- Callers now responsible for caller-level retry with backoff on >5s cap
- Existing h2_ratelimit_backoff test still PASSES (backoff within 5s)

### Rationale
- Workers SHOULD NOT block long: standard pattern (Go net/http,
  Node async) is fast-fail + caller-side backoff, not worker-blocking
- 12x reduction in worst-case worker starvation (60s -> 5s)
- Zero async restructuring risk (1-line change)

### Deferred (premature optimization)
- Full async timer-deferral pattern (pre-check rate, schedule re-enqueue
  via event loop, worker never blocks). Complex (2-3h, async path
  fragile), only needed if user reports worker starvation >5s.

### Verified
- h2_ratelimit_backoff: err1 fast-fail + r2 status=200 recovery (EXIT 0)
- Stress mock log: 8 burst connections from 5 concurrent requests --
  workers dispatch concurrently (not blocked 16s+ by backoff)
- Regression: 17/17 lang tests PASS

## [1.11.10] - 2026-10-31

### Added (feature)
- **Last-Modified / If-Modified-Since** (RFC 7232 §3.3 + §3.4) -- completes
  HTTP caching for gui.serveDir. Combined with existing ETag/If-None-Match
  (v1.11.7).

### Behavior
- 200 response includes Last-Modified: <RFC 1123 GMT> (mtime of file)
- 304 via If-Modified-Since when file mtime <= client timestamp
- If-None-Match takes precedence over If-Modified-Since (RFC 7232 §6):
  - If both present: ETag must match for 304, IMS is ignored
  - If only IMS: IMS comparison determines 304
- Existing ETag/INM path unchanged

### Implementation
- GetFileMTime(Path): Int64 -- FileDateToDateTime + DateTimeToUnix(UTC)
- FormatRFC1123(UnixSecs): string -- "Sat, 31 Oct 2026 12:30:26 GMT"
  via UnixToDateTime(UTC) + DecodeDateTime + const day/month arrays
- ParseRFC1123(S): Int64 -- manual parse (no locale deps), EncodeDateTime
  + DateTimeToUnix(UTC)
- Static branch: add Last-Modified header, add IMS 304 branch gated on
  SIfNoneMatch = '' (INM precedence)

### Verified (5 smoke test scenarios)
- 200: Last-Modified: Sat, 31 Oct 2026 12:30:26 GMT (RFC 1123 format)
- 304 via If-None-Match: matching ETag -> 304, no body
- 304 via If-Modified-Since: file unchanged -> 304, no body
- 200 via If-Modified-Since: past date (2020) -> 200 + body
- 200 via wrong ETag + IMS present -> 200 (INM wins over IMS per RFC §6)
- Regression: 17/17 lang tests PASS

### RFC reference
- RFC 7232 §3.3: Last-Modified response header
- RFC 7232 §3.4: If-Modified-Since request header
- RFC 7232 §6: If-None-Match precedence over If-Modified-Since
- RFC 1123: date format "Sun, 06 Nov 1994 08:49:37 GMT"

## [1.11.9] - 2026-10-31

### Fixed
- **304 Not Modified response had Content-Type + Content-Length headers**
  (RFC 7232 §4.1 violation). Browser ignored it (no body in 304), but
  HTTP proxies/tools could be confused.

### Root cause
- pascak_http.pas IsBodyless computation did not include 304 -- server
  default Content-Type text/plain; charset=utf-8 and Content-Length: 0
  appended to 304 responses.
- Engine worker loop (pascak_engine.pas ApplyResponseDict +
  Worker_HandleClient) unconditionally added default Content-Type
  before raw build. Two separate sources, both needed guards.

### Implementation
- pascak_http.pas:621 -- extend IsBodyless to include Status = 304
  (skip Content-Length default)
- pascak_engine.pas:26705 -- guard ApplyResponseDict CT default with
  Resp.Status <> 304
- pascak_engine.pas:27084 -- guard worker loop CT default with
  StatusCode <> 304

### Verified (smoke test 3 scenarios)
- 200: ETag + Content-Type: text/html + Content-Length: 46 + body (unchanged)
- 304: ETag + Cache-Control: no-cache + Connection/Keep-Alive, NO
  Content-Type, NO Content-Length, empty body
- Regression: bash tests/run.sh lang -> 17/17 PASS

### RFC reference
- RFC 7232 §4.1: 304 response MUST NOT have message body; headers listed
  should be limited to Cache-Control, Content-Location, Date, ETag,
  Expires, Vary.

## [1.11.8] - 2026-10-31

### Fixed
- **SIGPIPE kills process (exit 141)** on send() to closed socket
- Root cause: SIGPIPE default disposition = terminate process. Client writing
  to peer-closed socket (e.g. after H2 GOAWAY, or HTTPS close without RST)
  received SIGPIPE and died with exit code 128 + 13 = 141.
- Fix: install no-op SIGPIPE handler at CLI entry (all modes: CLI, LSP,
  REPL, test, fmt, lint). send() now returns EPIPE instead of killing
  process.

### Implementation
- HandleSigPipeIgnoreCdecl(sig: cint); cdecl; -- no-op handler
- fpSignal(SIGPIPE, @HandleSigPipeIgnoreCdecl) in RunCLI body (right
  after begin, before any network I/O)
- Wrapped in IFDEF UNIX (Windows uses WSAEPIPE semantics, not signals)
- Removed attempted registration from InstallSignalHandlers -- that
  function only fires on user signal.on() call, too late for h2_auto_retry

### Verified (smoke test)
- Before fix: h2_auto_retry -> exit 141 at Request 2 (fresh conn close)
- After fix: h2_auto_retry -> exit 0, both requests complete:
  - Request 1: status=200, version=h2, body=OK-after-retry (GOAWAY retry)
  - Request 2: status2=200, body2=OK-after-retry (fresh conn)
  - Pool stats: hits=1, misses=4
- Regression: bash tests/run.sh lang -> 17/17 PASS

### Known minor (deferred)
- Output may be cut at SIGTERM flush if timeout sends SIGTERM during
  buffered output. Not SIGPIPE-related, cosmetic.

## [1.11.7] - 2026-10-31

### Added (feature)
- **GUI static file caching** -- ETag + If-None-Match + 304 Not Modified
- `gui.serveDir` responses now include:
  - `ETag: "<mtime_hex>-<size_hex>"` (strong, quoted)
  - `Cache-Control: no-cache` (must revalidate -- required for hot-reload correctness)
- `If-None-Match` matching ETag -> 304 Not Modified (no body, no file read)
- File change -> ETag changes -> fresh 200 (hot-reload preserved)

### Behavior
- First GET: `200 OK` + `ETag` + `Cache-Control: no-cache` + body
- Revalidate (matching ETag): `304 Not Modified` + no body (skip `ReadFileToString`)
- Revalidate (wrong ETag): `200 OK` + body
- File modified: new ETag -> `200 OK` + fresh body

### Implementation
- `GetFileETag(Path)` -- strong ETag from `FindFirst` mtime + size
- `ExtractReqHeader(Args, Name)` -- case-insensitive lookup (`if-none-match` == `If-None-Match`)
- Static branch: ETag/MIME computed first, 304 short-circuit skips file read
- `Cache-Control: no-cache` -- browser MUST revalidate every request (no stale during dev)

### Verified (smoke test)
- Test 1: initial GET -> 200 + ETag + Cache-Control
- Test 2: ETag extract -> `"000000006AE5D3E9-...-002E"`
- Test 3: If-None-Match matching -> 304 Not Modified + Content-Length: 0
- Test 4: wrong ETag -> 200 + body
- Test 5: file touched -> new ETag -> 200 + v2 body (hot-reload correctness)
- Bonus: hot-reload watcher still fires on change

### Known minor issue (deferred)
- 304 response includes `Content-Type: text/plain` (HTTP server default fallback).
  RFC 7232 says 304 should not have Content-Type. Browser ignores it; cosmetic only.
  Fix requires HTTP server writer touch (pascak_http.pas) -- defer to v1.11.8 if
  proxy/tooling complains.

## [1.11.6] - 2026-10-31

### Verified (LSP Phase 4)
- **textDocument/signatureHelp** fully functional (already implemented pre-session, verified runtime)
- signatureHelpProvider capability correctly declared (trigger: `(`, `,`)
- Runtime verified 5 scenarios:
  - Inside outer function args -> outer signature + param 0
  - Inside nested function args (before comma) -> inner signature + param 0
  - Inside nested function args (after comma) -> inner signature + param 1
  - Return from nested function -> outer signature + param 0
  - Not in call context -> nil

### Test fix
- tests/integration/lsp_sighelp.py: fix activeParameter expectation at char 16
  (after comma = param 1, not 0); strict PASS/FAIL assertions added

### Backlog
- LSP Phase 4 marked DONE -- was "pending" in stale backlog context but
  actually implemented. Pattern matches v1.2.6, v1.2.7, H2 4c: verify
  runtime > trust backlog label.

## [1.11.5] - 2026-10-31

### Docs (tutorial)
- **Bab 28.12** -- rewrite "Ringkasan API" from 19 fungsi (v0.10) to full 52 API reference
- Full signature tables per category:
  - Window & Lifecycle (13): init, window, newWindow, focusWindow, closeWindow, listWindows, getFocusedWindow, isOpen, close, quit, setTitle, poll, delay
  - Utility (2): getTicks, getScale
  - Hi-DPI (2, v1.10.0): setAutoScale, getAutoScale
  - Drawing (6): clear, present, rect, outlineRect, line, point
  - Input (5): mouseX, mouseY, mouseButton, keyMod, keyName
  - Text (3): setFont, text, measureText
  - Texture (5, v0.11.1): loadTexture, texSize, drawTexture, drawTextureScaled, freeTexture
  - Music (12, v0.11.2-v0.11.3): loadMusic, playMusic, pauseMusic, resumeMusic, stopMusic, freeMusic, musicPos, musicDuration, seekMusic, musicVolume, isMusicPlaying, isMusicPaused
  - Sound Effects (3, v0.11.2): loadSound, playSound, freeSound
- Examples list expanded: 6 -> 10 (added hidpi, multi_window, image_viewer, audio_demo)
- Cross-link Bab 27 (browser GUI) + Bab 33 (HTTP/2)

## [1.11.4] - 2026-10-31

### Test infrastructure
- **mock_server.py**: configurable enhance count via `MOCK_ENHANCE_N` env var (default 3)
- **mock_server.py**: proper h2 response on OK path (headers + body + end_stream)
- Per-test config: `h2_auto_retry` uses 1, `h2_ratelimit_backoff` uses 3

### Verified (H2 Session 4c)
- **Retry wrapper**: GOAWAY -> retry on fresh connection -> 200 OK (proven runtime)
- **Rate limiter**: ENHANCE_YOUR_CALM x 3 -> backoff -> retry success (proven runtime)
- **GOAWAY parse**: LastStreamID + error_code correctly extracted
- **Retryable classification**: ENHANCE_YOUR_CALM -> retryable=True

### Known issues (separate ticket)
- Client exit 141 (SIGPIPE) when writing to closed socket after final response -- not H2 4c blocker

## [1.11.3] - 2026-10-31

### Fixed (tutorial structure)
- **Bab 32 malformed** -- `### 32` was inside Bab 31; promoted to `## Bab 32 -- Hot-Reload & Dev Workflow` with subsections 32.1 (CLI --watch), 32.2 (Dev wrapper), 32.3 (Graceful chain)
- **Duplicate `### 31.13`** -- renumbered Function Param Destructuring to `### 31.14` (Optional Method stays 31.13)
- **`## Bonus -- HTTP/2 Client`** -- promoted to `## Bab 33 -- HTTP/2 Client`

### Changed
- Dev wrapper content (was `**Dev wrapper...**` bold) promoted to `### 32.2` proper heading
- Graceful chain content (was `**Graceful chain...**` bold) promoted to `### 32.3` proper heading
- TOC extended: Bab 32 (Hot-Reload) + Bab 33 (HTTP/2)

### Verified
- 11 structural check markers all clean (unique headings, no duplicates, no orphan content)
- Boundary sanity: 31.13->31.14, 31.14->Bab32, 32.3->Bab33 all smooth
- `## Latihan Lanjutan` preserved at tail
- Docs-only patch, no code change, no build

## [1.11.2] - 2026-10-31

### Docs (tutorial)
- **Bab 27.20** -- `gui.watch(handle, path)` (v1.11.0 asset hot-reload, programmatic)
- **Bab 27.21** -- `gui.serveDir(handle, path)` (v1.11.1 static serving + implicit hot-reload)
- TOC updated: Bab 29 (Optional Chaining), Bab 30 (Enum), Bab 31 (Destructuring) were missing

### Known debt (deferred to next docs session)
- Tutorial Bab 32 malformed (`### 32` inside Bab 31) -- restructure to `## Bab 32`
- Duplicate `### 31.13` (Optional Method v1.2.7 + Function Param v1.6.0) -- renumber to 31.13/31.14
- `## Bonus -- HTTP/2 Client` -- promote to `## Bab 33` for consistency

## [1.11.1] - 2026-10-31

### Added (feature)
- **`gui.serveDir(handle, path)`** - static file serving native. Serves files from `path` at HTTP GET, with `MimeTypeFromExt` Content-Type. Falls through to `App.HTML` when file not found (SPA pattern).
- **Recursive asset dir walk** - `HotWatch_AddAssetDir` now walks subdirectories (was single-level in v1.11.0).

### Behavior
- `GET /` -> `index.html` (implicit)
- `GET /foo.css` -> file with Content-Type text/css
- `GET /sub/app.js` -> nested file served
- `GET /nonexistent` -> 200 `App.HTML` fallback (SPA)
- `GET /../etc/passwd` -> traversal rejected, 200 `App.HTML` fallback (no leak)
- `gui.serveDir` implies hot-reload (auto-injects WS reload JS, auto-watches root) - `gui.watch` not needed

### Path Safety
- Reject `..` segments and #0 bytes
- Reject backslash (Windows path)
- Canonical ExpandFileName must prefix-match root
- Does NOT use GetSafeSandboxedPath (internal resolver; sandbox applies to user script fs.read, not HTTP serving)

### Implementation
- `TGuiApp.StaticRoot: string` field
- `Native_GUI_ServeDir` - validate dir, set StaticRoot, recursive watch, lazy WS inject
- `Native_GUI_HttpHandler` - pre-HTML static branch via ExtractReqPath + ResolveStaticFilePath + ReadFileToString
- `HotWatch_AddAssetDir` - recursive walk
- `ExtractReqPath`, `ResolveStaticFilePath`, `ReadFileToString` - helpers

### Verified
- Build: 47565 lines, EXIT 0
- Smoke test (5 scenario):
  - `/` -> 200 text/html
  - `/style.css` -> 200 text/css
  - `/sub/app.js` -> 200 application/javascript (recursive)
  - `/../etc/passwd` -> 200 HTML fallback (no traversal leak)
  - `/missing.txt` -> 200 HTML fallback (SPA pattern)
- Regression: 17/17 lang tests PASS

### Limitations
- No symlink resolution depth limit yet
- No caching headers (future)
- No range request support
- No 304 / If-Modified-Since

## [1.11.0] - 2026-10-31

### Added (feature)
- **`gui.watch(handle, path)`** — asset hot-reload native. Watch file or directory (single-level), trigger browser reload via WS on change. Script keeps running (no `Halt`).

### Behavior
- **Asset files** (`.html/.css/.js/.txt/...`) → broadcast `{"type":"reload"}` to browser clients, update snapshot, continue polling
- **Source files** (`.pas`) → existing behavior: broadcast + graceful shutdown + halt (for restart wrapper)
- Differentiated via `THotWatchFile.IsSource: Boolean` field
- WS reload JS injected lazily when `gui.watch` is called, even without `--watch` CLI flag

### Use Case
Browser GUI dev workflow: `gui.watch` monitors asset folder, browser auto-reloads on edit, pascak keeps running. Combine with external static server (live-server, python http.server, etc) for asset serving.

### Implementation
- `THotWatchFile.IsSource` — distinguishes source vs asset
- `HotWatch_AddFile(Path, IsSource: Boolean = True)` — extended signature
- `HotWatch_AddAssetDir(Dir): Boolean` — walk `*` (not just `*.pas`), single-level
- `EnsureHotWatchThread` — lazy start if watcher not yet running
- `Native_GUI_Watch` — new native, registered under `gui.watch`
- `THotWatchThread.Execute` — split path: asset=continue polling, source=halt
- `TGuiApp.HasAssetWatch` + `HotReloadInjected` — per-app inject state

### Verified
- **Build**: 47,449 lines compiled (+121 from baseline), EXIT 0, no warning
- **Runtime smoke test**: `gui.watch(1, ...)` → `added 1 asset(s)`, `injected WS reload JS`, `detected change`, `broadcast reload`, no halt
- **Regression**: 17/17 lang tests PASS
- **Scope**: Termux-only path hardcoded in example (cross-platform = future)

### Limitations
- Asset dir walk is **single-level** (no recursive subdirs yet — future)
- WS broadcast `0 client(s)` observed in smoke test (no browser opened) — expected; with real browser client, reload triggers
- Thread safety: `gui.watch` should be called **before** `gui.start()` (documented, no lock yet)

## [1.10.4] - 2026-10-29

### Added (opt-in performance)
- **`PASCAK_VM_FAST_STACK=1` env var** — bypass `TCriticalSection` locking on VM stack operations (Push/Pop/opcAdd/opcSub/opcMul/opcDiv/opcMod).
- **Benchmark win**: arith 1405ms → 1272ms (~9.5% improvement). Prior test (unconditional) showed 13.5%; current flag adds ~3% overhead but preserves safety default.

### Why opt-in
- VM is single-threaded by design (no concurrent GC thread, verified via grep of `RunGarbageCollection`/`TValue.Mark`/`ProcessGCZombies` — all called from main thread only)
- But lock exists as precaution (comment "KUNCI MUTLAK: Amankan dari GC Marking dan Mutasi" at opcSub was defensiveness, not requirement)
- **Default safe**: `FStackLockEnabled := True` (lock active, unchanged behavior)
- **Opt-in fast**: `PASCAK_VM_FAST_STACK=1` → `FStackLockEnabled := False`
- **Risk**: theoretical race if future code introduces concurrent stack access. Current codebase analyzed safe, but conservative default protects against future regressions.

### Implementation
- `TVM.FStackLockEnabled: Boolean` field
- `TVM.Create` reads env var
- 4 conditional lock sites: Push, Pop, opcAdd fast-path, opcSub/Mul/Div/Mod fast-path
- Non-fast-path opcodes (opcGetIndex, array ops, etc.) still use lock unconditionally — unchanged.

### Verified
- **Default mode**: 1405ms arith, 17/17 lang tests
- **Fast mode**: 1272ms avg (1252-1302 range), 17/17 lang tests
- **Fast mode integration**:
  - Async http.get2Async: PASS
  - GUI2 DPI: PASS (scale detect + autoScale)
  - Hotreload graceful shutdown: PASS
- **5× stability**: 1252-1302ms, no variance explosion

### Performance context
- v1.9.3 baseline (before this): 1393ms
- v1.10.4 default: 1405ms (unchanged — lock still default)
- v1.10.4 fast mode: 1272ms (-8.7% vs v1.9.3, -9.5% vs v1.10.4 default)

### Production guidance
- **Leave default** unless profiling shows stack lock as bottleneck in your workload
- Fast mode safe for: pure compute scripts, single-request handlers, synchronous flows
- Fast mode risky for: long-running servers with hot path contention (theoretical, not observed)
- If enabling: monitor for crashes, especially under GC pressure from heavy object allocation

## [1.10.3] - 2026-10-29

### Added (docs)
- **Cookbook recipe #15** — Hi-DPI GUI auto-scaling pattern (`gui2.setAutoScale()` workflow, testing via `PASCAK_GUI2_SCALE=N`).
- **Cookbook recipe #16** — Optional chaining patterns (safe nested read, array access, null-safe assign, short-circuit RHS with side-effect skip).

### Coverage
- Recipe #15: covers v1.10.0 Hi-DPI feature end-to-end
- Recipe #16: covers all optional chaining family (v1.1.0 `?.`, v1.2.7 `?.method()`, v1.6.2 `?:=`, v1.10.2 `?.[]`)
- Both recipes include gotchas, security warnings, anti-patterns

### Cookbook
- 14 → 16 recipes (1553 lines)
- Daftar Resep updated

## [1.10.2] - 2026-10-29

### Added
- **Null-safe array index access** — `obj?.[idx]` (read) and `obj?.[idx] := value` (assign). Consistent with v1.1.0 `?.` and v1.6.2 `obj?.prop := value`.
- Chained chains work: `obj?.list?.[1]`, `n?.a?.[0] := value`.

### Behavior
- **Read** (`obj?.[idx]`): null target → null result, index expression not evaluated
- **Assign** (`obj?.[idx] := val`): null target → no-op, RHS not evaluated (short-circuit); non-null → normal assign
- Full parity with property-optional pattern

### Implementation
- `TArrayAccessNode.IsOptional` field + ctor param.
- `TArrayAssignNode.IsOptional` field + ctor param.
- ParseFactor `?.` block: detect `[` before identifier → build `TArrayAccessNode(IsOptional=True)`.
- ParseStatement `?.` block: same for assignment context.
- ParseStatement array-assign: capture `IsOptional` from `TArrayAccessNode` → pass to `TArrayAssignNode`.
- Compiler `TArrayAccessNode`/`TArrayAssignNode`: optional → `opcJumpIfNull` guard with 2-jump pattern (same as v1.6.2).

### Verified (10 test cases)
- Read: non-null array, null, nested `obj?.list?.[1]`, null mid-chain
- Assign: non-null, null-safe, RHS side-effect = 0 on null, 1 on non-null
- All 16 prior language tests still PASS + 1 new test = **17/17**

### Test suite
- `tests/lang/v1102_optional_index.pas` — 10 case coverage

## [1.10.1] - 2026-10-29

### Added
- **Consolidated test infrastructure** — `tests/` directory with unified runner, replacing scattered `$HOME/test_*.pas` files.

### Structure
    tests/
    ├── run.sh          # Unified runner
    ├── helpers.sh      # Shared setup (binary copy to $HOME, exec-safe)
    ├── lang/           # 16 language feature tests (deterministic PASS/FAIL)
    ├── integration/    # 11 network/GUI/LSP tests (manual setup)
    ├── fixtures/       # Mock servers, certs, hotreload test data
    └── README.md       # Documentation

### Features
- **16/16 language tests** run with single command: `bash tests/run.sh lang`
- Marker-based PASS/FAIL (each test has unique output marker)
- Per-test timeout (20s default, override with `TEST_TIMEOUT=N`)
- Auto-copy binary to `$HOME/pascak_test` (Termux `/storage/` = noexec)
- Filter modes: `lang`, `integration`, single `.pas` file
- `PASCAK_BIN=` env override for custom binary path

### Verified
- All 16 language tests PASS
- Runner works from `/storage/` path (via `bash`, `-f` check, `$HOME` exec)

### Notes
- Integration tests (h2, hotreload, LSP, GUI2 DPI) require manual mock setup — documented in `tests/README.md`
- Legacy `test/` directory (99 files, legacy diagnostics) left untouched

## [1.10.0] - 2026-10-29

### Added
- **Hi-DPI auto-scaling for native GUI (gui2)** — opt-in scaling for high-DPI displays (Retina, 4K, Android 2-3× scale). Previously `gui2.window(400, 300)` created physically 400×300, appearing tiny on 2× devices.
- `gui2.getScale()` — detect current DPI scale (1.0 = 96 DPI baseline, 2.0 = 2× display). Auto-detects via `SDL_GetDisplayDPI` (SDL 2.0.4+), fallback to 1.0.
- `gui2.setAutoScale(enable)` — toggle auto-scaling for drawing/mouse/font.
- `gui2.getAutoScale()` — query current state.
- `PASCAK_GUI2_SCALE` env override — for testing without real DPI device (e.g., `PASCAK_GUI2_SCALE=2`).

### Behavior (when autoScale = true)
- **Window size**: `gui2.window(400, 300)` → physical `(400*scale) x (300*scale)`, logical stays 400×300.
- **Drawing coords** (`rect`, `outlineRect`, `line`, `point`, `text`, `drawTextureScaled`): input logical × scale internally.
- **Mouse coords** (`mouseX`, `mouseY`): physical ÷ scale = logical returned to script.
- **Font size** (`setFont`): logical × scale in `TTF_OpenFont`.
- **Backward compat**: default `autoScale = false`, so no break for existing code.

### Implementation
- `TGuiSDLState`: `FDPIScale: Double`, `FAutoScale: Boolean`, `pGetDisplayDPI` function pointer.
- Helpers `Gui2DetectDPI`, `Gui2Scale`, `Gui2Unscale`.
- Lazy DPI detect on first `getScale()` call, and on `GuiSDLEnsureInit`.

### Verified
- Scale detection: env override=2→2.0, =3→3.0, real=1.0 (Termux X11 fallback).
- autoScale toggle: `setAutoScale(true)/false` reflected in `getAutoScale`.
- Window creation with autoScale on: physical size scales, window opens, drawing works.
- AutoScale off: existing behavior unchanged (no scaling).
- Performance: all benchmarks stable vs v1.9.4 (no regression).

### Example
`examples/gui2_hidpi.pas` — demo showing scale detection, autoScale, drawing, mouse.

## [1.9.4] - 2026-10-29

### Fixed
- **Server script hang on shutdown** — scripts using `gui.start(); sleep(N);` pattern (without `gui.run()`) hung indefinitely after body completed.

### Root cause
1. `runScript` unconditionally called `Engine.RunEventLoop` after exec. `RunLoop` is `repeat..until(IsShuttingDown=1)` — never breaks because shutdown signal is only set AFTER this call. Chicken-and-egg.
2. `gui.start()` sets an interval GUI poll timer, so `HasPendingTasks` stayed True even though user didn't request event processing.

### Fix
- `RunEventLoop` skips `RunLoop` when `HasPendingTasks = false`.
- `runScript` no longer implicitly enters event loop. Scripts that need live event processing use `gui.run()` or `Engine.RunEventLoop` explicitly.

### Behavior change (intentional)
- `gui.start() + sleep()` pattern now exits cleanly after sleep (~3s incl 1.5s cleanup).
- `gui.run()` pattern unchanged (blocks, drives event loop).
- If user wants live server, must call `gui.run()`.

### Verified
- `gui.start(); sleep(1)` — exits cleanly (was infinite hang)
- `gui.run()` + watcher — graceful shutdown works
- async `http.get2Async` — works
- Pure CLI `hi.pas` — 45ms startup unchanged
- 17/18 language regression tests PASS (v129/v130 require mock server)

### Performance
- No perf impact. Benchmark medians stable within noise vs v1.9.3.

## [1.9.3] - 2026-10-29

### Performance
- **Conditional WS poll** — `TEventLoop.RunLoop` uses `Tick(0)` (non-blocking) when no WS clients and no pending tasks, `Tick(20)` only when tasks/clients need waiting.
- **Startup: 68ms -> 45ms** (-34% vs v1.9.2).
- **Cumulative v1.8.0 -> v1.9.3**: JSON 11.1x, Array 6.8x, String 2.8x, Arith 2.4x, Calls 2.1x, Dict 1.5x, Startup 44x.

### Verified
- GUI scripts (`gui.run()`) still block correctly on WS clients.
- Async scripts (`http.get2Async`) still work (FTasks.Count > 0 triggers Tick(20)).
- Pure CLI scripts (`hi.pas`) get 45ms startup.
- Eager worker pool (`PASCAK_WORKER_POOL=eager`) unchanged (~250ms, thread join).
- All 130+ language tests pass (zero regression).

### Diminishing returns
~45ms is near-optimal for interpreter. Further optimization unrealistic without OS/compiler-level changes (static linking, preload, etc). Shift focus to feature work / bug fixes.

### Known limitations
- Server script without `gui.run()` (e.g., `gui.start(); sleep(N)`) hangs on shutdown — pre-existing, target v1.10+.

## [1.9.2] - 2026-10-29

### Performance
- **Fast CLI exit** — after `Engine.Free`, skip ~200ms of global cleanup (GC sweep, module registries, TLS/Net/Proc shutdown, lock frees) for scripts with no servers/GUI apps. OS reclaims memory on process exit.
- **Startup: 277ms -> 68ms** (-75% vs v1.9.1).
- **Cumulative v1.8.0 -> v1.9.2**: JSON 10.0x, Array 6.5x, String 2.8x, Arith 2.3x, Calls 2.1x, Dict 1.5x, Startup 29x.

### Added
- `PASCAK_FULL_CLEANUP=1` env var — opt-in full cleanup (preserve pre-v1.9.2 behavior).
- `PASCAK_TIMING=1` env var — print phase timings (globals_init / engine_create / exec / event_loop / engine_shutdown / engine_free / fast_exit / total).
- `benchmarks/results_v1.9.2.md` — cumulative analysis with per-phase timing.

### Safety
- Fast-exit guarded by `GHTTPServers.Count = 0`, `GWSServers.Count = 0`, `GGuiApps.Count = 0`.
- `RunShutdownHooks` already runs *before* fast-exit — user hooks not skipped.
- Server/GUI scripts still do full cleanup (graceful WS close, HTTP drain, TLS shutdown).
- Async scripts (pool only, no servers) — pool resources OS-reclaimed; verified `http.get2Async` completes correctly.

### Known limitations
- Server script without `gui.run()` (e.g., `gui.start(); sleep(2000);`) hangs on shutdown — pre-existing bug, not v1.9.2 regression, target v1.9.3.
- `event_loop: 21ms` fixed cost — possible minimal timer wait, investigate v1.9.3.

## [1.9.1] - 2026-10-29

### Performance
- **Lazy worker pool** — `TPascakEngine.InitializeRuntime` no longer spawns 8 eager worker threads at startup. Pool created on first async operation via `EnsureWorkerPoolForCtx`. Compute-only scripts never spawn threads.
- **Startup: 489ms -> 277ms** (-43% vs v1.9.0).
- **Cumulative v1.8.0 -> v1.9.1**: 2-5x speedup on compute benchmarks (Array 4.1x, JSON 5.1x, String 2.3x, Arith 2.0x).

### Added
- `PASCAK_WORKER_POOL=eager` env var — opt-in eager pool creation (for production servers that want pre-warmed workers).
- `EnsureWorkerPoolForCtx(Ctx)` helper — lazy-create function.
- `benchmarks/results_v1.9.1.md` — cumulative before/after analysis.

### Behavior preserved
- Async paths (`http.get2Async`, `http.listenAsync`, `spawn`) auto-create pool on first use (verified end-to-end).
- Teardown frees lazy-created pool via else-branch fallback.
- No regression on async workloads.

### Remaining (v1.9.2 target)
- Fixed ~277ms per exec: Engine.Create ~100ms + shutdown/GC ~140ms.
- Deferred native module registration + faster CLI exit potentially add another ~130ms savings.

## [1.9.0] - 2026-10-29

### Performance
- **~2x average speedup** across benchmarks (JSON 3.4x, Array 2.8x, String 1.9x, Arith 1.8x, Calls 1.7x, Dict 1.3x) via two targeted fixes to unconditional startup overhead.
- `pascak` with no args: 2.0s -> 30ms (66x).

### Fixed
- **Sleep(1500) unconditional in runScript finally** - fired even for pure compute scripts with no HTTP/WS servers. Now guarded by server-count check.
- **Script fallback ran test suite** - `cscript := scriptTest` dead assignment + `FileName := './storage/downloads/test.pas'` default caused every invocation with no args to run regression test. Replaced with proper `Usage:` print.

### Added
- **benchmarks/results_v1.9.0.md** — before/after comparison + per-op analysis.
- **benchmarks/README.md** references both baseline snapshots.

### Remaining overhead
- ~470ms fixed per exec (Engine.Create + native registration + shutdown GC). Target for v1.9.1.

## [1.8.0] - 2026-10-28

### Added
- **tools/pascak_dev.sh** - production-grade auto-restart wrapper for hot-reload. Combines v1.7.0 graceful shutdown with auto-restart.

Usage:
  tools/pascak_dev.sh <watch-spec> <script.pas> [extra pascak args]

Features: auto-restart on file change (exit 0) or error (exit 1/2),
SIGINT forwarded to child, 1s delay avoids TIME_WAIT, colored output,
PASCAK_BIN / RESTART_DELAY env overrides.

### Verified
Full graceful chain: watcher requests shutdown, gui.run returns naturally,
buffered output flushed, wrapper detects exit 0, restarts with fresh state.

### Deferred Indefinitely
True in-process re-execute (no process restart). GUI port TIME_WAIT +
fragmented global state + top-level var persistence = high risk vs
wrapper's zero-risk value.

## [1.7.0] - 2026-10-28

### Improved
- **Graceful shutdown for hot-reload** - `--watch`/`--hot` no longer uses abrupt `Halt(0)`. Watcher requests graceful shutdown via `IsShuttingDown` flag; `RunLoop` breaks naturally; post-`gui.run()` statements execute; shutdown hooks run; WS clients receive clean close frames; H2 pool closes cleanly.

### Implementation
- Watcher: `InterlockedExchange(IsShuttingDown, 1)` + 2s graceful window + `Halt(0)` fallback.
- `Flush(Output)` before Halt preserves buffered script output.

### Benefits
- No more dropped WS connections (clean onclose)
- No TLS/H2 shutdown errors
- User shutdown hooks execute
- Script statements after `gui.run()` run normally

### Verified
- `MARK3` printed after `gui.run()` returns -> RunLoop break works
- Buffered stdout flushed
- Main exits before 2s fallback (no 'window expired' log)
- ~4s total (2s touch + graceful break)

### Notes
- True in-process re-execute (no process restart) deferred to v1.8.0.

## [1.6.2] - 2026-10-28

### Added
- **Null-safe assignment** - `obj?.prop := value`. Non-null target: normal assign, RHS evaluated once. Null target: statement skipped, RHS NOT evaluated (short-circuit, no crash). Chains supported: `obj?.a?.b := value`.

### Implementation
- `TMemberAssignNode.IsOptional` + ctor param.
- ParseStatement postfix loop includes `ttOptionalDot`.
- Compiler emit: `opcJumpIfNull` before RHS compile (short-circuit).
- Non-optional branch unchanged.

### Verified
7 cases: non-null assign, null skip, nested null skip, nested non-null assign, RHS not-evaluated on null (side effect count), RHS evaluated once on non-null.

## [1.6.1] - 2026-10-28

### Added
- **Rest element in function param pattern** - `function f({a, b, ...rest})`, `function g([x, ...tail])`, `function h({cfg: {port, ...other}})` now supported.

### Implementation
- Splits rest path by last dot into prefix + leaf.
- Numeric leaf -> TArraySliceNode (array rest).
- String leaf -> TMethodCallNode(target, 'omit', siblings) - reuses v1.2.6 emit.
- Replaces v1.6.0 'belum support' error.

### Verified
4 cases: obj rest, array rest, nested rest, no-rest regression.

## [1.6.0] - 2026-10-28

### Added
- **Function parameter destructuring** — params can destructure objects/arrays:
  - `function f({a, b}, x) begin ... end`
  - `function g([x, y]) begin ... end`
  - `function h({cfg: {port}, u, v = 5}) begin ... end`
  - Mixed normal + pattern: `mixed(a, {b, c}, d)`

### Implementation
- `ParseFunctionDecl.AddParam` detects pattern, reuses `ParsePattern`.
- Synthetic param `__fp_N`, prelude `TVarDeclNode` chain at body start.
- Nested, defaults, multiple patterns, struct methods all supported.
- Zero compiler change (params become locals via existing AddLocal).

### Restrictions
- Rest element in pattern param: explicit error (v1.6.0).

### Verified
5 test cases: basic obj/array, nested+default, multiple patterns, mixed.

## [1.5.0] - 2026-10-28

### Added
- **LSP signature help** — `textDocument/signatureHelp` handler. Editor shows parameter hints when typing function call: `add(1, |2)` -> `function add(a, b)` with active parameter highlight.

### Implementation
- `HandleSignatureHelp`: backward scan from cursor for `(`, extract name, find `function NAME(...)` declaration across document, parse param list.
- Native fallback for builtins (`println`, `len`, `str`, `int`, `bool`, `range`, `sort`, `sleep`).
- `activeParameter` = comma count at paren depth 0.
- Capabilities: `signatureHelpProvider.triggerCharacters = ['(', ',']`.
- No vscode ext change needed (generic LSP auto-handles).

### Verified
Python LSP client test:
- init caps include `signatureHelpProvider`.
- `add(1, |)` -> `function add(a, b)` activeParameter 0/1 per comma.
- `println(|)` -> `println(value, ...)`.
- Outside call -> `null`.

## [1.4.2] - 2026-10-28

### Added
- **`--hot` flag** - implies `--watch` + auto-reloads browser GUI tabs. Broadcasts reload to WS clients, sleeps 300ms, exits cleanly. Injected JS `location.reload()`.

### Implementation
- `GHotMode` global + `--hot` CLI flag.
- `InjectHotReloadJS`: gui.serve appends script before `</body>`.
- `BroadcastHotReloadToGUI`: iterate GGuiApps, BroadcastToServer.
- Watcher: broadcast + Sleep(300) before Halt(0).

### Verified
Tests A/B/C: HTML 588->1047 bytes, broadcast executes, exit 0, elapsed 3s.

## [1.4.1] - 2026-10-28

### Added
- **Multi-file + directory watch** — `--watch` now accepts:
  - `--watch app.pas` (single, backward compat)
  - `--watch 'app.pas,lib.pas'` (comma-separated)
  - `--watch dir/` (all *.pas in directory, non-recursive)
  - `--watch 'dir/,extra.pas'` (mixed dir + file)

### Fixed
- **Spec vs script collision** — v1.4.0 bug where `--watch app.pas,lib.pas` was used as ScriptArg (broke script execution). Now `--watch` consumes next arg as SPEC; script remains separate positional.

### Implementation
- `THotWatchFile` record (Path + InitialAge + InitialSize per file).
- `HotWatch_IsDir`, `HotWatch_AddFile`, `HotWatch_AddDir`, `HotWatch_AddPath` helpers.
- `EnableHotWatch(spec)`: comma-split, walk dirs, spawn single thread.
- Watcher `Execute`: iterate all files, `Halt(0)` on first change.
- Validate-first: error before watcher thread starts if script missing.

### Verified
5 test cases: single, multi-file comma, dir mode, mixed dir+file, error (no script -> exit 1).

## [1.4.0] - 2026-10-28

### Added
- **`--watch` CLI flag** — hot-reload for dev workflow. Polls script file (mtime + size, 500ms). On change: prints `[hot-reload] detected change` and exits cleanly (0).

### Implementation
- `THotWatchThread`: background poller.
- `HotWatch_FileSize()` helper: FindFirst/TSearchRec wrapper.
- `EnableHotWatch(path)`: spawn thread with mtime+size snapshot.
- `RunCLI`: `--watch` flag -> `EnableHotWatch(ScriptArg)`.

### Verified
4 test cases: baseline, no-change, touch, content-change.

### Deferred
In-process re-execute (v1.4.1), WS browser reload (v1.4.2).

## [1.3.1] - 2026-10-28

### Added
- **Rate limiter backoff** on `H2_ERR_ENHANCE_YOUR_CALM` — per-host exponential backoff (1s, 2s, 4s, 8s, 16s) after consecutive throttling errors. Transparent to user code.

### Fixed
- **Post-wait GOAWAY classification** — `TH2Connection.Request()` post-wait path uses `FGoAwayErrCode` to enrich error message with proper code. Previously generic `code=0 fatal`.

### Implementation
- Globals: `G_H2RateList` + `G_H2RateLock` (thread-safe).
- `TH2RateEntry`: per-host state (backoff tick, consecutive, last access).
- `Native_HTTP_Get2` wrapper: rate check + Sleep + record + reset + 60s cap.

### Verified
- Mock H2 server 3 consecutive ENHANCE then success.
- req1: retryable, code=11 — error surfaced after 3 attempts.
- req2: sleeps ~4s (backoff), succeeds — total ~7s vs 1s pre-patch.

## [1.3.0] - 2026-10-27

### Fixed
- **HTTP/2 connection-level flow control** — client now sends connection-level `WINDOW_UPDATE` (stream 0) for every received DATA frame, in addition to the existing stream-level WINDOW_UPDATE. Previously, the connection window (initial 65535 bytes) was never replenished, causing the server to stall after sending ~64KB total across all streams.

### Verified
- Mock H2 server sends 128KB body -> client receives full body, status=200.
- Server log shows repeated `WINDOW_UPDATE stream=0 delta=16384` confirming client replenishes the connection window.

### Notes
- Per-stream flow control (v1.0.x) was already working; only the connection window was missing.
- No user-facing API change — transparent fix.

### Deferred (v1.3.1)
- Rate limiter backoff on `H2_ERR_ENHANCE_YOUR_CALM` (token bucket per host).

## [1.2.9] - 2026-10-27

### Added
- **Auto-retry** on retryable H2 errors — `http.get2` and `http.get2Async` now silently retry up to 3 attempts with exponential backoff (100ms, 200ms) on transient GOAWAY / connection-closed failures.
- `PASCAK_TLS_NO_VERIFY=1` env override — shared with HTTPS/1.1 path (existing) for TLS peer verify bypass. Used in tests only.

### Implementation
- `Native_HTTP_Get2` renamed to `Native_Http_Get2Impl` (unchanged body).
- New `Native_HTTP_Get2` wrapper handles retry logic.
- `get2Async` automatically inherits retry (via Native_HTTPSync2).

### Verified
- Mock H2 server (Python h2 + self-signed TLS, GOAWAY after N requests).
- E2E test: GOAWAY on first conn -> client silently retries -> 200 success.
- Server log confirms 2x ACCEPT + pool reuse after retry.

### Deferred (v1.3.0)
- Rate limiter backoff on H2_ERR_ENHANCE_YOUR_CALM (still needs token bucket)

## [1.2.8] - 2026-10-27

### Added
- **GOAWAY classification** — `http.get2` error message now distinguishes retryable vs fatal failures with H2 error code.
- `TH2Response.ErrorCode` + `TH2Response.Retryable` fields (public API for programmatic retry).
- `TH2Connection.FGoAwayErrCode` tracks RFC 7540 error code from GOAWAY frame.

### Behavior
- No change for happy path (http.get2 success -> status 200, pool reuse works).
- On failure, error message format:
  - Retryable: `request gagal (retryable, code=N) - <detail> — hint: retry on fresh connection`
  - Fatal: `request gagal (fatal, code=N) - <detail>`
- Retryable classification:
  - `H2_ERR_NO_ERROR` / `H2_ERR_ENHANCE_YOUR_CALM` -> retryable
  - Connection closed / reader thread unavailable -> retryable
  - Other H2 protocol errors -> fatal

### Deferred (v1.2.9)
- Auto-retry loop (needs mock GOAWAY server test infra)
- Rate limiter backoff on `H2_ERR_ENHANCE_YOUR_CALM`

### Regression
- 130/130 prior tests PASS + happy path verified.

## [1.2.7] - 2026-10-27

### Added
- **Optional method call** — `obj?.method()` and `obj?.method(args)` short-circuit on null target. Args not evaluated on null (short-circuit). Chains with property access: `obj?.prop?.method()`.

### Implementation
- `TMethodCallNode` extended with `IsOptional: Boolean`.
- Compiler emits `opcJumpIfNull` before method call when optional.
- VM unchanged — `opcJumpIfNull` already peek-only since v1.1.0.

### Regression
- 130/130 tests PASS (9 new v1.2.7 + 121 prior).

## [1.2.6] - 2026-10-27

### Added
- **Rest in nested destructuring** — `var {cfg: {host, ...rest}} = obj`, 2+ level `var {a: {b: {x, ...r}}} = obj`, array+obj mixed `var [first, {u, ...v}, last] = arr`.
- Emit path-aware: numeric rest leaf → slice, string rest leaf → omit siblings at that nesting level only.

### Refactored
- Unified rest emit logic (root and nested share one code path).
- Backward compatible: root-level rest identical to v1.2.5 behavior.

### Regression
- 121/121 tests PASS (18 new v1.2.6 + 103 prior).

## [1.2.5] - 2026-10-27

### Added
- **Object rest destructuring** — `var {a, b, ...rest} = obj` captures remaining keys into new dict. Combines with nested: `var {cfg: {h}, ...rest} = obj` excludes `cfg` top-level key from `rest`.

### Added (runtime)
- `dict.omit(keys_array)` native method — returns clone of dict excluding specified keys.

### Notes
- Object rest uses TMethodCallNode emit calling `__tmp.omit([known_keys])`.
- Array rest (v1.2.1) unchanged — still uses slice.
- Rest inside nested (`var {a: {b, ...r}}`): deferred to v1.2.6.

### Regression
- 103/103 tests PASS (18 new v1.2.5 + 85 prior).

## [1.2.4] - 2026-10-27

### Added
- **Arbitrary-depth nested destructuring** — `var {a: {b: {c: {d}}}} = obj` and beyond. Parser refactored to recursive `ParsePattern`.
- **Array-root nested** — `var [a, {u, v}, c] = arr`, `var [p, [q, r], s] = arr`, combined with rest `var [a, {b}, ...rest] = arr`.

### Refactored
- `TParser.ParsePattern` recursive helper replaces inline 2-level logic.
- Emit path iterator uses `StrToInt(path)` for array index; backward-compat.

### Notes
- Object rest (`var {a, ...rest} = obj`) still deferred (needs `dict.omit()`): v1.2.5.

### Regression
- 85/85 tests PASS (29 new v1.2.4 + 56 prior).

## [1.2.3] - 2026-10-26

### Added
- **2-level nested destructuring** — `var {a: {b: {c, d}}} = obj` and `var {a: {b: [x, y]}} = obj`. Extends v1.2.2 (1-level obj-root) up to 2 levels.

### Notes
- Deeper than 2 level, array-root nested, object rest, rest-inside-nested: deferred to v1.2.4.
- Emit refactored to iterate-all-dots path (backward compatible).

### Regression
- 14/14 v1.2.3 tests + 69/69 prior tests PASS.

## [1.2.2] - 2026-10-26

### Added
- **Nested destructuring (obj-root)** — `var {a: {b, c}} = obj` and `var {a: [x, y]} = obj`. Supports mixed flat+nested, multi-nested, nested with default, statement + top-level scope.

### Notes
- Array-root nested (`var [a, {b}] = arr`), rest inside nested, and deeper than 1 level: deferred to v1.2.3.

### Regression
- 19/19 nested tests PASS + 41/41 prior tests PASS.

## [1.2.1] - 2026-10-26

### Added
- **Array rest element** — `var [first, ...tail] = arr` captures remaining elements as array slice (reuses existing slice syntax `arr[start:]`). Rest must be last, no default allowed. Out-of-bounds → empty array.

### Notes
- Object rest (`var {a, ...rest} = obj`) and nested destructuring (`var {a: {b}} = obj`): planned for v1.2.2.

### Regression
- 10/10 new tests PASS + 31/31 prior tests PASS (Phase 1/2/3 + v1.2.0 defaults).

## [1.2.0] - 2026-10-26

### Added
- **Destructure defaults** — `var {a = 10, b = 20} = obj` (dan array equivalent `var [x = 0, y = 100] = arr`) provide fallback when key missing / index out-of-bounds. Defaults apply on `null` only; `0`, `""`, `false` pass through.
- **Enum in function scope** — `enum Status { OK, ERR }` now allowed inside function body or `begin` block (previously top-level only). Same desugar as top-level (dict + const).

### Notes
- Nested destructuring (`var {a: {b}} = obj`) and rest element (`var {a, ...rest} = obj`): planned for v1.2.1.

### Regression
- 21/21 v1.1.x tests PASS (Phase 1/2/3 unchanged) + 10/10 new v1.2.0 tests PASS.

## [1.1.1] - 2026-10-26

### Fixed
- **Optimizer hardening** — `TChunk.OptimizeBytecode` now recognizes `opcJumpIfNull`/`opcJumpIfNotNull` as jump opcodes in both jump-target marking and operand-remap phases. Prevents stack underflow recurrence if future features emit dead code that triggers useless-jump removal. Synergistic with Fix A (v1.1.0) which prevents the trigger, this Fix B hardens the optimizer for any future recurrence.

### Regression
- 21/21 tests PASS (Phase 1: 8, Phase 2: 5, Phase 3: 8) — zero behavior change for existing features.

## [1.1.0] - 2026-10-25

### Added
- **Optional chaining `?.`** — `user?.name`, `cfg?.db?.host`
- **Null-coalescing `??`** — `null ?? 42` = 42, `0 ?? 42` = 0
- **Enum** — `enum Color { Red, Green, Blue }` (auto-numbered 0..N-1, immutable)
- **Destructuring** — `var {a,b} = obj`, `var [x,y] = arr` (top-level + statement)

### Fixed
- Stack underflow on `null?.name` — stale `opcJumpIfNull` operand after optimizer dead-code removal
- Dict property access on missing key returns null (nil-safe)
- VM nil-safe guards on `opcJumpIfNull` / `opcJumpIfNotNull`


Semua perubahan penting pada Pascak VM dicatat di sini.

Format mengikuti [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versi mengikuti [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]

### Planned
- Register-based VM (tier-2 JIT)
- Concurrent GC
- HTTP/2 multiplexing (parallel requests via 1 connection)
- ChaCha20-Poly1305 cipher
- JSON Schema validation
- GUI: HTTPS localhost (self-signed)

### Backlog
- WebSocket client bidirectional bridge
- WASM target
- Package manager: HTTP registry
- GUI: dev-mode file watcher

---

## [0.6.0] — 2026-10-20

**Browser-Based GUI — HTTP + WS RPC bridge**

New `gui` module brings GUI to any Pascak app via local browser.
Zero external deps: HTML served from engine HTTP, JS bridges back
via WebSocket JSON-RPC. Works on Termux, Linux, macOS, Windows.
### Added

- **GUI (Browser-Based)** — new `gui` module, zero external deps:
  - `gui.create(port, [wsPort], [title]) -> handle`
  - `gui.serve(handle, html) -> bool` (auto-injects JS bridge script)
  - `gui.bind(handle, name, callback) -> bool` (register Pascal callback)
  - `gui.start(handle) -> bool` (bind HTTP + WS ports)
  - `gui.open(handle) -> bool` (spawn browser via termux-open-url/xdg-open)
  - `gui.run(handle)` (blocking event loop)
  - `gui.close(handle) -> bool` (cancels timer, clean shutdown)
  - Architecture: `http.serve` + auto `<script>` with
    `window.pascak.call(method, args) -> Promise`, JS↔Pascal via
    WebSocket JSON-RPC on separate port
  - HTTP accept driven by event-loop timer (poll), not blocking
  - `examples/hello_gui.pas` — counter demo with state in closure
  - `docs/pascak_api.md` §GUI (Browser-Based)

- **Handler type relaxations** — accept `dtNative` alongside `dtFunction`:
  - `http.serve` / `http.serveTLS` handler arg
  - `ws.serve` callbacks (`WSExtractHandlers`: onOpen/onMessage/onClose/onError)
  - WS client handlers (4×)
  - `Worker_HandleClient` (HTTP worker)
  - `CallWSCallback` (WS dispatch)
  - `TEventLoop.SetTimer` (for poll callback)

- **`NetAcceptTimeout` non-blocking** — `timeout=0` now uses 1ms poll
  (was blocking on `fpAccept`); GUI poll timer relies on this.

- **`gui.close` timer cleanup** — `PollTimerID` field cancels event-loop
  timer on close, prevents hang when script exits with active poll.

- **`gui.start` binds `127.0.0.1` explicitly** — `0.0.0.0` listen may
  not accept loopback on Termux.


## [0.5.0] — 2026-10-19

**B.7b milestone — In-Process Embedding + `elif`/`elseif` sugar**

Host Pascal code can now `uses pascak_engine` and register native
callbacks callable from script. Alternative `elif`/`elseif` spelling
shipped as pure lexer sugar. Full API docs added.


### Added
- **B.7b Session 1** — engine extraction to `pascak_engine.inc`
  (42,386 lines). Binary identical 2,940,840 bytes. Zero behavioral
  change verified (LSP 6/6 + full suite 30/30 PASS).
- **B.7b Session 2** — `pascak_engine.inc` converted to proper
  `pascak_engine.pas` unit (42,672 lines). Exposes `ExecuteEngine()`
  and `TPascakResult` to host Pascal code via `uses pascak_engine`.
  Binary identical 2,940,840 bytes (pre-patch). Full verification:
  LSP 6/6, full suite 30/30 PASS.
- **B.7b Session 2b** — persistent engine singleton fix:
  - `ExecuteEngine()` bug fixed: 2nd+ call AV'd due to arena
    freelist corruption when engine was freed per call.
  - Fix: `GEmbedEngine` singleton + `GEmbedLock` critical section.
  - `ShutdownEngine()` exposed for explicit release (also called
    at `finalization`).
  - Host verification: 5/5 tests PASS (numeric/string/boolean/null/
    multi-call 10×).
  - See `examples/embed_inproc.pas` for canonical template.
  - Binary size 2,944,952 bytes (was 2,940,840 — added ~4KB for
    singleton + finalization code).


- **B.7b Session 3** — `RegisterNative` for host->script callbacks:
  - `TPascakNativeFunc` type: `function(const Args: TNativeValueArray): TNativeValue`
  - `TNativeValue` record (Kind/Num/Str/Bool) — simplified, no cascade
  - Helper constructors: `NVNull`, `NVNum`, `NVStr`, `NVBool`
  - `RegisterNative(name, func)` — stores dict with `__native_simplified`
    marker in GlobalEnv
  - Two dispatch points: `opcCall` + `opcTailCall` (native branch
    before `dtNative`/FFI branches)
  - Host verification: 6/6 tests PASS (add, greet, isPositive, echo,
    script-loop call, non-native regression)
  - CLI regression: A1/A2/A3 all PASS, 30/30 suite
  - See `examples/embed_inproc.pas` Test 6 for full demo

- **Language: `elif` / `elseif`** — alternative spelling for `else if`:
  - Both keywords recognized by lexer, translated to `ttElse` + `ttIf`
  - Zero parser changes — pure syntactic sugar
  - Backward compat: `else if` (two tokens) still works
  - LSP autocomplete keywords expanded (44 total, +2)
  - Test: T5 else-if, T6 elif, T7 elseif, T8 elif chain — all PASS

## [0.4.0] — 2026-10-18

**Fase D + E.4 — HTTP/2 Client + Full IDE Stack**

Full IDE support untuk VSCode: syntax highlight + LSP (diagnostics, hover,
completion, go-to-definition). HTTP/2 client single-stream (multiplexing
di backlog). Formatter + linter improved.

### Added

#### E.4 — Full IDE Stack (VSCode Extension)

- **E.4 Phase 1** — TextMate grammar (`vscode/syntaxes/pascak.tmLanguage.json`):
  keyword, string, comment, number, operator, F-string interpolation.
  Extension mapping: `.pascak`, `.psk` (tidak claim `.pas`).
- **E.4 Phase 2a** — LSP server lifecycle + diagnostics + hover:
  - `initialize`, `shutdown`, `didOpen`, `didChange`, `didClose` handlers
  - Diagnostics: W001 unused var, W002 unreachable, E001 duplicate decl
  - Hover: type hint untuk variable/const/function/class
- **E.4 Phase 2b** — LSP completion + go-to-definition:
  - Autocomplete: keyword (43), module (12), builtin (38), local vars/func/class
  - `textDocument/definition` — jump ke declaration
- **E.4 Phase 3** — VSCode client (`vscode/extension.js`):
  - `LanguageClient` spawn `pascak_noASTnet --lsp` (stdio transport)
  - Config: `pascak.serverPath`, `pascak.enableLSP`
  - File watcher `**/*.{pascak,psk}`

#### D.2 — HTTP/2 Client (`pascak_h2*.pas`)

- **D.2.1** — Frame layer (`pascak_h2.pas`, 489 lines): 10 frame types
  (DATA, HEADERS, PRIORITY, RST_STREAM, SETTINGS, PUSH_PROMISE, PING,
  GOAWAY, WINDOW_UPDATE, CONTINUATION). Incremental parser + builder.
- **D.2.2** — HPACK Huffman decoder (`pascak_h2_huffman.pas`, 181 lines):
  257-symbol code table (RFC 7541 App. B), bit-level tree walk, EOS
  detection.
- **D.2.3** — HPACK decoder (`pascak_h2_hpack.pas`): 61-entry static
  table, dynamic table FIFO eviction, 5 header field patterns
  (Indexed, Literal+Incremental, Literal+Never, Literal+NoIdx,
  Size Update).
- **D.2.4** — HPACK encoder: 3-tier strategy (exact static match →
  name-only static match → full literal). 17/17 round-trip assertions.
- **D.2.5** — TLS ALPN extension (`pascak_tls.pas`): `TLSConnectALPN`,
  `SSL_set_alpn_protos`, `SSL_get0_alpn_selected`. Verified 'h2'
  negotiation vs httpbin.org (Cloudflare).
- **D.2.6** — `TH2Connection` state machine (`pascak_h2_conn.pas`,
  377 lines): client preface, SETTINGS handshake, single-stream HEADERS
  + DATA, frame dispatch, response accumulation.
- **D.2.7** — Engine integration: `http.get2(url, [headers], [body])`
  native. Full TLS+ALPN+H2 handshake + HPACK round-trip. Returns
  `{status, version: 'h2', headers, body}`.

#### D.2b — HTTP/2 Connection Pool

- `TH2Pool` with max-per-host (default 8), idle timeout (30s),
  hit/miss counters, LRU eviction.
- Engine integration: `http.get2PoolStats()`, `http.get2PoolConfig()`,
  `http.get2PoolClear()`.
- Scope: single-stream (serial) pooling — connection reuse untuk
  sequential requests. Multiplexing di backlog.

#### E.1b + E.2b — Formatter + Linter Improvements

- **E.1b** — Formatter operator spacing: `+`, `-`, `*`, `/`, `%`,
  comparison operators auto-spaced. Compound assignment (`+=`, `-=`,
  dll) preserved. Unary `+`/`-` detection (tidak di-space).
- **E.2b** — Linter function detection: unused function (W003) tidak
  lagi warn jika function dipanggil dari function lain. Function
  tracking di scope stack (`IsFunction` flag).

---

## [0.3.0] — 2026-10-10

**Fase 1 — Hardening**: context isolation, async I/O, production hardening.

### Added
- **Fase 1.1** — Context-aware memory quota (`AllocateQuotaCtx`).
  Per-`TEngineContext` `MemUsage` + `MemQuota`. Fallback global untuk CLI.
- **Fase 1.3** — Async File I/O lengkap (`fs.readAsync`,
  `fs.writeAsync`, `fs.appendAsync`, `fs.pollAsync`, `fs.waitAsync`,
  `fs.cancelAsync`, `fs.freeAsync`). Batas baca 64 MB.
- **Fase 1.5** — Worker exception markers (`__worker_crash`,
  `__worker_kind`) di-set oleh `sys.execAsync`, `poolRun`,
  `http.getAsync`, `fs.readAsync` saat worker crash.
- **CLI flag** `--dev` — membuka env override `PASCAK_EXEC_POLICY` +
  `PASCAK_TLS_NO_VERIFY`. Tanpa `--dev`, kedua env diabaikan.

### Changed
- **Fase 1.2** — Two-phase destruction `TSymbolTable`: cut semua
  reference dulu (di dalam lock), baru free `TValue` (di luar lock).
  Cegah cascade AV saat engine shutdown.
- **Fase 1.4** — Env override hanya di-honor bila `--dev` di-pass.
  Pertahanan terhadap privilege escalation via env poisoning.

### Fixed
- `pascak_poller.pas` — retry `EINTR` di `epoll_wait`.
- `pascak_wsevloop.pas` — hapus blok duplikat di `ProcessFramesInBuf`
  (WS message dispatched 2×); fragmentation buffer dispatch `FragBuf`
  bukan `Frame.Payload`.
- `pascak_noASTnet.pas` — `Native_Sleep` tick per-engine `EventLoop`
  via `TickOnce`, bukan hanya `GWSEventLoop`.

---

## [0.2.0] — 2026-10-08

**Fase 0 — Correctness & Security**: 8 patch audit mendalam.

### Added
- **Fase 0.3** — FFI whitelist MD5 wiring (opt-in, default off).
- **Fase 0.4** — Rename `AES_EncryptString`/`AES_DecryptString` →
  `ObfuscateString`/`DeobfuscateString`.

### Changed
- **Fase 0.1** — TLS context cache dipisah per verify flag.
- **Fase 0.6** — Dokumentasi ownership `TSymbolTable.DefineVar`.

### Fixed
- **Fase 0.2** — Sandbox symlink resolve (`realpath(3)` /
  `GetFinalPathNameByHandleW`).
- **Fase 0.5** — `CallbackDispatcher` restore `GCurrentContext` di
  `finally`.
- **Fase 0.7** — HTTP client socket double-close race.
- **Fase 0.8** — TLS verify override via `PASCAK_TLS_NO_VERIFY` +
  `X-Pascak-No-Verify` header.

---

## [0.1.0] — 2026-10-01

**Baseline**: versi stabil pertama sebelum audit mendalam.

### Added
- Core VM: lexer, parser, compiler, stack-based interpreter.
- Type system: numeric, string, boolean, null, array, dict, object,
  function, native function, class, pointer, DLL handle.
- GC: generational (Gen0 + Gen1) dengan zombie queue.
- Coroutine support (`coroutine_create`, `resume`, `coroutine_free`).
- Event loop dengan timer + I/O wait.
- Worker pool (8 thread) untuk task paralel.
- WebSocket server (RFC 6455) — plain + TLS, thread + event mode.
- HTTP client + server (sync + async).
- TLS binding via libssl 1.1.x / 3.x.
- SQLite via `sqlite3conn` FFI.
- FFI: `dll.load`, `lib.func`, `lib.callback`, native buffer, struct
  by value.
- Crypto: SHA-256, HMAC-SHA256, AES-128/192/256, PBKDF2, secure random.
- Package manager: local registry, semver resolver, lockfile.
- Exec policy: whitelist, rlimit, env sanitize, audit log.
- Sandbox: filesystem path restriction, control char strip.
- DEFLATE/zlib/gzip standalone (`paszlib.pas`).

---

## Format Versi

**MAJOR.MINOR.PATCH** — [Semantic Versioning](https://semver.org/)

- **MAJOR** — breaking change di API publik
- **MINOR** — fitur baru backward-compatible
- **PATCH** — bug fix backward-compatible

---

## Kategori

- **Added** — fitur baru
- **Changed** — perubahan behaviour existing
- **Deprecated** — fitur yang akan dihapus
- **Removed** — fitur yang sudah dihapus
- **Fixed** — bug fix
- **Security** — vulnerability fix

---

## Kontribusi

Setiap PR yang mengubah API / behaviour **wajib** update CHANGELOG.
Entry ditulis dengan gaya imperatif: "Tambah X", "Perbaiki Y",
"Rename Z".

Tambahkan entry di section `[Unreleased]` sebelum release.
Saat release, pindahkan ke section versi baru + update tanggal.
