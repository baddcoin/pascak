{ ====================================================================
  paszlib.pas — Standalone DEFLATE / Zlib / Gzip implementation
  ====================================================================
  Pure Pascal, zero external dependencies. RFC 1950/1951/1952 compliant.
  Class-based (compatible dengan FPC tanpa advanced-record support).

  Exposes:
    DeflateRaw / InflateRaw   — raw DEFLATE (RFC 1951)
    DeflateZlib / InflateZlib — zlib wrapper (RFC 1950)
    DeflateGzip / InflateGzip — gzip wrapper (RFC 1952)
    Adler32, CRC32            — checksum helpers
  ==================================================================== }
unit paszlib;

{$MODE OBJFPC}{$H+}

interface

uses SysUtils;

type
  EZlibError = class(Exception);

function DeflateRaw (const Data: RawByteString; Level: Integer = 6): RawByteString;
function InflateRaw (const Data: RawByteString): RawByteString;
function DeflateZlib(const Data: RawByteString; Level: Integer = 6): RawByteString;
function InflateZlib(const Data: RawByteString): RawByteString;
function DeflateGzip(const Data: RawByteString; Level: Integer = 6): RawByteString;
function InflateGzip(const Data: RawByteString): RawByteString;
function Adler32    (const Data: RawByteString): Cardinal;
function CRC32      (const Data: RawByteString): Cardinal;

implementation

// ════════════════════════════════════════════════════════════════
//  Constants (RFC 1951)
// ════════════════════════════════════════════════════════════════

const
  WINDOW_SIZE = 32768;
  MIN_MATCH   = 3;
  MAX_MATCH   = 258;
  HASH_BITS   = 15;
  HASH_SIZE   = 1 shl HASH_BITS;
  HASH_MASK   = HASH_SIZE - 1;
  MAX_CHAIN   = 128;
  NICE_LENGTH = 128;

  LENGTH_BASE: array[0..28] of Word = (
    3,4,5,6,7,8,9,10,11,13,15,17,19,23,27,31,
    35,43,51,59,67,83,99,115,131,163,195,227,258);
  LENGTH_EXTRA: array[0..28] of Byte = (
    0,0,0,0,0,0,0,0,1,1,1,1,2,2,2,2,
    3,3,3,3,4,4,4,4,5,5,5,5,0);

  DIST_BASE: array[0..29] of Word = (
    1,2,3,4,5,7,9,13,17,25,33,49,65,97,129,193,
    257,385,513,769,1025,1537,2049,3073,4097,6145,
    8193,12289,16385,24577);
  DIST_EXTRA: array[0..29] of Byte = (
    0,0,0,0,1,1,2,2,3,3,4,4,5,5,6,6,
    7,7,8,8,9,9,10,10,11,11,12,12,13,13);

  CL_ORDER: array[0..18] of Byte = (
    16,17,18,0,8,7,9,6,10,5,11,4,12,3,13,2,14,1,15);

type
  // ────────────────────────────────────────────────────────────────
  //  TBitWriter — LSB-first bit packing
  // ────────────────────────────────────────────────────────────────
  TBitWriter = class
  public
    Buf: RawByteString;
    BitBuf: Cardinal;
    BitCount: Integer;
    constructor Create;
    procedure WriteBit(B: Cardinal);
    procedure WriteBits(Value: Cardinal; Count: Integer);
    procedure WriteCode(Code: Cardinal; Len: Integer);
    procedure FlushByte;
    function  AsBytes: RawByteString;
  end;

  // ────────────────────────────────────────────────────────────────
  //  TBitReader — LSB-first bit unpacking
  // ────────────────────────────────────────────────────────────────
  TBitReader = class
  public
    Data: RawByteString;
    Pos: Integer;
    BitBuf: Cardinal;
    BitCount: Integer;
    constructor Create(const AData: RawByteString);
    function  ReadBit(out B: Cardinal): Boolean;
    function  ReadBits(Count: Integer; out Value: Cardinal): Boolean;
  end;

  // ────────────────────────────────────────────────────────────────
  //  THuffmanDecoder — canonical Huffman decoder
  // ────────────────────────────────────────────────────────────────
  THuffmanDecoder = class
  public
    Count:   array[0..15] of Integer;
    Symbols: array of Integer;
    constructor Create;
    procedure Build(const Lengths: array of Integer; SymbolCount: Integer);
    function  Decode(var BR: TBitReader; out Sym: Integer): Boolean;
  end;

