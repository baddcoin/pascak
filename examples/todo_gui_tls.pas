// examples/todo_gui_tls.pas — Todo app dengan HTTPS + WSS
//
// Prereq:
//   openssl req -x509 -newkey rsa:2048 \
//     -keyout ~/server.key -out ~/server.crt \
//     -days 365 -nodes -subj "/CN=localhost" \
//     -addext "subjectAltName=DNS:localhost,IP:127.0.0.1"
//
// Run:
//   PASCAK_EXEC_POLICY=allow-all ./pascak_noASTnet --dev examples/todo_gui_tls.pas
//
// Test:
//   curl -k https://localhost:8090/    (expect HTML with wss://)

var DB := -1;

function listTodos() begin
  return sqliteQuery(DB, "SELECT id, text, done FROM todos ORDER BY id DESC")
end;

function addTodo(text) begin
  sqliteExec(DB, "INSERT INTO todos (text, done) VALUES (?, 0)", [text]);
  return listTodos()
end;

function toggleTodo(id) begin
  sqliteExec(DB, "UPDATE todos SET done = 1 - done WHERE id = ?", [id]);
  return listTodos()
end;

function deleteTodo(id) begin
  sqliteExec(DB, "DELETE FROM todos WHERE id = ?", [id]);
  return listTodos()
end;

begin
  sys.execWhitelist(["termux-open-url", "xdg-open"]);

  DB := sqliteConnect("todos_tls.db");
  sqliteExec(DB, "CREATE TABLE IF NOT EXISTS todos (" +
                 "id INTEGER PRIMARY KEY AUTOINCREMENT, " +
                 "text TEXT NOT NULL, done INTEGER DEFAULT 0)");

  var home := sys.env("HOME");
  var cert := home + "/server.crt";
  var key := home + "/server.key";

  if not fileExists(cert) or not fileExists(key) then begin
    println("Cert missing — run:");
    println("  openssl req -x509 -newkey rsa:2048 \\");
    println("    -keyout ~/server.key -out ~/server.crt \\");
    println("    -days 365 -nodes -subj '/CN=localhost' \\");
    println("    -addext 'subjectAltName=DNS:localhost,IP:127.0.0.1'");
    sys.exit(1);
  end;

  var h := gui.createTLS(8090, cert, key, 8091, "Todo TLS");
  if h < 0 then begin
    println("createTLS failed");
    sys.exit(1);
  end;

  gui.bind(h, "list",   lambda args : listTodos());
  gui.bind(h, "add",    lambda args : addTodo(args[0]));
  gui.bind(h, "toggle", lambda args : toggleTodo(args[0]));
  gui.bind(h, "remove", lambda args : deleteTodo(args[0]));

  gui.serve(h, "<html><body style='font-family:sans-serif;max-width:600px;margin:40px auto;padding:20px'>" +
    "<h1>Todo (TLS)</h1>" +
    "<p style='color:#666'>HTTPS :8090 + WSS :8091</p>" +
    "<input id='n' placeholder='What to do?' style='width:70%;padding:8px'>" +
    "<button onclick='add()'>Add</button>" +
    "<ul id='list' style='list-style:none;padding:0'></ul>" +
    "<script>" +
    "async function render(todos){" +
    "  var ul=document.getElementById('list'); ul.innerHTML='';" +
    "  for(var t of todos){" +
    "    var li=document.createElement('li');" +
    "    li.style.cssText='padding:10px;border-bottom:1px solid #eee;display:flex;justify-content:space-between;" +
    "      '+(t.done?'text-decoration:line-through;color:#999':'');" +
    "    li.innerHTML='<span onclick=\\'tog('+t.id+')\\' style=\\'cursor:pointer;flex:1\\'>'+t.text+'</span>'+ " +
    "      '<button onclick=\\'del('+t.id+')\\'>X</button>';" +
    "    ul.appendChild(li);" +
    "  }" +
    "}" +
    "async function refresh(){ render(await window.pascak.call('list', [])); }" +
    "async function add(){" +
    "  var i=document.getElementById('n');" +
    "  if(!i.value) return;" +
    "  await window.pascak.call('add',[i.value]); i.value=''; refresh();" +
    "}" +
    "async function tog(id){ await window.pascak.call('toggle',[id]); refresh(); }" +
    "async function del(id){ await window.pascak.call('remove',[id]); refresh(); }" +
    "refresh();" +
    "</script></body></html>");

  if not gui.start(h) then begin
    println("gui.start failed");
    sys.exit(1);
  end;

  println("HTTPS: https://localhost:8090/");
  println("WSS:   wss://localhost:8091/");
  println("Note: browser will show cert warning — click Advanced > Proceed");

  gui.open(h);

  onShutdown(lambda : begin
    println("closing db");
    sqliteClose(DB);
  end);

  gui.run(h);
end.
