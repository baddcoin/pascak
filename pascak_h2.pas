{ ====================================================================
  pascak_h2.pas — HTTP/2 protocol layer (RFC 7540 + RFC 7541)

  Scope v1 (single-stream, no multiplexing):
    - Frame layer: parse + build 10 frame types
    - HPACK decoder: static + dynamic + Huffman (Step 1.3)
    - HPACK encoder: literal form (Step 1.3)
    - Connection state machine (Step 1.4)
    - Stream state machine (Step 1.4)

  Tidak tergantung engine — standalone, unit-testable.
  Dependensi: Classes, SysUtils (FPC stdlib).
  ==================================================================== }
unit pascak_h2;

{$MODE OBJFPC}{$H+}

interface

uses
  Classes, SysUtils;

type
  EH2Error            = class(Exception);
  EH2ProtocolError    = class(EH2Error);
  EH2CompressionError = class(EH2Error);

const
  H2_FRAME_HEADER_SIZE = 9;

  { Frame types (RFC 7540 §6) }
  H2_FRAME_DATA          = $0;
  H2_FRAME_HEADERS       = $1;
  H2_FRAME_PRIORITY      = $2;
  H2_FRAME_RST_STREAM    = $3;
  H2_FRAME_SETTINGS      = $4;
  H2_FRAME_PUSH_PROMISE  = $5;
  H2_FRAME_PING          = $6;
  H2_FRAME_GOAWAY        = $7;
  H2_FRAME_WINDOW_UPDATE = $8;
  H2_FRAME_CONTINUATION  = $9;

  { Frame flags }
  H2_FLAG_NONE        = $00;
  H2_FLAG_ACK         = $01;   { SETTINGS, PING }
  H2_FLAG_END_STREAM  = $01;   { DATA, HEADERS }
  H2_FLAG_END_HEADERS = $04;   { HEADERS, PUSH_PROMISE, CONTINUATION }
  H2_FLAG_PADDED      = $08;   { DATA, HEADERS, PUSH_PROMISE }
  H2_FLAG_PRIORITY    = $20;   { HEADERS }

  { Connection preface (RFC 7540 §3.5) }
  H2_CLIENT_PREFACE = 'PRI * HTTP/2.0'#13#10#13#10'SM'#13#10#13#10;

  { SETTINGS identifiers (RFC 7540 §6.5.2) }
  H2_SETTINGS_HEADER_TABLE_SIZE      = $1;
  H2_SETTINGS_ENABLE_PUSH            = $2;
  H2_SETTINGS_MAX_CONCURRENT_STREAMS = $3;
  H2_SETTINGS_INITIAL_WINDOW_SIZE    = $4;
  H2_SETTINGS_MAX_FRAME_SIZE         = $5;
  H2_SETTINGS_MAX_HEADER_LIST_SIZE   = $6;

  { Error codes (RFC 7540 §7) }
  H2_ERR_NO_ERROR            = $0;
  H2_ERR_PROTOCOL_ERROR      = $1;
  H2_ERR_INTERNAL_ERROR      = $2;
  H2_ERR_FLOW_CONTROL_ERROR  = $3;
  H2_ERR_SETTINGS_TIMEOUT    = $4;
  H2_ERR_STREAM_CLOSED       = $5;
  H2_ERR_FRAME_SIZE_ERROR    = $6;
  H2_ERR_REFUSED_STREAM      = $7;
  H2_ERR_CANCEL              = $8;
  H2_ERR_COMPRESSION_ERROR   = $9;
  H2_ERR_CONNECT_ERROR       = $A;
  H2_ERR_ENHANCE_YOUR_CALM   = $B;
  H2_ERR_INADEQUATE_SECURITY = $C;
  H2_ERR_HTTP_1_1_REQUIRED   = $D;

  { Protocol defaults }
  H2_DEFAULT_WINDOW_SIZE    = 65535;    { RFC 7540 §6.9.2 }
  H2_DEFAULT_MAX_FRAME_SIZE = 16384;    { RFC 7540 §4.2 }
  H2_MAX_FRAME_SIZE_LIMIT   = 16777215; { 2^24 - 1 }

