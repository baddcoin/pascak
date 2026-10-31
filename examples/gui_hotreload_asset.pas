
// v1.11.1: Asset hot-reload via serveDir (static + reload combined)
//
// Usage (Termux):
//   mkdir -p $HOME/web_test
//   echo '<h1>v1</h1>' > $HOME/web_test/index.html
//   echo 'body{color:red}' > $HOME/web_test/style.css
//   cd $HOME && pascak --dev /path/to/examples/gui_hotreload_asset.pas
//
//   Browser: http://127.0.0.1:18090/
//   Edit $HOME/web_test/index.html -> browser auto-reload
//
// WATCH_ROOT hardcoded for Termux. Adjust for other platforms.

var h = gui.create(18090, "Hot ServeDir Test");
var WATCH_ROOT = "/data/data/com.termux/files/home/web_test";

begin
  gui.serveDir(h, WATCH_ROOT);
  gui.start(h);
  println("GUI running on 18090 (serving " + WATCH_ROOT + ")");
  gui.run();
end.
