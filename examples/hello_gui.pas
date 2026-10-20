/*
  examples/hello_gui.pas

  Browser-based GUI demo (counter with HTML button).

  Run:   pascak_noASTnet examples/hello_gui.pas

  Opens browser to http://localhost:18300/
*/

begin
  // Allow browser spawn (gui.open shells out to termux-open-url / xdg-open)
  sys.execWhitelist(["termux-open-url", "xdg-open", "open"]);

  var h := gui.create(18300, 18301, "Pascak Counter");
  if h < 0 then begin
    println("gui.create failed");
    sys.exit(1);
  end;

  // Server-side counter state (persists across RPC calls)
  var counter := 0;

  gui.bind(h, "increment", lambda args : begin
    lock begin
      counter := counter + 1;
    end;
    return counter;
  end);

  gui.bind(h, "reset", lambda args : begin
    lock begin
      counter := 0;
    end;
    return 0;
  end);

  gui.serve(h,
    '<!DOCTYPE html>' +
    '<html><head><title>Pascak Counter</title>' +
    '<style>' +
    'body{font-family:sans-serif;padding:40px;text-align:center;}' +
    'h1{color:#333;}' +
    '#n{font-size:80px;font-weight:bold;color:#2a8;margin:20px;}' +
    'button{font-size:24px;padding:12px 24px;margin:8px;cursor:pointer;}' +
    '</style></head><body>' +
    '<h1>Pascak Counter</h1>' +
    '<div id="n">0</div>' +
    '<button onclick="inc()">+1</button>' +
    '<button onclick="rst()">Reset</button>' +
    '<script>' +
    'async function inc(){' +
    '  var v = await window.pascak.call("increment", []);' +
    '  document.getElementById("n").textContent = v;' +
    '}' +
    'async function rst(){' +
    '  var v = await window.pascak.call("reset", []);' +
    '  document.getElementById("n").textContent = v;' +
    '}' +
    '</script></body></html>');

  var r := gui.start(h);
  if not r then begin
    println("gui.start failed");
    gui.close(h);
    sys.exit(1);
  end;

  println("GUI running at http://localhost:18300/");
  println("Opening browser...");
  if not gui.open(h) then
    println("  (browser spawn failed — open URL manually)");

  // Auto-exit after 60s for demo purposes
  setTimeout(lambda : begin
    println("Demo timeout (60s) — closing");
    gui.close(h);
    sys.exit(0);
  end, 60000);

  gui.run(h);
end.
