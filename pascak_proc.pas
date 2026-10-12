{ ====================================================================
  pascak_proc.pas — Subprocess management untuk VM Pascak
  ====================================================================
  Cross-platform: POSIX (Linux, Termux/Android, macOS) + Windows.

  API contract:
    - Handle = integer 0..255 (0 bukan invalid, slot-based)
    - ProcInit/ProcShutdown refcounted
    - Fork safety: TIDAK ada library call di antara fork() dan exec()
      (hanya dup2, close, execvp) — aman untuk multi-threaded parent.

  Catatan Termux/Android:
    - fork() bekerja tapi harus sangat minimal sebelum exec()
    - Binary path harus absolute atau ada di PATH
    - Sandbox Android membatasi spawn binary di luar Termux prefix
  ==================================================================== }
unit pascak_proc;

{$MODE OBJFPC}{$H+}

interface

uses
  Classes, SysUtils, SyncObjs;

const
  PROC_READ_ERR    = -1;   // error atau timeout
  PROC_READ_CLOSED = 0;    // pipe tertutup (EOF)
  PROC_WRITE_ERR   = -1;
  PROC_MAX_READ    = 65536;
  PROC_MAX_SLOTS   = 256;

  // Stream identifier untuk ProcReadTimeout
  PROC_STREAM_STDOUT = 0;
  PROC_STREAM_STDERR = 1;
  
  // Default limits — konservatif tapi aman
  DEFAULT_CPU_SEC         = 60;
  DEFAULT_MEMORY_BYTES    = Int64(512) * 1024 * 1024;   // 512 MB
  DEFAULT_FILESIZE_BYTES  = Int64(50) * 1024 * 1024;    // 50 MB
  DEFAULT_OPEN_FILES      = 1024;
  DEFAULT_SUBPROCESSES    = 64;
  DEFAULT_MAX_CONCURRENT  = 8;
  DEFAULT_MAX_OUTPUT      = Int64(10) * 1024 * 1024;    // 10 MB  
  
type
  EProcError = class(Exception);
  ESecurityError = class(EProcError);

  // FPC Termux tidak define RLimit/TRLimit — declare manual
  TRLimitRec = record
    rlim_cur: NativeUInt;
    rlim_max: NativeUInt;
  end;

  // Typed array untuk envp — open array tidak support SetLength
  TEnvPArray = array of PChar;
  
  TExecPolicyMode = (
    epmDenyAll,     // default aman — semua exec ditolak
    epmWhitelist,   // hanya binary dalam list
    epmAllowAll     // development only — bypass policy (warning di stderr)
  );
  
  TExecLimits = record
    Enabled: Boolean;
    CpuSec: Integer;            // 0 = no limit
    MemoryBytes: Int64;         // 0 = no limit
    FileSizeBytes: Int64;       // 0 = no limit
    OpenFiles: Integer;         // 0 = no limit
    Subprocesses: Integer;      // 0 = no limit
  end;
  
  TExecPolicy = class
  public
    Mode: TExecPolicyMode;
    Binaries: TStringList;      // whitelist — nama binary saja, bukan full path
    EnvAllow: TStringList;      // env var yang diizinkan lewat
    EnvDeny: TStringList;       // env var yang WAJIB di-strip (prioritas di atas Allow)
    EnvSet: TStringList;        // format "KEY=VALUE", force-set di child
    DefaultCwd: string;         // '' = inherit parent cwd
    MaxConcurrent: Integer;     // 0 = unlimited (tidak direkomendasikan)
    MaxOutputBytes: Int64;      // 0 = unlimited (tidak direkomendasikan)
    Limits: TExecLimits;
    AuditLogPath: string;       // '' = disabled
    ResolvePath: Boolean;       // true = strict path resolution

    constructor Create;
    destructor Destroy; override;
    procedure Assign(Other: TExecPolicy);
    function Clone: TExecPolicy;
  end;
  
  PSProcEntry = ^TSProcEntry;
  TSProcEntry = record
    Used: Boolean;
    Pid: Integer;
    StdinW: Integer;    // write end of stdin pipe
    StdoutR: Integer;   // read end of stdout pipe
    StderrR: Integer;   // read end of stderr pipe
    Running: Boolean;
    ExitCode: Integer;
    {$IFDEF WINDOWS}
    ProcHandle: THandle;
    ThreadHandle: THandle;
    {$ENDIF}
  end;  
  
  // ─── Lifecycle (refcounted) ───
  procedure ProcInit;
  procedure ProcShutdown;
  
  // ─── Exec Policy API ───
  procedure InitExecPolicy;
  procedure FreeExecPolicy;
  function ProcGetExecPolicy: TExecPolicy;         // return borrowed — jangan Free
  procedure ProcSetExecPolicy(NewPolicy: TExecPolicy);  // deep copy
  function ProcIsExecAllowed(const Binary: string;
      out Reason: string): Boolean;
  
  // ─── Diagnostics ───
  function GetActiveProcessCount: Integer;

  // ─── Blocking exec ───
  // Spawn, capture stdout+stderr, tunggu exit.
  // TimeoutMs = 0 → tunggu tanpa batas.
  function ProcExec(const Cmd: string; const Args: array of string;
      out Stdout, Stderr: RawByteString;
      out ExitCode: Integer; TimeoutMs: Integer = 0): Boolean;
  
  // ─── Async spawn ───
  function ProcSpawn(const Cmd: string; const Args: array of string;
      out Proc: Integer): Boolean;
  
  // ─── I/O ───
  // Non-blocking: return jumlah byte, PROC_READ_ERR (tidak ada data),
  // atau PROC_READ_CLOSED (EOF).
  function ProcReadStdout(Proc: Integer; MaxBytes: Integer;
      out Data: RawByteString): Integer;
  function ProcReadStderr(Proc: Integer; MaxBytes: Integer;
      out Data: RawByteString): Integer;
  
  // Blocking dengan timeout (0 = non-blocking).
  function ProcReadTimeout(Proc: Integer; WhichStream: Integer;
      MaxBytes, TimeoutMs: Integer;
      out Data: RawByteString): Integer;
  
  function ProcWriteStdin(Proc: Integer; DataPtr: Pointer; DataLen: Integer): Integer;
  procedure ProcCloseStdin(Proc: Integer);
  
  // ─── Process control ───
  // TimeoutMs = 0 → tunggu tanpa batas.
  function ProcWait(Proc: Integer; TimeoutMs: Integer; out ExitCode: Integer): Boolean;
  procedure ProcKill(Proc: Integer);
  function ProcIsRunning(Proc: Integer): Boolean;
  
  // ─── Cleanup ───
  // Tutup semua handle terkait dan bebaskan slot.
  procedure ProcClose(Proc: Integer);
  function ProcLastError: string;

  function ResolveBinaryPath(const Cmd: string): string;
  procedure FreeEnvArray(var EnvP: TEnvPArray);
  procedure DoCleanupSlot(Idx: Integer);
  procedure ApplyRlimitsInChild;
  procedure BuildSanitizedEnv(out EnvP: TEnvPArray; out Count: Integer);

implementation

