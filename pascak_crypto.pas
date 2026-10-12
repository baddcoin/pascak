{ ====================================================================
  pascak_crypto.pas — Kriptografi untuk VM Pascak
  ====================================================================
  Pure Pascal implementation. No external dependencies.
  
  Exposes:
    - SHA-256
    - HMAC-SHA256
    - Secure random bytes (OS-specific: /dev/urandom or BCryptGenRandom)
    - Constant-time comparison (timing attack mitigation)
  ==================================================================== }
unit pascak_crypto;

{$MODE OBJFPC}{$H+}

interface

uses
  Classes, SysUtils, SyncObjs
  {$IFDEF WINDOWS}, Windows{$ENDIF}
  {$IFDEF UNIX}, BaseUnix{$ENDIF};

type
  ECryptoError = class(Exception);
  TAESMode = (amECB, amCBC);
// ════════════════════════════════════════════════════════════════
//  SHA-256
// ════════════════════════════════════════════════════════════════

// Hash raw bytes → 32-byte digest (raw)
function SHA256Bytes(const Data: RawByteString): RawByteString;

// Hash string → hex digest (64 lowercase hex chars)
function SHA256Hex(const Data: RawByteString): string;

// ════════════════════════════════════════════════════════════════
//  HMAC-SHA256
// ════════════════════════════════════════════════════════════════

function HMACSHA256Bytes(const Key, Msg: RawByteString): RawByteString;
function HMACSHA256Hex(const Key, Msg: RawByteString): string;

// ════════════════════════════════════════════════════════════════
//  Secure Random
// ════════════════════════════════════════════════════════════════

// Cryptographically secure random bytes (dari /dev/urandom atau OS RNG)
function SecureRandomBytes(Count: Integer): RawByteString;

// Secure random hex string (Count bytes → 2*Count hex chars)
function SecureRandomHex(Count: Integer): string;

// ════════════════════════════════════════════════════════════════
//  Utility
// ════════════════════════════════════════════════════════════════

// Constant-time byte comparison (mitigasi timing attack).
// Return True jika semua byte sama.
function ConstantTimeEqual(const A, B: RawByteString): Boolean;

// Hex encode/decode helpers
function BytesToHex(const Data: RawByteString): string;
function HexToBytes(const Hex: string): RawByteString;
function AESEncrypt(const Plaintext, Key: RawByteString;
  const IV: RawByteString = '';
  Mode: TAESMode = amCBC): RawByteString;
function AESDecrypt(const Ciphertext, Key: RawByteString;
  const IV: RawByteString = '';
  Mode: TAESMode = amCBC): RawByteString;

// ════════════════════════════════════════════════════════════════
//  PBKDF2-HMAC-SHA256 (RFC 2898)
// ════════════════════════════════════════════════════════════════
//  Iterations minimum 1000 untuk production (10.000+ recommended)
function PBKDF2_SHA256(const Password, Salt: RawByteString;
    Iterations, KeyLen: Integer): RawByteString;

//  SHA-1 (RFC 3174) — legacy, pakai SHA-256 untuk new code
function SHA1Bytes(const Data: RawByteString): RawByteString;
function SHA1Hex(const Data: RawByteString): string;

//  Base64 (RFC 4648)
function Base64Encode(const Data: RawByteString): string;
function Base64Decode(const S: string): RawByteString;

implementation

// ════════════════════════════════════════════════════════════════
//  SHA-256 Core Implementation
// ════════════════════════════════════════════════════════════════

type
  TSHA256Ctx = record
    State: array[0..7] of Cardinal;
    Buffer: array[0..63] of Byte;
    BufLen: Integer;
    TotalLen: QWord;
  end;
  TAESContext = record
    RoundKey: array[0..59] of Cardinal;   // max 60 words (AES-256)
    Nr: Integer;                         // 10, 12, 14
  end;
  
