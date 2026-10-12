unit pascak_net;

{$MODE OBJFPC}{$H+}

interface

uses
  {$IFDEF UNIX} cthreads, baseunix, {$IFDEF LINUX} linux, {$ENDIF} errors, {$ENDIF}
  {$IFDEF WINDOWS} winsock2, {$ENDIF}
  Classes, SysUtils, contnrs, syncobjs, dynlibs,
  sockets, ssockets, fphttpclient, 
  opensslsockets, openssl, base64, sha1,
  StrUtils;
  
type
  ENetError = class(Exception);

const
  NET_RECV_ERR     = -1;   // error atau timeout
  NET_RECV_CLOSED  = 0;    // peer menutup koneksi
  NET_SEND_ERR     = -1;

  NET_DEFAULT_BACKLOG = 128;
  NET_MAX_RECV_BYTES  = 1048576;   // 1 MB (sesuai strMax)
  NET_CONNECT_TIMEOUT = 5000;      // 5 detik default

// ─── Lifecycle ───
procedure NetInit;
procedure NetShutdown;

// ─── Server ───
function NetListen(const Host: string; Port: Integer; out Sock: Integer): Boolean;
function NetAcceptTimeout(ServerSock: Integer; TimeoutMs: Integer;
          out ClientSock: Integer): Boolean;

// ─── Client ───
function NetConnect(const Host: string; Port: Integer; TimeoutMs: Integer;
          out Sock: Integer): Boolean;

// ─── I/O ───
function NetSend(Sock: Integer; const Data: RawByteString): Integer;
function NetRecv(Sock: Integer; MaxBytes: Integer;
          out Data: RawByteString): Integer;
function NetRecvTimeout(Sock: Integer; MaxBytes, TimeoutMs: Integer;
          out Data: RawByteString): Integer;

// ─── Utility ───
procedure NetClose(Sock: Integer);
function NetIsOpen(Sock: Integer): Boolean;
procedure NetSetNoDelay(Sock: Integer; Enabled: Boolean);
procedure NetSetNonBlocking(Sock: Integer; Enabled: Boolean);
function NetPeerIP(Sock: Integer): string;
function NetPeerPort(Sock: Integer): Integer;

function NetLastError: string;

// ✅ Diagnostik resolver — kembalikan string status untuk debug
function NetDiagnoseDNS(const Host: string): string;

implementation

type
  PSockEntry = ^TSockEntry;
  TSockEntry = record
    Handle: Integer;
  end;

{$IFDEF UNIX}
// ═══════════════════════════════════════════════════════════════════
//  DNS resolver via libc runtime-loaded.
//
//  Kenapa runtime-load dan bukan `external 'c'`?
//  - FPC aarch64 Android build punya masalah binding `external 'c'`.
//  - Runtime LoadLibrary + GetProcAddress selalu bisa resolve.
//  - Portabel: Android Bionic (libc.so) & Linux glibc (libc.so.6).
// ═══════════════════════════════════════════════════════════════════
type
  PLibcHostEnt = ^TLibcHostEnt;
  TLibcHostEnt = record
    h_name: PAnsiChar;
    h_aliases: ^PAnsiChar;
    h_addrtype: cint;
    h_length: cint;
    h_addr_list: ^PAnsiChar;
  end;
  
  // addrinfo POSIX layout — ai_addrlen adalah socklen_t (4 byte di Linux
  // dan Bionic). Perhatikan: BUKAN size_t/NativeUInt!
  PLibcAddrinfo = ^TLibcAddrinfo;
  TLibcAddrinfo = record
    ai_flags: cint;
    ai_family: cint;
    ai_socktype: cint;
    ai_protocol: cint;
    ai_addrlen: Cardinal;      // socklen_t
    ai_addr: Pointer;
    ai_canonname: PAnsiChar;
    ai_next: Pointer;
  end;

  TSetEnv       = function(name, value: PAnsiChar; overwrite: Integer): Integer; cdecl;
  TGetHostByName = function(name: PAnsiChar): PLibcHostEnt; cdecl;
  TGetAddrInfo  = function(node, service: PAnsiChar; hints: Pointer;
                           res: PPointer): cint; cdecl;
  TFreeAddrInfo = procedure(res: Pointer); cdecl;

var
  GLibC: TLibHandle = NilHandle;
  GResolveLock: TCriticalSection = nil;
  GResolveInitGuard: TCriticalSection = nil;
  GDNSQueryCounter: LongInt = 0;
  GpSetEnv: TSetEnv = nil;
  GpGetHostByName: TGetHostByName = nil;
  GpGetAddrInfo: TGetAddrInfo = nil;
  GpFreeAddrInfo: TFreeAddrInfo = nil;

