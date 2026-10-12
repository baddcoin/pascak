{ ====================================================================
  pascak_pkg.pas — Package manager core
  ====================================================================
  Foundation untuk ekosistem modul Pascak.

  Scope v1:
    - Semver parse + compare (MAJOR.MINOR.PATCH)
    - Constraint parse + match (^, ~, >=, <=, >, <, exact, wildcard, *)
    - Range (OR of constraints)
    - (Chunk D.2+) Manifest, lockfile, resolver, registry client

  Pure Pascal. Zero external deps beyond SysUtils + Classes.
  ==================================================================== }
unit pascak_pkg;

{$MODE OBJFPC}{$H+}
{$INTERFACES CORBA}    // ← FIX: pakai CORBA convention, bukan COM default

interface

uses
  SysUtils, Classes, fgl, fpjson, jsonparser;  
  
type
  EPSPkgError = class(Exception);
  TPSResolved = class;
  
  TPSDependencyList = specialize TFPGMap<string, string>;
  TPSScriptList = specialize TFPGMap<string, string>;
  TPSResolvedList = specialize TFPGObjectList<TPSResolved>;

  { ─── Constraint ─── }
  TPSConstraintOp = (
    pcoExact,      // "1.2.3"
    pcoCaret,      // "^1.2.3"  → >=1.2.3 <2.0.0
    pcoTilde,      // "~1.2.3"  → >=1.2.3 <1.3.0
    pcoGte,        // ">=1.2.3"
    pcoLte,        // "<=1.2.3"
    pcoGt,         // ">1.2.3"
    pcoLt,         // "<1.2.3"
    pcoAny,        // "*" or ""
    pcoWildcard    // "1.x" or "1.2.x"
  );

  { ─── Version ─── }
  TPSVersion = record
    Major: Integer;
    Minor: Integer;
    Patch: Integer;
    Valid: Boolean;
  end;

  TPSConstraint = record
    Op: TPSConstraintOp;
    Major: Integer;
    Minor: Integer;
    Patch: Integer;
    HasMinor: Boolean;   // false untuk "1.x"
    HasPatch: Boolean;   // false untuk "1.2.x"
    Valid: Boolean;
  end;
  TPSConstraintArray = array of TPSConstraint;

  TPSManifest = class
  public
    Name: string;         // "@scope/name" atau "name"
    Version: string;      // "1.2.3"
    Description: string;
    Main: string;         // "src/main.pas"
    Author: string;
    License: string;      // "MIT", "Apache-2.0", etc.
    Dependencies: TPSDependencyList;   // name → constraint string
    Scripts: TPSScriptList;            // name → command
  
    constructor Create;
    destructor Destroy; override;
    procedure Clear;
    function Clone: TPSManifest;
  end;
  
  { ─── Lockfile (pascak.lock) ─── }
  TPSResolved = class
  public
    Name: string;
    Version: string;
    URL: string;
    Integrity: string;   // "sha256-..."
    Dependencies: TPSDependencyList;   // snapshot deps (untuk lock consistency)
    constructor Create;
    destructor Destroy; override;
  end;
  TPSVersionArray = array of TPSVersion;

  TPSLockfile = class
  public
    LockVersion: Integer;   // format version, mulai 1
    Resolved: TPSResolvedList;
  
    constructor Create;
    destructor Destroy; override;
    procedure Clear;
    function FindPackage(const Name: string): TPSResolved;
    procedure AddPackage(const Name, Version, URL, Integrity: string);
    // Sort resolved ascending by name
    procedure SortByName;
  end;

  { ─── Registry (abstract provider) ─── }
  // Implementasi konkret: local folder (D.4), HTTP (D.4), atau mock (test)
  IPSRegistry = interface
    // Daftar versi yang tersedia untuk package.
    // Return array kosong kalau package tidak ada.
    function GetVersions(const Name: string): TPSVersionArray;
  
    // Manifest untuk (name, version) spesifik.
    // Return nil kalau tidak ada.
    function GetManifest(const Name, Version: string): TPSManifest;
  
    // URL untuk download (dipakai di lockfile).
    // Format: sesuai implementasi (file://, https://, dst).
    function GetDownloadURL(const Name, Version: string): string;
  
    // Integrity hash (sha256-...).
    function GetIntegrity(const Name, Version: string): string;
  end;
  
  { ─── Resolver ─── }
  TPSResolver = class
  private
    FRegistry: IPSRegistry;
    FResolved: TPSDependencyList;   // name → version (resolved)
    FResolving: TStringList;         // cycle detection stack
    FMaxDepth: Integer;
  
    function ResolveRecursive(const Name, ConstraintStr, ParentChain: string;
                              Depth: Integer;
                              out Err: string): Boolean;
  public
    constructor Create(Registry: IPSRegistry);
    destructor Destroy; override;
  
    // Resolve dependency graph dari root manifest.
    // Hasil di L (lockfile). Return False + Err kalau conflict/cycle.
    function Resolve(Root: TPSManifest;
                     out L: TPSLockfile;
                     out Err: string): Boolean;
  end;

  // Parse "1.2.3" → Version. Terima juga "1.2" dan "1"
  // (missing parts default ke 0). Return False kalau invalid.
  function PSVersionParse(const S: string; out V: TPSVersion): Boolean;
  
  // "1.2.3"
  function PSVersionToString(const V: TPSVersion): string;
  
  // Return -1 / 0 / 1 (like CompareStr)
  function PSVersionCompare(const A, B: TPSVersion): Integer;
  
  function PSVersionEquals(const A, B: TPSVersion): Boolean;
  
  { ─── Constraint ops ─── }
  
  // Parse single constraint: "^1.2.3", ">=1.0.0", "1.x", "*", etc.
  function PSConstraintParse(const S: string; out C: TPSConstraint): Boolean;
  
  // Cek apakah version V memenuhi constraint C
  function PSConstraintMatch(const C: TPSConstraint; const V: TPSVersion): Boolean;
  
  // "1.2.3" atau "^1.2.3" (pretty print)
  function PSConstraintToString(const C: TPSConstraint): string;
  
  { ─── Range (OR of constraints) ─── }
  
  // Parse range dengan "||" sebagai OR separator:
  //   "^1.2.0 || >=2.0.0"  → 2 constraints, OR-ed
  // Untuk simple constraint (tanpa ||), hasilnya array 1 elemen.
  function PSRangeParse(const S: string; out Range: TPSConstraintArray): Boolean;
  
  // Cek apakah V match MINIMAL SATU constraint di range
  function PSRangeMatch(const Range: TPSConstraintArray;
    const V: TPSVersion): Boolean;
  
  { ─── Utility ─── }
  
  // Sort version array ascending (in-place, simple bubble untuk N kecil)
  procedure PSSortVersionsAsc(var Versions: array of TPSVersion);
  
  // Cari versi tertinggi yang match constraint di list versi
  // Return False kalau tidak ada yang match
  function PSFindHighestMatch(const Constraint: TPSConstraint;
    const Available: array of TPSVersion;
    out Best: TPSVersion): Boolean;

  // Parse JSON manifest. Return False kalau JSON invalid atau required
  // fields missing. M dikosongkan dulu sebelum parse.
  function PSManifestParse(const Json: string; out M: TPSManifest): Boolean;
  
  // Load dari file. Return False kalau file tidak ada / tidak bisa dibaca.
  function PSManifestLoad(const Path: string; out M: TPSManifest): Boolean;
  
  // Serialize ke JSON string (pretty, 2-space indent)
  function PSManifestToString(const M: TPSManifest): string;
  
  // Save ke file. Buat file baru (overwrite).
  function PSManifestSave(const M: TPSManifest; const Path: string): Boolean;
  
  // Validasi: name dan version wajib. Version harus semver valid.
  // Dependencies name + constraint harus valid.
  function PSManifestValidate(const M: TPSManifest; out Err: string): Boolean;
  
  { ─── Lockfile I/O ─── }
  
  function PSLockfileParse(const Json: string; out L: TPSLockfile): Boolean;
  function PSLockfileLoad(Path: string; out L: TPSLockfile): Boolean;
  function PSLockfileToString(const L: TPSLockfile): string;
  function PSLockfileSave(const L: TPSLockfile; const Path: string): Boolean;
  
  { ─── Scope helper ─── }
  
  // Parse nama package: "@scope/name" atau "name"
  // Return scope="" kalau unscoped
  procedure PSParsePackageName(const FullName: string;
                               out Scope, Name: string);
  
  // Validasi nama: lowercase, alfanumerik, dash, underscore.
  // Scope boleh ada @ di depan.
  function PSPackageNameIsValid(const FullName: string): Boolean;
  
  // Path relatif untuk package di cache: "scope/name" → "@scope/name-1.2.3"
  function PSPackageCachePath(const FullName, Version: string): string;


