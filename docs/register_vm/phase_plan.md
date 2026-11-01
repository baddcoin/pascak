# Register VM Implementation Plan

## Phased Rollout

Each phase: sub-branch, tested, merged to `feat/register-vm` only after green.

## Phase 1: Infrastructure (3-4 sessions)

- Add TVM.RegisterFile: array of TValue field
- Add register allocation API: AllocRegs(frame, n)
- Add stub register opcodes (dispatch case branches, all do nothing yet)
- Update TChunk.SaveToStream/LoadFromStream -- version bump, reject old version cleanly

Success: build passes, 17/17 lang tests PASS, no perf regression.

## Phase 2: Migrate arithmetic (2-3 sessions)

- Compiler: emit opcRegLoad, opcRegAdd, opcRegLoad, opcRegReturn for simple `a + b`
- VM: dispatch case for register arith
- Hybrid: fall back to stack for complex exprs (function calls, string ops)

Success: arith 100K <= 1369ms (no regression), 17/17 PASS.

## Phase 3: Migrate loops (2 sessions)

- Compiler: for i = 1 to N -> register counter in rN, opcRegAddImm, opcRegCmp, opcRegJumpIfTrue

Success: loop-heavy benchmark >= 1.2x faster, no regression.

## Phase 4: Migrate local variables (2 sessions)

- Compiler: var x = 10; x = x + 1 -> x in register instead of stack slot
- Register pressure tracking (max 256 regs, spill to stack if exceeded)

Success: local-heavy benchmark >= 1.15x faster, no regression.

## Phase 5: Function calls via registers (2-3 sessions)

- Calling convention: args in r0..rN-1, return in r0
- Recursive calls (each frame allocates own register file slice)

Success: calls 100K <= 1756ms (no regression), recursion works.

## Phase 6: Deopt framework (1 session)

- Register path deopt: fall back to stack interpretation for polymorphic ops
- Reuse Tier 2 TypeFeedback infrastructure

Success: polymorphic code doesn't crash, correct results.

## Phase 7: Benchmark sweep (1 session)

- Run all benchmarks vs v1.11.12 baseline
- Calculate aggregate speedup

Success criteria: overall >= 1.3x, no benchmark regresses > 5%.

## Phase 8: 17/17 lang tests re-verify (1 session)

- All existing tests must PASS on register VM path
- Add new tests for register-specific edge cases (deep recursion, register spill)

Success: 17/17 + new tests PASS.

## Phase 9: Integration tests (1 session)

- H2 async, WS, GUI, LSP -- all must work unchanged

Success: zero regression.

## Phase 10: Merge decision (1 session)

- If aggregate >= 1.3x and zero regression: merge to main
- Else: keep in branch as experimental (env var opt-in)

Success: decision made, documented.

## Phase 11-12: Buffer for unexpected issues

- Debugging, edge cases, perf tuning
- Not allocated unless needed

Total estimate: 15-20 sessions (3-4 weeks part-time). Note: higher than
initial "1-2 week" estimate -- reflects reality of compiler + VM rewrite.

## Register File Design

    TVM.RegisterFile: array[0..REG_MAX - 1] of TValue;

Size: 256 registers x 48 bytes = 12KB. Fits in L1 cache.

Allocation: compile-time. Compiler emits:
- Each function has max_reg_used per frame
- Caller allocates register file slice: base_reg = prev_base_reg + prev_max_reg
- Function epilogue releases registers

Calling convention:
- Args: registers r0..rN-1 (caller sets before call)
- Return: r0
- Locals: rN..rM (compiler-managed)
- Temps: rT..rT+ (compiler scratch)
