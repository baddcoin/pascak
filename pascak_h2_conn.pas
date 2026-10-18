{ ====================================================================
  pascak_h2_conn.pas — HTTP/2 single-stream connection (RFC 7540)
  ==================================================================== }
unit pascak_h2_conn;

{$MODE OBJFPC}{$H+}

interface

uses
  Classes, SyncObjs, SysUtils,
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

    function SendFrame(const Frame: RawByteString): Boolean;
    function RecvRaw(TimeoutMs: Integer): Integer;
    function TryExtractFrame(out Frame: TH2Frame): Boolean;
    function RecvFrame(out Frame: TH2Frame; TimeoutMs: Integer = 10000): Boolean;
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

  TH2Pool = class
  private
    FEntries: TList;
    FLock: TCriticalSection;
    FMaxPerHost: Integer;
    FIdleMs: Integer;
    FHits: Int64;
    FMisses: Int64;
    procedure CleanupLocked;
    function CountForKey(const Key: string): Integer;
  public
    constructor Create(AMaxPerHost: Integer = 8; AIdleMs: Integer = 30000);
    destructor Destroy; override;
    function Get(const Key: string): TH2PooledEntry;
    function Put(E: TH2PooledEntry): Boolean;
    procedure Cleanup;
    procedure Clear;
    function GetHits: Int64;
    function GetMisses: Int64;
    function GetIdleCount: Integer;
    property MaxPerHost: Integer read FMaxPerHost write FMaxPerHost;
    property IdleMs: Integer read FIdleMs write FIdleMs;
  end;

implementation

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
end;

destructor TH2Connection.Destroy;
begin
  FDec.Free;
  FEnc.Free;
  inherited;
end;

function TH2Connection.SendFrame(const Frame: RawByteString): Boolean;
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

  if not SendFrame(H2BuildClientPreface) then Exit;

  SetLength(Settings, 3);
  Settings[0].ID := H2_SETTINGS_HEADER_TABLE_SIZE;
  Settings[0].Value := 4096;
  Settings[1].ID := H2_SETTINGS_INITIAL_WINDOW_SIZE;
  Settings[1].Value := FStreamWindow;
  Settings[2].ID := H2_SETTINGS_MAX_CONCURRENT_STREAMS;
  Settings[2].Value := 100;

  if not SendFrame(H2BuildSettings(Settings, False)) then Exit;

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
          if not SendFrame(H2BuildSettingsAck) then Exit;
          GotServerSettings := True;
        end;

      H2_FRAME_PING:
        if (Frame.Flags and H2_FLAG_ACK) = 0 then
          SendFrame(H2BuildPing(Frame.Payload, True));

      H2_FRAME_GOAWAY:
        begin
          FClosed := True;
          Exit;
        end;
    end;
  end;

  Result := GotServerSettings and (not FClosed);
end;

{ --- Part 2 (Request + Close) follows --- }

function TH2Connection.Request(const Method, Path: string;
  const ExtraHeaders: THPACKHeaderArray;
  const Body: RawByteString;
  TimeoutMs: Integer): TH2Response;
var
  ReqHeaders: THPACKHeaderArray;
  I, Total: Integer;
  HeaderBlock, RespHeadersAccum, BodyAccum: RawByteString;
  Frame: TH2Frame;
  GotEndStream, HeadersDecoded, IsDone: Boolean;
  Hdrs: THPACKHeaderArray;
  StatusCode: Integer;
  Start: QWord;
  CurrentStreamID: Cardinal;

  procedure Fail(const Msg: string);
  begin
    Result.HasError := True;
    Result.Error := Msg;
    IsDone := True;
  end;

