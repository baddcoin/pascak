{ ====================================================================
  pascak_h2_conn.pas — HTTP/2 multiplexed connection (RFC 7540)

  v2 (D.2b.2b): Reader thread + per-stream state + concurrent Request().
  Multiple streams active on the same connection.
  ==================================================================== }
unit pascak_h2_conn;

{$MODE OBJFPC}{$H+}

interface

uses
  Classes, SyncObjs, SysUtils, fgl,
  pascak_tls, pascak_h2, pascak_h2_hpack, pascak_net;

type
  EH2ConnectionError = class(Exception);

  TH2Response = record
    Status: Integer;
    Headers: THPACKHeaderArray;
    Body: RawByteString;
    Error: string;
    HasError: Boolean;
  end;

  TStreamState = class
  public
    Event: PRTLEvent;
    RefCount: LongInt;
    HeadersAccum: RawByteString;
    Headers: THPACKHeaderArray;
    Body: RawByteString;
    Status: Integer;
    Ended: Boolean;
    HeadersDecoded: Boolean;
    ErrorMsg: string;
    constructor Create;
    destructor Destroy; override;
    procedure AddRef;
    procedure Release;
  end;

  TStreamMap = specialize TFPGMap<Cardinal, TStreamState>;

  TH2Connection = class
  private
    FTLS: TTLSConnection;
    FHost: string;
    FDec: THPACKDecoder;
    FEnc: THPACKEncoder;
    FRecvBuf: RawByteString;
    FStreamWindow: Cardinal;
    FClosed: Boolean;
    FNextStreamID: Cardinal;

    FReaderThread: TThread;
    FReaderTerminated: LongInt;
    FWriteLock: TCriticalSection;
    FStreamLock: TCriticalSection;
    FStreams: TStreamMap;
    FConnectionError: string;
    FGoAwayLastStreamID: Cardinal;
    FServerInitialWindow: Cardinal;
    FServerMaxStreams: Cardinal;

    function SendFrameRaw(const Frame: RawByteString): Boolean;
    function SendFrameLocked(const Frame: RawByteString): Boolean;
    function RecvRaw(TimeoutMs: Integer): Integer;
    function TryExtractFrame(out Frame: TH2Frame): Boolean;
    function RecvFrame(out Frame: TH2Frame; TimeoutMs: Integer = 10000): Boolean;

    procedure ReaderLoop;
    procedure DispatchFrame(const Frame: TH2Frame);
    procedure HandleSettings(const Payload: RawByteString);
    procedure HandleHeadersFrame(const Frame: TH2Frame);
    procedure HandleDataFrame(const Frame: TH2Frame);
    procedure HandleRSTStream(const Frame: TH2Frame);
    procedure HandleGoAway(const Frame: TH2Frame);
    procedure FailAllPending(const Msg: string);
  public
    constructor Create(ATLS: TTLSConnection; const AHost: string);
    destructor Destroy; override;
    function Open(TimeoutMs: Integer = 10000): Boolean;
    function Request(const Method, Path: string;
                     const ExtraHeaders: THPACKHeaderArray;
                     const Body: RawByteString;
                     TimeoutMs: Integer = 30000): TH2Response;
    procedure Close;
    property Host: string read FHost;
    property Closed: Boolean read FClosed;
  end;

  TH2PooledEntry = class
  public
    Key: string;
    Conn: TH2Connection;
    TLSConn: TTLSConnection;
    Sock: Integer;
    LastUsed: QWord;
    destructor Destroy; override;
  end;

  TPoolSlot = class
  public
    Key: string;
    Conn: TH2Connection;
    TLSConn: TTLSConnection;
    Sock: Integer;
    Creating: Boolean;
    Failed: Boolean;
    ErrorMsg: string;
    InitEvent: PRTLEvent;
    RefCount: LongInt;
    LastUsed: QWord;
    constructor Create(const AKey: string);
    destructor Destroy; override;
    procedure AddRef;
    procedure Release;
  end;

  TH2Pool = class
  private
    FSlots: TList;
    FLock: TCriticalSection;
    FMaxPerHost: Integer;
    FIdleMs: Integer;
    FHits: Int64;
    FMisses: Int64;
    procedure CleanupLocked;
    function FindSlotLocked(const Key: string): TPoolSlot;
  public
    constructor Create(AMaxPerHost: Integer = 8; AIdleMs: Integer = 30000);
    destructor Destroy; override;
    function Acquire(const Key: string; out IsCreator: Boolean): TPoolSlot;
    procedure Publish(Slot: TPoolSlot; Conn: TH2Connection;
                      TLSConn: TTLSConnection; Sock: Integer);
    procedure FailCreate(Slot: TPoolSlot; const ErrMsg: string);
    procedure Release(Slot: TPoolSlot);
    procedure Cleanup;
    procedure Clear;
    function GetHits: Int64;
    function GetMisses: Int64;
    function GetIdleCount: Integer;
    property MaxPerHost: Integer read FMaxPerHost write FMaxPerHost;
    property IdleMs: Integer read FIdleMs write FIdleMs;
  end;