procedure EnsureLibCLoaded;
begin
  // ✅ Fast path — sudah pernah init
  if Assigned(GResolveLock) and (GLibC <> NilHandle) then Exit;
  
  // Race-safe lazy init untuk lock dan library
  if not Assigned(GResolveInitGuard) then
    GResolveInitGuard := TCriticalSection.Create;
  
  GResolveInitGuard.Acquire;
  try
    if not Assigned(GResolveLock) then
      GResolveLock := TCriticalSection.Create;
  finally
    GResolveInitGuard.Release;
  end;  
  
  GResolveLock.Acquire;
  try
    if GLibC <> NilHandle then Exit;
    
    // Coba beberapa path — Android vs Linux
    GLibC := LoadLibrary('libc.so');
    if GLibC = NilHandle then
      GLibC := LoadLibrary('libc.so.6');
    if GLibC = NilHandle then
      GLibC := LoadLibrary('/system/lib64/libc.so');
    if GLibC = NilHandle then
      GLibC := LoadLibrary('/apex/com.android.runtime/lib64/bionic/libc.so');
    if GLibC = NilHandle then
      GLibC := LoadLibrary('c');
    
    if GLibC = NilHandle then Exit;
    
    Pointer(GpSetEnv)       := GetProcAddress(GLibC, 'setenv');
    Pointer(GpGetHostByName):= GetProcAddress(GLibC, 'gethostbyname');
    Pointer(GpGetAddrInfo)  := GetProcAddress(GLibC, 'getaddrinfo');
    Pointer(GpFreeAddrInfo) := GetProcAddress(GLibC, 'freeaddrinfo');
  finally
    GResolveLock.Release;
  end;
end;
{$ENDIF}

var
  GInitCount: Integer;
  GInitLock: TCriticalSection;
  GOpenSockets: TList;      // of PSockEntry
  GSockLock: TCriticalSection;
  GLastError: string;
  GLastErrorLock: TCriticalSection;
  E: PSockEntry;

procedure SetLastError(const Msg: string);
begin
  if Assigned(GLastErrorLock) then
  begin
    GLastErrorLock.Acquire;
    try GLastError := Msg;
    finally GLastErrorLock.Release;
    end;
  end;
end;

procedure NetInit;
begin
  {$IFDEF UNIX}
  EnsureLibCLoaded;
  
  // ✅ DNS fix: set ANDROID_DNS_MODE=local agar Bionic resolver
  // membaca /etc/resolv.conf langsung, bukan coba akses dnsproxyd
  // yang tidak accessible dari Termux namespace.
  if GetEnvironmentVariable('ANDROID_DNS_MODE') = '' then
  begin
    if Assigned(GpSetEnv) then
      GpSetEnv('ANDROID_DNS_MODE', 'local', 0);
  end;
  {$ENDIF}
  
  if not Assigned(GInitLock) then
  begin
    GInitLock := TCriticalSection.Create;
    GSockLock := TCriticalSection.Create;
    GLastErrorLock := TCriticalSection.Create;
    GOpenSockets := TList.Create;
  end;
  
  GInitLock.Acquire;
  try
    if GInitCount = 0 then
    begin
      {$IFDEF WINDOWS}
      var WSAData: TWSAData;
      if WSAStartup($0202, WSAData) <> 0 then
        raise ENetError.Create('WSAStartup gagal — Winsock tidak tersedia');
      {$ENDIF}
    end;
    Inc(GInitCount);
  finally
    GInitLock.Release;
  end;
end;

procedure NetShutdown;
begin
  if not Assigned(GInitLock) then Exit;
  
  GInitLock.Acquire;
  try
    if GInitCount = 0 then Exit;
    Dec(GInitCount);
    if GInitCount = 0 then
    begin
      if Assigned(GSockLock) then
      begin
        GSockLock.Acquire;
        try
          while GOpenSockets.Count > 0 do
          begin
            E := PSockEntry(GOpenSockets[GOpenSockets.Count - 1]);
            GOpenSockets.Delete(GOpenSockets.Count - 1);
            if Assigned(E) then
            begin
              CloseSocket(E^.Handle);
              Dispose(E);
            end;
          end;
        finally
          GSockLock.Release;
        end;
      end;
      
      {$IFDEF WINDOWS}
      WSACleanup;
      {$ENDIF}
    end;
  finally
    GInitLock.Release;
  end;
end;

procedure RegisterSocket(Sock: Integer);
begin
  if not Assigned(GOpenSockets) then Exit;
  New(E);
  E^.Handle := Sock;
  GSockLock.Acquire;
  try GOpenSockets.Add(E);
  finally GSockLock.Release;
  end;
end;

procedure UnregisterSocket(Sock: Integer);
var i: Integer; 
begin
  if not Assigned(GOpenSockets) then Exit;
  GSockLock.Acquire;
  try
    for i := 0 to GOpenSockets.Count - 1 do
    begin
      E := PSockEntry(GOpenSockets[i]);
      if Assigned(E) and (E^.Handle = Sock) then
      begin
        GOpenSockets.Delete(i);
        Dispose(E);
        Break;
      end;
    end;
  finally GSockLock.Release;
  end;
end;

// ────────────────────────────────────────────────────────────────
// IPv4 literal parser (dipakai untuk IP langsung)
// ────────────────────────────────────────────────────────────────
function ParseIPv4Literal(const S: string; out Addr: TInAddr): Boolean;
var
  Parts: array[0..3] of Integer;
  PartIdx, Val, DigitCount: Integer;
  C: Char;
  Accumulating: Boolean;
