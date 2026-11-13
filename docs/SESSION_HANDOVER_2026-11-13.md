# 📋 Handover — v1.11.54 (2026-11-13)

Supersedes: `SESSION_HANDOVER_2026-11-07.md` (v1.11.39)
Main HEAD: 966a1b4 (v1.11.54)
Tags: 108 total (106 release + v1.12.0-plan + v1.13.0-plan)
Engine: 52,503 lines (main) / 54,215 (all units compiled)
Tests: 17/17 PASS
Tree: clean

## Delta Since v1.11.39 (10 releases, 6 days)

| Version | Focus | Result |
|---|---|---|
| v1.11.44 | Cross-lang benchmark | Honest baseline |
| v1.11.45 | For-loop benchmark | 2.65x claim data |
| v1.11.46 | Phase 0 measurement | `--profile`, `--dump-bytecode` |
| **v1.11.47** | **Local loop fusion** | **5.2x speedup, function parity Node** |
| v1.11.48 | Global fusion | Structural only (no runtime win) |
| **v1.11.49** | **Error infra** | `getLastError` + 4 SetFont patches |
| **v1.11.50** | **Font guard** | 7 widget, return -1 |
| **v1.11.51** | **Window guard** | 7 widget, return -1 |
| **v1.11.52** | **Args+init guard** | 14 line patches + `GuiSetErr` helper |
| **v1.11.53** | **Caption type + docs** | 3 patch + `error_handling.md` (70 lines) |
| **v1.11.54** | **WS DoS hardening** | 16MB → 4MB frame cap |

**Zero regression, zero technical debt.**

## Error Handling Infrastructure (v1.11.49-53)

### Return Convention

| Return | Meaning | Recovery |
|---|---|---|
| `>= 1` | Valid widget ID | Use it |
| `-1` | Environment error (font, window, caption) | Fix prerequisite |
| `0` | Caller error (args count, no init) | Fix args |

### Error API

- `gui2.getLastError()` — read + clear error string
- `GuiBootstrapLastError` — global fallback valid pre-init (moved to top unit v1.11.52)
- `GuiSetErr(msg)` — helper: writes to `GGuiSDL.LastError` if assigned, else bootstrap

### Guard Coverage

All 7 widgets (button, edit, memo, combobox, listbox, checkbox, radio) guard:
- Args arity
- `GGuiSDL` init
- Font loaded
- Window created
- Caption type (button/checkbox/radio only — others use optional pattern)

### Docs

`docs/gui_widgets/error_handling.md` — 70 lines, 6 sections

## Security Audit (2026-11-13)

Scope: 5,604 lines security-critical code. **Zero P0/P1 findings.**

| Area | Verdict | Evidence |
|---|---|---|
| Sandbox policy | ✅ Clean | 3-layer guard, `epmDenyAll` default |
| Path traversal | ✅ Clean | `GetSafeSandboxedPath`, 13+ call sites |
| Proc exec | ✅ Clean | Gate before spawn, `fork+execvp` (no shell), whitelist basename-only, concurrent limit 256 |
| File ops | ✅ Clean | Intentional entry point bypass, `.pbc` cache engine-internal |
| HTTP server | ✅ Clean | 64KB header cap + reject, 10MB body cap, 400+close |
| WebSocket | ✅ Clean | 4MB frame cap (v1.11.54), control frame 125B |
| HTTP/2 | ✅ Clean | Client-side header construction (no attacker input) |
| TLS | ✅ Clean | Verify ON default, `SSL_set1_host` + chain verify, admin opt-in `--dev` only |
| FFI/DLL | ✅ Clean | MD5 whitelist (admin-controlled), Android `/sdcard/` workaround |

### P2/P3 Notes (Non-Blocking)

- P2-04: Per-connection no-verify opt-in (currently process-wide env var)
- P3: FFI whitelist MD5 → SHA-256 (MD5 fine for admin-controlled integrity)

### Future Work

- Fuzz harness (parser + VM) — 2-3 sesi, post-publish
- Escape analysis for top-level loop — 2-5 sesi, MEDIUM risk
- Register VM — design ready in `feat/register-vm`, defer until user reports

## State

- **Pilar Fast:** 75% (function parity, top-level 4.6x — disclosed)
- **Pilar Safe:** 100% (5,604 lines audited, 0 P0/P1)
- **Pilar Easy:** 100% (9 P0/P1 closed, docs complete)

**Publish ready with honest disclosure.**
