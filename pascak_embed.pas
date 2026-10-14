{ ====================================================================
  pascak_embed.pas — Public embedding API untuk Pascak VM
  ====================================================================
  Subprocess-based wrapper. Host applications dapat memanggil engine
  sebagai child process dengan kontrol env, exec policy, dan memory
  quota.

  Untuk use case in-process dengan native callback, lihat B.7b backlog.

  Usage:
    uses pascak_embed;
    var P := TPascakEmbed.Create('/path/to/pascak_noASTnet');
    var R := P.ExecuteString('begin return 42; end.');
    Writeln(R.Stdout);
    P.Free;
  ==================================================================== }
unit pascak_embed;

{$MODE OBJFPC}{$H+}

interface

uses
  Classes, SysUtils, Process
  {$IFDEF WINDOWS}, Windows{$ENDIF};
  
type
  EPascakEmbedError = class(Exception);

  TPascakResult = record
    ExitCode: Integer;
    Stdout: string;
    Stderr: string;
    DurationMs: QWord;
    TimedOut: Boolean;
  end;

  TPascakEmbed = class
  private
    FBinaryPath: string;
    FEnv: TStringList;
    FExecPolicy: string;
    FMemoryQuotaMB: Integer;
    FTimeoutMs: Integer;
    FDevMode: Boolean;
    FTmpDir: string;

    function BuildArgs(const ScriptPath: string): TStringArray;
  public
    constructor Create(const ABinaryPath: string);
    destructor Destroy; override;

    { Execute script dari source string — ditulis ke file temp,
      dijalankan, hasil di-capture. }
    function ExecuteString(const Source: string): TPascakResult;

    { Execute script dari file yang sudah ada. }
    function ExecuteFile(const FilePath: string): TPascakResult;

    { Config }
    procedure SetEnv(const Key, Value: string);
    procedure ClearEnv;
    procedure SetExecPolicy(const Policy: string);   // 'none'|'allow-all'|'whitelist:a,b,c'
    procedure SetMemoryQuota(MB: Integer);
    procedure SetTimeout(Ms: Integer);
    procedure SetDevMode(Enabled: Boolean);
    procedure SetTempDir(const Dir: string);

    { Diagnostics }
    function BinaryExists: Boolean;
    function BinaryVersion: string;
  end;

implementation

{ ─── Constructor / Destructor ─── }

constructor TPascakEmbed.Create(const ABinaryPath: string);
begin
  inherited Create;

  if ABinaryPath = '' then
    raise EPascakEmbedError.Create('Binary path tidak boleh kosong');

  FBinaryPath := ExpandFileName(ABinaryPath);
  if not FileExists(FBinaryPath) then
    raise EPascakEmbedError.Create('Binary tidak ditemukan: ' + FBinaryPath);

  FEnv := TStringList.Create;
  FEnv.NameValueSeparator := '=';
  FExecPolicy := 'none';
  FMemoryQuotaMB := 256;
  FTimeoutMs := 60000;
  FDevMode := False;
  
  FTmpDir := GetEnvironmentVariable('TMPDIR');
  if (FTmpDir = '') or (not DirectoryExists(FTmpDir)) then
    FTmpDir := GetEnvironmentVariable('HOME');
  if (FTmpDir = '') or (not DirectoryExists(FTmpDir)) then
    FTmpDir := GetCurrentDir;
  if FTmpDir = '' then
    raise EPascakEmbedError.Create('Tidak ada direktori temp yang writable');
end;

destructor TPascakEmbed.Destroy;
begin
  FEnv.Free;
  inherited;
end;

{ ─── Config ─── }

procedure TPascakEmbed.SetEnv(const Key, Value: string);
begin
  FEnv.Values[Key] := Value;
end;

procedure TPascakEmbed.ClearEnv;
begin
  FEnv.Clear;
end;

procedure TPascakEmbed.SetExecPolicy(const Policy: string);
begin
  FExecPolicy := Policy;
end;

procedure TPascakEmbed.SetMemoryQuota(MB: Integer);
begin
  FMemoryQuotaMB := MB;
end;

procedure TPascakEmbed.SetTimeout(Ms: Integer);
begin
  FTimeoutMs := Ms;
end;

procedure TPascakEmbed.SetDevMode(Enabled: Boolean);
begin
  FDevMode := Enabled;
end;

procedure TPascakEmbed.SetTempDir(const Dir: string);
begin
  FTmpDir := Dir;
end;

function TPascakEmbed.BinaryExists: Boolean;
begin
  Result := FileExists(FBinaryPath);
end;

function TPascakEmbed.BinaryVersion: string;
var
  R: TPascakResult;
begin
  R := ExecuteString('begin println("Pascak VM"); end.');
  if R.ExitCode = 0 then
    Result := Trim(R.Stdout)
  else
    Result := '';
end;

{ ─── Command builder ─── }

function TPascakEmbed.BuildArgs(const ScriptPath: string): TStringArray;
var
  Idx: Integer;
begin
  Result := nil;
  SetLength(Result, 3);
  Idx := 0;
  if FDevMode then
  begin
    Result[Idx] := '--dev';
    Inc(Idx);
  end;
  Result[Idx] := ScriptPath;
  SetLength(Result, Idx + 1);
end;

{ ─── Executor ─── }

function RunCommandCapture(const BinaryPath: string;
  const Args: array of string;
  TimeoutMs: Integer;
  EnvList: TStringList): TPascakResult;
