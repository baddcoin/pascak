{ ====================================================================
  pascak_websocket.pas — WebSocket protocol (RFC 6455) untuk VM Pascak
  ====================================================================
  Protocol layer murni: frame parsing, building, handshake helpers.
  Integrasi dengan socket/TLS ada di pascak_noASTnet.pas.

  Scope v1:
    - Handshake accept-key (Sec-WebSocket-Accept)
    - Frame parsing incremental (FIN/RSV/opcode/mask/extended-len)
    - Frame building (server → client, unmasked)
    - Fragmentasi (continuation frames)
    - Control frames (ping/pong/close) — dispatch diserahkan ke caller
    - Close payload parser (code + reason)

  Bukan scope v1 (A.2):
    - Permessage-deflate
    - Subprotocol negotiation response
    - HTTP/2 WebSocket (RFC 8441)
  ==================================================================== }
unit pascak_websocket;

{$MODE OBJFPC}{$H+}

interface

uses
  Classes, SysUtils, sha1, base64;

type
  EWSProtocolError = class(Exception);

const
  // Close codes (RFC 6455 §7.4.1)
  WS_CLOSE_NORMAL           = 1000;
  WS_CLOSE_GOING_AWAY       = 1001;
  WS_CLOSE_PROTOCOL_ERR     = 1002;
  WS_CLOSE_UNSUPPORTED      = 1003;
  WS_CLOSE_NO_STATUS        = 1005;   // reserved — tidak boleh dikirim
  WS_CLOSE_ABNORMAL         = 1006;   // reserved — tidak boleh dikirim
  WS_CLOSE_INVALID_PAYLOAD  = 1007;
  WS_CLOSE_POLICY_VIOLATION = 1008;
  WS_CLOSE_TOO_LARGE        = 1009;
  WS_CLOSE_EXTENSION_REQ    = 1010;
  WS_CLOSE_INTERNAL_ERR     = 1011;

  // Batas payload — frame lebih besar ditolak dengan close 1009
  WS_MAX_FRAME_PAYLOAD = 16 * 1024 * 1024;   // 16 MB

  // Magic GUID dari RFC 6455 §1.3
  WS_MAGIC_GUID = '258EAFA5-E914-47DA-95CA-C5AB0DC85B11';

type
  TWSOpcode = (
    wsContinuation = $0,
    wsText         = $1,
    wsBinary       = $2,
    wsClose        = $8,
    wsPing         = $9,
    wsPong         = $A
  );

  TWSFrame = record
    Fin: Boolean;
    RSV1: Boolean;
    RSV2: Boolean;
    RSV3: Boolean;
    Opcode: TWSOpcode;
    Masked: Boolean;
    MaskKey: array[0..3] of Byte;
    Payload: RawByteString;
  end;

  // Parser incremental — buffer di-append dari recv(), TryParse di-loop
  // sampai False (buffer tidak cukup untuk frame lengkap).
  TWSFrameParser = class
  private
    FBuffer: RawByteString;
    FServerMode: Boolean;
    function GetBufferedBytes: Integer;
  public
    AllowRSV1: Boolean;   // A.2.4: set true kalau permessage-deflate negotiated
    constructor Create(AServerMode: Boolean);
    destructor Destroy; override;
    procedure Append(const Data: RawByteString);
    function TryParse(out Frame: TWSFrame): Boolean;
    function HasData: Boolean;
    procedure Clear;
    property BufferedBytes: Integer read GetBufferedBytes;
  end;

// ─── Frame builder (server → client, unmasked per RFC §5.1) ───
function BuildWSFrame(Opcode: TWSOpcode;
                      const Payload: RawByteString;
                      Fin: Boolean = True): RawByteString;

// Helper: close frame dengan code + reason
function BuildWSClose(Code: Word; const Reason: string): RawByteString;

// ─── Handshake ───
// Sec-WebSocket-Accept = base64(SHA1(key + GUID))
function ComputeWSAccept(const ClientKey: string): string;

// Deteksi apakah HTTP request adalah WebSocket upgrade.
// Return True + isi ClientKey, Version, Protocol (opsional).
function IsWebSocketUpgrade(Names, Values: TStringList;
                            out ClientKey, Version, Protocol: string): Boolean;

// Bangun HTTP 101 Switching Protocols response
function BuildWSHandshakeResponse(const ClientKey, Protocol: string): RawByteString;

// ─── Close payload parsing ───
// Return True jika payload valid (0 byte → code 1005, ≥2 byte → code + reason)
function ParseClosePayload(const Payload: RawByteString;
                           out Code: Word; out Reason: string): Boolean;

implementation

// ════════════════════════════════════════════════════════════════
//  Handshake helpers
// ════════════════════════════════════════════════════════════════

function ComputeWSAccept(const ClientKey: string): string;
var
  Concatenated: string;
  Hash: TSHA1Digest;
  Raw: RawByteString;
begin
  Concatenated := Trim(ClientKey) + WS_MAGIC_GUID;
  Hash := SHA1String(Concatenated);
  SetLength(Raw, 20);
  Move(Hash[0], Raw[1], 20);
  Result := EncodeStringBase64(string(Raw));
