{ ====================================================================
  pascak_tls.pas — TLS/SSL binding untuk VM Pascak
  ====================================================================
  FFI ke libssl.so + libcrypto.so. Support OpenSSL 1.1.x dan 3.x.
  
  Semua fungsi di-bind via dlopen + GetProcAddress, jadi libssl
  tidak perlu ada saat compile — hanya saat runtime.
  ==================================================================== }
unit pascak_tls;

{$MODE OBJFPC}{$H+}

interface

uses
  SysUtils, Classes, dynlibs;

type
  ETLSException = class(Exception);

  { B.2: Non-blocking TLS operations }
  TTLSNBStatus = (
    tlsnbDone,       // selesai sukses
    tlsnbWantRead,   // perlu tunggu socket readable
    tlsnbWantWrite,  // perlu tunggu socket writable
    tlsnbError,      // hard error (LastError diisi)
    tlsnbClosed      // peer closed (untuk read)
  );
  
  TTLSContext = class
  private
    FRefCount: Integer;
  public
    CtxPtr: Pointer;   // SSL_CTX*
    VerifyPeer: Boolean;   // ✅ FASE 0.8: simpan flag verify

    constructor Create(AVerifyPeer: Boolean);
    destructor Destroy; override;
    procedure Retain;
    procedure Release;
  end;

  { C-2: Server-side TLS context — cert + key, bukan client verify }
  TLSServerContext = class
  private
    FRefCount: Integer;
  public
    CtxPtr: Pointer;
    LastError: string;
    
    constructor Create(const CertPath, KeyPath: string);
    destructor Destroy; override;
    procedure Retain;
    procedure Release;
    function IsValid: Boolean;
  end;

  TTLSConnection = class
  private
    FRefCount: Integer;
  public
    SSLPtr: Pointer;    // SSL*
    Ctx: TTLSContext;   // reference
    SockFd: Integer;
    HandshakeDone: Boolean;
    LastError: string;
    
    constructor Create(ACtx: TTLSContext; ASockFd: Integer);
    destructor Destroy; override;
    procedure Retain;
    procedure Release;
  end;
  
  
  // Load libssl + libcrypto. Return True jika sukses.
  // Idempotent — panggilan berulang tidak re-load.
  function TLSInit: Boolean;
  procedure TLSShutdown;
  function TLSIsLoaded: Boolean;
  
  // Versi OpenSSL yang ter-load (untuk diagnostik)
  function TLSVersion: string;
  
  // Drive handshake non-blocking (server-side, setelah TLSAcceptInit).
  // Bisa dipanggil ulang setelah tlsnbWantRead/WantWrite.
  function TLSNonBlockingHandshake(Conn: TTLSConnection): TTLSNBStatus;
  
  // Non-blocking read. MaxLen > 0.
  function TLSNonBlockingRead(Conn: TTLSConnection; Buf: Pointer;
    MaxLen: Integer;
    out BytesRead: Integer): TTLSNBStatus;
  
  // Non-blocking write. Bisa partial (BytesWritten < Len).
  function TLSNonBlockingWrite(Conn: TTLSConnection; Buf: Pointer;
    Len: Integer;
    out BytesWritten: Integer): TTLSNBStatus;
  
  // Cek apakah ada data buffered di SSL internal (setelah read partial).
  function TLSNonBlockingPending(Conn: TTLSConnection): Integer;
  
  // Init server-side TLS connection tanpa drive handshake.
  // Caller bertanggung jawab panggil TLSNonBlockingHandshake berulang.
  // ServerCtx harus tetap hidup selama Conn hidup.
  function TLSAcceptInit(ServerCtx: TLSServerContext; SockFd: Integer;
    out Conn: TTLSConnection): Boolean;
    
  function TLSAccept(Ctx: TLSServerContext; SockFd: Integer;
    out Conn: TTLSConnection): Boolean;  
  
  // Buka koneksi TLS ke host:port via socket TCP yang sudah connect.
  // ServerName = SNI hostname.
  function TLSConnect(Ctx: TTLSContext; SockFd: Integer;
    const ServerName: string;
    out Conn: TTLSConnection): Boolean;
  
  // Kirim data terenkripsi. Return byte terkirim, atau -1 error.
  function TLSSend(Conn: TTLSConnection; const Data: RawByteString): Integer;
  
  // Terima data (blocking dengan timeout via select pada fd).
  // Return: >0 = data, 0 = closed, -1 = error.
  function TLSRecv(Conn: TTLSConnection; MaxBytes: Integer;
    out Data: RawByteString): Integer;
  function TLSRecvTimeout(Conn: TTLSConnection; MaxBytes, TimeoutMs: Integer;
    out Data: RawByteString): Integer;
  
  // Shutdown TLS (send close_notify), lalu bebaskan SSL handle.
  procedure TLSClose(Conn: TTLSConnection);
  function TLSLastError: string;
  function TLSVerifyErrorString(Code: LongInt): string;


implementation

uses
  BaseUnix, Sockets;

