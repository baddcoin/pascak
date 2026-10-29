begin
  gui2.init();
  gui2.setAutoScale(true);
  println("scale =", gui2.getScale());
  println("autoscale =", gui2.getAutoScale());

  // With scale=2 and autoScale on: window(200,150) → physical 400x300
  // but logical coords remain 200x150 for drawing
  var win := gui2.window("Scaled Test", 200, 150);
  if not gui2.isOpen(win) then begin
    println("FAIL: window not open");
    gui2.quit();
  end;

  println("window opened");

  // Draw 100x50 rect at 10,10 (logical) — physical 200x100 at 20,20
  gui2.rect(10, 10, 100, 50, 80, 80, 80);
  gui2.present(win);

  println("rect drawn");
  gui2.delay(500);
  gui2.close(win);
  gui2.quit();
  println("done");
end.