implementation

{ ═══════════════════════════════════════════════════════════════
  Version parsing
  ═══════════════════════════════════════════════════════════════ }

// Parse integer, tolak leading zero (kecuali "0" tunggal)
function ParseVersionPart(const S: string; out Value: Integer): Boolean;
var
  I: Integer;
begin
  Result := False;
  Value := 0;

  if S = '' then Exit;

  // Leading zero check
  if (Length(S) > 1) and (S[1] = '0') then Exit;

  for I := 1 to Length(S) do
  begin
    if (S[I] < '0') or (S[I] > '9') then Exit;
    // Overflow check (max 9 digit)
    if I > 9 then Exit;
    Value := Value * 10 + (Ord(S[I]) - Ord('0'));
  end;

  Result := True;
end;

function PSVersionParse(const S: string; out V: TPSVersion): Boolean;
var
  Parts: TStringArray;
  Trimmed: string;
begin
  Result := False;
  V.Major := 0;
  V.Minor := 0;
  V.Patch := 0;
  V.Valid := False;

  Trimmed := Trim(S);
  if Trimmed = '' then Exit;

  Parts := Trimmed.Split(['.']);

  if Length(Parts) > 3 then Exit;
  if Length(Parts) = 0 then Exit;

  if not ParseVersionPart(Parts[0], V.Major) then Exit;
  if Length(Parts) >= 2 then
    if not ParseVersionPart(Parts[1], V.Minor) then Exit;
  if Length(Parts) >= 3 then
    if not ParseVersionPart(Parts[2], V.Patch) then Exit;

  V.Valid := True;
  Result := True;
end;

function PSVersionToString(const V: TPSVersion): string;
begin
  Result := Format('%d.%d.%d', [V.Major, V.Minor, V.Patch]);
end;

function Signum(X: Integer): Integer; inline;
begin
  if X < 0 then Result := -1
  else if X > 0 then Result := 1
  else Result := 0;
end;