implementation

type
  TH2ReaderThread = class(TThread)
  private
    FOwner: TH2Connection;
  protected
    procedure Execute; override;
  public
    constructor Create(AOwner: TH2Connection);
  end;

constructor TH2ReaderThread.Create(AOwner: TH2Connection);
begin
  inherited Create(True);
  FOwner := AOwner;
  FreeOnTerminate := False;
end;

procedure TH2ReaderThread.Execute;
begin
  FOwner.ReaderLoop;
end;

{ ═══════════════════════════════════════════════════════════════
  TStreamState
  ═══════════════════════════════════════════════════════════════ }

constructor TStreamState.Create;
begin
  Event := RTLEventCreate;
  RefCount := 1;
  HeadersAccum := '';
  SetLength(Headers, 0);
  Body := '';
  Status := 0;
  Ended := False;
  HeadersDecoded := False;
  ErrorMsg := '';
end;

destructor TStreamState.Destroy;
begin
  RTLEventDestroy(Event);
  inherited;
end;

procedure TStreamState.AddRef;
begin
  InterlockedIncrement(RefCount);
end;

procedure TStreamState.Release;
begin
  if InterlockedDecrement(RefCount) = 0 then
    Free;
end;

{ ═══════════════════════════════════════════════════════════════
  TH2Connection — lifecycle
  ═══════════════════════════════════════════════════════════════ }

constructor TH2Connection.Create(ATLS: TTLSConnection; const AHost: string);
begin
  inherited Create;
  FTLS := ATLS;
  FHost := AHost;
  FDec := THPACKDecoder.Create(4096);
  FEnc := THPACKEncoder.Create;
  FRecvBuf := '';
  FStreamWindow := 1048576;
  FClosed := False;
  FNextStreamID := 1;

  FReaderThread := nil;
  FReaderTerminated := 0;
  FWriteLock := TCriticalSection.Create;
  FStreamLock := TCriticalSection.Create;
  FStreams := TStreamMap.Create;
  FStreams.Sorted := True;
  FConnectionError := '';
  FGoAwayLastStreamID := 0;
  FServerInitialWindow := 65535;
  FServerMaxStreams := 100;
end;

destructor TH2Connection.Destroy;
begin
  Close;
  FDec.Free;
  FEnc.Free;
  FWriteLock.Free;
  FStreamLock.Free;
  FStreams.Free;
  inherited;
end;

function TH2Connection.SendFrameRaw(const Frame: RawByteString): Boolean;
begin
  Result := False;
  if not Assigned(FTLS) or FClosed then Exit;
  if TLSSend(FTLS, Frame) <> Length(Frame) then
  begin
    FClosed := True;
    Exit;
  end;
  Result := True;
end;

