{ ====================================================================
  pascak_wsevloop.pas — Non-blocking WebSocket event loop
  ====================================================================
  State machine + connection manager untuk WebSocket server model
  event-driven (epoll-based). Menggantikan model thread-per-connection
  untuk skala 10.000+ concurrent.

  Arsitektur:
    - TWSEventLoop: poller (epoll) + connection registry + server registry
    - TWSNBConn:  per-connection state (buffers, parser, timing)
    - Sink callbacks: engine hook via procedure-of-object pointer

  Dependensi:
    - pascak_poller:   epoll wrapper
    - pascak_websocket: frame parser + builder
    - pascak_http:     HTTP request parser
    - pascak_net:      NetPeerIP/NetPeerPort (untuk metadata)

  Tidak dependensi ke engine utama — pure socket + protocol layer.
  ==================================================================== }
unit pascak_wsevloop;

{$MODE OBJFPC}{$H+}

interface

uses
  {$IFDEF UNIX}
    cthreads,
  {$ENDIF}
  Classes, SysUtils, fgl, BaseUnix, Sockets,
  pascak_poller, pascak_websocket, pascak_http, 
  pascak_net, paszlib, pascak_tls;

type
  EWSEventLoopError = class(Exception);

  TNBSState = (
    nbsTLSHandshake, // B.2: TLS handshake in progress (server mode)
    nbsReadHTTP,     // menerima HTTP upgrade request
    nbsOpen,         // WS frame loop aktif
    nbsClosing,      // sudah kirim close frame, menunggu peer close
    nbsClosed        // siap dibebaskan
  );

  TNBSConnID = Int64;

  { Sink callbacks — engine hook }
  TNBSinkOnOpen = procedure(Ctx: Pointer; ConnID: TNBSConnID;
                            ConnHandle: Pointer) of object;
  TNBSinkOnMessage = procedure(Ctx: Pointer; ConnID: TNBSConnID;
                               const Payload: RawByteString) of object;
  TNBSinkOnClose = procedure(Ctx: Pointer; ConnID: TNBSConnID;
                             Code: Word) of object;

  { Server config — shared with engine }
  PNBServerConfig = ^TNBServerConfig;
  TNBServerConfig = record
    Handle: Integer;
    ListenSock: Integer;
    Subprotocols: TStringList;   // borrowed from engine, tidak di-free
    MaxPayloadBytes: Integer;
    PingIntervalMs: Integer;
    PongTimeoutMs: Integer;
    PingEnabled: Boolean;
    CompressionEnabled: Boolean;
    CompressionThreshold: Integer;
    SinkCtx: Pointer;            // opaque pointer ke engine context
    IsTLS: Boolean;              // B.1: harus False
    TLSContext: Pointer; 
  end;

  { Per-connection state }
  TWSNBConn = class
  public
    ID: TNBSConnID;
    Sock: Integer;
    ServerHandle: Integer;
    State: TNBSState;

    // I/O buffers
    ReadBuf: RawByteString;      // data yang sudah dibaca, belum diparse
    WriteBuf: RawByteString;     // data yang menunggu dikirim
    WantWrite: Boolean;          // true = registered untuk EPOLLOUT

    // WS frame parser
    Parser: TWSFrameParser;

    // Metadata HTTP (parsed saat handshake)
    Path: string;
    Query: string;
    Protocol: string;
    PeerIP: string;
    PeerPort: Integer;
    HeaderNames: TStringList;
    HeaderValues: TStringList;

    // Fragment accumulation
    FragActive: Boolean;
    FragOpcode: TWSOpcode;
    FragBuf: RawByteString;

    // Timing
    LastActivity: QWord;
    PendingPing: Boolean;
    PendingPingAt: QWord;

    // Compression
    CompressionNegotiated: Boolean;
    CompressionThreshold: Integer;

    // Server config pointer (borrowed)
    Config: PNBServerConfig;
    ClosingAt: QWord;

    // B.2: TLS
    TLSConn: TTLSConnection;      // owned, Free di Destroy
    TLSServerCtx: Pointer;         // borrowed, TLSServerContext*

    constructor Create(ASock: Integer; AConfig: PNBServerConfig);
    destructor Destroy; override;

    { Queue data untuk dikirim. Return True kalau perlu daftar EPOLLOUT. }
    function QueueWrite(const Data: RawByteString): Boolean;
  end;

  TWSEventLoop = class
  private
    FPoller: TPoller;
    FConns: specialize TFPGMap<Integer, TWSNBConn>;
    FServers: specialize TFPGMap<Integer, PNBServerConfig>;
    FListenSocks: specialize TFPGMap<Integer, PNBServerConfig>;  // B.1.4d: sock → cfg
    FNextConnID: TNBSConnID;    
    FRunning: Boolean;

    FOnOpen: TNBSinkOnOpen;
    FOnMessage: TNBSinkOnMessage;
    FOnClose: TNBSinkOnClose;

    FActiveConns: Integer;

    procedure HandleListenReadable(ListenSockFd: Integer);
    procedure HandleConnReadable(Conn: TWSNBConn);
    procedure HandleConnWritable(Conn: TWSNBConn);
    procedure UpdateEpollEvents(Conn: TWSNBConn);
    procedure CloseConn(Conn: TWSNBConn; Code: Word);
    procedure FreeConn(Conn: TWSNBConn);
    procedure CheckPingTimers;
  public
    constructor Create;
    destructor Destroy; override;

    procedure SetSink(OnOpen: TNBSinkOnOpen;
                      OnMessage: TNBSinkOnMessage;
                      OnClose: TNBSinkOnClose);

    function AddServer(Config: PNBServerConfig): Boolean;
    procedure RemoveServer(Handle: Integer);

    { API untuk engine mengirim dari handler script }
    function SendToConn(ConnID: TNBSConnID; const Data: RawByteString): Boolean;
    function SendCloseToConn(ConnID: TNBSConnID; Code: Word): Boolean;
    function FindConn(ConnID: TNBSConnID): TWSNBConn;
    
    // B.1.4c: broadcast text ke semua conn di server handle
    function BroadcastToServer(Handle: Integer;
      const Payload: RawByteString): Integer;
    
    // B.1.4c: list ConnID untuk server handle
    function GetConnIDsForServer(Handle: Integer): TStringArray;
    
    procedure Tick(TimeoutMs: Integer);
    procedure Run;
    procedure Stop;

    property ActiveConns: Integer read FActiveConns;
    property Running: Boolean read FRunning;
  end;