const
  K256: array[0..63] of Cardinal = (
    $428A2F98, $71374491, $B5C0FBCF, $E9B5DBA5,
    $3956C25B, $59F111F1, $923F82A4, $AB1C5ED5,
    $D807AA98, $12835B01, $243185BE, $550C7DC3,
    $72BE5D74, $80DEB1FE, $9BDC06A7, $C19BF174,
    $E49B69C1, $EFBE4786, $0FC19DC6, $240CA1CC,
    $2DE92C6F, $4A7484AA, $5CB0A9DC, $76F988DA,
    $983E5152, $A831C66D, $B00327C8, $BF597FC7,
    $C6E00BF3, $D5A79147, $06CA6351, $14292967,
    $27B70A85, $2E1B2138, $4D2C6DFC, $53380D13,
    $650A7354, $766A0ABB, $81C2C92E, $92722C85,
    $A2BFE8A1, $A81A664B, $C24B8B70, $C76C51A3,
    $D192E819, $D6990624, $F40E3585, $106AA070,
    $19A4C116, $1E376C08, $2748774C, $34B0BCB5,
    $391C0CB3, $4ED8AA4A, $5B9CCA4F, $682E6FF3,
    $748F82EE, $78A5636F, $84C87814, $8CC70208,
    $90BEFFFA, $A4506CEB, $BEF9A3F7, $C67178F2
  );

  AES_SBox: array[0..255] of Byte = (
    $63,$7C,$77,$7B,$F2,$6B,$6F,$C5,$30,$01,$67,$2B,$FE,$D7,$AB,$76,
    $CA,$82,$C9,$7D,$FA,$59,$47,$F0,$AD,$D4,$A2,$AF,$9C,$A4,$72,$C0,
    $B7,$FD,$93,$26,$36,$3F,$F7,$CC,$34,$A5,$E5,$F1,$71,$D8,$31,$15,
    $04,$C7,$23,$C3,$18,$96,$05,$9A,$07,$12,$80,$E2,$EB,$27,$B2,$75,
    $09,$83,$2C,$1A,$1B,$6E,$5A,$A0,$52,$3B,$D6,$B3,$29,$E3,$2F,$84,
    $53,$D1,$00,$ED,$20,$FC,$B1,$5B,$6A,$CB,$BE,$39,$4A,$4C,$58,$CF,
    $D0,$EF,$AA,$FB,$43,$4D,$33,$85,$45,$F9,$02,$7F,$50,$3C,$9F,$A8,
    $51,$A3,$40,$8F,$92,$9D,$38,$F5,$BC,$B6,$DA,$21,$10,$FF,$F3,$D2,
    $CD,$0C,$13,$EC,$5F,$97,$44,$17,$C4,$A7,$7E,$3D,$64,$5D,$19,$73,
    $60,$81,$4F,$DC,$22,$2A,$90,$88,$46,$EE,$B8,$14,$DE,$5E,$0B,$DB,
    $E0,$32,$3A,$0A,$49,$06,$24,$5C,$C2,$D3,$AC,$62,$91,$95,$E4,$79,
    $E7,$C8,$37,$6D,$8D,$D5,$4E,$A9,$6C,$56,$F4,$EA,$65,$7A,$AE,$08,
    $BA,$78,$25,$2E,$1C,$A6,$B4,$C6,$E8,$DD,$74,$1F,$4B,$BD,$8B,$8A,
    $70,$3E,$B5,$66,$48,$03,$F6,$0E,$61,$35,$57,$B9,$86,$C1,$1D,$9E,
    $E1,$F8,$98,$11,$69,$D9,$8E,$94,$9B,$1E,$87,$E9,$CE,$55,$28,$DF,
    $8C,$A1,$89,$0D,$BF,$E6,$42,$68,$41,$99,$2D,$0F,$B0,$54,$BB,$16
  );

  AES_InvSBox: array[0..255] of Byte = (
    $52,$09,$6A,$D5,$30,$36,$A5,$38,$BF,$40,$A3,$9E,$81,$F3,$D7,$FB,
    $7C,$E3,$39,$82,$9B,$2F,$FF,$87,$34,$8E,$43,$44,$C4,$DE,$E9,$CB,
    $54,$7B,$94,$32,$A6,$C2,$23,$3D,$EE,$4C,$95,$0B,$42,$FA,$C3,$4E,
    $08,$2E,$A1,$66,$28,$D9,$24,$B2,$76,$5B,$A2,$49,$6D,$8B,$D1,$25,
    $72,$F8,$F6,$64,$86,$68,$98,$16,$D4,$A4,$5C,$CC,$5D,$65,$B6,$92,
    $6C,$70,$48,$50,$FD,$ED,$B9,$DA,$5E,$15,$46,$57,$A7,$8D,$9D,$84,
    $90,$D8,$AB,$00,$8C,$BC,$D3,$0A,$F7,$E4,$58,$05,$B8,$B3,$45,$06,
    $D0,$2C,$1E,$8F,$CA,$3F,$0F,$02,$C1,$AF,$BD,$03,$01,$13,$8A,$6B,
    $3A,$91,$11,$41,$4F,$67,$DC,$EA,$97,$F2,$CF,$CE,$F0,$B4,$E6,$73,
    $96,$AC,$74,$22,$E7,$AD,$35,$85,$E2,$F9,$37,$E8,$1C,$75,$DF,$6E,
    $47,$F1,$1A,$71,$1D,$29,$C5,$89,$6F,$B7,$62,$0E,$AA,$18,$BE,$1B,
    $FC,$56,$3E,$4B,$C6,$D2,$79,$20,$9A,$DB,$C0,$FE,$78,$CD,$5A,$F4,
    $1F,$DD,$A8,$33,$88,$07,$C7,$31,$B1,$12,$10,$59,$27,$80,$EC,$5F,
    $60,$51,$7F,$A9,$19,$B5,$4A,$0D,$2D,$E5,$7A,$9F,$93,$C9,$9C,$EF,
    $A0,$E0,$3B,$4D,$AE,$2A,$F5,$B0,$C8,$EB,$BB,$3C,$83,$53,$99,$61,
    $17,$2B,$04,$7E,$BA,$77,$D6,$26,$E1,$69,$14,$63,$55,$21,$0C,$7D
  );

  AES_Rcon: array[0..14] of Byte = (
    $01,$02,$04,$08,$10,$20,$40,$80,$1B,$36,$6C,$D8,$AB,$4D,$9A
  );
  
  
function ROTR(X: Cardinal; N: Integer): Cardinal; inline;
begin
  Result := (X shr N) or (X shl (32 - N));
end;

procedure SHA256_Init(var Ctx: TSHA256Ctx);
begin
  Ctx.State[0] := $6A09E667;
  Ctx.State[1] := $BB67AE85;
  Ctx.State[2] := $3C6EF372;
  Ctx.State[3] := $A54FF53A;
  Ctx.State[4] := $510E527F;
  Ctx.State[5] := $9B05688C;
  Ctx.State[6] := $1F83D9AB;
  Ctx.State[7] := $5BE0CD19;
  Ctx.BufLen := 0;
  Ctx.TotalLen := 0;
end;

