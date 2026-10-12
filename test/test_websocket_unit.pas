{ ====================================================================
  test_websocket_unit.pas — Protocol layer test (pure Pascal)
  ====================================================================
  Compile & run:
    fpc -Mobjfpc -Sh test/test_websocket_unit.pas
    ./test_websocket_unit
  ==================================================================== }

program test_websocket_unit;

{$MODE OBJFPC}{$H+}

uses
  SysUtils, pascak_websocket;

var
  Passed: Integer = 0;
  Failed: Integer = 0;

procedure Check(const Name: string; Cond: Boolean);
begin
  if Cond then
  begin
    Inc(Passed);
    WriteLn('  [OK]   ', Name);
  end
  else
  begin
    Inc(Failed);
    WriteLn('  [FAIL] ', Name);
  end;
end;

procedure CheckEq(const Name, Expected, Actual: string);
begin
  if Expected = Actual then
  begin
    Inc(Passed);
    WriteLn('  [OK]   ', Name);
  end
  else
  begin
    Inc(Failed);
    WriteLn('  [FAIL] ', Name);
    WriteLn('      expected: [', Expected, ']');
    WriteLn('      actual:   [', Actual, ']');
  end;
end;

// ─── Test 1: Accept-key ───
procedure TestAcceptKey;
var R: string;
begin
  WriteLn('Test 1: Accept-key');
  R := ComputeWSAccept('dGhlIHNhbXBsZSBub25jZQ==');
  CheckEq('RFC 6455 §1.3 example', 's3pPLMBiTxaQ9kYGzzhZRbK+xOo=', R);
  R := ComputeWSAccept('  dGhlIHNhbXBsZSBub25jZQ==  ');
  CheckEq('Whitespace trim', 's3pPLMBiTxaQ9kYGzzhZRbK+xOo=', R);
end;

// ─── Test 2: Round-trip ───
procedure TestRoundTrip;
var
  Frame: RawByteString;
  Parser: TWSFrameParser;
  F: TWSFrame;
begin
  WriteLn('Test 2: Round-trip');
  Frame := BuildWSFrame(wsText, 'hello', True);
  Check('Text frame size 7', Length(Frame) = 7);
  Check('First byte 0x81', Byte(Frame[1]) = $81);
  Check('Len 5', Byte(Frame[2]) = 5);

  Parser := TWSFrameParser.Create(False);
  try
    Parser.Append(Frame);
    Check('Parse OK', Parser.TryParse(F));
    Check('FIN=True', F.Fin);
    Check('Opcode=text', F.Opcode = wsText);
    Check('Payload=hello', F.Payload = 'hello');
    Check('Not masked', not F.Masked);
    Check('Buffer empty', not Parser.HasData);
  finally
    Parser.Free;
  end;
end;

// ─── Test 3: Masking ───
procedure TestMasking;
var
  Header, Payload: RawByteString;
  MaskKey: array[0..3] of Byte;
  Frame: RawByteString;
  Parser: TWSFrameParser;
  F: TWSFrame;
  I: Integer;
begin
  WriteLn('Test 3: Masking');
  MaskKey[0] := $37; MaskKey[1] := $FA; MaskKey[2] := $21; MaskKey[3] := $3D;
  Header := #$81#$85 + Char(MaskKey[0]) + Char(MaskKey[1])
                       + Char(MaskKey[2]) + Char(MaskKey[3]);
  Payload := 'Hello';
  for I := 1 to Length(Payload) do
    Payload[I] := Char(Byte(Payload[I]) xor MaskKey[(I - 1) mod 4]);
  Frame := Header + Payload;

  Parser := TWSFrameParser.Create(True);
  try
    Parser.Append(Frame);
    Check('Masked parse', Parser.TryParse(F));
    Check('Masked flag', F.Masked);
    Check('Unmasked=Hello', F.Payload = 'Hello');
    Check('Mask key kept', F.MaskKey[0] = $37);
  finally
    Parser.Free;
  end;
end;

