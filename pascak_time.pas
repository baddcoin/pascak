{ ====================================================================
  pascak_time.pas — Time / Date utilities untuk VM Pascak
  ====================================================================
  Pure Pascal. Cross-platform. No external deps.
  Fixed-offset timezone — DST not handled.
  ==================================================================== }
unit pascak_time;

{$MODE OBJFPC}{$H+}

interface

uses
  SysUtils, DateUtils;

type
  ETimeError = class(Exception);

// ─── ISO8601 ───
// Format: "2023-11-13T22:13:20Z" atau dengan offset "2023-11-13T22:13:20+07:00"
function TimeToISO8601(Ts: Int64; OffsetSec: Integer = 0): string;
function TimeFromISO8601(const S: string; out Ts: Int64): Boolean;

// ─── Custom format ───
// Token: yyyy yy MM dd HH mm ss
// Contoh: "yyyy-MM-dd HH:mm:ss"
function TimeFormat(Ts: Int64; const Fmt: string;
                     OffsetSec: Integer = 0): string;

// ─── Diff ───
procedure TimeDiffParts(Ts1, Ts2: Int64;
                        out Days, Hours, Minutes, Seconds, Total: Int64);

// ─── Arithmetic ───
function TimeAdd(Ts: Int64; DeltaSec: Int64): Int64;
function TimeAddDays(Ts: Int64; Days: Int64): Int64;
function TimeAddHours(Ts: Int64; Hours: Int64): Int64;
function TimeAddMinutes(Ts: Int64; Minutes: Int64): Int64;

// ─── Boundary helpers ───
function TimeStartOfDay(Ts: Int64; OffsetSec: Integer = 0): Int64;
function TimeStartOfMonth(Ts: Int64; OffsetSec: Integer = 0): Int64;
function TimeStartOfYear(Ts: Int64; OffsetSec: Integer = 0): Int64;

// ─── Timezone offset lookup (fixed offset, no DST) ───
function TimeZoneOffsetSeconds(const ZoneName: string): Integer;

implementation

// ════════════════════════════════════════════════════════════════
//  ISO8601
// ════════════════════════════════════════════════════════════════

function FormatOffset(OffsetSec: Integer): string;
var
  Sign: Char;
  AbsOff, H, M: Integer;
begin
  if OffsetSec = 0 then Exit('Z');
  if OffsetSec < 0 then
  begin
    Sign := '-';
    AbsOff := -OffsetSec;
  end
  else
  begin
    Sign := '+';
    AbsOff := OffsetSec;
  end;
  H := AbsOff div 3600;
  M := (AbsOff mod 3600) div 60;
  Result := Format('%s%.2d:%.2d', [Sign, H, M]);
end;

function TimeToISO8601(Ts: Int64; OffsetSec: Integer = 0): string;
var
  DT: TDateTime;
begin
  try
    DT := UnixToDateTime(Ts + OffsetSec, True);
    Result := FormatDateTime('yyyy-mm-dd"T"hh:nn:ss', DT) + FormatOffset(OffsetSec);
  except
    Result := '';
  end;
end;

function TimeFromISO8601(const S: string; out Ts: Int64): Boolean;
var
  W: string;
  Y, Mo, D, H, Mi, Se, TmpI: Integer;
  OffsetSec, Sign: Integer;
  DT: TDateTime;
  i: Integer;
begin
  Result := False;
  Ts := 0;
  OffsetSec := 0;

  W := Trim(S);
  if W = '' then Exit;

  // Strip timezone suffix
  if (Length(W) > 0) and ((W[Length(W)] = 'Z') or (W[Length(W)] = 'z')) then
    SetLength(W, Length(W) - 1)
  else if (Length(W) >= 6) and
          ((W[Length(W) - 5] = '+') or (W[Length(W) - 5] = '-')) then
  begin
    if W[Length(W) - 5] = '+' then Sign := 1 else Sign := -1;
    H := StrToIntDef(Copy(W, Length(W) - 4, 2), -1);
    Mi := StrToIntDef(Copy(W, Length(W) - 1, 2), -1);
    if (H >= 0) and (Mi >= 0) then
    begin
      OffsetSec := Sign * (H * 3600 + Mi * 60);
      SetLength(W, Length(W) - 6);
    end;
  end;

  // Replace T dengan space
  for i := 1 to Length(W) do
    if (W[i] = 'T') or (W[i] = 't') then
    begin
      W[i] := ' ';
      Break;
    end;

  // Parse components
  Y := StrToIntDef(Copy(W, 1, 4), -1);
  if Y < 0 then Exit;

  Mo := 1; D := 1; H := 0; Mi := 0; Se := 0;

  if Length(W) >= 7 then
  begin
    TmpI := StrToIntDef(Copy(W, 6, 2), 1);
    if TmpI >= 1 then Mo := TmpI;
  end;
  if Length(W) >= 10 then
  begin
    TmpI := StrToIntDef(Copy(W, 9, 2), 1);
    if TmpI >= 1 then D := TmpI;
  end;
  if Length(W) >= 13 then
    H := StrToIntDef(Copy(W, 12, 2), 0);
  if Length(W) >= 16 then
    Mi := StrToIntDef(Copy(W, 15, 2), 0);
  if Length(W) >= 19 then
    Se := StrToIntDef(Copy(W, 18, 2), 0);

  try
    DT := EncodeDateTime(Y, Mo, D, H, Mi, Se, 0);
    Ts := DateTimeToUnix(DT, True) - OffsetSec;
    Result := True;
  except
    Result := False;
  end;
