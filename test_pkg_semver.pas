{ ====================================================================
  test_pkg_semver.pas — Semver parser + matcher test
  ====================================================================
  Compile & run:
    fpc -Mobjfpc -Sh test/test_pkg_semver.pas
    ./test_pkg_semver
  ==================================================================== }

program test_pkg_semver;

{$MODE OBJFPC}{$H+}

uses
  SysUtils, pascak_pkg;

var
  GPassed: Integer = 0;
  GFailed: Integer = 0;

procedure Check(const Name: string; Cond: Boolean);
begin
  if Cond then
  begin
    Inc(GPassed);
    WriteLn('  [OK]   ', Name);
  end
  else
  begin
    Inc(GFailed);
    WriteLn('  [FAIL] ', Name);
  end;
end;

procedure CheckEqInt(const Name: string; Expected, Actual: Integer);
begin
  if Expected = Actual then
  begin
    Inc(GPassed);
    WriteLn('  [OK]   ', Name);
  end
  else
  begin
    Inc(GFailed);
    WriteLn('  [FAIL] ', Name, ' — expected ', Expected, ', got ', Actual);
  end;
end;

procedure CheckEqStr(const Name, Expected, Actual: string);
begin
  if Expected = Actual then
  begin
    Inc(GPassed);
    WriteLn('  [OK]   ', Name);
  end
  else
  begin
    Inc(GFailed);
    WriteLn('  [FAIL] ', Name, ' — expected [', Expected, '], got [', Actual, ']');
  end;
end;

// ═══════════════════════════════════════════════════════════════
//  Test 1: Version parsing
// ═══════════════════════════════════════════════════════════════
procedure TestVersionParse;
var
  V: TPSVersion;
begin
  WriteLn('Test 1: Version parsing');

  Check('parse "1.2.3"', PSVersionParse('1.2.3', V));
  CheckEqInt('  major=1', 1, V.Major);
  CheckEqInt('  minor=2', 2, V.Minor);
  CheckEqInt('  patch=3', 3, V.Patch);

  Check('parse "1.2"', PSVersionParse('1.2', V));
  CheckEqInt('  minor=2', 2, V.Minor);
  CheckEqInt('  patch=0', 0, V.Patch);

  Check('parse "1"', PSVersionParse('1', V));
  CheckEqInt('  minor=0', 0, V.Minor);

  Check('parse "10.20.30"', PSVersionParse('10.20.30', V));
  CheckEqInt('  major=10', 10, V.Major);

  Check('reject "1.2.3.4"', not PSVersionParse('1.2.3.4', V));
  Check('reject "abc"', not PSVersionParse('abc', V));
  Check('reject ""', not PSVersionParse('', V));
  Check('reject "01.2.3" (leading zero)', not PSVersionParse('01.2.3', V));
  Check('reject "1.2.3-rc1" (prerelease)', not PSVersionParse('1.2.3-rc1', V));
  Check('accept "0.0.0"', PSVersionParse('0.0.0', V));

  Check('  "1.2.3" → tostring round-trip',
        PSVersionParse('1.2.3', V) and (PSVersionToString(V) = '1.2.3'));
end;

// ═══════════════════════════════════════════════════════════════
//  Test 2: Version compare
// ═══════════════════════════════════════════════════════════════
procedure TestVersionCompare;
var
  A, B: TPSVersion;
begin
  WriteLn('Test 2: Version compare');

  PSVersionParse('1.2.3', A);
  PSVersionParse('1.2.4', B);
  CheckEqInt('1.2.3 < 1.2.4', -1, PSVersionCompare(A, B));
  CheckEqInt('1.2.4 > 1.2.3', 1, PSVersionCompare(B, A));
  CheckEqInt('1.2.3 == 1.2.3', 0, PSVersionCompare(A, A));

  PSVersionParse('2.0.0', B);
  CheckEqInt('1.2.3 < 2.0.0', -1, PSVersionCompare(A, B));

  PSVersionParse('1.10.0', B);
  CheckEqInt('1.2.3 < 1.10.0', -1, PSVersionCompare(A, B));

  PSVersionParse('1.2.3', B);
  Check('PSVersionEquals', PSVersionEquals(A, B));
end;

// ═══════════════════════════════════════════════════════════════
//  Test 3: Constraint parsing
// ═══════════════════════════════════════════════════════════════
procedure TestConstraintParse;
var
  C: TPSConstraint;