function PSVersionCompare(const A, B: TPSVersion): Integer;
begin
  if A.Major <> B.Major then
    Exit(Signum(A.Major - B.Major));
  if A.Minor <> B.Minor then
    Exit(Signum(A.Minor - B.Minor));
  Result := Signum(A.Patch - B.Patch);
end;

// Helper: convert TPSConstraint ke TPSVersion (extract major/minor/patch)
function ConstraintToVersion(const C: TPSConstraint): TPSVersion;
begin
  Result.Major := C.Major;
  Result.Minor := C.Minor;
  Result.Patch := C.Patch;
  Result.Valid := True;
end;

function PSVersionEquals(const A, B: TPSVersion): Boolean;
begin
  Result := (A.Major = B.Major) and
            (A.Minor = B.Minor) and
            (A.Patch = B.Patch);
end;

{ ═══════════════════════════════════════════════════════════════
  Constraint parsing
  ═══════════════════════════════════════════════════════════════ }

function PSConstraintParse(const S: string; out C: TPSConstraint): Boolean;
var
  Trimmed, Body: string;
  V: TPSVersion;
  Parts: TStringArray;
begin
  Result := False;
  C.Op := pcoExact;
  C.Major := 0;
  C.Minor := 0;
  C.Patch := 0;
  C.HasMinor := True;
  C.HasPatch := True;
  C.Valid := False;

  Trimmed := Trim(S);
  if (Trimmed = '') or (Trimmed = '*') then
  begin
    C.Op := pcoAny;
    C.Valid := True;
    Exit(True);
  end;

  // Detect operator prefix
  if Copy(Trimmed, 1, 2) = '>=' then
  begin
    C.Op := pcoGte;
    Body := Trim(Copy(Trimmed, 3, Length(Trimmed)));
  end
  else if Copy(Trimmed, 1, 2) = '<=' then
  begin
    C.Op := pcoLte;
    Body := Trim(Copy(Trimmed, 3, Length(Trimmed)));
  end
  else if Trimmed[1] = '>' then
  begin
    C.Op := pcoGt;
    Body := Trim(Copy(Trimmed, 2, Length(Trimmed)));
  end
  else if Trimmed[1] = '<' then
  begin
    C.Op := pcoLt;
    Body := Trim(Copy(Trimmed, 2, Length(Trimmed)));
  end
  else if Trimmed[1] = '^' then
  begin
    C.Op := pcoCaret;
    Body := Trim(Copy(Trimmed, 2, Length(Trimmed)));
  end
  else if Trimmed[1] = '~' then
  begin
    C.Op := pcoTilde;
    Body := Trim(Copy(Trimmed, 2, Length(Trimmed)));
  end
  else
  begin
    Body := Trimmed;
  end;

  if Body = '' then Exit;

  // Check wildcard "x" atau "X" atau "*"
  Parts := Body.Split(['.']);

  if Length(Parts) > 3 then Exit;
  if Length(Parts) = 0 then Exit;

  // Parse part 0 (major)
  if (Parts[0] = 'x') or (Parts[0] = 'X') or (Parts[0] = '*') then
  begin
    // "x" / "*" → any
    C.Op := pcoAny;
    C.Valid := True;
    Exit(True);
  end;
  if not ParseVersionPart(Parts[0], C.Major) then Exit;

  // Parse part 1 (minor) — optional
  if Length(Parts) >= 2 then
  begin
    if (Parts[1] = 'x') or (Parts[1] = 'X') or (Parts[1] = '*') then
    begin
      // "1.x" → wildcard
      C.Op := pcoWildcard;
      C.HasMinor := False;
      C.HasPatch := False;
      C.Valid := True;
      Exit(True);
    end;
    if not ParseVersionPart(Parts[1], C.Minor) then Exit;
  end;

  // Parse part 2 (patch) — optional
  if Length(Parts) >= 3 then
  begin
    if (Parts[2] = 'x') or (Parts[2] = 'X') or (Parts[2] = '*') then
    begin
      // "1.2.x" → wildcard
      C.Op := pcoWildcard;
      C.HasPatch := False;
      C.Valid := True;
      Exit(True);
    end;
    if not ParseVersionPart(Parts[2], C.Patch) then Exit;
  end;

  C.Valid := True;
  Result := True;
end;

function PSConstraintToString(const C: TPSConstraint): string;
begin
  case C.Op of
    pcoAny:      Result := '*';
    pcoCaret:    Result := '^' + PSVersionToString(ConstraintToVersion(C));
    pcoTilde:    Result := '~' + PSVersionToString(ConstraintToVersion(C));
    pcoGte:      Result := '>=' + PSVersionToString(ConstraintToVersion(C));
    pcoLte:      Result := '<=' + PSVersionToString(ConstraintToVersion(C));
    pcoGt:       Result := '>' + PSVersionToString(ConstraintToVersion(C));
    pcoLt:       Result := '<' + PSVersionToString(ConstraintToVersion(C));
    pcoWildcard:
      begin
        Result := IntToStr(C.Major) + '.';
        if C.HasMinor then
          Result := Result + IntToStr(C.Minor) + '.';
        Result := Result + 'x';
      end;
  else
    Result := PSVersionToString(ConstraintToVersion(C));
  end;
end;

{ ═══════════════════════════════════════════════════════════════
  Constraint matching
  ═══════════════════════════════════════════════════════════════ }

