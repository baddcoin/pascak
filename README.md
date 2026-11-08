# Pascak VM
> Pascal-style scripting language with Python's expressiveness. Now with a production-ready Native GUI Toolkit.

[![Version](https://img.shields.io/badge/version-v1.11.43-blue)]()
[![License](https://img.shields.io/badge/license-MIT-green)]()
[![Platform](https://img.shields.io/badge/platform-Termux%20%7C%20Linux%20%7C%20Windows%20%7C%20macOS-lightgrey)]()

## What is Pascak?

Full-stack scripting language implemented in FreePascal. Single static binary (~3 MB) — no runtime dependencies beyond standard C libraries.

**Design goals:**
- **Fast startup** — ~110 ms end-to-end (10x faster than Node, 2x faster than Python in Termux)
- **Batteries included** — HTTP/2, WebSocket, TLS, SQLite, crypto, FFI, async
- **Modern language** — destructuring, `?.`, `??`, enums, coroutines
- **Native GUI** — SDL2-based toolkit with 7 widgets, flow/grid layouts, and full theming
- **Cross-platform** — Termux, Linux, Windows, macOS

## The GUI Toolkit (New in v1.11.x)

Forget clunky web-wrappers. Pascak ships with a native, immediate-mode GUI toolkit powered by SDL2. 

- **7 Production-Ready Widgets:** Button, Edit, Memo, ComboBox, ListBox, Checkbox, Radio.
- **Layout API:** `layoutFlow` (auto-wrap) and `layoutGrid` (matrix).
- **Theming:** Full RGB control over background, text, border, and hover states per-widget.
- **Built-in Editor Features:** Mouse-drag selection, dynamic line-number gutters, word-wrap.

### 10-Second GUI Example

    begin
      gui2.init();
      gui2.window("Pascak GUI", 400, 300);
      
      var btn := gui2.button(0, 0, 120, 40, "Click Me");
      // Custom Theming: Blue background, White text
      gui2.widgetSetColors(btn, 50, 150, 250, 255, 255, 255);
      
      // Layout Engine: Position with auto-spacing
      gui2.layoutFlow(20, 20, 360, [btn], 10);

      while gui2.isOpen() do begin
        var ev := gui2.poll();
        if ev == "quit" then break;
        gui2.clear(30, 30, 30);
        gui2.widgetsDraw();
        gui2.present();
        gui2.delay(16);
      end;
      gui2.quit();
    end.

## Quick Start

    begin
      var greeting := "Hello";
      var name := "World";
      println(f"{greeting}, {name}!");
    end.

Save as `hello.pas`, then run `pascak hello.pas`.

## Installation

### Termux (Android)

    pkg install fpc git sdl2 sdl2-ttf
    git clone https://github.com/baddcoin/pascak
    cd pascak
    fpc -Mobjfpc -Sh pascak_noASTnet.pas
    cp pascak_noASTnet $PREFIX/bin/pascak

### Linux / macOS (FPC 3.2+)

    git clone https://github.com/baddcoin/pascak
    cd pascak
    fpc -Mobjfpc -Sh pascak_noASTnet.pas
    sudo cp pascak_noASTnet /usr/local/bin/pascak

## Features at a Glance

| Category | Features |
|---|---|
| **Language** | Destructuring, `?.`, `??`, enums, lambdas, F-strings, classes, try/catch/finally |
| **Native GUI** | 7 Widgets, Flow/Grid Layouts, Per-widget Theming (RGB), Drag-select, Line numbers |
| **Async** | Coroutines (`yield`), timers, worker pool, event loop |
| **Network** | HTTP/1.1, HTTP/2 (multiplexing), WebSocket, TLS |
| **Data** | SQLite, JSON, dict, array, regex, crypto (SHA/AES/HMAC) |
| **Dev Tools** | LSP (hover/completion), linter, formatter, REPL, hot-reload |

## Examples

Full collection in `examples/` (36+ files, 2,300+ lines):

    pascak examples/todo_gui.pas      # Full SQLite + GUI app
    pascak examples/music_player.pas  # Native GUI media player
    pascak examples/gui2_counter.pas  # Button + Layout showcase
    pascak examples/parallel_fetch.pas

## Documentation

| File | Content |
|---|---|
| [docs/tutorial.md](docs/tutorial.md) | 34 chapters, zero to full-stack app (6,100+ lines) |
| [docs/pascak_api.md](docs/pascak_api.md) | Complete API reference (5,600+ lines) |
| [docs/cookbook.md](docs/cookbook.md) | 14 production recipes |
| [CHANGELOG.md](CHANGELOG.md) | Version history (100+ tags) |

## Project Status (v1.11.43)

- Core VM (95%+)
- Standard library (98%+)
- Network stack (99%+)
- **Native GUI Toolkit (100%)** — 7 widgets, layouts, theming, verified
- Dev tools (LSP, linter, formatter, test runner)
- **Zero Technical Debt.** 17/17 language tests passing.

## License

MIT - same as FreePascal ecosystem.
