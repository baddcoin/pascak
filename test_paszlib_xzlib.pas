{ ====================================================================
  test_paszlib_xzlib.pas — Cross-compatibility dengan zlib Python
  ====================================================================
  Verifikasi bahwa:
    - DeflateRaw(pascal) → zlib.decompress(python) match
    - zlib.compress(python) → InflateRaw(pascal) match
  ==================================================================== }

program test_paszlib_xzlib;

{$MODE OBJFPC}{$H+}

uses
  Classes, SysUtils, paszlib, Process;

var
  GPassed: Integer = 0;
  GFailed: Integer = 0;

function HexToRaw(const Hex: RawByteString): RawByteString;
var
  I: Integer;
  Hi, Lo: Byte;

  function Nibble(C: Char): Byte;
  begin
    case C of
      '0'..'9': Result := Ord(C) - Ord('0');
      'a'..'f': Result := Ord(C) - Ord('a') + 10;
      'A'..'F': Result := Ord(C) - Ord('A') + 10;
    else
      Result := 0;
    end;
  end;

begin
  SetLength(Result, Length(Hex) div 2);
  for I := 0 to Length(Result) - 1 do
  begin
    Hi := Nibble(Hex[I * 2 + 1]);
    Lo := Nibble(Hex[I * 2 + 2]);
    Result[I + 1] := Char((Hi shl 4) or Lo);
  end;
end;

procedure Check(const AName: string; ACondition: Boolean);
begin
  if ACondition then
  begin
    WriteLn('  [OK]   ', AName);
    Inc(GPassed);
  end
  else
  begin
    WriteLn('  [FAIL] ', AName);
    Inc(GFailed);
  end;
end;

{ Baca output Python dari command line — helper }
function RunPython(const AScript: string; out AOutput: RawByteString): Boolean;
var
  P: TProcess;
  MemStream: TMemoryStream;
  BytesRead: LongInt;
  Buf: array[0..4095] of Byte;
begin
  Result := False;
  AOutput := '';
  P := TProcess.Create(nil);
  MemStream := TMemoryStream.Create;
  try
    P.Executable := 'python3';
    P.Parameters.Add('-c');
    P.Parameters.Add(AScript);
    P.Options := [poUsePipes, poStderrToOutPut];
    P.Execute;

    repeat
      BytesRead := P.Output.Read(Buf, SizeOf(Buf));
      if BytesRead > 0 then
        MemStream.Write(Buf, BytesRead);
    until BytesRead = 0;

    P.WaitOnExit;
    MemStream.Position := 0;
    SetLength(AOutput, MemStream.Size);
    if MemStream.Size > 0 then
      MemStream.Read(AOutput[1], MemStream.Size);
    Result := P.ExitStatus = 0;
  finally
    MemStream.Free;
    P.Free;
  end;
end;

procedure Test_PascalDeflate_PythonInflate;
const
  TEST_DATA = 'hello world hello world hello world this is a test';
var
  Compressed: RawByteString;
  Hex, PyScript, PyOut: RawByteString;
  I: Integer;
  RestoredFromPy: RawByteString;
  Ok: Boolean;
begin
  WriteLn('Test 1: DeflateRaw(Pascal) -> zlib.decompress(Python)');

  Compressed := DeflateRaw(TEST_DATA);
  WriteLn('  compressed length: ', Length(Compressed));

  { Encode ke hex untuk transfer via command line }
  SetLength(Hex, Length(Compressed) * 2);
  for I := 1 to Length(Compressed) do
  begin
    Hex[(I - 1) * 2 + 1] := LowerCase(IntToHex(Byte(Compressed[I]), 2))[1];
    Hex[(I - 1) * 2 + 2] := LowerCase(IntToHex(Byte(Compressed[I]), 2))[2];
  end;

  PyScript := 'import zlib; ' +
              'data = bytes.fromhex("' + Hex + '"); ' +
              'print(zlib.decompress(data, -15).decode("latin-1"), end="")';

  Ok := RunPython(PyScript, PyOut);
  Check('python exited ok', Ok);
  Check('decompressed matches original', PyOut = TEST_DATA);
end;

procedure Test_PythonDeflate_PascalInflate;
const
  TEST_DATA = 'hello world hello world hello world this is a test';
var
  PyScript, PyOut: RawByteString;
  Compressed, Restored: RawByteString;
  Ok: Boolean;
begin
  WriteLn('Test 2: zlib.compress(Python) -> InflateRaw(Pascal)');

  { Python emit hex of raw deflate stream }
  PyScript := 'import zlib; ' +
              'data = b"' + TEST_DATA + '"; ' +
              'c = zlib.compressobj(6, zlib.DEFLATED, -15); ' +
              'raw = c.compress(data) + c.flush(); ' +
              'print(raw.hex(), end="")';

  Ok := RunPython(PyScript, PyOut);
  Check('python exited ok', Ok);
  Check('python produced output', Length(PyOut) > 0);

  if Length(PyOut) > 0 then
  begin
    { Decode hex dari Python ke raw bytes }
    SetLength(Compressed, Length(PyOut) div 2);
    Restored := InflateRaw(HexToRaw(PyOut));
    Check('decompressed matches original', Restored = TEST_DATA);
  end;
end;

begin
  WriteLn('=================================================');
  WriteLn('  paszlib <-> zlib interop test');
  WriteLn('=================================================');
  WriteLn;

  Test_PascalDeflate_PythonInflate;
  WriteLn;
  Test_PythonDeflate_PascalInflate;

  WriteLn;
  WriteLn('Passed: ', GPassed, '  Failed: ', GFailed);

  if GFailed = 0 then
  begin
    WriteLn('RESULT: PASS');
    Halt(0);
  end
  else
  begin
    WriteLn('RESULT: FAIL');
    Halt(1);
  end;
end.