begin
  Result := False;
  FillChar(Addr, SizeOf(Addr), 0);
  
  PartIdx := 0;
  Val := 0;
  DigitCount := 0;
  Accumulating := False;
  
  for C in S do
  begin
    if (C >= '0') and (C <= '9') then
    begin
      Val := Val * 10 + (Ord(C) - Ord('0'));
      Inc(DigitCount);
      Accumulating := True;
      
      if (DigitCount > 3) or (Val > 255) then Exit;
    end
    else if C = '.' then
    begin
      if not Accumulating then Exit;
      if PartIdx >= 3 then Exit;
      
      Parts[PartIdx] := Val;
      Inc(PartIdx);
      Val := 0;
      DigitCount := 0;
      Accumulating := False;
    end
    else
      Exit;
  end;
  
  if not Accumulating then Exit;
  if PartIdx <> 3 then Exit;
  Parts[3] := Val;
  
  {$IFDEF ENDIAN_LITTLE}
  Addr.s_addr := (Cardinal(Parts[0]) shl 0)
              or (Cardinal(Parts[1]) shl 8)
              or (Cardinal(Parts[2]) shl 16)
              or (Cardinal(Parts[3]) shl 24);
  {$ELSE}
  Addr.s_addr := (Cardinal(Parts[0]) shl 24)
              or (Cardinal(Parts[1]) shl 16)
              or (Cardinal(Parts[2]) shl 8)
              or (Cardinal(Parts[3]) shl 0);
  {$ENDIF}
  Result := True;
end;

// ────────────────────────────────────────────────────────────────
// DNS resolver — 2 lapis: getaddrinfo (modern) → gethostbyname (legacy)
// ────────────────────────────────────────────────────────────────
function ReadResolvConfNameservers(var Servers: array of string): Integer;
var
  F: TextFile;
  Line, Trimmed, NSStr: string;
  Count, i: Integer;
  Paths: array[0..4] of string;
  Assigned_: Boolean;
begin
  Count := 0;
  Paths[0] := '/etc/resolv.conf';
  Paths[1] := '/data/data/com.termux/files/usr/etc/resolv.conf';
  Paths[2] := '/system/etc/resolv.conf';
  Paths[3] := '/data/misc/dhcp/dns.conf';
  Paths[4] := GetEnvironmentVariable('PREFIX') + '/etc/resolv.conf';

  for i := Low(Paths) to High(Paths) do
  begin
    if Paths[i] = '' then Continue;
    if not FileExists(Paths[i]) then Continue;

    Assigned_ := False;
    {$I-}
    AssignFile(F, Paths[i]);
    Reset(F);
    if IOResult <> 0 then Continue;
    Assigned_ := True;

    while (not EOF(F)) and (Count < Length(Servers)) do
    begin
      ReadLn(F, Line);
      Trimmed := Trim(Line);
      if (Length(Trimmed) > 11) and
         (Copy(LowerCase(Trimmed), 1, 11) = 'nameserver ') then
      begin
        NSStr := Trim(Copy(Trimmed, 12, Length(Trimmed)));
        // Skip IPv6 untuk sekarang (kita IPv4 only)
        if (Pos(':', NSStr) = 0) and (NSStr <> '') then
        begin
          Servers[Count] := NSStr;
          Inc(Count);
        end;
      end;
    end;

    if Assigned_ then CloseFile(F);
    {$I+}
    if Count > 0 then Break;
  end;

  // Fallback public DNS
  if Count = 0 then
  begin
    if Length(Servers) > 0 then begin Servers[0] := '8.8.8.8'; Inc(Count); end;
    if Length(Servers) > 1 then begin Servers[1] := '1.1.1.1'; Inc(Count); end;
  end;

  Result := Count;
end;

function EncodeDNSName(const Host: string): RawByteString;
var
  i, Start, LabelLen: Integer;
begin
  Result := '';
  Start := 1;
  for i := 1 to Length(Host) do
  begin
    if (Host[i] = '.') or (i = Length(Host)) then
    begin
      if i = Length(Host) then
        LabelLen := i - Start + 1
      else
        LabelLen := i - Start;

      if LabelLen > 63 then Exit('');
      if LabelLen > 0 then
      begin
        SetLength(Result, Length(Result) + 1);
        Result[Length(Result)] := Char(LabelLen);
        Result := Result + Copy(Host, Start, LabelLen);
      end;
      Start := i + 1;
    end;
  end;
  // Terminating zero
  SetLength(Result, Length(Result) + 1);
  Result[Length(Result)] := #0;
end;

function PureDNSResolve(const Host: string; out Addr: TInAddr): Boolean;
var
  Query, QName: RawByteString;
  Servers: array[0..7] of string;
  ServerCount, i: Integer;
  ServerAddr: TInAddr;
  UDPSock: Integer;
  ServerSockAddr: TInetSockAddr;
  SendBytes, RecvBytes: Integer;
  RcvBuf: array[0..511] of Byte;
  TV: TTimeVal;
  FDS: TFDSet;
  SelRes: Integer;
  QueryID: Word;
  AnsCount: Integer;
  P: Integer;
  LabelLen: Integer;
  RecType, RecClass, RDLen: Word;
  AnswerIP: TInAddr;
