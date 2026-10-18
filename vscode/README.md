# Pascak VSCode Extension

Full IDE support untuk bahasa scripting **Pascak**: syntax highlight +
LSP (diagnostics, hover, completion, go-to-definition).

## Fitur

### Syntax Highlighting
- Keyword, string, comment, number, operator coloring
- F-string interpolation highlight (nested expression)
- Builtin function + module highlighting
- Comment toggle (`//` line, `/* */` block)
- Auto-closing pairs, auto-indent, folding regions

### LSP Features
- **Diagnostics** — unused variable (W001), unused function (W003),
  duplicate declaration (E001) — squiggly line langsung di editor
- **Hover** — tooltip tipe symbol (variable, const, function, class)
- **Autocomplete** — keyword (43), module (12), builtin function (38),
  local vars/functions/classes dari AST
- **Go-to-definition** — Ctrl+Click / F12 pada var/func/class

## Requirements

- VSCode **1.75+**
- Binary `pascak_noASTnet` accessible via `PATH` **atau** set
  `pascak.serverPath` config ke full path

## Extension Mapping

- `.pascak` — primary
- `.psk` — short form

**Tidak** claim `.pas` — avoid conflict dengan FPC/Delphi extension.

## Instalasi

### Cara 1: Dari .vsix (Recommended)

    cd vscode/
    npm install --no-bin-links      # Termux: symlinks not supported on /storage
    npm install -g @vscode/vsce
    vsce package
    # Install pascak-0.1.0.vsix via VSCode Extensions UI

### Cara 2: Development Mode

1. Copy folder `vscode/` ke `<vscode-extensions-dir>/pascak-0.1.0/`
2. Install dependencies:
       cd <vscode-extensions-dir>/pascak-0.1.0/
       npm install --no-bin-links
3. Restart VSCode
4. Buka file `.pascak` atau `.psk`

## Configuration

| Setting | Default | Deskripsi |
|---------|---------|-----------|
| `pascak.serverPath` | `pascak_noASTnet` | Full path ke binary Pascak |
| `pascak.enableLSP` | `true` | Enable/disable LSP (syntax highlight tetap jalan) |

Contoh `.vscode/settings.json`:

    {
      "pascak.serverPath": "/data/data/com.termux/files/home/pascak_noASTnet",
      "pascak.enableLSP": true
    }

## Struktur

    vscode/
    ├── package.json                    # Manifest + contributes + deps
    ├── extension.js                    # LSP client (spawn --lsp)
    ├── language-configuration.json     # Editor behavior
    ├── syntaxes/
    │   └── pascak.tmLanguage.json      # TextMate grammar
    ├── node_modules/                   # (gitignored, run npm install)
    ├── package-lock.json
    └── README.md

## Verifikasi LSP (tanpa VSCode)

Piped JSON-RPC test:

    python3 -c "
    import json, subprocess
    msgs = [
        {'jsonrpc':'2.0','id':1,'method':'initialize','params':{}},
        {'jsonrpc':'2.0','method':'exit','params':None}
    ]
    data = b''
    for m in msgs:
        b = json.dumps(m).encode()
        data += f'Content-Length: {len(b)}' + '\r\n\r\n' + b.decode()
    r = subprocess.run(['pascak_noASTnet', '--lsp'], input=data.encode(),
                       capture_output=True, text=True, timeout=10)
    print('STDOUT:', r.stdout[:300])
    "

Expected: STDOUT contains `"capabilities"` dan `"serverInfo"`.

## Catatan Termux

`npm install` di Termux dengan source di `/storage/emulated/0/`
(shared storage) **butuh** flag `--no-bin-links` karena FUSE mount
shared storage tidak support symlink. Source di home filesystem
(`/data/data/com.termux/files/home/`) tidak punya masalah ini.

## Roadmap

- Phase 1 — TextMate grammar ✅
- Phase 2 — LSP server (lifecycle, diagnostics, hover, completion, definition) ✅
- Phase 3 — VSCode client integration ✅
- Phase 4 (backlog) — signature help, code actions, format-on-save via LSP

## Lisensi

MIT