procedure SHA256_Transform(var Ctx: TSHA256Ctx);
var
  W: array[0..63] of Cardinal;
  A, B, C, D, E, F, G, H, T1, T2, S0, S1, Ch, Maj: Cardinal;
  i: Integer;
begin
  for i := 0 to 15 do
    W[i] := (Cardinal(Ctx.Buffer[i*4])     shl 24)
         or (Cardinal(Ctx.Buffer[i*4 + 1]) shl 16)
         or (Cardinal(Ctx.Buffer[i*4 + 2]) shl 8)
         or  Cardinal(Ctx.Buffer[i*4 + 3]);
  
  for i := 16 to 63 do
  begin
    S0 := ROTR(W[i-15], 7) xor ROTR(W[i-15], 18) xor (W[i-15] shr 3);
    S1 := ROTR(W[i-2], 17) xor ROTR(W[i-2], 19) xor (W[i-2] shr 10);
    W[i] := W[i-16] + S0 + W[i-7] + S1;
  end;
  
  A := Ctx.State[0]; B := Ctx.State[1]; C := Ctx.State[2]; D := Ctx.State[3];
  E := Ctx.State[4]; F := Ctx.State[5]; G := Ctx.State[6]; H := Ctx.State[7];
  
  for i := 0 to 63 do
  begin
    S1 := ROTR(E, 6) xor ROTR(E, 11) xor ROTR(E, 25);
    Ch := (E and F) xor ((not E) and G);
    T1 := H + S1 + Ch + K256[i] + W[i];
    S0 := ROTR(A, 2) xor ROTR(A, 13) xor ROTR(A, 22);
    Maj := (A and B) xor (A and C) xor (B and C);
    T2 := S0 + Maj;
    
    H := G; G := F; F := E; E := D + T1;
    D := C; C := B; B := A; A := T1 + T2;
  end;
  
  Ctx.State[0] := Ctx.State[0] + A;
  Ctx.State[1] := Ctx.State[1] + B;
  Ctx.State[2] := Ctx.State[2] + C;
  Ctx.State[3] := Ctx.State[3] + D;
  Ctx.State[4] := Ctx.State[4] + E;
  Ctx.State[5] := Ctx.State[5] + F;
  Ctx.State[6] := Ctx.State[6] + G;
  Ctx.State[7] := Ctx.State[7] + H;
end;

procedure SHA256_Update(var Ctx: TSHA256Ctx; Data: PByte; Len: Integer);
var
  i: Integer;
  Fill, Take: Integer;
begin
  Inc(Ctx.TotalLen, QWord(Len));
  
  i := 0;
  while i < Len do
  begin
    Fill := 64 - Ctx.BufLen;
    Take := Len - i;
    if Take > Fill then Take := Fill;
    
    Move(Data[i], Ctx.Buffer[Ctx.BufLen], Take);
    Inc(Ctx.BufLen, Take);
    Inc(i, Take);
    
    if Ctx.BufLen = 64 then
    begin
      SHA256_Transform(Ctx);
      Ctx.BufLen := 0;
    end;
  end;
end;

procedure SHA256_Final(var Ctx: TSHA256Ctx; out Digest: array of Byte);
var
  Pad: array[0..71] of Byte;
  PadLen, i: Integer;
  BitLen: QWord;
begin
  // Padding: 0x80, zeros, then 8-byte big-endian bit length
  FillChar(Pad, SizeOf(Pad), 0);
  Pad[0] := $80;
  
  PadLen := 56 - (Ctx.BufLen mod 64);
  if PadLen <= 0 then PadLen := PadLen + 64;
  
  BitLen := Ctx.TotalLen * 8;
  
  SHA256_Update(Ctx, @Pad[0], PadLen);
  
  // Encode BitLen as big-endian 8 bytes
  Pad[0] := Byte((BitLen shr 56) and $FF);
  Pad[1] := Byte((BitLen shr 48) and $FF);
  Pad[2] := Byte((BitLen shr 40) and $FF);
  Pad[3] := Byte((BitLen shr 32) and $FF);
  Pad[4] := Byte((BitLen shr 24) and $FF);
  Pad[5] := Byte((BitLen shr 16) and $FF);
  Pad[6] := Byte((BitLen shr  8) and $FF);
  Pad[7] := Byte((BitLen       ) and $FF);
  SHA256_Update(Ctx, @Pad[0], 8);
  
  // Output as big-endian
  for i := 0 to 7 do
  begin
    Digest[i*4]     := Byte((Ctx.State[i] shr 24) and $FF);
    Digest[i*4 + 1] := Byte((Ctx.State[i] shr 16) and $FF);
    Digest[i*4 + 2] := Byte((Ctx.State[i] shr  8) and $FF);
    Digest[i*4 + 3] := Byte((Ctx.State[i]      ) and $FF);
  end;
end;

// ════════════════════════════════════════════════════════════════
//  SHA-256 Public API
// ════════════════════════════════════════════════════════════════

function SHA256Bytes(const Data: RawByteString): RawByteString;
var
  Ctx: TSHA256Ctx;
  Digest: array[0..31] of Byte;
begin
  SHA256_Init(Ctx);
  if Length(Data) > 0 then
    SHA256_Update(Ctx, @Data[1], Length(Data));
  SHA256_Final(Ctx, Digest);
  SetLength(Result, 32);
  Move(Digest[0], Result[1], 32);
end;

function SHA256Hex(const Data: RawByteString): string;
var
  Raw: RawByteString;
begin
  Raw := SHA256Bytes(Data);
  Result := BytesToHex(Raw);
end;

// ════════════════════════════════════════════════════════════════
//  HMAC-SHA256
// ════════════════════════════════════════════════════════════════