function PSConstraintMatch(const C: TPSConstraint; const V: TPSVersion): Boolean;
begin
  if (not C.Valid) or (not V.Valid) then Exit(False);

  case C.Op of
    pcoAny:
      Result := True;

    pcoExact:
      Result := (V.Major = C.Major) and
                (V.Minor = C.Minor) and
                (V.Patch = C.Patch);

    pcoCaret:
      begin
        // ^1.2.3 → >=1.2.3 <2.0.0
        // Special: ^0.2.3 → >=0.2.3 <0.3.0 (semver rule untuk major=0)
        //          ^0.0.3 → >=0.0.3 <0.0.4
        if V.Major <> C.Major then
          Exit(False);
        if C.Major > 0 then
          // any minor/patch as long as major matches
          Result := (V.Minor > C.Minor) or
                    ((V.Minor = C.Minor) and (V.Patch >= C.Patch))
        else if C.Minor > 0 then
          // 0.x.y: minor locked
          Result := (V.Minor = C.Minor) and (V.Patch >= C.Patch)
        else
          // 0.0.x: patch locked
          Result := (V.Minor = 0) and (V.Patch = C.Patch);
      end;

    pcoTilde:
      begin
        // ~1.2.3 → >=1.2.3 <1.3.0
        Result := (V.Major = C.Major) and
                  (V.Minor = C.Minor) and
                  (V.Patch >= C.Patch);
      end;

    pcoGte:
      Result := PSVersionCompare(V, ConstraintToVersion(C)) >= 0;
    
    pcoLte:
      Result := PSVersionCompare(V, ConstraintToVersion(C)) <= 0;
    
    pcoGt:
      Result := PSVersionCompare(V, ConstraintToVersion(C)) > 0;
    
    pcoLt:
      Result := PSVersionCompare(V, ConstraintToVersion(C)) < 0;

    pcoWildcard:
      begin
        // "1.x"   → major match
        // "1.2.x" → major+minor match
        if V.Major <> C.Major then
          Exit(False);
        if C.HasMinor and (V.Minor <> C.Minor) then
          Exit(False);
        Result := True;
      end;
  else
    Result := False;
  end;
end;

{ ═══════════════════════════════════════════════════════════════
  Range (OR of constraints)
  ═══════════════════════════════════════════════════════════════ }

function PSRangeParse(const S: string; out Range: TPSConstraintArray): Boolean;
var
  Parts: TStringArray;
  I, Count: Integer;
  C: TPSConstraint;
begin
  SetLength(Range, 0);
  Result := False;

  if Trim(S) = '' then
  begin
    SetLength(Range, 1);
    Range[0].Op := pcoAny;
    Range[0].Valid := True;
    Exit(True);
  end;

  // Split by "||"
  Parts := S.Split(['||']);
  SetLength(Range, Length(Parts));
  Count := 0;

  for I := 0 to High(Parts) do
  begin
    if not PSConstraintParse(Trim(Parts[I]), C) then
      Exit(False);
    Range[Count] := C;
    Inc(Count);
  end;

  SetLength(Range, Count);
  Result := Count > 0;
end;

function PSRangeMatch(const Range: TPSConstraintArray;
                      const V: TPSVersion): Boolean;
var
  I: Integer;
begin
  for I := 0 to High(Range) do
    if PSConstraintMatch(Range[I], V) then
      Exit(True);
  Result := False;
end;

{ ═══════════════════════════════════════════════════════════════
  Utility
  ═══════════════════════════════════════════════════════════════ }

procedure PSSortVersionsAsc(var Versions: array of TPSVersion);
var
  I, J: Integer;
  Tmp: TPSVersion;
begin
  for I := 0 to High(Versions) - 1 do
    for J := I + 1 to High(Versions) do
      if PSVersionCompare(Versions[I], Versions[J]) > 0 then
      begin
        Tmp := Versions[I];
        Versions[I] := Versions[J];
        Versions[J] := Tmp;
      end;
end;

function PSFindHighestMatch(const Constraint: TPSConstraint;
                            const Available: array of TPSVersion;
                            out Best: TPSVersion): Boolean;
var
  I: Integer;
  Found: Boolean;
begin
  Result := False;
  Best.Valid := False;
  Found := False;

  for I := 0 to High(Available) do
  begin
    if not Available[I].Valid then Continue;
    if PSConstraintMatch(Constraint, Available[I]) then
    begin
      if (not Found) or (PSVersionCompare(Available[I], Best) > 0) then
      begin
        Best := Available[I];
        Found := True;
      end;
    end;
  end;

  Result := Found;
end;

{ ═══════════════════════════════════════════════════════════════
  JSON escape/unescape helpers (tanpa fpjson, untuk serialize)
  ═══════════════════════════════════════════════════════════════ }

function JsonEscape(const S: string): string;
var
  I: Integer;
  C: Char;
begin
  Result := '';
  for I := 1 to Length(S) do
  begin
    C := S[I];
    case C of
      '"':  Result := Result + '\"';
      '\':  Result := Result + '\\';
      #8:   Result := Result + '\b';
      #9:   Result := Result + '\t';
      #10:  Result := Result + '\n';
      #12:  Result := Result + '\f';
      #13:  Result := Result + '\r';
    else
      if C < #32 then
        Result := Result + '\u' + IntToHex(Ord(C), 4)
      else
        Result := Result + C;
    end;
  end;
end;

{ ═══════════════════════════════════════════════════════════════
  Manifest
  ═══════════════════════════════════════════════════════════════ }

constructor TPSManifest.Create;
begin
  inherited Create;
  Dependencies := TPSDependencyList.Create;
  Dependencies.Sorted := True;
  Scripts := TPSScriptList.Create;
  Scripts.Sorted := True;
  Clear;
