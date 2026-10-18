# Pascak VSCode Extension

Syntax highlighting untuk bahasa scripting **Pascak**.

## Fitur

- Syntax highlight untuk keyword, string, comment, number, operator
- Builtin function highlighting (`println`, `http.get2`, dll)
- Module highlighting (`sys`, `math`, `crypto`, `http`, dll)
- F-string interpolation highlighting (nested expression)
- Comment toggling (`//` line, `/* */` block)
- Auto-closing pairs, surrounding pairs
- Auto-indent berdasarkan `begin`/`end`, `try`/`catch`
- Folding regions via `// region` ... `// endregion`

## Extension Mapping

- `.pascak` — primary extension (Pascak script)
- `.psk` — short form (alternatif)

Extension ini **tidak** claim `.pas` untuk avoid conflict dengan
extension FPC/Delphi yang sudah beredar.


## Instalasi

### Manual (Development)

1. Copy folder `vscode/` ke `<vscode-extensions-dir>/pascak-0.1.0/`
2. Restart VSCode
3. Buka file `.pascak` atau `.psk` — syntax highlight aktif

### Publish (Future)

Lihat VSCode publishing docs untuk build vsix dan upload ke
Marketplace.

## Struktur

    vscode/
      package.json                    Extension manifest
      language-configuration.json     Editor behavior
      syntaxes/pascak.tmLanguage.json TextMate grammar
      README.md                       This file

## Roadmap

Phase 1 (current): syntax highlighting only.

Phase 2 (planned): LSP server
  - Hover documentation
  - Autocomplete
  - Go-to-definition
  - Diagnostics dari built-in linter
  - Format on save (dari built-in formatter)

## Lisensi

MIT
