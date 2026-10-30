# Pascak VM

> Pascal-style scripting language with Python's expressiveness. Runs on any device with the Pascak VM (Termux, Linux, Windows, macOS).

[![Version](https://img.shields.io/badge/version-v1.10.4-blue)]()
[![License](https://img.shields.io/badge/license-MIT-green)]()
[![Platform](https://img.shields.io/badge/platform-Termux%20%7C%20Linux%20%7C%20Windows%20%7C%20macOS-lightgrey)]()

## What is Pascak?

Full-stack scripting language implemented in FreePascal. Single static binary (~3 MB) — no runtime dependencies beyond standard C libraries.

**Design goals:**
- **Fast startup** — ~2 ms cold start (bytecode cache)
- **Batteries included** — HTTP/1.1 + HTTP/2, WebSocket, TLS, SQLite, crypto, FFI, timers, async
- **Modern language** — destructuring, optional chaining (?.), null-coalescing (??), enums, coroutines
- **Two GUIs** — browser-based (HTML + WS RPC) and native (SDL2, 48 API)
- **Cross-platform** — Termux, Linux, Windows, macOS

## Quick Start

    begin
      var greeting := "Hello";
      var name := "World";
      println(f"{greeting}, {name}!");
    end.

Save as `hello.pas`, then run `pascak hello.pas`.

## Installation

### Termux (Android)

    pkg install fpc git
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
| **Language** | Destructuring (obj/array/nested/rest), `?.` optional chaining, `??` null-coalescing, enums, lambdas, F-strings, ternary, list comprehension, class inheritance, try/catch/finally |
| **Async** | Coroutines (`yield`), timers, worker pool, event loop |
| **Network** | HTTP/1.1, HTTP/2 (multiplexing, retry, flow control, rate limit), WebSocket, TLS |
| **Data** | SQLite, JSON, dict, array, regex, base64, crypto (SHA/AES/HMAC/PBKDF2) |
| **GUI** | Browser (HTTP + WS RPC), Native SDL2 (window, drawing, keyboard, audio) |
| **Dev Tools** | LSP (hover, completion, definition), linter, formatter, test runner, REPL, hot-reload |
| **Security** | Sandbox, exec policy, rlimit, env sanitize |

## Examples

Full collection in `examples/` (30+ files):

    pascak examples/http_server.pas
    pascak examples/todo_gui.pas
    pascak examples/hello_gui2.pas
    pascak examples/parallel_fetch.pas
    pascak examples/lang_v110.pas

## Documentation

| File | Content |
|---|---|
| [docs/tutorial.md](docs/tutorial.md) | 31+ chapters, zero to full-stack app |
| [docs/pascak_api.md](docs/pascak_api.md) | Complete API reference |
| [docs/cookbook.md](docs/cookbook.md) | 14 production recipes |
| [CHANGELOG.md](CHANGELOG.md) | Version history (v0.4.0 to v1.8.0 chain) |

## Dev Workflow

Hot-reload with browser auto-reload:

    tools/pascak_dev.sh 'src/,app.pas' app.pas --hot

Edit `app.pas` → browser auto-reload → fresh code live. Graceful shutdown, no dropped WS connections.

### LSP

    pascak --lsp

Works with VSCode, Neovim, and other LSP clients. Signature help, hover types, go-to-definition.

### REPL

    pascak --repl

## Project Status

- Core VM (95%+)
- Standard library (98%+)
- Network stack (HTTP/1, HTTP/2, WS, TLS) (99%+)
- Browser GUI (HTTP + HTTPS)
- Native GUI (SDL2, 48 API)
- Language features (JS-modern parity: destructuring, optional chaining, null-coalescing, enum)
- Dev tools (LSP, linter, formatter, test runner, hot-reload)
- Embedding (subprocess + in-process)
- Cross-platform (Termux, Linux, Windows, macOS)

See [CHANGELOG.md](CHANGELOG.md) for detailed milestone history.

## Contributing

Bug reports, feature requests, and PRs welcome. See [docs/cookbook.md](docs/cookbook.md) for recipe contribution guidelines.

## License

MIT - same as FreePascal ecosystem.
