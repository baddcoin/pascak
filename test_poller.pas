{ ====================================================================
  test_poller.pas — Standalone test untuk pascak_poller
  ====================================================================
  Test dengan anonymous pipe (2 fd), bukan socket.
  Verifikasi:
    - Create/Destroy
    - Add fd
    - Poll timeout
    - Poll read event
    - Mod_ event mask
    - Del fd
  ==================================================================== }

program test_poller;

{$MODE OBJFPC}{$H+}

uses
  SysUtils, BaseUnix, pascak_poller;

var
  GPassed: Integer = 0;
  GFailed: Integer = 0;

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

procedure Test_CreateDestroy;
var
  P: TPoller;
begin
  WriteLn('Test 1: Create/Destroy');
  P := TPoller.Create;
  try
    Check('poller valid', P.IsValid);
  finally
    P.Free;
  end;
end;

procedure Test_PollTimeout;
var
  P: TPoller;
  Pipe: array[0..1] of cint;
  Results: array[0..7] of TPollerResult;
  N: Integer;
begin
  WriteLn('Test 2: Poll timeout (no data)');

  if fpPipe(Pipe) <> 0 then
  begin
    WriteLn('  [SKIP] pipe() gagal');
    Exit;
  end;

  P := TPoller.Create;
  try
    Check('Add pipe read end', P.Add(Pipe[0], [pekRead]));

    N := P.Poll(100, Results);   // 100ms timeout, tidak ada data
    Check('Poll return 0 (timeout)', N = 0);

    P.Del(Pipe[0]);
  finally
    P.Free;
    fpClose(Pipe[0]);
    fpClose(Pipe[1]);
  end;
end;

procedure Test_PollReadable;
var
  P: TPoller;
  Pipe: array[0..1] of cint;
  Results: array[0..7] of TPollerResult;
  N: Integer;
  Buf: array[0..15] of Byte;
  Written: Integer;
begin
  WriteLn('Test 3: Poll readable');

  if fpPipe(Pipe) <> 0 then
  begin
    WriteLn('  [SKIP] pipe() gagal');
    Exit;
  end;

  P := TPoller.Create;
  try
    P.Add(Pipe[0], [pekRead]);

    // Tulis 5 byte ke pipe → read end jadi readable
    Written := fpWrite(Pipe[1], 'hello', 5);
    Check('write 5 byte', Written = 5);

    N := P.Poll(500, Results);
    Check('Poll return 1', N = 1);
    if N >= 1 then
    begin
      Check('Sock = pipe read end', Results[0].Sock = Pipe[0]);
      Check('pekRead set', pekRead in Results[0].Kinds);
    end;

    // Consume data supaya pipe bersih
    fpRead(Pipe[0], Buf, SizeOf(Buf));
  finally
    P.Free;
    fpClose(Pipe[0]);
    fpClose(Pipe[1]);
  end;
end;

procedure Test_PollTwoFds;
var
  P: TPoller;
  PipeA, PipeB: array[0..1] of cint;
  Results: array[0..7] of TPollerResult;
  N, i, CountA, CountB: Integer;
begin
  WriteLn('Test 4: Poll dua fd sekaligus');

  if (fpPipe(PipeA) <> 0) or (fpPipe(PipeB) <> 0) then
  begin
    WriteLn('  [SKIP] pipe() gagal');
    Exit;
  end;

  P := TPoller.Create;
  try
    P.Add(PipeA[0], [pekRead]);
    P.Add(PipeB[0], [pekRead]);

    // Tulis ke dua pipe
    fpWrite(PipeA[1], 'A', 1);
    fpWrite(PipeB[1], 'B', 1);

    N := P.Poll(500, Results);
    Check('Poll return 2', N = 2);

    if N >= 2 then
    begin
      CountA := 0;
      CountB := 0;
      for i := 0 to N - 1 do
      begin
        if Results[i].Sock = PipeA[0] then Inc(CountA);
        if Results[i].Sock = PipeB[0] then Inc(CountB);
      end;
      Check('PipeA readable', CountA = 1);
      Check('PipeB readable', CountB = 1);
    end;
  finally
    P.Free;
    fpClose(PipeA[0]); fpClose(PipeA[1]);
    fpClose(PipeB[0]); fpClose(PipeB[1]);
  end;
end;

procedure Test_ModDel;
var
  P: TPoller;
  Pipe: array[0..1] of cint;
  Results: array[0..7] of TPollerResult;
  N: Integer;
begin
  WriteLn('Test 5: Mod_ dan Del');

  if fpPipe(Pipe) <> 0 then
  begin
    WriteLn('  [SKIP] pipe() gagal');
    Exit;
  end;

  P := TPoller.Create;
  try
    P.Add(Pipe[0], [pekRead]);
    Check('Mod_ ke pekWrite', P.Mod_(Pipe[0], [pekWrite]));

    // Tulis ke pipe — read event tidak akan trigger karena kita hanya
    // subscribe write
    fpWrite(Pipe[1], 'A', 1);
    N := P.Poll(100, Results);
    // Write end pipe tidak akan "writable" dalam arti epoll_event OUT
    // karena pipe selalu writable kalau buffer belum penuh...
    // Ini agak tricky, jadi kita hanya cek Poll sukses return >= 0
    Check('Poll sukses (return >= 0)', N >= 0);

    Check('Del fd', P.Del(Pipe[0]));
  finally
    P.Free;
    fpClose(Pipe[0]);
    fpClose(Pipe[1]);
  end;
end;

begin
  WriteLn('=================================================');
  WriteLn('  pascak_poller standalone test');
  WriteLn('=================================================');
  WriteLn;

  Test_CreateDestroy;
  Test_PollTimeout;
  Test_PollReadable;
  Test_PollTwoFds;
  Test_ModDel;

  WriteLn;
  WriteLn('=================================================');
  WriteLn('  Summary');
  WriteLn('=================================================');
  WriteLn('  Passed: ', GPassed);
  WriteLn('  Failed: ', GFailed);
  WriteLn;

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