// ════════════════════════════════════════════════════════════════
//  FFI function pointer types
// ════════════════════════════════════════════════════════════════
type
  TSSL_library_init = function(): Integer; cdecl;
  TSSL_load_error_strings = procedure(); cdecl;
  TOpenSSL_add_all_algorithms = procedure(); cdecl;
  
  TSSL_ctrl = function(ssl: Pointer; cmd: Integer; larg: LongInt; parg: Pointer): LongInt; cdecl;
  TSSL_do_handshake = function(ssl: Pointer): Integer; cdecl;
  TSSL_pending = function(ssl: Pointer): Integer; cdecl;

  TTLS_method = function(): Pointer; cdecl;   // 1.1+ (dulu SSLv23_method)
  TTLS_client_method = function(): Pointer; cdecl;
  TSSL_CTX_new = function(method: Pointer): Pointer; cdecl;
  TSSL_CTX_free = procedure(ctx: Pointer); cdecl;
  
  TSSL_new = function(ctx: Pointer): Pointer; cdecl;
  TSSL_free = procedure(ssl: Pointer); cdecl;
  TSSL_set_fd = function(ssl: Pointer; fd: Integer): Integer; cdecl;
  TSSL_set_tlsext_host_name = function(ssl: Pointer; name: PAnsiChar): Integer; cdecl;
  
  TSSL_connect = function(ssl: Pointer): Integer; cdecl;
  TSSL_read = function(ssl: Pointer; buf: Pointer; num: Integer): Integer; cdecl;
  TSSL_write = function(ssl: Pointer; buf: Pointer; num: Integer): Integer; cdecl;
  TSSL_shutdown = function(ssl: Pointer): Integer; cdecl;
  
  TSSL_CTX_set_verify = procedure(ctx: Pointer; mode: Integer; cb: Pointer); cdecl;
  TSSL_CTX_set_default_verify_paths = function(ctx: Pointer): Integer; cdecl;
  
  TSSL_get_error = function(ssl: Pointer; ret: Integer): Integer; cdecl;
  TERR_get_error = function(): Cardinal; cdecl;
  TERR_error_string_n = procedure(e: Cardinal; buf: PAnsiChar; len: NativeUInt); cdecl;
  
  TSSL_set1_host = function(ssl: Pointer; hostname: PAnsiChar): Integer; cdecl;
  
  TSSL_CTX_use_certificate_chain_file = function(ctx: Pointer; filepath: PAnsiChar): Integer; cdecl;
  TSSL_CTX_use_PrivateKey_file = function(ctx: Pointer; filepath: PAnsiChar; t: Integer): Integer; cdecl;

  TSSL_CTX_check_private_key = function(ctx: Pointer): Integer; cdecl;
  TSSL_accept = function(ssl: Pointer): Integer; cdecl;
  TTLS_server_method = function(): Pointer; cdecl;
  TSSL_CTX_load_verify_locations = function(ctx: Pointer; CAfile: PAnsiChar; CApath: PAnsiChar): Integer; cdecl;  
  
  TOPENSSL_init_ssl = function(opts: QWord; settings: Pointer): Integer; cdecl;
  TSSL_get_verify_result = function(ssl: Pointer): LongInt; cdecl;
  
  TSSLeay_version = function(t: Integer): PAnsiChar; cdecl;
  TOpenSSL_version = function(t: Integer): PAnsiChar; cdecl;

var
  GLibSSL: TLibHandle = NilHandle;
  GLibCrypto: TLibHandle = NilHandle;
  GInitCount: Integer = 0;
  GLoaded: Boolean = False;   // true kalau symbol sudah pernah di-bind
  GInitLock: TRTLCriticalSection;
  
  // Function pointers
  fp_SSL_library_init: TSSL_library_init;
  fp_SSL_load_error_strings: TSSL_load_error_strings;
  fp_OpenSSL_add_all_algorithms: TOpenSSL_add_all_algorithms;
  fp_TLS_method: TTLS_method;
  fp_TLS_client_method: TTLS_client_method;
  fp_SSL_CTX_new: TSSL_CTX_new;
  fp_SSL_CTX_free: TSSL_CTX_free;
  fp_SSL_new: TSSL_new;
  fp_SSL_free: TSSL_free;
  fp_SSL_set_fd: TSSL_set_fd;
  fp_SSL_set_tlsext_host_name: TSSL_set_tlsext_host_name;
  fp_SSL_connect: TSSL_connect;
  fp_SSL_read: TSSL_read;
  fp_SSL_write: TSSL_write;
  fp_SSL_shutdown: TSSL_shutdown;
  fp_SSL_CTX_set_verify: TSSL_CTX_set_verify;
  fp_SSL_CTX_set_default_verify_paths: TSSL_CTX_set_default_verify_paths;
  fp_SSL_get_error: TSSL_get_error;
  fp_ERR_get_error: TERR_get_error;
  fp_ERR_error_string_n: TERR_error_string_n;
  fp_OpenSSL_version: TOpenSSL_version;

  fp_SSL_set1_host: TSSL_set1_host;
  fp_SSL_ctrl: TSSL_ctrl;
  fp_SSL_CTX_load_verify_locations: TSSL_CTX_load_verify_locations = nil;
  fp_OPENSSL_init_ssl: TOPENSSL_init_ssl;
  fp_SSL_get_verify_result: TSSL_get_verify_result;

  fp_SSL_CTX_use_certificate_chain_file: TSSL_CTX_use_certificate_chain_file;
  fp_SSL_CTX_use_PrivateKey_file: TSSL_CTX_use_PrivateKey_file;
  fp_SSL_CTX_check_private_key: TSSL_CTX_check_private_key;
  fp_SSL_accept: TSSL_accept;
  fp_TLS_server_method: TTLS_server_method;

  fp_SSL_do_handshake: TSSL_do_handshake = nil;
  fp_SSL_pending: TSSL_pending = nil;

// ════════════════════════════════════════════════════════════════
//  Library loading
// ════════════════════════════════════════════════════════════════