uses
  DateUtils,
  {$IFDEF UNIX} BaseUnix, Unix, {$ENDIF}
  {$IFDEF WINDOWS} Windows, {$ENDIF}
  {$IFDEF UNIX} cthreads; {$ENDIF}

{$IFDEF UNIX}
const
  // Linux rlimit constants — nilai fixed, tidak berubah
  RLIMIT_CPU_C    = 0;
  RLIMIT_FSIZE_C  = 1;
  RLIMIT_DATA_C   = 2;
  RLIMIT_STACK_C  = 3;
  RLIMIT_CORE_C   = 4;
  RLIMIT_RSS_C    = 5;
  RLIMIT_NPROC_C  = 6;
  RLIMIT_NOFILE_C = 7;
  RLIMIT_MEMLOCK_C= 8;
  RLIMIT_AS_C     = 9;

function c_setrlimit(resource: cint; rlim: Pointer): cint;
  cdecl; external 'c' name 'setrlimit';
{$ENDIF}

var
  GSlots: array[0..PROC_MAX_SLOTS - 1] of TSProcEntry;
  GLock: TCriticalSection;
  GInitCount: Integer;
  GInitLock: TCriticalSection;
  GLastError: string;
  GLastErrorLock: TCriticalSection;

  GExecPolicy: TExecPolicy = nil;
  GExecPolicyLock: TCriticalSection = nil;
  GActiveProcessCount: LongInt = 0;


// ════════════════════════════════════════════════════════════════
//  Utilities
// ════════════════════════════════════════════════════════════════

procedure SetLastError(const Msg: string);
begin
  if not Assigned(GLastErrorLock) then Exit;
  GLastErrorLock.Acquire;
  try GLastError := Msg;
  finally GLastErrorLock.Release;
  end;
end;

function ProcLastError: string;
begin
  Result := '';
  if not Assigned(GLastErrorLock) then Exit;
  GLastErrorLock.Acquire;
  try Result := GLastError;
  finally GLastErrorLock.Release;
  end;
end;

procedure ProcInit;
begin
  if not Assigned(GInitLock) then
  begin
    GInitLock := TCriticalSection.Create;
    GLock := TCriticalSection.Create;
    GLastErrorLock := TCriticalSection.Create;
    FillChar(GSlots, SizeOf(GSlots), 0);
    InitExecPolicy;
  end;
  GInitLock.Acquire;
  try
    Inc(GInitCount);
  finally
    GInitLock.Release;
  end;
end;

procedure ProcShutdown;
var i: Integer;
begin
  if not Assigned(GInitLock) then Exit;
  GInitLock.Acquire;
  try
    if GInitCount = 0 then Exit;
    Dec(GInitCount);
    if GInitCount = 0 then
    begin
      if Assigned(GLock) then
      begin
        GLock.Acquire;
        try
          // ─── Force kill semua subprocess dulu ───
          for i := 0 to PROC_MAX_SLOTS - 1 do
            if GSlots[i].Used and GSlots[i].Running then
            begin
              {$IFDEF UNIX}
              try fpKill(GSlots[i].Pid, SIGTERM); except end;
              {$ENDIF}
              {$IFDEF WINDOWS}
              try TerminateProcess(GSlots[i].ProcHandle, 1); except end;
              {$ENDIF}
            end;

          // Tunggu sebentar untuk graceful exit
          Sleep(200);

          // Reap + close
          for i := 0 to PROC_MAX_SLOTS - 1 do
            if GSlots[i].Used then
              DoCleanupSlot(i);
        finally
          GLock.Release;
        end;
      end;
    end;
  finally
    GInitLock.Release;
  end;
end;

function AllocSlot: Integer;
var i: Integer;
begin
  Result := -1;
  GLock.Acquire;
  try
    for i := 0 to PROC_MAX_SLOTS - 1 do
    begin
      if not GSlots[i].Used then
      begin
        FillChar(GSlots[i], SizeOf(TSProcEntry), 0);
        GSlots[i].Used := True;
        GSlots[i].StdinW := -1;
        GSlots[i].StdoutR := -1;
        GSlots[i].StderrR := -1;
        GSlots[i].Running := False;
        GSlots[i].ExitCode := -1;
        Exit(i);
      end;
    end;
  finally
    GLock.Release;
  end;
end;

function GetSlot(Handle: Integer): PSProcEntry;
begin
  Result := nil;
  if (Handle < 0) or (Handle >= PROC_MAX_SLOTS) then Exit;
  if not GSlots[Handle].Used then Exit;
  Result := @GSlots[Handle];
end;

// ════════════════════════════════════════════════════════════════
//  POSIX implementation
// ════════════════════════════════════════════════════════════════
{$IFDEF UNIX}

function DoSpawnPosix(const Cmd: string; const Args: array of string;
    Slot: Integer): Boolean;
var
  InP, OutP, ErrP: array[0..1] of Integer;
  Pid: TPid;
  Argv: array of PChar;
  Envp: TEnvPArray;
  EnvpCount, i, N: Integer;
  FullPath, ChdirTarget: string;
  UseEnvP: Boolean; Reason: string;