function TH2Connection.SendFrameLocked(const Frame: RawByteString): Boolean;
begin
  FWriteLock.Acquire;
  try
    Result := SendFrameRaw(Frame);
  finally
    FWriteLock.Release;
  end;
end;

function TH2Connection.RecvRaw(TimeoutMs: Integer): Integer;
var
  Data: RawByteString;
  N: Integer;
begin
  Result := 0;
  if not Assigned(FTLS) or FClosed then Exit(-1);

  N := TLSRecvTimeout(FTLS, 65536, TimeoutMs, Data);
  if N > 0 then
  begin
    FRecvBuf := FRecvBuf + Data;
    Result := N;
  end
  else if N = 0 then
  begin
    FClosed := True;
    Result := -1;
  end
  else
  begin
    if Pos('timeout', FTLS.LastError) > 0 then
      Result := 0
    else
    begin
      FClosed := True;
      Result := -1;
    end;
  end;
end;

function TH2Connection.TryExtractFrame(out Frame: TH2Frame): Boolean;
var
  Consumed: Integer;
begin
  Result := H2TryParseFrame(FRecvBuf, 1, Frame, Consumed);
  if Result then
    FRecvBuf := Copy(FRecvBuf, Consumed + 1, Length(FRecvBuf) - Consumed);
end;

function TH2Connection.RecvFrame(out Frame: TH2Frame; TimeoutMs: Integer): Boolean;
var
  Start: QWord;
  N: Integer;
begin
  Result := False;
  Start := GetTickCount64;
  while True do
  begin
    if TryExtractFrame(Frame) then Exit(True);
    if FClosed then Exit(False);
    if GetTickCount64 - Start > QWord(TimeoutMs) then Exit(False);
    N := RecvRaw(500);
    if N < 0 then Exit(False);
  end;
end;

function TH2Connection.Open(TimeoutMs: Integer): Boolean;
var
  Settings: TH2SettingArray;
  Frame: TH2Frame;
  GotServerSettings: Boolean;
  Start: QWord;
begin
  Result := False;
  if not Assigned(FTLS) then Exit;

  if not SendFrameLocked(H2BuildClientPreface) then Exit;

  SetLength(Settings, 4);
  Settings[0].ID := H2_SETTINGS_HEADER_TABLE_SIZE;
  Settings[0].Value := 4096;
  Settings[1].ID := H2_SETTINGS_INITIAL_WINDOW_SIZE;
  Settings[1].Value := FStreamWindow;
  Settings[2].ID := H2_SETTINGS_MAX_CONCURRENT_STREAMS;
  Settings[2].Value := 100;
  Settings[3].ID := H2_SETTINGS_ENABLE_PUSH;
  Settings[3].Value := 0;

  if not SendFrameLocked(H2BuildSettings(Settings, False)) then Exit;

  GotServerSettings := False;
  Start := GetTickCount64;
  while (not GotServerSettings) and
        (GetTickCount64 - Start < QWord(TimeoutMs)) and
        (not FClosed) do
  begin
    if not RecvFrame(Frame, TimeoutMs) then Exit;

    case Frame.FrameType of
      H2_FRAME_SETTINGS:
        if (Frame.Flags and H2_FLAG_ACK) = 0 then
        begin
          HandleSettings(Frame.Payload);
          if not SendFrameLocked(H2BuildSettingsAck) then Exit;
          GotServerSettings := True;
        end;

      H2_FRAME_PING:
        if (Frame.Flags and H2_FLAG_ACK) = 0 then
          SendFrameLocked(H2BuildPing(Frame.Payload, True));

      H2_FRAME_GOAWAY:
        begin
          FClosed := True;
          Exit;
        end;
    end;
  end;

  if not (GotServerSettings and (not FClosed)) then Exit;

  FReaderThread := TH2ReaderThread.Create(Self);
  FReaderThread.Start;
  Result := True;
end;

procedure TH2Connection.HandleSettings(const Payload: RawByteString);
var
  Items: TH2SettingArray;
  I: Integer;
