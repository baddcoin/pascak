begin
  gui2.init();
  var win := gui2.window("Test", 400, 300);
  println("window id =", win);
  println("isOpen   =", gui2.isOpen(win));
  gui2.rect(0, 0, 400, 300, 30, 30, 30);
  gui2.present(win);
  gui2.close(win);
  gui2.quit();
end.