end;

destructor TPSManifest.Destroy;
begin
  Dependencies.Free;
  Scripts.Free;
  inherited;
end;

procedure TPSManifest.Clear;
begin
  Name := '';
  Version := '';
  Description := '';
  Main := '';
  Author := '';
  License := '';
  Dependencies.Clear;
  Scripts.Clear;
end;

function TPSManifest.Clone: TPSManifest;
var
  I: Integer;
begin
  Result := TPSManifest.Create;
  Result.Name := Name;
  Result.Version := Version;
  Result.Description := Description;
  Result.Main := Main;
  Result.Author := Author;
  Result.License := License;
  for I := 0 to Dependencies.Count - 1 do
    Result.Dependencies.Add(Dependencies.Keys[I], Dependencies.Data[I]);
  for I := 0 to Scripts.Count - 1 do
    Result.Scripts.Add(Scripts.Keys[I], Scripts.Data[I]);
end;

function GetJsonString(J: TJSONObject; const Key: string;
                       const Default: string = ''): string;
var
  V: TJSONData;
begin
  Result := Default;
  if not Assigned(J) then Exit;
  V := J.Find(Key);
  if Assigned(V) and (V.JSONType = jtString) then
    Result := V.AsString;
end;

function PSManifestParse(const Json: string; out M: TPSManifest): Boolean;
var
  Data: TJSONData;
  Root, DepsObj, ScriptsObj: TJSONObject;
  I: Integer;
begin
  Result := False;
  M.Clear;

  Data := nil;
  try
    try
      Data := GetJSON(Json);
    except
      Exit(False);
    end;

    if (not Assigned(Data)) or (Data.JSONType <> jtObject) then Exit;

    Root := TJSONObject(Data);
    M.Name := GetJsonString(Root, 'name');
    M.Version := GetJsonString(Root, 'version');
    M.Description := GetJsonString(Root, 'description');
    M.Main := GetJsonString(Root, 'main');
    M.Author := GetJsonString(Root, 'author');
    M.License := GetJsonString(Root, 'license');

    // Dependencies
    DepsObj := nil;
    if Assigned(Root.Find('dependencies')) and
       (Root.Find('dependencies').JSONType = jtObject) then
      DepsObj := TJSONObject(Root.Find('dependencies'));

    if Assigned(DepsObj) then
      for I := 0 to DepsObj.Count - 1 do
      begin
        if DepsObj.Items[I].JSONType = jtString then
          M.Dependencies.Add(DepsObj.Names[I], DepsObj.Items[I].AsString);
      end;

    // Scripts
    ScriptsObj := nil;
    if Assigned(Root.Find('scripts')) and
       (Root.Find('scripts').JSONType = jtObject) then
      ScriptsObj := TJSONObject(Root.Find('scripts'));

    if Assigned(ScriptsObj) then
      for I := 0 to ScriptsObj.Count - 1 do
      begin
        if ScriptsObj.Items[I].JSONType = jtString then
          M.Scripts.Add(ScriptsObj.Names[I], ScriptsObj.Items[I].AsString);
      end;

    Result := True;
  finally
    if Assigned(Data) then Data.Free;
  end;
end;

function PSManifestLoad(const Path: string; out M: TPSManifest): Boolean;
var
  F: TFileStream;
  S: string;
begin
  Result := False;
  M.Clear;

  if not FileExists(Path) then Exit;

  try
    F := TFileStream.Create(Path, fmOpenRead or fmShareDenyNone);
    try
      SetLength(S, F.Size);
      if F.Size > 0 then F.ReadBuffer(S[1], F.Size);
    finally
      F.Free;
    end;
  except
    Exit(False);
  end;

  Result := PSManifestParse(S, M);
end;

function PSManifestToString(const M: TPSManifest): string;
var
  Root, DepsObj, ScriptsObj: TJSONObject;
  I: Integer;
begin
  Root := TJSONObject.Create;
  try
    Root.Add('name', M.Name);
    Root.Add('version', M.Version);

    if M.Description <> '' then
      Root.Add('description', M.Description);
    if M.Main <> '' then
      Root.Add('main', M.Main);
    if M.Author <> '' then
      Root.Add('author', M.Author);
    if M.License <> '' then
      Root.Add('license', M.License);

    if M.Dependencies.Count > 0 then
    begin
      DepsObj := TJSONObject.Create;
      for I := 0 to M.Dependencies.Count - 1 do
        DepsObj.Add(M.Dependencies.Keys[I], M.Dependencies.Data[I]);
      Root.Add('dependencies', DepsObj);
    end;

    if M.Scripts.Count > 0 then
    begin
      ScriptsObj := TJSONObject.Create;
      for I := 0 to M.Scripts.Count - 1 do
        ScriptsObj.Add(M.Scripts.Keys[I], M.Scripts.Data[I]);
      Root.Add('scripts', ScriptsObj);
    end;

    Result := Root.FormatJSON([], 2);
  finally
    Root.Free;
  end;
end;

function PSManifestSave(const M: TPSManifest; const Path: string): Boolean;
var
  F: TFileStream;
  S: string;
begin
  Result := False;
  try
    S := PSManifestToString(M);
    F := TFileStream.Create(Path, fmCreate);
    try
      if Length(S) > 0 then F.WriteBuffer(S[1], Length(S));
    finally
      F.Free;
    end;
    Result := True;
  except
    Result := False;
  end;
end;

