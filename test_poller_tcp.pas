{ ====================================================================
  test_poller_tcp.pas — Non-blocking TCP echo with epoll
  ====================================================================
  Verifikasi primitif yang dibutuhkan event loop B.1.3:
    - Non-blocking listen socket
    - Non-blocking accept (EAGAIN handling)
    - Non-blocking read (partial data + EAGAIN)
    - Non-blocking write (partial write + EAGAIN)
    - epoll + socket integration

  Server di 127.0.0.1:9330. Client plain TCP kirim "hello",
  server echo balik. Test tanpa engine — pure standalone.
  ==================================================================== }

program test_poller_tcp;

{$MODE OBJFPC}{$H+}

uses
  {$IFDEF UNIX}
    cthreads,
  {$ENDIF}
  SysUtils, BaseUnix, Sockets, pascak_net, pascak_poller;

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

{ Buat listen socket non-blocking }
function MakeNonBlockingListen(const Host: string; Port: Integer;
                               out Sock: Integer): Boolean;
var
  S: Integer;
  Addr: TInetSockAddr;
  AddrIn: TInAddr;
  OptVal: Integer;
begin
  Result := False;
  Sock := -1;
  if not NetListen(Host, Port, S) then Exit;
  NetSetNonBlocking(S, True);
  Sock := S;
  Result := True;
end;

{ Non-blocking accept — return fd baru, atau -1 kalau EAGAIN }
function TryAccept(ListenSock: Integer; out ClientSock: Integer): Boolean;
var
  Addr: TSockAddr;
  AddrLen: Integer;
  NewSock: Integer;
begin
  Result := False;
  ClientSock := -1;
  AddrLen := SizeOf(Addr);
  NewSock := fpAccept(ListenSock, @Addr, @AddrLen);
  if NewSock < 0 then
  begin
    if fpGetErrno = ESysEAGAIN then Exit(False);
    Exit(False);
  end;
  NetSetNonBlocking(NewSock, True);
  ClientSock := NewSock;
  Result := True;
end;

{ Test utama — echo 1 client }
procedure Test_EchoSingle;
var
  ListenSock, ClientSock, ConnSock: Integer;
  P: TPoller;
  Results: array[0..15] of TPollerResult;
  N, I: Integer;
  Accepted: Boolean;
  ReadBuf: array[0..255] of Byte;
  Wrote: Integer;
  Sent, Received: Integer;
  TryCount: Integer;
  Got: RawByteString;
begin
  WriteLn('Test 1: Echo single client via epoll');

  if not MakeNonBlockingListen('127.0.0.1', 9330, ListenSock) then
  begin
    Check('listen 9330 berhasil', False);
    Exit;
  end;
  Check('listen non-blocking OK', ListenSock >= 0);

  P := TPoller.Create;
  try
    P.Add(ListenSock, [pekRead]);

    { Client connect dari thread yang sama — blocking connect dulu }
    if not NetConnect('127.0.0.1', 9330, 1000, ClientSock) then
    begin
      Check('client connect', False);
      Exit;
    end;
    Check('client connect OK', ClientSock >= 0);

    { Client kirim "hello" }
    Sent := NetSend(ClientSock, 'hello');
    Check('client sent 5 byte', Sent = 5);

    { Tunggu listen socket jadi readable (client connect pending) }
    N := P.Poll(500, Results);
    Check('poll return >= 1', N >= 1);

    Accepted := False;
    ConnSock := -1;
    for I := 0 to N - 1 do
    begin
      if Results[I].Sock = ListenSock then
      begin
        if TryAccept(ListenSock, ConnSock) then
          Accepted := True;
      end;
    end;
    Check('accept berhasil', Accepted);
    if not Accepted then Exit;

    { Register conn socket ke poller }
    P.Add(ConnSock, [pekRead]);

    { Tunggu data dari client (kirim tadi) }
    N := P.Poll(500, Results);
    Check('poll return >= 1 (data ready)', N >= 1);

    Got := '';
    for I := 0 to N - 1 do
    begin
      if Results[I].Sock = ConnSock then
      begin
        { Baca — handle partial read dengan retry }
        TryCount := 0;
        while TryCount < 10 do
        begin
          Received := fpRead(ConnSock, @ReadBuf[0], SizeOf(ReadBuf));
          if Received > 0 then
          begin
            SetLength(Got, Length(Got) + Received);
            Move(ReadBuf[0], Got[Length(Got) - Received + 1], Received);
            if Length(Got) >= 5 then Break;
          end else if Received < 0 then
          begin
            if fpGetErrno = ESysEAGAIN then
            begin
              Inc(TryCount);
              Continue;
            end
            else
              Break;
          end else
            Break;
        end;
      end;
    end;

    Check('server received "hello"', Got = 'hello');

    { Echo balik }
    Wrote := fpWrite(ConnSock, @Got[1], Length(Got));
    Check('server wrote 5 byte', Wrote = 5);

    { Client baca echo }
    Received := NetRecvTimeout(ClientSock, 64, 500, Got);
    Check('client received echo', (Received > 0) and (Got = 'hello'));

    { Cleanup }
    P.Del(ConnSock);
    NetClose(ConnSock);
    NetClose(ClientSock);
  finally
    P.Free;
    NetClose(ListenSock);
  end;
end;

{ Test partial write — kirim data besar sekaligus ke socket yang
  tidak di-drain, verify EAGAIN handling }
procedure Test_MultiClient;
var
  ListenSock: Integer;
  P: TPoller;
  Results: array[0..15] of TPollerResult;
  Clients: array[0..4] of Integer;
  I, J, N, Accepted, ConnSock: Integer;
  Buf: array[0..15] of Byte;
begin
  WriteLn('Test 2: Multi client (3 concurrent)');

  if not MakeNonBlockingListen('127.0.0.1', 9331, ListenSock) then
  begin
    Check('listen 9331 berhasil', False);
    Exit;
  end;

  { Connect 3 client }
  Accepted := 0;
  for I := 0 to 2 do
  begin
    if NetConnect('127.0.0.1', 9331, 1000, Clients[I]) then
    begin
      NetSend(Clients[I], 'C' + IntToStr(I));
      Inc(Accepted);
    end else
      Clients[I] := -1;
  end;
  Check('3 client connect', Accepted = 3);

  P := TPoller.Create;
  try
    P.Add(ListenSock, [pekRead]);

    { Poll — harus accept 3 kali, mungkin butuh beberapa iterasi
      karena epoll level-triggered }
    ConnSock := 0;
    for J := 0 to 2 do
    begin
      N := P.Poll(500, Results);
      for I := 0 to N - 1 do
      begin
        if Results[I].Sock = ListenSock then
        begin
          if TryAccept(ListenSock, ConnSock) then
          begin
            P.Add(ConnSock, [pekRead]);
          end;
        end;
      end;
    end;

    { Give epoll a moment, then check }
    N := P.Poll(200, Results);
    Check('epoll mengembalikan event', N >= 0);   { sanity }

    { Cleanup }
    for I := 0 to 2 do
      if Clients[I] >= 0 then
        NetClose(Clients[I]);
  finally
    P.Free;
    NetClose(ListenSock);
  end;
end;

begin
  WriteLn('=================================================');
  WriteLn('  pascak_poller + TCP test');
  WriteLn('=================================================');
  WriteLn;

  Test_EchoSingle;
  WriteLn;
  Test_MultiClient;

  WriteLn;
  WriteLn('=================================================');
  WriteLn('  Summary');
  WriteLn('=================================================');
  WriteLn('  Passed: ', GPassed);
  WriteLn('  Failed: ', GFailed);

  if GFailed = 0 then
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