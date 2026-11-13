# GUI2 Widget Error Handling (v1.11.53)

## Return Convention

| Return | Meaning | Recovery |
|---|---|---|
| `>= 1` | Valid widget ID | Use it |
| `-1` | Environment error (missing font/window/caption) | Call prerequisite |
| `0` | Caller error (bad args count, no init) | Fix args / init |

## Reading Errors

`gui2.getLastError()` returns the last error string and **clears** it.
Always check after a widget call returns `< 1`:

```pascal
begin
  var btn = gui2.button(10, 10, 100, 30, "OK");
  if btn < 1 then
    println("Failed: " + gui2.getLastError())
  else
    println("Created widget " + str(btn));
end.
```

## Error Messages

| Message | Cause | Fix |
|---|---|---|
| `<widget>: expected N-M args` | Wrong arg count | See signature table |
| `<widget>: call gui2.init() first` | `gui2.init()` missing | Call `gui2.init()` first |
| `<widget>: font not loaded, call gui2.setFont() first` | No font | Call `gui2.setFont()` first |
| `<widget>: no window, call gui2.window() first` | No active window | Call `gui2.window()` first |
| `<widget>: caption must be string` | Caption arg is numeric | Pass a string |

## Widget Signatures

| Widget | Signature | Args | Auto-size |
|---|---|---|---|
| button | `button(x, y, w, h, caption[, r, g, b])` | 5-8 | No |
| edit | `edit(x, y, w[, initial[, r, g, b]])` | 3-7 | No |
| memo | `memo(x, y, w, h[, initial[, r, g, b]])` | 4-8 | No |
| combobox | `combobox(x, y, w, h[, items[, selected]])` | 3-7 | No |
| listbox | `listbox(x, y, w, h[, items])` | 4-8 | No |
| checkbox | `checkbox(x, y, caption[, checked[, r, g, b]])` | 3-7 | **Yes** |
| radio | `radio(x, y, caption[, group_id[, checked[, r, g, b]]])` | 3-8 | **Yes** |

`checkbox` and `radio` **auto-size** — no `w`/`h` needed. Passing
`w, h` as 3rd/4th args will be interpreted as `caption` and
`checked` — call will fail with `caption must be string`.

## Standard Setup

```pascal
begin
  gui2.init();
  gui2.setFont("/path/to/font.ttf", 20);
  gui2.window("My App", 800, 600);
  gui2.textInputEnabled(true);
  var btn = gui2.button(10, 10, 100, 30, "Click");
end.
```

## Known Gaps (v1.11.54 planned)

- `caption` type check only on button/checkbox/radio. Edit/Memo/
  Combobox/ListBox accept optional caption via `Args[N].DataType =
  dtString` pattern (silent default if wrong type).
- Numeric args (x, y, w, h) not validated — non-numeric values
  default to 0 via `Trunc(TValue.NumVal)`.
