{ ====================================================================
  pascak_poller.pas — I/O multiplexing abstraction
  ====================================================================
  Level-triggered epoll wrapper untuk UNIX/Android (Termux).

  UNIX: epoll_create1 + epoll_ctl + epoll_wait
  macOS: TODO (kqueue) — B.1.1b
  Windows: tidak didukung — fallback ke thread mode

  Standalone — tidak butuh engine runtime untuk dites.
  ==================================================================== }
unit pascak_poller;

{$MODE OBJFPC}{$H+}

interface

uses
  {$IFDEF UNIX}
    cthreads,
  {$ENDIF}
  SysUtils, Classes, BaseUnix;

type
  EPollerError = class(Exception);

  TPollerEventKind = (pekRead, pekWrite, pekError, pekHangup);
  TPollerEventKinds = set of TPollerEventKind;

  TPollerResult = record
    Sock: Integer;
    Kinds: TPollerEventKinds;
  end;

  { TPoller — epoll wrapper }
  TPoller = class
  private
    FHandle: Integer;
    FClosed: Boolean;
    function NativeToKinds(NativeEvents: Cardinal): TPollerEventKinds;
  public
    constructor Create;
    destructor Destroy; override;

    function IsValid: Boolean;

    { Register fd untuk events yang diinginkan }
    function Add(Sock: Integer; Kinds: TPollerEventKinds): Boolean;
    function Mod_(Sock: Integer; Kinds: TPollerEventKinds): Boolean;
    function Del(Sock: Integer): Boolean;

    { Wait up to TimeoutMs. Isi Results array, return jumlah event ready.
      TimeoutMs = 0 → non-blocking; TimeoutMs < 0 → blocking forever }
    function Poll(TimeoutMs: Integer;
                  var Results: array of TPollerResult): Integer;
  end;

implementation

{$IFDEF UNIX}

const
  { UNIX epoll constants — nilai fixed, tidak berubah }
  EPOLLIN_C      = $001;
  EPOLLPRI_C     = $002;
  EPOLLOUT_C     = $004;
  EPOLLERR_C     = $008;
  EPOLLHUP_C     = $010;
  EPOLLRDHUP_C   = $2000;

  EPOLL_CTL_ADD_C = 1;
  EPOLL_CTL_DEL_C = 2;
  EPOLL_CTL_MOD_C = 3;

type
  { epoll_data_t — union, 8 byte di 64-bit }
  TEPollData = record
    case Integer of
      0: (Ptr: Pointer);
      1: (Fd: Integer);
      2: (U32: Cardinal);
      3: (U64: QWord);
  end;

  { struct epoll_event — 12 byte data + 4 byte padding di 64-bit }
  TEPollEvent = record
    Events: Cardinal;
    Data: TEPollData;
  end;

{ libc function bindings }
function fpEpollCreate1(Flags: cint): cint;
  cdecl; external 'c' name 'epoll_create1';
function fpEpollCtl(EPFd: cint; Op: cint; Fd: cint; Event: Pointer): cint;
  cdecl; external 'c' name 'epoll_ctl';
function fpEpollWait(EPFd: cint; Events: Pointer; MaxEvents: cint;
  Timeout: cint): cint; cdecl; external 'c' name 'epoll_wait';

{$ENDIF UNIX}

{ --------------------------------------------------------------------
  Lifecycle
  -------------------------------------------------------------------- }

constructor TPoller.Create;
begin
  inherited Create;
  FClosed := False;
  FHandle := -1;

  {$IFDEF UNIX}
  FHandle := fpEpollCreate1(0);
  if FHandle < 0 then
    raise EPollerError.CreateFmt(
      'epoll_create1 gagal (errno=%d)', [fpGetErrno]);
  {$ELSE}
  raise EPollerError.Create(
    'pascak_poller: platform tidak didukung. ' +
    'Hanya UNIX/Android (epoll) yang didukung di versi ini.');
  {$ENDIF}
end;

destructor TPoller.Destroy;
begin
  {$IFDEF UNIX}
  if (not FClosed) and (FHandle >= 0) then
  begin
    try fpClose(FHandle); except end;
    FHandle := -1;
  end;
  {$ENDIF}
  inherited;
end;

function TPoller.IsValid: Boolean;
begin
  Result := (not FClosed) and (FHandle >= 0);
end;

{ --------------------------------------------------------------------
  Event translation
  -------------------------------------------------------------------- }

function TPoller.NativeToKinds(NativeEvents: Cardinal): TPollerEventKinds;
begin
  Result := [];
  if (NativeEvents and EPOLLIN_C) <> 0 then Include(Result, pekRead);
  if (NativeEvents and EPOLLOUT_C) <> 0 then Include(Result, pekWrite);
  if (NativeEvents and EPOLLERR_C) <> 0 then Include(Result, pekError);
  if (NativeEvents and EPOLLHUP_C) <> 0 then Include(Result, pekHangup);
  if (NativeEvents and EPOLLRDHUP_C) <> 0 then Include(Result, pekHangup);
