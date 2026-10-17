{ ====================================================================
  pascak_h2_hpack.pas — HPACK decoder (RFC 7541)
  Scope v1: decoder only (encoder in Step 1.3c)
  Depends: pascak_h2_huffman
  ==================================================================== }
unit pascak_h2_hpack;

{$MODE OBJFPC}{$H+}

interface

uses
  SysUtils,
  pascak_h2_huffman;

type
  EH2HPACKError = class(Exception);

  THPACKHeader = record
    Name: string;
    Value: string;
  end;
  THPACKHeaderArray = array of THPACKHeader;

  THPACKDecoder = class
  private
    FDynamic: THPACKHeaderArray;
    FDynamicSize: Integer;
    FMaxSize: Integer;
  public
    constructor Create(AMaxSize: Integer = 4096);
    destructor Destroy; override;
    function Decode(const Block: RawByteString): THPACKHeaderArray;
    procedure Reset;
    property MaxSize: Integer read FMaxSize write FMaxSize;
    property CurrentSize: Integer read FDynamicSize;
  end;

function H2HPACKDecodeInteger(const Data: RawByteString;
  var Offset: Integer; PrefixBits: Byte; out Value: Cardinal): Boolean;

function H2HPACKDecodeString(const Data: RawByteString;
  var Offset: Integer; out Str: RawByteString): Boolean;

function H2HPACKStaticName(Index: Integer): string;
function H2HPACKStaticValue(Index: Integer): string;

implementation

const
  STATIC_TABLE_SIZE = 61;

  { RFC 7541 Appendix A — Static Table (61 entries) }
  STATIC_NAMES: array[1..STATIC_TABLE_SIZE] of string = (
    ':authority',
    ':method', ':method',
    ':path', ':path',
    ':scheme', ':scheme',
    ':status', ':status', ':status', ':status',
    ':status', ':status', ':status',
    'accept-charset', 'accept-encoding', 'accept-language',
    'accept-ranges', 'accept', 'access-control-allow-origin',
    'age', 'allow', 'authorization', 'cache-control',
    'content-disposition', 'content-encoding', 'content-language',
    'content-length', 'content-location', 'content-range',
    'content-type', 'cookie', 'date', 'etag', 'expect',
    'expires', 'from', 'host', 'if-match', 'if-modified-since',
    'if-none-match', 'if-range', 'if-unmodified-since',
    'last-modified', 'link', 'location', 'max-forwards',
    'proxy-authenticate', 'proxy-authorization', 'range',
    'referer', 'refresh', 'retry-after', 'server', 'set-cookie',
    'strict-transport-security', 'transfer-encoding', 'user-agent',
    'vary', 'via', 'www-authenticate'
  );

  STATIC_VALUES: array[1..STATIC_TABLE_SIZE] of string = (
    '',
    'GET', 'POST',
    '/', '/index.html',
    'http', 'https',
    '200', '204', '206', '304', '400', '404', '500',
    '', 'gzip, deflate', '',
    '', '', '',
    '', '', '', '',
    '', '', '',
    '', '', '',
    '', '', '', '', '',
    '', '', '', '', '',
    '', '', '',
    '', '', '', '',
    '', '', '',
    '', '', '', '', '',
    '', '', '',
    '', '', ''
  );

function H2HPACKStaticName(Index: Integer): string;
begin
  if (Index < 1) or (Index > STATIC_TABLE_SIZE) then
    raise EH2HPACKError.CreateFmt('Static table index out of range: %d', [Index]);
  Result := STATIC_NAMES[Index];
end;

function H2HPACKStaticValue(Index: Integer): string;
begin
  if (Index < 1) or (Index > STATIC_TABLE_SIZE) then
    raise EH2HPACKError.CreateFmt('Static table index out of range: %d', [Index]);
  Result := STATIC_VALUES[Index];
end;

{ RFC 7541 §5.1 — Variable-length integer with N-bit prefix }
function H2HPACKDecodeInteger(const Data: RawByteString;
  var Offset: Integer; PrefixBits: Byte; out Value: Cardinal): Boolean;
var
  B, Mask: Byte;
  Shift: Integer;
begin
  Result := False;
  Value := 0;
  if (Offset < 1) or (Offset > Length(Data)) then Exit;
  if (PrefixBits < 1) or (PrefixBits > 8) then Exit;

  Mask := (1 shl PrefixBits) - 1;
  if PrefixBits = 8 then Mask := $FF;

  B := Byte(Data[Offset]);
  Inc(Offset);
  Value := B and Mask;

  if Value < Mask then Exit(True);

  Shift := 0;
  while True do
  begin
    if Offset > Length(Data) then Exit;
    B := Byte(Data[Offset]);
    Inc(Offset);
    if Shift > 28 then
      raise EH2HPACKError.Create('HPACK: integer too long');
    Value := Value + (Cardinal(B and $7F) shl Shift);
    Inc(Shift, 7);
    if (B and $80) = 0 then Break;
  end;

  Result := True;
