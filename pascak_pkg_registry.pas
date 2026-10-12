{ ====================================================================
  pascak_pkg_registry.pas — Local folder registry untuk pascak_pkg
  ====================================================================
  Implementasi IPSRegistry:
    - TPSLocalRegistry   → baca dari folder lokal

  HTTP registry diimplementasikan di engine layer (native function)
  karena butuh http.get yang tersedia di program utama.

  Struktur local registry:
    <root>/
      @scope/name/
        1.2.3/
          pascak.json
          <files>
        1.5.0/
          pascak.json
          <files>
      simple-pkg/
        1.0.0/
          pascak.json
  ==================================================================== }
unit pascak_pkg_registry;

{$MODE OBJFPC}{$H+}
{$INTERFACES CORBA}

interface

uses
  SysUtils, Classes, fgl, fpjson, jsonparser,
  pascak_pkg;

type
  EPSRegistryError = class(Exception);

  { ─── Local folder registry ─── }
  TPSLocalRegistry = class(TInterfacedObject, IPSRegistry)
  private
    FRoot: string;                    // folder root registry
    function PackageDir(const Name, Version: string): string;
  public
    constructor Create(const ARoot: string);
    function GetVersions(const Name: string): TPSVersionArray;
    function GetManifest(const Name, Version: string): TPSManifest;
    function GetDownloadURL(const Name, Version: string): string;
    function GetIntegrity(const Name, Version: string): string;
  end;

  { ─── Install helpers ─── }
  
  // Recursively copy folder Src → Dst (create Dst if needed).
  // Skip: .git, *.pbc (bytecode cache).
  function PSCopyTree(const Src, Dst: string): Boolean;
  
  // Install dependencies from RegistryRoot into ProjectDir/packages/.
  // Prereq: ProjectDir/pascak.json exists (valid manifest).
  // Writes: ProjectDir/pascak.lock
  // Fills: InstalledList with "name@version" strings (caller owns list).
  // Returns True on success.
  function PSInstallProject(const RegistryRoot, ProjectDir: string;
    out InstalledList: TStringList;
    out Err: string): Boolean;
  
  // List installed packages from ProjectDir/pascak.lock.
  // Fills: List with "name@version" strings (caller owns list).
  // Returns True on success (lockfile exists + parsed).
  function PSListInstalled(const ProjectDir: string;
    out List: TStringList;
    out Err: string): Boolean;
                         
implementation

uses
  pascak_crypto;

const
  MANIFEST_FILE = 'pascak.json';

function JoinPath(const A, B: string): string;
begin
  if A = '' then Exit(B);
  if B = '' then Exit(A);
  if A[Length(A)] = PathDelim then
    Result := A + B
  else
    Result := A + PathDelim + B;
end;

{ ═══════════════════════════════════════════════════════════════
  TPSLocalRegistry
  ═══════════════════════════════════════════════════════════════ }

constructor TPSLocalRegistry.Create(const ARoot: string);
begin
  inherited Create;
  FRoot := ExcludeTrailingPathDelimiter(ARoot);
end;

function TPSLocalRegistry.PackageDir(const Name, Version: string): string;
begin
  Result := JoinPath(FRoot, Name);
  Result := JoinPath(Result, Version);
end;

function TPSLocalRegistry.GetVersions(const Name: string): TPSVersionArray;
var
  PkgDir: string;
  SR: TSearchRec;
  V: TPSVersion;
  Count: Integer;
begin
  SetLength(Result, 0);
  PkgDir := JoinPath(FRoot, Name);

  if not DirectoryExists(PkgDir) then Exit;

  Count := 0;
  if FindFirst(JoinPath(PkgDir, '*'), faDirectory, SR) = 0 then
  begin
    try
      repeat
        if (SR.Name = '.') or (SR.Name = '..') then Continue;
        if (SR.Attr and faDirectory) = 0 then Continue;
        if PSVersionParse(SR.Name, V) then
        begin
          SetLength(Result, Count + 1);
          Result[Count] := V;
          Inc(Count);
        end;
      until FindNext(SR) <> 0;
    finally
      FindClose(SR);
    end;
  end;

  if Count > 1 then
    PSSortVersionsAsc(Result);
end;

function TPSLocalRegistry.GetManifest(const Name, Version: string): TPSManifest;
var
  ManifestPath: string;
  M: TPSManifest;
