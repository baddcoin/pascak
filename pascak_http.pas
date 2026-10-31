unit pascak_http;

{$MODE OBJFPC}{$H+}

interface

uses
  Classes, SysUtils, StrUtils;

type
  EHTTPError = class(Exception);

const
  HTTP_MAX_HEADER_BYTES = 65536;    // 64 KB untuk headers
  HTTP_MAX_BODY_BYTES   = 10485760; // 10 MB
  HTTP_RECV_TIMEOUT_MS  = 30000;    // 30 detik
  HTTP_CLIENT_TIMEOUT   = 30000;

  KEEPALIVE_MAX_REQUESTS = 100;
  KEEPALIVE_TIMEOUT_MS   = 30000;
// ════════════════════════════════════════════════════════════════
//  Request struct (parsed)
// ════════════════════════════════════════════════════════════════
type
  THTTPRequest = class
    Method: string;         // 'GET', 'POST', ...
    Path: string;           // '/user/42'
    QueryString: string;    // 'a=1&b=2'
    Version: string;        // 'HTTP/1.1'
    HeaderNames: TStringList;
    HeaderValues: TStringList;
    Body: RawByteString;
    
    function GetHeader(const Name: string): string;
    function GetQueryParam(const Name: string): string;
  end;

  THTTPResponse = class
    Status: Integer;        // 200, 404, ...
    StatusText: string;     // 'OK', 'Not Found', ...
    HeaderNames: TStringList;
    HeaderValues: TStringList;
    Body: RawByteString;
    
    procedure Init;
    procedure Done;
    procedure SetHeader(const Name, Value: string);
    function GetHeader(const Name: string): string;
  end;

// ════════════════════════════════════════════════════════════════
//  Parsing / Building
// ════════════════════════════════════════════════════════════════

// Parse raw HTTP request bytes. Return True jika berhasil.
// Consumed = jumlah byte yang dipakai (headers + body).
function ParseHTTPRequest(const Raw: RawByteString; 
          out Req: THTTPRequest;
          out Consumed: Integer;
          out ErrMsg: string): Boolean;

function ParseRawHTTPRequest(const Raw: RawByteString;
          out Method, Path, Query, Version: string;
          Names, Values: TStringList;
          out Body: RawByteString;
          out Consumed: Integer;
          out ErrMsg: string): Boolean;


// Build HTTP response bytes siap dikirim ke socket.
function BuildHTTPResponse(const Resp: THTTPResponse): RawByteString;

// Build HTTP request bytes (untuk client).
function BuildHTTPRequest(const Method, Path, Host: string;
          const Headers: TStringList;
          const Body: RawByteString): RawByteString;

procedure ParseCookieHeader(const CookieHeader: string;
          Names, Values: TStringList);
                            
function BuildHTTPResponseRaw(Status: Integer; const StatusText: string;
          Names, Values: TStringList;
          const Body: RawByteString): RawByteString;
// ════════════════════════════════════════════════════════════════
//  Router (path matching)
// ════════════════════════════════════════════════════════════════

// Match "pattern" (e.g. "/user/:id/post/:postId") terhadap
// "actual" (e.g. "/user/42/post/7").
// ParamNames/ParamValues diisi dengan nama+value param yang tertangkap.
// Return True jika cocok.
function MatchRoute(const Pattern, Actual: string;
          ParamNames, ParamValues: TStringList): Boolean;

// ════════════════════════════════════════════════════════════════
//  Utility
// ════════════════════════════════════════════════════════════════

// URL decode: '%20' -> ' ', '+' -> ' '
function URLDecode(const S: string): string;
// URL encode
function URLEncode(const S: string): string;

// Status text lookup
function HTTPStatusText(Code: Integer): string;

// Extract header value case-insensitively
function FindHeader(Names, Values: TStringList; const Name: string): string;

// MIME type guess from extension
function MimeTypeFromExt(const FileName: string): string;
function FindCRLF(const S: RawByteString; StartPos: Integer): Integer;
function FindCRLFCRLF(const S: RawByteString): Integer;

implementation

// ════════════════════════════════════════════════════════════════
//  Helpers
// ════════════════════════════════════════════════════════════════

function FindCRLF(const S: RawByteString; StartPos: Integer): Integer;
var
  i: Integer;