begin
  Result := False;

  ServerCount := ReadResolvConfNameservers(Servers);
  if ServerCount = 0 then Exit;

  QName := EncodeDNSName(Host);
  if QName = '' then Exit;

  // Build query (12 byte header + QNAME + 4 byte question tail)
  QueryID := Word(InterlockedIncrement(GDNSQueryCounter));
  if QueryID = 0 then
    QueryID := 1;  
  
  SetLength(Query, 12 + Length(QName) + 4);
  Query[1]  := Char(QueryID shr 8);
  Query[2]  := Char(QueryID and $FF);
  Query[3]  := #$01;   // Flags: RD=1 (recursion desired)
  Query[4]  := #$00;
  Query[5]  := #$00;   // QDCOUNT
  Query[6]  := #$01;
  Query[7]  := #$00;   // ANCOUNT
  Query[8]  := #$00;
  Query[9]  := #$00;   // NSCOUNT
  Query[10] := #$00;
  Query[11] := #$00;   // ARCOUNT
  Query[12] := #$00;
  Move(QName[1], Query[13], Length(QName));
  P := 12 + Length(QName);
  Query[P+1] := #$00;  // QTYPE = 1 (A)
  Query[P+2] := #$01;
  Query[P+3] := #$00;  // QCLASS = 1 (IN)
  Query[P+4] := #$01;

  for i := 0 to ServerCount - 1 do
  begin
    if not ParseIPv4Literal(Servers[i], ServerAddr) then Continue;

    UDPSock := fpSocket(AF_INET, SOCK_DGRAM, 0);
    if UDPSock < 0 then Continue;

    try
      FillChar(ServerSockAddr, SizeOf(ServerSockAddr), 0);
      ServerSockAddr.sin_family := AF_INET;
      ServerSockAddr.sin_port   := htons(53);
      ServerSockAddr.sin_addr   := ServerAddr;

      SendBytes := fpSendTo(UDPSock, @Query[1], Length(Query), 0,
                            @ServerSockAddr, SizeOf(ServerSockAddr));
      if SendBytes <> Length(Query) then Continue;

      // Wait response, 3s timeout
      fpFD_ZERO(FDS);
      fpFD_SET(UDPSock, FDS);
      TV.tv_sec  := 3;
      TV.tv_usec := 0;
      SelRes := fpSelect(UDPSock + 1, @FDS, nil, nil, @TV);
      if SelRes <= 0 then Continue;

      RecvBytes := fpRecv(UDPSock, @RcvBuf[0], SizeOf(RcvBuf), 0);
      if RecvBytes < 12 then Continue;

      // Verify ID
      if (Byte(RcvBuf[0]) <> (QueryID shr 8)) or
         (Byte(RcvBuf[1]) <> (QueryID and $FF)) then Continue;

      // QR bit set + rcode == 0
      if (RcvBuf[2] and $80) = 0 then Continue;
      if (RcvBuf[3] and $0F) <> 0 then Continue;

      AnsCount := (Byte(RcvBuf[6]) shl 8) or Byte(RcvBuf[7]);
      if AnsCount = 0 then Continue;

      // Skip question section
      P := 12;
      while P < RecvBytes do
      begin
        LabelLen := RcvBuf[P];
        Inc(P);
        if LabelLen = 0 then Break;
        if (LabelLen and $C0) = $C0 then
        begin
          Inc(P);
          Break;
        end;
        Inc(P, LabelLen);
      end;
      Inc(P, 4);   // skip QTYPE + QCLASS

      // Parse answers
      while (P < RecvBytes) and (AnsCount > 0) do
      begin
        // Skip name (handle compression pointer)
        while P < RecvBytes do
        begin
          LabelLen := RcvBuf[P];
          if LabelLen = 0 then begin Inc(P); Break; end;
          if (LabelLen and $C0) = $C0 then
          begin
            Inc(P, 2);
            Break;
          end;
          Inc(P, 1 + LabelLen);
        end;

        if P + 10 > RecvBytes then Break;

        RecType  := (RcvBuf[P] shl 8) or RcvBuf[P+1]; Inc(P, 2);
        RecClass := (RcvBuf[P] shl 8) or RcvBuf[P+1]; Inc(P, 2);
        Inc(P, 4);   // skip TTL
        RDLen    := (RcvBuf[P] shl 8) or RcvBuf[P+1]; Inc(P, 2);

        if (RecType = 1) and (RecClass = 1) and (RDLen = 4) then
        begin
          Move(RcvBuf[P], AnswerIP.s_addr, 4);
          Addr := AnswerIP;
          Exit(True);
        end;

        Inc(P, RDLen);
        Dec(AnsCount);
      end;
    finally
      CloseSocket(UDPSock);
    end;
  end;
end;

