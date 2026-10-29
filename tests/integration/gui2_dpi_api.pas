begin
  gui2.init();
  println("=== Hi-DPI API test ===");
  println("scale           =", gui2.getScale());
  println("autoscale       =", gui2.getAutoScale());
  gui2.setAutoScale(true);
  println("autoscale (on)  =", gui2.getAutoScale());
  gui2.setAutoScale(false);
  println("autoscale (off) =", gui2.getAutoScale());
  gui2.quit();
end.