function PSManifestValidate(const M: TPSManifest; out Err: string): Boolean;
var
  V: TPSVersion;
  I: Integer;
  C: TPSConstraint;
  DepName, DepConstraint: string;
begin
  Result := False;
  Err := '';

  if M.Name = '' then
  begin
    Err := 'manifest: field "name" wajib diisi';
    Exit;
  end;

  if not PSPackageNameIsValid(M.Name) then
  begin
    Err := 'manifest: nama package tidak valid: "' + M.Name + '"';
    Exit;
  end;

  if M.Version = '' then
  begin
    Err := 'manifest: field "version" wajib diisi';
    Exit;
  end;

  if not PSVersionParse(M.Version, V) then
  begin
    Err := 'manifest: version bukan semver valid: "' + M.Version + '"';
    Exit;
  end;

  // Validate dependencies
  for I := 0 to M.Dependencies.Count - 1 do
  begin
    DepName := M.Dependencies.Keys[I];
    DepConstraint := M.Dependencies.Data[I];

    if not PSPackageNameIsValid(DepName) then
    begin
      Err := 'manifest: dependency name tidak valid: "' + DepName + '"';
      Exit;
    end;

    if not PSConstraintParse(DepConstraint, C) then
    begin
      Err := 'manifest: constraint untuk "' + DepName +
             '" tidak valid: "' + DepConstraint + '"';
      Exit;
    end;
  end;

  Result := True;
end;

{ ═══════════════════════════════════════════════════════════════
  Resolved + Lockfile
  ═══════════════════════════════════════════════════════════════ }

constructor TPSResolved.Create;
begin
  inherited Create;
  Dependencies := TPSDependencyList.Create;
  Dependencies.Sorted := True;
end;

destructor TPSResolved.Destroy;
begin
  Dependencies.Free;
  inherited;
end;

constructor TPSLockfile.Create;
begin
  inherited Create;
  LockVersion := 1;
  Resolved := TPSResolvedList.Create(True);
end;

destructor TPSLockfile.Destroy;
begin
  Resolved.Free;
  inherited;
end;

procedure TPSLockfile.Clear;
begin
  Resolved.Clear;
  LockVersion := 1;
end;

function TPSLockfile.FindPackage(const Name: string): TPSResolved;
var
  I: Integer;
begin
  Result := nil;
  for I := 0 to Resolved.Count - 1 do
    if Resolved[I].Name = Name then
      Exit(Resolved[I]);
end;

procedure TPSLockfile.AddPackage(const Name, Version, URL, Integrity: string);
var
  R: TPSResolved;
begin
  R := TPSResolved.Create;
  R.Name := Name;
  R.Version := Version;
  R.URL := URL;
  R.Integrity := Integrity;
  Resolved.Add(R);
end;

procedure TPSLockfile.SortByName;
var
  I, J: Integer;
  Tmp: TPSResolved;
begin
  for I := 0 to Resolved.Count - 2 do
    for J := I + 1 to Resolved.Count - 1 do
      if Resolved[I].Name > Resolved[J].Name then
      begin
        Tmp := Resolved[I];
        Resolved[I] := Resolved[J];
        Resolved[J] := Tmp;
      end;
end;

function PSLockfileParse(const Json: string; out L: TPSLockfile): Boolean;
var
  Data: TJSONData;
  Root, ResolvedObj, EntryObj, DepsObj: TJSONObject;
  I, J, VerInt: Integer;
  EntryName: string;
  EntryData: TJSONData;
  R: TPSResolved;
begin
  Result := False;
  L.Clear;

  Data := nil;
  try
    try
      Data := GetJSON(Json);
    except
      Exit(False);
    end;

    if (not Assigned(Data)) or (Data.JSONType <> jtObject) then Exit;

    Root := TJSONObject(Data);

    // lockfileVersion (opsional, default 1)
    VerInt := 1;
    if Assigned(Root.Find('lockfileVersion')) and
       (Root.Find('lockfileVersion').JSONType = jtNumber) then
      VerInt := Root.Find('lockfileVersion').AsInteger;
    L.LockVersion := VerInt;

    // resolved
    if (not Assigned(Root.Find('resolved'))) or
       (Root.Find('resolved').JSONType <> jtObject) then
    begin
      Result := True;   // lockfile kosong valid
      Exit;
    end;

    ResolvedObj := TJSONObject(Root.Find('resolved'));
    for I := 0 to ResolvedObj.Count - 1 do
    begin
      EntryName := ResolvedObj.Names[I];
      EntryData := ResolvedObj.Items[I];
      if EntryData.JSONType <> jtObject then Continue;

      EntryObj := TJSONObject(EntryData);
      R := TPSResolved.Create;
      R.Name := EntryName;
      R.Version := GetJsonString(EntryObj, 'version');
      R.URL := GetJsonString(EntryObj, 'resolved');
      R.Integrity := GetJsonString(EntryObj, 'integrity');

      // Optional deps
      if Assigned(EntryObj.Find('dependencies')) and
         (EntryObj.Find('dependencies').JSONType = jtObject) then
      begin
        DepsObj := TJSONObject(EntryObj.Find('dependencies'));
        for J := 0 to DepsObj.Count - 1 do
          if DepsObj.Items[J].JSONType = jtString then
            R.Dependencies.Add(DepsObj.Names[J], DepsObj.Items[J].AsString);
      end;

      L.Resolved.Add(R);
    end;

    L.SortByName;
    Result := True;
  finally
    if Assigned(Data) then Data.Free;
  end;