const
  SSL_CANDIDATES: array[0..7] of string = (
    'libssl.so.3',
    'libssl.so.1.1',
    '/data/data/com.termux/files/usr/lib/libssl.so.3',
    '/data/data/com.termux/files/usr/lib/libssl.so.1.1',
    '/data/data/com.termux/files/usr/lib/libssl.so',
    'libssl.so',
    '/system/lib64/libssl.so',
    '/usr/lib/x86_64-linux-gnu/libssl.so.3'
  );
  CA_BUNDLE_PATH = '/data/data/com.termux/files/usr/etc/tls/cert.pem';
  CRYPTO_CANDIDATES: array[0..7] of string = (
    'libcrypto.so.3',
    'libcrypto.so.1.1',
    '/data/data/com.termux/files/usr/lib/libcrypto.so.3',
    '/data/data/com.termux/files/usr/lib/libcrypto.so.1.1',
    '/data/data/com.termux/files/usr/lib/libcrypto.so',
    'libcrypto.so',
    '/system/lib64/libcrypto.so',
    '/usr/lib/x86_64-linux-gnu/libcrypto.so.3'
  );

function TryLoadFirst(const Candidates: array of string): TLibHandle;
var
  i: Integer;
begin
  Result := NilHandle;
  for i := 0 to High(Candidates) do
  begin
    Result := LoadLibrary(Candidates[i]);
    if Result <> NilHandle then
      Exit;
  end;
end;

function LoadSymbol(H: TLibHandle; const Name: PAnsiChar): Pointer;
begin
  Result := GetProcAddress(H, Name);
end;

function TLSInit: Boolean;
begin
  EnterCriticalSection(GInitLock);
  try
    if GLoaded then
    begin
      Inc(GInitCount);
      Exit(True);
    end;

    GLibCrypto := TryLoadFirst(CRYPTO_CANDIDATES);
    if GLibCrypto = NilHandle then
    begin
      LeaveCriticalSection(GInitLock);
      Exit(False);
    end;

    GLibSSL := TryLoadFirst(SSL_CANDIDATES);
    if GLibSSL = NilHandle then
    begin
      UnloadLibrary(GLibCrypto);
      GLibCrypto := NilHandle;
      LeaveCriticalSection(GInitLock);
      Exit(False);
    end;

    // ─── Bind symbol lama ───
    Pointer(fp_SSL_library_init) := LoadSymbol(GLibSSL, 'SSL_library_init');
    Pointer(fp_SSL_load_error_strings) := LoadSymbol(GLibSSL, 'SSL_load_error_strings');
    Pointer(fp_TLS_method) := LoadSymbol(GLibSSL, 'TLS_method');
    if not Assigned(fp_TLS_method) then
      Pointer(fp_TLS_method) := LoadSymbol(GLibSSL, 'SSLv23_method');
    Pointer(fp_TLS_client_method) := LoadSymbol(GLibSSL, 'TLS_client_method');
    Pointer(fp_SSL_CTX_new) := LoadSymbol(GLibSSL, 'SSL_CTX_new');
    Pointer(fp_SSL_CTX_free) := LoadSymbol(GLibSSL, 'SSL_CTX_free');
    Pointer(fp_SSL_new) := LoadSymbol(GLibSSL, 'SSL_new');
    Pointer(fp_SSL_free) := LoadSymbol(GLibSSL, 'SSL_free');
    Pointer(fp_SSL_set_fd) := LoadSymbol(GLibSSL, 'SSL_set_fd');
    Pointer(fp_SSL_set_tlsext_host_name) := LoadSymbol(GLibSSL, 'SSL_set_tlsext_host_name');
    Pointer(fp_SSL_connect) := LoadSymbol(GLibSSL, 'SSL_connect');
    Pointer(fp_SSL_read) := LoadSymbol(GLibSSL, 'SSL_read');
    Pointer(fp_SSL_write) := LoadSymbol(GLibSSL, 'SSL_write');
    Pointer(fp_SSL_shutdown) := LoadSymbol(GLibSSL, 'SSL_shutdown');
    Pointer(fp_SSL_CTX_set_verify) := LoadSymbol(GLibSSL, 'SSL_CTX_set_verify');
    Pointer(fp_SSL_CTX_set_default_verify_paths) := LoadSymbol(GLibSSL, 'SSL_CTX_set_default_verify_paths');
    Pointer(fp_SSL_get_error) := LoadSymbol(GLibSSL, 'SSL_get_error');
    Pointer(fp_ERR_get_error) := LoadSymbol(GLibCrypto, 'ERR_get_error');
    Pointer(fp_ERR_error_string_n) := LoadSymbol(GLibCrypto, 'ERR_error_string_n');
    Pointer(fp_OpenSSL_version) := LoadSymbol(GLibCrypto, 'OpenSSL_version');

    // ─── ✅ T-2a: binding baru ───
    Pointer(fp_SSL_set1_host) := LoadSymbol(GLibSSL, 'SSL_set1_host');
    Pointer(fp_SSL_ctrl) := LoadSymbol(GLibSSL, 'SSL_ctrl');   // ← tambah
    Pointer(fp_SSL_CTX_load_verify_locations) := LoadSymbol(GLibSSL, 'SSL_CTX_load_verify_locations');
    Pointer(fp_OPENSSL_init_ssl) := LoadSymbol(GLibSSL, 'OPENSSL_init_ssl');
    Pointer(fp_SSL_get_verify_result) := LoadSymbol(GLibSSL, 'SSL_get_verify_result');

    Pointer(fp_SSL_CTX_use_certificate_chain_file) := LoadSymbol(GLibSSL, 'SSL_CTX_use_certificate_chain_file');
    Pointer(fp_SSL_CTX_use_PrivateKey_file) := LoadSymbol(GLibSSL, 'SSL_CTX_use_PrivateKey_file');
    Pointer(fp_SSL_CTX_check_private_key) := LoadSymbol(GLibSSL, 'SSL_CTX_check_private_key');
    Pointer(fp_SSL_accept) := LoadSymbol(GLibSSL, 'SSL_accept');
    Pointer(fp_TLS_server_method) := LoadSymbol(GLibSSL, 'TLS_server_method');
    if not Assigned(fp_TLS_server_method) then
      Pointer(fp_TLS_server_method) := LoadSymbol(GLibSSL, 'SSLv23_server_method');
      
    // B.2: non-blocking bindings
    Pointer(fp_SSL_do_handshake) := LoadSymbol(GLibSSL, 'SSL_do_handshake');
    Pointer(fp_SSL_pending) := LoadSymbol(GLibSSL, 'SSL_pending');      
          
    // Validasi critical
    if not Assigned(fp_SSL_CTX_new) or not Assigned(fp_SSL_new) or
       not Assigned(fp_SSL_connect) or not Assigned(fp_TLS_method) then
    begin
      UnloadLibrary(GLibSSL);
      UnloadLibrary(GLibCrypto);
      GLibSSL := NilHandle;
      GLibCrypto := NilHandle;
      LeaveCriticalSection(GInitLock);
      Exit(False);
    end;

    // ─── ✅ T-2a: initialisasi OpenSSL 3.x aware ───
    // OpenSSL 3.x: SSL_library_init adalah no-op, init sebenarnya via
    // OPENSSL_init_ssl. OpenSSL 1.1.x: OPENSSL_init_ssl tidak ada,
    // pakai SSL_library_init + SSL_load_error_strings.
    if Assigned(fp_OPENSSL_init_ssl) then
    begin
      // Flag: OPENSSL_INIT_LOAD_SSL_STRINGS | OPENSSL_INIT_LOAD_CRYPTO_STRINGS
      fp_OPENSSL_init_ssl(QWord($00000002) or QWord($00000004), nil);
    end
    else if Assigned(fp_SSL_library_init) then
    begin
      fp_SSL_library_init();
      if Assigned(fp_SSL_load_error_strings) then
        fp_SSL_load_error_strings();
    end;

    GLoaded := True;
    GInitCount := 1;
    Result := True;
  finally
    LeaveCriticalSection(GInitLock);
  end;