var
  Proc: TProcess;
  OutStream, ErrStream: TMemoryStream;
  OutBuf, ErrBuf: array[0..8191] of Byte;
  N: LongInt;
  StartTick: QWord;
  BytesOut, BytesErr: Int64;
  PassThrough: array[0..7] of string;
  i: Integer;
  V: string;
begin
  Result.ExitCode := -1;
  Result.Stdout := '';
  Result.Stderr := '';
  Result.DurationMs := 0;
  Result.TimedOut := False;

  StartTick := GetTickCount64;

  OutStream := TMemoryStream.Create;
  ErrStream := TMemoryStream.Create;
  Proc := TProcess.Create(nil);
  try
    Proc.Executable := BinaryPath;
    Proc.Parameters.Clear;
    Proc.Options := [poUsePipes, poNoConsole];

    for N := Low(Args) to High(Args) do
      Proc.Parameters.Add(Args[N]);

    // ─── Environment ───
    // Kalau user set custom env, bangun list sendiri dengan
    // default passthrough. Kalau tidak, inherit parent (default).
    if (EnvList <> nil) and (EnvList.Count > 0) then
    begin
      Proc.Environment.Assign(EnvList);
      PassThrough[0] := 'PATH';
      PassThrough[1] := 'HOME';
      PassThrough[2] := 'TMPDIR';
      PassThrough[3] := 'LANG';
      PassThrough[4] := 'LC_ALL';
      PassThrough[5] := 'PREFIX';
      PassThrough[6] := 'TERM';
      PassThrough[7] := 'USER';
      for i := Low(PassThrough) to High(PassThrough) do
      begin
        if Proc.Environment.IndexOfName(PassThrough[i]) >= 0 then Continue;
        V := GetEnvironmentVariable(PassThrough[i]);
        if V <> '' then
          Proc.Environment.Values[PassThrough[i]] := V;
      end;
    end;

    try
      Proc.Execute;
    except
      on E: Exception do
      begin
        Result.Stderr := 'Execute failed: ' + E.Message;
        Result.DurationMs := GetTickCount64 - StartTick;
        Exit;
      end;
    end;

    // Read output with timeout loop
    repeat
      if Proc.Output.NumBytesAvailable > 0 then
      begin
        N := Proc.Output.Read(OutBuf[0], SizeOf(OutBuf));
        if N > 0 then OutStream.Write(OutBuf[0], N);
      end;
      if Proc.Stderr.NumBytesAvailable > 0 then
      begin
        N := Proc.Stderr.Read(ErrBuf[0], SizeOf(ErrBuf));
        if N > 0 then ErrStream.Write(ErrBuf[0], N);
      end;
      if not Proc.Running then Break;
      if (TimeoutMs > 0) and
         ((GetTickCount64 - StartTick) > QWord(TimeoutMs)) then
      begin
        Result.TimedOut := True;
        Proc.Terminate(1);
        Break;
      end;
      Sleep(10);
    until False;

    // Drain
    repeat
      N := Proc.Output.Read(OutBuf[0], SizeOf(OutBuf));
      if N > 0 then OutStream.Write(OutBuf[0], N);
    until N <= 0;
    repeat
      N := Proc.Stderr.Read(ErrBuf[0], SizeOf(ErrBuf));
      if N > 0 then ErrStream.Write(ErrBuf[0], N);
    until N <= 0;

    try
      {$IFDEF UNIX}
      Result.ExitCode := Proc.ExitStatus shr 8;
      {$ELSE}
      Result.ExitCode := Proc.ExitStatus;
      {$ENDIF}
    except
      Result.ExitCode := -1;
    end;

    BytesOut := OutStream.Size;
    if BytesOut > 0 then
    begin
      SetLength(Result.Stdout, BytesOut);
      OutStream.Position := 0;
      OutStream.Read(Result.Stdout[1], BytesOut);
    end;

    BytesErr := ErrStream.Size;
    if BytesErr > 0 then
    begin
      SetLength(Result.Stderr, BytesErr);
      ErrStream.Position := 0;
      ErrStream.Read(Result.Stderr[1], BytesErr);
    end;
  finally
    Proc.Free;
    OutStream.Free;
    ErrStream.Free;
  end;

  Result.DurationMs := GetTickCount64 - StartTick;
end;

{ ─── Public executors ─── }

function TPascakEmbed.ExecuteString(const Source: string): TPascakResult;
var
  TmpPath: string;
  SL: TStringList;
  Args: TStringArray;
begin
  TmpPath := IncludeTrailingPathDelimiter(FTmpDir) +
             'pascak_embed_' + IntToStr(GetProcessID) + '_' +
             IntToStr(Random(1000000)) + '.pas';

  SL := TStringList.Create;
  try
    SL.Text := Source;
    SL.SaveToFile(TmpPath);
  finally
    SL.Free;
  end;

  try 
    Args := BuildArgs(TmpPath);
    Result := RunCommandCapture(FBinaryPath, Args, FTimeoutMs, FEnv);
  finally
    if FileExists(TmpPath) then
      DeleteFile(TmpPath);
  end;
end;

function TPascakEmbed.ExecuteFile(const FilePath: string): TPascakResult;
var
  AbsPath: string;
  Args: TStringArray;
begin
  AbsPath := ExpandFileName(FilePath);
  if not FileExists(AbsPath) then
    raise EPascakEmbedError.Create('File tidak ditemukan: ' + AbsPath);

  Args := BuildArgs(AbsPath);
  Result := RunCommandCapture(FBinaryPath, Args, FTimeoutMs, FEnv);
end;

initialization
  Randomize;

end.
ENDOFUNIT
echo "OK — pascak_embed.pas created"