begin
  Result := False;

  // ─── Whitelist check ───
  begin
    if not ProcIsExecAllowed(Cmd, Reason) then
    begin
      SetLastError('exec denied: ' + Reason);
      Exit;
    end;
  end;

  // ─── Path resolution ───
  FullPath := ResolveBinaryPath(Cmd);
  if FullPath = '' then
  begin
    SetLastError('binary not found: ' + Cmd);
    Exit;
  end;

  // ─── Build argv (di parent, bukan child) ───
  N := Length(Args);
  SetLength(Argv, N + 2);
  Argv[0] := StrNew(PChar(FullPath));
  for i := 0 to N - 1 do
    Argv[i + 1] := StrNew(PChar(Args[i]));
  Argv[N + 1] := nil;

  // ─── Build sanitized envp (di parent) ───
  UseEnvP := False;
  EnvpCount := 0;
  SetLength(Envp, 0);
  if Assigned(GExecPolicy) and (GExecPolicy.Mode <> epmAllowAll) then
  begin
    BuildSanitizedEnv(Envp, EnvpCount);
    UseEnvP := EnvpCount > 0;
  end;

  // ─── Pre-fetch cwd (di parent) ───
  ChdirTarget := '';
  if Assigned(GExecPolicy) then
    ChdirTarget := GExecPolicy.DefaultCwd;

  // ─── Create pipes ───
  if fpPipe(InP) <> 0 then
  begin
    SetLastError('pipe(stdin) gagal');
    for i := 0 to N + 1 do
      if Assigned(Argv[i]) then StrDispose(Argv[i]);
    if UseEnvP then FreeEnvArray(Envp);
    Exit;
  end;
  if fpPipe(OutP) <> 0 then
  begin
    fpClose(InP[0]); fpClose(InP[1]);
    SetLastError('pipe(stdout) gagal');
    for i := 0 to N + 1 do
      if Assigned(Argv[i]) then StrDispose(Argv[i]);
    if UseEnvP then FreeEnvArray(Envp);
    Exit;
  end;
  if fpPipe(ErrP) <> 0 then
  begin
    fpClose(InP[0]); fpClose(InP[1]);
    fpClose(OutP[0]); fpClose(OutP[1]);
    SetLastError('pipe(stderr) gagal');
    for i := 0 to N + 1 do
      if Assigned(Argv[i]) then StrDispose(Argv[i]);
    if UseEnvP then FreeEnvArray(Envp);
    Exit;
  end;

  // ─── Fork ───
  Pid := fpFork;
  if Pid < 0 then
  begin
    fpClose(InP[0]); fpClose(InP[1]);
    fpClose(OutP[0]); fpClose(OutP[1]);
    fpClose(ErrP[0]); fpClose(ErrP[1]);
    SetLastError('fork gagal');
    for i := 0 to N + 1 do
      if Assigned(Argv[i]) then StrDispose(Argv[i]);
    if UseEnvP then FreeEnvArray(Envp);
    Exit;
  end;

  if Pid = 0 then
  begin
    // ─── CHILD ───
    // Hanya async-signal-safe calls di sini.

    if fpDup2(InP[0], 0) < 0 then fpExit(127);
    if fpDup2(OutP[1], 1) < 0 then fpExit(127);
    if fpDup2(ErrP[1], 2) < 0 then fpExit(127);

    fpClose(InP[0]); fpClose(InP[1]);
    fpClose(OutP[0]); fpClose(OutP[1]);
    fpClose(ErrP[0]); fpClose(ErrP[1]);

    // Apply rlimit (sebelum exec)
    {$IFDEF UNIX}
    try ApplyRlimitsInChild; except end;
    {$ENDIF}

    // Chdir kalau di-set
    if ChdirTarget <> '' then
      fpChdir(PChar(ChdirTarget));

    // Exec dengan envp (kalau disanitasi) atau inherit
    if UseEnvP then
      fpExecve(PChar(FullPath), @Argv[0], @Envp[0])
    else
      fpExecvp(PChar(FullPath), @Argv[0]);

    // Exec gagal
    fpExit(127);
  end;

  // ─── PARENT ───
  fpClose(InP[0]);
  fpClose(OutP[1]);
  fpClose(ErrP[1]);

  // Bebaskan string argv + envp
  for i := 0 to N + 1 do
    if Assigned(Argv[i]) then StrDispose(Argv[i]);
  if UseEnvP then FreeEnvArray(Envp);

  GSlots[Slot].Pid := Pid;
  GSlots[Slot].StdinW := InP[1];
  GSlots[Slot].StdoutR := OutP[0];
  GSlots[Slot].StderrR := ErrP[0];
  GSlots[Slot].Running := True;

  InterlockedIncrement(GActiveProcessCount);

  SetLastError('');
  Result := True;
end;

function DoNonBlockingReadPosix(Fd: Integer; MaxBytes: Integer;
  out Data: RawByteString): Integer;
var
  FDS: TFDSet;
  TV: TTimeVal;
  Buf: array[0..4095] of Byte;
  R, Cap: Integer;
begin
  Data := '';
  if Fd < 0 then Exit(PROC_READ_CLOSED);
  
  fpFD_ZERO(FDS);
  fpFD_SET(Fd, FDS);
  TV.tv_sec := 0;
  TV.tv_usec := 0;
  
  if fpSelect(Fd + 1, @FDS, nil, nil, @TV) <= 0 then
    Exit(PROC_READ_ERR);
  
  Cap := MaxBytes;
  if Cap <= 0 then Cap := 4096;
  if Cap > SizeOf(Buf) then Cap := SizeOf(Buf);
  if Cap > PROC_MAX_READ then Cap := PROC_MAX_READ;
  
  R := fpRead(Fd, @Buf[0], Cap);
  if R < 0 then Exit(PROC_READ_ERR);
  if R = 0 then Exit(PROC_READ_CLOSED);
  
  SetLength(Data, R);
  Move(Buf[0], Data[1], R);
  Result := R;
end;

function DoBlockingReadPosix(Fd: Integer; MaxBytes, TimeoutMs: Integer;
  out Data: RawByteString): Integer;
var
  FDS: TFDSet;
  TV: TTimeVal;
  Buf: array[0..4095] of Byte;
  R, Cap, SelRes: Integer;
begin
  Data := '';
  if Fd < 0 then Exit(PROC_READ_CLOSED);
  
  fpFD_ZERO(FDS);
  fpFD_SET(Fd, FDS);
  TV.tv_sec := TimeoutMs div 1000;
  TV.tv_usec := (TimeoutMs mod 1000) * 1000;
  
  SelRes := fpSelect(Fd + 1, @FDS, nil, nil, @TV);
  if SelRes = 0 then Exit(PROC_READ_ERR);  // timeout
  if SelRes < 0 then Exit(PROC_READ_ERR);
  
  Cap := MaxBytes;
  if Cap <= 0 then Cap := 4096;
  if Cap > SizeOf(Buf) then Cap := SizeOf(Buf);
  if Cap > PROC_MAX_READ then Cap := PROC_MAX_READ;
  
  R := fpRead(Fd, @Buf[0], Cap);
  if R < 0 then Exit(PROC_READ_ERR);
  if R = 0 then Exit(PROC_READ_CLOSED);
  
  SetLength(Data, R);
  Move(Buf[0], Data[1], R);
  Result := R;
end;

function DoWaitPosix(Pid: Integer; TimeoutMs: Integer;
    out ExitCode: Integer): Boolean;
var
  Status: Integer;
  R: TPid;
  StartTime, Now: QWord;
begin
  Result := False;
  ExitCode := -1;
  StartTime := GetTickCount64;
  
  repeat
    R := fpWaitPid(Pid, @Status, WNOHANG);
    if R = Pid then
    begin
      if WIFEXITED(Status) then
        ExitCode := WEXITSTATUS(Status)
      else if WIFSIGNALED(Status) then
        ExitCode := -(128 + WTERMSIG(Status))
      else
        ExitCode := -1;
      Exit(True);
    end
    else if R < 0 then
    begin
      // ECHILD — proses sudah di-wait oleh someone else
      // atau tidak valid
      ExitCode := -1;
      Exit(False);
    end;
    
    // R = 0 → masih running
    if TimeoutMs > 0 then
    begin
      Now := GetTickCount64;
      if (Now - StartTime) >= QWord(TimeoutMs) then
        Exit(False);  // timeout
    end;
    Sleep(10);
  until False;
end;

function DoReapPosix(Pid: Integer; out ExitCode: Integer): Boolean;
var
  Status: Integer;
  R: TPid;
begin
  Result := False;
  ExitCode := -1;
  
  R := fpWaitPid(Pid, @Status, WNOHANG);
  if R = Pid then
  begin
    if WIFEXITED(Status) then
      ExitCode := WEXITSTATUS(Status)
    else if WIFSIGNALED(Status) then
      ExitCode := -(128 + WTERMSIG(Status));
    Result := True;   // ← proses direap
  end;
  // R = 0 → masih hidup; R < 0 → error/ECHILD
end;

function ProcessAlivePosix(Pid: Integer): Boolean;
var
  R: TPid;
begin
  R := fpWaitPid(Pid, nil, WNOHANG);
  Result := (R = 0);   // 0 = masih hidup, Pid = sudah exit
end;