// ─── Test 4: Extended 126 ───
procedure TestExtended126;
var
  Payload, Frame: RawByteString;
  Parser: TWSFrameParser;
  F: TWSFrame;
  I: Integer;
begin
  WriteLn('Test 4: Extended 126');
  SetLength(Payload, 300);
  for I := 1 to 300 do Payload[I] := Char(65 + (I mod 26));
  Frame := BuildWSFrame(wsText, Payload, True);
  Check('Size 4+300', Length(Frame) = 304);
  Check('Marker 126', Byte(Frame[2]) = 126);

  Parser := TWSFrameParser.Create(False);
  try
    Parser.Append(Frame);
    Check('Parse', Parser.TryParse(F));
    Check('Len 300', Length(F.Payload) = 300);
    Check('Content match', F.Payload = Payload);
  finally
    Parser.Free;
  end;
end;

// ─── Test 5: Extended 127 ───
procedure TestExtended127;
var
  Payload, Frame: RawByteString;
  Parser: TWSFrameParser;
  F: TWSFrame;
begin
  WriteLn('Test 5: Extended 127');
  SetLength(Payload, 70000);
  FillChar(Payload[1], 70000, 'X');
  Frame := BuildWSFrame(wsBinary, Payload, True);
  Check('Size 10+70000', Length(Frame) = 70010);
  Check('Marker 127', Byte(Frame[2]) = 127);

  Parser := TWSFrameParser.Create(False);
  try
    Parser.Append(Frame);
    Check('Parse', Parser.TryParse(F));
    Check('Len 70000', Length(F.Payload) = 70000);
    Check('Opcode binary', F.Opcode = wsBinary);
  finally
    Parser.Free;
  end;
end;

// ─── Test 6: Partial buffer ───
procedure TestPartialBuffer;
var
  Frame: RawByteString;
  Parser: TWSFrameParser;
  F: TWSFrame;
begin
  WriteLn('Test 6: Partial buffer');
  Frame := BuildWSFrame(wsText, 'hello world', True);
  Check('Size 13', Length(Frame) = 13);

  Parser := TWSFrameParser.Create(False);
  try
    Parser.Append(Copy(Frame, 1, 3));
    Check('Insufficient → False', not Parser.TryParse(F));
    Check('Buffer retained', Parser.HasData);

    Parser.Append(Copy(Frame, 4, Length(Frame) - 3));
    Check('Now parse OK', Parser.TryParse(F));
    Check('Payload=hello world', F.Payload = 'hello world');
  finally
    Parser.Free;
  end;
end;

// ─── Test 7: Close payload ───
procedure TestClosePayload;
var
  Payload: RawByteString;
  Code: Word;
  Reason: string;
begin
  WriteLn('Test 7: Close payload');
  SetLength(Payload, 0);
  Check('Empty parses', ParseClosePayload(Payload, Code, Reason));
  Check('Code 1005', Code = WS_CLOSE_NO_STATUS);
  Check('Reason empty', Reason = '');

  SetLength(Payload, 5);
  Payload[1] := Char((1000 shr 8) and $FF);
  Payload[2] := Char(1000 and $FF);
  Move('bye'[1], Payload[3], 3);
  Check('Parse 1000/bye', ParseClosePayload(Payload, Code, Reason));
  Check('Code 1000', Code = 1000);
  Check('Reason bye', Reason = 'bye');

  SetLength(Payload, 1);
  Payload[1] := 'X';
  Check('1-byte rejected', not ParseClosePayload(Payload, Code, Reason));
end;

// ─── Test 8: Fragmentasi ───
procedure TestFragmentasi;
var
  Parser: TWSFrameParser;
  F1, F2: TWSFrame;
  F1Raw, F2Raw: RawByteString;
begin
  WriteLn('Test 8: Fragmentasi');
  F1Raw := BuildWSFrame(wsText, 'Hello ', False);
  F2Raw := BuildWSFrame(wsContinuation, 'World', True);

  Parser := TWSFrameParser.Create(False);
  try
    Parser.Append(F1Raw);
    Check('F1 parse', Parser.TryParse(F1));
    Check('F1 FIN=False', not F1.Fin);
    Check('F1 opcode text', F1.Opcode = wsText);

    Parser.Append(F2Raw);
    Check('F2 parse', Parser.TryParse(F2));
    Check('F2 FIN=True', F2.Fin);
    Check('F2 opcode cont', F2.Opcode = wsContinuation);
    Check('F2 payload World', F2.Payload = 'World');
  finally
    Parser.Free;
  end;