end;

{ --------------------------------------------------------------------
  Registration
  -------------------------------------------------------------------- }

function BuildNativeEvents(Kinds: TPollerEventKinds): Cardinal;
begin
  Result := 0;
  if pekRead in Kinds then Result := Result or EPOLLIN_C;
  if pekWrite in Kinds then Result := Result or EPOLLOUT_C;
  // Note: pekError/pekHangup selalu di-report oleh kernel, tidak perlu di-set
end;

function TPoller.Add(Sock: Integer; Kinds: TPollerEventKinds): Boolean;
{$IFDEF UNIX}
var
  Ev: TEPollEvent;
{$ENDIF}
begin
  if not IsValid then
    raise EPollerError.Create('TPoller.Add: poller sudah closed');
  if Sock < 0 then
    raise EPollerError.Create('TPoller.Add: sock fd tidak valid');

  {$IFDEF UNIX}
  FillChar(Ev, SizeOf(Ev), 0);
  Ev.Events := BuildNativeEvents(Kinds);
  Ev.Data.Fd := Sock;
  Result := fpEpollCtl(FHandle, EPOLL_CTL_ADD_C, Sock, @Ev) = 0;
  {$ELSE}
  Result := False;
  {$ENDIF}
end;

function TPoller.Mod_(Sock: Integer; Kinds: TPollerEventKinds): Boolean;
{$IFDEF UNIX}
var
  Ev: TEPollEvent;
{$ENDIF}
begin
  if not IsValid then
    raise EPollerError.Create('TPoller.Mod_: poller sudah closed');
  if Sock < 0 then
    raise EPollerError.Create('TPoller.Mod_: sock fd tidak valid');

  {$IFDEF UNIX}
  FillChar(Ev, SizeOf(Ev), 0);
  Ev.Events := BuildNativeEvents(Kinds);
  Ev.Data.Fd := Sock;
  Result := fpEpollCtl(FHandle, EPOLL_CTL_MOD_C, Sock, @Ev) = 0;
  {$ELSE}
  Result := False;
  {$ENDIF}
end;

function TPoller.Del(Sock: Integer): Boolean;
begin
  if not IsValid then
    raise EPollerError.Create('TPoller.Del: poller sudah closed');
  if Sock < 0 then Exit(False);

  {$IFDEF UNIX}
  { epoll_ctl DEL tidak butuh event pointer }
  Result := fpEpollCtl(FHandle, EPOLL_CTL_DEL_C, Sock, nil) = 0;
  {$ELSE}
  Result := False;
  {$ENDIF}
end;

{ --------------------------------------------------------------------
  Poll
  -------------------------------------------------------------------- }

function TPoller.Poll(TimeoutMs: Integer;
  var Results: array of TPollerResult): Integer;
{$IFDEF UNIX}
var
  NativeBuf: array of TEPollEvent;
  N, i, MaxEvents: Integer;
{$ENDIF}
begin
  Result := 0;

  if not IsValid then
    raise EPollerError.Create('TPoller.Poll: poller sudah closed');

  {$IFDEF UNIX}
  MaxEvents := Length(Results);
  if MaxEvents = 0 then Exit;

  SetLength(NativeBuf, MaxEvents);
  if MaxEvents > 0 then
    FillChar(NativeBuf[0], MaxEvents * SizeOf(TEPollEvent), 0);

  // ✅ FIX (WS regression): retry EINTR. epoll_wait diinterupsi signal
  // (SIGCHLD dari sys.exec subprocess, SIGIO dari socket lain, dsb)
  // TIDAK boleh dianggap fatal — kalau raise, event loop mati dan
  // WS callback tidak pernah terpanggil. Ini yang menyebabkan WS
  // event-mode fail di Termux saat sys.exec jalan di thread lain.
  repeat
    N := fpEpollWait(FHandle, @NativeBuf[0], MaxEvents, TimeoutMs);
    if N < 0 then
    begin
      if fpGetErrno = ESysEINTR then
        Continue;   // retry
      raise EPollerError.CreateFmt(
        'epoll_wait gagal (errno=%d)', [fpGetErrno]);
    end;
    Break;
  until False;
  
  for i := 0 to N - 1 do
  begin
    Results[i].Sock := NativeBuf[i].Data.Fd;
    Results[i].Kinds := NativeToKinds(NativeBuf[i].Events);
  end;

  Result := N;
  {$ENDIF}
end;

initialization
finalization

end.