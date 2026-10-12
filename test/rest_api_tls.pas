// ============================================================
// REST API Async Server — http.listenAsync
//
// Sama dengan rest_api.pas tapi handler dieksekusi di worker
// pool (async), bukan di main thread (blocking).
//
// Test: 8 request paralel harus selesai lebih cepat
// ============================================================

var DB := 0;

function jsonResponse(status, data) begin
  return {
    "status": status,
    "headers": {"Content-Type": "application/json"},
    "body": jsonStringify(data)
  };
end;

function errorResponse(status, msg) begin
  return jsonResponse(status, {"ok": false, "error": msg});
end;

function initDb() begin
  DB := sqliteConnect("rest_api_async.db");
  sqliteExec(DB, "CREATE TABLE IF NOT EXISTS users (" +
                 "id INTEGER PRIMARY KEY AUTOINCREMENT, " +
                 "name TEXT NOT NULL, email TEXT, age INTEGER)");
end;

function listUsers() begin
  var rows := sqliteQuery(DB,
    "SELECT id, name, email, age FROM users ORDER BY id");
  return jsonResponse(200, {"ok": true, "count": len(rows), "users": rows});
end;

function createUser(body) begin
  if body == "" then return errorResponse(400, "Empty body");
  var data := jsonParse(body);
  if data == null then return errorResponse(400, "Invalid JSON");
  if not data.hasKey("name") then return errorResponse(400, "Missing name");

  var name := data["name"];
  var email := null;
  var age := null;
  if data.hasKey("email") then email := data["email"];
  if data.hasKey("age") then age := data["age"];

  sqliteExec(DB, "INSERT INTO users (name, email, age) VALUES (?, ?, ?)",
             [name, email, age]);
  return jsonResponse(201, {"ok": true});
end;

function slowHandler() begin
  sleep(100);
  return jsonResponse(200, {"ok": true, "message": "slow response"});
end;

function handler(req) begin
  var reqMethod := req["method"];
  var path := req["path"];
  var body := req["body"];

  if path == "/health" then
    return jsonResponse(200, {"ok": true, "status": "healthy"});

  if path == "/slow" then
    return slowHandler();

  if path == "/users" then
  begin
    if reqMethod == "GET" then return listUsers();
    if reqMethod == "POST" then return createUser(body);
    return errorResponse(405, "Method not allowed");
  end

  return errorResponse(404, "Not found: " + path);
end;

begin
  println("=== REST API Async Server ===");
  initDb();

  var home := sys.env("HOME");
  var certPath := home + "/server.crt";
  var keyPath  := home + "/server.key";
  
  var srv := http.serveTLS(8443, certPath, keyPath, handler);
  if srv < 0 then begin
    println("Failed to start");
    return;
  end

  println("Server on https://localhost:8443 (TLS, async, worker pool)");
  println("Endpoints:");
  println("  GET  /health");
  println("  GET  /users");
  println("  POST /users");
  println("  GET  /slow          ← sleep 100ms untuk test concurrency");
  println("");
  println("Press Ctrl+C to stop.");

  var n := http.listenAsync(srv);
  println("Server stopped. Total dispatched: ", n);
  sqliteClose(DB);
end.