end;

{ RFC 7541 §5.2 — Length-prefixed string, optional Huffman }
function H2HPACKDecodeString(const Data: RawByteString;
  var Offset: Integer; out Str: RawByteString): Boolean;
var
  Len: Cardinal;
  IsHuff: Boolean;
  RawBytes: RawByteString;
begin
  Result := False;
  Str := '';
  if (Offset < 1) or (Offset > Length(Data)) then Exit;
  IsHuff := (Byte(Data[Offset]) and $80) <> 0;
  if not H2HPACKDecodeInteger(Data, Offset, 7, Len) then Exit;
  if Offset + Integer(Len) - 1 > Length(Data) then Exit;
  SetLength(RawBytes, Len);
  if Len > 0 then Move(Data[Offset], RawBytes[1], Len);
  Inc(Offset, Len);
  if IsHuff then
  begin
    try
      Str := H2HuffmanDecode(RawBytes);
    except
      on E: Exception do
        raise EH2HPACKError.Create('HPACK: Huffman decode failed');
    end;
  end
  else
    Str := RawBytes;
  Result := True;
end;

{ --- Part B (dynamic table + field decoder + class) follows --- }

{ ═══════════════════════════════════════════════════════════════
  Dynamic table (RFC 7541 §2.3)
  ═══════════════════════════════════════════════════════════════ }

function EntrySize(const H: THPACKHeader): Integer;
begin
  Result := Length(H.Name) + Length(H.Value) + 32;
end;

function RBToStr(const RB: RawByteString): string;
begin
  SetLength(Result, Length(RB));
  if Length(RB) > 0 then Move(RB[1], Result[1], Length(RB));
end;

function HPACKLookup(Decoder: THPACKDecoder;
  Index: Cardinal; out Name, Value: string): Boolean;
begin
  Result := False;
  Name := '';
  Value := '';
  if Index = 0 then Exit;
  if Index <= Cardinal(STATIC_TABLE_SIZE) then
  begin
    Name := STATIC_NAMES[Integer(Index)];
    Value := STATIC_VALUES[Integer(Index)];
    Exit(True);
  end;
  { Dynamic: index 62 = most recent (FDynamic[0]) }
  if (Index >= 62) and (Integer(Index) - 62 < Length(Decoder.FDynamic)) then
  begin
    Name := Decoder.FDynamic[Integer(Index) - 62].Name;
    Value := Decoder.FDynamic[Integer(Index) - 62].Value;
    Exit(True);
  end;
end;

procedure HPACKEvict(Decoder: THPACKDecoder);
var
  Sz: Integer;
begin
  while (Decoder.FDynamicSize > Decoder.FMaxSize) and
        (Length(Decoder.FDynamic) > 0) do
  begin
    Sz := EntrySize(Decoder.FDynamic[High(Decoder.FDynamic)]);
    SetLength(Decoder.FDynamic, Length(Decoder.FDynamic) - 1);
    Dec(Decoder.FDynamicSize, Sz);
  end;
end;

procedure HPACKAdd(Decoder: THPACKDecoder; const Name, Value: string);
var
  H: THPACKHeader;
  i: Integer;
  NewArr: THPACKHeaderArray;
begin
  H.Name := Name;
  H.Value := Value;
  if EntrySize(H) > Decoder.FMaxSize then
  begin
    { Entry too big — RFC 7541 §4.4: empty the table }
    SetLength(Decoder.FDynamic, 0);
    Decoder.FDynamicSize := 0;
    Exit;
  end;
  SetLength(NewArr, Length(Decoder.FDynamic) + 1);
  NewArr[0] := H;
  for i := 0 to High(Decoder.FDynamic) do
    NewArr[i + 1] := Decoder.FDynamic[i];
  Decoder.FDynamic := NewArr;
  Inc(Decoder.FDynamicSize, EntrySize(H));
  HPACKEvict(Decoder);
end;

{ ═══════════════════════════════════════════════════════════════
  THPACKDecoder
  ═══════════════════════════════════════════════════════════════ }

constructor THPACKDecoder.Create(AMaxSize: Integer);
begin
  inherited Create;
  FMaxSize := AMaxSize;
  SetLength(FDynamic, 0);
  FDynamicSize := 0;
end;

destructor THPACKDecoder.Destroy;
begin
  SetLength(FDynamic, 0);
  inherited;
end;

procedure THPACKDecoder.Reset;
begin
  SetLength(FDynamic, 0);
  FDynamicSize := 0;
  FMaxSize := 4096;
end;