begin
  Result.Status := 0;
  SetLength(Result.Headers, 0);
  Result.Body := '';
  Result.Error := '';
  Result.HasError := False;
  IsDone := False;
  StatusCode := 0;

  CurrentStreamID := FNextStreamID;
  Inc(FNextStreamID, 2);

  Total := 4 + Length(ExtraHeaders);
  SetLength(ReqHeaders, Total);
  ReqHeaders[0].Name := ':method';    ReqHeaders[0].Value := Method;
  ReqHeaders[1].Name := ':scheme';    ReqHeaders[1].Value := 'https';
  ReqHeaders[2].Name := ':path';      ReqHeaders[2].Value := Path;
  ReqHeaders[3].Name := ':authority'; ReqHeaders[3].Value := FHost;
  for I := 0 to High(ExtraHeaders) do
    ReqHeaders[4 + I] := ExtraHeaders[I];

  HeaderBlock := FEnc.Encode(ReqHeaders);

  if not SendFrame(H2BuildHeaders(CurrentStreamID, HeaderBlock, Length(Body) = 0, True)) then
  begin
    Fail('Send HEADERS failed');
    Exit;
  end;

  if Length(Body) > 0 then
  begin
    if not SendFrame(H2BuildData(CurrentStreamID, Body, True)) then
    begin
      Fail('Send DATA failed');
      Exit;
    end;
  end;

  RespHeadersAccum := '';
  BodyAccum := '';
  GotEndStream := False;
  HeadersDecoded := False;
  Start := GetTickCount64;

  while (not IsDone) and (not GotEndStream) and (not FClosed) do
  begin
    if GetTickCount64 - Start > QWord(TimeoutMs) then
    begin
      Fail('Response timeout');
      Break;
    end;

    if not RecvFrame(Frame, TimeoutMs) then
    begin
      if FClosed then Fail('Connection closed before END_STREAM')
      else Fail('RecvFrame failed');
      Break;
    end;

    case Frame.FrameType of
      H2_FRAME_SETTINGS:
        if (Frame.Flags and H2_FLAG_ACK) = 0 then
          SendFrame(H2BuildSettingsAck);

      H2_FRAME_PING:
        if (Frame.Flags and H2_FLAG_ACK) = 0 then
          SendFrame(H2BuildPing(Frame.Payload, True));

      H2_FRAME_WINDOW_UPDATE:
        ;

      H2_FRAME_HEADERS:
        if Frame.StreamID = CurrentStreamID then
        begin
          if not HeadersDecoded then
          begin
            RespHeadersAccum := RespHeadersAccum + Frame.Payload;
            if (Frame.Flags and H2_FLAG_END_HEADERS) <> 0 then
            begin
              try
                Hdrs := FDec.Decode(RespHeadersAccum);
              except
                on E: Exception do
                begin
                  Fail('HPACK decode failed: ' + E.Message);
                  Continue;
                end;
              end;
              for I := 0 to High(Hdrs) do
                if Hdrs[I].Name = ':status' then
                  StatusCode := StrToIntDef(Hdrs[I].Value, 0);
              Result.Headers := Hdrs;
              HeadersDecoded := True;
              RespHeadersAccum := '';
            end;
          end;
          if (Frame.Flags and H2_FLAG_END_STREAM) <> 0 then
            GotEndStream := True;
        end;

      H2_FRAME_CONTINUATION:
        if (Frame.StreamID = CurrentStreamID) and (not HeadersDecoded) then
        begin
          RespHeadersAccum := RespHeadersAccum + Frame.Payload;
          if (Frame.Flags and H2_FLAG_END_HEADERS) <> 0 then
          begin
            try
              Hdrs := FDec.Decode(RespHeadersAccum);
            except
              on E: Exception do
              begin
                Fail('HPACK decode failed (CONT): ' + E.Message);
                Continue;
              end;
            end;
            for I := 0 to High(Hdrs) do
              if Hdrs[I].Name = ':status' then
                StatusCode := StrToIntDef(Hdrs[I].Value, 0);
            Result.Headers := Hdrs;
            HeadersDecoded := True;
          end;
        end;

      H2_FRAME_DATA:
        if Frame.StreamID = CurrentStreamID then
        begin
          BodyAccum := BodyAccum + Frame.Payload;
          if Length(Frame.Payload) > 0 then
            SendFrame(H2BuildWindowUpdate(CurrentStreamID, Length(Frame.Payload)));
          if (Frame.Flags and H2_FLAG_END_STREAM) <> 0 then
            GotEndStream := True;
        end;

      H2_FRAME_RST_STREAM:
        if Frame.StreamID = CurrentStreamID then
          Fail('Server sent RST_STREAM');

      H2_FRAME_GOAWAY:
        Fail('Server sent GOAWAY');
    end;
  end;

  Result.Status := StatusCode;
  Result.Body := BodyAccum;
  if not Result.HasError and not GotEndStream then
  begin
    Result.HasError := True;
    Result.Error := 'No END_STREAM received';
  end;
end;

procedure TH2Connection.Close;
begin
  if not Assigned(FTLS) or FClosed then Exit;
  try
    SendFrame(H2BuildGoAway(1, H2_ERR_NO_ERROR, ''));
  except
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