procedure DoKillPosix(Pid: Integer);
var
  I: Integer;
begin
  // Graceful: SIGTERM
  fpKill(Pid, SIGTERM);

  // Tunggu sampai 1 detik
  for I := 1 to 10 do
  begin
    if not ProcessAlivePosix(Pid) then Exit;
    Sleep(100);
  end;

  // Escalate: SIGKILL
  fpKill(Pid, SIGKILL);
end;

{$ENDIF UNIX}

// ════════════════════════════════════════════════════════════════
//  Windows implementation
// ════════════════════════════════════════════════════════════════
{$IFDEF WINDOWS}

function BuildCommandLine(const Cmd: string; const Args: array of string): string;
var i: Integer;
begin
  // Windows command line: command + args dipisahkan spasi, masing-masing
  // argumen yang punya spasi di-quote.
  Result := '"' + Cmd + '"';
  for i := 0 to High(Args) do
  begin
    Result := Result + ' ';
    if Pos(' ', Args[i]) > 0 then
      Result := Result + '"' + Args[i] + '"'
    else
      Result := Result + Args[i];
  end;
end;

function DoSpawnWindows(const Cmd: string; const Args: array of string;
                        Slot: Integer): Boolean;
var
  SA: TSecurityAttributes;
  InRead, InWrite, OutRead, OutWrite, ErrRead, ErrWrite: THandle;
  SI: TStartupInfoA;
  PI: TProcessInformation;
  CmdLine: string;
begin
  Result := False;
  
  SA.nLength := SizeOf(SA);
  SA.bInheritHandle := True;
  SA.lpSecurityDescriptor := nil;
  
  // Buat pipe stdin
  if not CreatePipe(InRead, InWrite, @SA, 0) then
  begin
    SetLastError('CreatePipe(stdin) gagal');
    Exit;
  end;
  SetHandleInformation(InWrite, HANDLE_FLAG_INHERIT, 0);
  
  // Pipe stdout
  if not CreatePipe(OutRead, OutWrite, @SA, 0) then
  begin
    CloseHandle(InRead); CloseHandle(InWrite);
    SetLastError('CreatePipe(stdout) gagal');
    Exit;
  end;
  SetHandleInformation(OutRead, HANDLE_FLAG_INHERIT, 0);
  
  // Pipe stderr
  if not CreatePipe(ErrRead, ErrWrite, @SA, 0) then
  begin
    CloseHandle(InRead); CloseHandle(InWrite);
    CloseHandle(OutRead); CloseHandle(OutWrite);
    SetLastError('CreatePipe(stderr) gagal');
    Exit;
  end;
  SetHandleInformation(ErrRead, HANDLE_FLAG_INHERIT, 0);
  
  FillChar(SI, SizeOf(SI), 0);
  SI.cb := SizeOf(SI);
  SI.dwFlags := STARTF_USESTDHANDLES;
  SI.hStdInput := InRead;
  SI.hStdOutput := OutWrite;
  SI.hStdError := ErrWrite;
  
  CmdLine := BuildCommandLine(Cmd, Args);
  
  if not CreateProcessA(nil, PChar(CmdLine), nil, nil, True,
                        CREATE_NO_WINDOW, nil, nil, @SI, @PI) then
  begin
    CloseHandle(InRead); CloseHandle(InWrite);
    CloseHandle(OutRead); CloseHandle(OutWrite);
    CloseHandle(ErrRead); CloseHandle(ErrWrite);
    SetLastError('CreateProcess gagal: ' + Cmd);
    Exit;
  end;
  
  // Tutup end yang tidak dipakai parent
  CloseHandle(InRead);
  CloseHandle(OutWrite);
  CloseHandle(ErrWrite);
  
  GSlots[Slot].Pid := PI.dwProcessId;
  GSlots[Slot].ProcHandle := PI.hProcess;
  GSlots[Slot].ThreadHandle := PI.hThread;
  GSlots[Slot].StdinW := InWrite;
  GSlots[Slot].StdoutR := OutRead;
  GSlots[Slot].StderrR := ErrRead;
  GSlots[Slot].Running := True;
  
  SetLastError('');
  Result := True;
end;

function DoNonBlockingReadWindows(Fd: THandle; MaxBytes: Integer;
                                  out Data: RawByteString): Integer;
var
  Avail, R: DWORD;
  Buf: array[0..4095] of Byte;
  Cap: Integer;
begin
  Data := '';
  if Fd = 0 then Exit(PROC_READ_CLOSED);
  
  if not PeekNamedPipe(Fd, nil, 0, nil, @Avail, nil) then
    Exit(PROC_READ_ERR);
  if Avail = 0 then Exit(PROC_READ_ERR);
  
  Cap := MaxBytes;
  if Cap <= 0 then Cap := 4096;
  if Cap > SizeOf(Buf) then Cap := SizeOf(Buf);
  if Cap > PROC_MAX_READ then Cap := PROC_MAX_READ;
  if DWORD(Cap) > Avail then Cap := Avail;
  
  if not ReadFile(Fd, Buf[0], Cap, R, nil) then Exit(PROC_READ_ERR);
  if R = 0 then Exit(PROC_READ_CLOSED);
  
  SetLength(Data, R);
  Move(Buf[0], Data[1], R);
  Result := R;
end;

function DoWaitWindows(ProcHandle: THandle; TimeoutMs: Integer;
                       out ExitCode: Integer): Boolean;
var
  R: DWORD;
  Code: DWORD;
  WaitTime: DWORD;
begin
  Result := False;
  ExitCode := -1;
  
  if TimeoutMs <= 0 then
    WaitTime := INFINITE
  else
    WaitTime := TimeoutMs;
  
  R := WaitForSingleObject(ProcHandle, WaitTime);
  if R = WAIT_TIMEOUT then Exit(False);
  if R <> WAIT_OBJECT_0 then Exit(False);
  
  if not GetExitCodeProcess(ProcHandle, Code) then Exit(False);
  ExitCode := Integer(Code);
  Result := True;
end;

procedure DoKillWindows(ProcHandle: THandle);
begin
  TerminateProcess(ProcHandle, 1);
end;

{$ENDIF WINDOWS}

// ════════════════════════════════════════════════════════════════
//  Public API — cross-platform dispatch
// ════════════════════════════════════════════════════════════════
procedure WriteAuditLog(const Cmd: string;
  const Args: array of string;Allowed: Boolean;
  const Reason: string);
var
  F: TextFile;
  Line, ArgsStr: string;
  I: Integer;
  LogPath: string;
begin
  if not Assigned(GExecPolicy) then Exit;
  LogPath := GExecPolicy.AuditLogPath;
  if LogPath = '' then Exit;

  ArgsStr := '';
  for I := 0 to High(Args) do
  begin
    if I > 0 then ArgsStr := ArgsStr + ' ';
    if Pos(' ', Args[I]) > 0 then
      ArgsStr := ArgsStr + '"' + Args[I] + '"'
    else
      ArgsStr := ArgsStr + Args[I];
  end;

  Line := Format('[%s] pid=%d cmd=%s args=%s allowed=%s reason=%s',
    [FormatDateTime('yyyy-mm-dd hh:nn:ss', Now),
     GetProcessID, Cmd, ArgsStr,
     BoolToStr(Allowed, 'yes', 'no'),
     Reason]);

  try
    AssignFile(F, LogPath);
    if FileExists(LogPath) then
      Append(F)
    else
      Rewrite(F);
    try
      WriteLn(F, Line);
    finally
      CloseFile(F);
    end;
  except
    // Audit log failure tidak boleh block exec
  end;
