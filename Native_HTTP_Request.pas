// Native: http.get(url) → {status, headers, body}
// Only HTTP (no HTTPS yet)
function Native_HTTP_Request(Args: TObjectList; CallEnv: TSymbolTable): TValue;
var
  Method, URL, Host, Path, BodyStr: string;
  HeadersList: TStringList;
  Port, Sock: Integer;
  ColonPos, SlashPos, SchemeEnd: Integer;
  RawReq, RespBuf, Chunk, BodySlice: RawByteString;
  R, HeaderEnd, BodyStart: Integer;
  ResultDict, HeadersDict: TDictValue;
  StatusLine, HeaderBlock: string;
  Lines: TStringArray;
  i, Space1, Space2, Colon: Integer;
  HdrName, HdrValue: string;

  Keys: TStringArray;
  HV: TValue;
  Rest: string;
  StatusText2: string;
  OldHeaderVal: TValue;
  
  UseTLS: Boolean;
  DefaultPort: Integer;
  TLSConn: TTLSConnection;
  TLSContextLocal: TTLSContext;
  
  // ✅ TLS verify + header override
  NoVerifyEnv: string;
  VerifyEnabled: Boolean;
  hIdx: Integer;
  hLine, hName, hVal: string;
        
  ErrDetail: string; 

  // A.1 — Pool
  PoolKey: string;
  PooledConn: PHTTPPooledConn;
  ContentLength: integer;
  ResContentLength: Integer;
  ResConnClose: Boolean;
  ResChunked: Boolean;
  ChunkBody: RawByteString;
  ChunkComplete: Boolean;
  Reusable: Boolean;
  HeaderParsed: Boolean;
  hdrLines: TStringArray;
  hdrIdx: Integer;
  hdrLine: string;
  
  procedure DBG_HTTP(const Msg: string);
  begin
    {$IFDEF HTTP_DEBUG}
    WriteLn(ErrOutput, '[http] ', Msg);
    Flush(ErrOutput);
    {$ENDIF}
  end;

