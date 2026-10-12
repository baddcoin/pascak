program test_pkg_install;

{$MODE OBJFPC}{$H+}
{$INTERFACES CORBA}

uses
  SysUtils, Classes, pascak_pkg, pascak_pkg_registry;

var
  GPassed: Integer = 0;
  GFailed: Integer = 0;
  GRegistry: string;
  GProject: string;

procedure Check(const Name: string; Cond: Boolean);
begin
  if Cond then begin Inc(GPassed); WriteLn('  [OK]   ', Name); end
  else begin Inc(GFailed); WriteLn('  [FAIL] ', Name); end;
end;

procedure CheckEqInt(const Name: string; Expected, Actual: Integer);
begin
  if Expected = Actual then begin Inc(GPassed); WriteLn('  [OK]   ', Name); end
  else begin
    Inc(GFailed);
    WriteLn('  [FAIL] ', Name, ' — expected ', Expected, ', got ', Actual);
  end;
end;

procedure CheckFileExists(const Name, Path: string);
begin
  if FileExists(Path) then begin Inc(GPassed); WriteLn('  [OK]   ', Name); end
  else begin Inc(GFailed); WriteLn('  [FAIL] ', Name, ' — not found: ', Path); end;
end;

procedure CheckDirExists(const Name, Path: string);
begin
  if DirectoryExists(Path) then begin Inc(GPassed); WriteLn('  [OK]   ', Name); end
  else begin Inc(GFailed); WriteLn('  [FAIL] ', Name, ' — not found: ', Path); end;
end;

procedure WriteTextFile(const Path, Content: string);
var F: TFileStream;
begin
  ForceDirectories(ExtractFileDir(Path));
  F := TFileStream.Create(Path, fmCreate);
  try
    if Length(Content) > 0 then F.WriteBuffer(Content[1], Length(Content));
  finally F.Free; end;
end;

procedure MakeRegistryPkg(const Name, Version, ManifestJson: string;
                          const MainContent: string = '');
var
  Dir: string;
begin
  Dir := IncludeTrailingPathDelimiter(GRegistry) + Name + PathDelim + Version;
  ForceDirectories(Dir);
  WriteTextFile(IncludeTrailingPathDelimiter(Dir) + 'pascak.json', ManifestJson);
  if MainContent <> '' then
    WriteTextFile(IncludeTrailingPathDelimiter(Dir) + 'main.pas', MainContent);
end;

procedure RemoveRec(const Dir: string);
var SR: TSearchRec; FullPath: string;
begin
  if FindFirst(IncludeTrailingPathDelimiter(Dir) + '*', faAnyFile, SR) = 0 then
  begin
    try
      repeat
        if (SR.Name = '.') or (SR.Name = '..') then Continue;
        FullPath := IncludeTrailingPathDelimiter(Dir) + SR.Name;
        if (SR.Attr and faDirectory) <> 0 then RemoveRec(FullPath)
        else DeleteFile(FullPath);
      until FindNext(SR) <> 0;
    finally FindClose(SR); end;
  end;
  RemoveDir(Dir);
end;

procedure SetupEnv;
var Base: string;
begin
  Base := GetEnvironmentVariable('HOME');
  if Base = '' then Base := '/data/data/com.termux/files/home';

  GRegistry := IncludeTrailingPathDelimiter(Base) + '.cache' +
               PathDelim + 'pkg_reg_' + IntToStr(Random(100000));
  GProject := IncludeTrailingPathDelimiter(Base) + '.cache' +
              PathDelim + 'pkg_proj_' + IntToStr(Random(100000));

  ForceDirectories(GRegistry);
  ForceDirectories(GProject);
end;

procedure CleanupEnv;
begin
  if DirectoryExists(GRegistry) then RemoveRec(GRegistry);
  if DirectoryExists(GProject) then RemoveRec(GProject);
end;

// ═══════════════════════════════════════════════════════════════
//  Test 1: Simple install
// ═══════════════════════════════════════════════════════════════
procedure TestSimpleInstall;
var
  List: TStringList;
  Err: string;
