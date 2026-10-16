procedure TickCoTasks;
var
  ReadyIDs: array of Int64;
  ReadyPriorities: array of Integer;
  TmpID: Int64;
  TmpP: Integer;
  i, j: Integer;
  T: PCoTask;
  VM: TVM;
  Res, SleepVal: TValue;
  NowTick: QWord;
  SleepMs: Integer;
  WasRunning: Boolean;
begin
  if not Assigned(GCoTasks) then Exit;

  // Collect ready tasks
  NowTick := GetTickCount64;
  SetLength(ReadyIDs, 0);
  SetLength(ReadyPriorities, 0);
  
  GCoTaskLock.Acquire;
  try
    for i := 0 to GCoTasks.Count - 1 do
    begin
      T := GCoTasks.Data[i];
      if not Assigned(T) then Continue;
      if (T^.State = 0) or (T^.State = 2) then
      begin
        if NowTick >= T^.WakeAt then
        begin
          T^.State := 1;
          SetLength(ReadyIDs, Length(ReadyIDs) + 1);
          SetLength(ReadyPriorities, Length(ReadyPriorities) + 1);
          ReadyIDs[High(ReadyIDs)] := T^.TaskID;
          ReadyPriorities[High(ReadyPriorities)] := T^.Priority;
        end;
      end;
    end;
  finally
    GCoTaskLock.Release;
  end;

  // Sort by priority descending (higher first) — insertion sort, small N
  for i := 0 to High(ReadyIDs) - 1 do
  begin
    for j := i + 1 to High(ReadyIDs) do
      if ReadyPriorities[j] > ReadyPriorities[i] then
      begin
        TmpID := ReadyIDs[i]; ReadyIDs[i] := ReadyIDs[j]; ReadyIDs[j] := TmpID;
        TmpP := ReadyPriorities[i]; ReadyPriorities[i] := ReadyPriorities[j]; ReadyPriorities[j] := TmpP;
      end;
  
  
    T := CoTaskFind(ReadyIDs[j]);
    if not Assigned(T) then Continue;

    VM := TVM(T^.VM);
    if not Assigned(VM) then
    begin
      T^.State := 4;
      T^.ErrorMsg := 'VM hilang';
      Continue;
    end;

    WasRunning := (VM.FState = vmReady) or (VM.FState = vmYielded);
    Res := nil;
    try
      if VM.FState = vmReady then
        Res := VM.Run(nil, True)
      else if VM.FState = vmYielded then
        Res := VM.Resume(nil)
      else
      begin
        T^.State := 3;
        Continue;
      end;
    except
      on E: Exception do
      begin
        T^.State := 4;
        T^.ErrorMsg := E.Message;
        Continue;
      end;
    end;

    // Interpret result based on VM state
    if VM.FState = vmDead then
    begin
      T^.State := 3;
      if Assigned(Res) then
        T^.FinalValue := Res
      else
        T^.FinalValue := TValue.CreateNull;
    
      // D.1c — fire callback if registered
      if Assigned(T^.Callback) and (T^.Callback.DataType = dtFunction) then
      begin
        try
          CallWSCallback(T^.Callback, [T^.FinalValue.Clone]);
        except
          on E: Exception do
            PushThreadError('coThen callback: ' + E.Message);
        end;
        // Callback registered → auto-free task
        CoTaskUnregister(T^.TaskID);
        CoTaskFree(T);
      end;
      Continue;
    end;

    // vmYielded — check for co_sleep marker
    if Assigned(Res) and (Res.DataType = dtDict) and
       Res.DictVal.HasKey('__co_sleep') then
    begin
      SleepVal := Res.DictVal.GetValueClone('__co_sleep');
      SleepMs := 0;
      if Assigned(SleepVal) and (SleepVal.DataType = dtNumeric) then
        SleepMs := Trunc(SleepVal.NumVal);
      if Assigned(SleepVal) then SleepVal.Free;
      Res.Free;
      T^.State := 2;
      T^.WakeAt := GetTickCount64 + QWord(SleepMs);
    end
    else
    begin
      // Generic yield — treat as pending, resume next tick
      if Assigned(Res) then Res.Free;
      T^.State := 0;
      T^.WakeAt := GetTickCount64 + 10;
    end;
  end;
end;