function ResolveIPv4(const Host: string; out Addr: TInAddr): Boolean;
var
  HostLower: string;
  {$IFDEF UNIX}
  HE: PLibcHostEnt;
  AddrList: ^PAnsiChar;
  FirstAddrPtr: PAnsiChar;
  Hints: TLibcAddrinfo;
  RawRes: Pointer;
  Rc: cint;
  SinAddr: PInetSockAddr;
  {$ENDIF}
begin
  Result := False;
  FillChar(Addr, SizeOf(Addr), 0);
  
  HostLower := LowerCase(Trim(Host));
  
  // ─── Special cases ───
  if (HostLower = '') or (HostLower = '*') or (HostLower = 'any') then
  begin
    Addr.s_addr := 0;   // INADDR_ANY
    Exit(True);
  end;
  
  if HostLower = 'localhost' then
  begin
    {$IFDEF ENDIAN_LITTLE}
    Addr.s_addr := $0100007F;
    {$ELSE}
    Addr.s_addr := $7F000001;
    {$ENDIF}
    Exit(True);
  end;
  
  // ─── IP literal ───
  if ParseIPv4Literal(HostLower, Addr) then
    Exit(True);
  
  {$IFDEF UNIX}
  EnsureLibCLoaded;
  
  if GLibC = NilHandle then
  begin
    SetLastError('libc tidak dapat di-load untuk DNS resolution');
    Exit(False);
  end;
  
  // ═══════════════════════════════════════════════════════════════
  // Lapis 1: getaddrinfo (modern, recomended)
  // ═══════════════════════════════════════════════════════════════
  if Assigned(GpGetAddrInfo) then
  begin
    FillChar(Hints, SizeOf(Hints), 0);
    Hints.ai_family   := AF_INET;
    Hints.ai_socktype := SOCK_STREAM;
    
    RawRes := nil;
    Rc := GpGetAddrInfo(PAnsiChar(AnsiString(Host)), nil, @Hints, @RawRes);
    if (Rc = 0) and (RawRes <> nil) then
    begin
      try
        if PLibcAddrinfo(RawRes)^.ai_addr <> nil then
        begin
          SinAddr := PInetSockAddr(PLibcAddrinfo(RawRes)^.ai_addr);
          Addr := SinAddr^.sin_addr;
          SetLastError('');
          Exit(True);
        end;
      finally
        if Assigned(GpFreeAddrInfo) then
          GpFreeAddrInfo(RawRes);
      end;
    end;
  end;
  
  // ═══════════════════════════════════════════════════════════════
  // Lapis 2: gethostbyname (legacy, fallback)
  // ═══════════════════════════════════════════════════════════════
  if Assigned(GpGetHostByName) then
  begin
    HE := GpGetHostByName(PAnsiChar(AnsiString(Host)));
    if (HE <> nil) and (HE^.h_addrtype = AF_INET) and 
       (HE^.h_length = 4) and (HE^.h_addr_list <> nil) then
    begin
      AddrList := HE^.h_addr_list;
      FirstAddrPtr := AddrList^;
      if FirstAddrPtr <> nil then
      begin
        Move(FirstAddrPtr^, Addr.s_addr, 4);
        SetLastError('');
        Exit(True);
      end;
    end;
  end;
  {$ENDIF}
  
  if PureDNSResolve(Host, Addr) then
  begin
    SetLastError('');
    Exit(True);
  end;

  SetLastError('host tidak dapat di-resolve: ' + Host);
  Result := False;
end;

// ────────────────────────────────────────────────────────────────
// Listen
// ────────────────────────────────────────────────────────────────
function NetListen(const Host: string; Port: Integer; out Sock: Integer): Boolean;
var
  ServerSock: Integer;
  Addr: TInetSockAddr;
  AddrIn: TInAddr;
  OptVal: Integer;
begin
  Result := False;
  Sock := -1;
  
  if (Port < 1) or (Port > 65535) then
  begin
    SetLastError('port tidak valid (harus 1..65535)');
    Exit;
  end;
  
  if not ResolveIPv4(Host, AddrIn) then
  begin
    SetLastError('host tidak dapat di-resolve: ' + Host);
    Exit;
  end;
  
  ServerSock := fpSocket(AF_INET, SOCK_STREAM, 0);
  if ServerSock < 0 then
  begin
    SetLastError('fpSocket gagal');
    Exit;
  end;
  
  OptVal := 1;
  fpSetSockOpt(ServerSock, SOL_SOCKET, SO_REUSEADDR, @OptVal, SizeOf(OptVal));
  
  FillChar(Addr, SizeOf(Addr), 0);
  Addr.sin_family := AF_INET;
  Addr.sin_port := htons(Port);
  Addr.sin_addr := AddrIn;
  
  if fpBind(ServerSock, @Addr, SizeOf(Addr)) <> 0 then
  begin
    SetLastError('bind gagal pada port ' + IntToStr(Port));
    CloseSocket(ServerSock);
    Exit;
  end;
  
  if fpListen(ServerSock, NET_DEFAULT_BACKLOG) <> 0 then
  begin
    SetLastError('listen gagal');
    CloseSocket(ServerSock);
    Exit;
  end;
  
  RegisterSocket(ServerSock);
  Sock := ServerSock;
  Result := True;
  SetLastError('');