end;

function ProcSpawn(const Cmd: string; const Args: array of string;
    out Proc: Integer): Boolean;
var Slot: Integer; Reason: string;
begin
  Result := False;
  Proc := -1;
  
  if not Assigned(GLock) then
  begin
    SetLastError('ProcInit belum dipanggil');
    Exit;
  end;

  // ─── Concurrent limit ───
  if Assigned(GExecPolicy) and (GExecPolicy.MaxConcurrent > 0) then
  begin
    if GetActiveProcessCount >= GExecPolicy.MaxConcurrent then
    begin
      SetLastError('concurrent exec limit tercapai: ' +
                   IntToStr(GExecPolicy.MaxConcurrent));
      Exit;
    end;
  end;

  // ─── Whitelist check (defense in depth — native layer juga cek) ───
  begin
    if not ProcIsExecAllowed(Cmd, Reason) then
    begin
      WriteAuditLog(Cmd, Args, False, Reason);
      SetLastError('exec denied: ' + Reason);
      Exit;
    end;
  end;
  
  // Concurrent limit cek log juga
  if Assigned(GExecPolicy) and (GExecPolicy.MaxConcurrent > 0) then
  begin
    if GetActiveProcessCount >= GExecPolicy.MaxConcurrent then
    begin
      WriteAuditLog(Cmd, Args, False,
        'concurrent limit ' + IntToStr(GExecPolicy.MaxConcurrent));
      SetLastError('concurrent exec limit tercapai');
      Exit;
    end;
  end;
  
  Slot := AllocSlot;
  if Slot < 0 then
  begin
    SetLastError('slot proses penuh (max 256)');
    Exit;
  end;
  
  {$IFDEF UNIX}
  Result := DoSpawnPosix(Cmd, Args, Slot);
  {$ENDIF}
  {$IFDEF WINDOWS}
  Result := DoSpawnWindows(Cmd, Args, Slot);
  {$ENDIF}
  
  if Result then
  begin
    Proc := Slot;
    WriteAuditLog(Cmd, Args, True, 'ok');
  end
  else
  begin
    WriteAuditLog(Cmd, Args, False, ProcLastError);
    GLock.Acquire;
    try GSlots[Slot].Used := False;
    finally GLock.Release;
    end;
  end;
end;

function ProcReadStdout(Proc: Integer; MaxBytes: Integer;
                        out Data: RawByteString): Integer;
var E: PSProcEntry;
begin
  Data := '';
  E := GetSlot(Proc);
  if (E = nil) or (E^.StdoutR < 0) then Exit(PROC_READ_CLOSED);
  
  {$IFDEF UNIX}
  Result := DoNonBlockingReadPosix(E^.StdoutR, MaxBytes, Data);
  {$ENDIF}
  {$IFDEF WINDOWS}
  Result := DoNonBlockingReadWindows(E^.StdoutR, MaxBytes, Data);
  {$ENDIF}
  
  if Result = PROC_READ_CLOSED then
  begin
    GLock.Acquire;
    try
      if E^.StdoutR >= 0 then
      begin
        {$IFDEF UNIX} fpClose(E^.StdoutR); {$ENDIF}
        {$IFDEF WINDOWS} CloseHandle(E^.StdoutR); {$ENDIF}
        E^.StdoutR := -1;
      end;
    finally
      GLock.Release;
    end;
  end;
end;

function ProcReadStderr(Proc: Integer; MaxBytes: Integer;
                        out Data: RawByteString): Integer;
var E: PSProcEntry;
begin
  Data := '';
  E := GetSlot(Proc);
  if (E = nil) or (E^.StderrR < 0) then Exit(PROC_READ_CLOSED);
  
  {$IFDEF UNIX}
  Result := DoNonBlockingReadPosix(E^.StderrR, MaxBytes, Data);
  {$ENDIF}
  {$IFDEF WINDOWS}
  Result := DoNonBlockingReadWindows(E^.StderrR, MaxBytes, Data);
  {$ENDIF}
  
  if Result = PROC_READ_CLOSED then
  begin
    GLock.Acquire;
    try
      if E^.StderrR >= 0 then
      begin
        {$IFDEF UNIX} fpClose(E^.StderrR); {$ENDIF}
        {$IFDEF WINDOWS} CloseHandle(E^.StderrR); {$ENDIF}
        E^.StderrR := -1;
      end;
    finally
      GLock.Release;
    end;
  end;
end;

function ProcReadTimeout(Proc: Integer; WhichStream: Integer;
                         MaxBytes, TimeoutMs: Integer;
                         out Data: RawByteString): Integer;
var E: PSProcEntry; Fd: Integer;
begin
  Data := '';
  E := GetSlot(Proc);
  if E = nil then Exit(PROC_READ_ERR);
  
  if WhichStream = PROC_STREAM_STDOUT then
    Fd := E^.StdoutR
  else
    Fd := E^.StderrR;
  
  if Fd < 0 then Exit(PROC_READ_CLOSED);
  
  if TimeoutMs = 0 then
  begin
    // Non-blocking
    if WhichStream = PROC_STREAM_STDOUT then
      Exit(ProcReadStdout(Proc, MaxBytes, Data))
    else
      Exit(ProcReadStderr(Proc, MaxBytes, Data));
  end;
  
  {$IFDEF UNIX}
  Result := DoBlockingReadPosix(Fd, MaxBytes, TimeoutMs, Data);
  {$ENDIF}
  {$IFDEF WINDOWS}
  // Windows: belum ada implementasi blocking dengan timeout.
  // Fallback ke non-blocking.
  if WhichStream = PROC_STREAM_STDOUT then
    Result := ProcReadStdout(Proc, MaxBytes, Data)
  else
    Result := ProcReadStderr(Proc, MaxBytes, Data);
  {$ENDIF}
end;

function ProcWriteStdin(Proc: Integer; DataPtr: Pointer; DataLen: Integer): Integer;
var E: PSProcEntry; Total, W: Integer; P: PByte;
begin
  E := GetSlot(Proc);
  if (E = nil) or (E^.StdinW < 0) then Exit(PROC_WRITE_ERR);
  if (DataLen <= 0) or (DataPtr = nil) then Exit(0);
  
  Total := 0;
  P := PByte(DataPtr);
  {$IFDEF UNIX}
  while Total < DataLen do
  begin
    W := fpWrite(E^.StdinW, P^, DataLen - Total);
    if W <= 0 then Exit(PROC_WRITE_ERR);
    Inc(Total, W);
    Inc(P, W);
  end;
  {$ENDIF}
  {$IFDEF WINDOWS}
  if not WriteFile(E^.StdinW, DataPtr^, DataLen, DWORD(W), nil) then
    Exit(PROC_WRITE_ERR);
  Total := W;
  {$ENDIF}
  Result := Total;