end;

function IsWebSocketUpgrade(Names, Values: TStringList;
                            out ClientKey, Version, Protocol: string): Boolean;
var
  i: Integer;
  UpgradeVal, ConnectionVal, KeyVal, VersionVal, ProtocolVal: string;
begin
  Result := False;
  ClientKey := '';
  Version := '';
  Protocol := '';

  if (not Assigned(Names)) or (not Assigned(Values)) then Exit;
  if Names.Count <> Values.Count then Exit;

  UpgradeVal := '';
  ConnectionVal := '';
  KeyVal := '';
  VersionVal := '';
  ProtocolVal := '';

  for i := 0 to Names.Count - 1 do
  begin
    if SameText(Names[i], 'Upgrade') then
      UpgradeVal := Values[i]
    else if SameText(Names[i], 'Connection') then
      ConnectionVal := Values[i]
    else if SameText(Names[i], 'Sec-WebSocket-Key') then
      KeyVal := Values[i]
    else if SameText(Names[i], 'Sec-WebSocket-Version') then
      VersionVal := Values[i]
    else if SameText(Names[i], 'Sec-WebSocket-Protocol') then
      ProtocolVal := Values[i];
  end;

  // RFC §4.2.1: minimal 4 validasi
  if not SameText(Trim(UpgradeVal), 'websocket') then Exit;
  if Pos('upgrade', LowerCase(ConnectionVal)) = 0 then Exit;
  if Trim(KeyVal) = '' then Exit;
  if Trim(VersionVal) <> '13' then Exit;

  ClientKey := Trim(KeyVal);
  Version := Trim(VersionVal);
  Protocol := Trim(ProtocolVal);
  Result := True;
end;

function BuildWSHandshakeResponse(const ClientKey, Protocol: string): RawByteString;
var
  Resp: string;
begin
  Resp := 'HTTP/1.1 101 Switching Protocols' + #13#10 +
          'Upgrade: websocket' + #13#10 +
          'Connection: Upgrade' + #13#10 +
          'Sec-WebSocket-Accept: ' + ComputeWSAccept(ClientKey) + #13#10;
  if Protocol <> '' then
    Resp := Resp + 'Sec-WebSocket-Protocol: ' + Protocol + #13#10;
  Resp := Resp + #13#10;   // blank line terminator
  Result := RawByteString(Resp);
end;

// ════════════════════════════════════════════════════════════════
//  Frame Parser
// ════════════════════════════════════════════════════════════════

constructor TWSFrameParser.Create(AServerMode: Boolean);
begin
  inherited Create;
  FBuffer := '';
  FServerMode := AServerMode;
  AllowRSV1 := False;
end;

destructor TWSFrameParser.Destroy;
begin
  FBuffer := '';
  inherited;
end;

procedure TWSFrameParser.Append(const Data: RawByteString);
begin
  if Length(Data) > 0 then
    FBuffer := FBuffer + Data;
end;

procedure TWSFrameParser.Clear;
begin
  FBuffer := '';
end;

function TWSFrameParser.GetBufferedBytes: Integer;
begin
  Result := Length(FBuffer);
end;

function TWSFrameParser.HasData: Boolean;
begin
  Result := Length(FBuffer) > 0;
end;

function TWSFrameParser.TryParse(out Frame: TWSFrame): Boolean;
var
  B0, B1: Byte;
  PayloadLen: Int64;
  MaskKey: array[0..3] of Byte;
  HeaderSize, TotalSize, i: Integer;