end;

// ────────────────────────────────────────────────────────────────
// Accept dengan timeout
// ────────────────────────────────────────────────────────────────
function NetAcceptTimeout(ServerSock: Integer; TimeoutMs: Integer;
                          out ClientSock: Integer): Boolean;
var
  Addr: TSockAddr;
  AddrLen: Integer;
  NewSock: Integer;
  FDS: TFDSet;
  TV: TTimeVal;
  SelRes: Integer;
begin
  Result := False;
  ClientSock := -1;
  
  if TimeoutMs > 0 then
  begin
    {$IFDEF UNIX}
    fpFD_ZERO(FDS);
    fpFD_SET(ServerSock, FDS);
    {$ENDIF}
    {$IFDEF WINDOWS}
    FDS.fd_count := 1;
    FDS.fd_array[0] := ServerSock;
    {$ENDIF}
    TV.tv_sec := TimeoutMs div 1000;
    TV.tv_usec := (TimeoutMs mod 1000) * 1000;
    
    {$IFDEF UNIX}
    SelRes := fpSelect(ServerSock + 1, @FDS, nil, nil, @TV);
    {$ENDIF}
    {$IFDEF WINDOWS}
    SelRes := WinSock2.select(0, @FDS, nil, nil, @TV);
    {$ENDIF}
    
    if SelRes = 0 then
    begin
      SetLastError('accept timeout');
      Exit;
    end;
    if SelRes < 0 then
    begin
      SetLastError('select gagal');
      Exit;
    end;
  end;
  
  AddrLen := SizeOf(Addr);
  NewSock := fpAccept(ServerSock, @Addr, @AddrLen);
  if NewSock < 0 then
  begin
    SetLastError('fpAccept gagal');
    Exit;
  end;
  
  RegisterSocket(NewSock);
  ClientSock := NewSock;
  Result := True;
  SetLastError('');
end;

// ────────────────────────────────────────────────────────────────
// Connect (blocking dengan timeout via SO_RCVTIMEO tidak dipakai)
// ────────────────────────────────────────────────────────────────
function NetConnect(const Host: string; Port: Integer; TimeoutMs: Integer;
  out Sock: Integer): Boolean;
var
  ClientSock: Integer;
  Addr: TInetSockAddr;
  AddrIn: TInAddr;
  R, ErrCode, Attempt: Integer;
begin
  Result := False;
  Sock := -1;
  
  if (Port < 1) or (Port > 65535) then
  begin
    SetLastError('port tidak valid');
    Exit;
  end;
  
  if not ResolveIPv4(Host, AddrIn) then
  begin
    SetLastError('host tidak dapat di-resolve: ' + Host);
    Exit;
  end;
  
  ClientSock := fpSocket(AF_INET, SOCK_STREAM, 0);
  if ClientSock < 0 then
  begin
    SetLastError('fpSocket gagal');
    Exit;
  end;
  
  FillChar(Addr, SizeOf(Addr), 0);
  Addr.sin_family := AF_INET;
  Addr.sin_port := htons(Port);
  Addr.sin_addr := AddrIn;
  
  // ✅ Retry loop untuk EINTR.
  // FPC Sockets menerjemahkan EINTR sebagai "Thread error" (generic) —
  // muncul di worker thread saat connect diinterupsi signal (SIGCHLD dari
  // subprocess, SIGIO dari socket lain, dsb). Retry immediately — pada
  // EINTR, koneksi TCP belum established, aman untuk ulang.
  R := -1;
  ErrCode := 0;
  for Attempt := 1 to 5 do
  begin
    R := fpConnect(ClientSock, @Addr, SizeOf(Addr));
    if R = 0 then Break;
    
    {$IFDEF UNIX}
    ErrCode := fpGetErrno;
    if ErrCode <> ESysEINTR then Break;
    {$ELSE}
    Break;
    {$ENDIF}
  end;
  
  if R <> 0 then
  begin
    SetLastError('connect gagal ke ' + Host + ':' + IntToStr(Port) +
                 ' (errno=' + IntToStr(ErrCode) + ')');
    CloseSocket(ClientSock);
    Exit;
  end;
  
  RegisterSocket(ClientSock);
  Sock := ClientSock;
  Result := True;
  SetLastError('');
end;

// ────────────────────────────────────────────────────────────────
// Send
// ────────────────────────────────────────────────────────────────
function NetSend(Sock: Integer; const Data: RawByteString): Integer;
var
  Total, Sent: Integer;
  P: PByte;
begin
  if Length(Data) = 0 then Exit(0);
  
  Total := 0;
  P := @Data[1];
  
  while Total < Length(Data) do
  begin
    Sent := fpSend(Sock, P, Length(Data) - Total, 0);
    if Sent <= 0 then
    begin
      SetLastError('send gagal setelah ' + IntToStr(Total) + ' byte');
      Exit(NET_SEND_ERR);
    end;
    Inc(Total, Sent);
    Inc(P, Sent);
  end;
  
  Result := Total;
end;

