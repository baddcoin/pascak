begin
  gui2.init();
  gui2.window("bench", 400, 300);
  var i := 0;
  while i < 100 do begin
    var b := gui2.button(0, 0, 80, 30, "B" + str(i));
    gui2.widgetSetColors(b, 100, 150, 200, 255, 255, 255);
    i := i + 1;
  end;
  var ids := [];
  i := 0;
  while i < 100 do begin
    ids := ids + [i + 1];
    i := i + 1;
  end;
  println("100 buttons created+themed");
  gui2.quit();
end.