begin
  if not H2ParseSettings(Payload, Items) then Exit;
  for I := 0 to High(Items) do
    case Items[I].ID of
      H2_SETTINGS_INITIAL_WINDOW_SIZE:
        FServerInitialWindow := Items[I].Value;
      H2_SETTINGS_MAX_CONCURRENT_STREAMS:
        FServerMaxStreams := Items[I].Value;
    end;
end;

procedure TH2Connection.DispatchFrame(const Frame: TH2Frame);
begin
  case Frame.FrameType of
    H2_FRAME_SETTINGS:
      if (Frame.Flags and H2_FLAG_ACK) = 0 then
      begin
        HandleSettings(Frame.Payload);
        SendFrameLocked(H2BuildSettingsAck);
      end;

    H2_FRAME_PING:
      if (Frame.Flags and H2_FLAG_ACK) = 0 then
        SendFrameLocked(H2BuildPing(Frame.Payload, True));

    H2_FRAME_HEADERS, H2_FRAME_CONTINUATION:
      HandleHeadersFrame(Frame);

    H2_FRAME_DATA:
      HandleDataFrame(Frame);

    H2_FRAME_RST_STREAM:
      HandleRSTStream(Frame);

    H2_FRAME_GOAWAY:
      HandleGoAway(Frame);

    H2_FRAME_WINDOW_UPDATE:
      ;  // per-stream flow control: v1 ignores
  end;
end;

procedure TH2Connection.HandleHeadersFrame(const Frame: TH2Frame);
var
  Idx: Integer;
  Stream: TStreamState;
  Hdrs: THPACKHeaderArray;
  I: Integer;
begin
  FStreamLock.Acquire;
  try
    Idx := FStreams.IndexOf(Frame.StreamID);
    if Idx < 0 then Exit;
    Stream := FStreams.Data[Idx];
    Stream.AddRef;
  finally
    FStreamLock.Release;
  end;
  try
    Stream.HeadersAccum := Stream.HeadersAccum + Frame.Payload;
    if (Frame.Flags and H2_FLAG_END_HEADERS) <> 0 then
    begin
      try
        Hdrs := FDec.Decode(Stream.HeadersAccum);
        Stream.Headers := Hdrs;
        Stream.HeadersDecoded := True;
        for I := 0 to High(Hdrs) do
          if Hdrs[I].Name = ':status' then
            Stream.Status := StrToIntDef(Hdrs[I].Value, 0);
        Stream.HeadersAccum := '';
      except
        on E: Exception do
        begin
          Stream.ErrorMsg := 'HPACK: ' + E.Message;
          Stream.Ended := True;
          RTLEventSetEvent(Stream.Event);
          Exit;
        end;
      end;
    end;
    if (Frame.Flags and H2_FLAG_END_STREAM) <> 0 then
    begin
      Stream.Ended := True;
      RTLEventSetEvent(Stream.Event);
    end;
  finally
    Stream.Release;
  end;
end;

procedure TH2Connection.HandleDataFrame(const Frame: TH2Frame);
var
  Idx: Integer;
  Stream: TStreamState;
begin
  FStreamLock.Acquire;
  try
    Idx := FStreams.IndexOf(Frame.StreamID);
    if Idx < 0 then Exit;
    Stream := FStreams.Data[Idx];
    Stream.AddRef;
  finally
    FStreamLock.Release;
  end;
  try
    Stream.Body := Stream.Body + Frame.Payload;
    if Length(Frame.Payload) > 0 then
      SendFrameLocked(H2BuildWindowUpdate(Frame.StreamID, Length(Frame.Payload)));
    if (Frame.Flags and H2_FLAG_END_STREAM) <> 0 then
    begin
      Stream.Ended := True;
      RTLEventSetEvent(Stream.Event);
    end;
  finally
    Stream.Release;
  end;
end;