type
  { Enum untuk readability — tapi wire formatnya Byte }
  TH2FrameType = (
    h2ftData         = $0,
    h2ftHeaders      = $1,
    h2ftPriority     = $2,
    h2ftRSTStream    = $3,
    h2ftSettings     = $4,
    h2ftPushPromise  = $5,
    h2ftPing         = $6,
    h2ftGoAway       = $7,
    h2ftWindowUpdate = $8,
    h2ftContinuation = $9
  );

  TH2Frame = record
    Length:    Cardinal;         { 24-bit payload length }
    FrameType: Byte;             { raw byte — decode via H2FrameTypeName }
    Flags:     Byte;
    StreamID:  Cardinal;         { 31-bit — reserved bit sudah di-strip }
    Payload:   RawByteString;
  end;

  TH2SettingItem = record
    ID:    Word;
    Value: Cardinal;
  end;
  TH2SettingArray = array of TH2SettingItem;

{ ═══════════════════════════════════════════════════════════════
  Frame parsing
  ═══════════════════════════════════════════════════════════════ }

{ Try parse satu frame dari Buf mulai offset (1-based).
  Return True kalau header + payload lengkap tersedia.
  Consumed = 9 + Length bytes yang dikonsumsi (mulai dari offset). }
function H2TryParseFrame(const Buf: RawByteString; Offset: Integer;
                          out Frame: TH2Frame;
                          out Consumed: Integer): Boolean;

{ ═══════════════════════════════════════════════════════════════
  Frame building
  ═══════════════════════════════════════════════════════════════ }

function H2BuildFrame(FrameType, Flags: Byte; StreamID: Cardinal;
                      const Payload: RawByteString): RawByteString;

function H2BuildClientPreface: RawByteString;
function H2BuildSettings(const Items: TH2SettingArray;
                          Ack: Boolean = False): RawByteString;
function H2BuildSettingsAck: RawByteString;
function H2BuildWindowUpdate(StreamID, Increment: Cardinal): RawByteString;
function H2BuildPing(const Data: RawByteString;
                     Ack: Boolean = False): RawByteString;
function H2BuildGoAway(LastStreamID, ErrorCode: Cardinal;
                       const DebugData: RawByteString = ''): RawByteString;
function H2BuildRSTStream(StreamID, ErrorCode: Cardinal): RawByteString;
function H2BuildHeaders(StreamID: Cardinal;
                        const HeaderBlock: RawByteString;
                        EndStream: Boolean;
                        EndHeaders: Boolean = True): RawByteString;
function H2BuildData(StreamID: Cardinal;
                     const Data: RawByteString;
                     EndStream: Boolean = False): RawByteString;

{ ═══════════════════════════════════════════════════════════════
  Frame parsing helpers
  ═══════════════════════════════════════════════════════════════ }

function H2ParseSettings(const Payload: RawByteString;
                          out Items: TH2SettingArray): Boolean;
function H2ParseGoAway(const Payload: RawByteString;
                        out LastStreamID, ErrorCode: Cardinal;
                        out DebugData: RawByteString): Boolean;
function H2ParseRSTStream(const Payload: RawByteString;
                           out ErrorCode: Cardinal): Boolean;
function H2ParseWindowUpdate(const Payload: RawByteString;
                              out Increment: Cardinal): Boolean;

{ ═══════════════════════════════════════════════════════════════
  Diagnostics
  ═══════════════════════════════════════════════════════════════ }

function H2FrameTypeName(FT: Byte): string;
function H2ErrorName(Code: Cardinal): string;

implementation

{ ═══════════════════════════════════════════════════════════════
  Frame building
  ═══════════════════════════════════════════════════════════════ }

function H2BuildFrame(FrameType, Flags: Byte; StreamID: Cardinal;
                      const Payload: RawByteString): RawByteString;
var
  Len: Cardinal;
begin
  Len := Cardinal(Length(Payload));
  if Len > H2_MAX_FRAME_SIZE_LIMIT then
    raise EH2Error.CreateFmt('H2: frame payload too large (%d bytes)', [Len]);

  SetLength(Result, H2_FRAME_HEADER_SIZE + Integer(Len));

  { 24-bit length, big-endian }
  Result[1] := Char((Len shr 16) and $FF);
  Result[2] := Char((Len shr  8) and $FF);
  Result[3] := Char( Len        and $FF);

  Result[4] := Char(FrameType);
  Result[5] := Char(Flags);

  { 31-bit stream ID, big-endian, reserved bit = 0 }
  StreamID := StreamID and $7FFFFFFF;
  Result[6] := Char((StreamID shr 24) and $FF);
  Result[7] := Char((StreamID shr 16) and $FF);
  Result[8] := Char((StreamID shr  8) and $FF);
  Result[9] := Char( StreamID        and $FF);

  if Len > 0 then
    Move(Payload[1], Result[H2_FRAME_HEADER_SIZE + 1], Len);
