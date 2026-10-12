program test_pkg_resolver;

{$MODE OBJFPC}{$H+}

uses
  SysUtils, Classes, fgl, pascak_pkg;

var
  GPassed: Integer = 0;
  GFailed: Integer = 0;

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

// ═══════════════════════════════════════════════════════════════
//  Mock Registry — in-memory provider untuk testing
// ═══════════════════════════════════════════════════════════════

type
  TMockPkg = class
    Name: string;
    Version: string;
    Deps: TStringList;   // "name=constraint"
    constructor Create(const AName, AVer: string);
    destructor Destroy; override;
  end;

  TMockRegistry = class(TInterfacedObject, IPSRegistry)
  private
    FPkgs: specialize TFPGObjectList<TMockPkg>;
  public
    constructor Create;
    destructor Destroy; override;
    procedure AddPackage(const Name, Version, Deps: string);
    function GetVersions(const Name: string): TPSVersionArray;
    function GetManifest(const Name, Version: string): TPSManifest;
    function GetDownloadURL(const Name, Version: string): string;
    function GetIntegrity(const Name, Version: string): string;
  end;

constructor TMockPkg.Create(const AName, AVer: string);
begin
  inherited Create;
  Name := AName;
  Version := AVer;
  Deps := TStringList.Create;
end;

destructor TMockPkg.Destroy;
begin
  Deps.Free;
  inherited;
end;

constructor TMockRegistry.Create;
begin
  inherited Create;
  FPkgs := specialize TFPGObjectList<TMockPkg>.Create(True);
end;

destructor TMockRegistry.Destroy;
begin
  FPkgs.Free;
  inherited;
end;

procedure TMockRegistry.AddPackage(const Name, Version, Deps: string);
var
  P: TMockPkg;
  DepList: TStringArray;
  I: Integer;
begin
  P := TMockPkg.Create(Name, Version);
  if Deps <> '' then
  begin
    DepList := Deps.Split([',']);
    for I := 0 to High(DepList) do
      P.Deps.Add(Trim(DepList[I]));
  end;
  FPkgs.Add(P);
end;

function TMockRegistry.GetVersions(const Name: string): TPSVersionArray;
var
  I, Count: Integer;
  V: TPSVersion;
begin
  SetLength(Result, 0);
  for I := 0 to FPkgs.Count - 1 do
    if FPkgs[I].Name = Name then
    begin
      if PSVersionParse(FPkgs[I].Version, V) then
      begin
        SetLength(Result, Length(Result) + 1);
        Result[High(Result)] := V;
      end;
    end;
  Count := Length(Result);
  if Count > 1 then
    PSSortVersionsAsc(Result);
end;

function TMockRegistry.GetManifest(const Name, Version: string): TPSManifest;
var
  I, J, Eq: Integer;
  P: TMockPkg;
  DName, DCon: string;
begin
  Result := nil;
  for I := 0 to FPkgs.Count - 1 do
    if (FPkgs[I].Name = Name) and (FPkgs[I].Version = Version) then
    begin
      P := FPkgs[I];
      Result := TPSManifest.Create;
      Result.Name := P.Name;
      Result.Version := P.Version;
      for J := 0 to P.Deps.Count - 1 do
      begin
        Eq := Pos('=', P.Deps[J]);
        if Eq > 0 then
        begin
          DName := Copy(P.Deps[J], 1, Eq - 1);
          DCon := Copy(P.Deps[J], Eq + 1, Length(P.Deps[J]));
          Result.Dependencies.Add(DName, DCon);
        end;
      end;
      Exit;
    end;
end;

function TMockRegistry.GetDownloadURL(const Name, Version: string): string;
begin
  Result := 'mock://' + Name + '/' + Version;
end;

function TMockRegistry.GetIntegrity(const Name, Version: string): string;
begin
  Result := 'sha256-mock-' + Name + '-' + Version;
end;

// ═══════════════════════════════════════════════════════════════
//  Test 1: Simple — no dependencies
// ═══════════════════════════════════════════════════════════════
procedure TestSimple;
var
  Reg: TMockRegistry;
  Root: TPSManifest;
  Resolver: TPSResolver;
  L: TPSLockfile;
  Err: string;
  R: TPSResolved;
