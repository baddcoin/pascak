program test_pkg_registry;

{$MODE OBJFPC}{$H+}
{$INTERFACES CORBA}

uses
  SysUtils, Classes, pascak_pkg, pascak_pkg_registry;

var
  GPassed: Integer = 0;
  GFailed: Integer = 0;
  GTempDir: string;

procedure Check(const Name: string; Cond: Boolean);
begin
  if Cond then begin Inc(GPassed); WriteLn('  [OK]   ', Name); end
  else begin Inc(GFailed); WriteLn('  [FAIL] ', Name); end;
end;

procedure CheckEqStr(const Name, Expected, Actual: string);
begin
  if Expected = Actual then begin Inc(GPassed); WriteLn('  [OK]   ', Name); end
  else begin
    Inc(GFailed);
    WriteLn('  [FAIL] ', Name, ' — expected [', Expected, '], got [', Actual, ']');
  end;
end;

procedure CheckEqInt(const Name: string; Expected, Actual: Integer);
begin
  if Expected = Actual then begin Inc(GPassed); WriteLn('  [OK]   ', Name); end
  else begin
    Inc(GFailed);
    WriteLn('  [FAIL] ', Name, ' — expected ', Expected, ', got ', Actual);
  end;
end;

// ─── Test fixtures ───

procedure SetupTempDir;
var
  BaseDir: string;
begin
  // Termux tidak punya write access ke /data/local/tmp/.
  // Pakai $HOME (ext4) sebagai base.
  BaseDir := GetEnvironmentVariable('HOME');
  if BaseDir = '' then
    BaseDir := GetEnvironmentVariable('TMPDIR');
  if BaseDir = '' then
    BaseDir := '/data/data/com.termux/files/usr/tmp';
  if BaseDir = '' then
    BaseDir := GetCurrentDir;

  GTempDir := IncludeTrailingPathDelimiter(BaseDir) +
              '.cache' + PathDelim +
              'pascak_registry_test_' + IntToStr(Random(100000));
  if not ForceDirectories(GTempDir) then
  begin
    WriteLn('FATAL: tidak bisa membuat temp dir: ', GTempDir);
    Halt(99);
  end;
end;

procedure WriteTextFile(const Path, Content: string);
var
  F: TFileStream;
begin
  ForceDirectories(ExtractFileDir(Path));
  F := TFileStream.Create(Path, fmCreate);
  try
    if Length(Content) > 0 then
      F.WriteBuffer(Content[1], Length(Content));
  finally
    F.Free;
  end;
end;

procedure CreateLocalPkg(const Name, Version, Extra: string);
var
  PkgDir, Manifest: string;
begin
  PkgDir := IncludeTrailingPathDelimiter(GTempDir) + Name +
            PathDelim + Version;
  ForceDirectories(PkgDir);
  Manifest := '{"name":"' + Name + '","version":"' + Version + '"' +
              Extra + '}';
  WriteTextFile(IncludeTrailingPathDelimiter(PkgDir) + 'pascak.json', Manifest);
end;

procedure CleanupTempDir;
var
  SR: TSearchRec;

  procedure RemoveRec(const Dir: string);
  var
    SR2: TSearchRec;
    FullPath: string;
  begin
    if FindFirst(IncludeTrailingPathDelimiter(Dir) + '*', faAnyFile, SR2) = 0 then
    begin
      try
        repeat
          if (SR2.Name = '.') or (SR2.Name = '..') then Continue;
          FullPath := IncludeTrailingPathDelimiter(Dir) + SR2.Name;
          if (SR2.Attr and faDirectory) <> 0 then
            RemoveRec(FullPath)
          else
            DeleteFile(FullPath);
        until FindNext(SR2) <> 0;
      finally
        FindClose(SR2);
      end;
    end;
    RemoveDir(Dir);
  end;

begin
  if DirectoryExists(GTempDir) then
    RemoveRec(GTempDir);
end;

// ═══════════════════════════════════════════════════════════════
//  Test 1: GetVersions
// ═══════════════════════════════════════════════════════════════
procedure TestGetVersions;
var
  Reg: TPSLocalRegistry;
  V: TPSVersionArray;
begin
  WriteLn('Test 1: Local GetVersions');

  CreateLocalPkg('@a/lib', '1.0.0', '');
  CreateLocalPkg('@a/lib', '1.5.0', '');
  CreateLocalPkg('@a/lib', '2.0.0', '');
  CreateLocalPkg('simple', '0.1.0', '');

  Reg := TPSLocalRegistry.Create(GTempDir);
  try
    V := Reg.GetVersions('@a/lib');
    CheckEqInt('@a/lib 3 versions', 3, Length(V));
    CheckEqStr('sorted: 1.0.0', '1.0.0', PSVersionToString(V[0]));
    CheckEqStr('sorted: 1.5.0', '1.5.0', PSVersionToString(V[1]));
    CheckEqStr('sorted: 2.0.0', '2.0.0', PSVersionToString(V[2]));

    V := Reg.GetVersions('simple');
    CheckEqInt('simple 1 version', 1, Length(V));

    V := Reg.GetVersions('@missing/pkg');
    CheckEqInt('missing → empty', 0, Length(V));
  finally
    Reg.Free;
  end;