// ════════════════════════════════════════════════════════════════
//  TBitWriter implementation
// ════════════════════════════════════════════════════════════════

constructor TBitWriter.Create;
begin
  inherited Create;
  Buf := ''; BitBuf := 0; BitCount := 0;
end;

procedure TBitWriter.WriteBit(B: Cardinal);
begin
  BitBuf := BitBuf or ((B and 1) shl BitCount);
  Inc(BitCount);
  if BitCount = 8 then
  begin
    Buf := Buf + Char(BitBuf and $FF);
    BitBuf := 0; BitCount := 0;
  end;
end;

procedure TBitWriter.WriteBits(Value: Cardinal; Count: Integer);
var i: Integer;
begin
  for i := 0 to Count - 1 do
    WriteBit((Value shr i) and 1);
end;

procedure TBitWriter.WriteCode(Code: Cardinal; Len: Integer);
var i: Integer;
begin
  for i := Len - 1 downto 0 do
    WriteBit((Code shr i) and 1);
end;

procedure TBitWriter.FlushByte;
begin
  while BitCount > 0 do WriteBit(0);
end;

function TBitWriter.AsBytes: RawByteString;
begin
  FlushByte;
  Result := Buf;
end;

// ════════════════════════════════════════════════════════════════
//  TBitReader implementation
// ════════════════════════════════════════════════════════════════

constructor TBitReader.Create(const AData: RawByteString);
begin
  inherited Create;
  Data := AData; Pos := 1; BitBuf := 0; BitCount := 0;
end;

function TBitReader.ReadBit(out B: Cardinal): Boolean;
begin
  if BitCount = 0 then
  begin
    if Pos > Length(Data) then begin B := 0; Exit(False); end;
    BitBuf := Byte(Data[Pos]);
    Inc(Pos);
    BitCount := 8;
  end;
  B := BitBuf and 1;
  BitBuf := BitBuf shr 1;
  Dec(BitCount);
  Result := True;
end;

function TBitReader.ReadBits(Count: Integer; out Value: Cardinal): Boolean;
var i: Integer; B: Cardinal;
begin
  Value := 0;
  for i := 0 to Count - 1 do
  begin
    if not ReadBit(B) then Exit(False);
    Value := Value or (B shl i);
  end;
  Result := True;
end;

// ════════════════════════════════════════════════════════════════
//  THuffmanDecoder implementation
// ════════════════════════════════════════════════════════════════

constructor THuffmanDecoder.Create;
begin
  inherited Create;
  FillChar(Count, SizeOf(Count), 0);
  SetLength(Symbols, 0);
end;

procedure THuffmanDecoder.Build(const Lengths: array of Integer; SymbolCount: Integer);
var
  i, l: Integer;
  Offsets: array[0..15] of Integer;
begin
  FillChar(Count, SizeOf(Count), 0);
  for i := 0 to SymbolCount - 1 do
  begin
    l := Lengths[i];
    if l > 0 then Inc(Count[l]);
  end;

  Offsets[0] := 0;
  for l := 1 to 15 do
    Offsets[l] := Offsets[l-1] + Count[l-1];

  SetLength(Symbols, SymbolCount);
  for i := 0 to SymbolCount - 1 do
  begin
    l := Lengths[i];
    if l > 0 then
    begin
      Symbols[Offsets[l]] := i;
      Inc(Offsets[l]);
    end;
  end;
  SetLength(Symbols, Offsets[15]);
end;

function THuffmanDecoder.Decode(var BR: TBitReader; out Sym: Integer): Boolean;
var
  code, first, index, len: Integer;
  B: Cardinal;