function THPACKDecoder.Decode(const Block: RawByteString): THPACKHeaderArray;
var
  Offset: Integer;
  B: Byte;
  Idx: Cardinal;
  Name, Value: string;
  RBName, RBValue: RawByteString;
  H: THPACKHeader;
  Count: Integer;
begin
  Result := nil;
  SetLength(Result, 0);
  Count := 0;
  Offset := 1;

  while Offset <= Length(Block) do
  begin
    B := Byte(Block[Offset]);

    { Pattern 1: Indexed Header Field — 1xxxxxxx }
    if (B and $80) <> 0 then
    begin
      if not H2HPACKDecodeInteger(Block, Offset, 7, Idx) then
        raise EH2HPACKError.Create('HPACK: incomplete Indexed');
      if not HPACKLookup(Self, Idx, Name, Value) then
        raise EH2HPACKError.CreateFmt('HPACK: lookup failed idx=%d', [Idx]);
      H.Name := Name;
      H.Value := Value;
      SetLength(Result, Count + 1);
      Result[Count] := H;
      Inc(Count);
    end

    { Pattern 2: Literal with Incremental Indexing — 01xxxxxx }
    else if (B and $C0) = $40 then
    begin
      if not H2HPACKDecodeInteger(Block, Offset, 6, Idx) then
        raise EH2HPACKError.Create('HPACK: incomplete Literal Incr');
      if Idx = 0 then
      begin
        if not H2HPACKDecodeString(Block, Offset, RBName) then
          raise EH2HPACKError.Create('HPACK: name decode failed');
        Name := RBToStr(RBName);
      end
      else
      begin
        if not HPACKLookup(Self, Idx, Name, Value) then
          raise EH2HPACKError.CreateFmt('HPACK: name lookup failed idx=%d', [Idx]);
      end;
      if not H2HPACKDecodeString(Block, Offset, RBValue) then
        raise EH2HPACKError.Create('HPACK: value decode failed');
      Value := RBToStr(RBValue);
      H.Name := Name;
      H.Value := Value;
      SetLength(Result, Count + 1);
      Result[Count] := H;
      Inc(Count);
      HPACKAdd(Self, Name, Value);
    end

    { Pattern 3: Dynamic Table Size Update — 001xxxxx }
    else if (B and $E0) = $20 then
    begin
      if not H2HPACKDecodeInteger(Block, Offset, 5, Idx) then
        raise EH2HPACKError.Create('HPACK: incomplete Size Update');
      if Idx > 65536 then
        raise EH2HPACKError.Create('HPACK: table size exceeds 65536');
      FMaxSize := Integer(Idx);
      HPACKEvict(Self);
    end

    { Pattern 4: Literal Never Indexed — 0001xxxx }
    else if (B and $F0) = $10 then
    begin
      if not H2HPACKDecodeInteger(Block, Offset, 4, Idx) then
        raise EH2HPACKError.Create('HPACK: incomplete Literal Never');
      if Idx = 0 then
      begin
        if not H2HPACKDecodeString(Block, Offset, RBName) then
          raise EH2HPACKError.Create('HPACK: name decode failed');
        Name := RBToStr(RBName);
      end
      else
      begin
        if not HPACKLookup(Self, Idx, Name, Value) then
          raise EH2HPACKError.CreateFmt('HPACK: name lookup failed idx=%d', [Idx]);
      end;
      if not H2HPACKDecodeString(Block, Offset, RBValue) then
        raise EH2HPACKError.Create('HPACK: value decode failed');
      Value := RBToStr(RBValue);
      H.Name := Name;
      H.Value := Value;
      SetLength(Result, Count + 1);
      Result[Count] := H;
      Inc(Count);
    end

    { Pattern 5: Literal without Indexing — 0000xxxx }
    else if (B and $F0) = $00 then
    begin
      if not H2HPACKDecodeInteger(Block, Offset, 4, Idx) then
        raise EH2HPACKError.Create('HPACK: incomplete Literal NoIdx');
      if Idx = 0 then
      begin
        if not H2HPACKDecodeString(Block, Offset, RBName) then
          raise EH2HPACKError.Create('HPACK: name decode failed');
        Name := RBToStr(RBName);
      end
      else
      begin
        if not HPACKLookup(Self, Idx, Name, Value) then
          raise EH2HPACKError.CreateFmt('HPACK: name lookup failed idx=%d', [Idx]);
      end;
      if not H2HPACKDecodeString(Block, Offset, RBValue) then
        raise EH2HPACKError.Create('HPACK: value decode failed');
      Value := RBToStr(RBValue);
      H.Name := Name;
      H.Value := Value;
      SetLength(Result, Count + 1);
      Result[Count] := H;
      Inc(Count);
    end

    else
      raise EH2HPACKError.CreateFmt('HPACK: invalid byte $%.2x', [B]);
  end;
end;

initialization
end.