end;

procedure TLSShutdown;
begin
  EnterCriticalSection(GInitLock);
  try
    if GInitCount = 0 then Exit;
    Dec(GInitCount);

    // ═══════════════════════════════════════════════════════════
    // ✅ T-2a: JANGAN UnloadLibrary(libssl/libcrypto)!
    //
    // Alasan:
    // 1. Kalau ada TTLSConnection yang masih hidup (worker thread yang
    //    telat cleanup, HTTP request yang crash sebelum close), vtable
    //    SSL_* akan dangling → SIGSEGV saat SSL_shutdown/SSL_free.
    // 2. Android/Termux: dlclose tidak reliable dengan linker namespace.
    // 3. OpenSSL punya atexit handler internal yang mereferensi symbol
    //    saat proses exit → unload menyebabkan use-after-unload.
    // 4. Node.js, Python, Go, dan mayoritas runtime scripting juga
    //    TIDAK unload libssl saat runtime shutdown.
    //
    // Yang kita lakukan:
    // - GInitCount decrement (untuk lifecycle bookkeeping)
    // - JANGAN clear GLoaded
    // - JANGAN clear function pointers
    // - JANGAN UnloadLibrary
    //
    // Efek: proses bisa shutdown dengan aman, dan TLSInit bisa
    // dipanggil lagi tanpa re-bind (GLoaded masih true).
    // ═══════════════════════════════════════════════════════════
  finally
    LeaveCriticalSection(GInitLock);
  end;
end;

function TLSIsLoaded: Boolean;
begin
  Result := (GLibSSL <> NilHandle) and (GLibCrypto <> NilHandle);
end;

function TLSVersion: string;
var
  P: PAnsiChar;
begin
  Result := 'unknown';
  if not TLSIsLoaded then Exit;
  if Assigned(fp_OpenSSL_version) then
  begin
    P := fp_OpenSSL_version(0);  // OPENSSL_VERSION = 0
    if Assigned(P) then
      Result := string(P);
  end;
end;

function TLSLastError: string;
var
  E: Cardinal;
  Buf: array[0..255] of AnsiChar;
begin
  Result := '';
  if not TLSIsLoaded then Exit('libssl not loaded');
  if Assigned(fp_ERR_get_error) and Assigned(fp_ERR_error_string_n) then
  begin
    E := fp_ERR_get_error();
    if E = 0 then Exit('');
    fp_ERR_error_string_n(E, @Buf[0], SizeOf(Buf));
    Result := string(AnsiString(PAnsiChar(@Buf[0])));
  end;
end;

function TLSVerifyErrorString(Code: LongInt): string;
begin
  case Code of
    0:  Result := 'OK';
    2:  Result := 'UNABLE_TO_GET_ISSUER_CERT';
    10: Result := 'CERT_HAS_EXPIRED';
    18: Result := 'DEPTH_ZERO_SELF_SIGNED_CERT';
    19: Result := 'SELF_SIGNED_CERT_IN_CHAIN';
    20: Result := 'UNABLE_TO_GET_ISSUER_CERT_LOCALLY';
    21: Result := 'UNABLE_TO_VERIFY_LEAF_SIGNATURE';
    26: Result := 'UNSPECIFIED_CERTIFICATE_ERROR';
    62: Result := 'HOSTNAME_MISMATCH';
    66: Result := 'EE_CERTIFICATE_HAS_EXPIRED';
  else
    Result := 'code_' + IntToStr(Code);
  end;
