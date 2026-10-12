program test_pkg_manifest;

{$MODE OBJFPC}{$H+}

uses
  SysUtils, pascak_pkg;

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
//  Test 1: Manifest parse
// ═══════════════════════════════════════════════════════════════
procedure TestManifestParse;
var
  M: TPSManifest;
  Json: string;
begin
  WriteLn('Test 1: Manifest parse');
  M := TPSManifest.Create;
  try
    Json := '{"name": "@myorg/utils", "version": "1.2.3", ' +
            '"main": "src/main.pas", "license": "MIT"}';
    Check('parse basic', PSManifestParse(Json, M));
    CheckEqStr('name', '@myorg/utils', M.Name);
    CheckEqStr('version', '1.2.3', M.Version);
    CheckEqStr('main', 'src/main.pas', M.Main);
    CheckEqStr('license', 'MIT', M.License);

    Json := '{"name": "app", "version": "1.0.0", ' +
            '"dependencies": {"@a/b": "^1.0.0", "@c/d": "~2.0.0"}}';
    Check('parse with deps', PSManifestParse(Json, M));
    CheckEqInt('deps count', 2, M.Dependencies.Count);
    CheckEqStr('dep @a/b', '^1.0.0', M.Dependencies.KeyData['@a/b']);

    Json := '{"name": "app", "version": "1.0.0", ' +
            '"scripts": {"test": "pascak test.pas", "build": "pascak build.pas"}}';
    Check('parse with scripts', PSManifestParse(Json, M));
    CheckEqInt('scripts count', 2, M.Scripts.Count);

    Check('reject invalid json', not PSManifestParse('not json', M));
    Check('reject array root', not PSManifestParse('[1,2,3]', M));
    Check('accept minimal', PSManifestParse('{"name":"x","version":"1.0.0"}', M));
  finally
    M.Free;
  end;
end;

// ═══════════════════════════════════════════════════════════════
//  Test 2: Manifest validate
// ═══════════════════════════════════════════════════════════════
procedure TestManifestValidate;
var
  M: TPSManifest;
  Err: string;
begin
  WriteLn('Test 2: Manifest validate');
  M := TPSManifest.Create;
  try
    M.Name := 'my-app';
    M.Version := '1.0.0';
    Check('valid minimal', PSManifestValidate(M, Err));

    M.Name := '';
    Check('reject empty name', not PSManifestValidate(M, Err));
    Check('err mentions name', Pos('name', Err) > 0);

    M.Name := 'My-App';   // uppercase invalid
    Check('reject uppercase name', not PSManifestValidate(M, Err));

    M.Name := 'my-app';
    M.Version := 'invalid';
    Check('reject invalid version', not PSManifestValidate(M, Err));

    M.Version := '1.0.0';
    M.Dependencies.Add('@BadName/x', '^1.0.0');  // benar-benar uppercase
    Check('reject bad dep name', not PSManifestValidate(M, Err));    
    
    M.Dependencies.Clear;
    M.Dependencies.Add('@ok/name', 'invalid constraint ^&');
    Check('reject bad constraint', not PSManifestValidate(M, Err));
  finally
    M.Free;
  end;
end;

// ═══════════════════════════════════════════════════════════════
//  Test 3: Manifest round-trip
// ═══════════════════════════════════════════════════════════════
procedure TestManifestRoundTrip;
var
  M1, M2: TPSManifest;
  S: string;
begin
  WriteLn('Test 3: Manifest round-trip');
  M1 := TPSManifest.Create;
  M2 := TPSManifest.Create;
  try
    M1.Name := '@myorg/utils';
    M1.Version := '2.1.0';
    M1.Description := 'Utils paket';
    M1.Main := 'src/index.pas';
    M1.License := 'Apache-2.0';
    M1.Dependencies.Add('@pascak/crypto', '^1.0.0');
    M1.Dependencies.Add('@pascak/http', '~2.3.0');

    S := PSManifestToString(M1);
    Check('serialize not empty', Length(S) > 0);
    Check('contains name', Pos('@myorg/utils', S) > 0);
    Check('contains dep', Pos('@pascak/crypto', S) > 0);

    Check('parse back', PSManifestParse(S, M2));
    CheckEqStr('name preserved', M1.Name, M2.Name);
    CheckEqStr('version preserved', M1.Version, M2.Version);
    CheckEqStr('main preserved', M1.Main, M2.Main);
    CheckEqStr('license preserved', M1.License, M2.License);
    CheckEqInt('deps preserved', M1.Dependencies.Count, M2.Dependencies.Count);
  finally
    M1.Free;
    M2.Free;
  end;
