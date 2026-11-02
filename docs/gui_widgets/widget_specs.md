# Widget Specifications

## Button

    gui2.button(win, x, y, w, h, label, [onClick]) -> handle

State: idle, hover, pressed, disabled
Draw: filled rect + border + centered text
Events:
- mousedown within bounds -> pressed=true, capture
- mouseup within bounds -> if was pressed: call onClick
- mousemove -> update hover state
- Enter/Space (when focused) -> call onClick
Colors: 3 palettes (normal, hover, pressed) via theme

## Edit (single-line text input)

    gui2.edit(win, x, y, w, [initial]) -> handle
    gui2.editSetText(h, str)
    gui2.editGetText(h) -> str

State: text, cursor_pos, selection_start, selection_end, scroll_x
Draw: bg rect + border + text + cursor (blinking) + selection highlight
Events:
- textinput:<char> -> insert at cursor, advance cursor
- key:BACKSPACE -> delete before cursor (or selection)
- key:DELETE -> delete at cursor (or selection)
- key:LEFT/RIGHT -> move cursor
- key:HOME/END -> jump to start/end
- key:SHIFT+LEFT/RIGHT -> extend selection
- Ctrl+C/V/X -> clipboard (prerequisite)
- Ctrl+A -> select all
- key:ENTER -> onEnter callback (optional)
Cursor blink: 500ms toggle, only when focused

## Memo (multi-line text editor)

    gui2.memo(win, x, y, w, h, [initial]) -> handle
    gui2.memoSetText(h, str)
    gui2.memoGetText(h) -> str

State: text (lines array), cursor_line, cursor_col, scroll_y, selection
Draw: bg + border + visible lines + cursor + selection highlight + scrollbar
Events: like Edit + additional
- key:ENTER -> insert newline at cursor
- key:UP/DOWN -> move cursor line, preserve column
- PageUp/PageDown -> jump visible_height lines
- scrollbar drag -> update scroll_y
Wrapping: optional (word-wrap or char-wrap) -- Phase 5b
Performance: only render visible lines (viewport culling)

## Checkbox

    gui2.checkbox(win, x, y, label, [checked], [onChange]) -> handle

State: checked (bool)
Draw: small box + checkmark + label to right
Events:
- mousedown within box or label -> toggle checked, call onChange
- Space (when focused) -> toggle

## Radio Button

    gui2.radio(win, x, y, label, [selected], [onChange], [group_id]) -> handle

State: selected
Draw: circular + dot + label
Events:
- Click -> select self, deselect others in same group_id
- Space (when focused) -> select

## ComboBox

    gui2.combobox(win, x, y, w, [items], [onChange]) -> handle
    gui2.comboSetItems(h, arr)
    gui2.comboGetSelected(h) -> num
    gui2.comboSetSelected(h, idx)

State: items (array of strings), selected_idx, dropdown_open
Draw: rect + selected text + dropdown arrow + optional popup list
Events:
- click -> toggle dropdown_open
- click on item -> select, close dropdown
- click outside dropdown -> close (global mouse capture check)
- key:UP/DOWN (when closed) -> cycle selection
- key:ENTER -> open dropdown, or select focused item
Popup layer: rendered ON TOP of all other widgets (z-order)

## ListBox

    gui2.listbox(win, x, y, w, h, [items], [onSelect]) -> handle
    gui2.listSetItems(h, arr)
    gui2.listGetSelected(h) -> num
    gui2.listSetSelected(h, idx)

State: items, selected_idx, scroll_y
Draw: bg + border + visible items + selection highlight + scrollbar
Events:
- click on item -> select, call onSelect
- key:UP/DOWN -> cycle selection (auto-scroll into view)
- PageUp/PageDown -> jump visible_height rows
- scrollbar drag -> update scroll_y
- mouse wheel -> scroll (future, needs wheel event binding)

## Scrollbar (reusable component)

    gui2.scrollbar(win, x, y, w, h, [vertical]) -> handle
    gui2.scrollbarSetRange(h, min, max, page)
    gui2.scrollbarGetPos(h) -> num

State: min_val, max_val, page_size, current_pos
Draw: track + thumb (proportional to page_size)
Events:
- thumb drag -> update current_pos, notify owner widget
- click on track -> page up/down
- key:PageUp/PageDown -> page
Used by Memo, ListBox, ComboBox dropdown (if items > visible)

## Layout API

    gui2.widgetSetPos(h, x, y)
    gui2.widgetSetSize(h, w, h)
    gui2.widgetGetBounds(h) -> {x, y, w, h}
    gui2.widgetSetVisible(h, bool)
    gui2.widgetSetEnabled(h, bool)
    gui2.widgetSetFocus(h)
    gui2.widgetDestroy(h)

Absolute layout by default (x, y explicit). Flow layout optional in
future (row, column, grid) -- out of MVP scope.
