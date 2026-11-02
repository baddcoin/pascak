# Prerequisites — Phase 1 Blocker

## Critical Gap Discovered

Probe v1.11.13 reveals gui2 missing bindings required for widget toolkit.

### Blocker 1: SDL_TEXTINPUT not bound

**Current state:**
- gui2.poll() returns 'key:<name>' for SDL_KEYDOWN
- No SDL_TEXTINPUT binding
- SDL_StartTextInput / SDL_StopTextInput not called

**Why blocker:**
- 'key:A' ambiguous (lowercase vs uppercase?)
- Shift state not encoded in event name
- Unicode (é, ñ, 中) impossible via keycode mapping
- IME / compose input impossible

**Missing bindings:**
    pStartTextInput: procedure(); cdecl;
    pStopTextInput: procedure(); cdecl;
    SDL_TEXTINPUT = $303;  // event type

**Fix plan:**
1. Add binding di TGuiSDLState
2. Call SDL_StartTextInput setelah window creation
3. Handle SDL_TEXTINPUT event di poll():
   - Event struct offset for UTF-8 text field (SDL_TextInputEvent.text)
   - Return 'textinput:<utf8 string>' dari poll()
4. Handle SDL_TEXTEDITING untuk IME candidate (optional Phase 1)

### Blocker 2: Keyboard state not tracked

**Current state:**
- poll() returns key events only (KEYDOWN/KEYUP as strings)
- No persistent state of which keys are currently held
- No SDL_GetKeyboardState binding

**Why blocker:**
- Text editing needs repeat detection (e.g. hold Backspace)
- Widget hotkeys (Ctrl+S, Shift+Arrow for selection)
- Game-like input patterns (WASD continuous movement)

**Missing binding:**
    pGetKeyboardState: function(numkeys: PInt32): PUInt8; cdecl;

**Fix plan:**
1. Add binding di TGuiSDLState
2. Cache keyboard state per frame:
   - KeyDown array: array[0..512] of Boolean
   - Updated on KEYDOWN/KEYUP events in poll()
3. Expose as gui2.keyDown(scancode) or gui2.keyDownByName('A')
4. Widget uses: if keyDown('SHIFT') and keyDown('LEFT') -> extend selection

## Other Prerequisites (Non-Blocking, Nice to Have)

- **Mouse cursor shape** — SDL_CreateSystemCursor + SDL_SetCursor
  untuk pointer hover indication
- **SDL_TEXTEDITING** — IME composition candidate (future)
- **Clipboard** — SDL_GetClipboardText / SDL_SetClipboardText
  untuk Ctrl+C/V/X di Edit widget

## Phase 1 Deliverable

After Phase 1 complete, gui2 API adds:

    gui2.textInputEnabled(true|false)   // toggle
    gui2.keyDown(name) -> bool          // persistent state
    gui2.keyUp(name) -> bool
    poll() returns 'textinput:abc'      // for unicode text

Test suite: 5 test cases covering ASCII, unicode, IME, key repeat, hotkeys.