begin
  WriteLn('Test 3: Constraint parsing');

  Check('parse "1.2.3"', PSConstraintParse('1.2.3', C));
  Check('  op=Exact', C.Op = pcoExact);

  Check('parse "^1.2.3"', PSConstraintParse('^1.2.3', C));
  Check('  op=Caret', C.Op = pcoCaret);

  Check('parse "~1.2.3"', PSConstraintParse('~1.2.3', C));
  Check('  op=Tilde', C.Op = pcoTilde);

  Check('parse ">=1.0.0"', PSConstraintParse('>=1.0.0', C));
  Check('  op=Gte', C.Op = pcoGte);

  Check('parse "<2.0.0"', PSConstraintParse('<2.0.0', C));
  Check('  op=Lt', C.Op = pcoLt);

  Check('parse "*"', PSConstraintParse('*', C));
  Check('  op=Any', C.Op = pcoAny);

  Check('parse "1.x"', PSConstraintParse('1.x', C));
  Check('  op=Wildcard', C.Op = pcoWildcard);
  Check('  hasMinor=false', not C.HasMinor);

  Check('parse "1.2.x"', PSConstraintParse('1.2.x', C));
  Check('  op=Wildcard', C.Op = pcoWildcard);
  Check('  hasMinor=true', C.HasMinor);
  Check('  hasPatch=false', not C.HasPatch);

  Check('reject "abc"', not PSConstraintParse('abc', C));
  Check('reject "^"', not PSConstraintParse('^', C));
end;

// ═══════════════════════════════════════════════════════════════
//  Test 4: Caret (^) matching
// ═══════════════════════════════════════════════════════════════
procedure TestCaret;
var
  C: TPSConstraint;
  V: TPSVersion;
begin
  WriteLn('Test 4: Caret (^) matching');

  PSConstraintParse('^1.2.3', C);

  PSVersionParse('1.2.3', V); Check('1.2.3 match (lower bound)', PSConstraintMatch(C, V));
  PSVersionParse('1.2.4', V); Check('1.2.4 match', PSConstraintMatch(C, V));
  PSVersionParse('1.9.9', V); Check('1.9.9 match', PSConstraintMatch(C, V));
  PSVersionParse('1.2.2', V); Check('1.2.2 reject (below)', not PSConstraintMatch(C, V));
  PSVersionParse('2.0.0', V); Check('2.0.0 reject (above)', not PSConstraintMatch(C, V));
  PSVersionParse('0.9.9', V); Check('0.9.9 reject', not PSConstraintMatch(C, V));

  // ^0.2.3 → minor-locked
  PSConstraintParse('^0.2.3', C);
  PSVersionParse('0.2.3', V); Check('^0.2.3 → 0.2.3 match', PSConstraintMatch(C, V));
  PSVersionParse('0.2.9', V); Check('^0.2.3 → 0.2.9 match', PSConstraintMatch(C, V));
  PSVersionParse('0.3.0', V); Check('^0.2.3 → 0.3.0 reject', not PSConstraintMatch(C, V));

  // ^0.0.3 → patch-locked
  PSConstraintParse('^0.0.3', C);
  PSVersionParse('0.0.3', V); Check('^0.0.3 → 0.0.3 match', PSConstraintMatch(C, V));
  PSVersionParse('0.0.4', V); Check('^0.0.3 → 0.0.4 reject', not PSConstraintMatch(C, V));
end;

// ═══════════════════════════════════════════════════════════════
//  Test 5: Tilde (~) matching
// ═══════════════════════════════════════════════════════════════
procedure TestTilde;
var
  C: TPSConstraint;
  V: TPSVersion;
begin
  WriteLn('Test 5: Tilde (~) matching');

  PSConstraintParse('~1.2.3', C);

  PSVersionParse('1.2.3', V); Check('1.2.3 match', PSConstraintMatch(C, V));
  PSVersionParse('1.2.9', V); Check('1.2.9 match', PSConstraintMatch(C, V));
  PSVersionParse('1.2.2', V); Check('1.2.2 reject', not PSConstraintMatch(C, V));
  PSVersionParse('1.3.0', V); Check('1.3.0 reject', not PSConstraintMatch(C, V));
  PSVersionParse('1.9.9', V); Check('1.9.9 reject', not PSConstraintMatch(C, V));
end;

// ═══════════════════════════════════════════════════════════════
//  Test 6: Range (>=, <=, >, <, exact)
// ═══════════════════════════════════════════════════════════════
procedure TestRangeOps;
var
  C: TPSConstraint;
  V: TPSVersion;
begin
  WriteLn('Test 6: Range operators');

  PSConstraintParse('>=1.2.0', C);
  PSVersionParse('1.2.0', V); Check('>=1.2.0 → 1.2.0 match', PSConstraintMatch(C, V));
  PSVersionParse('1.1.9', V); Check('>=1.2.0 → 1.1.9 reject', not PSConstraintMatch(C, V));
  PSVersionParse('9.9.9', V); Check('>=1.2.0 → 9.9.9 match', PSConstraintMatch(C, V));

  PSConstraintParse('<2.0.0', C);
  PSVersionParse('1.9.9', V); Check('<2.0.0 → 1.9.9 match', PSConstraintMatch(C, V));
  PSVersionParse('2.0.0', V); Check('<2.0.0 → 2.0.0 reject', not PSConstraintMatch(C, V));

  PSConstraintParse('1.2.3', C);
  PSVersionParse('1.2.3', V); Check('exact 1.2.3 match', PSConstraintMatch(C, V));
  PSVersionParse('1.2.4', V); Check('exact 1.2.3 → 1.2.4 reject', not PSConstraintMatch(C, V));