begin
  if (Args.Count < 2) or (Args.Count > 4) or
     (TValue(Args[0]).DataType <> dtString) or
     (TValue(Args[1]).DataType <> dtString) then
  begin
    errMSG.callerror(139, 
      'http.request(method, url, [headers], [body])', errMSG.xrow, errMSG.xcol);
    Exit(TValue.CreateNull);
  end;
  
  Method := UpperCase(TValue(Args[0]).StrVal);
  URL := TValue(Args[1]).StrVal;
  HeadersList := nil;
  BodyStr := '';
  
  if Args.Count >= 3 then
    if TValue(Args[2]).DataType = dtDict then
    begin
      HeadersList := TStringList.Create;
      Keys := TValue(Args[2]).DictVal.GetKeys;              // ← assignment biasa
      for i := 0 to High(Keys) do
      begin
        HV := TValue(Args[2]).DictVal.GetValueClone(Keys[i]);  // ← assignment biasa
        if Assigned(HV) and (HV.DataType = dtString) then
          HeadersList.Add(Keys[i] + ': ' + HV.StrVal);
        HV.Free;
      end;
    end;
  
  if Args.Count >= 4 then
    if TValue(Args[3]).DataType = dtString then
      BodyStr := TValue(Args[3]).StrVal;
  
  try
    SchemeEnd := Pos('://', URL);
    if SchemeEnd = 0 then
    begin
      errMSG.callerror(139, 'http.request: URL harus http://... atau https://...',
                       errMSG.xrow, errMSG.xcol);
      Exit(TValue.CreateNull);
    end;
    
    UseTLS := (Copy(URL, 1, 5) = 'https') or (Copy(URL, 1, 5) = 'HTTPS');
    DefaultPort := 80;
    if UseTLS then DefaultPort := 443;
    
    Rest := Copy(URL, SchemeEnd + 3, Length(URL));    
    SlashPos := Pos('/', Rest);
    if SlashPos = 0 then
    begin
      Host := Rest;
      Path := '/';
    end
    else
    begin
      Host := Copy(Rest, 1, SlashPos - 1);
      Path := Copy(Rest, SlashPos, Length(Rest));
    end;
    
    ColonPos := Pos(':', Host);
    if ColonPos > 0 then
    begin
      Port := StrToIntDef(Copy(Host, ColonPos + 1, Length(Host)), DefaultPort);
      Host := Copy(Host, 1, ColonPos - 1);
    end
    else
      Port := DefaultPort;
    
    DBG_HTTP('URL parsed: host=' + Host + ' port=' + IntToStr(Port) + ' path=' + Path);
    
    // Determine verify BEFORE pool key (affects pool identity)
    if UseTLS then
    begin
      if GDangerousEnvAllowed then
        NoVerifyEnv := GetEnvironmentVariable('PASCAK_TLS_NO_VERIFY')
      else
        NoVerifyEnv := '';
      VerifyEnabled := NoVerifyEnv <> '1';
      if VerifyEnabled and Assigned(HeadersList) then
      begin
        hIdx := 0;
        while hIdx < HeadersList.Count do
        begin
          hLine := HeadersList[hIdx];
          ColonPos := Pos(':', hLine);
          if ColonPos > 0 then
          begin
            hName := Trim(Copy(hLine, 1, ColonPos - 1));
            hVal := Trim(Copy(hLine, ColonPos + 1, Length(hLine)));
            if (LowerCase(hName) = 'x-pascak-no-verify') and (hVal = '1') then
            begin
              VerifyEnabled := False;
              Break;
            end;
          end;
          Inc(hIdx);
        end;
      end;
    end
    else
      VerifyEnabled := True;
    
    // Build pool key
    PoolKey := Host + ':' + IntToStr(Port) + ':' +
               IfThen(UseTLS, 'T', 'P') + ':' +
               IfThen(VerifyEnabled, 'V', 'N');
    
    Sock := -1;
    TLSConn := nil;
    TLSContextLocal := nil;
    
    // Try pool first
    PooledConn := nil;
    if Assigned(GHTTPPoolLock) then
      PooledConn := HTTPPoolGet(PoolKey);
    
    if Assigned(PooledConn) then
    begin
      Sock := PooledConn^.Sock;
      TLSConn := PooledConn^.TLSConn;
      TLSContextLocal := PooledConn^.TLSContextRef;
      PooledConn^.TLSConn := nil;
      PooledConn^.TLSContextRef := nil;
      PooledConn^.Sock := -1;
      Dispose(PooledConn);
      Inc(GHTTPPoolHits);
      DBG_HTTP('pool HIT — reusing conn');
    end
    else
    begin
      Inc(GHTTPPoolMisses);
      DBG_HTTP('pool MISS — new connect');
      if not NetConnect(Host, Port, HTTP_CLIENT_TIMEOUT, Sock) then
      begin
        errMSG.callerror(145, 'http.request: connect gagal — ' + NetLastError,
                         errMSG.xrow, errMSG.xcol);
        Exit(TValue.CreateNull);
      end;
    end;
  
    // ✅ E-2: wrap dengan TLS jika https://
    TLSConn := nil;
    TLSContextLocal := nil;
    if UseTLS then
    begin
      if not TLSInit then
      begin
        NetClose(Sock);
        errMSG.callerror(144, 'http.request: TLS tidak tersedia (libssl belum di-load)',
                         errMSG.xrow, errMSG.xcol);
        Exit(TValue.CreateNull);
      end;
      
      TLSContextLocal := GetSharedTLSContext(VerifyEnabled);
      if not Assigned(TLSContextLocal) then
      begin
        NetClose(Sock);
        errMSG.callerror(144, 'http.request: gagal buat TLS context',
                         errMSG.xrow, errMSG.xcol);
        Exit(TValue.CreateNull);
      end;
      
      if not TLSConnect(TLSContextLocal, Sock, Host, TLSConn) then
      begin
        // ✅ FIX: TLSConn selalu valid — aman akses LastError.
        // Kita harus Release TLSConn dan TLSContextLocal secara benar.
        ErrDetail := 'http.request: TLS handshake gagal — ' + TLSConn.LastError;
        
        if Assigned(TLSConn) then
        begin
          TLSConn.Release;
          TLSConn := nil;
        end;
        if Assigned(TLSContextLocal) then
        begin
          TLSContextLocal.Release;
          TLSContextLocal := nil;
        end;
        NetClose(Sock);
        
        errMSG.callerror(144, ErrDetail, errMSG.xrow, errMSG.xcol);
        Exit(TValue.CreateNull);
      end;
      
      DBG_HTTP('TLS handshake OK');
    end;    
   
    // A.1: force keep-alive for pooling
    if not Assigned(HeadersList) then
      HeadersList := TStringList.Create;
    HeadersList.Add('Connection: keep-alive');
   
    try
      RawReq := BuildHTTPRequest(Method, Path, Host, HeadersList, StrToRaw(BodyStr));
      DBG_HTTP('sending request, len=' + IntToStr(Length(RawReq)));
      if UseTLS then
      begin
        if TLSSend(TLSConn, RawReq) < 0 then
        begin
          errMSG.callerror(144, 'http.request: TLS send gagal — ' + TLSConn.LastError,
                           errMSG.xrow, errMSG.xcol);
          Exit(TValue.CreateNull);
        end;
      end
      else
      begin
        if NetSend(Sock, RawReq) < 0 then
        begin
          errMSG.callerror(144, 'http.request: send gagal', errMSG.xrow, errMSG.xcol);
          Exit(TValue.CreateNull);
        end;
      end;
      
      RespBuf := '';
      HeaderEnd := -1;
      ContentLength := -1;
      ResContentLength := -1;
      ResConnClose := False;
      ResChunked := False;
      ChunkComplete := False;
      HeaderParsed := False; 
      
      while True do
      begin
        if UseTLS then
          R := TLSRecv(TLSConn, 4096, Chunk)
        else
          R := NetRecvTimeout(Sock, 4096, HTTP_CLIENT_TIMEOUT, Chunk);
        if R <= 0 then Break;
        RespBuf := RespBuf + Chunk;
        
        // Parse headers once we have full header block
        if not HeaderParsed then
        begin
          HeaderEnd := LocalFindCRLFCRLF(RespBuf);
          if HeaderEnd > 0 then
          begin
            HeaderParsed := True;
            HeaderBlock := Copy(RespBuf, 1, HeaderEnd - 1);
            hdrLines := HeaderBlock.Split([#13#10]);
            for hdrIdx := 1 to High(hdrLines) do
            begin
              hdrLine := hdrLines[hdrIdx];
              if (Length(hdrLine) >= 15) and
                 SameText(Copy(hdrLine, 1, 15), 'Content-Length:') then
                ResContentLength := StrToIntDef(
                  Trim(Copy(hdrLine, 16, Length(hdrLine))), -1)
              
              else if (Length(hdrLine) >= 18) and
                      SameText(Copy(hdrLine, 1, 18), 'Transfer-Encoding:') then
              begin
                if Pos('chunked', LowerCase(hdrLine)) > 0 then
                begin
                  ResContentLength := -1;
                  ResChunked := True;
                end;
              end
              
              else if (Length(hdrLine) >= 11) and
                      SameText(Copy(hdrLine, 1, 11), 'Connection:') then
              begin
                if Pos('close', LowerCase(hdrLine)) > 0 then
                  ResConnClose := True;
              end;
            end;
          end;
        end;
        
        // Stop early: Content-Length known
        if HeaderParsed and (ResContentLength >= 0) then
        begin
          if Length(RespBuf) >= HeaderEnd + 3 + ResContentLength then
            Break;
        end;
        
        // Stop early: chunked, cek terminator '0\r\n'
        if HeaderParsed and ResChunked then
        begin
          if DecodeChunkedBody(RespBuf, HeaderEnd + 4, ChunkBody) then
          begin
            ChunkComplete := True;
            Break;
          end;
        end;
        
      end;
      DBG_HTTP('read done, total=' + IntToStr(Length(RespBuf)) + ' bytes');
      
      HeaderEnd := LocalFindCRLFCRLF(RespBuf);
      DBG_HTTP('HeaderEnd=' + IntToStr(HeaderEnd) + ' BodyStart=' + IntToStr(HeaderEnd + 4));
      if HeaderEnd < 0 then
      begin
        errMSG.callerror(144, 'http.request: response malformed', 
                         errMSG.xrow, errMSG.xcol);
        Exit(TValue.CreateNull);
      end;
      
      HeaderBlock := Copy(RespBuf, 1, HeaderEnd - 1);
      BodyStart := HeaderEnd + 4;
      
      // A.1b — De-chunk body kalau chunked
      if ResChunked then
      begin
        if not ChunkComplete then
        begin
          // Fallback: coba decode sekali lagi
          if not DecodeChunkedBody(RespBuf, BodyStart, ChunkBody) then
          begin
            // Incomplete — tutup socket, tidak reusable
            ChunkBody := '';
            ResConnClose := True;
          end
          else
            ChunkComplete := True;
        end;
      end;      
      
      Lines := HeaderBlock.Split([#13#10]);
      DBG_HTTP('header lines=' + IntToStr(Length(Lines)));
      
      StatusLine := Lines[0];
      Space1 := Pos(' ', StatusLine);
      StatusText2 := Copy(StatusLine, Space1 + 1, Length(StatusLine));  // ← assignment biasa
      Space2 := Pos(' ', StatusText2);
      
      ResultDict := TDictValue.Create;
      HeadersDict := TDictValue.Create;
      
      ResultDict.SetValue('status', 
        TValue.CreateNum(StrToIntDef(Copy(StatusText2, 1, Space2 - 1), 0)));
      
      ResultDict.SetValue('tls_verify',
        TValue.CreateBool(VerifyEnabled));
  
      for i := 1 to High(Lines) do
      begin
        if Lines[i] = '' then Continue;
        Colon := Pos(':', Lines[i]);
        if Colon <= 0 then Continue;
        DBG_HTTP('  hdr[' + IntToStr(i) + ']');
        HdrName := Trim(Copy(Lines[i], 1, Colon - 1));
        HdrValue := Trim(Copy(Lines[i], Colon + 1, Length(Lines[i])));
        
        // ✅ E-1b-2: accumulate duplicate headers (Set-Cookie, etc.)
        if HeadersDict.HasKey(HdrName) then
        begin
          OldHeaderVal := HeadersDict.GetValueClone(HdrName);
          if Assigned(OldHeaderVal) and (OldHeaderVal.DataType = dtString) then
            HeadersDict.SetValue(HdrName,
              TValue.CreateStr(OldHeaderVal.StrVal + ', ' + HdrValue))
          else
            HeadersDict.SetValue(HdrName, TValue.CreateStr(HdrValue));
          if Assigned(OldHeaderVal) then OldHeaderVal.Free;
        end
        else
          HeadersDict.SetValue(HdrName, TValue.CreateStr(HdrValue));
      end;
      
      ResultDict.SetValue('headers', TValue.CreateDict(HeadersDict));
      
      DBG_HTTP('building body from ' + IntToStr(BodyStart) + ' to ' + IntToStr(Length(RespBuf)));
      
      // A.1b — pakai de-chunked body kalau chunked
      if ResChunked then
      begin
        if ChunkComplete then
          BodySlice := ChunkBody
        else
          BodySlice := '';
      end
      else
      begin
        if (BodyStart >= 1) and (BodyStart <= Length(RespBuf)) then
        begin
          SetLength(BodySlice, Length(RespBuf) - BodyStart + 1);
          if Length(BodySlice) > 0 then
            Move(RespBuf[BodyStart], BodySlice[1], Length(BodySlice));
        end
        else
          BodySlice := '';
      end;
      
      if Length(BodySlice) > 0 then
      begin
        SetLength(BodyStr, Length(BodySlice));
        Move(BodySlice[1], BodyStr[1], Length(BodySlice));
      end
      else
        BodyStr := '';
      
      ResultDict.SetValue('body', TValue.CreateStr(BodyStr));      
      
      Result := TValue.CreateDict(ResultDict);
    finally
      // A.1 + A.1b: Decide pool vs close
      Reusable := HeaderParsed and (not ResConnClose) and (Sock >= 0) and
                  (((ResContentLength >= 0)) or
                   (ResChunked and ChunkComplete));     
                   
      if Reusable and Assigned(GHTTPPoolLock) then
      begin
        if HTTPPoolPut(PoolKey, Host, Port, Sock, TLSConn, TLSContextLocal) then
        begin
          DBG_HTTP('pool RETURN — conn back to pool');
          Sock := -1;
          TLSConn := nil;
          TLSContextLocal := nil;
        end
        else
        begin
          DBG_HTTP('pool REJECT — pool full, closing');
          if UseTLS and Assigned(TLSConn) then
          begin
            TLSClose(TLSConn);
            TLSConn.Release;
            TLSConn := nil;
          end;
          if Assigned(TLSContextLocal) then
          begin
            TLSContextLocal.Release;
            TLSContextLocal := nil;
          end;
          if Sock >= 0 then NetClose(Sock);
        end;
      end
      else
      begin
        if UseTLS and Assigned(TLSConn) then
        begin
          TLSClose(TLSConn);
          TLSConn.Release;
          TLSConn := nil;
        end;
        if Assigned(TLSContextLocal) then
        begin
          TLSContextLocal.Release;
          TLSContextLocal := nil;
        end;
        if Sock >= 0 then NetClose(Sock);
      end;
    end;
  finally
    if Assigned(HeadersList) then HeadersList.Free;
  end;
end;