begin
  Result := -1;
  for i := StartPos to Length(S) - 1 do
    if (S[i] = #13) and (S[i+1] = #10) then
      Exit(i);
end;

function FindCRLFCRLF(const S: RawByteString): Integer;
var
  P: Integer;
begin
  Result := -1;
  P := 1;
  while P <= Length(S) - 3 do
  begin
    if (S[P] = #13) and (S[P+1] = #10) and 
       (S[P+2] = #13) and (S[P+3] = #10) then
      Exit(P);
    Inc(P);
  end;
end;

function HTTPStatusText(Code: Integer): string;
begin
  case Code of
    100: Result := 'Continue';
    200: Result := 'OK';
    201: Result := 'Created';
    204: Result := 'No Content';
    301: Result := 'Moved Permanently';
    302: Result := 'Found';
    304: Result := 'Not Modified';
    400: Result := 'Bad Request';
    401: Result := 'Unauthorized';
    403: Result := 'Forbidden';
    404: Result := 'Not Found';
    405: Result := 'Method Not Allowed';
    408: Result := 'Request Timeout';
    413: Result := 'Payload Too Large';
    500: Result := 'Internal Server Error';
    501: Result := 'Not Implemented';
    502: Result := 'Bad Gateway';
    503: Result := 'Service Unavailable';
  else
    Result := 'Unknown';
  end;
end;

function FindHeader(Names, Values: TStringList; const Name: string): string;
var
  i: Integer;
begin
  Result := '';
  if (Names = nil) or (Values = nil) then Exit;
  for i := 0 to Names.Count - 1 do
    if SameText(Names[i], Name) then
      Exit(Values[i]);
end;

function URLDecode(const S: string): string;
var
  i, Len: Integer;
  C: Char;
  Hi, Lo: Byte;
  
  function HexVal(C: Char): Byte;
  begin
    case C of
      '0'..'9': Result := Ord(C) - Ord('0');
      'a'..'f': Result := Ord(C) - Ord('a') + 10;
      'A'..'F': Result := Ord(C) - Ord('A') + 10;
    else
      Result := 255;
    end;
  end;
  
begin
  Result := '';
  i := 1;
  Len := Length(S);
  while i <= Len do
  begin
    C := S[i];
    if C = '+' then
    begin
      Result := Result + ' ';
      Inc(i);
    end
    else if (C = '%') and (i + 2 <= Len) then
    begin
      Hi := HexVal(S[i+1]);
      Lo := HexVal(S[i+2]);
      if (Hi <> 255) and (Lo <> 255) then
      begin
        Result := Result + Char((Hi shl 4) or Lo);
        Inc(i, 3);
      end
      else
      begin
        Result := Result + C;
        Inc(i);
      end;
    end
    else
    begin
      Result := Result + C;
      Inc(i);
    end;
  end;
end;

function URLEncode(const S: string): string;
const
  HexChars: array[0..15] of Char = '0123456789ABCDEF';
var
  i: Integer;
  B: Byte;
  IsSafe: Boolean;
begin
  Result := '';
  for i := 1 to Length(S) do
  begin
    B := Byte(S[i]);
    IsSafe := (B >= Ord('A')) and (B <= Ord('Z')) or
              (B >= Ord('a')) and (B <= Ord('z')) or
              (B >= Ord('0')) and (B <= Ord('9')) or
              (B = Ord('-')) or (B = Ord('_')) or 
              (B = Ord('.')) or (B = Ord('~'));
    if IsSafe then
      Result := Result + Char(B)
    else
    begin
      Result := Result + '%';
      Result := Result + HexChars[B shr 4];
      Result := Result + HexChars[B and $0F];
    end;
  end;
end;

function MimeTypeFromExt(const FileName: string): string;
var
  Ext: string;
begin
  Ext := LowerCase(ExtractFileExt(FileName));
  case Ext of
    '.html', '.htm': Result := 'text/html; charset=utf-8';
    '.css': Result := 'text/css';
    '.js':  Result := 'application/javascript';
    '.json': Result := 'application/json';
    '.txt': Result := 'text/plain; charset=utf-8';
    '.xml': Result := 'application/xml';
    '.png': Result := 'image/png';
    '.jpg', '.jpeg': Result := 'image/jpeg';
    '.gif': Result := 'image/gif';
    '.svg': Result := 'image/svg+xml';
    '.pdf': Result := 'application/pdf';
    '.zip': Result := 'application/zip';
    '.bin', '.exe', '.dll', '.so': Result := 'application/octet-stream';
  else
    Result := 'application/octet-stream';
  end;
end;

// ════════════════════════════════════════════════════════════════
//  THTTPRequest
// ════════════════════════════════════════════════════════════════

function THTTPRequest.GetHeader(const Name: string): string;
begin
  Result := FindHeader(HeaderNames, HeaderValues, Name);
end;

function THTTPRequest.GetQueryParam(const Name: string): string;
var
  Pairs: TStringArray;
  i, EqPos: Integer;
  Key, Val: string;
begin
  Result := '';
  if QueryString = '' then Exit;
  Pairs := QueryString.Split(['&']);
  for i := 0 to High(Pairs) do
  begin
    EqPos := Pos('=', Pairs[i]);
    if EqPos > 0 then
    begin
      Key := Copy(Pairs[i], 1, EqPos - 1);
      Val := Copy(Pairs[i], EqPos + 1, Length(Pairs[i]));
      if Key = Name then
        Exit(URLDecode(Val));
    end
    else if Pairs[i] = Name then
      Exit('');
  end;
end;

// ════════════════════════════════════════════════════════════════
//  THTTPResponse
// ════════════════════════════════════════════════════════════════

procedure THTTPResponse.Init;
begin
  Status := 200;
  StatusText := 'OK';
  HeaderNames := TStringList.Create;
  HeaderValues := TStringList.Create;
  Body := '';
end;

procedure THTTPResponse.Done;
begin
  if Assigned(HeaderNames) then FreeAndNil(HeaderNames);
  if Assigned(HeaderValues) then FreeAndNil(HeaderValues);
end;

procedure THTTPResponse.SetHeader(const Name, Value: string);
var
  i: Integer;
begin
  for i := 0 to HeaderNames.Count - 1 do
    if SameText(HeaderNames[i], Name) then
    begin
      HeaderValues[i] := Value;
      Exit;
    end;
  HeaderNames.Add(Name);
  HeaderValues.Add(Value);
end;

function THTTPResponse.GetHeader(const Name: string): string;
begin
  Result := FindHeader(HeaderNames, HeaderValues, Name);
end;

// ════════════════════════════════════════════════════════════════
//  Request parser
// ════════════════════════════════════════════════════════════════

function ParseHTTPRequest(const Raw: RawByteString; 
                          out Req: THTTPRequest;
                          out Consumed: Integer;
                          out ErrMsg: string): Boolean;
var
  HeaderEnd, BodyStart: Integer;
  HeaderBlock, Line: string;
  Lines: TStringArray;
  i, SpacePos1, SpacePos2, ColonPos: Integer;
  ContentLen: Integer;
  TotalNeeded: Integer;
  MethodAndPath: string;
  QueryPos: Integer;
begin
  Result := False;
  Consumed := 0;
  ErrMsg := '';
  
  // ✅ FIX: caller sudah create TStringList. Kita hanya clear + reuse
  // untuk menghindari memory leak pada multiple-incomplete-headers loop.
  if not Assigned(Req.HeaderNames) then
    Req.HeaderNames := TStringList.Create
  else
    Req.HeaderNames.Clear;
  
  if not Assigned(Req.HeaderValues) then
    Req.HeaderValues := TStringList.Create
  else
    Req.HeaderValues.Clear;
  
  Req.Body := '';
  
  // Cari akhir headers: \r\n\r\n
  HeaderEnd := FindCRLFCRLF(Raw);
  if HeaderEnd < 0 then
  begin
    ErrMsg := 'incomplete headers';
    Exit;
  end;
  
  HeaderBlock := Copy(Raw, 1, HeaderEnd - 1);
  BodyStart := HeaderEnd + 4;
  
  Lines := HeaderBlock.Split([#13#10]);
  if Length(Lines) = 0 then
  begin
    ErrMsg := 'empty request';
    Exit;
  end;
  
  // Parse request line: METHOD PATH HTTP/x.y
  Line := Lines[0];
  SpacePos1 := Pos(' ', Line);
  if SpacePos1 <= 0 then
  begin
    ErrMsg := 'malformed request line';
    Exit;
  end;
  MethodAndPath := Copy(Line, SpacePos1 + 1, Length(Line));
  SpacePos2 := Pos(' ', MethodAndPath);
  if SpacePos2 <= 0 then
  begin
    ErrMsg := 'malformed request line (no version)';
    Exit;
  end;
  
  Req.Method := Copy(Line, 1, SpacePos1 - 1);
  Req.Path := Copy(MethodAndPath, 1, SpacePos2 - 1);
  Req.Version := Copy(MethodAndPath, SpacePos2 + 1, Length(MethodAndPath));
  
  // Extract query string
  QueryPos := Pos('?', Req.Path);
  if QueryPos > 0 then
  begin
    Req.QueryString := Copy(Req.Path, QueryPos + 1, Length(Req.Path));
    Req.Path := Copy(Req.Path, 1, QueryPos - 1);
  end;
  
  // Parse headers
  for i := 1 to High(Lines) do
  begin
    Line := Lines[i];
    if Line = '' then Continue;
    ColonPos := Pos(':', Line);
    if ColonPos <= 0 then Continue;
    Req.HeaderNames.Add(Trim(Copy(Line, 1, ColonPos - 1)));
    Req.HeaderValues.Add(Trim(Copy(Line, ColonPos + 1, Length(Line))));
  end;
  
  // Body length
  ContentLen := 0;
  Line := Req.GetHeader('Content-Length');
  if Line <> '' then
    ContentLen := StrToIntDef(Line, 0);
  
  if ContentLen < 0 then
  begin
    ErrMsg := 'invalid Content-Length';
    Exit;
  end;
  
  if ContentLen > HTTP_MAX_BODY_BYTES then
  begin
    ErrMsg := 'body too large';
    Exit;
  end;
  
  TotalNeeded := BodyStart - 1 + ContentLen;
  if Length(Raw) < TotalNeeded then
  begin
    ErrMsg := 'incomplete body';
    Exit;
  end;
  
  if ContentLen > 0 then
    Req.Body := Copy(Raw, BodyStart, ContentLen);
  
  Consumed := TotalNeeded;
  Result := True;
end;

// ✅ Helper: parse tanpa THTTPRequest record
function ParseRawHTTPRequest(const Raw: RawByteString;
                              out Method, Path, Query, Version: string;
                              Names, Values: TStringList;
                              out Body: RawByteString;
                              out Consumed: Integer;
                              out ErrMsg: string): Boolean;
var
  HeaderEnd, BodyStart, ContentLen, TotalNeeded: Integer;
  HeaderBlock, Line: string;
  Lines: TStringArray;
  i, SpacePos1, SpacePos2, ColonPos, QueryPos: Integer;
  MethodAndPath: string;
begin
  Result := False;
  Consumed := 0;
  ErrMsg := '';
  Method := '';
  Path := '';
  Query := '';
  Version := '';
  Body := '';
  Names.Clear;
  Values.Clear;
  
  HeaderEnd := FindCRLFCRLF(Raw);
  if HeaderEnd < 0 then
  begin
    ErrMsg := 'incomplete headers';
    Exit;
  end;
  
  HeaderBlock := Copy(Raw, 1, HeaderEnd - 1);
  BodyStart := HeaderEnd + 4;
  
  Lines := HeaderBlock.Split([#13#10]);
  if Length(Lines) = 0 then
  begin
    ErrMsg := 'empty request';
    Exit;
  end;
  
  Line := Lines[0];
  SpacePos1 := Pos(' ', Line);
  if SpacePos1 <= 0 then
  begin
    ErrMsg := 'malformed request line';
    Exit;
  end;
  MethodAndPath := Copy(Line, SpacePos1 + 1, Length(Line));
  SpacePos2 := Pos(' ', MethodAndPath);
  if SpacePos2 <= 0 then
  begin
    ErrMsg := 'malformed request line (no version)';
    Exit;
  end;
  
  Method := Copy(Line, 1, SpacePos1 - 1);
  Path := Copy(MethodAndPath, 1, SpacePos2 - 1);
  Version := Copy(MethodAndPath, SpacePos2 + 1, Length(MethodAndPath));
  
  QueryPos := Pos('?', Path);
  if QueryPos > 0 then
  begin
    Query := Copy(Path, QueryPos + 1, Length(Path));
    Path := Copy(Path, 1, QueryPos - 1);
  end;
  
  for i := 1 to High(Lines) do
  begin
    Line := Lines[i];
    if Line = '' then Continue;
    ColonPos := Pos(':', Line);
    if ColonPos <= 0 then Continue;
    Names.Add(Trim(Copy(Line, 1, ColonPos - 1)));
    Values.Add(Trim(Copy(Line, ColonPos + 1, Length(Line))));
  end;
  
  ContentLen := 0;
  Line := FindHeader(Names, Values, 'Content-Length');
  if Line <> '' then
    ContentLen := StrToIntDef(Line, 0);
  
  if ContentLen < 0 then
  begin
    ErrMsg := 'invalid Content-Length';
    Exit;
  end;
  
  if ContentLen > HTTP_MAX_BODY_BYTES then
  begin
    ErrMsg := 'body too large';
    Exit;
  end;
  
  TotalNeeded := BodyStart - 1 + ContentLen;
  if Length(Raw) < TotalNeeded then
  begin
    ErrMsg := 'incomplete body';
    Exit;
  end;
  
  if ContentLen > 0 then
    Body := Copy(Raw, BodyStart, ContentLen);
  
  Consumed := TotalNeeded;
  Result := True;
end;

// ✅ Helper: build response dari scalar + TStringList
function BuildHTTPResponseRaw(Status: Integer; const StatusText: string;
          Names, Values: TStringList;
          const Body: RawByteString): RawByteString;
var
  Head: string;
  i: Integer;
  HasContentLength, HasConnection, HasContentType: Boolean;
  IsBodyless: Boolean;
begin
  Head := 'HTTP/1.1 ' + IntToStr(Status) + ' ' + StatusText + #13#10;
  
  HasContentLength := False;
  HasConnection := False;
  HasContentType := False;
  
  if Assigned(Names) and Assigned(Values) then
    for i := 0 to Names.Count - 1 do
    begin
      Head := Head + Names[i] + ': ' + Values[i] + #13#10;
      if SameText(Names[i], 'Content-Length') then HasContentLength := True;
      if SameText(Names[i], 'Connection') then HasConnection := True;
      if SameText(Names[i], 'Content-Type') then HasContentType := True;
    end;
  
  // RFC 7230 §3.3.2: 1xx dan 204 adalah "bodyless" — tidak boleh
  // punya Content-Length, dan secara implisit tidak punya body sama sekali.
  { v1.11.9: 304 Not Modified is bodyless per RFC 7232 §4.1 —
    no Content-Type, no Content-Length (browser uses cached value). }
  IsBodyless := ((Status >= 100) and (Status < 200)) or (Status = 204) or (Status = 304);
  
  if (not IsBodyless) and (not HasContentLength) then
    Head := Head + 'Content-Length: ' + IntToStr(Length(Body)) + #13#10;
  
  if not HasConnection then
    Head := Head + 'Connection: close' + #13#10;
  
  // Content-Type default hanya untuk response yang punya body.
  // 101 Switching Protocols TIDAK boleh punya Content-Type — body
  // sepenuhnya milik protokol di atasnya (WebSocket frame stream).
  if (not IsBodyless) and (not HasContentType) then
    Head := 'HTTP/1.1 ' + IntToStr(Status) + ' ' + StatusText + #13#10 +
            'Content-Type: text/plain; charset=utf-8' + #13#10 +
            Copy(Head, Pos(#13#10, Head) + 2, Length(Head));
  
  Head := Head + #13#10;
  
  Result := RawByteString(Head);
  if (not IsBodyless) and (Length(Body) > 0) then
    Result := Result + Body;
end;

// ════════════════════════════════════════════════════════════════
//  Response builder
// ════════════════════════════════════════════════════════════════

function BuildHTTPResponse(const Resp: THTTPResponse): RawByteString;
var
  Head: string;
  i: Integer;
  HasContentLength: Boolean;
  HasConnection: Boolean;
begin
  Head := 'HTTP/1.1 ' + IntToStr(Resp.Status) + ' ' + Resp.StatusText + #13#10;
  
  HasContentLength := False;
  HasConnection := False;
  for i := 0 to Resp.HeaderNames.Count - 1 do
  begin
    Head := Head + Resp.HeaderNames[i] + ': ' + Resp.HeaderValues[i] + #13#10;
    if SameText(Resp.HeaderNames[i], 'Content-Length') then HasContentLength := True;
    if SameText(Resp.HeaderNames[i], 'Connection') then HasConnection := True;
  end;
  
  if not HasContentLength then
    Head := Head + 'Content-Length: ' + IntToStr(Length(Resp.Body)) + #13#10;
  if not HasConnection then
    Head := Head + 'Connection: close' + #13#10;
  
  Head := Head + #13#10;
  
  Result := RawByteString(Head);
  if Length(Resp.Body) > 0 then
    Result := Result + Resp.Body;
end;

// ════════════════════════════════════════════════════════════════
//  Request builder (client)
// ════════════════════════════════════════════════════════════════

function BuildHTTPRequest(const Method, Path, Host: string;
                          const Headers: TStringList;
                          const Body: RawByteString): RawByteString;
var
  Head: string;
  i: Integer;
  HasContentLength, HasHost, HasConnection: Boolean;
begin
  Head := Method + ' ' + Path + ' HTTP/1.1' + #13#10;
  
  HasContentLength := False;
  HasHost := False;
  HasConnection := False;
  
  if Assigned(Headers) then
  begin
    for i := 0 to Headers.Count - 1 do
    begin
      Head := Head + Headers[i] + #13#10;
      if SameText(Copy(Headers[i], 1, Pos(':', Headers[i]) - 1), 'Content-Length') then 
        HasContentLength := True;
      if SameText(Copy(Headers[i], 1, Pos(':', Headers[i]) - 1), 'Host') then 
        HasHost := True;
      if SameText(Copy(Headers[i], 1, Pos(':', Headers[i]) - 1), 'Connection') then 
        HasConnection := True;
    end;
  end;
  
  if not HasHost then Head := Head + 'Host: ' + Host + #13#10;
  if not HasContentLength then Head := Head + 'Content-Length: ' + IntToStr(Length(Body)) + #13#10;
  if not HasConnection then Head := Head + 'Connection: close' + #13#10;
  
  Head := Head + #13#10;
  
  Result := RawByteString(Head);
  if Length(Body) > 0 then
    Result := Result + Body;
end;

procedure ParseCookieHeader(const CookieHeader: string;
                            Names, Values: TStringList);
var
  Segs: TStringArray;
  i, EqPos: Integer;
  Pair, Name, Val: string;
begin
  if (not Assigned(Names)) or (not Assigned(Values)) then Exit;
  if CookieHeader = '' then Exit;
  
  Segs := CookieHeader.Split([';']);
  for i := 0 to High(Segs) do
  begin
    Pair := Trim(Segs[i]);
    if Pair = '' then Continue;
    EqPos := Pos('=', Pair);
    if EqPos <= 0 then Continue;
    Name := Trim(Copy(Pair, 1, EqPos - 1));
    Val := Trim(Copy(Pair, EqPos + 1, Length(Pair)));
    Names.Add(Name);
    Values.Add(Val);
  end;
end;

// ════════════════════════════════════════════════════════════════
//  Router
// ════════════════════════════════════════════════════════════════

function MatchRoute(const Pattern, Actual: string;
                    ParamNames, ParamValues: TStringList): Boolean;
var
  PatParts, ActParts: TStringArray;
  i: Integer;
  Seg: string;
begin
  Result := False;
  if Assigned(ParamNames) then ParamNames.Clear;
  if Assigned(ParamValues) then ParamValues.Clear;
  
  PatParts := Pattern.Split(['/']);
  ActParts := Actual.Split(['/']);
  
  if Length(PatParts) <> Length(ActParts) then Exit;
  
  for i := 0 to High(PatParts) do
  begin
    Seg := PatParts[i];
    if (Length(Seg) > 0) and (Seg[1] = ':') then
    begin
      if Assigned(ParamNames) then
        ParamNames.Add(Copy(Seg, 2, Length(Seg)));
      if Assigned(ParamValues) then
        ParamValues.Add(ActParts[i]);
    end
    else if Seg <> ActParts[i] then
      Exit;
  end;
  
  Result := True;
end;

initialization
finalization

end.