function HMACSHA256Bytes(const Key, Msg: RawByteString): RawByteString;
const
  BLOCK_SIZE = 64;
var
  K: RawByteString;
  IPad, OPad: RawByteString;
  InnerHash, OuterHash: RawByteString;
  i, KeyLen, PadFrom: Integer;
begin
  KeyLen := Length(Key);
  
  // If key > block size, hash it to 32 bytes
  if KeyLen > BLOCK_SIZE then
  begin
    K := SHA256Bytes(Key);
    PadFrom := Length(K);   // 32
  end
  else
  begin
    K := Key;
    PadFrom := KeyLen;
  end;
  
  // ✅ FIX: ALWAYS pad K to exactly BLOCK_SIZE
  // Pakai SetLength + explicit FillChar untuk menghilangkan ambiguitas
  // zero-init RTL (terutama pada kondisi realloc in-place).
  SetLength(K, BLOCK_SIZE);
  if PadFrom < BLOCK_SIZE then
    FillChar(K[PadFrom + 1], BLOCK_SIZE - PadFrom, 0);
  
  // Build ipad and opad
  SetLength(IPad, BLOCK_SIZE);
  SetLength(OPad, BLOCK_SIZE);
  for i := 1 to BLOCK_SIZE do
  begin
    IPad[i] := Char(Byte(K[i]) xor $36);
    OPad[i] := Char(Byte(K[i]) xor $5C);
  end;
  
  InnerHash := SHA256Bytes(IPad + Msg);
  OuterHash := SHA256Bytes(OPad + InnerHash);
  
  Result := OuterHash;
end;

function HMACSHA256Hex(const Key, Msg: RawByteString): string;
begin
  Result := BytesToHex(HMACSHA256Bytes(Key, Msg));
end;

// ════════════════════════════════════════════════════════════════
//  Secure Random
// ════════════════════════════════════════════════════════════════

{$IFDEF UNIX}
function ReadDevURandom(Count: Integer): RawByteString;
var
  F: TFileStream;
begin
  F := TFileStream.Create('/dev/urandom', fmOpenRead or fmShareDenyNone);
  try
    SetLength(Result, Count);
    if Count > 0 then
      F.ReadBuffer(Result[1], Count);
  finally
    F.Free;
  end;
end;
{$ENDIF}

function SecureRandomBytes(Count: Integer): RawByteString;
{$IFDEF UNIX}
begin
  if Count <= 0 then Exit('');
  Result := ReadDevURandom(Count);
end;
{$ENDIF}
{$IFDEF WINDOWS}
var
  HProv: THandle;
  i: Integer;
begin
  if Count <= 0 then Exit('');
  SetLength(Result, Count);
  if CryptAcquireContext(@HProv, nil, nil, PROV_RSA_FULL, CRYPT_VERIFYCONTEXT) then
  begin
    try
      CryptGenRandom(HProv, Count, @Result[1]);
    finally
      CryptReleaseContext(HProv, 0);
    end;
  end
  else
    raise ECryptoError.Create('Gagal acquire crypto context');
end;
{$ENDIF}

function SecureRandomHex(Count: Integer): string;
begin
  Result := BytesToHex(SecureRandomBytes(Count));
end;

// ════════════════════════════════════════════════════════════════
//  Utility
// ════════════════════════════════════════════════════════════════

function ConstantTimeEqual(const A, B: RawByteString): Boolean;
var
  i: Integer;
  Diff: Byte;
begin
  if Length(A) <> Length(B) then
  begin
    // Tetap loop untuk constant-time (walaupun bisa langsung return False)
    Diff := 1;
    for i := 1 to Length(B) do
      Diff := Diff or Byte(A[1]) xor Byte(B[i]);   // dummy work
    Exit(False);
  end;
  
  Diff := 0;
  for i := 1 to Length(A) do
    Diff := Diff or (Byte(A[i]) xor Byte(B[i]));
  
  Result := (Diff = 0);
end;

function BytesToHex(const Data: RawByteString): string;
const
  HexChars: array[0..15] of Char = '0123456789abcdef';
var
  i: Integer;
begin
  SetLength(Result, Length(Data) * 2);
  for i := 1 to Length(Data) do
  begin
    Result[(i-1)*2 + 1] := HexChars[Byte(Data[i]) shr 4];
    Result[(i-1)*2 + 2] := HexChars[Byte(Data[i]) and $0F];
  end;
end;

function HexToBytes(const Hex: string): RawByteString;
var
  i, Len: Integer;
  Hi, Lo: Byte;
  
  function HexNibble(C: Char): Byte;
  begin
    case C of
      '0'..'9': Result := Ord(C) - Ord('0');
      'a'..'f': Result := Ord(C) - Ord('a') + 10;
      'A'..'F': Result := Ord(C) - Ord('A') + 10;
    else
      Result := 0;
    end;
  end;
  
begin
  Len := Length(Hex) div 2;
  SetLength(Result, Len);
  for i := 0 to Len - 1 do
  begin
    Hi := HexNibble(Hex[i*2 + 1]);
    Lo := HexNibble(Hex[i*2 + 2]);
    Result[i + 1] := Char((Hi shl 4) or Lo);
  end;
end;

// Byte access helpers
function AES_SubWord(W: Cardinal): Cardinal; inline;
var
  B0, B1, B2, B3: Byte;