// ════════════════════════════════════════════════════════════════
//  Implementation
// ════════════════════════════════════════════════════════════════

implementation

uses
  DateUtils;

const
  CONN_READ_CHUNK = 16384;
  EPOLL_TICK_MS = 100;   // default tick, bisa di-override


//HTTP upgrade handshake — dipanggil saat state nbsReadHTTP
function ProcessHTTPUpgrade(Conn: TWSNBConn): Boolean;
var
  HdrEnd: Integer;
  Method, Path, Query, Version: string;
  ClientKey, WSVer, WSProto: string;
  WSExtensions: string;
  Parsed: Integer;
  ParseErr: string;
  BodyDiscard: RawByteString;
  I, J: Integer;
  Names, Values: TStringList;
  Resp: RawByteString;
  ExtHeader: string;
  ClientProtos: TStringArray;
  P: string;
begin
  Result := False;

  // Cari \r\n\r\n
  HdrEnd := 0;
  for I := 1 to Length(Conn.ReadBuf) - 3 do
  begin
    if (Conn.ReadBuf[I] = #13) and (Conn.ReadBuf[I+1] = #10) and
       (Conn.ReadBuf[I+2] = #13) and (Conn.ReadBuf[I+3] = #10) then
    begin
      HdrEnd := I + 3;
      Break;
    end;
  end;

  if HdrEnd = 0 then
  begin
    // Belum lengkap
    if Length(Conn.ReadBuf) > HTTP_MAX_HEADER_BYTES then
    begin
      // Header terlalu besar
      Conn.QueueWrite(BuildHTTPResponseRaw(431, 'Request Header Fields Too Large',
        TStringList.Create, TStringList.Create, ''));
      Conn.State := nbsClosing;
      Conn.ClosingAt := GetTickCount64;
    end;
    Exit(False);
  end;

  // Parse HTTP request
  Names := TStringList.Create;
  Values := TStringList.Create;
  try
    if not ParseRawHTTPRequest(Conn.ReadBuf,
        Method, Path, Query, Version,
        Names, Values, BodyDiscard, Parsed, ParseErr) then
    begin
      // Malformed request
      Resp := BuildHTTPResponseRaw(400, 'Bad Request', Names, Values,
                                   RawByteString('Malformed: ' + ParseErr));
      Conn.QueueWrite(Resp);
      Conn.State := nbsClosing;
      Conn.ClosingAt := GetTickCount64;
      Exit(False);
    end;

    // Cek upgrade
    if not IsWebSocketUpgrade(Names, Values, ClientKey, WSVer, WSProto) then
    begin
      Resp := BuildHTTPResponseRaw(400, 'Bad Request', Names, Values,
                                   'Not a WebSocket upgrade');
      Conn.QueueWrite(Resp);
      Conn.State := nbsClosing;
      Conn.ClosingAt := GetTickCount64;
      Exit(False);
    end;

    // Parse extensions
    WSExtensions := '';
    for I := 0 to Names.Count - 1 do
    begin
      if SameText(Names[I], 'Sec-WebSocket-Extensions') then
      begin
        WSExtensions := LowerCase(Values[I]);
        Break;
      end;
    end;

    // Negotiate permessage-deflate
    if Conn.Config^.CompressionEnabled and
       (Pos('permessage-deflate', WSExtensions) > 0) then
    begin
      Conn.CompressionNegotiated := True;
      Conn.Parser.AllowRSV1 := True;
    end;

    // Pilih subprotocol
    if (WSProto <> '') and (Conn.Config^.Subprotocols <> nil) then
    begin
      ClientProtos := WSProto.Split([',']);
      J := 0;
      Conn.Protocol := '';
      while (J <= High(ClientProtos)) and (Conn.Protocol = '') do
      begin
        P := Trim(ClientProtos[J]);
        if Conn.Config^.Subprotocols.IndexOf(P) >= 0 then
          Conn.Protocol := P;
        Inc(J);
      end;
    end;

    // Populate metadata
    Conn.Path := Path;
    Conn.Query := Query;
    for I := 0 to Names.Count - 1 do
    begin
      Conn.HeaderNames.Add(Names[I]);
      Conn.HeaderValues.Add(Values[I]);
    end;

    // Build handshake response
    Resp := BuildWSHandshakeResponse(ClientKey, Conn.Protocol);
    if Conn.CompressionNegotiated then
    begin
      // Sisipkan extensions header sebelum blank-line terminator
      if Length(Resp) >= 2 then
      begin
        Delete(Resp, Length(Resp) - 1, 2);
        ExtHeader :=
          'Sec-WebSocket-Extensions: permessage-deflate; ' +
          'server_no_context_takeover; client_no_context_takeover' + #13#10 +
          #13#10;
        Resp := Resp + RawByteString(ExtHeader);
      end;
    end;

    Conn.QueueWrite(Resp);

    // Consume headers dari ReadBuf — sisakan payload sisa (kalau ada frame)
    if Parsed >= Length(Conn.ReadBuf) then
      Conn.ReadBuf := ''
    else
      Delete(Conn.ReadBuf, 1, Parsed);

    // Transition
    Conn.State := nbsOpen;
    Conn.LastActivity := GetTickCount64;

    // Notify sink — onOpen
    Result := True;
  finally
    Names.Free;
    Values.Free;
  end;
end;

//Frame processing — dipanggil setiap ada data di ReadBuf saat nbsOpen
procedure ProcessFramesInBuf(Loop: TWSEventLoop; Conn: TWSNBConn);
var
  Frame: TWSFrame;
  Payload: RawByteString;
begin
  while True do
  begin
    try
      if not Conn.Parser.TryParse(Frame) then
        Break;
    except
      // Protocol error → close
      Loop.SendCloseToConn(Conn.ID, WS_CLOSE_PROTOCOL_ERR);
      Break;
    end;
    
    Conn.LastActivity := GetTickCount64;
    Conn.PendingPing := False;
    Conn.PendingPingAt := 0;

    case Frame.Opcode of
      wsText, wsBinary:
        begin
          if Conn.FragActive then
          begin
            Loop.SendCloseToConn(Conn.ID, WS_CLOSE_PROTOCOL_ERR);
            Break;
          end;
          if Frame.Fin then
          begin
            Payload := Frame.Payload;
            if Frame.RSV1 and Conn.CompressionNegotiated then
            begin
              try
                Payload := InflateRaw(Payload + #0#0#$FF#$FF);
              except
                Loop.SendCloseToConn(Conn.ID, WS_CLOSE_PROTOCOL_ERR);
                Break;
              end;
            end;
            // ✅ FIX: hanya satu dispatch, tidak ada blok duplikat
            if Loop.FOnMessage <> nil then
              try Loop.FOnMessage(Conn.Config^.SinkCtx, Conn.ID, Payload);
              except end;
          end else
          begin
            Conn.FragActive := True;
            Conn.FragOpcode := Frame.Opcode;
            Conn.FragBuf := Frame.Payload;
          end;
        end;

      wsContinuation:
        begin
          if not Conn.FragActive then
          begin
            Loop.SendCloseToConn(Conn.ID, WS_CLOSE_PROTOCOL_ERR);
            Break;
          end;
          Conn.FragBuf := Conn.FragBuf + Frame.Payload;
          if Length(Conn.FragBuf) > Conn.Config^.MaxPayloadBytes then
          begin
            Loop.SendCloseToConn(Conn.ID, WS_CLOSE_TOO_LARGE);
            Break;
          end;
          if Frame.Fin then
          begin
            // ✅ FIX: dispatch Conn.FragBuf (buffer akumulasi), bukan Payload
            if Loop.FOnMessage <> nil then
              try Loop.FOnMessage(Conn.Config^.SinkCtx, Conn.ID, Conn.FragBuf);
              except end;
            Conn.FragActive := False;
            Conn.FragBuf := '';
          end;
        end;

      wsPing:
        begin
          // Auto-respond pong
          Conn.QueueWrite(BuildWSFrame(wsPong, Frame.Payload, True));
        end;

      wsPong:
        begin
          // Update activity (sudah di atas)
        end;

      wsClose:
        begin
          // Balas close lalu tutup
          Loop.CloseConn(Conn, WS_CLOSE_NORMAL);
          Break;
        end;
    end;
  end;
end;

{ --------------------------------------------------------------------
  TWSNBConn
  -------------------------------------------------------------------- }

constructor TWSNBConn.Create(ASock: Integer; AConfig: PNBServerConfig);
begin
  inherited Create;
  ID := 0;
  Sock := ASock;
  ServerHandle := AConfig^.Handle;
  State := nbsReadHTTP;

  ReadBuf := '';
  WriteBuf := '';
  WantWrite := False;

  Parser := TWSFrameParser.Create(True);

  Path := '';
  Query := '';
  Protocol := '';
  PeerIP := '';
  PeerPort := 0;
  HeaderNames := TStringList.Create;
  HeaderValues := TStringList.Create;

  FragActive := False;
  FragOpcode := wsText;
  FragBuf := '';

  LastActivity := GetTickCount64;
  PendingPing := False;
  PendingPingAt := 0;

  CompressionNegotiated := False;
  CompressionThreshold := AConfig^.CompressionThreshold;

  Config := AConfig;
  ClosingAt := 0;
  
  TLSConn := nil;
  TLSServerCtx := nil;
end;

destructor TWSNBConn.Destroy;
begin
  Parser.Free;
  HeaderNames.Free;
  HeaderValues.Free;
  // B.2: TLS cleanup dulu (butuh fd), baru close socket
  if Assigned(TLSConn) then
  begin
    try TLSClose(TLSConn); except end;
    try TLSConn.Release;   except end;
    TLSConn := nil;
  end;
  if Sock >= 0 then
  begin
    try NetClose(Sock); except end;
    Sock := -1;
  end;
  inherited;
end;

function TWSNBConn.QueueWrite(const Data: RawByteString): Boolean;
begin
  if Length(Data) = 0 then
    Exit(False);
  if WriteBuf = '' then
    WriteBuf := Data
  else
    WriteBuf := WriteBuf + Data;
  Result := not WantWrite;   // true = caller harus register EPOLLOUT
end;

// ════════════════════════════════════════════════════════════════
//  B.2: TLS-aware I/O
// ════════════════════════════════════════════════════════════════
//  Read:  >0 bytes | 0 closed | -1 want read | -2 want write | -3 error
//  Write: >0 bytes | -1 want read | -2 want write | -3 error
// ════════════════════════════════════════════════════════════════

function WSNBRead(Conn: TWSNBConn; Buf: Pointer; MaxLen: Integer): Integer;
var
  Stat: TTLSNBStatus;
  N: Integer;
begin
  if not Assigned(Conn.TLSConn) then
    Exit(fpRead(Conn.Sock, Buf^, MaxLen));

  Stat := TLSNonBlockingRead(Conn.TLSConn, Buf, MaxLen, N);
  case Stat of
    tlsnbDone:     Result := N;
    tlsnbClosed:   Result := 0;
    tlsnbWantRead: Result := -1;
    tlsnbWantWrite:Result := -2;
  else
    Result := -3;
  end;
end;

function WSNBWrite(Conn: TWSNBConn; Buf: Pointer; Len: Integer): Integer;
var
  Stat: TTLSNBStatus;
  N: Integer;
begin
  if not Assigned(Conn.TLSConn) then
    Exit(fpWrite(Conn.Sock, Buf^, Len));

  Stat := TLSNonBlockingWrite(Conn.TLSConn, Buf, Len, N);
  case Stat of
    tlsnbDone:     Result := N;
    tlsnbClosed:   Result := -3;
    tlsnbWantRead: Result := -1;
    tlsnbWantWrite:Result := -2;
  else
    Result := -3;
  end;
end;

{ --------------------------------------------------------------------
  TWSEventLoop
  -------------------------------------------------------------------- }

constructor TWSEventLoop.Create;
begin
  inherited Create;
  FPoller := TPoller.Create;
  FConns := specialize TFPGMap<Integer, TWSNBConn>.Create;
  FServers := specialize TFPGMap<Integer, PNBServerConfig>.Create;
  FListenSocks := specialize TFPGMap<Integer, PNBServerConfig>.Create;
  FNextConnID := 1;
  FRunning := False;
  FActiveConns := 0;
  FOnOpen := nil;
  FOnMessage := nil;
  FOnClose := nil;
end;

destructor TWSEventLoop.Destroy;
var
  I: Integer;
begin
  // Free semua connections
  for I := FConns.Count - 1 downto 0 do
  begin
    try FConns.Data[I].Free; except end;
  end;
  FConns.Free;

  // ⚠️ FServers.Data[] OWNED BY ENGINE (pascak_noASTnet.pas).
  // FreeWSServers sudah Dispose NBSConfig + Free Subprotocols
  // SEBELUM GWSEventLoop.Free dijalankan. Jadi Destroy TIDAK BOLEH
  // menyentuh FServers.Data[] — double-free bug (fix B.2.5).
  //
  // FServers hanya menyimpan pointer borrowed. Cukup Free map-nya.
  FServers.Free;
  FListenSocks.Free;
  FPoller.Free;
  inherited;
end;

procedure TWSEventLoop.SetSink(OnOpen: TNBSinkOnOpen;
  OnMessage: TNBSinkOnMessage;
  OnClose: TNBSinkOnClose);
begin
  FOnOpen := OnOpen;
  FOnMessage := OnMessage;
  FOnClose := OnClose;
end;

function TWSEventLoop.AddServer(Config: PNBServerConfig): Boolean;
begin
  Result := False;
  if not Assigned(Config) then Exit;
  // B.2: TLS sekarang didukung
  if Config^.IsTLS and (not Assigned(Config^.TLSContext)) then
    raise EWSEventLoopError.Create(
      'wss:// butuh TLSContext — set Config^.TLSContext sebelum AddServer');
  if Config^.ListenSock < 0 then Exit;
  
  NetSetNonBlocking(Config^.ListenSock, True);

  if not FPoller.Add(Config^.ListenSock, [pekRead]) then
    raise EWSEventLoopError.CreateFmt(
      'epoll add listen sock %d gagal', [Config^.ListenSock]);

  FServers.Add(Config^.Handle, Config);
  FListenSocks.Add(Config^.ListenSock, Config);   // B.1.4d
  Result := True;
end;

procedure TWSEventLoop.RemoveServer(Handle: Integer);
var
  Idx, SockIdx: Integer;
  Cfg: PNBServerConfig;
begin
  Idx := FServers.IndexOf(Handle);
  if Idx < 0 then Exit;

  Cfg := FServers.Data[Idx];
  if Assigned(Cfg) and (Cfg^.ListenSock >= 0) then
  begin
    SockIdx := FListenSocks.IndexOf(Cfg^.ListenSock);
    if SockIdx >= 0 then
      FListenSocks.Delete(SockIdx);

    try FPoller.Del(Cfg^.ListenSock); except end;
    try NetClose(Cfg^.ListenSock); except end;
    Cfg^.ListenSock := -1;
  end;

  FServers.Delete(Idx);
  // NB: tidak Free Cfg di sini — engine yang owns
end;

function TWSEventLoop.FindConn(ConnID: TNBSConnID): TWSNBConn;
var
  I: Integer;
begin
  Result := nil;
  for I := 0 to FConns.Count - 1 do
  begin
    if FConns.Data[I].ID = ConnID then
      Exit(FConns.Data[I]);
  end;
end;

function TWSEventLoop.SendToConn(ConnID: TNBSConnID;
 const Data: RawByteString): Boolean;
var
  Conn: TWSNBConn;
begin
  Result := False;
  if Length(Data) = 0 then Exit;
  Conn := FindConn(ConnID);
  if not Assigned(Conn) then Exit;
  if Conn.State <> nbsOpen then Exit;

  if Conn.QueueWrite(Data) then
    UpdateEpollEvents(Conn);
  Result := True;
end;

function TWSEventLoop.SendCloseToConn(ConnID: TNBSConnID;
    Code: Word): Boolean;
var
  Conn: TWSNBConn;
  Frame: RawByteString;
begin
  Result := False;
  Conn := FindConn(ConnID);
  if not Assigned(Conn) then Exit;
  if Conn.State in [nbsClosing, nbsClosed] then Exit;

  Frame := BuildWSClose(Code, '');
  if Conn.QueueWrite(Frame) then
    UpdateEpollEvents(Conn);

  Conn.State := nbsClosing;
  Result := True;
end;

procedure TWSEventLoop.UpdateEpollEvents(Conn: TWSNBConn);
var
  Kinds: TPollerEventKinds;
  WantWriteNow: Boolean;
  NeedChange: Boolean;
begin
  if (not Assigned(Conn)) or (Conn.Sock < 0) then Exit;

  // B.2: TLS handshake — EPOLLIN only. SSL_accept di-loop sampai WANT_READ.
  if Conn.State = nbsTLSHandshake then
  begin
    Kinds := [pekRead];
    if Conn.WantWrite or True then
    begin
      if FPoller.Mod_(Conn.Sock, Kinds) then
      begin
        Conn.WantWrite := False;
        Exit;
      end;
      try FPoller.Del(Conn.Sock); except end;
      if FPoller.Add(Conn.Sock, Kinds) then
        Conn.WantWrite := False;
      Exit;
    end;
  end;

  WantWriteNow := Length(Conn.WriteBuf) > 0;
  Kinds := [pekRead];
  if WantWriteNow then Include(Kinds, pekWrite);

  if WantWriteNow <> Conn.WantWrite then
  begin
    if FPoller.Mod_(Conn.Sock, Kinds) then
      Conn.WantWrite := WantWriteNow
    else
    begin
      try FPoller.Del(Conn.Sock); except end;
      if FPoller.Add(Conn.Sock, Kinds) then
        Conn.WantWrite := WantWriteNow;
    end;
  end;
end;

procedure TWSEventLoop.FreeConn(Conn: TWSNBConn);
var
  Idx: Integer;
begin
  if not Assigned(Conn) then Exit;

  // Deregister dari epoll
  if Conn.Sock >= 0 then
  begin
    try FPoller.Del(Conn.Sock); except end;
  end;

  // Hapus dari map
  Idx := FConns.IndexOf(Conn.Sock);
  if Idx >= 0 then
    FConns.Delete(Idx);

  Dec(FActiveConns);
  try Conn.Free; except end;
end;

procedure TWSEventLoop.CloseConn(Conn: TWSNBConn; Code: Word);
begin
  if not Assigned(Conn) then Exit;
  if Conn.State = nbsClosed then Exit;

  // Kirim close frame kalau belum
  if Conn.State = nbsOpen then
  begin
    try
      Conn.QueueWrite(BuildWSClose(Code, ''));
      UpdateEpollEvents(Conn);
    except
    end;
  end;

  // Notify engine
  if Assigned(FOnClose) and (Conn.Config <> nil) then
  begin
    try FOnClose(Conn.Config^.SinkCtx, Conn.ID, Code); except end;
  end;

  // Jangan langsung closed — biarkan Tick sweep setelah WriteBuf terkirim
  // atau timeout 5s
  if Length(Conn.WriteBuf) > 0 then
  begin
    Conn.State := nbsClosing;
    Conn.ClosingAt := GetTickCount64;
  end
  else
    Conn.State := nbsClosed;
end;

procedure TWSEventLoop.CheckPingTimers;
var
  I: Integer;
  Conn: TWSNBConn;
  NowTick: QWord;
  Cfg: PNBServerConfig;
begin
  NowTick := GetTickCount64;
  for I := FConns.Count - 1 downto 0 do
  begin
    Conn := FConns.Data[I];
    if not Assigned(Conn) then Continue;
    if Conn.State <> nbsOpen then Continue;

    Cfg := Conn.Config;
    if (not Assigned(Cfg)) or (not Cfg^.PingEnabled) then Continue;

    // Pong timeout?
    if Conn.PendingPing and
       ((NowTick - Conn.PendingPingAt) > QWord(Cfg^.PongTimeoutMs)) then
    begin
      CloseConn(Conn, WS_CLOSE_GOING_AWAY);
      Continue;
    end;

    // Kirim ping kalau idle
    if (not Conn.PendingPing) and
       ((NowTick - Conn.LastActivity) > QWord(Cfg^.PingIntervalMs)) then
    begin
      if Conn.QueueWrite(BuildWSFrame(wsPing, '', True)) then
        UpdateEpollEvents(Conn);
      Conn.PendingPingAt := NowTick;
      Conn.PendingPing := True;
    end;
  end;
end;

{ Implementasi sisa (HandleListenReadable, HandleConnReadable,
  HandleConnWritable, Tick, Run, Stop) akan diisi di B.1.3b }
procedure TWSEventLoop.HandleListenReadable(ListenSockFd: Integer);
var
  Cfg: PNBServerConfig;
  Idx, NewSock: Integer;
  Addr: TSockAddr;
  AddrLen: Integer;
  Conn: TWSNBConn;
begin
  // ✅ FIX: lookup via FListenSocks (key = sock fd)
  Idx := FListenSocks.IndexOf(ListenSockFd);
  if Idx < 0 then Exit;
  Cfg := FListenSocks.Data[Idx];
  if not Assigned(Cfg) then Exit;
  
  // Loop accept — handle multiple pending connection
  while True do
  begin
    AddrLen := SizeOf(Addr);
    NewSock := fpAccept(Cfg^.ListenSock, @Addr, @AddrLen);
    if NewSock < 0 then
    begin
      // EAGAIN / EWOULDBLOCK → semua pending sudah di-accept
      if (fpGetErrno = ESysEAGAIN) or (fpGetErrno = ESysEWOULDBLOCK) then
        Break;
      // EMFILE / ENFILE → fd exhaustion, stop accept loop sementara
      if (fpGetErrno = ESysEMFILE) or (fpGetErrno = ESysENFILE) then
        Break;
      Break;
    end;

    // Set client socket non-blocking
    NetSetNonBlocking(NewSock, True);
    NetSetNoDelay(NewSock, True);

    // Buat conn state
    Conn := TWSNBConn.Create(NewSock, Cfg);
    Conn.ID := FNextConnID;
    Inc(FNextConnID);
    
    Conn.PeerIP := NetPeerIP(NewSock);
    Conn.PeerPort := NetPeerPort(NewSock);

    // B.2: TLS init
    if Cfg^.IsTLS and Assigned(Cfg^.TLSContext) then
    begin
      if not TLSAcceptInit(TLSServerContext(Cfg^.TLSContext), NewSock,
                           Conn.TLSConn) then
      begin
        Conn.Free;
        Continue;
      end;
      
      Conn.TLSServerCtx := Cfg^.TLSContext;
      Conn.State := nbsTLSHandshake;
      // Register read only — handshake akan loop SSL_accept internal
      if not FPoller.Add(NewSock, [pekRead]) then
      begin
        Conn.Free;
        Continue;
      end;
      Conn.WantWrite := False;
      
    end
    else
    begin
      // Plain WS
      if not FPoller.Add(NewSock, [pekRead]) then
      begin
        Conn.Free;
        Continue;
      end;
      Conn.WantWrite := False;
    end;

    FConns.Add(NewSock, Conn);
    Inc(FActiveConns);
  end;
end;

//Conn readable — state dispatch
procedure TWSEventLoop.HandleConnReadable(Conn: TWSNBConn);
var
  Chunk: array[0..CONN_READ_CHUNK - 1] of Byte;
  N: Integer;
  GotData: Boolean;
  EmptyStreak: Integer;
  HandshakeStat: TTLSNBStatus;
  RetryCount: integer;
begin
  if not Assigned(Conn) then Exit;
  if Conn.Sock < 0 then Exit;

  // ═══════════════════════════════════════════════════════════════
  //  B.2 FIX: TLS handshake harus di-drive SEBELUM read loop.
  //  SSL_read pada SSL yang belum handshake = error → tidak boleh
  //  masuk read loop saat state masih nbsTLSHandshake.
  // ═══════════════════════════════════════════════════════════════
  if Conn.State = nbsTLSHandshake then
  begin
    RetryCount := 0;
    while RetryCount < 32 do
    begin
      Inc(RetryCount);
      HandshakeStat := TLSNonBlockingHandshake(Conn.TLSConn);
      case HandshakeStat of
        tlsnbDone:
          begin
            Conn.State := nbsReadHTTP;
            UpdateEpollEvents(Conn);
            Break;   // fall through ke read loop
          end;
        tlsnbWantWrite:
          Continue;  // retry langsung (socket writable)
        tlsnbWantRead:
          begin
            UpdateEpollEvents(Conn);
            Exit;    // tunggu socket readable berikutnya
          end;
        tlsnbClosed, tlsnbError:
          begin
            Conn.State := nbsClosed;
            Exit;
          end;
      end;
    end;
    // Kalau sampai sini, handshake done — lanjut ke read loop
  end;

  EmptyStreak := 0;
  repeat
    // B.2: route melalui WSNBRead (TLS atau plain)
    N := WSNBRead(Conn, @Chunk[0], SizeOf(Chunk));  
  
    if N > 0 then
    begin
      SetLength(Conn.ReadBuf, Length(Conn.ReadBuf) + N);
      Move(Chunk[0], Conn.ReadBuf[Length(Conn.ReadBuf) - N + 1], N);
      GotData := True;
      EmptyStreak := 0;
      Continue;
    end;
  
    if N = 0 then
    begin
      // Peer closed
      if Conn.State = nbsOpen then
        CloseConn(Conn, WS_CLOSE_ABNORMAL)
      else
        Conn.State := nbsClosed;
      Exit;
    end;
  
    if N = -1 then
    begin
      // TLS want read — tunggu socket readable
      Break;
    end;
  
    if N = -2 then
    begin
      // TLS want write — update epoll, break (jangan block)
      UpdateEpollEvents(Conn);
      Break;
    end;
  
    // N = -3 (error) atau plain N<0 → cek errno
    if fpGetErrno = ESysEAGAIN then
      Break
    else if fpGetErrno = ESysEINTR then
    begin
      Inc(EmptyStreak);
      if EmptyStreak > 10 then Break;
      Continue;
    end
    else
    begin
      Conn.State := nbsClosed;
      Exit;
    end;
  until False;

  // ═══════════════════════════════════════════════════════════════
  //  B.2 FIX: Setelah read loop, proses berdasarkan state.
  //  Blok ini WAJIB — tanpa ini, HTTP upgrade request tidak
  //  pernah diproses setelah TLS handshake selesai.
  // ═══════════════════════════════════════════════════════════════

  if Conn.State = nbsReadHTTP then
  begin
    if ProcessHTTPUpgrade(Conn) then
    begin
      if FOnOpen <> nil then
        try FOnOpen(Conn.Config^.SinkCtx, Conn.ID, Pointer(Conn));
        except end;
    end;
  end;

  // Append ReadBuf ke Parser sebelum parse frame (early frame).
  if (Conn.State = nbsOpen) and (Length(Conn.ReadBuf) > 0) then
  begin
    Conn.Parser.Append(Conn.ReadBuf);
    Conn.ReadBuf := '';
    ProcessFramesInBuf(Self, Conn);
  end;

  // Pastikan WriteBuf selalu flush (handshake response, pong, echo).
  if Length(Conn.WriteBuf) > 0 then
    UpdateEpollEvents(Conn);

end;

//Conn writable — flush WriteBuf
procedure TWSEventLoop.HandleConnWritable(Conn: TWSNBConn);
var
  Written: Integer;
begin
  if not Assigned(Conn) then Exit;
  if Conn.Sock < 0 then Exit;

  // B.2: TLS handshake progress (writable event bisa drive WANT_WRITE)
  if Conn.State = nbsTLSHandshake then
  begin
    Exit;
  end;

  if Length(Conn.WriteBuf) = 0 then
  begin
    UpdateEpollEvents(Conn);
    Exit;
  end;

  Written := WSNBWrite(Conn, @Conn.WriteBuf[1], Length(Conn.WriteBuf));
  if Written > 0 then
  begin
    if Written >= Length(Conn.WriteBuf) then
      Conn.WriteBuf := ''
    else
      Delete(Conn.WriteBuf, 1, Written);

    if Length(Conn.WriteBuf) = 0 then
    begin
      UpdateEpollEvents(Conn);
      if Conn.State = nbsClosing then
        Conn.State := nbsClosed;
    end;
  end
  else if Written = -1 then
  begin
    // TLS want read — update epoll, tunggu readable
    UpdateEpollEvents(Conn);
  end
  else if Written = -2 then
  begin
    // TLS want write — tetap tunggu writable
    UpdateEpollEvents(Conn);
  end
  else if Written < 0 then
  begin
    // Plain socket error
    if (fpGetErrno <> ESysEAGAIN) and (fpGetErrno <> ESysEINTR) then
      Conn.State := nbsClosed;
  end;
end;

//B.1.4c: Broadcast — per-connection compression
function TWSEventLoop.BroadcastToServer(Handle: Integer;
  const Payload: RawByteString): Integer;
var
  I, Count: Integer;
  Conn: TWSNBConn;
  Compressed, Frame: RawByteString;
  UseComp: Boolean;
begin
  Result := 0;
  Count := 0;
  for I := 0 to FConns.Count - 1 do
  begin
    Conn := FConns.Data[I];
    if not Assigned(Conn) then Continue;
    if Conn.ServerHandle <> Handle then Continue;
    if Conn.State <> nbsOpen then Continue;
    
    UseComp := False;
    Frame := '';
    if Conn.CompressionNegotiated and
       (Length(Payload) >= Conn.CompressionThreshold) then
    begin
      try
        Compressed := DeflateRaw(Payload);
        if Length(Compressed) < Length(Payload) then
        begin
          Frame := BuildWSFrame(wsText, Compressed, True);
          if Length(Frame) > 0 then
            Frame[1] := Char(Byte(Frame[1]) or $40);
          UseComp := True;
        end;
      except
      end;
    end;
    
    if not UseComp then
      Frame := BuildWSFrame(wsText, Payload, True);
    
    if Conn.QueueWrite(Frame) then
      UpdateEpollEvents(Conn);
    Inc(Count);
  end;
  Result := Count;
end;

function TWSEventLoop.GetConnIDsForServer(Handle: Integer): TStringArray;
var
  I, Count: Integer;
begin
  SetLength(Result, 0);
  Count := 0;
  SetLength(Result, FConns.Count);
  for I := 0 to FConns.Count - 1 do
  begin
    if FConns.Data[I].ServerHandle = Handle then
    begin
      Result[Count] := 'nbs-' + IntToStr(FConns.Data[I].ID);
      Inc(Count);
    end;
  end;
  SetLength(Result, Count);
end;

//Tick — main event loop iteration
procedure TWSEventLoop.Tick(TimeoutMs: Integer);
var
  Results: array[0..255] of TPollerResult;
  N, I: Integer;
  Conn: TWSNBConn;
  NowTick: QWord;
  ToFree: TList;
  CfgIdx,ConnIdx: Integer;
begin
  try
    N := FPoller.Poll(TimeoutMs, Results);
  except
    Exit;
  end;

  ToFree := TList.Create;
  try
    for I := 0 to N - 1 do
    begin
      // ✅ FIX: cek listen socket via FListenSocks (key = sock fd, bukan handle)
      CfgIdx := FListenSocks.IndexOf(Results[I].Sock);
      if CfgIdx >= 0 then
      begin
        if pekRead in Results[I].Kinds then
          HandleListenReadable(Results[I].Sock);
        Continue;
      end;

      // Regular conn
      ConnIdx := FConns.IndexOf(Results[I].Sock);
      if ConnIdx < 0 then Continue;
      Conn := FConns.Data[ConnIdx];
      if not Assigned(Conn) then Continue;

      // B.2: TLS handshake — coba drive baik dari read maupun write event
      if Conn.State = nbsTLSHandshake then
      begin
        if (pekRead in Results[I].Kinds) or (pekWrite in Results[I].Kinds) then
          HandleConnReadable(Conn);   // handle handshake di sana
        Continue;
      end;
      
      if pekRead in Results[I].Kinds then
      begin
        HandleConnReadable(Conn);
      end;
      
      if pekWrite in Results[I].Kinds then
        HandleConnWritable(Conn);
      
      if (pekError in Results[I].Kinds) or
         (pekHangup in Results[I].Kinds) then
      begin
        if Conn.State = nbsOpen then
          CloseConn(Conn, WS_CLOSE_ABNORMAL)
        else
          Conn.State := nbsClosed;
      end;
    end;

    // Sweep closed conns
    for I := FConns.Count - 1 downto 0 do
    begin
      Conn := FConns.Data[I];
      if not Assigned(Conn) then Continue;
      if Conn.State = nbsClosed then
        ToFree.Add(Conn);
    end;

    for I := 0 to ToFree.Count - 1 do
      FreeConn(TWSNBConn(ToFree[I]));
  finally
    ToFree.Free;
  end;

  // Ping/pong idle check (setiap tick)
  CheckPingTimers;

  // Force close conn yang closing terlalu lama
  NowTick := GetTickCount64;
  for I := FConns.Count - 1 downto 0 do
  begin
    Conn := FConns.Data[I];
    if not Assigned(Conn) then Continue;
    if (Conn.State = nbsClosing) and
       ((NowTick - Conn.ClosingAt) > 5000) then
      Conn.State := nbsClosed;
  end;
end;

procedure TWSEventLoop.Run;
begin
  FRunning := True;
  while FRunning do
    Tick(EPOLL_TICK_MS);
end;

procedure TWSEventLoop.Stop;
begin
  FRunning := False;
end;

initialization
finalization

end.