end;

// ─── Test 9: Ping/pong ───
procedure TestPingPong;
var
  PingFrame, PongFrame: RawByteString;
  Parser: TWSFrameParser;
  F: TWSFrame;
begin
  WriteLn('Test 9: Ping/pong');
  PingFrame := BuildWSFrame(wsPing, 'PING', True);
  Check('Ping size 6', Length(PingFrame) = 6);
  Check('Ping byte 0x89', Byte(PingFrame[1]) = $89);

  Parser := TWSFrameParser.Create(False);
  try
    Parser.Append(PingFrame);
    Check('Ping parse', Parser.TryParse(F));
    Check('Opcode ping', F.Opcode = wsPing);
    Check('Payload PING', F.Payload = 'PING');

    PongFrame := BuildWSFrame(wsPong, F.Payload, True);
    Check('Pong 0x8A', Byte(PongFrame[1]) = $8A);
    Check('Pong len 4', Byte(PongFrame[2]) = 4);
  finally
    Parser.Free;
  end;
end;

// ─── Test 10: Error cases ───
procedure TestErrorCases;
var
  Parser: TWSFrameParser;
  F: TWSFrame;
  Frame: RawByteString;
  Caught: Boolean;
begin
  WriteLn('Test 10: Error cases');

  Frame := #$C1#$00;   // RSV1 set
  Parser := TWSFrameParser.Create(False);
  try
    Parser.Append(Frame);
    Caught := False;
    try Parser.TryParse(F); except on E: EWSProtocolError do Caught := True; end;
    Check('RSV1 rejected', Caught);
  finally Parser.Free; end;

  Frame := #$83#$00;   // Invalid opcode 0x3
  Parser := TWSFrameParser.Create(False);
  try
    Parser.Append(Frame);
    Caught := False;
    try Parser.TryParse(F); except on E: EWSProtocolError do Caught := True; end;
    Check('Invalid opcode rejected', Caught);
  finally Parser.Free; end;

  Frame := BuildWSFrame(wsText, 'hi', True);   // Unmasked
  Parser := TWSFrameParser.Create(True);   // Server mode
  try
    Parser.Append(Frame);
    Caught := False;
    try Parser.TryParse(F); except on E: EWSProtocolError do Caught := True; end;
    Check('Unmasked in server mode rejected', Caught);
  finally Parser.Free; end;
end;

// ─── Test 11: Fuzz ───
procedure Test_Fuzz;
var
  Parser: TWSFrameParser;
  F: TWSFrame;
  RndBytes: array[0..255] of Byte;
  I, J, Len, Crashes, Raised: Integer;
