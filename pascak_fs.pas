{ ====================================================================
  pascak_fs.pas — Filesystem advanced operations
  ====================================================================
  Pure Pascal, cross-platform (POSIX + Windows).
  Sandbox handled oleh caller (VM wrapper), bukan unit ini.
  ==================================================================== }
unit pascak_fs;

{$MODE OBJFPC}{$H+}

interface

uses
  Classes, SysUtils, StrUtils
  {$IFDEF UNIX}, BaseUnix{$ENDIF}
  {$IFDEF WINDOWS}, Windows{$ENDIF};
  
type
  EFSException = class(Exception);

  TFSInfo = record
    Size: Int64;
    MTime: Int64;       // Unix timestamp (seconds since 1970)
    IsDir: Boolean;
    IsFile: Boolean;
    Permissions: Integer;   // 0..0777 (Unix style). Windows: 0755 untuk readonly=false
  end;

// ─── Glob pattern matching ───
// Pattern: '*' (any except '/'), '?' (single except '/'),
//          '**' (any including '/')
// Return list of matching paths (relative to base dir).
function FSGlob(const BaseDir, Pattern: string;
                out Results: TStringList): Boolean;

// ─── Recursive directory walk ───
// MaxDepth = 0 → unlimited.
// Return semua entry (file + dir), path relative ke Root.
function FSWalkDir(const Root: string; MaxDepth: Integer;
                   out Results: TStringList): Boolean;

// ─── Stat ───
function FSStat(const Path: string; out Info: TFSInfo): Boolean;

// ─── Copy (file atau dir) ───
function FSCopy(const Src, Dst: string; Recursive: Boolean): Boolean;

// ─── Move / rename ───
function FSMove(const Src, Dst: string): Boolean;

// ─── Remove (file atau dir) ───
function FSRemove(const Path: string; Recursive: Boolean): Boolean;

// ─── Chmod (Unix) / Readonly toggle (Windows) ───
function FSChmod(const Path: string; Mode: Integer): Boolean;

// ─── Temp file ───
// Return absolute path ke file yang baru dibuat (empty).
function FSTempFile(const BaseDir, Prefix: string; out Path: string): Boolean;

implementation
var
  GTempCounter: LongInt = 0; 

function GetFileSizeByName(const FileName: string): Int64;
var
  FS: TFileStream;
begin
  Result := -1;

  if not FileExists(FileName) then
    Exit;

  try
    FS :=
      TFileStream.Create(
        FileName,
        fmOpenRead or fmShareDenyNone);

    try
      Result := FS.Size;
    finally
      FS.Free;
    end;

  except
    on E: Exception do
      Result := -1;
  end;
end;

// ════════════════════════════════════════════════════════════════
//  Pattern matching
// ════════════════════════════════════════════════════════════════
function MatchSegment(const Pat, Text: string): Boolean;
var
  Pi, Ti, StarP, StarT: Integer;
begin
  Pi := 1; Ti := 1;
  StarP := 0; StarT := 0;
  
  while Ti <= Length(Text) do
  begin
    if (Pi <= Length(Pat)) and ((Pat[Pi] = '?') or (Pat[Pi] = Text[Ti])) then
    begin
      Inc(Pi); Inc(Ti);
    end
    else if (Pi <= Length(Pat)) and (Pat[Pi] = '*') then
    begin
      StarP := Pi;
      StarT := Ti;
      Inc(Pi);
    end
    else if StarP > 0 then
    begin
      Pi := StarP + 1;
      Inc(StarT);
      Ti := StarT;
    end
    else
      Exit(False);
  end;
  
  while (Pi <= Length(Pat)) and (Pat[Pi] = '*') do Inc(Pi);
  Result := Pi > Length(Pat);
end;

// Match path pattern termasuk '**'
function MatchPath(const Pat, Text: string): Boolean;
var
  PatSegs, TxtSegs: TStringArray;

  function SegmentMatches(PatSeg, TxtSeg: string): Boolean;
  begin
    Result := MatchSegment(PatSeg, TxtSeg);
  end;
  
  function RecMatch(pi, ti: Integer): Boolean;
  var
    p: Integer;
  begin
    // Base: semua pattern habis
    if pi > High(PatSegs) then
      Exit(ti > High(TxtSegs));
    
    // Kalau pattern '**', bisa match 0..N segment
    if PatSegs[pi] = '**' then
    begin
      // Coba match sisa pattern dengan 0,1,2,... segment text
      for p := ti to Length(TxtSegs) do
        if RecMatch(pi + 1, p) then Exit(True);
      Exit(False);
    end;
    
    // Segment biasa
    if ti > High(TxtSegs) then Exit(False);
    if not SegmentMatches(PatSegs[pi], TxtSegs[ti]) then Exit(False);
    Result := RecMatch(pi + 1, ti + 1);
  end;
  