procedure TH2Connection.HandleRSTStream(const Frame: TH2Frame);
var
  Idx: Integer;
  Stream: TStreamState;
  ErrCode: Cardinal;
begin
  if not H2ParseRSTStream(Frame.Payload, ErrCode) then Exit;
  FStreamLock.Acquire;
  try
    Idx := FStreams.IndexOf(Frame.StreamID);
    if Idx < 0 then Exit;
    Stream := FStreams.Data[Idx];
    Stream.AddRef;
  finally
    FStreamLock.Release;
  end;
  try
    Stream.ErrorMsg := 'RST_STREAM: ' + H2ErrorName(ErrCode);
    Stream.Ended := True;
    RTLEventSetEvent(Stream.Event);
  finally
    Stream.Release;
  end;
end;

procedure TH2Connection.HandleGoAway(const Frame: TH2Frame);
var
  LastID, ErrCode: Cardinal;
  DebugData: RawByteString;
begin
  if H2ParseGoAway(Frame.Payload, LastID, ErrCode, DebugData) then
  begin
    FGoAwayLastStreamID := LastID;
    FConnectionError := 'GOAWAY: ' + H2ErrorName(ErrCode);
  end
  else
    FConnectionError := 'GOAWAY received';
  FailAllPending(FConnectionError);
  FClosed := True;
end;

procedure TH2Connection.FailAllPending(const Msg: string);
var
  I: Integer;
  Streams: array of TStreamState;
begin
  FStreamLock.Acquire;
  try
    SetLength(Streams, FStreams.Count);
    for I := 0 to FStreams.Count - 1 do
    begin
      Streams[I] := FStreams.Data[I];
      Streams[I].AddRef;
    end;
  finally
    FStreamLock.Release;
  end;
  for I := 0 to High(Streams) do
  begin
    Streams[I].ErrorMsg := Msg;
    Streams[I].Ended := True;
    RTLEventSetEvent(Streams[I].Event);
    Streams[I].Release;
  end;
end;

procedure TH2Connection.ReaderLoop;
var
  Frame: TH2Frame;
begin
  while InterlockedCompareExchange(FReaderTerminated, 0, 0) = 0 do
  begin
    if FClosed then
    begin
      FailAllPending('connection closed');
      Break;
    end;

    if not RecvFrame(Frame, 500) then
    begin
      if FClosed then
      begin
        FailAllPending('connection closed');
        Break;
      end;
      Continue;
    end;

    try
      DispatchFrame(Frame);
    except
      on E: Exception do
      begin
        FConnectionError := 'reader: ' + E.Message;
        FClosed := True;
      end;
    end;
  end;
end;

{ --- Part 2 (Request + Close) follows --- }

function TH2Connection.Request(const Method, Path: string;
  const ExtraHeaders: THPACKHeaderArray;
  const Body: RawByteString;
  TimeoutMs: Integer): TH2Response;
var
  SID: Cardinal;
  Stream: TStreamState;
  ReqHeaders: THPACKHeaderArray;
  HeaderBlock: RawByteString;
  Total, I, Idx: Integer;
  SendOK, RemovedFromMap: Boolean;
  Start: QWord;
  WaitMs, ElapsedMs: Integer;
  StreamAcquired: Boolean;
  WaitStreamStart: QWord;