begin
  B0 := AES_SBox[ W         and $FF];
  B1 := AES_SBox[(W shr  8) and $FF];
  B2 := AES_SBox[(W shr 16) and $FF];
  B3 := AES_SBox[(W shr 24) and $FF];
  Result := Cardinal(B0) or (Cardinal(B1) shl 8)
         or (Cardinal(B2) shl 16) or (Cardinal(B3) shl 24);
end;

function AES_RotWord(W: Cardinal): Cardinal; inline;
begin
  Result := (W shr 8) or (W shl 24);
end;

procedure AES_KeyExpansion(var Ctx: TAESContext;
                           Key: PByte; KeyLen: Integer);
var
  Nk, i: Integer;
  Temp: Cardinal;
  W: array[0..59] of Cardinal;
begin
  Nk := KeyLen div 4;   // 4, 6, 8
  Ctx.Nr := Nk + 6;     // 10, 12, 14

  // Copy key (little-endian words)
  for i := 0 to Nk - 1 do
    W[i] := Cardinal(Key[i*4])
         or (Cardinal(Key[i*4 + 1]) shl 8)
         or (Cardinal(Key[i*4 + 2]) shl 16)
         or (Cardinal(Key[i*4 + 3]) shl 24);

  for i := Nk to 4 * (Ctx.Nr + 1) - 1 do
  begin
    Temp := W[i - 1];
    if (i mod Nk) = 0 then
    begin
      Temp := AES_SubWord(AES_RotWord(Temp)) xor Cardinal(AES_Rcon[i div Nk - 1]);
    end
    else if (Nk > 6) and ((i mod Nk) = 4) then
      Temp := AES_SubWord(Temp);
    W[i] := W[i - Nk] xor Temp;
  end;

  for i := 0 to 4 * (Ctx.Nr + 1) - 1 do
    Ctx.RoundKey[i] := W[i];
end;

procedure AES_AddRoundKey(var State: array of Byte;
                          var Ctx: TAESContext; Round: Integer); inline;
var
  i, j: Integer;
  W: Cardinal;
begin
  for i := 0 to 3 do
  begin
    W := Ctx.RoundKey[Round * 4 + i];
    for j := 0 to 3 do
      State[i * 4 + j] := State[i * 4 + j] xor Byte((W shr (j * 8)) and $FF);
  end;
end;

procedure AES_SubBytes(var State: array of Byte); inline;
var i: Integer;
begin
  for i := 0 to 15 do
    State[i] := AES_SBox[State[i]];
end;

procedure AES_InvSubBytes(var State: array of Byte); inline;
var i: Integer;
begin
  for i := 0 to 15 do
    State[i] := AES_InvSBox[State[i]];
end;

procedure AES_ShiftRows(var State: array of Byte); inline;
var T: Byte;
begin
  // Row 1: shift left 1
  T := State[1]; State[1] := State[5]; State[5] := State[9]; State[9] := State[13]; State[13] := T;
  // Row 2: shift left 2
  T := State[2]; State[2] := State[10]; State[10] := T;
  T := State[6]; State[6] := State[14]; State[14] := T;
  // Row 3: shift left 3 (= right 1)
  T := State[15]; State[15] := State[11]; State[11] := State[7]; State[7] := State[3]; State[3] := T;
end;

procedure AES_InvShiftRows(var State: array of Byte); inline;
var T: Byte;
begin
  T := State[13]; State[13] := State[9]; State[9] := State[5]; State[5] := State[1]; State[1] := T;
  T := State[2]; State[2] := State[10]; State[10] := T;
  T := State[6]; State[6] := State[14]; State[14] := T;
  T := State[3]; State[3] := State[7]; State[7] := State[11]; State[11] := State[15]; State[15] := T;
end;

function AES_GMul(A, B: Byte): Byte; inline;
var
  P: Byte;
  i: Integer;
begin
  P := 0;
  for i := 0 to 7 do
  begin
    if (B and 1) <> 0 then P := P xor A;
    if (A and $80) <> 0 then A := (A shl 1) xor $1B
    else A := A shl 1;
    B := B shr 1;
  end;
  Result := P;
end;

procedure AES_MixColumns(var State: array of Byte); inline;
var i: Integer;
    a0, a1, a2, a3: Byte;
begin
  for i := 0 to 3 do
  begin
    a0 := State[i * 4];
    a1 := State[i * 4 + 1];
    a2 := State[i * 4 + 2];
    a3 := State[i * 4 + 3];
    State[i * 4]     := AES_GMul(a0, 2) xor AES_GMul(a1, 3) xor a2 xor a3;
    State[i * 4 + 1] := a0 xor AES_GMul(a1, 2) xor AES_GMul(a2, 3) xor a3;
    State[i * 4 + 2] := a0 xor a1 xor AES_GMul(a2, 2) xor AES_GMul(a3, 3);
    State[i * 4 + 3] := AES_GMul(a0, 3) xor a1 xor a2 xor AES_GMul(a3, 2);
  end;
end;

procedure AES_InvMixColumns(var State: array of Byte); inline;
var i: Integer;
    a0, a1, a2, a3: Byte;
begin
  for i := 0 to 3 do
  begin
    a0 := State[i * 4];
    a1 := State[i * 4 + 1];
    a2 := State[i * 4 + 2];
    a3 := State[i * 4 + 3];
    State[i * 4]     := AES_GMul(a0, 14) xor AES_GMul(a1, 11) xor AES_GMul(a2, 13) xor AES_GMul(a3, 9);
    State[i * 4 + 1] := AES_GMul(a0, 9)  xor AES_GMul(a1, 14) xor AES_GMul(a2, 11) xor AES_GMul(a3, 13);
    State[i * 4 + 2] := AES_GMul(a0, 13) xor AES_GMul(a1, 9)  xor AES_GMul(a2, 14) xor AES_GMul(a3, 11);
    State[i * 4 + 3] := AES_GMul(a0, 11) xor AES_GMul(a1, 13) xor AES_GMul(a2, 9)  xor AES_GMul(a3, 14);
  end;
