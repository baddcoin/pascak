// If, while, for, foreach, case
begin
  // If-Else
  var umur := 20;
  if umur >= 18 then
    println("Dewasa")
  else
    println("Anak");
  
  // Ternary
  var label := umur >= 18 ? "Dewasa" : "Anak";
  println("Label: ", label);
  
  // While
  println("While loop:");
  var i := 0;
  while i < 5 do begin
    print(i, " ");
    i += 1;
  end;
  println();
  
  // For
  println("For to:");
  for i := 1 to 5 do print(i, " ");
  println();
  
  println("For downto:");
  for i := 5 downto 1 do print(i, " ");
  println();
  
  println("For step 2:");
  for i := 0 to 10 step 2 do print(i, " ");
  println();
  
  // Foreach
  println("Foreach array:");
  for x in [10, 20, 30] do print(x, " ");
  println();
  
  println("Foreach dict (keys):");
  for k in {a: 1, b: 2, c: 3} do print(k, " ");
  println();
  
  // Case
  var nilai := 85;
  case nilai of
    100: println("Sempurna");
    90: println("A");
    80: println("B");
    else: println("Lainnya");
  end;
  
  // Break & continue
  println("Break at 3:");
  for i := 0 to 10 do begin
    if i = 3 then break;
    print(i, " ");
  end;
  println();
end.