end;

function PSLockfileLoad(Path: string; out L: TPSLockfile): Boolean;
var
  F: TFileStream;
  S: string;
begin
  Result := False;
  L.Clear;

  if not FileExists(path) then Exit;

  try
    F := TFileStream.Create(path, fmOpenRead or fmShareDenyNone);
    try
      SetLength(S, F.Size);
      if F.Size > 0 then F.ReadBuffer(S[1], F.Size);
    finally
      F.Free;
    end;
  except
    Exit(False);
  end;

  Result := PSLockfileParse(S, L);
end;

function PSLockfileToString(const L: TPSLockfile): string;
var
  Root, ResolvedObj, EntryObj, DepsObj: TJSONObject;
  I, J: Integer;
begin
  Root := TJSONObject.Create;
  try
    Root.Add('lockfileVersion', L.LockVersion);

    ResolvedObj := TJSONObject.Create;
    for I := 0 to L.Resolved.Count - 1 do
    begin
      EntryObj := TJSONObject.Create;
      EntryObj.Add('version', L.Resolved[I].Version);
      EntryObj.Add('resolved', L.Resolved[I].URL);
      EntryObj.Add('integrity', L.Resolved[I].Integrity);

      if L.Resolved[I].Dependencies.Count > 0 then
      begin
        DepsObj := TJSONObject.Create;
        for J := 0 to L.Resolved[I].Dependencies.Count - 1 do
          DepsObj.Add(L.Resolved[I].Dependencies.Keys[J],
                      L.Resolved[I].Dependencies.Data[J]);
        EntryObj.Add('dependencies', DepsObj);
      end;

      ResolvedObj.Add(L.Resolved[I].Name, EntryObj);
    end;

    Root.Add('resolved', ResolvedObj);

    Result := Root.FormatJSON([], 2);
  finally
    Root.Free;
  end;
end;

function PSLockfileSave(const L: TPSLockfile; const Path: string): Boolean;
var
  F: TFileStream;
  S: string;
begin
  Result := False;
  try
    S := PSLockfileToString(L);
    F := TFileStream.Create(Path, fmCreate);
    try
      if Length(S) > 0 then F.WriteBuffer(S[1], Length(S));
    finally
      F.Free;
    end;
    Result := True;
  except
    Result := False;
  end;
end;

{ ═══════════════════════════════════════════════════════════════
  Scope helpers
  ═══════════════════════════════════════════════════════════════ }

procedure PSParsePackageName(const FullName: string;
  out Scope, Name: string);
var
  P: Integer;
begin
  Scope := '';
  Name := FullName;

  if (Length(FullName) > 0) and (FullName[1] = '@') then
  begin
    P := Pos('/', FullName);
    if P > 1 then
    begin
      Scope := Copy(FullName, 2, P - 2);      // tanpa '@'
      Name := Copy(FullName, P + 1, Length(FullName));
    end;
  end;
end;

function NamePartIsValid(const S: string): Boolean;
var
  I: Integer;
  C: Char;
begin
  Result := False;
  if S = '' then Exit;

  for I := 1 to Length(S) do
  begin
    C := S[I];
    if not ((C >= 'a') and (C <= 'z')) and
       not ((C >= '0') and (C <= '9')) and
       (C <> '-') and (C <> '_') then
      Exit;
  end;
  Result := True;
end;

function PSPackageNameIsValid(const FullName: string): Boolean;
var
  Scope, Name: string;
begin
  Result := False;
  if FullName = '' then Exit;

  if FullName[1] = '@' then
  begin
    PSParsePackageName(FullName, Scope, Name);
    if Scope = '' then Exit;
    if not NamePartIsValid(Scope) then Exit;
    if not NamePartIsValid(Name) then Exit;
    Result := True;
  end
  else
  begin
    Result := NamePartIsValid(FullName);
  end;
end;

function PSPackageCachePath(const FullName, Version: string): string;
var
  Scope, Name: string;
begin
  PSParsePackageName(FullName, Scope, Name);
  if Scope <> '' then
    Result := '@' + Scope + '/' + Name + '-' + Version
  else
    Result := Name + '-' + Version;
end;

{ ═══════════════════════════════════════════════════════════════
  Resolver
  ═══════════════════════════════════════════════════════════════ }

constructor TPSResolver.Create(Registry: IPSRegistry);
begin
  inherited Create;
  FRegistry := Registry;
  FResolved := TPSDependencyList.Create;
  FResolved.Sorted := True;
  FResolving := TStringList.Create;
  FResolving.Sorted := False;
  FMaxDepth := 64;   // hard limit untuk rekursi
end;

destructor TPSResolver.Destroy;
begin
  FResolved.Free;
  FResolving.Free;
  inherited;
end;

function TPSResolver.ResolveRecursive(const Name, ConstraintStr, ParentChain: string;
                                      Depth: Integer;
                                      out Err: string): Boolean;
var
  Constraint: TPSConstraint;
  Available: TPSVersionArray;
  Best: TPSVersion;
  ExistingIdx: Integer;
  ExistingVersion: string;
  M: TPSManifest;
  I: Integer;
  DepName, DepConstraint: string;
  NewChain: string;