end;

procedure AES_EncryptBlock(var Ctx: TAESContext;
                            InBlock: PByte; OutBlock: PByte);
var
  State: array[0..15] of Byte;
  Round: Integer;
begin
  Move(InBlock^, State[0], 16);
  AES_AddRoundKey(State, Ctx, 0);
  for Round := 1 to Ctx.Nr - 1 do
  begin
    AES_SubBytes(State);
    AES_ShiftRows(State);
    AES_MixColumns(State);
    AES_AddRoundKey(State, Ctx, Round);
  end;
  AES_SubBytes(State);
  AES_ShiftRows(State);
  AES_AddRoundKey(State, Ctx, Ctx.Nr);
  Move(State[0], OutBlock^, 16);
end;

procedure AES_DecryptBlock(var Ctx: TAESContext;
                            InBlock: PByte; OutBlock: PByte);
var
  State: array[0..15] of Byte;
  Round: Integer;
begin
  Move(InBlock^, State[0], 16);
  AES_AddRoundKey(State, Ctx, Ctx.Nr);
  for Round := Ctx.Nr - 1 downto 1 do
  begin
    AES_InvShiftRows(State);
    AES_InvSubBytes(State);
    AES_AddRoundKey(State, Ctx, Round);
    AES_InvMixColumns(State);
  end;
  AES_InvShiftRows(State);
  AES_InvSubBytes(State);
  AES_AddRoundKey(State, Ctx, 0);
  Move(State[0], OutBlock^, 16);
end;

function AESEncrypt(const Plaintext, Key: RawByteString;
                    const IV: RawByteString;
                    Mode: TAESMode): RawByteString;
var
  Ctx: TAESContext;
  KeyLen, PadLen, Blocks, i, j: Integer;
  Padded: RawByteString;
  Prev, Tmp: array[0..15] of Byte;
begin
  KeyLen := Length(Key);
  if (KeyLen <> 16) and (KeyLen <> 24) and (KeyLen <> 32) then
    raise ECryptoError.Create('AESEncrypt: key harus 16/24/32 byte');
  if (Mode = amCBC) and (Length(IV) <> 16) then
    raise ECryptoError.Create('AESEncrypt: IV harus 16 byte untuk CBC');

  AES_KeyExpansion(Ctx, @Key[1], KeyLen);

  // PKCS#7 pad
  PadLen := 16 - (Length(Plaintext) mod 16);
  SetLength(Padded, Length(Plaintext) + PadLen);
  if Length(Plaintext) > 0 then
    Move(Plaintext[1], Padded[1], Length(Plaintext));
  for i := Length(Plaintext) + 1 to Length(Padded) do
    Padded[i] := Char(PadLen);

  Blocks := Length(Padded) div 16;
  SetLength(Result, Length(Padded));

  // Init IV
  if Mode = amCBC then
    Move(IV[1], Prev[0], 16)
  else
    FillChar(Prev, 16, 0);

  for i := 0 to Blocks - 1 do
  begin
    if Mode = amCBC then
      for j := 0 to 15 do
        Tmp[j] := Byte(Padded[i * 16 + j + 1]) xor Prev[j]
    else
      for j := 0 to 15 do
        Tmp[j] := Byte(Padded[i * 16 + j + 1]);

    AES_EncryptBlock(Ctx, @Tmp[0], @Prev[0]);

    for j := 0 to 15 do
      Result[i * 16 + j + 1] := Char(Prev[j]);
  end;
end;

function AESDecrypt(const Ciphertext, Key: RawByteString;
                    const IV: RawByteString;
                    Mode: TAESMode): RawByteString;
var
  Ctx: TAESContext;
  KeyLen, Blocks, i, j, PadLen: Integer;
  Prev, Tmp, Dec: array[0..15] of Byte;
  CipherBlock: array[0..15] of Byte;
begin
  KeyLen := Length(Key);
  if (KeyLen <> 16) and (KeyLen <> 24) and (KeyLen <> 32) then
    raise ECryptoError.Create('AESDecrypt: key harus 16/24/32 byte');
  if (Length(Ciphertext) mod 16) <> 0 then
    raise ECryptoError.Create('AESDecrypt: ciphertext bukan kelipatan 16 byte');
  if Length(Ciphertext) = 0 then
    raise ECryptoError.Create('AESDecrypt: ciphertext kosong');
  if (Mode = amCBC) and (Length(IV) <> 16) then
    raise ECryptoError.Create('AESDecrypt: IV harus 16 byte untuk CBC');

  AES_KeyExpansion(Ctx, @Key[1], KeyLen);
  Blocks := Length(Ciphertext) div 16;
  SetLength(Result, Length(Ciphertext));

  if Mode = amCBC then
    Move(IV[1], Prev[0], 16)
  else
    FillChar(Prev, 16, 0);

  for i := 0 to Blocks - 1 do
  begin
    Move(Ciphertext[i * 16 + 1], CipherBlock[0], 16);

    AES_DecryptBlock(Ctx, @CipherBlock[0], @Tmp[0]);

    if Mode = amCBC then
      for j := 0 to 15 do
        Dec[j] := Tmp[j] xor Prev[j]
    else
      for j := 0 to 15 do
        Dec[j] := Tmp[j];

    for j := 0 to 15 do
      Result[i * 16 + j + 1] := Char(Dec[j]);

    Move(CipherBlock[0], Prev[0], 16);
  end;

  // Unpad PKCS#7
  PadLen := Byte(Result[Length(Result)]);
  if (PadLen < 1) or (PadLen > 16) or (PadLen > Length(Result)) then
    raise ECryptoError.Create('AESDecrypt: padding invalid');
  for i := Length(Result) - PadLen + 1 to Length(Result) do
    if Byte(Result[i]) <> PadLen then
      raise ECryptoError.Create('AESDecrypt: padding byte mismatch');
  SetLength(Result, Length(Result) - PadLen);
