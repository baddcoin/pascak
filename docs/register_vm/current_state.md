# Current VM Architecture (v1.11.12)

## Stack VM Core

- `TVM.FStack: array[0..STACK_MAX - 1] of TValue` — value stack
- `TVM.FTop: Integer` — stack pointer
- `TVM.FFrames: array[0..MAX_CALL_STACK - 1] of TCallFrame` — call frames
- Dispatch: `function TVM.Run(Chunk: TChunk): TValue` — case-based switch loop
- `FStackLockEnabled: Boolean` — v1.10.4 opt-in fast stack

## Instruction Encoding

TInstruction record:

    OpCode: TVMOpCode;
    Operand, Operand2, Operand3: Integer;
    CacheIdx: Integer;
    CacheTypeDef: Pointer;
    GlobalCache: Pointer;
    TypeFeedback: Byte;
    HitCount: Word;

Size: ~48 bytes/instruction (padded).

## Tier 1 — Superinstructions (DONE)

17 specialized opcodes for common patterns:

- Arithmetic: opcAddNum, opcSubNum, opcMulNum, opcDivNum
- Local access: opcIncrLocal, opcDecrLocal, opcAddLocalLocal, opcAddLocalConst
- Global access: opcIncrGlobal, opcDecrGlobal, opcAddGlobalConst
- Array: opcGetIndexArrayInt, opcSumArrayIndex
- Loops: opcForLoopCond, opcForLoopCondDown
- Optimization: opcReturnNull, opcJumpIfNull, opcJumpIfNotNull

Win: ~1.3-1.6x vs pure stack VM for hot arith loops.

## Tier 2 — Adaptive Specialization (DONE)

Runtime profiler per instruction:

1. After opcode executes, increment HitCount
2. Record TypeFeedback (numeric vs non-numeric)
3. When HitCount >= 100 and HitCount < 200 and TypeFeedback == 1:
   Hot-patch OpCode: opcAdd -> opcAddNum, etc.
4. On type change -> deopt fallback (fixed in v1.11.12)

Location: pascak_engine.pas line ~19488-19512.

## Problem Statement

What Tier 3 would solve:

1. Dispatch overhead (every stack op = 1 case branch + stack push/pop)
2. Stack traffic (generic opcAdd = 3 stack ops)
3. Instruction cache locality (fewer branches)

What Tier 3 would NOT solve:

1. TValue allocation per op (needs arena allocator)
2. String concat quadratic (algorithm-level)
3. Dict hash cost (data structure)
4. GC pauses (cycles)

Reality: Tier 3 alone = 1.3-1.5x realistic. Combined with specialization
+ JIT + arena gives 2-5x, but that's multi-month project.

## Current Baseline (v1.11.12)

See benchmarks/results_v1.11.12.md:

- Arith 100K: 1369ms
- Calls 100K: 1756ms
- Dict 200K: 3941ms
- Array 20K: 316ms
- String 10K: 1109ms
- JSON 1K: 218ms
- Parser 47K: 64ms