begin
  Result.Status := 0;
  SetLength(Result.Headers, 0);
  Result.Body := '';
  Result.Error := '';
  Result.HasError := False;

  if FReaderThread = nil then
  begin
    Result.HasError := True;
    Result.Error := 'connection not opened or reader not running';
    Exit;
  end;

  { H2 S4b: enforce server MAX_CONCURRENT_STREAMS (RFC 7540 §5.1.2).
    Prevents GOAWAY when client opens more streams than server allows.
    Limit 0 or >=1000 treated as unlimited (safety cap). }
  WaitStreamStart := GetTickCount64;
  StreamAcquired := False;
  while not StreamAcquired do
  begin
    FStreamLock.Acquire;
    try
      if FClosed then
      begin
        Result.HasError := True;
        Result.Error := 'connection closed: ' + FConnectionError;
        Exit;
      end;
      if FGoAwayLastStreamID > 0 then
      begin
        Result.HasError := True;
        Result.Error := 'connection GOAWAY received';
        Exit;
      end;
      if (Integer(FServerMaxStreams) > 0) and
         (Integer(FServerMaxStreams) < 1000) and
         (FStreams.Count >= Integer(FServerMaxStreams)) then
      begin
        { Stream limit reached — wait for one to complete }
      end
      else
      begin
        SID := FNextStreamID;
        Inc(FNextStreamID, 2);
        Stream := TStreamState.Create;
        FStreams.Add(SID, Stream);
        Stream.AddRef;
        StreamAcquired := True;
      end;
    finally
      FStreamLock.Release;
    end;
    if not StreamAcquired then
    begin
      if (GetTickCount64 - WaitStreamStart) > QWord(TimeoutMs) then
      begin
        Result.HasError := True;
        Result.Error := 'timeout waiting for stream slot (limit=' +
                        IntToStr(FServerMaxStreams) + ')';
        Exit;
      end;
      Sleep(5);
    end;
  end;

  try
    Total := 4 + Length(ExtraHeaders);
    SetLength(ReqHeaders, Total);
    ReqHeaders[0].Name := ':method';    ReqHeaders[0].Value := Method;
    ReqHeaders[1].Name := ':scheme';    ReqHeaders[1].Value := 'https';
    ReqHeaders[2].Name := ':path';      ReqHeaders[2].Value := Path;
    ReqHeaders[3].Name := ':authority'; ReqHeaders[3].Value := FHost;
    for I := 0 to High(ExtraHeaders) do
      ReqHeaders[4 + I] := ExtraHeaders[I];

    FWriteLock.Acquire;
    try
      HeaderBlock := FEnc.Encode(ReqHeaders);
      SendOK := SendFrameRaw(H2BuildHeaders(SID, HeaderBlock,
        Length(Body) = 0, True));
      if SendOK and (Length(Body) > 0) then
        SendOK := SendFrameRaw(H2BuildData(SID, Body, True));
    finally
      FWriteLock.Release;
    end;

    if not SendOK then
    begin
      Result.HasError := True;
      Result.Error := 'send failed';
      Exit;
    end;

    Start := GetTickCount64;
    while not Stream.Ended do
    begin
      ElapsedMs := Integer(GetTickCount64 - Start);
      if ElapsedMs >= TimeoutMs then Break;
      WaitMs := TimeoutMs - ElapsedMs;
      if WaitMs > 500 then WaitMs := 500;
      RTLEventWaitFor(Stream.Event, WaitMs);
    end;

    if Stream.ErrorMsg <> '' then
    begin
      Result.HasError := True;
      Result.Error := Stream.ErrorMsg;
    end
    else if not Stream.Ended then
    begin
      Result.HasError := True;
      Result.Error := 'timeout waiting for response';
      SendFrameLocked(H2BuildRSTStream(SID, H2_ERR_CANCEL));
    end
    else
    begin
      Result.Status := Stream.Status;
      Result.Headers := Stream.Headers;
      Result.Body := Stream.Body;
    end;
  finally
    RemovedFromMap := False;
    FStreamLock.Acquire;
    try
      Idx := FStreams.IndexOf(SID);
      if (Idx >= 0) and (FStreams.Data[Idx] = Stream) then
      begin
        FStreams.Remove(SID);
        RemovedFromMap := True;
      end;
    finally
      FStreamLock.Release;
    end;
    if RemovedFromMap then
      Stream.Release;
    Stream.Release;
  end;
end;