begin
  PatSegs := Pat.Split(['/']);
  TxtSegs := Text.Split(['/']);
  // Handle empty pattern segments
  SetLength(PatSegs, Length(PatSegs));
  SetLength(TxtSegs, Length(TxtSegs));
  Result := RecMatch(0, 0);
end;

// ════════════════════════════════════════════════════════════════
//  FSGlob
// ════════════════════════════════════════════════════════════════
procedure GlobCollect(const BaseDir, RelPrefix, RemPattern: string;
  Results: TStringList);
var
  SR: TSearchRec;
  FullPath, RelPath, PatFirst, PatRest: string;
  SlashPos: Integer;
begin
  if RemPattern = '' then Exit;

  // Split first segment
  SlashPos := Pos('/', RemPattern);
  if SlashPos > 0 then
  begin
    PatFirst := Copy(RemPattern, 1, SlashPos - 1);
    PatRest  := Copy(RemPattern, SlashPos + 1, Length(RemPattern));
  end
  else
  begin
    PatFirst := RemPattern;
    PatRest  := '';
  end;

  // ─── Case A: PatFirst = '**' ───
  if PatFirst = '**' then
  begin
    if PatRest = '' then
    begin
      // '**' as last segment — match ALL entries recursively
      if FindFirst(IncludeTrailingPathDelimiter(BaseDir) + '*',
                    faAnyFile, SR) = 0 then
      begin
        try
          repeat
            if (SR.Name = '.') or (SR.Name = '..') then Continue;
            RelPath := RelPrefix + SR.Name;
            FullPath := IncludeTrailingPathDelimiter(BaseDir) + SR.Name;
            Results.Add(RelPath);
            if (SR.Attr and faDirectory) <> 0 then
              GlobCollect(FullPath, RelPath + '/', '**', Results);
          until FindNext(SR) <> 0;
        finally
          FindClose(SR);
        end;
      end;
    end
    else
    begin
      // '**/rest' — try rest at current level, then recurse into subdirs with same pattern
      GlobCollect(BaseDir, RelPrefix, PatRest, Results);

      if FindFirst(IncludeTrailingPathDelimiter(BaseDir) + '*',
                    faAnyFile, SR) = 0 then
      begin
        try
          repeat
            if (SR.Name = '.') or (SR.Name = '..') then Continue;
            if (SR.Attr and faDirectory) = 0 then Continue;
            FullPath := IncludeTrailingPathDelimiter(BaseDir) + SR.Name;
            RelPath  := RelPrefix + SR.Name + '/';
            GlobCollect(FullPath, RelPath, RemPattern, Results);
          until FindNext(SR) <> 0;
        finally
          FindClose(SR);
        end;
      end;
    end;
    Exit;
  end;

  // ─── Case B: normal segment ───
  if FindFirst(IncludeTrailingPathDelimiter(BaseDir) + '*', faAnyFile, SR) = 0 then
  begin
    try
      repeat
        if (SR.Name = '.') or (SR.Name = '..') then Continue;
        if not MatchSegment(PatFirst, SR.Name) then Continue;

        RelPath  := RelPrefix + SR.Name;
        FullPath := IncludeTrailingPathDelimiter(BaseDir) + SR.Name;

        if PatRest = '' then
          Results.Add(RelPath)
        else if (SR.Attr and faDirectory) <> 0 then
          GlobCollect(FullPath, RelPath + '/', PatRest, Results);
      until FindNext(SR) <> 0;
    finally
      FindClose(SR);
    end;
  end;
end;

function FSGlob(const BaseDir, Pattern: string;
                out Results: TStringList): Boolean;
begin
  Results.Clear;
  Result := True;
  try
    if not DirectoryExists(BaseDir) then
    begin
      Result := False;
      Exit;
    end;
    GlobCollect(ExcludeTrailingPathDelimiter(BaseDir), '', Pattern, Results);
  except
    Result := False;
  end;
end;

// ════════════════════════════════════════════════════════════════
//  FSWalkDir
// ════════════════════════════════════════════════════════════════
procedure WalkRecursive(const Root, RelPrefix: string;
                        MaxDepth, CurDepth: Integer;
                        Results: TStringList);
var
  SR: TSearchRec;
  FullPath, RelPath: string;