begin
  code := 0; first := 0; index := 0;
  for len := 1 to 15 do
  begin
    if not BR.ReadBit(B) then begin Sym := -1; Exit(False); end;
    code := (code shl 1) or Integer(B);
    if Count[len] > 0 then
    begin
      if code - first < Count[len] then
      begin
        Sym := Symbols[index + (code - first)];
        Exit(True);
      end;
      Inc(index, Count[len]);
      first := (first + Count[len]) shl 1;
    end else
      first := first shl 1;
  end;
  Sym := -1;
  Result := False;
end;

// ════════════════════════════════════════════════════════════════
//  Fixed Huffman tables (RFC 1951 §3.2.6)
// ════════════════════════════════════════════════════════════════

procedure BuildFixedLitLen(out Codes: array of Cardinal;
                           out Lengths: array of Integer);
var i: Integer;
begin
  for i := 0 to 143 do begin Codes[i] := $30 + Cardinal(i); Lengths[i] := 8; end;
  for i := 144 to 255 do begin Codes[i] := $190 + Cardinal(i-144); Lengths[i] := 9; end;
  for i := 256 to 279 do begin Codes[i] := Cardinal(i-256); Lengths[i] := 7; end;
  for i := 280 to 287 do begin Codes[i] := $C0 + Cardinal(i-280); Lengths[i] := 8; end;
end;

// ════════════════════════════════════════════════════════════════
//  INFLATE — decompress (full: fixed + dynamic + stored)
// ════════════════════════════════════════════════════════════════

function InflateRaw(const Data: RawByteString): RawByteString;
var
  BR: TBitReader;
  LitLen, Dist: THuffmanDecoder;
  OutBuf: RawByteString;
  OutLen: Integer;

  procedure AppendByte(B: Byte); inline;
  begin
    if OutLen >= Length(OutBuf) then
      SetLength(OutBuf, Length(OutBuf) * 2 + 256);
    Inc(OutLen);
    OutBuf[OutLen] := Char(B);
  end;

  function DecodeBlock(Fixed: Boolean): Boolean;
  var
    Sym, DistSym, i, j: Integer;
    MatchLen, ExtraValue: Cardinal;
    CopyDist, SrcIdx: Integer;
    Tmp: Cardinal;
    HLIT, HDIST, HCLEN: Integer;
    CL_Lens: array[0..18] of Integer;
    CL_Dec: THuffmanDecoder;
    LitLens: array[0..287] of Integer;
    DistLens: array[0..31] of Integer;
    NumLit, NumDist, TotalLens: Integer;
    CurLen, RepeatCount: Integer;
    codes: array[0..287] of Cardinal;
  begin
    Result := False;

    if Fixed then
    begin
      BuildFixedLitLen(codes, LitLens);
      LitLen.Build(LitLens, 288);
      for i := 0 to 29 do DistLens[i] := 5;
      Dist.Build(DistLens, 30);
    end else
    begin
      if not BR.ReadBits(5, Tmp) then Exit; HLIT := Integer(Tmp) + 257;
      if not BR.ReadBits(5, Tmp) then Exit; HDIST := Integer(Tmp) + 1;
      if not BR.ReadBits(4, Tmp) then Exit; HCLEN := Integer(Tmp) + 4;

      FillChar(CL_Lens, SizeOf(CL_Lens), 0);
      for i := 0 to HCLEN - 1 do
      begin
        if not BR.ReadBits(3, Tmp) then Exit;
        CL_Lens[CL_ORDER[i]] := Integer(Tmp);
      end;
      CL_Dec := THuffmanDecoder.Create;
      try
        CL_Dec.Build(CL_Lens, 19);

        NumLit := HLIT;
        NumDist := HDIST;
        TotalLens := NumLit + NumDist;
        FillChar(LitLens, SizeOf(LitLens), 0);
        FillChar(DistLens, SizeOf(DistLens), 0);

        i := 0;
        while i < TotalLens do
        begin
          if not CL_Dec.Decode(BR, Sym) then Exit;
          if Sym < 16 then
          begin
            if i < NumLit then LitLens[i] := Sym else DistLens[i - NumLit] := Sym;
            Inc(i);
          end else if Sym = 16 then
          begin
            if i = 0 then Exit;
            if i-1 < NumLit then CurLen := LitLens[i-1] else CurLen := DistLens[i-1-NumLit];
            if not BR.ReadBits(2, Tmp) then Exit;
            RepeatCount := 3 + Integer(Tmp);
            while (RepeatCount > 0) and (i < TotalLens) do
            begin
              if i < NumLit then LitLens[i] := CurLen else DistLens[i-NumLit] := CurLen;
              Inc(i); Dec(RepeatCount);
            end;
          end else if Sym = 17 then
          begin
            if not BR.ReadBits(3, Tmp) then Exit;
            RepeatCount := 3 + Integer(Tmp);
            while (RepeatCount > 0) and (i < TotalLens) do
            begin
              if i < NumLit then LitLens[i] := 0 else DistLens[i-NumLit] := 0;
              Inc(i); Dec(RepeatCount);
            end;
          end else if Sym = 18 then
          begin
            if not BR.ReadBits(7, Tmp) then Exit;
            RepeatCount := 11 + Integer(Tmp);
            while (RepeatCount > 0) and (i < TotalLens) do
            begin
              if i < NumLit then LitLens[i] := 0 else DistLens[i-NumLit] := 0;
              Inc(i); Dec(RepeatCount);
            end;
          end else Exit;
        end;

        LitLen.Build(LitLens, NumLit);
        Dist.Build(DistLens, NumDist);
      finally
        CL_Dec.Free;
      end;
    end;

    while True do
    begin
      if not LitLen.Decode(BR, Sym) then Exit;
      if Sym < 256 then
        AppendByte(Byte(Sym))
      else if Sym = 256 then
        Exit(True)
      else
      begin
        i := Sym - 257;
        if (i < 0) or (i > 28) then Exit;
        if not BR.ReadBits(LENGTH_EXTRA[i], ExtraValue) then Exit;
        MatchLen := Cardinal(LENGTH_BASE[i]) + ExtraValue;

        if not Dist.Decode(BR, DistSym) then Exit;
        if (DistSym < 0) or (DistSym > 29) then Exit;
        if not BR.ReadBits(DIST_EXTRA[DistSym], ExtraValue) then Exit;
        CopyDist := DIST_BASE[DistSym] + Integer(ExtraValue);
        if CopyDist > OutLen then Exit;

        SrcIdx := OutLen - CopyDist + 1;
        for j := 1 to Integer(MatchLen) do
        begin
          AppendByte(Byte(OutBuf[SrcIdx]));
          Inc(SrcIdx);
        end;
      end;
    end;
  end;

