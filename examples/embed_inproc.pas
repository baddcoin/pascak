{
  ═══════════════════════════════════════════════════════════════
  examples/embed_inproc.pas

  In-process Pascak engine embedding demo.
  Shows how to use pascak_engine as a library.

  Build:
      fpc -Mobjfpc -Sh examples/embed_inproc.pas

  Run:
      ./examples/embed_inproc

  IMPORTANT: cthreads MUST be first unit on Unix.
  Without it, FPC may crash before the engine initializes.

  ═══════════════════════════════════════════════════════════════
}
program embed_inproc;

{$MODE OBJFPC}{$H+}

uses
  {$IFDEF UNIX}
    cthreads,
  {$ENDIF}
  SysUtils, pascak_engine;

var
  R: TPascakResult;
  Failed: Integer;
  I: Integer;
begin
  Failed := 0;

  WriteLn('=== Test 1: numeric ===');
  R := ExecuteEngine('begin return 6 * 7; end.');
  if R.Success and (R.ValueType = 'numeric') and (Abs(R.ValueAsNum - 42) < 0.001) then
    WriteLn('  PASS: ', R.ValueAsString)
  else
  begin
    WriteLn('  FAIL: type=', R.ValueType, ' num=', R.ValueAsNum, ' err=', R.Error);
    Inc(Failed);
  end;

  WriteLn('=== Test 2: string ===');
  R := ExecuteEngine('begin return "hello"; end.');
  if R.Success and (R.ValueType = 'string') and (R.ValueAsString = 'hello') then
    WriteLn('  PASS: ', R.ValueAsString)
  else
  begin
    WriteLn('  FAIL: type=', R.ValueType, ' str=', R.ValueAsString, ' err=', R.Error);
    Inc(Failed);
  end;

  WriteLn('=== Test 3: boolean ===');
  R := ExecuteEngine('begin return true; end.');
  if R.Success and (R.ValueType = 'boolean') and R.ValueAsBool then
    WriteLn('  PASS: true')
  else
  begin
    WriteLn('  FAIL: type=', R.ValueType, ' err=', R.Error);
    Inc(Failed);
  end;

  WriteLn('=== Test 4: null (no explicit return) ===');
  R := ExecuteEngine('begin var x := 1; end.');
  if R.Success and (R.ValueType = 'null') then
    WriteLn('  PASS: null')
  else
  begin
    WriteLn('  FAIL: type=', R.ValueType, ' err=', R.Error);
    Inc(Failed);
  end;

  WriteLn('=== Test 5: multi-call (10 iterations) ===');
  for I := 1 to 10 do
  begin
    R := ExecuteEngine('begin return ' + IntToStr(I * 100) + '; end.');
    if not (R.Success and (Abs(R.ValueAsNum - I * 100) < 0.001)) then
    begin
      WriteLn('  FAIL at iter ', I, ': type=', R.ValueType,
              ' num=', R.ValueAsNum, ' err=', R.Error);
      Inc(Failed);
      Break;
    end;
  end;
  if Failed = 0 then WriteLn('  PASS: 10 iterations');

  WriteLn('');
  if Failed = 0 then
  begin
    WriteLn('=== ALL PASS ===');
    Halt(0);
  end
  else
  begin
    WriteLn('=== ', Failed, ' TESTS FAILED ===');
    Halt(1);
  end;
end.