end;

// ════════════════════════════════════════════════════════════════
//  TTLSContext
// ════════════════════════════════════════════════════════════════

const
  SSL_VERIFY_NONE = 0;
  SSL_VERIFY_PEER = 1;

constructor TTLSContext.Create(AVerifyPeer: Boolean);
var
  Method: Pointer;
begin
  inherited Create;
  FRefCount := 1;
  CtxPtr := nil;
  VerifyPeer := AVerifyPeer;   // ✅ FASE 0.8
  
  if not TLSIsLoaded then Exit;
  
  if Assigned(fp_TLS_client_method) then
    Method := fp_TLS_client_method()
  else if Assigned(fp_TLS_method) then
    Method := fp_TLS_method()
  else
    Exit;
  
  if Method = nil then Exit;
  
  CtxPtr := fp_SSL_CTX_new(Method);
  if CtxPtr = nil then Exit;
  
  if AVerifyPeer then
  begin
    // 1. Coba deteksi otomatis (biasanya untuk Linux desktop)
    if Assigned(fp_SSL_CTX_set_default_verify_paths) then
      fp_SSL_CTX_set_default_verify_paths(CtxPtr);
  
    // 2. Override dengan path CA Termux yang eksplisit.
    //    Ini WAJIB di Android/Termux karena OpenSSL tidak tahu
    //    lokasi CA bundle-nya sendiri.
    if Assigned(fp_SSL_CTX_load_verify_locations) then
    begin
      if not FileExists(CA_BUNDLE_PATH) then
      begin
        // Fallback: coba beberapa path umum lain
        // (biarkan kosong, karena tujuannya untuk desktop/Linux)
      end;
      fp_SSL_CTX_load_verify_locations(CtxPtr, PAnsiChar(AnsiString(CA_BUNDLE_PATH)), nil);
    end;
  
    if Assigned(fp_SSL_CTX_set_verify) then
      fp_SSL_CTX_set_verify(CtxPtr, SSL_VERIFY_PEER, nil);
  end
  else
  begin
    if Assigned(fp_SSL_CTX_set_verify) then
      fp_SSL_CTX_set_verify(CtxPtr, SSL_VERIFY_NONE, nil);
  end;
end;

destructor TTLSContext.Destroy;
begin
  if Assigned(CtxPtr) and Assigned(fp_SSL_CTX_free) then
    fp_SSL_CTX_free(CtxPtr);
  CtxPtr := nil;
  inherited;
end;

procedure TTLSContext.Retain;
begin
  InterlockedIncrement(FRefCount);
end;

procedure TTLSContext.Release;
begin
  if InterlockedDecrement(FRefCount) = 0 then
    Self.Free;
end;

//TLSServerContext≠===================================
//====================================================
constructor TLSServerContext.Create(const CertPath, KeyPath: string);
const PEM = 1;   // SSL_FILETYPE_PEM
var
  Method: Pointer;
  CertA, KeyA: AnsiString;
begin
  inherited Create;
  FRefCount := 1;
  CtxPtr := nil;
  LastError := '';
  
  if not TLSIsLoaded then
  begin
    LastError := 'libssl tidak ter-load';
    Exit;
  end;
  
  if not Assigned(fp_TLS_server_method) then
  begin
    LastError := 'TLS_server_method tidak tersedia';
    Exit;
  end;
  
  Method := fp_TLS_server_method();
  if Method = nil then
  begin
    LastError := 'TLS_server_method return nil';
    Exit;
  end;
  
  CtxPtr := fp_SSL_CTX_new(Method);
  if CtxPtr = nil then
  begin
    LastError := 'SSL_CTX_new gagal';
    Exit;
  end;
  
  CertA := AnsiString(CertPath);
  KeyA := AnsiString(KeyPath);
  
  if not Assigned(fp_SSL_CTX_use_certificate_chain_file) then
  begin
    LastError := 'SSL_CTX_use_certificate_chain_file tidak tersedia';
    fp_SSL_CTX_free(CtxPtr);
    CtxPtr := nil;
    Exit;
  end;
  
  if fp_SSL_CTX_use_certificate_chain_file(CtxPtr, PAnsiChar(CertA)) <> 1 then
  begin
    LastError := 'Gagal load certificate: ' + CertPath;
    fp_SSL_CTX_free(CtxPtr);
    CtxPtr := nil;
    Exit;
  end;
  
  if fp_SSL_CTX_use_PrivateKey_file(CtxPtr, PAnsiChar(KeyA), PEM) <> 1 then
  begin
    LastError := 'Gagal load private key: ' + KeyPath;
    fp_SSL_CTX_free(CtxPtr);
    CtxPtr := nil;
    Exit;
  end;
  
  if fp_SSL_CTX_check_private_key(CtxPtr) <> 1 then
  begin
    LastError := 'Private key tidak cocok dengan certificate';
    fp_SSL_CTX_free(CtxPtr);
    CtxPtr := nil;
    Exit;
  end;
  
  LastError := '';
end;

destructor TLSServerContext.Destroy;
begin
  if Assigned(CtxPtr) and Assigned(fp_SSL_CTX_free) then
    fp_SSL_CTX_free(CtxPtr);
  CtxPtr := nil;
  inherited;