var
  BFINAL, BTYPE: Cardinal;
  FinalBlock: Boolean;
  LEN, NLEN, i: Integer;
begin
  OutBuf := '';
  OutLen := 0;

  BR := TBitReader.Create(Data);
  LitLen := THuffmanDecoder.Create;
  Dist := THuffmanDecoder.Create;
  try
    repeat
      if not BR.ReadBit(BFINAL) then
      begin
        // ✅ RFC 7692: Z_SYNC_FLUSH stream TIDAK diakhiri BFINAL=1.
        // Tolerate EOF di block boundary (setelah minimal 1 block selesai).
        if OutLen > 0 then
          Break
        else
          raise EZlibError.Create('inflate: truncated (empty stream)');
      end;
      if not BR.ReadBits(2, BTYPE) then
        raise EZlibError.Create('inflate: truncated (BTYPE)');
      FinalBlock := BFINAL = 1;

      case BTYPE of
        0: begin
          while BR.BitCount > 0 do
            if not BR.ReadBit(BFINAL) then
              raise EZlibError.Create('inflate: truncated (stored pad)');
          if BR.Pos + 3 > Length(BR.Data) then
            raise EZlibError.Create('inflate: truncated (stored LEN)');
          LEN := Byte(BR.Data[BR.Pos]) or (Byte(BR.Data[BR.Pos+1]) shl 8);
          NLEN := Byte(BR.Data[BR.Pos+2]) or (Byte(BR.Data[BR.Pos+3]) shl 8);
          Inc(BR.Pos, 4);
          if (LEN xor $FFFF) <> NLEN then
            raise EZlibError.Create('inflate: LEN/NLEN mismatch');
          if BR.Pos + LEN - 1 > Length(BR.Data) then
            raise EZlibError.Create('inflate: truncated (stored data)');
          for i := 0 to LEN - 1 do
          begin
            AppendByte(Byte(BR.Data[BR.Pos]));
            Inc(BR.Pos);
          end;
        end;
        1: if not DecodeBlock(True) then
             raise EZlibError.Create('inflate: error in fixed block');
        2: if not DecodeBlock(False) then
             raise EZlibError.Create('inflate: error in dynamic block');
        3: raise EZlibError.Create('inflate: invalid block type 3');
      end;
    until FinalBlock;

    SetLength(OutBuf, OutLen);
    Result := OutBuf;
  finally
    BR.Free;
    LitLen.Free;
    Dist.Free;
  end;
