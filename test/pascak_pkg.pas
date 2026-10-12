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

interface

uses
  SysUtils, Classes;

type
  EPSPkgError = class(Exception);

  { ─── Version ─── }
  TPSVersion = record
    Major: Integer;
    Minor: Integer;
    Patch: Integer;
    Valid: Boolean;
  end;

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

{ ─── Version ops ─── }

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

function PSVersionCompare(const A, B: TPSVersion): Integer;
begin
  if A.Major <> B.Major then
    Exit(Sign(A.Major - B.Major));
  if A.Minor <> B.Minor then
    Exit(Sign(A.Minor - B.Minor));
  Result := Sign(A.Patch - B.Patch);
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
    pcoCaret:    Result := '^' + PSVersionToString(
                              TPSVersion(C));
    pcoTilde:    Result := '~' + PSVersionToString(
                              TPSVersion(C));
    pcoGte:      Result := '>=' + PSVersionToString(
                              TPSVersion(C));
    pcoLte:      Result := '<=' + PSVersionToString(
                              TPSVersion(C));
    pcoGt:       Result := '>' + PSVersionToString(
                              TPSVersion(C));
    pcoLt:       Result := '<' + PSVersionToString(
                              TPSVersion(C));
    pcoWildcard:
      begin
        Result := IntToStr(C.Major) + '.';
        if C.HasMinor then
          Result := Result + IntToStr(C.Minor) + '.';
        Result := Result + 'x';
      end;
  else
    Result := PSVersionToString(TPSVersion(C));
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
                    ((V.Minor = C.Minor) and (V.Patch >= C.Patch));
        else if C.Minor > 0 then
          // 0.x.y: minor locked
          Result := (V.Minor = C.Minor) and (V.Patch >= C.Patch);
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
      Result := PSVersionCompare(V, TPSVersion(C)) >= 0;

    pcoLte:
      Result := PSVersionCompare(V, TPSVersion(C)) <= 0;

    pcoGt:
      Result := PSVersionCompare(V, TPSVersion(C)) > 0;

    pcoLt:
      Result := PSVersionCompare(V, TPSVersion(C)) < 0;

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

initialization
finalization

end.