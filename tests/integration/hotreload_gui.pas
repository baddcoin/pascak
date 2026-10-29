var h := gui.create(18090, "Hot Test");

begin
  gui.serve(h, "<html><body><h1>APP v1</h1></body></html>");
  gui.start(h);
  println("GUI running on 18090");
  gui.run();
end.