end;

// ════════════════════════════════════════════════════════════════
//  PBKDF2-HMAC-SHA256 (RFC 2898)
// ════════════════════════════════════════════════════════════════

function PBKDF2_SHA256(const Password, Salt: RawByteString;
                       Iterations, KeyLen: Integer): RawByteString;
var
  BlockIndex, I, J, Offset, ToCopy: Integer;
  U, T, PrevU: RawByteString;
  SaltWithIdx: RawByteString;
begin
  if Iterations < 1 then
    raise ECryptoError.Create('PBKDF2: iterations minimal 1');
  if KeyLen < 1 then
    raise ECryptoError.Create('PBKDF2: keyLen minimal 1');

  SetLength(Result, KeyLen);
  Offset := 0;
  BlockIndex := 1;

  while Offset < KeyLen do
  begin
    // Salt || INT32_BE(BlockIndex)
    SaltWithIdx := Salt + Char((BlockIndex shr 24) and $FF)
                        + Char((BlockIndex shr 16) and $FF)
                        + Char((BlockIndex shr 8) and $FF)
                        + Char(BlockIndex and $FF);

    U := HMACSHA256Bytes(Password, SaltWithIdx);
    T := U;
    PrevU := U;

    for I := 2 to Iterations do
    begin
      U := HMACSHA256Bytes(Password, PrevU);
      PrevU := U;
      for J := 1 to Length(T) do
        T[J] := Char(Byte(T[J]) xor Byte(U[J]));
    end;

    ToCopy := KeyLen - Offset;
    if ToCopy > Length(T) then ToCopy := Length(T);
    Move(T[1], Result[Offset + 1], ToCopy);
    Inc(Offset, ToCopy);
    Inc(BlockIndex);
  end;
end;

// ════════════════════════════════════════════════════════════════
//  SHA-1 (RFC 3174)
// ════════════════════════════════════════════════════════════════

type
  TSHA1Ctx = record
    State: array[0..4] of Cardinal;
    Buffer: array[0..63] of Byte;
    BufLen: Integer;
    TotalLen: QWord;
  end;

procedure SHA1_Transform(var Ctx: TSHA1Ctx);
var
  W: array[0..79] of Cardinal;
  A, B, C, D, E, F, K, T: Cardinal;
  i: Integer;
begin
  for i := 0 to 15 do
    W[i] := (Cardinal(Ctx.Buffer[i*4])     shl 24)
         or (Cardinal(Ctx.Buffer[i*4 + 1]) shl 16)
         or (Cardinal(Ctx.Buffer[i*4 + 2]) shl 8)
         or  Cardinal(Ctx.Buffer[i*4 + 3]);
  for i := 16 to 79 do
  begin
    T := W[i-3] xor W[i-8] xor W[i-14] xor W[i-16];
    W[i] := (T shl 1) or (T shr 31);
  end;

  A := Ctx.State[0]; B := Ctx.State[1]; C := Ctx.State[2];
  D := Ctx.State[3]; E := Ctx.State[4];

  for i := 0 to 79 do
  begin
    if i < 20 then
    begin
      F := (B and C) or ((not B) and D); K := $5A827999;
    end else if i < 40 then
    begin
      F := B xor C xor D; K := $6ED9EBA1;
    end else if i < 60 then
    begin
      F := (B and C) or (B and D) or (C and D); K := $8F1BBCDC;
    end else
    begin
      F := B xor C xor D; K := $CA62C1D6;
    end;

    T := ((A shl 5) or (A shr 27)) + F + E + K + W[i];
    E := D; D := C; C := (B shl 30) or (B shr 2); B := A; A := T;
  end;

  Inc(Ctx.State[0], A); Inc(Ctx.State[1], B); Inc(Ctx.State[2], C);
  Inc(Ctx.State[3], D); Inc(Ctx.State[4], E);
end;

procedure SHA1_Update(var Ctx: TSHA1Ctx; Data: PByte; Len: Integer);
var i, Fill, Take: Integer;
begin
  Inc(Ctx.TotalLen, QWord(Len));
  i := 0;
  while i < Len do
  begin
    Fill := 64 - Ctx.BufLen;
    Take := Len - i;
    if Take > Fill then Take := Fill;
    Move(Data[i], Ctx.Buffer[Ctx.BufLen], Take);
    Inc(Ctx.BufLen, Take);
    Inc(i, Take);
    if Ctx.BufLen = 64 then
    begin
      SHA1_Transform(Ctx);
      Ctx.BufLen := 0;
    end;
  end;
end;

function SHA1Bytes(const Data: RawByteString): RawByteString;
var
  Ctx: TSHA1Ctx;
  Pad: array[0..71] of Byte;
  PadLen, i: Integer;
  BitLen: QWord;
