
// v1.11.0: Asset hot-reload example
//
// Usage (Termux):
//   1. echo "v1" > $HOME/web_test.txt
//   2. cd $HOME && pascak --dev /path/to/examples/gui_hotreload_asset.pas
//   3. Open browser: http://127.0.0.1:18090
//   4. echo "v2" > $HOME/web_test.txt  -> browser auto-reload
//
// Note: WATCH_PATH hardcoded for Termux. Adjust for other platforms.
//       Asset file is served by external tool (live-server, python http.server, etc);
//       gui.watch only triggers browser reload on file change.

var h = gui.create(18090, "Hot Asset Test");
var WATCH_PATH = "/data/data/com.termux/files/home/web_test.txt";

begin
  gui.watch(h, WATCH_PATH);
  gui.serve(h, "<html><body><h1>Asset Hot-Reload v1.11.0</h1><p>Edit web_test.txt and watch reload.</p></body></html>");
  gui.start(h);
  println("GUI running on 18090");
  println("Watching: " + WATCH_PATH);
  gui.run();
end.