end;

// ════════════════════════════════════════════════════════════════
//  DEFLATE — compress (fixed Huffman + LZ77)
// ════════════════════════════════════════════════════════════════

function Hash3(const Data: RawByteString; Pos: Integer): Cardinal; inline;
begin
  Result := (Cardinal(Byte(Data[Pos])) shl 10)
          xor (Cardinal(Byte(Data[Pos+1])) shl 5)
          xor Cardinal(Byte(Data[Pos+2]));
  Result := Result and HASH_MASK;
end;

function EncodeLengthCode(Len: Integer; out Extra, ExtraBits: Cardinal): Integer;
var i: Integer;
begin
  for i := 28 downto 0 do
    if Len >= Integer(LENGTH_BASE[i]) then
    begin
      Result := 257 + i;
      Extra := Cardinal(Len - Integer(LENGTH_BASE[i]));
      ExtraBits := LENGTH_EXTRA[i];
      Exit;
    end;
  Result := 257; Extra := 0; ExtraBits := 0;
end;

function EncodeDistCode(Dist: Integer; out Extra, ExtraBits: Cardinal): Integer;
var i: Integer;
begin
  for i := 29 downto 0 do
    if Dist >= Integer(DIST_BASE[i]) then
    begin
      Result := i;
      Extra := Cardinal(Dist - Integer(DIST_BASE[i]));
      ExtraBits := DIST_EXTRA[i];
      Exit;
    end;
  Result := 0; Extra := 0; ExtraBits := 0;
end;

function DeflateRaw(const Data: RawByteString; Level: Integer): RawByteString;
var
  BW: TBitWriter;
  HashHead: array[0..HASH_SIZE-1] of Integer;
  HashPrev: array[0..WINDOW_SIZE-1] of Integer;
  FixedCodes: array[0..287] of Cardinal;
  FixedLens: array[0..287] of Integer;
  InLen, InPos, ChainLimit: Integer;
  Hash, ChainLen, BestLen, BestDist: Integer;
  i, j, Cand: Integer;
  LenCode, DistCode: Integer;
  Extra, ExtraBits: Cardinal;