end;

procedure TLSServerContext.Retain;
begin
  InterlockedIncrement(FRefCount);
end;

procedure TLSServerContext.Release;
begin
  if InterlockedDecrement(FRefCount) = 0 then
    Self.Free;
end;

function TLSServerContext.IsValid: Boolean;
begin
  Result := Assigned(CtxPtr);
end;

// ════════════════════════════════════════════════════════════════
//  TTLSConnection
// ════════════════════════════════════════════════════════════════

constructor TTLSConnection.Create(ACtx: TTLSContext; ASockFd: Integer);
begin
  inherited Create;
  FRefCount := 1;
  SSLPtr := nil;
  Ctx := ACtx;
  if Assigned(Ctx) then Ctx.Retain;
  SockFd := ASockFd;
  HandshakeDone := False;
  LastError := '';
end;

destructor TTLSConnection.Destroy;
begin
  if Assigned(SSLPtr) and Assigned(fp_SSL_free) then
    fp_SSL_free(SSLPtr);
  SSLPtr := nil;
  if Assigned(Ctx) then Ctx.Release;
  inherited;
end;

procedure TTLSConnection.Retain;
begin
  InterlockedIncrement(FRefCount);
end;

procedure TTLSConnection.Release;
begin
  if InterlockedDecrement(FRefCount) = 0 then
    Self.Free;
end;

// ════════════════════════════════════════════════════════════════
//  Connect / Send / Recv
// ════════════════════════════════════════════════════════════════

function WaitSocketReadable(Fd, TimeoutMs: Integer): Boolean;
var
  FDS: TFDSet;
  TV: TTimeVal;
  R: Integer;
begin
  fpFD_ZERO(FDS);
  fpFD_SET(Fd, FDS);
  TV.tv_sec := TimeoutMs div 1000;
  TV.tv_usec := (TimeoutMs mod 1000) * 1000;
  R := fpSelect(Fd + 1, @FDS, nil, nil, @TV);
  Result := R > 0;
end;

function TLSConnect(Ctx: TTLSContext; SockFd: Integer;
    const ServerName: string;
    out Conn: TTLSConnection): Boolean;
var
  R: Integer;
  SNI: AnsiString;
  VerifyResult: LongInt;
begin
  Result := False;
  
  // ✅ FIX: SELALU create Conn, bahkan sebelum validasi. Ini memastikan
  // `Conn.LastError` selalu valid di caller, dan caller dapat membaca
  // pesan error yang jelas, bukan AV.
  Conn := TTLSConnection.Create(Ctx, SockFd);
  
  if not Assigned(Ctx) or (Ctx.CtxPtr = nil) then
  begin
    Conn.LastError := 'TLS context invalid';
    Exit;
  end;
  
  Conn.SSLPtr := fp_SSL_new(Ctx.CtxPtr);
  if Conn.SSLPtr = nil then
  begin
    Conn.LastError := 'SSL_new failed: ' + TLSLastError;
    Exit;
  end;
  
  if fp_SSL_set_fd(Conn.SSLPtr, SockFd) <> 1 then
  begin
    Conn.LastError := 'SSL_set_fd failed';
    Exit;
  end;
  
  // ─── SNI (Server Name Indication) ───
  if ServerName <> '' then
  begin
    SNI := AnsiString(ServerName);
    if Assigned(fp_SSL_set_tlsext_host_name) then
    begin
      fp_SSL_set_tlsext_host_name(Conn.SSLPtr, PAnsiChar(SNI));
      {$IFDEF TLS_DEBUG}
      WriteLn(ErrOutput, '[tls] SNI via SSL_set_tlsext_host_name: ', ServerName);
      {$ENDIF}
    end
    else if Assigned(fp_SSL_ctrl) then
    begin
      fp_SSL_ctrl(Conn.SSLPtr, 55 { SSL_CTRL_SET_TLSEXT_HOSTNAME },
                  0 { TLSEXT_NAMETYPE_host_name }, PAnsiChar(SNI));
      {$IFDEF TLS_DEBUG}
      WriteLn(ErrOutput, '[tls] SNI via SSL_ctrl: ', ServerName);
      {$ENDIF}
    end;
  end;
  
  // ─── Hostname verification (SSL_set1_host) ───
  // ✅ FASE 0.8: hanya aktifkan hostname check bila verify di-aktifkan.
  if Ctx.VerifyPeer and (ServerName <> '') and Assigned(fp_SSL_set1_host) then
  begin
    SNI := AnsiString(ServerName);
    if fp_SSL_set1_host(Conn.SSLPtr, PAnsiChar(SNI)) <> 1 then
    begin
      Conn.LastError := 'SSL_set1_host failed untuk ' + ServerName;
      Exit;
    end;
  end;
  
  // ─── Handshake ───
  R := fp_SSL_connect(Conn.SSLPtr);
  if R <> 1 then
  begin
    Conn.LastError := 'SSL_connect failed (ret=' + IntToStr(R) + '): ' +
                      TLSLastError;
    Exit;   // ← Conn tetap valid
  end;
  
  // ─── Verify result (chain + hostname) ───
  // ✅ FASE 0.8: hanya cek bila VerifyPeer aktif. SSL_get_verify_result
  //    selalu melaporkan hasil verifikasi chain meski SSL_VERIFY_NONE
  //    di-set di context — jadi flag harus di-gate di sini.
  if Ctx.VerifyPeer and (ServerName <> '') and Assigned(fp_SSL_get_verify_result) then
  begin
    VerifyResult := fp_SSL_get_verify_result(Conn.SSLPtr);
    if VerifyResult <> 0 then
    begin
      Conn.LastError := Format('Certificate verify failed (code=%d, %s) untuk %s',
                               [VerifyResult, TLSVerifyErrorString(VerifyResult), 
                                ServerName]);
      Exit;
    end;
  end;
  
  Conn.HandshakeDone := True;
  Result := True;