begin
  if (MaxDepth > 0) and (CurDepth >= MaxDepth) then Exit;
  
  if FindFirst(IncludeTrailingPathDelimiter(Root) + '*', faAnyFile, SR) = 0 then
  begin
    try
      repeat
        if (SR.Name = '.') or (SR.Name = '..') then Continue;
        
        RelPath := RelPrefix + SR.Name;
        FullPath := IncludeTrailingPathDelimiter(Root) + SR.Name;
        
        Results.Add(RelPath);
        
        if (SR.Attr and faDirectory) <> 0 then
          WalkRecursive(FullPath, RelPath + '/', MaxDepth, CurDepth + 1, Results);
      until FindNext(SR) <> 0;
    finally
      FindClose(SR);
    end;
  end;
end;

function FSWalkDir(const Root: string; MaxDepth: Integer;
                   out Results: TStringList): Boolean;
begin
  Results.Clear;
  Result := True;
  try
    if not DirectoryExists(Root) then
    begin
      Result := False;
      Exit;
    end;
    WalkRecursive(ExcludeTrailingPathDelimiter(Root), '', MaxDepth, 0, Results);
  except
    Result := False;
  end;
end;

// ════════════════════════════════════════════════════════════════
//  FSStat
// ════════════════════════════════════════════════════════════════
function FSStat(const Path: string; out Info: TFSInfo): Boolean;
var
  SR: TSearchRec;
  Attr: Integer; var St: Stat;
begin
  Result := False;
  FillChar(Info, SizeOf(Info), 0);
  
  if not (FileExists(Path) or DirectoryExists(Path)) then Exit;
  
  Info.IsDir := DirectoryExists(Path);
  Info.IsFile := FileExists(Path) and not Info.IsDir;
  
  // Size (hanya untuk file)
  if Info.IsFile then
  begin
    try
      Info.Size := GetFileSizeByName(Path);
    except
      Info.Size := 0;
    end;
  end;
  
  // mtime — pakai FindFirst untuk cross-platform
  if FindFirst(Path, faAnyFile, SR) = 0 then
  begin
    try
      Info.MTime := SR.Time;
      Attr := SR.Attr;
    finally
      FindClose(SR);
    end;
  end
  else
  begin
    Info.MTime := 0;
    Attr := 0;
  end;
  
  {$IFDEF UNIX}
  // Unix permission bits
  if fpStat(PChar(Path), St) = 0 then
    Info.Permissions := St.st_mode and $1FF  // 0..0777
  else
    Info.Permissions := 0;
  {$ELSE}
  // Windows: konversi readonly flag ke Unix-style
  if (Attr and faReadOnly) <> 0 then
    Info.Permissions := $124  // 0444
  else if Info.IsDir then
    Info.Permissions := $1ED  // 0755
  else
    Info.Permissions := $1B6; // 0666
  {$ENDIF}
  
  Result := True;
end;

// ════════════════════════════════════════════════════════════════
//  FSCopy
// ════════════════════════════════════════════════════════════════
function CopyFileSimple(const Src, Dst: string): Boolean;
var
  SrcF, DstF: TFileStream;
begin
  Result := False;
  try
    SrcF := TFileStream.Create(Src, fmOpenRead or fmShareDenyNone);
    try
      DstF := TFileStream.Create(Dst, fmCreate or fmShareDenyWrite);
      try
        DstF.CopyFrom(SrcF, 0);
        Result := True;
      finally
        DstF.Free;
      end;
    finally
      SrcF.Free;
    end;
  except
    Result := False;
  end;
end;

function FSCopy(const Src, Dst: string; Recursive: Boolean): Boolean;
var
  SR: TSearchRec;
  SrcPath, DstPath, AbsDst: string;
begin
  Result := False;

  // ✅ FIX: cek DirectoryExists DULU sebelum FileExists.
  // Di Termux/Android, FileExists kadang return true untuk directory.
  // Kalau kita cek FileExists dulu, direktori akan masuk branch file copy
  // dan gagal karena TFileStream tidak bisa open directory.
  if DirectoryExists(Src) then
  begin
    if not Recursive then Exit;

    AbsDst := ExpandFileName(Dst);
    try
      if not DirectoryExists(AbsDst) then
        if not ForceDirectories(AbsDst) then Exit;

      if FindFirst(IncludeTrailingPathDelimiter(Src) + '*', faAnyFile, SR) = 0 then
      begin
        try
          repeat
            if (SR.Name = '.') or (SR.Name = '..') then Continue;
            SrcPath := IncludeTrailingPathDelimiter(Src) + SR.Name;
            DstPath := IncludeTrailingPathDelimiter(AbsDst) + SR.Name;

            if (SR.Attr and faDirectory) <> 0 then
              FSCopy(SrcPath, DstPath, True)
            else
              CopyFileSimple(SrcPath, DstPath);
          until FindNext(SR) <> 0;
        finally
          FindClose(SR);
        end;
      end;

      Result := DirectoryExists(AbsDst);
    except
      Result := False;
    end;
    Exit;
  end;

  // Kalau bukan dir, baru cek file
  if FileExists(Src) then
    Result := CopyFileSimple(Src, Dst);