end;

// ═══════════════════════════════════════════════════════════════
//  Test 4: Lockfile parse + round-trip
// ═══════════════════════════════════════════════════════════════
procedure TestLockfile;
var
  L1, L2: TPSLockfile;
  R: TPSResolved;
  S: string;
begin
  WriteLn('Test 4: Lockfile');
  L1 := TPSLockfile.Create;
  L2 := TPSLockfile.Create;
  try
    L1.AddPackage('@pascak/crypto', '1.0.0',
                  'https://r.pascak.dev/crypto-1.0.0.tgz',
                  'sha256-abcdef');
    L1.AddPackage('@pascak/http', '2.3.0',
                  'https://r.pascak.dev/http-2.3.0.tgz',
                  'sha256-123456');
    L1.SortByName;

    CheckEqInt('2 packages', 2, L1.Resolved.Count);

    R := L1.FindPackage('@pascak/http');
    Check('find existing', Assigned(R));
    CheckEqStr('  version', '2.3.0', R.Version);

    Check('not found', not Assigned(L1.FindPackage('@missing/x')));

    S := PSLockfileToString(L1);
    Check('serialize not empty', Length(S) > 0);

    Check('parse back', PSLockfileParse(S, L2));
    CheckEqInt('count preserved', 2, L2.Resolved.Count);

    R := L2.FindPackage('@pascak/crypto');
    Check('find after round-trip', Assigned(R));
    CheckEqStr('integrity preserved', 'sha256-abcdef', R.Integrity);
  finally
    L1.Free;
    L2.Free;
  end;
end;

// ═══════════════════════════════════════════════════════════════
//  Test 5: Package name validation
// ═══════════════════════════════════════════════════════════════
procedure TestNameValidation;
var
  Scope, Name: string;
begin
  WriteLn('Test 5: Package name');

  Check('valid @scope/name', PSPackageNameIsValid('@scope/name'));
  Check('valid scoped-dash', PSPackageNameIsValid('@my-org/utils'));
  Check('valid simple', PSPackageNameIsValid('utils'));
  Check('valid with underscore', PSPackageNameIsValid('my_utils'));

  Check('reject uppercase', not PSPackageNameIsValid('MyApp'));
  Check('reject space', not PSPackageNameIsValid('my app'));
  Check('reject @scope only', not PSPackageNameIsValid('@scope'));
  Check('reject empty', not PSPackageNameIsValid(''));

  PSParsePackageName('@scope/name', Scope, Name);
  CheckEqStr('scope parsed', 'scope', Scope);
  CheckEqStr('name parsed', 'name', Name);

  PSParsePackageName('utils', Scope, Name);
  CheckEqStr('unscoped scope empty', '', Scope);
  CheckEqStr('unscoped name', 'utils', Name);
end;

// ═══════════════════════════════════════════════════════════════
//  Test 6: Cache path
// ═══════════════════════════════════════════════════════════════
procedure TestCachePath;
begin
  WriteLn('Test 6: Cache path');
  CheckEqStr('scoped', '@pascak/crypto-1.2.3',
             PSPackageCachePath('@pascak/crypto', '1.2.3'));
  CheckEqStr('unscoped', 'utils-1.0.0',
             PSPackageCachePath('utils', '1.0.0'));
end;

// ═══════════════════════════════════════════════════════════════
//  Main
// ═══════════════════════════════════════════════════════════════
begin
  WriteLn('=================================================');
  WriteLn('  pascak_pkg — Manifest + Lockfile Test');
  WriteLn('=================================================');
  WriteLn;

  TestManifestParse;
  TestManifestValidate;
  TestManifestRoundTrip;
  TestLockfile;
  TestNameValidation;
  TestCachePath;

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