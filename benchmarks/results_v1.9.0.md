# Benchmark Baseline — v1.9.0 (2026-10-29)

**Device**: Termux on Android (aarch64)
**Method**: bash date +%s%N wall clock, 1 warm-up + 3 runs, median
**Binary**: pascak_noASTnet

## Comparison vs v1.8.0

| Benchmark | v1.8.0 | v1.9.0 | Speedup | Per-op (v1.9.0) |
|---|---|---|---|---|
| VM arithmetic | 3340 | 1866 | 1.8x | 14 us/iter |
| Function calls | 3712 | 2213 | 1.7x | 17 us/call |
| Dict set+get | 5908 | 4456 | 1.3x | 20 us/op |
| Array push+iter | 2259 | 795 | 2.8x | 16 us/op |
| String concat | 3023 | 1553 | 1.9x | 108 us/append |
| JSON roundtrip | 2146 | 632 | 3.4x | 162 us/rt |
| Parser | 60 | 61 | 1.0x | unchanged |

Average speedup: **~2x** (JSON 3.4x, Array 2.8x on low-op benchmarks).

## What changed in v1.9.0

Two targeted fixes to remove unconditional startup overhead:

### Fix 1: Sleep(1500) guard
`runScript` finally block had unconditional `Sleep(1500)` intended to wait for HTTP/WS server threads. Fired even for pure compute scripts (hello world, benchmarks). Now guarded:

    if (Assigned(GHTTPServers) and (GHTTPServers.Count > 0)) or
       (Assigned(GWSServers) and (GWSServers.Count > 0)) then
      Sleep(1500);

### Fix 2: Script fallback cleanup
Removed `cscript := scriptTest` assignment (dead variable). When no script argument, previously ran test suite as fallback:

    // Before (bug):
    if ScriptArg <> '' then FileName := ScriptArg
    else FileName := './storage/downloads/test.pas';   // runs regression test

    // After:
    if ScriptArg = '' then show usage
    else runScript(ScriptArg);

Impact: `pascak` with no args = 30ms (was 2.0s, 66x faster).

## Per-op analysis (v1.9.0 with overhead removed)

Assuming ~470ms fixed overhead per exec (Engine.Create + native registration + GC):
- VM arith: 14 us/iter — reasonable interpreter range
- Function call: 17 us/call — reasonable
- Dict: 20 us/op — reasonable (TValue boxing per op)
- Array push: 16 us/op (was 113 us — 7x improvement)
- String: 108 us/append — O(n^2) quadratic (expected)
- JSON: 162 us/roundtrip — decent

## Remaining overhead

~470ms fixed per exec (Engine.Create + shutdown GC). Still dominant for trivial scripts:
- hi.pas (1 println): 498ms, of which ~470ms = fixed overhead

## Future optimization targets (v1.9.1)

1. **Engine init / GC sweep** — 470ms fixed cost. Likely: eager native registration (276 RegisterNative calls) + full GC sweep at shutdown. Lazy native registration could cut by 50%.
2. **Array push** — 16 us still 2-3x above target. Per-op lock + Clone overhead remains.
3. **String concat** — document array+join alternative.
4. **JSON** — profile parser; consider compiled schema cache.

## Reproduce

    cp pascak_noASTnet ~/pascak_test
    chmod +x ~/pascak_test
    PASCAK_BIN=~/pascak_test bash benchmarks/run_all.sh

## Change history

- **v1.9.0 (2026-10-29)** — Optimization: removed unconditional Sleep(1500) for non-server scripts + cleaned script fallback path. ~2x average speedup.
- **v1.8.0 (2026-10-29)** — Initial baseline.