begin
  Result := False;
  Err := '';

  // Depth guard
  if Depth > FMaxDepth then
  begin
    Err := 'resolver: dependency chain terlalu dalam (> ' +
           IntToStr(FMaxDepth) + ') — kemungkinan cycle';
    Exit;
  end;

  // Cycle detection
  if FResolving.IndexOf(Name) >= 0 then
  begin
    Err := 'resolver: circular dependency terdeteksi: ' +
           ParentChain + ' → ' + Name;
    Exit;
  end;

  // Parse constraint
  if not PSConstraintParse(ConstraintStr, Constraint) then
  begin
    Err := 'resolver: constraint "' + ConstraintStr +
           '" untuk "' + Name + '" tidak valid';
    Exit;
  end;

  // Cek apakah sudah resolved dengan versi lain (conflict detection)
  ExistingIdx := FResolved.IndexOf(Name);
  if ExistingIdx >= 0 then
  begin
    ExistingVersion := FResolved.Data[ExistingIdx];
    if PSVersionParse(ExistingVersion, Best) then
    begin
      if PSConstraintMatch(Constraint, Best) then
      begin
        // Sudah ada versi yang kompatibel, reuse
        Result := True;
        Exit;
      end
      else
      begin
        // Conflict: versi yang sudah di-resolve tidak match constraint baru
        Err := 'resolver: conflict untuk "' + Name + '": ' +
               'sudah di-resolve ke ' + ExistingVersion +
               ', tapi constraint baru "' + ConstraintStr +
               '" (dari ' + ParentChain + ') memerlukan versi berbeda';
        Exit;
      end;
    end;
  end;

  // Fetch available versions
  Available := FRegistry.GetVersions(Name);
  if Length(Available) = 0 then
  begin
    Err := 'resolver: package "' + Name + '" tidak ditemukan di registry';
    Exit;
  end;

  // Find highest matching version
  if not PSFindHighestMatch(Constraint, Available, Best) then
  begin
    Err := 'resolver: tidak ada versi "' + Name +
           '" yang match constraint "' + ConstraintStr + '"';
    Exit;
  end;

  // Fetch manifest untuk versi ini
  M := FRegistry.GetManifest(Name, PSVersionToString(Best));
  if not Assigned(M) then
  begin
    Err := 'resolver: manifest untuk ' + Name + '@' +
           PSVersionToString(Best) + ' tidak tersedia';
    Exit;
  end;

  try
    // Register resolved
    FResolved.Add(Name, PSVersionToString(Best));
    FResolving.Add(Name);
    try
      // Recurse ke deps
      for I := 0 to M.Dependencies.Count - 1 do
      begin
        DepName := M.Dependencies.Keys[I];
        DepConstraint := M.Dependencies.Data[I];
  
        if ParentChain = '' then
          NewChain := Name
        else
          NewChain := ParentChain + ' → ' + Name;
  
        if not ResolveRecursive(DepName, DepConstraint, NewChain,
                                Depth + 1, Err) then
        begin
          // ⚠️ JANGAN cleanup di sini — biar finally yang handle.
          // Cleanup ganda = EStringListError.
          Exit(False);
        end;
      end;
  
      Result := True;
    finally
      // Pop FResolving (entry kita sendiri)
      if FResolving.Count > 0 then
        FResolving.Delete(FResolving.Count - 1);
      // Rollback FResolved kalau gagal
      if not Result then
      begin
        ExistingIdx := FResolved.IndexOf(Name);
        if ExistingIdx >= 0 then
          FResolved.Delete(ExistingIdx);
      end;
    end;
  finally
    M.Free;
  end;
end;

function TPSResolver.Resolve(Root: TPSManifest;
  out L: TPSLockfile;
  out Err: string): Boolean;
var
  I, J: Integer;
  DepName, DepConstraint: string;
  R: TPSResolved;
  Manifest: TPSManifest;
  VersionStr: string;
begin
  Result := False;
  Err := '';
  L.Clear;

  if not Assigned(Root) then
  begin
    Err := 'resolver: root manifest nil';
    Exit;
  end;

  if not Assigned(FRegistry) then
  begin
    Err := 'resolver: registry tidak di-set';
    Exit;
  end;

  // Reset state
  FResolved.Clear;
  FResolving.Clear;

  // Resolve semua root deps
  for I := 0 to Root.Dependencies.Count - 1 do
  begin
    DepName := Root.Dependencies.Keys[I];
    DepConstraint := Root.Dependencies.Data[I];

    if not ResolveRecursive(DepName, DepConstraint, '', 0, Err) then
      Exit(False);
  end;

  // Build lockfile dengan metadata lengkap
  // FResolved sekarang berisi (name → version) map, tapi urutannya
  // arbitrary. Iterate sorted.
  FResolved.Sort;

  for I := 0 to FResolved.Count - 1 do
  begin
    DepName := FResolved.Keys[I];
    VersionStr := FResolved.Data[I];

    R := L.FindPackage(DepName);
    if Assigned(R) then Continue;

    R := TPSResolved.Create;
    R.Name := DepName;
    R.Version := VersionStr;
    R.URL := FRegistry.GetDownloadURL(DepName, VersionStr);
    R.Integrity := FRegistry.GetIntegrity(DepName, VersionStr);

    // Snapshot deps untuk lock consistency
    Manifest := FRegistry.GetManifest(DepName, VersionStr);
    if Assigned(Manifest) then
    begin
      try
        for J := 0 to Manifest.Dependencies.Count - 1 do
          R.Dependencies.Add(Manifest.Dependencies.Keys[J],
                             Manifest.Dependencies.Data[J]);
      finally
        Manifest.Free;
      end;
    end;

    L.Resolved.Add(R);
  end;

  L.SortByName;
  Result := True;
end;


initialization
finalization

end.