end;

function TLSAccept(Ctx: TLSServerContext; SockFd: Integer;
                   out Conn: TTLSConnection): Boolean;
var
  R: Integer;
begin
  Result := False;
  Conn := TTLSConnection.Create(nil, SockFd);   // client ctx nil — server pakai ctx ini
  
  if not Assigned(Ctx) or (Ctx.CtxPtr = nil) then
  begin
    Conn.LastError := 'Server TLS context invalid';
    Exit;
  end;
  
  Conn.SSLPtr := fp_SSL_new(Ctx.CtxPtr);
  if Conn.SSLPtr = nil then
  begin
    Conn.LastError := 'SSL_new failed: ' + TLSLastError;
    Exit;
  end;
  
  if fp_SSL_set_fd(Conn.SSLPtr, SockFd) <> 1 then
  begin
    Conn.LastError := 'SSL_set_fd failed';
    Exit;
  end;
  
  R := fp_SSL_accept(Conn.SSLPtr);
  if R <> 1 then
  begin
    Conn.LastError := 'SSL_accept failed (ret=' + IntToStr(R) + '): ' + TLSLastError;
    Exit;
  end;
  
  Conn.HandshakeDone := True;
  Result := True;
end;

function TLSSend(Conn: TTLSConnection; const Data: RawByteString): Integer;
var
  Total, W: Integer;
  P: PByte;
begin
  Result := -1;
  if not Assigned(Conn) or not Conn.HandshakeDone then Exit;
  if Length(Data) = 0 then Exit(0);
  
  Total := 0;
  P := @Data[1];
  while Total < Length(Data) do
  begin
    W := fp_SSL_write(Conn.SSLPtr, P, Length(Data) - Total);
    if W <= 0 then
    begin
      Conn.LastError := 'SSL_write failed: ' + TLSLastError;
      Exit(-1);
    end;
    Inc(Total, W);
    Inc(P, W);
  end;
  Result := Total;
end;

function TLSRecv(Conn: TTLSConnection; MaxBytes: Integer;
                 out Data: RawByteString): Integer;
var
  Buf: array[0..16383] of Byte;
  R, Cap, Er, Retry: Integer;
begin
  Result := -1;
  Data := '';
  if not Assigned(Conn) or not Conn.HandshakeDone then Exit;

  Cap := MaxBytes;
  if Cap <= 0 then Cap := 4096;
  if Cap > SizeOf(Buf) then Cap := SizeOf(Buf);

  // ✅ T-2a: retry loop untuk WANT_READ/WANT_WRITE
  Retry := 0;
  while Retry < 100 do
  begin
    if not WaitSocketReadable(Conn.SockFd, 30000) then
    begin
      Conn.LastError := 'SSL_recv: timeout';
      Exit(-1);
    end;

    R := fp_SSL_read(Conn.SSLPtr, @Buf[0], Cap);
    if R > 0 then
    begin
      SetLength(Data, R);
      Move(Buf[0], Data[1], R);
      Exit(R);
    end;

    Er := fp_SSL_get_error(Conn.SSLPtr, R);
    case Er of
      6: Exit(0);          // SSL_ERROR_ZERO_RETURN — clean close
      2, 3:                // WANT_READ / WANT_WRITE — retry
        begin
          Inc(Retry);
          Continue;
        end;
      else
      begin
        Conn.LastError := 'SSL_read failed (ret=' + IntToStr(R) +
                          ', err=' + IntToStr(Er) + '): ' + TLSLastError;
        Exit(-1);
      end;
    end;
  end;

  Conn.LastError := 'SSL_recv: max retry exceeded';
  Exit(-1);
end;

function TLSRecvTimeout(Conn: TTLSConnection; MaxBytes, TimeoutMs: Integer;
            out Data: RawByteString): Integer;
var
  Buf: array[0..16383] of Byte;
  R, Cap, Er, Retry: Integer;
begin
  Result := -1;
  Data := '';
  if not Assigned(Conn) or not Conn.HandshakeDone then Exit;

  Cap := MaxBytes;
  if Cap <= 0 then Cap := 4096;
  if Cap > SizeOf(Buf) then Cap := SizeOf(Buf);

  Retry := 0;
  while Retry < 100 do
  begin
    if not WaitSocketReadable(Conn.SockFd, TimeoutMs) then
    begin
      Conn.LastError := 'SSL_recv: timeout';
      Exit(-1);
    end;

    R := fp_SSL_read(Conn.SSLPtr, @Buf[0], Cap);
    if R > 0 then
    begin
      SetLength(Data, R);
      Move(Buf[0], Data[1], R);
      Exit(R);
    end;

    Er := fp_SSL_get_error(Conn.SSLPtr, R);
    case Er of
      6: Exit(0);          // SSL_ERROR_ZERO_RETURN
      2, 3: Inc(Retry);    // WANT_READ / WANT_WRITE
      else
      begin
        Conn.LastError := 'SSL_read failed (ret=' + IntToStr(R) +
                          ', err=' + IntToStr(Er) + '): ' + TLSLastError;
        Exit(-1);
      end;
    end;
  end;

  Conn.LastError := 'SSL_recv: max retry exceeded';
  Exit(-1);
end;

