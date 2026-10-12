# Debug Notes — Resolved & Open Issues

## Resolved #1: Flaky Non-Zero Exit Code

**Status:** ✅ RESOLVED 2026-10-09
**Severity (was):** High — masked real bug for multiple sessions
**Fix:** Init `ExitCode := 0` at start of `runScript` + `libc__exit()`

### Symptom

Minimal script (`begin println("minimal"); end.`) produced
**non-deterministic exit code**:

```

Run 1: exit=80
Run 2: exit=0
Run 3: exit=208

```

Mostly multiples of 16. Compiled with heaptrace `-gh`:
always `exit=24`.

### Root Cause

Local variable `ExitCode` in `runScript` was **never initialized**.
When script exits normally (no `sys.exit`), the final:

```pascal
if ExitCode <> 0 then
  Halt(ExitCode);    // ← garbage value passed to OS
```

passed stack garbage to the OS exit code.

Fix

Location: pascak_noASTnet.pas, runScript

```pascal
begin
  FS := DefaultFormatSettings;
  FS.DecimalSeparator := '.';
  ExitCode := 0;    // ✅ FIX
  ...
```

Also: bypass FPC finalization chain (which corrupted
System.ExitCode at shutdown) via libc._exit():

```pascal
{$IFDEF UNIX}
procedure libc__exit(status: LongInt); cdecl;
  external 'c' name '_exit';
{$ENDIF}

// ... end of runScript
{$IFDEF UNIX}
Flush(Output);
Flush(ErrOutput);
libc__exit(ExitCode);
{$ELSE}
Halt(ExitCode);
{$ENDIF}
```

Misdiagnosis Chain (Lesson Learned)

Debug journey ~3 hours akibat chained misdiagnosis:

1. Permission denied (exit 126) — cp tidak preserve exec
   bit, umask Termux 0177 strip x. Fix: chmod +x di $HOME.
2. "Heap corruption" — heaptrace reported 239 unfreed
   blocks. Ternyata by-design: IsShuttingDown guard di
   TSymbolTable.ClearMap skip TValue.Free saat shutdown.
3. "TLS race" — test_phase_t2a_2 flaky. Bukan race, tapi
   ExitCode garbage propagate ke exit code.
4. "FPC runtime bug" — minitest standalone dengan _exit(0)
   konsisten 0. FPC runtime OK.
5. REAL: uninitialized ExitCode variable.

Smoking gun: debug print code=-702488864 (heap pointer
garbage). Setelah visible, fix = 1 line.

Lesson

When exit code is not a valid POSIX value (128+N for signals,
0 for success, 1-125 for user), suspect uninitialized
memory before investigating complex theories.

Also: always init local variables, especially those
propagated to OS-level effects.

Resolved #2: Double-Free in TWSEventLoop.Destroy

Status: ✅ RESOLVED 2026-10-09
Fix: Removed Dispose(NBSConfig) — engine owns

FreeWSServers disposes PNBServerConfig pointers, then
GWSEventLoop.Free tried to dispose them again → double-free.
Fixed by making Destroy only free the map, not the data
(borrowed from engine).

Open #1: 239 Unfreed Blocks (Heaptrace)

Status: By design — not a bug
Impact: Production zero (long-running, no shutdown in normal ops)

TSymbolTable.ClearMap skips TValue.Free when
IsShuttingDown = 1, to avoid cascade AV during teardown.
Trade-off: 16 KB leak per process exit vs AV risk. Chose leak.

OS reclaims automatically. Heaptrace -gh reports this and
sets exit code 24.

Backlog

Fix via context-local FIsTearingDown guard in ClearMap.
Effort ~30 min change + ~4 hours validation. Low priority.

Open #2: WorkerPool Cleanup Race

Status: Mitigated (Sleep(200) added in Destroy)
Impact: Stabilized — no longer flaky
