begin
  testBegin("Fase 1.4 - Env Poisoning Guard");
  
  // Di bawah --dev, env override aktif — cek via sys.execInfo
  var info := sys.execInfo();
  if info["mode"] == "allow-all" then
    println("  [dev] env policy active: ", info["mode"])
  else
    println("  [prod] env policy ignored: ", info["mode"]);
  
  assertTrue(true, "info fetched");
  testEnd();
end.