end;

// ════════════════════════════════════════════════════════════════
//  Custom Format
// ════════════════════════════════════════════════════════════════

function TimeFormat(Ts: Int64; const Fmt: string; OffsetSec: Integer = 0): string;
var
  DT: TDateTime;
  Y, Mo, D, H, Mi, Se, MS: Word;
  i: Integer;
begin
  try
    DT := UnixToDateTime(Ts + OffsetSec, True);
    DecodeDateTime(DT, Y, Mo, D, H, Mi, Se, MS);
  except
    Exit('');
  end;

  Result := '';
  i := 1;
  while i <= Length(Fmt) do
  begin
    if (i + 3 <= Length(Fmt)) and (Copy(Fmt, i, 4) = 'yyyy') then
    begin
      Result := Result + Format('%.4d', [Y]);
      Inc(i, 4);
    end
    else if (i + 1 <= Length(Fmt)) and (Copy(Fmt, i, 2) = 'yy') then
    begin
      Result := Result + Format('%.2d', [Y mod 100]);
      Inc(i, 2);
    end
    else if (i + 1 <= Length(Fmt)) and (Copy(Fmt, i, 2) = 'MM') then
    begin
      Result := Result + Format('%.2d', [Mo]);
      Inc(i, 2);
    end
    else if (i + 1 <= Length(Fmt)) and (Copy(Fmt, i, 2) = 'dd') then
    begin
      Result := Result + Format('%.2d', [D]);
      Inc(i, 2);
    end
    else if (i + 1 <= Length(Fmt)) and (Copy(Fmt, i, 2) = 'HH') then
    begin
      Result := Result + Format('%.2d', [H]);
      Inc(i, 2);
    end
    else if (i + 1 <= Length(Fmt)) and (Copy(Fmt, i, 2) = 'mm') then
    begin
      Result := Result + Format('%.2d', [Mi]);
      Inc(i, 2);
    end
    else if (i + 1 <= Length(Fmt)) and (Copy(Fmt, i, 2) = 'ss') then
    begin
      Result := Result + Format('%.2d', [Se]);
      Inc(i, 2);
    end
    else
    begin
      Result := Result + Fmt[i];
      Inc(i);
    end;
  end;
end;

// ════════════════════════════════════════════════════════════════
//  Diff
// ════════════════════════════════════════════════════════════════

procedure TimeDiffParts(Ts1, Ts2: Int64;
                        out Days, Hours, Minutes, Seconds, Total: Int64);
var
  Diff: Int64;
begin
  Diff := Ts2 - Ts1;
  Total := Diff;
  if Diff < 0 then Diff := -Diff;

  Days := Diff div 86400;
  Diff := Diff mod 86400;
  Hours := Diff div 3600;
  Diff := Diff mod 3600;
  Minutes := Diff div 60;
  Seconds := Diff mod 60;
end;

// ════════════════════════════════════════════════════════════════
//  Arithmetic
// ════════════════════════════════════════════════════════════════

function TimeAdd(Ts: Int64; DeltaSec: Int64): Int64;
begin
  Result := Ts + DeltaSec;
end;

function TimeAddDays(Ts: Int64; Days: Int64): Int64;
begin
  Result := Ts + Days * 86400;
end;

function TimeAddHours(Ts: Int64; Hours: Int64): Int64;
begin
  Result := Ts + Hours * 3600;
end;

function TimeAddMinutes(Ts: Int64; Minutes: Int64): Int64;
begin
  Result := Ts + Minutes * 60;
end;

// ════════════════════════════════════════════════════════════════
//  Boundary helpers
// ════════════════════════════════════════════════════════════════

function TimeStartOfDay(Ts: Int64; OffsetSec: Integer = 0): Int64;
var
  Local, DayStart: Int64;