begin
  WriteLn('Test 11: Fuzz random bytes');

  Crashes := 0;
  Raised := 0;
  RandSeed := 12345;

  // Fuzz 1: random bytes
  for I := 1 to 500 do
  begin
    Len := 1 + Random(256);
    for J := 0 to Len - 1 do RndBytes[J] := Random(256);
    Parser := TWSFrameParser.Create(Random(2) = 1);
    try
      Parser.Append(Copy(RawByteString(RndBytes), 0, Len));
      try
        while Parser.TryParse(F) do
          if not Parser.HasData then Break;
      except
        on E: EWSProtocolError do Inc(Raised);
      end;
    finally Parser.Free; end;
  end;
  Check('fuzz 500 random — no crash', Crashes = 0);
  WriteLn('  (raised: ', Raised, ' / 500)');

  // Fuzz 2: HTTP-like
  for I := 1 to 100 do
  begin
    Len := 20 + Random(100);
    for J := 0 to Len - 1 do RndBytes[J] := 32 + Random(90);
    J := Random(Len - 4);
    RndBytes[J] := 13; RndBytes[J+1] := 10;
    RndBytes[J+2] := 13; RndBytes[J+3] := 10;
    Parser := TWSFrameParser.Create(True);
    try
      Parser.Append(Copy(RawByteString(RndBytes), 0, Len));
      try
        while Parser.TryParse(F) do
          if not Parser.HasData then Break;
      except
        on E: EWSProtocolError do ;
      end;
    finally Parser.Free; end;
  end;
  Check('fuzz HTTP-like — no crash', Crashes = 0);

  // Fuzz 3: byte-by-byte
  for I := 1 to 50 do
  begin
    Len := 10 + Random(50);
    for J := 0 to Len - 1 do RndBytes[J] := Random(256);
    Parser := TWSFrameParser.Create(False);
    try
      for J := 0 to Len - 1 do
      begin
        Parser.Append(RawByteString(Char(RndBytes[J])));
        try Parser.TryParse(F);
        except on E: EWSProtocolError do ; end;
      end;
    finally Parser.Free; end;
  end;
  Check('fuzz byte-by-byte — no crash', Crashes = 0);
end;

// ─── Test 12: Length extremes ───
procedure Test_LengthExtremes;
var
  Parser: TWSFrameParser;
  F: TWSFrame;
  Frame, Payload: RawByteString;
begin
  WriteLn('Test 12: Length extremes');

  Payload := StringOfChar('A', 125);
  Frame := BuildWSFrame(wsBinary, Payload, True);
  Check('125 direct marker', Byte(Frame[2]) = 125);
  Parser := TWSFrameParser.Create(False);
  try
    Parser.Append(Frame);
    Check('125 parse', Parser.TryParse(F));
    Check('125 match', Length(F.Payload) = 125);
  finally Parser.Free; end;

  Payload := StringOfChar('B', 126);
  Frame := BuildWSFrame(wsBinary, Payload, True);
  Check('126 extended', Byte(Frame[2]) = 126);
  Parser := TWSFrameParser.Create(False);
  try
    Parser.Append(Frame);
    Check('126 parse', Parser.TryParse(F));
    Check('126 match', Length(F.Payload) = 126);
  finally Parser.Free; end;

  Payload := StringOfChar('C', 65535);
  Frame := BuildWSFrame(wsBinary, Payload, True);
  Check('65535 marker 126', Byte(Frame[2]) = 126);
  Parser := TWSFrameParser.Create(False);
  try
    Parser.Append(Frame);
    Check('65535 parse', Parser.TryParse(F));
    Check('65535 match', Length(F.Payload) = 65535);
  finally Parser.Free; end;

  Payload := StringOfChar('D', 65536);
  Frame := BuildWSFrame(wsBinary, Payload, True);
  Check('65536 marker 127', Byte(Frame[2]) = 127);
  Parser := TWSFrameParser.Create(False);
  try
    Parser.Append(Frame);
    Check('65536 parse', Parser.TryParse(F));
    Check('65536 match', Length(F.Payload) = 65536);
  finally Parser.Free; end;
end;

// ═══════════════════════════════════════════════════════════════
//  Main
// ═══════════════════════════════════════════════════════════════
begin
  WriteLn('=================================================');
  WriteLn('  pascak_websocket Protocol Test');
  WriteLn('=================================================');
  WriteLn;

  TestAcceptKey;
  TestRoundTrip;
  TestMasking;
  TestExtended126;
  TestExtended127;
  TestPartialBuffer;
  TestClosePayload;
  TestFragmentasi;
  TestPingPong;
  TestErrorCases;
  Test_Fuzz;
  Test_LengthExtremes;

  WriteLn;
  WriteLn('=================================================');
  WriteLn('  Summary');
  WriteLn('=================================================');
  WriteLn('  Passed: ', Passed);
  WriteLn('  Failed: ', Failed);

  if Failed = 0 then
  begin
    WriteLn;
    WriteLn('RESULT: PASS');
    Halt(0);
  end
  else
  begin
    WriteLn;
    WriteLn('RESULT: FAIL');
    Halt(1);
  end;
end.