end;

function H2BuildClientPreface: RawByteString;
begin
  Result := RawByteString(H2_CLIENT_PREFACE);
end;

function H2BuildSettings(const Items: TH2SettingArray;
                          Ack: Boolean): RawByteString;
var
  Payload: RawByteString;
  i: Integer;
  V: Cardinal;
begin
  if Ack then
  begin
    Result := H2BuildFrame(H2_FRAME_SETTINGS, H2_FLAG_ACK, 0, '');
    Exit;
  end;

  SetLength(Payload, Length(Items) * 6);
  for i := 0 to High(Items) do
  begin
    Payload[i * 6 + 1] := Char((Items[i].ID shr 8) and $FF);
    Payload[i * 6 + 2] := Char( Items[i].ID       and $FF);
    V := Items[i].Value;
    Payload[i * 6 + 3] := Char((V shr 24) and $FF);
    Payload[i * 6 + 4] := Char((V shr 16) and $FF);
    Payload[i * 6 + 5] := Char((V shr  8) and $FF);
    Payload[i * 6 + 6] := Char( V        and $FF);
  end;
  Result := H2BuildFrame(H2_FRAME_SETTINGS, 0, 0, Payload);
end;

function H2BuildSettingsAck: RawByteString;
begin
  Result := H2BuildFrame(H2_FRAME_SETTINGS, H2_FLAG_ACK, 0, '');
end;

function H2BuildWindowUpdate(StreamID, Increment: Cardinal): RawByteString;
var
  Payload: RawByteString;
begin
  Increment := Increment and $7FFFFFFF;
  SetLength(Payload, 4);
  Payload[1] := Char((Increment shr 24) and $FF);
  Payload[2] := Char((Increment shr 16) and $FF);
  Payload[3] := Char((Increment shr  8) and $FF);
  Payload[4] := Char( Increment        and $FF);
  Result := H2BuildFrame(H2_FRAME_WINDOW_UPDATE, 0, StreamID, Payload);
end;

function H2BuildPing(const Data: RawByteString; Ack: Boolean): RawByteString;
var
  Flags: Byte;
begin
  if Length(Data) <> 8 then
    raise EH2Error.Create('H2: ping payload must be exactly 8 bytes');
  if Ack then Flags := H2_FLAG_ACK else Flags := 0;
  Result := H2BuildFrame(H2_FRAME_PING, Flags, 0, Data);
end;

function H2BuildGoAway(LastStreamID, ErrorCode: Cardinal;
                       const DebugData: RawByteString): RawByteString;
var
  Payload: RawByteString;
begin
  SetLength(Payload, 8 + Length(DebugData));
  LastStreamID := LastStreamID and $7FFFFFFF;
  Payload[1] := Char((LastStreamID shr 24) and $FF);
  Payload[2] := Char((LastStreamID shr 16) and $FF);
  Payload[3] := Char((LastStreamID shr  8) and $FF);
  Payload[4] := Char( LastStreamID        and $FF);
  Payload[5] := Char((ErrorCode shr 24) and $FF);
  Payload[6] := Char((ErrorCode shr 16) and $FF);
  Payload[7] := Char((ErrorCode shr  8) and $FF);
  Payload[8] := Char( ErrorCode        and $FF);
  if Length(DebugData) > 0 then
    Move(DebugData[1], Payload[9], Length(DebugData));
  Result := H2BuildFrame(H2_FRAME_GOAWAY, 0, 0, Payload);
end;

function H2BuildRSTStream(StreamID, ErrorCode: Cardinal): RawByteString;
var
  Payload: RawByteString;
begin
  SetLength(Payload, 4);
  Payload[1] := Char((ErrorCode shr 24) and $FF);
  Payload[2] := Char((ErrorCode shr 16) and $FF);
  Payload[3] := Char((ErrorCode shr  8) and $FF);
  Payload[4] := Char( ErrorCode        and $FF);
  Result := H2BuildFrame(H2_FRAME_RST_STREAM, 0, StreamID, Payload);