begin
  Local := Ts + OffsetSec;
  // Round down to nearest 86400
  DayStart := Local - (Local mod 86400);
  if (Local < 0) and (Local mod 86400 <> 0) then
    Dec(DayStart, 86400);
  Result := DayStart - OffsetSec;
end;

function TimeStartOfMonth(Ts: Int64; OffsetSec: Integer = 0): Int64;
var
  DT: TDateTime;
  Y, Mo, D, H, Mi, Se, MS: Word;
begin
  try
    DT := UnixToDateTime(Ts + OffsetSec, True);
    DecodeDateTime(DT, Y, Mo, D, H, Mi, Se, MS);
    DT := EncodeDateTime(Y, Mo, 1, 0, 0, 0, 0);
    Result := DateTimeToUnix(DT, True) - OffsetSec;
  except
    Result := Ts;
  end;
end;

function TimeStartOfYear(Ts: Int64; OffsetSec: Integer = 0): Int64;
var
  DT: TDateTime;
  Y, Mo, D, H, Mi, Se, MS: Word;
begin
  try
    DT := UnixToDateTime(Ts + OffsetSec, True);
    DecodeDateTime(DT, Y, Mo, D, H, Mi, Se, MS);
    DT := EncodeDateTime(Y, 1, 1, 0, 0, 0, 0);
    Result := DateTimeToUnix(DT, True) - OffsetSec;
  except
    Result := Ts;
  end;
end;

// ════════════════════════════════════════════════════════════════
//  Timezone offset (fixed, no DST)
// ════════════════════════════════════════════════════════════════

function TimeZoneOffsetSeconds(const ZoneName: string): Integer;
var
  U: string;
begin
  U := UpperCase(Trim(ZoneName));
  if (U = '') or (U = 'UTC') or (U = 'GMT') then Exit(0);

  // Indonesia
  if (U = 'WIB') or (U = 'ASIA/JAKARTA') or (U = 'JAKARTA') then Exit(7 * 3600);
  if (U = 'WITA') or (U = 'ASIA/MAKASSAR') or (U = 'MAKASSAR') then Exit(8 * 3600);
  if (U = 'WIT') or (U = 'ASIA/JAYAPURA') or (U = 'JAYAPURA') then Exit(9 * 3600);

  // Asia
  if (U = 'ASIA/SINGAPORE') or (U = 'SINGAPORE') or (U = 'SGT') then Exit(8 * 3600);
  if (U = 'ASIA/TOKYO') or (U = 'TOKYO') or (U = 'JST') then Exit(9 * 3600);
  if (U = 'ASIA/SHANGHAI') or (U = 'SHANGHAI') then Exit(8 * 3600);
  if (U = 'ASIA/HONG_KONG') or (U = 'HONG_KONG') then Exit(8 * 3600);
  if (U = 'ASIA/KOLKATA') or (U = 'KOLKATA') or (U = 'IST') then Exit(5 * 3600 + 30 * 60);
  if (U = 'ASIA/DUBAI') or (U = 'DUBAI') then Exit(4 * 3600);
  if (U = 'ASIA/SEOUL') or (U = 'SEOUL') then Exit(9 * 3600);

  // Eropa
  if (U = 'EUROPE/LONDON') or (U = 'LONDON') then Exit(0);
  if (U = 'EUROPE/PARIS') or (U = 'PARIS') or (U = 'CET') then Exit(1 * 3600);
  if (U = 'EUROPE/BERLIN') or (U = 'BERLIN') then Exit(1 * 3600);
  if (U = 'EUROPE/MOSCOW') or (U = 'MOSCOW') then Exit(3 * 3600);

  // Amerika
  if (U = 'AMERICA/NEW_YORK') or (U = 'NEW_YORK') or (U = 'EST') then Exit(-5 * 3600);
  if (U = 'AMERICA/CHICAGO') or (U = 'CHICAGO') or (U = 'CST') then Exit(-6 * 3600);
  if (U = 'AMERICA/DENVER') or (U = 'DENVER') or (U = 'MST') then Exit(-7 * 3600);
  if (U = 'AMERICA/LOS_ANGELES') or (U = 'LOS_ANGELES') or (U = 'PST') then Exit(-8 * 3600);
  if (U = 'AMERICA/SAO_PAULO') or (U = 'SAO_PAULO') then Exit(-3 * 3600);

  // Oceania
  if (U = 'AUSTRALIA/SYDNEY') or (U = 'SYDNEY') or (U = 'AEST') then Exit(10 * 3600);
  if (U = 'AUSTRALIA/PERTH') or (U = 'PERTH') then Exit(8 * 3600);
  if (U = 'PACIFIC/AUCKLAND') or (U = 'AUCKLAND') then Exit(12 * 3600);

  Result := 0;
end;

initialization
finalization

end.