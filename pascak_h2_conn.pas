{ ====================================================================
  pascak_h2_conn.pas — HTTP/2 single-stream connection (RFC 7540)
  ==================================================================== }
unit pascak_h2_conn;

{$MODE OBJFPC}{$H+}

interface

uses
  SysUtils,
  pascak_tls, pascak_h2, pascak_h2_hpack;

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

  Total := 4 + Length(ExtraHeaders);
  SetLength(ReqHeaders, Total);
  ReqHeaders[0].Name := ':method';    ReqHeaders[0].Value := Method;
  ReqHeaders[1].Name := ':scheme';    ReqHeaders[1].Value := 'https';
  ReqHeaders[2].Name := ':path';      ReqHeaders[2].Value := Path;
  ReqHeaders[3].Name := ':authority'; ReqHeaders[3].Value := FHost;
  for I := 0 to High(ExtraHeaders) do
    ReqHeaders[4 + I] := ExtraHeaders[I];

  HeaderBlock := FEnc.Encode(ReqHeaders);

  if not SendFrame(H2BuildHeaders(1, HeaderBlock, Length(Body) = 0, True)) then
  begin
    Fail('Send HEADERS failed');
    Exit;
  end;

  if Length(Body) > 0 then
  begin
    if not SendFrame(H2BuildData(1, Body, True)) then
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
        if Frame.StreamID = 1 then
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
        if (Frame.StreamID = 1) and (not HeadersDecoded) then
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
        if Frame.StreamID = 1 then
        begin
          BodyAccum := BodyAccum + Frame.Payload;
          if Length(Frame.Payload) > 0 then
            SendFrame(H2BuildWindowUpdate(1, Length(Frame.Payload)));
          if (Frame.Flags and H2_FLAG_END_STREAM) <> 0 then
            GotEndStream := True;
        end;

      H2_FRAME_RST_STREAM:
        if Frame.StreamID = 1 then
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

initialization
end.