end;

// ═══════════════════════════════════════════════════════════════
//  Test 2: GetManifest
// ═══════════════════════════════════════════════════════════════
procedure TestGetManifest;
var
  Reg: TPSLocalRegistry;
  M: TPSManifest;
begin
  WriteLn('Test 2: Local GetManifest');

  CreateLocalPkg('@a/lib', '1.2.3',
    ',"main":"src/index.pas","license":"MIT",' +
    '"dependencies":{"@a/other":"^1.0.0"}');

  Reg := TPSLocalRegistry.Create(GTempDir);
  try
    M := Reg.GetManifest('@a/lib', '1.2.3');
    Check('found manifest', Assigned(M));
    if Assigned(M) then
    begin
      try
        CheckEqStr('name', '@a/lib', M.Name);
        CheckEqStr('version', '1.2.3', M.Version);
        CheckEqStr('main', 'src/index.pas', M.Main);
        CheckEqStr('license', 'MIT', M.License);
        CheckEqInt('1 dep', 1, M.Dependencies.Count);
      finally
        M.Free;
      end;
    end;

    M := Reg.GetManifest('@a/lib', '9.9.9');
    Check('missing version → nil', not Assigned(M));
  finally
    Reg.Free;
  end;
end;

// ═══════════════════════════════════════════════════════════════
//  Test 3: GetIntegrity
// ═══════════════════════════════════════════════════════════════
procedure TestGetIntegrity;
var
  Reg: TPSLocalRegistry;
  Hash: string;
begin
  WriteLn('Test 3: Local GetIntegrity');

  CreateLocalPkg('@a/lib', '1.0.0', '');

  Reg := TPSLocalRegistry.Create(GTempDir);
  try
    Hash := Reg.GetIntegrity('@a/lib', '1.0.0');
    Check('hash not empty', Hash <> '');
    Check('hash starts with sha256-', Pos('sha256-', Hash) = 1);

    // Deterministic
    CheckEqStr('deterministic', Hash, Reg.GetIntegrity('@a/lib', '1.0.0'));

    Hash := Reg.GetIntegrity('@a/missing', '1.0.0');
    Check('missing → empty', Hash = '');
  finally
    Reg.Free;
  end;
end;

// ═══════════════════════════════════════════════════════════════
//  Test 4: End-to-end — resolver + local registry
// ═══════════════════════════════════════════════════════════════
procedure TestEndToEnd;
var
  Reg: TPSLocalRegistry;
  Root: TPSManifest;
  Resolver: TPSResolver;
  L: TPSLockfile;
  Err: string;
  R: TPSResolved;
begin
  WriteLn('Test 4: End-to-end — local registry + resolver');

  // Setup: app → @a/x ^1.0.0 → @a/z ^1.0.0
  CreateLocalPkg('@a/x', '1.0.0',
    ',"dependencies":{"@a/z":"^1.0.0"}');
  CreateLocalPkg('@a/z', '1.0.0', '');
  CreateLocalPkg('@a/z', '1.5.0', '');

  Reg := TPSLocalRegistry.Create(GTempDir);
  Root := TPSManifest.Create;
  L := TPSLockfile.Create;
  Resolver := nil;
  try
    Root.Name := 'app';
    Root.Version := '1.0.0';
    Root.Dependencies.Add('@a/x', '^1.0.0');

    Resolver := TPSResolver.Create(Reg);
    Check('resolve success', Resolver.Resolve(Root, L, Err));

    CheckEqInt('2 packages', 2, L.Resolved.Count);

    R := L.FindPackage('@a/x');
    Check('found @a/x', Assigned(R));
    CheckEqStr('@a/x version', '1.0.0', R.Version);

    R := L.FindPackage('@a/z');
    Check('found @a/z', Assigned(R));
    CheckEqStr('@a/z version (highest matching)', '1.5.0', R.Version);
    Check('@a/z has integrity',
          Pos('sha256-', R.Integrity) = 1);
  finally
    Resolver.Free;
    Reg.Free;
    Root.Free;
    L.Free;
  end;
end;

// ═══════════════════════════════════════════════════════════════
//  Main
// ═══════════════════════════════════════════════════════════════
begin
  Randomize;
  WriteLn('=================================================');
  WriteLn('  pascak_pkg — Registry Test');
  WriteLn('=================================================');
  WriteLn;

  SetupTempDir;
  try
    TestGetVersions;
    TestGetManifest;
    TestGetIntegrity;
    TestEndToEnd;
  finally
    CleanupTempDir;
  end;

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