// ────────────────────────────────────────────────────────────────
// Recv (blocking)
// ────────────────────────────────────────────────────────────────
function NetRecv(Sock: Integer; MaxBytes: Integer;
                 out Data: RawByteString): Integer;
var
  Buf: array[0..65535] of Byte;
  Cap, R: Integer;
begin
  Data := '';
  
  Cap := MaxBytes;
  if Cap <= 0 then Cap := 4096;
  if Cap > SizeOf(Buf) then Cap := SizeOf(Buf);
  if Cap > NET_MAX_RECV_BYTES then Cap := NET_MAX_RECV_BYTES;
  
  R := fpRecv(Sock, @Buf[0], Cap, 0);
  if R < 0 then
  begin
    SetLastError('recv gagal');
    Exit(NET_RECV_ERR);
  end;
  if R = 0 then
    Exit(NET_RECV_CLOSED);
  
  SetLength(Data, R);
  Move(Buf[0], Data[1], R);
  Result := R;
end;

// ────────────────────────────────────────────────────────────────
// Recv dengan timeout
// ────────────────────────────────────────────────────────────────
function NetRecvTimeout(Sock: Integer; MaxBytes, TimeoutMs: Integer;
                        out Data: RawByteString): Integer;
var
  FDS: TFDSet;
  TV: TTimeVal;
  SelRes: Integer;
  Buf: array[0..65535] of Byte;
  Cap, R: Integer;
begin
  Data := '';
  SetLastError('');
  
  {$IFDEF UNIX}
  fpFD_ZERO(FDS);
  fpFD_SET(Sock, FDS);
  {$ENDIF}
  {$IFDEF WINDOWS}
  FDS.fd_count := 1;
  FDS.fd_array[0] := Sock;
  {$ENDIF}
  TV.tv_sec := TimeoutMs div 1000;
  TV.tv_usec := (TimeoutMs mod 1000) * 1000;
  
  {$IFDEF UNIX}
  SelRes := fpSelect(Sock + 1, @FDS, nil, nil, @TV);
  {$ENDIF}
  {$IFDEF WINDOWS}
  SelRes := WinSock2.select(0, @FDS, nil, nil, @TV);
  {$ENDIF}
  
  if SelRes = 0 then
  begin
    SetLastError('recv timeout');
    Exit(NET_RECV_ERR);
  end;
  if SelRes < 0 then
  begin
    SetLastError('select gagal');
    Exit(NET_RECV_ERR);
  end;
  
  Cap := MaxBytes;
  if Cap <= 0 then Cap := 4096;
  if Cap > SizeOf(Buf) then Cap := SizeOf(Buf);
  if Cap > NET_MAX_RECV_BYTES then Cap := NET_MAX_RECV_BYTES;
  
  R := fpRecv(Sock, @Buf[0], Cap, 0);
  if R < 0 then
  begin
    SetLastError('recv gagal');
    Exit(NET_RECV_ERR);
  end;
  if R = 0 then
    Exit(NET_RECV_CLOSED);
  
  SetLength(Data, R);
  Move(Buf[0], Data[1], R);
  Result := R;
end;

// ────────────────────────────────────────────────────────────────
// Close
// ────────────────────────────────────────────────────────────────
procedure NetClose(Sock: Integer);
begin
  if Sock < 0 then Exit;
  UnregisterSocket(Sock);
  CloseSocket(Sock);
end;

function NetIsOpen(Sock: Integer): Boolean;
var i: Integer; 
begin
  Result := False;
  if Sock < 0 then Exit;
  if not Assigned(GOpenSockets) then Exit;
  GSockLock.Acquire;
  try
    for i := 0 to GOpenSockets.Count - 1 do
    begin
      E := PSockEntry(GOpenSockets[i]);
      if Assigned(E) and (E^.Handle = Sock) then
        Exit(True);
    end;
  finally GSockLock.Release;
  end;
end;

procedure NetSetNoDelay(Sock: Integer; Enabled: Boolean);
var OptVal: Integer;
begin
  if Enabled then OptVal := 1 else OptVal := 0;
  fpSetSockOpt(Sock, IPPROTO_TCP, TCP_NODELAY, @OptVal, SizeOf(OptVal));
end;

procedure NetSetNonBlocking(Sock: Integer; Enabled: Boolean);
{$IFDEF UNIX}
var
  Flags: cint;
{$ENDIF}
begin
  {$IFDEF UNIX}
  Flags := fpFcntl(Sock, F_GETFL, 0);
  if Flags < 0 then Exit;
  if Enabled then
    Flags := Flags or O_NONBLOCK
  else
    Flags := Flags and (not O_NONBLOCK);
  fpFcntl(Sock, F_SETFL, Flags);
  {$ENDIF}
end;

function NetPeerIP(Sock: Integer): string;
var
  Addr: TSockAddr;
  AddrLen: Integer;
  InAddr: TInAddr;
begin
  Result := '';
  AddrLen := SizeOf(Addr);
  if fpGetPeerName(Sock, @Addr, @AddrLen) <> 0 then Exit;
  InAddr := TInetSockAddr(Addr).sin_addr;
  Result := NetAddrToStr(InAddr);
end;