begin
  Result := nil;
  ManifestPath := JoinPath(PackageDir(Name, Version), MANIFEST_FILE);

  if not FileExists(ManifestPath) then Exit;

  M := TPSManifest.Create;
  if not PSManifestLoad(ManifestPath, M) then
  begin
    M.Free;
    Exit;
  end;

  // Override name/version dengan yang di-request (consistency)
  M.Name := Name;
  M.Version := Version;

  Result := M;
end;

function TPSLocalRegistry.GetDownloadURL(const Name, Version: string): string;
begin
  Result := 'file://' + PackageDir(Name, Version);
end;

function TPSLocalRegistry.GetIntegrity(const Name, Version: string): string;
var
  ManifestPath: string;
  F: TFileStream;
  Bytes: RawByteString;
  Hash: RawByteString;
begin
  // Hash manifest file sebagai integrity check sederhana.
  // v2: hash seluruh folder (Merkle tree).
  ManifestPath := JoinPath(PackageDir(Name, Version), MANIFEST_FILE);
  if not FileExists(ManifestPath) then
  begin
    Result := '';
    Exit;
  end;

  try
    F := TFileStream.Create(ManifestPath, fmOpenRead or fmShareDenyNone);
    try
      SetLength(Bytes, F.Size);
      if F.Size > 0 then
        F.ReadBuffer(Bytes[1], F.Size);
    finally
      F.Free;
    end;
    Hash := SHA256Bytes(Bytes);
    Result := 'sha256-' + BytesToHex(Hash);
  except
    Result := '';
  end;
end;

{ ═══════════════════════════════════════════════════════════════
  Install helpers
  ═══════════════════════════════════════════════════════════════ }

function CopyFileSimple(const Src, Dst: string): Boolean;
var
  SrcF, DstF: TFileStream;
begin
  Result := False;
  try
    SrcF := TFileStream.Create(Src, fmOpenRead or fmShareDenyNone);
    try
      DstF := TFileStream.Create(Dst, fmCreate);
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

function IsSkipFile(const Name: string): Boolean;
var
  Len: Integer;
begin
  Result := False;
  if Name = '.git' then Exit(True);
  Len := Length(Name);
  if (Len > 4) and (Copy(Name, Len - 3, 4) = '.pbc') then Exit(True);
end;

// Recursively delete folder
function PSDelTree(const Dir: string): Boolean;
var
  SR: TSearchRec;
  FullPath: string;
begin
  Result := True;
  if not DirectoryExists(Dir) then Exit;

  if FindFirst(IncludeTrailingPathDelimiter(Dir) + '*', faAnyFile, SR) = 0 then
  begin
    try
      repeat
        if (SR.Name = '.') or (SR.Name = '..') then Continue;
        FullPath := IncludeTrailingPathDelimiter(Dir) + SR.Name;
        if (SR.Attr and faDirectory) <> 0 then
          PSDelTree(FullPath)
        else
          try DeleteFile(FullPath); except end;
      until FindNext(SR) <> 0;
    finally
      FindClose(SR);
    end;
  end;
  try RemoveDir(Dir); except Result := False; end;
end;

function PSCopyTree(const Src, Dst: string): Boolean;
var
  SR: TSearchRec;
  FullSrc, FullDst: string;
begin
  Result := False;
  if not DirectoryExists(Src) then Exit;
  if not ForceDirectories(Dst) then Exit;

  if FindFirst(IncludeTrailingPathDelimiter(Src) + '*', faAnyFile, SR) = 0 then
  begin
    try
      repeat
        if (SR.Name = '.') or (SR.Name = '..') then Continue;
        if IsSkipFile(SR.Name) then Continue;

        FullSrc := IncludeTrailingPathDelimiter(Src) + SR.Name;
        FullDst := IncludeTrailingPathDelimiter(Dst) + SR.Name;

        if (SR.Attr and faDirectory) <> 0 then
        begin
          if not PSCopyTree(FullSrc, FullDst) then Exit;
        end
        else
        begin
          if not CopyFileSimple(FullSrc, FullDst) then Exit;
        end;
      until FindNext(SR) <> 0;
    finally
      FindClose(SR);
    end;
  end;
  Result := True;
end;

function PSInstallProject(const RegistryRoot, ProjectDir: string;
  out InstalledList: TStringList;
  out Err: string): Boolean;
