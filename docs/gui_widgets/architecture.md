# Widget Architecture

## Layered Design

Layers (top to bottom):

1. User Script (Pascak) -- gui2.button(...), gui2.edit(...)
2. Widget Layer (NEW) -- widget base, container, focus chain, event dispatch
3. gui2 primitives (EXISTING) -- rect, line, text, measureText, poll
4. SDL2 (EXISTING)

## Widget Base Class (FPC-side)

Widgets stored as TObjectList of TGuiWidget in TGuiSDLWindow:

    TGuiWidget = class
      ID: Integer;
      X, Y, W, H: Integer;
      Visible: Boolean;
      Enabled: Boolean;
      Focused: Boolean;
      OnClick: TValue;
      OnChange: TValue;
      procedure Draw(GuiState: TGuiSDLState); virtual; abstract;
      function HandleMouse(MX, MY: Integer; Btn: Integer;
        Down: Boolean): Boolean; virtual;
      function HandleKey(Key: string; Down: Boolean): Boolean; virtual;
      function HandleText(const UTF8: string): Boolean; virtual;
    end;

Concrete types (derived): TGuiButton, TGuiEdit, TGuiMemo,
TGuiCheckbox, TGuiRadio, TGuiComboBox, TGuiListBox, TGuiScrollbar.

## Per-Window Widget List

Extend TGuiSDLWindow (existing multi-window support):

    TGuiSDLWindow = class
      ...
      Widgets: TObjectList;         // of TGuiWidget
      FocusedWidgetID: Integer;
      MouseCaptureID: Integer;      // widget receiving mousedown
      NextWidgetID: Integer;
    end;

Multi-window sudah didukung existing code. Widgets per window
independent -- no global state collision.

## Event Dispatch Flow

poll() returns string events. Dispatch flow:

    poll() -> 'key:<name>'       -> focused widget HandleKey
           -> 'keyup:<name>'     -> focused widget HandleKey (down=false)
           -> 'textinput:<utf8>' -> focused widget HandleText
           -> 'mousedown:N'      -> hit-test all widgets -> topmost gets
                                    MouseCaptureID + HandleMouse
           -> 'mousemove'        -> if MouseCaptureID: HandleMouse
                                    (for drag); also update hover state
           -> 'mouseup:N'        -> MouseCaptureID HandleMouse + release
           -> 'quit'             -> exit loop

## Focus Chain

Tab / Shift+Tab cycle through focusable widgets:

    procedure FocusNext(Window: TGuiSDLWindow; Reverse: Boolean);
    // iterate Widgets, find next Enabled + Visible + Focusable
    // set old FocusedWidgetID := -1, new := widget ID

Click on widget also sets focus (for Text Input widgets).
