# SESSION_CONTEXT Update — 2026-10-30

**Authoritative state at this date.** Overrides claims in `SESSION_CONTEXT.md`
(which is from v1.0.2 era, 9 minor versions stale).

## Repo State

- HEAD: `44c693e` (docs readme bump above `07773d1` chore)
- Latest tag: `v1.10.4`
- Tags total: **55** (v0.4.0 → v1.10.4)
- `pascak_engine.pas`: **47,328** lines
- Tests: 17 files (~103 cases), `bash tests/run.sh lang` PASS

## Overrides to SESSION_CONTEXT.md (v1.0.2)

| Old claim | Actual |
|---|---|
| HEAD 5dbcb8c (tag: v1.0.2) | 44c693e / v1.10.4 |
| Tags 22 total | 55 total |
| Backlog: v1.2.6 rest-nested | DONE |
| Backlog: v1.2.7 ?.() | DONE |

## Runtime Verification (2026-10-30, all PASS)

    var r = null?.name    -> null
    var r = null?.greet() -> null
    var r = null?.[0]     -> null
    var src = {cfg:{host:"h",port:80,user:"u"}}
    var {cfg:{host,...rest}} = src
    -> host="h", rest={"user":"u","port":80}

## Critical Gotchas (Confirmed This Session)

1. print() / statements MUST be inside begin...end, NOT top-level.
   Error if wrong: "Expected token tapi mendapat [print]"
2. Termux paste >3KB is unreliable - clipboard limit + line-merge bug.
   Use nano for files >3KB, or chunked heredoc (cat >> file <<'TAG').

## Lesson

Verify runtime, not code comments. "// v1.2.7:" in parser code was
proven working only after runtime tests T1-T4 on 2026-10-30. Comments
can describe aspirational or half-merged features.

## Backlog (post-v1.10.4)

- H2 Session 4c - rate limiter + GOAWAY retry (~2-3 jam)
- GUI hot-reload - browser file watcher (~2 jam)
- LSP Phase 4 - signature help (~3 jam)
- Register VM / arena allocator (arsitektural, 1-2 minggu)