end;

function H2BuildHeaders(StreamID: Cardinal;
                        const HeaderBlock: RawByteString;
                        EndStream: Boolean;
                        EndHeaders: Boolean): RawByteString;
var
  Flags: Byte;
begin
  Flags := 0;
  if EndStream  then Flags := Flags or H2_FLAG_END_STREAM;
  if EndHeaders then Flags := Flags or H2_FLAG_END_HEADERS;
  Result := H2BuildFrame(H2_FRAME_HEADERS, Flags, StreamID, HeaderBlock);
end;

function H2BuildData(StreamID: Cardinal;
                     const Data: RawByteString;
                     EndStream: Boolean): RawByteString;
var
  Flags: Byte;
begin
  Flags := 0;
  if EndStream then Flags := Flags or H2_FLAG_END_STREAM;
  Result := H2BuildFrame(H2_FRAME_DATA, Flags, StreamID, Data);
end;

{ ═══════════════════════════════════════════════════════════════
  Frame parsing
  ═══════════════════════════════════════════════════════════════ }

function H2TryParseFrame(const Buf: RawByteString; Offset: Integer;
                          out Frame: TH2Frame;
                          out Consumed: Integer): Boolean;
var
  Avail: Integer;
  Len: Cardinal;
begin
  Result := False;
  Consumed := 0;
  Frame.Length := 0;
  Frame.FrameType := 0;
  Frame.Flags := 0;
  Frame.StreamID := 0;
  Frame.Payload := '';

  if Offset < 1 then Offset := 1;
  Avail := Length(Buf) - Offset + 1;
  if Avail < H2_FRAME_HEADER_SIZE then Exit;

  Len := (Cardinal(Byte(Buf[Offset]))     shl 16)
       or (Cardinal(Byte(Buf[Offset + 1])) shl 8)
       or  Cardinal(Byte(Buf[Offset + 2]));

  if Avail < H2_FRAME_HEADER_SIZE + Integer(Len) then Exit;

  Frame.Length    := Len;
  Frame.FrameType := Byte(Buf[Offset + 3]);
  Frame.Flags     := Byte(Buf[Offset + 4]);
  Frame.StreamID  := ((Cardinal(Byte(Buf[Offset + 5])) shl 24)
                   or (Cardinal(Byte(Buf[Offset + 6])) shl 16)
                   or (Cardinal(Byte(Buf[Offset + 7])) shl 8)
                   or  Cardinal(Byte(Buf[Offset + 8]))) and $7FFFFFFF;

  if Len > 0 then
  begin
    SetLength(Frame.Payload, Len);
    Move(Buf[Offset + H2_FRAME_HEADER_SIZE], Frame.Payload[1], Len);
  end;

  Consumed := H2_FRAME_HEADER_SIZE + Integer(Len);
  Result := True;
end;

function H2ParseSettings(const Payload: RawByteString;
                          out Items: TH2SettingArray): Boolean;
var
  i, N: Integer;
begin
  Result := False;
  SetLength(Items, 0);
  if (Length(Payload) mod 6) <> 0 then Exit;
  N := Length(Payload) div 6;
  SetLength(Items, N);
  for i := 0 to N - 1 do
  begin
    Items[i].ID := (Word(Byte(Payload[i * 6 + 1])) shl 8)
                 or  Word(Byte(Payload[i * 6 + 2]));
    Items[i].Value := (Cardinal(Byte(Payload[i * 6 + 3])) shl 24)
                    or (Cardinal(Byte(Payload[i * 6 + 4])) shl 16)
                    or (Cardinal(Byte(Payload[i * 6 + 5])) shl 8)
                    or  Cardinal(Byte(Payload[i * 6 + 6]));
  end;
  Result := True;
end;

function H2ParseGoAway(const Payload: RawByteString;
                        out LastStreamID, ErrorCode: Cardinal;
                        out DebugData: RawByteString): Boolean;