end;

procedure ProcCloseStdin(Proc: Integer);
var E: PSProcEntry;
begin
  E := GetSlot(Proc);
  if (E = nil) or (E^.StdinW < 0) then Exit;
  GLock.Acquire;
  try
    if E^.StdinW >= 0 then
    begin
      {$IFDEF UNIX} fpClose(E^.StdinW); {$ENDIF}
      {$IFDEF WINDOWS} CloseHandle(E^.StdinW); {$ENDIF}
      E^.StdinW := -1;
    end;
  finally
    GLock.Release;
  end;
end;

procedure MarkSlotNotRunning(E: PSProcEntry); inline;
begin
  if not Assigned(E) then Exit;
  if E^.Running then
  begin
    E^.Running := False;
    InterlockedDecrement(GActiveProcessCount);
  end;
end;

function ProcWait(Proc: Integer; TimeoutMs: Integer;
    out ExitCode: Integer): Boolean;
var E: PSProcEntry;
begin
  Result := False;
  ExitCode := -1;
  E := GetSlot(Proc);
  if E = nil then Exit;
  
  if not E^.Running then
  begin
    ExitCode := E^.ExitCode;
    Exit(True);
  end;
  
  {$IFDEF UNIX}
  Result := DoWaitPosix(E^.Pid, TimeoutMs, ExitCode);
  {$ENDIF}
  {$IFDEF WINDOWS}
  Result := DoWaitWindows(E^.ProcHandle, TimeoutMs, ExitCode);
  {$ENDIF}
  
  if Result then
  begin
    MarkSlotNotRunning(E);
    E^.ExitCode := ExitCode;  
  end;
end;

function ProcIsRunning(Proc: Integer): Boolean;
var E: PSProcEntry; 
begin
  Result := False;
  E := GetSlot(Proc);
  if E = nil then Exit;
  if not E^.Running then Exit(False);
  
  {$IFDEF UNIX}
  // ✅ FIX: DoReapPosix melakukan WNOHANG dan mengembalikan status
  // jika proses sudah exit. Ini mencegah double-reap yang menyebabkan
  // exit code hilang (stuck di -1).
  if DoReapPosix(E^.Pid, E^.ExitCode) then
  begin
    MarkSlotNotRunning(E);
    Result := False;
  end
  else
    Result := True;   // masih hidup atau status belum diketahui
  {$ENDIF}
  
  {$IFDEF WINDOWS}
  var Code: DWORD;
  if GetExitCodeProcess(E^.ProcHandle, Code) then
  begin
    if Code <> STILL_ACTIVE then
    begin
      MarkSlotNotRunning(E);
      E^.ExitCode := Integer(Code);
      Result := False;
    end
    else
      Result := True;
  end;
  {$ENDIF}
end;

procedure ProcKill(Proc: Integer);
var E: PSProcEntry;
begin
  E := GetSlot(Proc);
  if (E = nil) or (not E^.Running) then Exit;
  
  {$IFDEF UNIX}
  DoKillPosix(E^.Pid);
  {$ENDIF}
  {$IFDEF WINDOWS}
  DoKillWindows(E^.ProcHandle);
  {$ENDIF}
end;

procedure DoCleanupSlot(Idx: Integer);
var E: PSProcEntry;
begin
  E := @GSlots[Idx];
  if not E^.Used then Exit;

  // Kalau masih running, kill dulu lalu transisi via helper
  if E^.Running then
  begin
    {$IFDEF UNIX}
    try fpKill(E^.Pid, SIGKILL); except end;
    try fpWaitPid(E^.Pid, nil, 0); except end;
    {$ENDIF}
    {$IFDEF WINDOWS}
    try TerminateProcess(E^.ProcHandle, 1); except end;
    {$ENDIF}
    MarkSlotNotRunning(E);
  end;
  
  // Tutup semua fd
  if E^.StdinW >= 0 then
  begin
    {$IFDEF UNIX} try fpClose(E^.StdinW); except end; {$ENDIF}
    {$IFDEF WINDOWS} try CloseHandle(E^.StdinW); except end; {$ENDIF}
  end;
  if E^.StdoutR >= 0 then
  begin
    {$IFDEF UNIX} try fpClose(E^.StdoutR); except end; {$ENDIF}
    {$IFDEF WINDOWS} try CloseHandle(E^.StdoutR); except end; {$ENDIF}
  end;
  if E^.StderrR >= 0 then
  begin
    {$IFDEF UNIX} try fpClose(E^.StderrR); except end; {$ENDIF}
    {$IFDEF WINDOWS} try CloseHandle(E^.StderrR); except end; {$ENDIF}
  end;
  {$IFDEF WINDOWS}
  if E^.ProcHandle <> 0 then try CloseHandle(E^.ProcHandle); except end;
  if E^.ThreadHandle <> 0 then try CloseHandle(E^.ThreadHandle); except end;
  {$ENDIF}
  
  FillChar(GSlots[Idx], SizeOf(TSProcEntry), 0);
end;

procedure ProcClose(Proc: Integer);
begin
  if not Assigned(GLock) then Exit;
  GLock.Acquire;
  try
    if (Proc >= 0) and (Proc < PROC_MAX_SLOTS) and GSlots[Proc].Used then
      DoCleanupSlot(Proc);
  finally
    GLock.Release;
  end;
end;

// ════════════════════════════════════════════════════════════════
//  High-level ProcExec
// ════════════════════════════════════════════════════════════════
function ProcExec(const Cmd: string; const Args: array of string;
  out Stdout, Stderr: RawByteString;
  out ExitCode: Integer; TimeoutMs: Integer = 0): Boolean;
var
  Proc: Integer;
  E: PSProcEntry;
  Chunk: RawByteString;
  StartTime, Now: QWord;
  R: Integer;
  ShouldExit: Boolean;
  MaxOut: Int64;
  TotalOut, TotalErr: Int64;
  OutputKilled: Boolean;