begin
  WriteLn('Test 1: Simple — single package, no deps');
  Reg := TMockRegistry.Create;
  Root := TPSManifest.Create;
  L := TPSLockfile.Create;
  Resolver := nil;
  try
    Reg.AddPackage('@a/lib', '1.2.3', '');
    Root.Name := 'app';
    Root.Version := '1.0.0';
    Root.Dependencies.Add('@a/lib', '^1.0.0');

    Resolver := TPSResolver.Create(Reg);
    Check('resolve success', Resolver.Resolve(Root, L, Err));
    CheckEqInt('1 package', 1, L.Resolved.Count);

    R := L.FindPackage('@a/lib');
    Check('found @a/lib', Assigned(R));
    CheckEqStr('version 1.2.3', '1.2.3', R.Version);
    CheckEqStr('integrity mock', 'sha256-mock-@a/lib-1.2.3', R.Integrity);
  finally
    Resolver.Free;
    Reg.Free;
    Root.Free;
    L.Free;
  end;
end;

// ═══════════════════════════════════════════════════════════════
//  Test 2: Transitive — diamond
// ═══════════════════════════════════════════════════════════════
procedure TestTransitive;
var
  Reg: TMockRegistry;
  Root: TPSManifest;
  Resolver: TPSResolver;
  L: TPSLockfile;
  Err: string;
  R: TPSResolved;
begin
  WriteLn('Test 2: Transitive — diamond');
  Reg := TMockRegistry.Create;
  Root := TPSManifest.Create;
  L := TPSLockfile.Create;
  Resolver := nil;
  try
    // app → @a/x ^1.0.0, @a/y ^2.0.0
    // @a/x 1.0.0 → @a/z ^1.0.0
    // @a/y 2.0.0 → @a/z ^1.0.0
    // @a/z 1.5.0
    Reg.AddPackage('@a/x', '1.0.0', '@a/z=^1.0.0');
    Reg.AddPackage('@a/y', '2.0.0', '@a/z=^1.0.0');
    Reg.AddPackage('@a/z', '1.5.0', '');

    Root.Name := 'app';
    Root.Version := '1.0.0';
    Root.Dependencies.Add('@a/x', '^1.0.0');
    Root.Dependencies.Add('@a/y', '^2.0.0');

    Resolver := TPSResolver.Create(Reg);
    Check('resolve diamond', Resolver.Resolve(Root, L, Err));
    CheckEqInt('3 packages', 3, L.Resolved.Count);

    R := L.FindPackage('@a/z');
    Check('found @a/z', Assigned(R));
    CheckEqStr('@a/z = 1.5.0', '1.5.0', R.Version);
  finally
    Resolver.Free;
    Reg.Free;
    Root.Free;
    L.Free;
  end;
end;

// ═══════════════════════════════════════════════════════════════
//  Test 3: Version constraint resolution
// ═══════════════════════════════════════════════════════════════
procedure TestVersionSelection;
var
  Reg: TMockRegistry;
  Root: TPSManifest;
  Resolver: TPSResolver;
  L: TPSLockfile;
  Err: string;
  R: TPSResolved;
begin
  WriteLn('Test 3: Version selection — highest matching');
  Reg := TMockRegistry.Create;
  Root := TPSManifest.Create;
  L := TPSLockfile.Create;
  Resolver := nil;
  try
    Reg.AddPackage('@a/lib', '1.0.0', '');
    Reg.AddPackage('@a/lib', '1.2.0', '');
    Reg.AddPackage('@a/lib', '1.5.0', '');
    Reg.AddPackage('@a/lib', '2.0.0', '');

    Root.Name := 'app';
    Root.Version := '1.0.0';
    Root.Dependencies.Add('@a/lib', '^1.0.0');

    Resolver := TPSResolver.Create(Reg);
    Check('resolve', Resolver.Resolve(Root, L, Err));
    R := L.FindPackage('@a/lib');
    CheckEqStr('picks 1.5.0 (highest ^1)', '1.5.0', R.Version);
  finally
    Resolver.Free;
    Reg.Free;
    Root.Free;
    L.Free;
  end;
end;

// ═══════════════════════════════════════════════════════════════
//  Test 4: Not found
// ═══════════════════════════════════════════════════════════════
procedure TestNotFound;
var
  Reg: TMockRegistry;
  Root: TPSManifest;
  Resolver: TPSResolver;
  L: TPSLockfile;
  Err: string;
begin
  WriteLn('Test 4: Package not found');
  Reg := TMockRegistry.Create;
  Root := TPSManifest.Create;
  L := TPSLockfile.Create;
  Resolver := nil;
  try
    Root.Name := 'app';
    Root.Version := '1.0.0';
    Root.Dependencies.Add('@missing/pkg', '^1.0.0');

    Resolver := TPSResolver.Create(Reg);
    Check('resolve fails', not Resolver.Resolve(Root, L, Err));
    Check('err mentions not found', Pos('tidak ditemukan', Err) > 0);
  finally
    Resolver.Free;
    Reg.Free;
    Root.Free;
    L.Free;
  end;