var
  ManifestPath, LockPath, PackagesDir: string;
  M: TPSManifest;
  Reg: TPSLocalRegistry;
  Resolver: TPSResolver;
  L: TPSLockfile;
  I: Integer;
  R: TPSResolved;
  SrcDir, DstDir: string;
  Scope, Name: string;
begin
  Result := False;
  Err := '';
  InstalledList.Clear;

  if not DirectoryExists(ProjectDir) then
  begin
    Err := 'install: project dir tidak ada: ' + ProjectDir;
    Exit;
  end;

  if not DirectoryExists(RegistryRoot) then
  begin
    Err := 'install: registry dir tidak ada: ' + RegistryRoot;
    Exit;
  end;

  ManifestPath := IncludeTrailingPathDelimiter(ProjectDir) + 'pascak.json';
  if not FileExists(ManifestPath) then
  begin
    Err := 'install: pascak.json tidak ditemukan di ' + ProjectDir;
    Exit;
  end;

  // Load manifest
  M := TPSManifest.Create;
  try
    if not PSManifestLoad(ManifestPath, M) then
    begin
      Err := 'install: gagal parse pascak.json';
      Exit;
    end;

    if not PSManifestValidate(M, Err) then
    begin
      Err := 'install: manifest tidak valid: ' + Err;
      Exit;
    end;

    // Resolve
    Reg := TPSLocalRegistry.Create(RegistryRoot);
    try
      Resolver := TPSResolver.Create(Reg);
      L := TPSLockfile.Create;
      try
        if not Resolver.Resolve(M, L, Err) then
        begin
          Err := 'install: resolve gagal: ' + Err;
          Exit;
        end;

        // Write lockfile
        LockPath := IncludeTrailingPathDelimiter(ProjectDir) + 'pascak.lock';
        if not PSLockfileSave(L, LockPath) then
        begin
          Err := 'install: gagal write pascak.lock';
          Exit;
        end;

        // Copy packages
        PackagesDir := IncludeTrailingPathDelimiter(ProjectDir) + 'packages';
        if not ForceDirectories(PackagesDir) then
        begin
          Err := 'install: gagal buat packages/';
          Exit;
        end;

        for I := 0 to L.Resolved.Count - 1 do
        begin
          R := L.Resolved[I];

          PSParsePackageName(R.Name, Scope, Name);
          if Scope <> '' then
            DstDir := IncludeTrailingPathDelimiter(PackagesDir) + '@' +
                      Scope + PathDelim + Name
          else
            DstDir := IncludeTrailingPathDelimiter(PackagesDir) + Name;

          SrcDir := IncludeTrailingPathDelimiter(RegistryRoot) + R.Name +
                    PathDelim + R.Version;

          if not DirectoryExists(SrcDir) then
          begin
            Err := 'install: source package tidak ada: ' + SrcDir;
            Exit;
          end;
          
          // ✅ Wipe target dulu supaya replace, bukan append/new
          if DirectoryExists(DstDir) then
          begin
            if not PSDelTree(DstDir) then
            begin
              Err := 'install: gagal hapus target lama: ' + DstDir;
              Exit;
            end;
          end;
          
          if not PSCopyTree(SrcDir, DstDir) then
          begin
            Err := 'install: copy gagal: ' + SrcDir + ' → ' + DstDir;
            Exit;
          end;
          
          InstalledList.Add(R.Name + '@' + R.Version);
        end;

        Result := True;
      finally
        L.Free;
        Resolver.Free;
      end;
    finally
      Reg.Free;
    end;
  finally
    M.Free;
  end;
end;

function PSListInstalled(const ProjectDir: string;
  out List: TStringList;
  out Err: string): Boolean;
var
  LockPath: string;
  L: TPSLockfile;
  I: Integer;
begin
  Result := False;
  Err := '';
  List.Clear;

  LockPath := IncludeTrailingPathDelimiter(ProjectDir) + 'pascak.lock';
  if not FileExists(LockPath) then
  begin
    Err := 'list: pascak.lock tidak ditemukan';
    Exit;
  end;

  L := TPSLockfile.Create;
  try
    if not PSLockfileLoad(LockPath, L) then
    begin
      Err := 'list: gagal parse pascak.lock';
      Exit;
    end;

    for I := 0 to L.Resolved.Count - 1 do
      List.Add(L.Resolved[I].Name + '@' + L.Resolved[I].Version);

    Result := True;
  finally
    L.Free;
  end;
end;

initialization
finalization

end.