begin
  Result := False;
  Stdout := '';
  Stderr := '';
  ExitCode := -1;
  TotalOut := 0;
  TotalErr := 0;
  OutputKilled := False;

  MaxOut := DEFAULT_MAX_OUTPUT;
  if Assigned(GExecPolicy) and (GExecPolicy.MaxOutputBytes > 0) then
    MaxOut := GExecPolicy.MaxOutputBytes;

  if not ProcSpawn(Cmd, Args, Proc) then Exit;  
  
  E := GetSlot(Proc);
  if E = nil then
  begin
    ProcClose(Proc);
    Exit;
  end;
  
  // Tutup stdin langsung — exec tidak interaktif
  ProcCloseStdin(Proc);
  
  StartTime := GetTickCount64;
  ShouldExit := False;
  
  while not ShouldExit do
  begin
    // Baca stdout
    if E^.StdoutR >= 0 then
    begin
      R := ProcReadStdout(Proc, 65536, Chunk);
      if R > 0 then
      begin
        Inc(TotalOut, R);
        if (MaxOut > 0) and (TotalOut > MaxOut) then
        begin
          // Truncate + kill
          if not OutputKilled then
          begin
            ProcKill(Proc);
            OutputKilled := True;
          end;
        end else
          Stdout := Stdout + Chunk;
      end;
    end;
    
    // Baca stderr
    if E^.StderrR >= 0 then
    begin
      R := ProcReadStderr(Proc, 65536, Chunk);
      if R > 0 then
      begin
        Inc(TotalErr, R);
        if (MaxOut > 0) and (TotalOut + TotalErr > MaxOut) then
        begin
          if not OutputKilled then
          begin
            ProcKill(Proc);
            OutputKilled := True;
          end;
        end else
          Stderr := Stderr + Chunk;
      end;
    end;
    
    // Cek process masih hidup
    if not ProcIsRunning(Proc) then
    begin
      ProcWait(Proc, 100, ExitCode);
      ShouldExit := True;
    end
    else
    begin
      // Cek timeout
      if TimeoutMs > 0 then
      begin
        Now := GetTickCount64;
        if (Now - StartTime) >= QWord(TimeoutMs) then
        begin
          ProcKill(Proc);
          Sleep(50);
          ProcWait(Proc, 1000, ExitCode);
          ShouldExit := True;
        end;
      end;
    end;
    
    if not ShouldExit then
      Sleep(5);
  end;
  
  // Drain sisa output
  repeat
    R := ProcReadStdout(Proc, 65536, Chunk);
    if R > 0 then Stdout := Stdout + Chunk;
  until R <= 0;
  
  repeat
    R := ProcReadStderr(Proc, 65536, Chunk);
    if R > 0 then Stderr := Stderr + Chunk;
  until R <= 0;
  
  ProcClose(Proc);
  Result := True;
end;

constructor TExecPolicy.Create;
begin
  inherited;
  Mode := epmDenyAll;
  Binaries := TStringList.Create;
  Binaries.Sorted := True;
  Binaries.Duplicates := dupIgnore;
  EnvAllow := TStringList.Create;
  EnvAllow.Sorted := True;
  EnvDeny := TStringList.Create;
  EnvDeny.Sorted := True;
  EnvSet := TStringList.Create;

  // Safe default env vars — cukup untuk Python/Node/shell normal
  EnvAllow.Add('HOME');
  EnvAllow.Add('LANG');
  EnvAllow.Add('LC_ALL');
  EnvAllow.Add('PATH');
  EnvAllow.Add('PREFIX');
  EnvAllow.Add('TERM');
  EnvAllow.Add('TMPDIR');
  EnvAllow.Add('USER');

  // Env vars yang WAJIB di-strip (vektor privilege escalation)
  EnvDeny.Add('LD_LIBRARY_PATH');
  EnvDeny.Add('LD_PRELOAD');
  EnvDeny.Add('LD_AUDIT');
  EnvDeny.Add('PYTHONPATH');
  EnvDeny.Add('PYTHONSTARTUP');
  EnvDeny.Add('NODE_OPTIONS');
  EnvDeny.Add('NODE_PATH');
  EnvDeny.Add('RUBYOPT');
  
  DefaultCwd := '';
  
  MaxConcurrent := DEFAULT_MAX_CONCURRENT;
  MaxOutputBytes := DEFAULT_MAX_OUTPUT;
  Limits.Enabled := True;
  Limits.CpuSec := DEFAULT_CPU_SEC;
  Limits.MemoryBytes := DEFAULT_MEMORY_BYTES;
  Limits.FileSizeBytes := DEFAULT_FILESIZE_BYTES;
  Limits.OpenFiles := DEFAULT_OPEN_FILES;
  Limits.Subprocesses := DEFAULT_SUBPROCESSES;
  AuditLogPath := '';
  ResolvePath := True;
end;

destructor TExecPolicy.Destroy;
begin
  Binaries.Free;
  EnvAllow.Free;
  EnvDeny.Free;
  EnvSet.Free;
  inherited;
end;

procedure TExecPolicy.Assign(Other: TExecPolicy);
begin
  if (Other = nil) or (Other = Self) then Exit;
  Mode := Other.Mode;
  Binaries.Assign(Other.Binaries);
  EnvAllow.Assign(Other.EnvAllow);
  EnvDeny.Assign(Other.EnvDeny);
  EnvSet.Assign(Other.EnvSet);
  DefaultCwd := Other.DefaultCwd;
  MaxConcurrent := Other.MaxConcurrent;
  MaxOutputBytes := Other.MaxOutputBytes;
  Limits := Other.Limits;
  AuditLogPath := Other.AuditLogPath;
  ResolvePath := Other.ResolvePath;
end;

function TExecPolicy.Clone: TExecPolicy;
begin
  Result := TExecPolicy.Create;
  Result.Assign(Self);
end;

{ ─── Policy lifecycle ─── }

procedure InitExecPolicy;
begin
  if Assigned(GExecPolicyLock) then Exit;
  GExecPolicyLock := TCriticalSection.Create;
  GExecPolicy := TExecPolicy.Create;
end;

procedure FreeExecPolicy;
begin
  if Assigned(GExecPolicyLock) then
  begin
    GExecPolicyLock.Acquire;
    try
      if Assigned(GExecPolicy) then
      begin
        GExecPolicy.Free;
        GExecPolicy := nil;
      end;
    finally
      GExecPolicyLock.Release;
    end;
  end;
  if Assigned(GExecPolicyLock) then
  begin
    GExecPolicyLock.Free;
    GExecPolicyLock := nil;
  end;
end;

function ProcGetExecPolicy: TExecPolicy;
begin
  // Borrowed reference — caller tidak boleh Free
  Result := GExecPolicy;
end;

procedure ProcSetExecPolicy(NewPolicy: TExecPolicy);
begin
  if not Assigned(GExecPolicyLock) then
    InitExecPolicy;
  GExecPolicyLock.Acquire;
  try
    if Assigned(NewPolicy) then
      GExecPolicy.Assign(NewPolicy)
    else
      GExecPolicy.Assign(TExecPolicy.Create);  // reset to default
  finally
    GExecPolicyLock.Release;
  end;
end;

function GetActiveProcessCount: Integer;
begin
  Result := InterlockedCompareExchange(GActiveProcessCount, 0, 0);
end;

{ ─── Whitelist check ─── }

function ExtractBinaryName(const Cmd: string): string;
var
  P: Integer;