procedure TH2Connection.Close;
begin
  if InterlockedCompareExchange(FReaderTerminated, 1, 0) <> 0 then Exit;

  FailAllPending('connection closed by user');

  if Assigned(FReaderThread) then
  begin
    try FReaderThread.WaitFor; except end;
    try FReaderThread.Free; except end;
    FReaderThread := nil;
  end;

  if (not FClosed) and Assigned(FTLS) then
  begin
    try SendFrameLocked(H2BuildGoAway(1, H2_ERR_NO_ERROR, '')); except end;
  end;
  FClosed := True;
end;

{ ═══════════════════════════════════════════════════════════════
  TH2PooledEntry
  ═══════════════════════════════════════════════════════════════ }

destructor TH2PooledEntry.Destroy;
begin
  if Assigned(Conn) then
  begin
    try Conn.Close; except end;
    try Conn.Free; except end;
    Conn := nil;
  end;
  if Assigned(TLSConn) then
  begin
    try TLSClose(TLSConn); except end;
    try TLSConn.Free; except end;
    TLSConn := nil;
  end;
  if Sock >= 0 then
  begin
    try NetClose(Sock); except end;
    Sock := -1;
  end;
  inherited;
end;

{ ═══════════════════════════════════════════════════════════════
  TH2Pool
  ═══════════════════════════════════════════════════════════════ }

{ ═══════════════════════════════════════════════════════════════
  TPoolSlot — single-entry pool storage (D.2b.2b Session 2)
  ═══════════════════════════════════════════════════════════════ }

constructor TPoolSlot.Create(const AKey: string);
begin
  Key := AKey;
  Conn := nil;
  TLSConn := nil;
  Sock := -1;
  Creating := True;
  Failed := False;
  ErrorMsg := '';
  InitEvent := RTLEventCreate;
  RefCount := 1;
  LastUsed := GetTickCount64;
end;

destructor TPoolSlot.Destroy;
begin
  if Assigned(Conn) then
  begin
    try
      if not Conn.Closed then Conn.Close;
    except
    end;
    try Conn.Free; except end;
    Conn := nil;
  end;
  if Assigned(TLSConn) then
  begin
    try TLSClose(TLSConn); except end;
    try TLSConn.Free; except end;
    TLSConn := nil;
  end;
  if Sock >= 0 then
  begin
    try NetClose(Sock); except end;
    Sock := -1;
  end;
  RTLEventDestroy(InitEvent);
  inherited;
end;

procedure TPoolSlot.AddRef;
begin
  InterlockedIncrement(RefCount);
end;

procedure TPoolSlot.Release;
begin
  if InterlockedDecrement(RefCount) = 0 then
    Free;
end;

{ ═══════════════════════════════════════════════════════════════
  TH2Pool — singleflight slot manager (D.2b.2b Session 2)
  ═══════════════════════════════════════════════════════════════ }

constructor TH2Pool.Create(AMaxPerHost: Integer; AIdleMs: Integer);
begin
  inherited Create;
  FSlots := TList.Create;
  FLock := TCriticalSection.Create;
  FMaxPerHost := AMaxPerHost;
  FIdleMs := AIdleMs;
  FHits := 0;
  FMisses := 0;
end;

destructor TH2Pool.Destroy;
begin
  Clear;
  FSlots.Free;
  FLock.Free;
  inherited;
end;

procedure TH2Pool.CleanupLocked;
var
  i: Integer;
  S: TPoolSlot;
  NowTick: QWord;
begin
  NowTick := GetTickCount64;
  i := FSlots.Count - 1;
  while i >= 0 do
  begin
    S := TPoolSlot(FSlots[i]);
    if InterlockedCompareExchange(S.RefCount, 1, 1) = 1 then
    begin
      if S.Failed or (not Assigned(S.Conn)) or S.Conn.Closed or
         ((NowTick - S.LastUsed) > QWord(FIdleMs)) then
      begin
        FSlots.Delete(i);
        try S.Release; except end;
      end;
    end;
    Dec(i);
  end;
end;

procedure TH2Pool.Cleanup;
begin
  FLock.Acquire;
  try CleanupLocked; finally FLock.Release; end;