procedure TLSClose(Conn: TTLSConnection);
begin
  if not Assigned(Conn) then Exit;
  if Conn.HandshakeDone and Assigned(fp_SSL_shutdown) then
  begin
    try
      fp_SSL_shutdown(Conn.SSLPtr);
    except
    end;
  end;
  // SSL handle bebas saat Conn di-free
end;

{ ═══════════════════════════════════════════════════════════════
  B.2: Non-blocking TLS operations
  ═══════════════════════════════════════════════════════════════ }

function TLSNonBlockingHandshake(Conn: TTLSConnection): TTLSNBStatus;
var
  R, Er: Integer;
begin
  if not Assigned(Conn) or not Assigned(Conn.SSLPtr) then
    Exit(tlsnbError);
  if not Assigned(fp_SSL_accept) then
  begin
    Conn.LastError := 'SSL_accept tidak ter-bind';
    Exit(tlsnbError);
  end;

  // ✅ SSL_accept (bukan SSL_do_handshake):
  //   SSL_accept internal: set_accept_state() + do_handshake()
  //   SSL_do_handshake tanpa state = error 0A000090
  R := fp_SSL_accept(Conn.SSLPtr);
  if R = 1 then
  begin
    Conn.HandshakeDone := True;
    Exit(tlsnbDone);
  end;
  
  Er := fp_SSL_get_error(Conn.SSLPtr, R);
  case Er of
    2: Result := tlsnbWantRead;
    3: Result := tlsnbWantWrite;
    6: Result := tlsnbClosed;   // ZERO_RETURN selama handshake
  else
    begin
      Conn.LastError := Format('handshake failed (ret=%d err=%d): %s',
                               [R, Er, TLSLastError]);
      Result := tlsnbError;
    end;
  end;
end;

function TLSNonBlockingRead(Conn: TTLSConnection; Buf: Pointer;
  MaxLen: Integer;
  out BytesRead: Integer): TTLSNBStatus;
var
  R, Er: Integer;
begin
  BytesRead := 0;
  if not Assigned(Conn) or not Assigned(Conn.SSLPtr) then
    Exit(tlsnbError);
  if MaxLen <= 0 then
    Exit(tlsnbDone);

  R := fp_SSL_read(Conn.SSLPtr, Buf, MaxLen);
  if R > 0 then
  begin
    BytesRead := R;
    Exit(tlsnbDone);
  end;

  Er := fp_SSL_get_error(Conn.SSLPtr, R);
  case Er of
    0: Result := tlsnbClosed;   // tidak ada error tapi R<=0 → EOF
    2: Result := tlsnbWantRead;
    3: Result := tlsnbWantWrite;
    6: Result := tlsnbClosed;   // ZERO_RETURN
  else
    begin
      Conn.LastError := Format('read failed (ret=%d err=%d): %s',
                               [R, Er, TLSLastError]);
      Result := tlsnbError;
    end;
  end;
end;

function TLSNonBlockingWrite(Conn: TTLSConnection; Buf: Pointer;
  Len: Integer;
  out BytesWritten: Integer): TTLSNBStatus;
var
  R, Er: Integer;
begin
  BytesWritten := 0;
  if not Assigned(Conn) or not Assigned(Conn.SSLPtr) then
    Exit(tlsnbError);
  if Len <= 0 then
    Exit(tlsnbDone);

  R := fp_SSL_write(Conn.SSLPtr, Buf, Len);
  if R > 0 then
  begin
    BytesWritten := R;
    Exit(tlsnbDone);
  end;

  Er := fp_SSL_get_error(Conn.SSLPtr, R);
  case Er of
    2: Result := tlsnbWantRead;
    3: Result := tlsnbWantWrite;
    6: Result := tlsnbClosed;
  else
    begin
      Conn.LastError := Format('write failed (ret=%d err=%d): %s',
                               [R, Er, TLSLastError]);
      Result := tlsnbError;
    end;
  end;
end;

function TLSNonBlockingPending(Conn: TTLSConnection): Integer;
begin
  if not Assigned(Conn) or not Assigned(Conn.SSLPtr)
     or not Assigned(fp_SSL_pending) then
    Exit(0);
  Result := fp_SSL_pending(Conn.SSLPtr);
end;

function TLSAcceptInit(ServerCtx: TLSServerContext; SockFd: Integer;
  out Conn: TTLSConnection): Boolean;
begin
  Result := False;
  Conn := nil;

  if not Assigned(ServerCtx) or not ServerCtx.IsValid then Exit;
  if not Assigned(fp_SSL_new) or not Assigned(fp_SSL_set_fd) then Exit;

  Conn := TTLSConnection.Create(nil, SockFd);
  Conn.SSLPtr := fp_SSL_new(ServerCtx.CtxPtr);
  if Conn.SSLPtr = nil then
  begin
    Conn.LastError := 'SSL_new failed: ' + TLSLastError;
    Conn.Free;
    Conn := nil;
    Exit;
  end;

  if fp_SSL_set_fd(Conn.SSLPtr, SockFd) <> 1 then
  begin
    Conn.LastError := 'SSL_set_fd failed';
    Conn.Free;
    Conn := nil;
    Exit;
  end;

  // Handshake belum dijalankan — caller harus drive via
  // TLSNonBlockingHandshake berulang.
  Conn.HandshakeDone := False;
  Result := True;
end;

initialization
  InitCriticalSection(GInitLock);

finalization
  // Force cleanup jika user lupa panggil TLSShutdown
  while GInitCount > 0 do
    TLSShutdown;
  DoneCriticalSection(GInitLock);

end.