begin
  // Ambil bagian setelah path separator terakhir
  P := Length(Cmd);
  while (P > 0) and (Cmd[P] <> '/') and (Cmd[P] <> '\') do
    Dec(P);
  Result := Copy(Cmd, P + 1, Length(Cmd));
end;

function ProcIsExecAllowed(const Binary: string; out Reason: string): Boolean;
var
  Name: string;
  Idx: Integer;
  AllowedByPolicy: Boolean;
begin
  Result := False;
  Reason := '';

  if not Assigned(GExecPolicy) then
  begin
    Reason := 'policy belum di-init';
    Exit;
  end;

  GExecPolicyLock.Acquire;
  try
    case GExecPolicy.Mode of
      epmDenyAll:
        begin
          Reason := 'exec policy: DENY ALL (default aman)';
          Exit;
        end;
      epmAllowAll:
        begin
          // Warning satu kali
          Result := True;
          Exit;
        end;
      epmWhitelist:
        begin
          Name := ExtractBinaryName(Binary);
          Idx := GExecPolicy.Binaries.IndexOf(Name);
          AllowedByPolicy := (Idx >= 0);
          if not AllowedByPolicy then
          begin
            Reason := 'binary "' + Name + '" tidak ada di whitelist';
            Exit;
          end;
          Result := True;
        end;
    end;
  finally
    GExecPolicyLock.Release;
  end;
end;

{ ─── Path resolution ─── }

function ResolveBinaryPath(const Cmd: string): string;
var
  SearchPath: string;
  Paths: TStringArray;
  I: Integer;
  FullPath: string;
  Policy: TExecPolicy;
  EnvSetPath: string;
  Idx: Integer;
begin
  Result := '';

  // 1. Kalau Cmd berisi separator — treat as explicit path
  if (Pos('/', Cmd) > 0) or (Pos('\', Cmd) > 0) then
  begin
    if FileExists(Cmd) then
      Result := Cmd
    else
      Result := '';
    Exit;
  end;

  // 2. Ambil PATH dari policy (EnvSet) atau default
  Policy := GExecPolicy;
  SearchPath := '';
  if Assigned(Policy) then
  begin
    GExecPolicyLock.Acquire;
    try
      Idx := Policy.EnvSet.IndexOfName('PATH');
      if Idx >= 0 then
        SearchPath := Policy.EnvSet.ValueFromIndex[Idx];
    finally
      GExecPolicyLock.Release;
    end;
  end;

  // Fallback: system PATH yang aman
  if SearchPath = '' then
  begin
    EnvSetPath := GetEnvironmentVariable('PREFIX');
    if EnvSetPath <> '' then
      SearchPath := EnvSetPath + '/bin:/usr/bin:/bin'
    else
      SearchPath := '/usr/bin:/bin:/usr/local/bin';
  end;

  // 3. Split dan cari
  Paths := SearchPath.Split([':']);
  for I := 0 to High(Paths) do
  begin
    FullPath := Paths[I] + '/' + Cmd;
    if FileExists(FullPath) then
    begin
      Result := FullPath;
      Exit;
    end;
  end;
end;

{ ─── Env sanitization ─── }

// Build envp array untuk execve. Caller harus FreeEnvArray setelahnya.
// Return Count = 0 → caller pakai execvp (inherit env).
procedure BuildSanitizedEnv(out EnvP: TEnvPArray; out Count: Integer);
var
  I, J: Integer;
  VarName, VarValue, KeyVal: string;
  EnvList: TStringList;
  Policy: TExecPolicy;
begin
  SetLength(EnvP, 0);
  Count := 0;

  Policy := GExecPolicy;

  // Mode allow-all: caller gunakan execvp (inherit env parent)
  if (Policy = nil) or (Policy.Mode = epmAllowAll) then
    Exit;

  EnvList := TStringList.Create;
  try
    EnvList.Sorted := True;
    EnvList.Duplicates := dupIgnore;

    GExecPolicyLock.Acquire;
    try
      // Step 1: EnvSet (force-set)
      for I := 0 to Policy.EnvSet.Count - 1 do
      begin
        KeyVal := Policy.EnvSet[I];
        J := Pos('=', KeyVal);
        if J > 0 then
        begin
          VarName := Copy(KeyVal, 1, J - 1);
          VarValue := Copy(KeyVal, J + 1, Length(KeyVal));
          EnvList.Values[VarName] := VarValue;
        end;
      end;

      // Step 2: EnvAllow (pass through dari parent)
      for I := 0 to Policy.EnvAllow.Count - 1 do
      begin
        VarName := Policy.EnvAllow[I];
        if EnvList.IndexOfName(VarName) >= 0 then Continue;
        if Policy.EnvDeny.IndexOf(VarName) >= 0 then Continue;
        VarValue := GetEnvironmentVariable(VarName);
        if VarValue <> '' then
          EnvList.Values[VarName] := VarValue;
      end;

      // Step 3: Pastikan PATH ada
      if EnvList.IndexOfName('PATH') < 0 then
        EnvList.Values['PATH'] := '/usr/bin:/bin';
    finally
      GExecPolicyLock.Release;
    end;

    // Build PChar array
    Count := EnvList.Count;
    SetLength(EnvP, Count + 1);
    for I := 0 to Count - 1 do
      EnvP[I] := StrNew(PChar(EnvList[I]));
    EnvP[Count] := nil;
  finally
    EnvList.Free;
  end;
end;

procedure FreeEnvArray(var EnvP: TEnvPArray);
var
  I: Integer;
begin
  for I := 0 to High(EnvP) do
    if Assigned(EnvP[I]) then
      StrDispose(EnvP[I]);
  SetLength(EnvP, 0);
end;

{ ─── rlimit ─── }

{$IFDEF UNIX}
procedure ApplyRlimitsInChild;
var
  R: TRLimitRec;
  Policy: TExecPolicy;
begin
  Policy := GExecPolicy;
  if (Policy = nil) or (not Policy.Limits.Enabled) then Exit;

  // CPU time
  if Policy.Limits.CpuSec > 0 then
  begin
    R.rlim_cur := NativeUInt(Policy.Limits.CpuSec);
    R.rlim_max := NativeUInt(Policy.Limits.CpuSec + 5);
    c_setrlimit(RLIMIT_CPU_C, @R);
  end;

  // Memory (virtual address space)
  if Policy.Limits.MemoryBytes > 0 then
  begin
    R.rlim_cur := NativeUInt(Policy.Limits.MemoryBytes);
    R.rlim_max := NativeUInt(Policy.Limits.MemoryBytes);
    c_setrlimit(RLIMIT_AS_C, @R);
  end;

  // File size
  if Policy.Limits.FileSizeBytes > 0 then
  begin
    R.rlim_cur := NativeUInt(Policy.Limits.FileSizeBytes);
    R.rlim_max := NativeUInt(Policy.Limits.FileSizeBytes);
    c_setrlimit(RLIMIT_FSIZE_C, @R);
  end;

  // Open files
  if Policy.Limits.OpenFiles > 0 then
  begin
    R.rlim_cur := NativeUInt(Policy.Limits.OpenFiles);
    R.rlim_max := NativeUInt(Policy.Limits.OpenFiles);
    c_setrlimit(RLIMIT_NOFILE_C, @R);
  end;

  // Subprocesses — sering diabaikan di Android, tapi tetap coba
  if Policy.Limits.Subprocesses > 0 then
  begin
    R.rlim_cur := NativeUInt(Policy.Limits.Subprocesses);
    R.rlim_max := NativeUInt(Policy.Limits.Subprocesses);
    c_setrlimit(RLIMIT_NPROC_C, @R);
  end;

  // No core dump
  R.rlim_cur := 0;
  R.rlim_max := 0;
  c_setrlimit(RLIMIT_CORE_C, @R);
end;
{$ENDIF}

initialization
  GInitCount := 0;

finalization
  //FreeExecPolicy;
  if Assigned(GLock) then GLock.Free;
  if Assigned(GInitLock) then GInitLock.Free;
  if Assigned(GLastErrorLock) then GLastErrorLock.Free;
  
end.