end;

function TH2Pool.FindSlotLocked(const Key: string): TPoolSlot;
var
  i: Integer;
  S: TPoolSlot;
begin
  Result := nil;
  for i := 0 to FSlots.Count - 1 do
  begin
    S := TPoolSlot(FSlots[i]);
    if (S.Key = Key) and (not S.Failed) then
    begin
      Result := S;
      Exit;
    end;
  end;
end;

function TH2Pool.Acquire(const Key: string; out IsCreator: Boolean): TPoolSlot;
var
  S: TPoolSlot;
begin
  IsCreator := False;
  Result := nil;
  FLock.Acquire;
  try
    CleanupLocked;
    S := FindSlotLocked(Key);
    if Assigned(S) then
    begin
      if not S.Creating then
        Inc(FHits);
      S.AddRef;
      Result := S;
      Exit;
    end;
    S := TPoolSlot.Create(Key);   { RefCount=1, owned by pool }
    S.AddRef;                     { RefCount=2, caller also holds }
    FSlots.Add(S);
    Inc(FMisses);
    IsCreator := True;
    Result := S;
  finally
    FLock.Release;
  end;
end;

procedure TH2Pool.Publish(Slot: TPoolSlot; Conn: TH2Connection;
                          TLSConn: TTLSConnection; Sock: Integer);
begin
  if not Assigned(Slot) then Exit;
  FLock.Acquire;
  try
    Slot.Conn := Conn;
    Slot.TLSConn := TLSConn;
    Slot.Sock := Sock;
    Slot.Creating := False;
    Slot.LastUsed := GetTickCount64;
    RTLEventSetEvent(Slot.InitEvent);
  finally
    FLock.Release;
  end;
end;

procedure TH2Pool.FailCreate(Slot: TPoolSlot; const ErrMsg: string);
var
  i: Integer;
begin
  if not Assigned(Slot) then Exit;
  FLock.Acquire;
  try
    { H2 S4: set Failed + ErrorMsg BEFORE Creating so waiters that
      observe Creating=False also see Failed=True atomically }
    Slot.Failed := True;
    Slot.ErrorMsg := ErrMsg;
    Slot.Creating := False;
    for i := 0 to FSlots.Count - 1 do
      if TPoolSlot(FSlots[i]) = Slot then
      begin
        FSlots.Delete(i);
        Break;
      end;
    RTLEventSetEvent(Slot.InitEvent);
  finally
    FLock.Release;
  end;
  Slot.Release;
end;

procedure TH2Pool.Release(Slot: TPoolSlot);
begin
  if not Assigned(Slot) then Exit;
  Slot.LastUsed := GetTickCount64;
  Slot.Release;
end;

procedure TH2Pool.Clear;
var
  i: Integer;
  S: TPoolSlot;
begin
  FLock.Acquire;
  try
    for i := 0 to FSlots.Count - 1 do
    begin
      S := TPoolSlot(FSlots[i]);
      RTLEventSetEvent(S.InitEvent);
      try S.Release; except end;
    end;
    FSlots.Clear;
  finally
    FLock.Release;
  end;
end;

function TH2Pool.GetHits: Int64;
begin
  FLock.Acquire;
  try Result := FHits; finally FLock.Release; end;
end;

function TH2Pool.GetMisses: Int64;
begin
  FLock.Acquire;
  try Result := FMisses; finally FLock.Release; end;
end;

function TH2Pool.GetIdleCount: Integer;
var
  i: Integer;
  S: TPoolSlot;
begin
  Result := 0;
  FLock.Acquire;
  try
    for i := 0 to FSlots.Count - 1 do
    begin
      S := TPoolSlot(FSlots[i]);
      if (not S.Creating) and (not S.Failed) and Assigned(S.Conn)
         and (InterlockedCompareExchange(S.RefCount, 1, 1) = 1) then
        Inc(Result);
    end;
  finally
    FLock.Release;
  end;
end;

initialization
end.
