begin
  gui2.init();
  // do NOT setAutoScale
  println("scale =", gui2.getScale());
  println("autoscale =", gui2.getAutoScale());
  var win := gui2.window("No Scale", 200, 150);
  println("window opened");
  gui2.rect(10, 10, 100, 50, 80, 80, 80);
  gui2.present(win);
  gui2.delay(500);
  gui2.close(win);
  gui2.quit();
end.