begin
  SetLength(Result, 0);
  InLen := Length(Data);

  if Level < 1 then Level := 1;
  if Level > 9 then Level := 9;
  ChainLimit := MAX_CHAIN;

  BuildFixedLitLen(FixedCodes, FixedLens);

  for i := 0 to HASH_SIZE - 1 do HashHead[i] := 0;
  for i := 0 to WINDOW_SIZE - 1 do HashPrev[i] := 0;

  BW := TBitWriter.Create;
  try
    BW.WriteBit(1);       // BFINAL = 1
    BW.WriteBits(1, 2);   // BTYPE = 01 (fixed)

    if InLen = 0 then
    begin
      BW.WriteCode(0, 7);   // symbol 256
      Result := BW.AsBytes;
      Exit;
    end;

    InPos := 1;
    while InPos <= InLen do
    begin
      BestLen := 0;
      BestDist := 0;

      if InPos + MIN_MATCH - 1 <= InLen then
      begin
        Hash := Hash3(Data, InPos);
        Cand := HashHead[Hash];
        ChainLen := ChainLimit;

        while (Cand > 0) and (ChainLen > 0) do
        begin
          if InPos - Cand > WINDOW_SIZE then Break;

          j := 0;
          while (j < MAX_MATCH) and (InPos + j <= InLen) and
                (Data[Cand + j] = Data[InPos + j]) do
            Inc(j);

          if j > BestLen then
          begin
            BestLen := j;
            BestDist := InPos - Cand;
            if j >= NICE_LENGTH then Break;
          end;

          Cand := HashPrev[(Cand - 1) and (WINDOW_SIZE - 1)];
          Dec(ChainLen);
        end;
      end;

      if BestLen >= MIN_MATCH then
      begin
        LenCode := EncodeLengthCode(BestLen, Extra, ExtraBits);
        BW.WriteCode(FixedCodes[LenCode], FixedLens[LenCode]);
        if ExtraBits > 0 then BW.WriteBits(Extra, ExtraBits);

        DistCode := EncodeDistCode(BestDist, Extra, ExtraBits);
        BW.WriteCode(DistCode, 5);
        if ExtraBits > 0 then BW.WriteBits(Extra, ExtraBits);

        for i := 0 to BestLen - 1 do
        begin
          if InPos + i + MIN_MATCH - 1 <= InLen then
          begin
            Hash := Hash3(Data, InPos + i);
            HashPrev[(InPos + i - 1) and (WINDOW_SIZE - 1)] := HashHead[Hash];
            HashHead[Hash] := InPos + i;
          end;
        end;

        Inc(InPos, BestLen);
      end else
      begin
        BW.WriteCode(FixedCodes[Byte(Data[InPos])], FixedLens[Byte(Data[InPos])]);

        if InPos + MIN_MATCH - 1 <= InLen then
        begin
          Hash := Hash3(Data, InPos);
          HashPrev[(InPos - 1) and (WINDOW_SIZE - 1)] := HashHead[Hash];
          HashHead[Hash] := InPos;
        end;

        Inc(InPos);
      end;
    end;

    BW.WriteCode(0, 7);   // end of block
    Result := BW.AsBytes;
  finally
    BW.Free;
  end;
end;

// ════════════════════════════════════════════════════════════════
//  Checksums
// ════════════════════════════════════════════════════════════════

var
  GCRC32Table: array[0..255] of Cardinal;
  GCRC32Built: Boolean = False;

procedure BuildCRC32Table;
var i, j: Integer; C: Cardinal;
begin
  for i := 0 to 255 do
  begin
    C := Cardinal(i);
    for j := 0 to 7 do
      if (C and 1) <> 0 then C := $EDB88320 xor (C shr 1)
      else C := C shr 1;
    GCRC32Table[i] := C;
  end;
  GCRC32Built := True;
end;

function CRC32(const Data: RawByteString): Cardinal;
var i: Integer;
begin
  if not GCRC32Built then BuildCRC32Table;
  Result := $FFFFFFFF;
  for i := 1 to Length(Data) do
    Result := GCRC32Table[(Result xor Byte(Data[i])) and $FF] xor (Result shr 8);
  Result := Result xor $FFFFFFFF;
end;

function Adler32(const Data: RawByteString): Cardinal;
const MOD_ADLER = 65521;
var i: Integer; A, B: Cardinal;
begin
  A := 1; B := 0;
  for i := 1 to Length(Data) do
  begin
    A := (A + Byte(Data[i])) mod MOD_ADLER;
    B := (B + A) mod MOD_ADLER;
  end;
  Result := (B shl 16) or A;
end;

// ════════════════════════════════════════════════════════════════
//  Zlib wrapper (RFC 1950)
// ════════════════════════════════════════════════════════════════

function DeflateZlib(const Data: RawByteString; Level: Integer): RawByteString;
const CMF = $78;
var
  Body: RawByteString;
  AD: Cardinal;
  Len: Integer;