constructor TH2Pool.Create(AMaxPerHost: Integer; AIdleMs: Integer);
begin
  inherited Create;
  FEntries := TList.Create;
  FLock := TCriticalSection.Create;
  FMaxPerHost := AMaxPerHost;
  FIdleMs := AIdleMs;
  FHits := 0;
  FMisses := 0;
end;

destructor TH2Pool.Destroy;
begin
  Clear;
  FEntries.Free;
  FLock.Free;
  inherited;
end;

procedure TH2Pool.CleanupLocked;
var
  i: Integer;
  E: TH2PooledEntry;
  NowTick: QWord;
begin
  NowTick := GetTickCount64;
  i := FEntries.Count - 1;
  while i >= 0 do
  begin
    E := TH2PooledEntry(FEntries[i]);
    if (not Assigned(E.Conn)) or E.Conn.Closed or
       ((NowTick - E.LastUsed) > QWord(FIdleMs)) then
    begin
      FEntries.Delete(i);
      try E.Free; except end;
    end;
    Dec(i);
  end;
end;

procedure TH2Pool.Cleanup;
begin
  FLock.Acquire;
  try CleanupLocked;
  finally FLock.Release;
  end;
end;

function TH2Pool.CountForKey(const Key: string): Integer;
var
  i: Integer;
begin
  Result := 0;
  for i := 0 to FEntries.Count - 1 do
    if TH2PooledEntry(FEntries[i]).Key = Key then
      Inc(Result);
end;

function TH2Pool.Get(const Key: string): TH2PooledEntry;
var
  i: Integer;
  E: TH2PooledEntry;
begin
  Result := nil;
  FLock.Acquire;
  try
    CleanupLocked;
    for i := FEntries.Count - 1 downto 0 do
    begin
      E := TH2PooledEntry(FEntries[i]);
      if E.Key = Key then
      begin
        Result := E;
        FEntries.Delete(i);
        Inc(FHits);
        Exit;
      end;
    end;
    Inc(FMisses);
  finally FLock.Release;
  end;
end;

function TH2Pool.Put(E: TH2PooledEntry): Boolean;
var
  i, SameKeyCount: Integer;
  EvictIdx: Integer;
  EvictTick: QWord;
begin
  Result := False;
  if not Assigned(E) then Exit;

  FLock.Acquire;
  try
    CleanupLocked;

    if (not Assigned(E.Conn)) or E.Conn.Closed then
    begin
      try E.Free; except end;
      Exit;
    end;

    // FIX: MaxPerHost=0 = pool disabled, reject entry
    if FMaxPerHost <= 0 then
    begin
      try E.Free; except end;
      Exit;
    end;

    SameKeyCount := CountForKey(E.Key);
    if SameKeyCount >= FMaxPerHost then
    begin
      EvictIdx := -1;
      EvictTick := High(QWord);
      for i := 0 to FEntries.Count - 1 do
      begin
        if (TH2PooledEntry(FEntries[i]).Key = E.Key) and
           (TH2PooledEntry(FEntries[i]).LastUsed < EvictTick) then
        begin
          EvictTick := TH2PooledEntry(FEntries[i]).LastUsed;
          EvictIdx := i;
        end;
      end;
      if EvictIdx >= 0 then
      begin
        try TH2PooledEntry(FEntries[EvictIdx]).Free; except end;
        FEntries.Delete(EvictIdx);
      end;
    end;

    E.LastUsed := GetTickCount64;
    FEntries.Add(E);
    Result := True;
  finally FLock.Release;
  end;
end;

procedure TH2Pool.Clear;
var
  i: Integer;
begin
  FLock.Acquire;
  try
    for i := 0 to FEntries.Count - 1 do
      try TH2PooledEntry(FEntries[i]).Free; except end;
    FEntries.Clear;
  finally FLock.Release;
  end;
end;

function TH2Pool.GetHits: Int64;
begin
  FLock.Acquire;
  try Result := FHits;
  finally FLock.Release;
  end;
end;

function TH2Pool.GetMisses: Int64;
begin
  FLock.Acquire;
  try Result := FMisses;
  finally FLock.Release;
  end;
end;

function TH2Pool.GetIdleCount: Integer;
begin
  FLock.Acquire;
  try Result := FEntries.Count;
  finally FLock.Release;
  end;
end;


initialization
end.