begin
  WriteLn('Test 1: Simple install');

  // Registry: @a/lib 1.0.0 (no deps)
  MakeRegistryPkg('@a/lib', '1.0.0',
    '{"name":"@a/lib","version":"1.0.0","main":"main.pas"}',
    'begin end.');

  // Project: app → @a/lib ^1.0.0
  WriteTextFile(IncludeTrailingPathDelimiter(GProject) + 'pascak.json',
    '{"name":"app","version":"1.0.0","dependencies":{"@a/lib":"^1.0.0"}}');

  List := TStringList.Create;
  try
    Check('install success', PSInstallProject(GRegistry, GProject, List, Err));
    if Err <> '' then WriteLn('       err: ', Err);
    CheckEqInt('1 installed', 1, List.Count);

    CheckFileExists('pascak.lock created',
                    IncludeTrailingPathDelimiter(GProject) + 'pascak.lock');
    CheckDirExists('packages/@a/lib exists',
                   IncludeTrailingPathDelimiter(GProject) +
                   'packages' + PathDelim + '@a' + PathDelim + 'lib');
    CheckFileExists('main.pas copied',
                    IncludeTrailingPathDelimiter(GProject) +
                    'packages' + PathDelim + '@a' + PathDelim + 'lib' +
                    PathDelim + 'main.pas');
    CheckFileExists('manifest copied',
                    IncludeTrailingPathDelimiter(GProject) +
                    'packages' + PathDelim + '@a' + PathDelim + 'lib' +
                    PathDelim + 'pascak.json');
  finally
    List.Free;
  end;
end;

// ═══════════════════════════════════════════════════════════════
//  Test 2: Transitive install
// ═══════════════════════════════════════════════════════════════
procedure TestTransitiveInstall;
var
  List: TStringList;
  Err: string;
begin
  WriteLn('Test 2: Transitive install');

  MakeRegistryPkg('@a/x', '1.0.0',
    '{"name":"@a/x","version":"1.0.0","main":"main.pas",' +
    '"dependencies":{"@a/z":"^1.0.0"}}', 'begin end.');
  MakeRegistryPkg('@a/z', '1.0.0',
    '{"name":"@a/z","version":"1.0.0","main":"main.pas"}', 'begin end.');
  MakeRegistryPkg('@a/z', '1.5.0',
    '{"name":"@a/z","version":"1.5.0","main":"main.pas"}', 'begin end.');

  // Reset project
  RemoveRec(GProject);
  ForceDirectories(GProject);
  WriteTextFile(IncludeTrailingPathDelimiter(GProject) + 'pascak.json',
    '{"name":"app","version":"1.0.0","dependencies":{"@a/x":"^1.0.0"}}');

  List := TStringList.Create;
  try
    Check('transitive install', PSInstallProject(GRegistry, GProject, List, Err));
    if Err <> '' then WriteLn('       err: ', Err);
    CheckEqInt('2 installed', 2, List.Count);

    // Verify both packages present
    CheckDirExists('packages/@a/x',
                   IncludeTrailingPathDelimiter(GProject) +
                   'packages' + PathDelim + '@a' + PathDelim + 'x');
    CheckDirExists('packages/@a/z',
                   IncludeTrailingPathDelimiter(GProject) +
                   'packages' + PathDelim + '@a' + PathDelim + 'z');
  finally
    List.Free;
  end;
end;

// ═══════════════════════════════════════════════════════════════
//  Test 3: List installed
// ═══════════════════════════════════════════════════════════════
procedure TestListInstalled;
var
  List: TStringList;
  Err: string;
begin
  WriteLn('Test 3: List installed');

  List := TStringList.Create;
  try
    Check('list success', PSListInstalled(GProject, List, Err));
    if Err <> '' then WriteLn('       err: ', Err);
    CheckEqInt('2 in lockfile', 2, List.Count);

    // Entries should be name@version
    Check('has @a/x@1.0.0', List.IndexOf('@a/x@1.0.0') >= 0);
    Check('has @a/z@1.5.0', List.IndexOf('@a/z@1.5.0') >= 0);
  finally
    List.Free;
  end;
end;

// ═══════════════════════════════════════════════════════════════
//  Test 4: Missing project manifest
// ═══════════════════════════════════════════════════════════════
procedure TestMissingManifest;
var
  List: TStringList;
  Err: string;
  EmptyProj: string;
begin
  WriteLn('Test 4: Missing project manifest');

  EmptyProj := GProject + '_empty';
  ForceDirectories(EmptyProj);

  List := TStringList.Create;
  try
    Check('install fails', not PSInstallProject(GRegistry, EmptyProj, List, Err));
    Check('err mentions pascak.json', Pos('pascak.json', Err) > 0);
  finally
    List.Free;
    RemoveRec(EmptyProj);
  end;
end;

// ═══════════════════════════════════════════════════════════════
//  Main
// ═══════════════════════════════════════════════════════════════
begin
  Randomize;
  WriteLn('=================================================');
  WriteLn('  pascak_pkg — Install Test');
  WriteLn('=================================================');
  WriteLn;

  SetupEnv;
  try
    TestSimpleInstall;
    TestTransitiveInstall;
    TestListInstalled;
    TestMissingManifest;
  finally
    CleanupEnv;
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