end;

// ═══════════════════════════════════════════════════════════════
//  Test 5: No matching version
// ═══════════════════════════════════════════════════════════════
procedure TestNoMatch;
var
  Reg: TMockRegistry;
  Root: TPSManifest;
  Resolver: TPSResolver;
  L: TPSLockfile;
  Err: string;
begin
  WriteLn('Test 5: No matching version');
  Reg := TMockRegistry.Create;
  Root := TPSManifest.Create;
  L := TPSLockfile.Create;
  Resolver := nil;
  try
    Reg.AddPackage('@a/lib', '1.0.0', '');
    Reg.AddPackage('@a/lib', '1.5.0', '');

    Root.Name := 'app';
    Root.Version := '1.0.0';
    Root.Dependencies.Add('@a/lib', '^2.0.0');   // tidak ada 2.x

    Resolver := TPSResolver.Create(Reg);
    Check('resolve fails', not Resolver.Resolve(Root, L, Err));
    Check('err mentions no match', Pos('tidak ada versi', Err) > 0);
  finally
    Resolver.Free;
    Reg.Free;
    Root.Free;
    L.Free;
  end;
end;

// ═══════════════════════════════════════════════════════════════
//  Test 6: Circular dependency
// ═══════════════════════════════════════════════════════════════
procedure TestCircular;
var
  Reg: TMockRegistry;
  Root: TPSManifest;
  Resolver: TPSResolver;
  L: TPSLockfile;
  Err: string;
begin
  WriteLn('Test 6: Circular dependency');
  Reg := TMockRegistry.Create;
  Root := TPSManifest.Create;
  L := TPSLockfile.Create;
  Resolver := nil;
  try
    Reg.AddPackage('@a/x', '1.0.0', '@a/y=^1.0.0');
    Reg.AddPackage('@a/y', '1.0.0', '@a/x=^1.0.0');   // cycle

    Root.Name := 'app';
    Root.Version := '1.0.0';
    Root.Dependencies.Add('@a/x', '^1.0.0');

    Resolver := TPSResolver.Create(Reg);
    Check('resolve fails', not Resolver.Resolve(Root, L, Err));
    Check('err mentions circular', Pos('circular', Err) > 0);
  finally
    Resolver.Free;
    Reg.Free;
    Root.Free;
    L.Free;
  end;
end;

// ═══════════════════════════════════════════════════════════════
//  Test 7: Shared dependency reuse
// ═══════════════════════════════════════════════════════════════
procedure TestSharedReuse;
var
  Reg: TMockRegistry;
  Root: TPSManifest;
  Resolver: TPSResolver;
  L: TPSLockfile;
  Err: string;
  R: TPSResolved;
begin
  WriteLn('Test 7: Shared dependency reuse');
  Reg := TMockRegistry.Create;
  Root := TPSManifest.Create;
  L := TPSLockfile.Create;
  Resolver := nil;
  try
    // x@1.0.0 → z=^1.0.0
    // y@1.0.0 → z=^1.0.0
    // z: 1.0.0, 1.5.0, 2.0.0
    // Expected: z resolved to 1.5.0 (highest matching ^1)
    // Both x and y reuse z=1.5.0
    Reg.AddPackage('@a/x', '1.0.0', '@a/z=^1.0.0');
    Reg.AddPackage('@a/y', '1.0.0', '@a/z=^1.0.0');
    Reg.AddPackage('@a/z', '1.0.0', '');
    Reg.AddPackage('@a/z', '1.5.0', '');
    Reg.AddPackage('@a/z', '2.0.0', '');

    Root.Name := 'app';
    Root.Version := '1.0.0';
    Root.Dependencies.Add('@a/x', '^1.0.0');
    Root.Dependencies.Add('@a/y', '^1.0.0');

    Resolver := TPSResolver.Create(Reg);
    Check('resolve', Resolver.Resolve(Root, L, Err));
    CheckEqInt('3 packages (z shared)', 3, L.Resolved.Count);

    R := L.FindPackage('@a/z');
    CheckEqStr('z = 1.5.0', '1.5.0', R.Version);
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
  WriteLn('=================================================');
  WriteLn('  pascak_pkg — Resolver Test');
  WriteLn('=================================================');
  WriteLn;

  TestSimple;
  TestTransitive;
  TestVersionSelection;
  TestNotFound;
  TestNoMatch;
  TestCircular;
  TestSharedReuse;

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