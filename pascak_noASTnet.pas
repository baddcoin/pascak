{$MODE OBJFPC}{$H+}
{$INTERFACES CORBA}
program pascak;
uses
  {$IFDEF UNIX} 
    cthreads, BaseUnix,
  {$ENDIF} 
  {$IFDEF WINDOWS}
    Windows,      
  {$ENDIF}


  Classes, SysUtils, fgl, contnrs, StrUtils,
  math, syncobjs, dateutils,dynlibs, TypInfo,
  fpjson, jsonparser,
  sha1, regexpr,base64,md5,
  sqldb, sqlite3conn, sqlite3dyn, db,
  
  pascak_net,
  pascak_proc,
  pascak_crypto,
  pascak_http,
  pascak_fs,
  pascak_time,
  pascak_tls,
  pascak_h2,
  pascak_h2_hpack,
  pascak_h2_conn,
  pascak_websocket,
  paszlib,
  pascak_wsevloop,
  pascak_pkg,
  pascak_pkg_registry;  

{$I pascak_engine.inc}

var
  DebugMode: Boolean;
  ScriptArg: string;
  ArgIdx: Integer;
  ReplMode: Boolean;
  LspMode: Boolean;
  LspServer: TLspServer;
  TestMode: Boolean;
  FmtMode: Boolean;
  FmtCheck: Boolean;
  LintMode: Boolean;
  LintStrict: Boolean;

begin
  cscript := scriptTest;
  
  SetExceptionMask([exInvalidOp, exDenormalized, exZeroDivide, exOverflow, exUnderflow, exPrecision]);
  Randomize;
  
  // ✅ TAHAP D-1: parse CLI args
  DebugMode := False;
  ScriptArg := '';
  ReplMode := False;
  LspMode := False;
  TestMode := False;
  FmtMode := False;
  FmtCheck := False;  
  LintMode := False;
  LintStrict := False;
  
  ArgIdx := 1;
  while ArgIdx <= ParamCount do
  begin
    if ParamStr(ArgIdx) = '--debug' then
      DebugMode := True
    else if ParamStr(ArgIdx) = '--dev' then
      GDangerousEnvAllowed := True
    else if ParamStr(ArgIdx) = '--repl' then
      ReplMode := True
    else if ParamStr(ArgIdx) = '--lsp' then
      LspMode := True
    else if ParamStr(ArgIdx) = '--test' then
      TestMode := True    
    else if ParamStr(ArgIdx) = '--fmt' then
      FmtMode := True
    else if ParamStr(ArgIdx) = '--check' then
      FmtCheck := True    
    else if ParamStr(ArgIdx) = '--lint' then
      LintMode := True
    else if ParamStr(ArgIdx) = '--strict' then
      LintStrict := True    
    else if ScriptArg = '' then
      ScriptArg := ParamStr(ArgIdx);
    Inc(ArgIdx);
  end;
  
  if GDangerousEnvAllowed and (GetEnvironmentVariable('PASCAK_DEBUG') = '1') then
  begin
    Writeln('[boot] DEV MODE — env overrides enabled ' +
            '(PASCAK_EXEC_POLICY, PASCAK_TLS_NO_VERIFY)');
  end;

  // E.2 — Linter mode
  if LintMode then
  begin
    if ScriptArg = '' then
    begin
      Writeln('Usage: pascak --lint <file|dir> [--strict]');
      {$IFDEF UNIX} libc__exit(2); {$ELSE} Halt(2); {$ENDIF}
    end;
    RunLintMode(ScriptArg, LintStrict);
    {$IFDEF UNIX} libc__exit(0); {$ELSE} Halt(0); {$ENDIF}
  end;

  // E.1 — Formatter mode
  if FmtMode then
  begin
    if ScriptArg = '' then
    begin
      Writeln('Usage: pascak --fmt <file|dir> [--check]');
      {$IFDEF UNIX} libc__exit(2); {$ELSE} Halt(2); {$ENDIF}
    end;
    RunFormatMode(ScriptArg, FmtCheck);
    {$IFDEF UNIX} libc__exit(0); {$ELSE} Halt(0); {$ENDIF}
  end;
  
  // E.5 — Test mode
  if TestMode then
  begin
    NetInit;
    ProcInit;
    try
      RunTestMode(GetCurrentDir, ScriptArg);
    finally
      ProcShutdown;
      NetShutdown;
    end;
    {$IFDEF UNIX}
    libc__exit(0);
    {$ELSE}
    Halt(0);
    {$ENDIF}
  end;
  
  // E.4 Phase 2a — LSP mode
  if LspMode then
  begin
    LspServer := TLspServer.Create;
    try
      LspServer.Run;
    finally
      LspServer.Free;
    end;
    Flush(Output);
    Flush(ErrOutput);
    {$IFDEF UNIX}
    libc__exit(0);
    {$ELSE}
    Halt(0);
    {$ENDIF}
  end;

  // B.3 — REPL mode
  if ReplMode then
  begin
    NetInit;
    ProcInit;
    try
      RunREPL;
    finally
      ProcShutdown;
      NetShutdown;
    end;
    {$IFDEF UNIX}
    libc__exit(0);
    {$ELSE}
    Halt(0);
    {$ENDIF}
  end;
  
  if ScriptArg <> '' then
    FileName := ScriptArg
  else 
    FileName := './storage/downloads/test.pas';
  
  if SysUtils.FileExists(FileName) then
    Script := LoadScriptFromFile(FileName)
  else 
    Script := cScript;
  
  if Script = '' then
    Writeln(FileName + ' [script null]')
  else 
    runScript(Script, DebugMode);
end.
