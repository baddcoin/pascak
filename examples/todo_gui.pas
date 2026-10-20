/*
  examples/todo_gui.pas

  Browser-based Todo list with SQLite persistence.

  Run:   pascak_noASTnet examples/todo_gui.pas
  Opens: http://localhost:18310/

  Demonstrates:
    - gui.bind RPC (add / list / toggle / delete)
    - SQLite from within RPC callbacks
    - JSON serialization of rows -> JS array
*/

begin
  sys.execWhitelist(["termux-open-url", "xdg-open", "open"]);

  var db := sqliteConnect("todo.db");
  sqliteExec(db,
    "CREATE TABLE IF NOT EXISTS todos (" +
    "id INTEGER PRIMARY KEY AUTOINCREMENT, " +
    "text TEXT NOT NULL, " +
    "done INTEGER NOT NULL DEFAULT 0)");

  var h := gui.create(18310, 18311, "Pascak Todo");
  if h < 0 then begin
    println("gui.create failed");
    sys.exit(1);
  end;

  gui.bind(h, "add", lambda args : begin
    var text := args[0];
    if typeOf(text) != "string" then return false;
    if len(trim(text)) == 0 then return false;
    sqliteExec(db, "INSERT INTO todos (text) VALUES (?)", [trim(text)]);
    return true;
  end);

  gui.bind(h, "list", lambda args : begin
    return sqliteQuery(db, "SELECT id, text, done FROM todos ORDER BY id DESC");
  end);

  gui.bind(h, "toggle", lambda args : begin
    var id := toInteger(args[0]);
    sqliteExec(db, "UPDATE todos SET done = 1 - done WHERE id = ?", [id]);
    return true;
  end);

  gui.bind(h, "remove", lambda args : begin
    var id := toInteger(args[0]);
    sqliteExec(db, "DELETE FROM todos WHERE id = ?", [id]);
    return true;
  end);

  gui.serve(h,
    '<!DOCTYPE html>' +
    '<html><head><title>Pascak Todo</title><style>' +
    'body{font-family:sans-serif;max-width:600px;margin:40px auto;padding:0 20px;}' +
    'h1{color:#333;}' +
    '.row{display:flex;gap:8px;margin-bottom:16px;}' +
    '#inp{flex:1;padding:10px;font-size:16px;border:1px solid #ccc;border-radius:4px;}' +
    'button{padding:10px 20px;font-size:16px;cursor:pointer;border:0;border-radius:4px;background:#2a8;color:#fff;}' +
    'button:hover{background:#287;}' +
    'ul{list-style:none;padding:0;}' +
    'li{display:flex;align-items:center;gap:10px;padding:10px;border:1px solid #eee;border-radius:4px;margin-bottom:6px;}' +
    'li.done{opacity:0.5;text-decoration:line-through;}' +
    'li span{flex:1;}' +
    'li button{padding:4px 10px;font-size:12px;}' +
    '.del{background:#c33;}.del:hover{background:#a22;}' +
    '</style></head><body>' +
    '<h1>Pascak Todo</h1>' +
    '<div class="row"><input id="inp" placeholder="What needs doing?" onkeypress="if(event.key===\'Enter\')add()"/>' +
    '<button onclick="add()">Add</button></div>' +
    '<ul id="list"></ul>' +
    '<script>' +
    'async function add(){' +
    '  var i=document.getElementById("inp");' +
    '  var v=i.value.trim(); if(!v)return;' +
    '  await window.pascak.call("add",[v]); i.value=""; refresh();' +
    '}' +
    'async function toggle(id){' +
    '  await window.pascak.call("toggle",[id]); refresh();' +
    '}' +
    'async function del(id){' +
    '  await window.pascak.call("remove",[id]); refresh();' +
    '}' +
    'async function refresh(){' +
    '  var items = await window.pascak.call("list",[]);' +
    '  var ul = document.getElementById("list");' +
    '  ul.innerHTML = "";' +
    '  for(var it of items){' +
    '    var li = document.createElement("li");' +
    '    if(it.done)li.className="done";' +
    '    li.innerHTML = "<input type=checkbox "+(it.done?"checked":"")+" onchange=\'toggle("+it.id+")\'/>" +' +
    '                   "<span>"+escape(it.text)+"</span>"+' +
    '                   "<button class=del onclick=\'del("+it.id+")\'>x</button>";' +
    '    ul.appendChild(li);' +
    '  }' +
    '}' +
    'function escape(s){var d=document.createElement("div");d.textContent=s;return d.innerHTML;}' +
    'refresh();' +
    '</script></body></html>');

  var r := gui.start(h);
  if not r then begin
    println("gui.start failed");
    sqliteClose(db);
    gui.close(h);
    sys.exit(1);
  end;

  println("Todo GUI: http://localhost:18310/");
  if not gui.open(h) then
    println("  open browser manually");

  setTimeout(lambda : begin
    println("Closing (10 min timeout)");
    gui.close(h);
    sqliteClose(db);
    sys.exit(0);
  end, 600000);

  gui.run(h);
end.