begin
  Ctx.State[0] := $67452301;
  Ctx.State[1] := $EFCDAB89;
  Ctx.State[2] := $98BADCFE;
  Ctx.State[3] := $10325476;
  Ctx.State[4] := $C3D2E1F0;
  Ctx.BufLen := 0;
  Ctx.TotalLen := 0;

  if Length(Data) > 0 then
    SHA1_Update(Ctx, @Data[1], Length(Data));
  
  // ⚠️ FIX: capture BitLen SEBELUM padding di-update.
  // TotalLen harus merefleksikan panjang data original saja.
  BitLen := Ctx.TotalLen * 8;
  
  FillChar(Pad, SizeOf(Pad), 0);
  Pad[0] := $80;
  PadLen := 56 - (Ctx.BufLen mod 64);
  if PadLen <= 0 then PadLen := PadLen + 64;
  SHA1_Update(Ctx, @Pad[0], PadLen);
  
  Pad[0] := Byte((BitLen shr 56) and $FF);  
  Pad[1] := Byte((BitLen shr 48) and $FF);
  Pad[2] := Byte((BitLen shr 40) and $FF);
  Pad[3] := Byte((BitLen shr 32) and $FF);
  Pad[4] := Byte((BitLen shr 24) and $FF);
  Pad[5] := Byte((BitLen shr 16) and $FF);
  Pad[6] := Byte((BitLen shr  8) and $FF);
  Pad[7] := Byte((BitLen       ) and $FF);
  SHA1_Update(Ctx, @Pad[0], 8);

  SetLength(Result, 20);
  for i := 0 to 4 do
  begin
    Result[i*4 + 1] := Char((Ctx.State[i] shr 24) and $FF);
    Result[i*4 + 2] := Char((Ctx.State[i] shr 16) and $FF);
    Result[i*4 + 3] := Char((Ctx.State[i] shr  8) and $FF);
    Result[i*4 + 4] := Char((Ctx.State[i]      ) and $FF);
  end;
end;

function SHA1Hex(const Data: RawByteString): string;
begin
  Result := BytesToHex(SHA1Bytes(Data));
end;

// ════════════════════════════════════════════════════════════════
//  Base64 (RFC 4648)
// ════════════════════════════════════════════════════════════════

const
  B64_CHARS = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';

function Base64Encode(const Data: RawByteString): string;
var
  i, OutLen: Integer;
  B0, B1, B2: Byte;
begin
  if Length(Data) = 0 then Exit('');
  OutLen := ((Length(Data) + 2) div 3) * 4;
  SetLength(Result, OutLen);

  i := 1;
  while i <= Length(Data) do
  begin
    B0 := Byte(Data[i]);
    B1 := 0; B2 := 0;
    if i + 1 <= Length(Data) then B1 := Byte(Data[i+1]);
    if i + 2 <= Length(Data) then B2 := Byte(Data[i+2]);

    Result[((i-1) div 3) * 4 + 1] := B64_CHARS[(B0 shr 2) + 1];
    Result[((i-1) div 3) * 4 + 2] := B64_CHARS[(((B0 and 3) shl 4) or (B1 shr 4)) + 1];
    if i + 1 <= Length(Data) then
      Result[((i-1) div 3) * 4 + 3] := B64_CHARS[(((B1 and 15) shl 2) or (B2 shr 6)) + 1]
    else
      Result[((i-1) div 3) * 4 + 3] := '=';
    if i + 2 <= Length(Data) then
      Result[((i-1) div 3) * 4 + 4] := B64_CHARS[(B2 and 63) + 1]
    else
      Result[((i-1) div 3) * 4 + 4] := '=';

    Inc(i, 3);
  end;
end;

function Base64Decode(const S: string): RawByteString;
var
  i, OutLen, Idx: Integer;
  C0, C1, C2, C3: Byte;
  Clean: string;

  function DecodeChar(C: Char): Integer;
  begin
    case C of
      'A'..'Z': Result := Ord(C) - Ord('A');
      'a'..'z': Result := Ord(C) - Ord('a') + 26;
      '0'..'9': Result := Ord(C) - Ord('0') + 52;
      '+': Result := 62;
      '/': Result := 63;
      '=', #0: Result := -1;
    else
      Result := -1;
    end;
  end;

begin
  // Strip whitespace
  Clean := '';
  for i := 1 to Length(S) do
    if S[i] in ['A'..'Z', 'a'..'z', '0'..'9', '+', '/', '='] then
      Clean := Clean + S[i];

  if Length(Clean) = 0 then Exit('');
  OutLen := (Length(Clean) div 4) * 3;
  if (Length(Clean) >= 1) and (Clean[Length(Clean)] = '=') then Dec(OutLen);
  if (Length(Clean) >= 2) and (Clean[Length(Clean)-1] = '=') then Dec(OutLen);

  SetLength(Result, OutLen);
  Idx := 0;
  i := 1;
  while i + 3 <= Length(Clean) do
  begin
    C0 := DecodeChar(Clean[i]);
    C1 := DecodeChar(Clean[i+1]);
    C2 := DecodeChar(Clean[i+2]);
    C3 := DecodeChar(Clean[i+3]);

    if Idx < OutLen then begin Result[Idx + 1] := Char((C0 shl 2) or (C1 shr 4)); Inc(Idx); end;
    if (Idx < OutLen) and (C2 >= 0) then begin Result[Idx + 1] := Char(((C1 and 15) shl 4) or (C2 shr 2)); Inc(Idx); end;
    if (Idx < OutLen) and (C3 >= 0) then begin Result[Idx + 1] := Char(((C2 and 3) shl 6) or C3); Inc(Idx); end;

    Inc(i, 4);
  end;
end;


initialization
finalization

end.