begin
  Body := DeflateRaw(Data, Level);
  AD := Adler32(Data);
  Len := 2 + Length(Body) + 4;
  SetLength(Result, Len);

  Result[1] := Char(CMF);
  Result[2] := Char($9C);

  if Length(Body) > 0 then
    Move(Body[1], Result[3], Length(Body));

  Result[Len-3] := Char((AD shr 24) and $FF);
  Result[Len-2] := Char((AD shr 16) and $FF);
  Result[Len-1] := Char((AD shr 8)  and $FF);
  Result[Len]   := Char(AD and $FF);
end;

function InflateZlib(const Data: RawByteString): RawByteString;
var Body: RawByteString;
begin
  if Length(Data) < 6 then
    raise EZlibError.Create('inflate zlib: stream too short');
  if (Byte(Data[1]) and $0F) <> 8 then
    raise EZlibError.Create('inflate zlib: unsupported compression method');
  Body := Copy(Data, 3, Length(Data) - 6);
  Result := InflateRaw(Body);
end;

// ════════════════════════════════════════════════════════════════
//  Gzip wrapper (RFC 1952)
// ════════════════════════════════════════════════════════════════

function DeflateGzip(const Data: RawByteString; Level: Integer): RawByteString;
var
  Body, Header: RawByteString;
  CRCv, Size: Cardinal;
  P: Integer;
begin
  Body := DeflateRaw(Data, Level);
  CRCv := CRC32(Data);
  Size := Cardinal(Length(Data));

  SetLength(Header, 10);
  Header[1] := #$1F; Header[2] := #$8B;
  Header[3] := #$08; Header[4] := #$00;
  Header[5] := #$00; Header[6] := #$00;
  Header[7] := #$00; Header[8] := #$00;
  Header[9] := #$00; Header[10] := #$FF;

  SetLength(Result, 10 + Length(Body) + 8);
  Move(Header[1], Result[1], 10);
  if Length(Body) > 0 then
    Move(Body[1], Result[11], Length(Body));

  P := 11 + Length(Body);
  Result[P]   := Char(CRCv and $FF);
  Result[P+1] := Char((CRCv shr 8) and $FF);
  Result[P+2] := Char((CRCv shr 16) and $FF);
  Result[P+3] := Char((CRCv shr 24) and $FF);
  Result[P+4] := Char(Size and $FF);
  Result[P+5] := Char((Size shr 8) and $FF);
  Result[P+6] := Char((Size shr 16) and $FF);
  Result[P+7] := Char((Size shr 24) and $FF);
end;

function InflateGzip(const Data: RawByteString): RawByteString;
var FLG: Byte; HeaderSize: Integer; P: Integer;
begin
  if Length(Data) < 18 then
    raise EZlibError.Create('inflate gzip: stream too short');
  if (Byte(Data[1]) <> $1F) or (Byte(Data[2]) <> $8B) then
    raise EZlibError.Create('inflate gzip: bad magic');
  if Byte(Data[3]) <> 8 then
    raise EZlibError.Create('inflate gzip: unsupported compression');

  FLG := Byte(Data[4]);
  if (FLG and $E0) <> 0 then
    raise EZlibError.Create('inflate gzip: reserved FLG bits set');

  HeaderSize := 10;
  if (FLG and $04) <> 0 then
  begin
    if HeaderSize + 2 > Length(Data) then
      raise EZlibError.Create('inflate gzip: truncated FEXTRA');
    P := HeaderSize + 1;
    HeaderSize := HeaderSize + 2 +
      (Byte(Data[P]) or (Byte(Data[P+1]) shl 8));
  end;
  if (FLG and $08) <> 0 then
  begin
    P := HeaderSize + 1;
    while (P <= Length(Data)) and (Data[P] <> #0) do Inc(P);
    HeaderSize := P;
  end;
  if (FLG and $10) <> 0 then
  begin
    P := HeaderSize + 1;
    while (P <= Length(Data)) and (Data[P] <> #0) do Inc(P);
    HeaderSize := P;
  end;
  if (FLG and $02) <> 0 then
    Inc(HeaderSize, 2);

  if HeaderSize + 8 > Length(Data) then
    raise EZlibError.Create('inflate gzip: header extends past stream');

  Result := InflateRaw(Copy(Data, HeaderSize + 1, Length(Data) - HeaderSize - 8));
end;

end.