function NetPeerPort(Sock: Integer): Integer;
var
  Addr: TSockAddr;
  AddrLen: Integer;
begin
  Result := 0;
  AddrLen := SizeOf(Addr);
  if fpGetPeerName(Sock, @Addr, @AddrLen) <> 0 then Exit;
  Result := ntohs(TInetSockAddr(Addr).sin_port);
end;

function NetLastError: string;
begin
  if Assigned(GLastErrorLock) then
  begin
    GLastErrorLock.Acquire;
    try Result := GLastError;
    finally GLastErrorLock.Release;
    end;
  end
  else Result := '';
end;

// ────────────────────────────────────────────────────────────────
// Diagnostik resolver
// ────────────────────────────────────────────────────────────────
function NetDiagnoseDNS(const Host: string): string;
{$IFDEF UNIX}
var
  Hints: TLibcAddrinfo;
  RawRes: Pointer;
  Res: PLibcAddrinfo;
  Rc: cint;
  HE: PLibcHostEnt;
  SinAddr: PInetSockAddr;
  Bytes: array[0..3] of Byte;
  IPStr: string;
{$ENDIF}
begin
  {$IFDEF UNIX}
  Result := 'Host: ' + Host + #10;
  Result := Result + 'ANDROID_DNS_MODE: [' + 
            GetEnvironmentVariable('ANDROID_DNS_MODE') + ']' + #10;
  
  EnsureLibCLoaded;
  
  Result := Result + 'libc handle: ' + IntToHex(PtrUInt(GLibC), 16) + #10;
  Result := Result + '  getaddrinfo    ptr: ' + IntToHex(PtrUInt(GpGetAddrInfo), 16) + #10;
  Result := Result + '  gethostbyname  ptr: ' + IntToHex(PtrUInt(GpGetHostByName), 16) + #10;
  Result := Result + '  setenv         ptr: ' + IntToHex(PtrUInt(GpSetEnv), 16) + #10;
  Result := Result + #10;
  
  // Coba getaddrinfo
  if Assigned(GpGetAddrInfo) then
  begin
    FillChar(Hints, SizeOf(Hints), 0);
    Hints.ai_family := AF_INET;
    Hints.ai_socktype := SOCK_STREAM;
    RawRes := nil;
    Rc := GpGetAddrInfo(PAnsiChar(AnsiString(Host)), nil, @Hints, @RawRes);
    Result := Result + 'getaddrinfo(' + Host + ') rc = ' + IntToStr(Rc) + #10;
    
    if (Rc = 0) and (RawRes <> nil) then
    begin
      Res := PLibcAddrinfo(RawRes);
      if Res^.ai_addr <> nil then
      begin
        SinAddr := PInetSockAddr(Res^.ai_addr);
        Move(SinAddr^.sin_addr, Bytes[0], 4);
        IPStr := Format('%d.%d.%d.%d', [Bytes[0], Bytes[1], Bytes[2], Bytes[3]]);
        Result := Result + '  → ' + IPStr + #10;
      end;
      if Assigned(GpFreeAddrInfo) then
        GpFreeAddrInfo(RawRes);
    end;
  end;
  Result := Result + #10;
  
  // Coba gethostbyname
  if Assigned(GpGetHostByName) then
  begin
    HE := GpGetHostByName(PAnsiChar(AnsiString(Host)));
    if HE = nil then
      Result := Result + 'gethostbyname(' + Host + ') = nil' + #10
    else
    begin
      Result := Result + 'gethostbyname(' + Host + ') = OK' + #10;
      Result := Result + '  h_addrtype = ' + IntToStr(HE^.h_addrtype) + #10;
      Result := Result + '  h_length   = ' + IntToStr(HE^.h_length) + #10;
    end;
  end;
  {$ELSE}
  Result := 'NetDiagnoseDNS hanya tersedia di Unix';
  {$ENDIF}
end;

initialization
  GInitCount := 0;
  GOpenSockets := nil;
  GInitLock := nil;
  GSockLock := nil;
  GLastErrorLock := nil;
  {$IFDEF UNIX}
  GResolveLock := nil;
  {$ENDIF}

finalization
  if Assigned(GOpenSockets) then
  begin
    while GOpenSockets.Count > 0 do
    begin
      E := PSockEntry(GOpenSockets[GOpenSockets.Count - 1]);
      GOpenSockets.Delete(GOpenSockets.Count - 1);
      if Assigned(E) then
      begin
        try CloseSocket(E^.Handle); except end;
        Dispose(E);
      end;
    end;
    GOpenSockets.Free;
  end;
  if Assigned(GInitLock) then GInitLock.Free;
  if Assigned(GSockLock) then GSockLock.Free;
  if Assigned(GLastErrorLock) then GLastErrorLock.Free;
  {$IFDEF UNIX}
  if Assigned(GResolveLock) then GResolveLock.Free;
  // ⚠️ JANGAN UnloadLibrary(GLibC) — sama seperti libssl/libffi,
  // biarkan OS reclaim saat exit untuk menghindari crash bila ada
  // resolver call yang masih hidup.
  {$ENDIF}

end.