begin
  Result := False;
  Frame.Fin := False;
  Frame.RSV1 := False;
  Frame.RSV2 := False;
  Frame.RSV3 := False;
  Frame.Opcode := wsContinuation;
  Frame.Masked := False;
  Frame.Payload := '';

  if Length(FBuffer) < 2 then Exit;

  B0 := Byte(FBuffer[1]);
  B1 := Byte(FBuffer[2]);

  Frame.Fin := (B0 and $80) <> 0;
  Frame.RSV1 := (B0 and $40) <> 0;
  Frame.RSV2 := (B0 and $20) <> 0;
  Frame.RSV3 := (B0 and $10) <> 0;
  Frame.Opcode := TWSOpcode(B0 and $0F);
  Frame.Masked := (B1 and $80) <> 0;

  if Frame.RSV2 or Frame.RSV3 then
    raise EWSProtocolError.Create('RSV2/RSV3 set — extension tidak didukung');
  
  // RSV1 hanya valid kalau permessage-deflate di-negotiate
  if Frame.RSV1 and (not AllowRSV1) then
    raise EWSProtocolError.Create('RSV1 set — permessage-deflate tidak di-negotiate');

  case Frame.Opcode of
    wsContinuation, wsText, wsBinary, wsClose, wsPing, wsPong: ;
  else
    raise EWSProtocolError.CreateFmt('Opcode tidak dikenal: 0x%x',
                                     [Byte(Frame.Opcode)]);
  end;

  if Byte(Frame.Opcode) >= 8 then
  begin
    if not Frame.Fin then
      raise EWSProtocolError.Create('Control frame tidak boleh fragmented');
  end;

  if FServerMode and (not Frame.Masked) then
    raise EWSProtocolError.Create('Client frame harus masked');

  PayloadLen := B1 and $7F;
  HeaderSize := 2;

  if PayloadLen = 126 then
  begin
    if Length(FBuffer) < 4 then Exit;
    PayloadLen := (Int64(Byte(FBuffer[3])) shl 8)
                or Int64(Byte(FBuffer[4]));
    HeaderSize := 4;
  end
  else if PayloadLen = 127 then
  begin
    if Length(FBuffer) < 10 then Exit;
    PayloadLen := 0;
    for i := 0 to 7 do
      PayloadLen := (PayloadLen shl 8) or Int64(Byte(FBuffer[3 + i]));
    HeaderSize := 10;
  end;

  if (Byte(Frame.Opcode) >= 8) and (PayloadLen > 125) then
    raise EWSProtocolError.Create('Control frame payload > 125');

  if PayloadLen > WS_MAX_FRAME_PAYLOAD then
    raise EWSProtocolError.CreateFmt('Frame payload terlalu besar: %d byte',
                                     [PayloadLen]);

  if Frame.Masked then
  begin
    if Length(FBuffer) < HeaderSize + 4 then Exit;
    for i := 0 to 3 do
      MaskKey[i] := Byte(FBuffer[HeaderSize + 1 + i]);
    Inc(HeaderSize, 4);
  end;

  TotalSize := HeaderSize + Integer(PayloadLen);
  if Length(FBuffer) < TotalSize then Exit;

  if PayloadLen > 0 then
  begin
    SetLength(Frame.Payload, Integer(PayloadLen));
    Move(FBuffer[HeaderSize + 1], Frame.Payload[1], Integer(PayloadLen));
  end;

  if Frame.Masked then
  begin
    for i := 1 to Length(Frame.Payload) do
      Frame.Payload[i] := Char(Byte(Frame.Payload[i]) xor
                               MaskKey[(i - 1) mod 4]);
    for i := 0 to 3 do
      Frame.MaskKey[i] := MaskKey[i];
  end;

  if TotalSize >= Length(FBuffer) then
    FBuffer := ''
  else
    Delete(FBuffer, 1, TotalSize);

  Result := True;
end;

// ════════════════════════════════════════════════════════════════
//  Frame Builder
// ════════════════════════════════════════════════════════════════

function BuildWSFrame(Opcode: TWSOpcode;
                      const Payload: RawByteString;
                      Fin: Boolean = True): RawByteString;
var
  Header: RawByteString;
  B0: Byte;
  Len: Int64;
begin
  Len := Length(Payload);
  B0 := Byte(Opcode);
  if Fin then B0 := B0 or $80;

  if Len < 126 then
  begin
    SetLength(Header, 2);
    Header[1] := Char(B0);
    Header[2] := Char(Byte(Len));
  end
  else if Len <= 65535 then
  begin
    SetLength(Header, 4);
    Header[1] := Char(B0);
    Header[2] := Char(126);
    Header[3] := Char((Len shr 8) and $FF);
    Header[4] := Char(Len and $FF);
  end
  else
  begin
    SetLength(Header, 10);
    Header[1]  := Char(B0);
    Header[2]  := Char(127);
    Header[3]  := Char((Len shr 56) and $FF);
    Header[4]  := Char((Len shr 48) and $FF);
    Header[5]  := Char((Len shr 40) and $FF);
    Header[6]  := Char((Len shr 32) and $FF);
    Header[7]  := Char((Len shr 24) and $FF);
    Header[8]  := Char((Len shr 16) and $FF);
    Header[9]  := Char((Len shr 8)  and $FF);
    Header[10] := Char(Len and $FF);
  end;

  if Len > 0 then
    Result := Header + Payload
  else
    Result := Header;
end;

function BuildWSClose(Code: Word; const Reason: string): RawByteString;
var
  Payload: RawByteString;
begin
  SetLength(Payload, 2 + Length(Reason));
  Payload[1] := Char((Code shr 8) and $FF);
  Payload[2] := Char(Code and $FF);
  if Length(Reason) > 0 then
    Move(Reason[1], Payload[3], Length(Reason));
  Result := BuildWSFrame(wsClose, Payload, True);
end;

// ════════════════════════════════════════════════════════════════
//  Close payload parsing
// ════════════════════════════════════════════════════════════════

function ParseClosePayload(const Payload: RawByteString;
                           out Code: Word; out Reason: string): Boolean;
begin
  Result := False;
  Code := WS_CLOSE_NO_STATUS;
  Reason := '';

  // RFC §5.5.1: 0 byte → implicit 1005; 1 byte → invalid
  if Length(Payload) = 0 then
  begin
    Result := True;
    Exit;
  end;

  if Length(Payload) = 1 then
    Exit(False);

  Code := (Word(Byte(Payload[1])) shl 8) or Word(Byte(Payload[2]));
  if Length(Payload) > 2 then
    Reason := Copy(Payload, 3, Length(Payload) - 2);
  Result := True;
end;

initialization
finalization

end.