end;

// ═══════════════════════════════════════════════════════════════
//  Test 7: Wildcard + Any
// ═══════════════════════════════════════════════════════════════
procedure TestWildcard;
var
  C: TPSConstraint;
  V: TPSVersion;
begin
  WriteLn('Test 7: Wildcard + Any');

  PSConstraintParse('*', C);
  PSVersionParse('0.0.0', V); Check('* matches 0.0.0', PSConstraintMatch(C, V));
  PSVersionParse('99.99.99', V); Check('* matches 99.99.99', PSConstraintMatch(C, V));

  PSConstraintParse('1.x', C);
  PSVersionParse('1.0.0', V); Check('1.x → 1.0.0 match', PSConstraintMatch(C, V));
  PSVersionParse('1.9.9', V); Check('1.x → 1.9.9 match', PSConstraintMatch(C, V));
  PSVersionParse('2.0.0', V); Check('1.x → 2.0.0 reject', not PSConstraintMatch(C, V));
  PSVersionParse('0.9.9', V); Check('1.x → 0.9.9 reject', not PSConstraintMatch(C, V));

  PSConstraintParse('1.2.x', C);
  PSVersionParse('1.2.0', V); Check('1.2.x → 1.2.0 match', PSConstraintMatch(C, V));
  PSVersionParse('1.2.99', V); Check('1.2.x → 1.2.99 match', PSConstraintMatch(C, V));
  PSVersionParse('1.3.0', V); Check('1.2.x → 1.3.0 reject', not PSConstraintMatch(C, V));
end;

// ═══════════════════════════════════════════════════════════════
//  Test 8: Range (OR)
// ═══════════════════════════════════════════════════════════════
procedure TestRangeOr;
var
  R: TPSConstraintArray;
  V: TPSVersion;
begin
  WriteLn('Test 8: Range OR (||)');

  Check('parse "^1.2.0 || >=2.0.0"',
        PSRangeParse('^1.2.0 || >=2.0.0', R));
  CheckEqInt('2 constraints', 2, Length(R));

  PSVersionParse('1.5.0', V); Check('1.5.0 matches (via ^)', PSRangeMatch(R, V));
  PSVersionParse('2.0.0', V); Check('2.0.0 matches (via >=)', PSRangeMatch(R, V));
  PSVersionParse('3.0.0', V); Check('3.0.0 matches (via >=)', PSRangeMatch(R, V));
  PSVersionParse('0.9.0', V); Check('0.9.0 rejects', not PSRangeMatch(R, V));

  Check('single constraint range', PSRangeParse('1.2.3', R));
  CheckEqInt('1 constraint', 1, Length(R));

  Check('empty → any', PSRangeParse('', R));
  CheckEqInt('1 constraint (Any)', 1, Length(R));
end;

// ═══════════════════════════════════════════════════════════════
//  Test 9: Find highest match
// ═══════════════════════════════════════════════════════════════
procedure TestFindHighest;
var
  Avail: array[0..4] of TPSVersion;
  C: TPSConstraint;
  Best: TPSVersion;
begin
  WriteLn('Test 9: Find highest match');

  PSVersionParse('1.0.0', Avail[0]);
  PSVersionParse('1.2.0', Avail[1]);
  PSVersionParse('1.2.5', Avail[2]);
  PSVersionParse('1.3.0', Avail[3]);
  PSVersionParse('2.0.0', Avail[4]);

  PSConstraintParse('^1.2.0', C);
  Check('found match for ^1.2.0', PSFindHighestMatch(C, Avail, Best));
  CheckEqStr('best = 1.3.0', '1.3.0', PSVersionToString(Best));

  PSConstraintParse('~1.2.0', C);
  Check('found match for ~1.2.0', PSFindHighestMatch(C, Avail, Best));
  CheckEqStr('best = 1.2.5', '1.2.5', PSVersionToString(Best));

  PSConstraintParse('>=1.2.4', C);
  Check('found match for >=1.2.4', PSFindHighestMatch(C, Avail, Best));
  CheckEqStr('best = 2.0.0', '2.0.0', PSVersionToString(Best));

  PSConstraintParse('>=3.0.0', C);
  Check('no match for >=3.0.0', not PSFindHighestMatch(C, Avail, Best));
end;

// ═══════════════════════════════════════════════════════════════
//  Main
// ═══════════════════════════════════════════════════════════════
begin
  WriteLn('=================================================');
  WriteLn('  pascak_pkg — Semver Test');
  WriteLn('=================================================');
  WriteLn;

  TestVersionParse;
  TestVersionCompare;
  TestConstraintParse;
  TestCaret;
  TestTilde;
  TestRangeOps;
  TestWildcard;
  TestRangeOr;
  TestFindHighest;

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