end;

// ════════════════════════════════════════════════════════════════
//  FSMove
// ════════════════════════════════════════════════════════════════
function FSMove(const Src, Dst: string): Boolean;
begin
  Result := False;
  try
    Result := RenameFile(Src, Dst);
  except
    Result := False;
  end;
end;

// ════════════════════════════════════════════════════════════════
//  FSChmod
// ════════════════════════════════════════════════════════════════
function FSChmod(const Path: string; Mode: Integer): Boolean;
begin
  Result := False;
  {$IFDEF UNIX}
  try
    Result := fpChmod(PChar(Path), Mode) = 0;
  except
    Result := False;
  end;
  {$ELSE}
  // Windows: readonly bit only
  try
    if (Mode and $80) = 0 then
      FileSetAttr(Path, FileGetAttr(Path) or faReadOnly)
    else
      FileSetAttr(Path, FileGetAttr(Path) and not faReadOnly);
    Result := True;
  except
    Result := False;
  end;
  {$ENDIF}
end;

procedure RemoveDirRecursive(const Dir: string);
var
  SR: TSearchRec;
  FullPath: string;
  Retries: Integer;
begin
  // Hapus isi dulu
  if FindFirst(IncludeTrailingPathDelimiter(Dir) + '*', faAnyFile, SR) = 0 then
  begin
    try
      repeat
        if (SR.Name = '.') or (SR.Name = '..') then Continue;
        FullPath := IncludeTrailingPathDelimiter(Dir) + SR.Name;

        if (SR.Attr and faDirectory) <> 0 then
          RemoveDirRecursive(FullPath)
        else
        begin
          // ✅ Retry delete — Termux kadang file masih locked
          Retries := 3;
          while (Retries > 0) and FileExists(FullPath) do
          begin
            if not DeleteFile(FullPath) then
              Sleep(20);
            Dec(Retries);
          end;
        end;
      until FindNext(SR) <> 0;
    finally
      FindClose(SR);
    end;
  end;

  // Hapus directory sendiri (retry juga)
  Retries := 3;
  while (Retries > 0) and DirectoryExists(Dir) do
  begin
    if not RemoveDir(Dir) then
      Sleep(20);
    Dec(Retries);
  end;
end;

function FSRemove(const Path: string; Recursive: Boolean): Boolean;
begin
  Result := False;
  try
    if FileExists(Path) then
      Result := DeleteFile(Path)
    else if DirectoryExists(Path) then
    begin
      if Recursive then
      begin
        RemoveDirRecursive(Path);
        Result := not DirectoryExists(Path);
      end
      else
        Result := RemoveDir(Path);
    end;
  except
    Result := False;
  end;
end;

// ════════════════════════════════════════════════════════════════
//  FSTempFile
// ════════════════════════════════════════════════════════════════
function FSTempFile(const BaseDir, Prefix: string; out Path: string): Boolean;
const
  TMP_SUBDIR = '.pascak_tmp';
var
  SafePrefix, Candidate, TmpRoot, FullCandidate, UniqPart: string;
  Attempts: Integer;
  F: TFileStream;
begin
  Result := False;
  Path := '';

  if BaseDir = '' then Exit;

  // ✅ BaseDir = sandbox root (script dir)
  TmpRoot := IncludeTrailingPathDelimiter(BaseDir) + TMP_SUBDIR;

  if not DirectoryExists(TmpRoot) then
  begin
    try
      if not ForceDirectories(TmpRoot) then Exit;
    except
      Exit;
    end;
  end;

  if Prefix = '' then SafePrefix := 'pascak_'
  else SafePrefix := Prefix;

  for Attempts := 1 to 100 do
  begin
    UniqPart := IntToHex(GetTickCount64, 8) + '_' +
                IntToHex(Cardinal(InterlockedIncrement(GTempCounter)), 8);
    Candidate := SafePrefix + UniqPart + '.tmp';

    // ✅ Return path RELATIF terhadap BaseDir
    Path := TMP_SUBDIR + '/' + Candidate;
    FullCandidate := IncludeTrailingPathDelimiter(TmpRoot) + Candidate;

    try
      F := TFileStream.Create(FullCandidate, fmCreate or fmShareExclusive);
      try
        Result := True;
        Exit;
      finally
        F.Free;
      end;
    except
      // coba lagi
    end;
  end;
end;

initialization
finalization

end.