begin
  Result := False;
  LastStreamID := 0;
  ErrorCode := 0;
  DebugData := '';
  if Length(Payload) < 8 then Exit;

  LastStreamID := ((Cardinal(Byte(Payload[1])) shl 24)
                or (Cardinal(Byte(Payload[2])) shl 16)
                or (Cardinal(Byte(Payload[3])) shl 8)
                or  Cardinal(Byte(Payload[4]))) and $7FFFFFFF;

  ErrorCode := (Cardinal(Byte(Payload[5])) shl 24)
             or (Cardinal(Byte(Payload[6])) shl 16)
             or (Cardinal(Byte(Payload[7])) shl 8)
             or  Cardinal(Byte(Payload[8]));

  if Length(Payload) > 8 then
    DebugData := Copy(Payload, 9, Length(Payload) - 8);

  Result := True;
end;

function H2ParseRSTStream(const Payload: RawByteString;
                           out ErrorCode: Cardinal): Boolean;
begin
  Result := False;
  ErrorCode := 0;
  if Length(Payload) <> 4 then Exit;
  ErrorCode := (Cardinal(Byte(Payload[1])) shl 24)
             or (Cardinal(Byte(Payload[2])) shl 16)
             or (Cardinal(Byte(Payload[3])) shl 8)
             or  Cardinal(Byte(Payload[4]));
  Result := True;
end;

function H2ParseWindowUpdate(const Payload: RawByteString;
                              out Increment: Cardinal): Boolean;
begin
  Result := False;
  Increment := 0;
  if Length(Payload) <> 4 then Exit;
  Increment := ((Cardinal(Byte(Payload[1])) shl 24)
              or (Cardinal(Byte(Payload[2])) shl 16)
              or (Cardinal(Byte(Payload[3])) shl 8)
              or  Cardinal(Byte(Payload[4]))) and $7FFFFFFF;
  Result := True;
end;

{ ═══════════════════════════════════════════════════════════════
  Diagnostics
  ═══════════════════════════════════════════════════════════════ }

function H2FrameTypeName(FT: Byte): string;
begin
  case FT of
    H2_FRAME_DATA:          Result := 'DATA';
    H2_FRAME_HEADERS:       Result := 'HEADERS';
    H2_FRAME_PRIORITY:      Result := 'PRIORITY';
    H2_FRAME_RST_STREAM:    Result := 'RST_STREAM';
    H2_FRAME_SETTINGS:      Result := 'SETTINGS';
    H2_FRAME_PUSH_PROMISE:  Result := 'PUSH_PROMISE';
    H2_FRAME_PING:          Result := 'PING';
    H2_FRAME_GOAWAY:        Result := 'GOAWAY';
    H2_FRAME_WINDOW_UPDATE: Result := 'WINDOW_UPDATE';
    H2_FRAME_CONTINUATION:  Result := 'CONTINUATION';
  else
    Result := Format('UNKNOWN($%.2x)', [FT]);
  end;
end;

function H2ErrorName(Code: Cardinal): string;
begin
  case Code of
    H2_ERR_NO_ERROR:            Result := 'NO_ERROR';
    H2_ERR_PROTOCOL_ERROR:      Result := 'PROTOCOL_ERROR';
    H2_ERR_INTERNAL_ERROR:      Result := 'INTERNAL_ERROR';
    H2_ERR_FLOW_CONTROL_ERROR:  Result := 'FLOW_CONTROL_ERROR';
    H2_ERR_SETTINGS_TIMEOUT:    Result := 'SETTINGS_TIMEOUT';
    H2_ERR_STREAM_CLOSED:       Result := 'STREAM_CLOSED';
    H2_ERR_FRAME_SIZE_ERROR:    Result := 'FRAME_SIZE_ERROR';
    H2_ERR_REFUSED_STREAM:      Result := 'REFUSED_STREAM';
    H2_ERR_CANCEL:              Result := 'CANCEL';
    H2_ERR_COMPRESSION_ERROR:   Result := 'COMPRESSION_ERROR';
    H2_ERR_CONNECT_ERROR:       Result := 'CONNECT_ERROR';
    H2_ERR_ENHANCE_YOUR_CALM:   Result := 'ENHANCE_YOUR_CALM';
    H2_ERR_INADEQUATE_SECURITY: Result := 'INADEQUATE_SECURITY';
    H2_ERR_HTTP_1_1_REQUIRED:   Result := 'HTTP_1_1_REQUIRED';
  else
    Result := Format('UNKNOWN($%.2x)', [Code]);
  end;
end;

initialization
finalization

end.
