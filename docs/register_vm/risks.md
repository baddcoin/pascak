# Register VM — Risk Assessment

## High Risks

### 1. Bytecode cache break

TChunk.SaveToStream format changes. Old compiled scripts (.pasc) cannot
load. Mitigation: version bump in header, reject old version with clear
error message. Users rebuild from .pas source transparently.

### 2. Semantic drift

Subtle numeric precision changes possible (float ops via register vs
stack eval order). Mitigation: 17/17 lang tests + new numeric edge tests
per phase.

### 3. Debugger / stack trace

GenerateStackTrace relies on stack state. Register VM reduces stack
visibility. Mitigation: keep stack mirror for debug (opt-in env var).

### 4. GC root tracking

TValue in register file must be marked. Mitigation: register file
registered as GC root, add to Mark phase.

## Medium Risks

### 1. Register spill complexity

Pascal expressions can exceed 256 live registers. Mitigation: spill to
stack slot (fallback), complex but bounded.

### 2. Performance regression

Bad register allocation can be SLOWER than stack VM (spill thrashing).
Mitigation: benchmark gate per phase; abandon if Phase 2 regresses.

### 3. Integration test gaps

Async, WS, GUI, LSP touch VM indirectly. Mitigation: manual integration
sweep in Phase 9.

## Low Risks

- Language semantics: no change to user-facing Pascal
- Embedding API: ExecuteEngine / RegisterNative unchanged at API level

## Rollback Strategy

Per-phase rollback: each phase on sub-branch, merged only after Phase N
tests pass. Revert single phase = git revert <merge-commit>.

Full rollback: feat/register-vm branch stays orphan if abandoned. Main
stays unchanged until Phase 10 merge decision.

Backward compat: old compiled .pasc files rejected with version error.
Users rebuild from .pas source (transparent).

## Decision Matrix — Should We Do Tier 3?

| Condition | Recommendation |
|---|---|
| User reports perf bottleneck AND Tier 2.5 doesn't solve it | GO |
| User reports perf bottleneck, unclear where | TRY Tier 2.5 first |
| No user report, "just for fun" | DEFER (diminishing returns) |
| Need competitive benchmark against Lua/Node | TRY Tier 2.5 first |
| Want 2-5x win | Not achievable by Tier 3 alone |

## Alternative — Tier 2.5 (Extend Superinstructions)

Lower risk, comparable win for many workloads:

- Add more superinstructions: opcCmpAndJump, opcBuildArrayN,
  opcStringConcatN, opcDictGetOrNull
- Extended adaptive: re-specialize after deopt (currently one-way patch)
- Effort: 2-3 sessions (vs 15-20 for Tier 3)
- Win: 1.2-1.4x (vs 1.3-1.5x for Tier 3)
- Risk: LOW (additive, no rewrite)

Recommendation: try Tier 2.5 first. If insufficient, escalate to Tier 3.

## References

- CPython 3.11 specialization (PEP 659)
- LuaJIT trace compilation
- V8 Ignition + TurboFan
- PyPy RPython JIT
