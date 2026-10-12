// ============================================================
// REST API Server Example
//
// Integrasi end-to-end:
//   HTTP server (sync) + SQLite storage + JSON API
//
// Endpoints:
//   GET    /health          — health check
//   GET    /users           — list all users
//   POST   /users           — create user (JSON body)
//   GET    /users/:id       — single user
//   DELETE /users/:id       — delete user
//
// Test dengan curl. Lihat komentar di akhir file.
// ============================================================

// Global database handle — accessible dari semua handler
var DB := 0;

// ============================================================
// Helper: JSON response builders
// ============================================================

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

// ============================================================
// Database setup
// ============================================================

function initDb() begin
  DB := sqliteConnect("rest_api.db");
  sqliteExec(DB, "CREATE TABLE IF NOT EXISTS users (" +
                 "id INTEGER PRIMARY KEY AUTOINCREMENT, " +
                 "name TEXT NOT NULL, " +
                 "email TEXT UNIQUE, " +
                 "age INTEGER)");
end;

// ============================================================
// Business logic
// ============================================================

function listUsers() begin
  var rows := sqliteQuery(DB,
    "SELECT id, name, email, age FROM users ORDER BY id");
  return jsonResponse(200, {
    "ok": true,
    "count": len(rows),
    "users": rows
  });
end;

function getUser(id) begin
  var rows := sqliteQuery(DB,
    "SELECT id, name, email, age FROM users WHERE id = ?", [id]);
  
  if len(rows) == 0 then
    return errorResponse(404, "User not found");
  
  return jsonResponse(200, {"ok": true, "user": rows[0]});
end;

function createUser(body) begin
  if body == "" then
    return errorResponse(400, "Empty request body");
  
  var data := jsonParse(body);
  if data == null then
    return errorResponse(400, "Invalid JSON");
  
  if not data.hasKey("name") then
    return errorResponse(400, "Missing required field: name");
  
  var name := data["name"];
  var email := null;
  var age := null;
  
  if data.hasKey("email") then email := data["email"];
  if data.hasKey("age") then age := data["age"];
  
  try
    sqliteExec(DB,
      "INSERT INTO users (name, email, age) VALUES (?, ?, ?)",
      [name, email, age]);
  catch e do
    return errorResponse(500, "Insert failed: " + e.message);
  end
  
  return jsonResponse(201, {"ok": true, "message": "User created"});
end;

function deleteUser(id) begin
  // Cek dulu user ada
  var rows := sqliteQuery(DB,
    "SELECT id FROM users WHERE id = ?", [id]);
  
  if len(rows) == 0 then
    return errorResponse(404, "User not found");
  
  sqliteExec(DB, "DELETE FROM users WHERE id = ?", [id]);
  return jsonResponse(200, {"ok": true, "message": "User deleted"});
end;

// ============================================================
// Path parsing
// ============================================================

// Extract id dari "/users/123" → 123
function extractIdFromPath(path) begin
  var parts := path.split("/");
  // ["", "users", "123"] untuk "/users/123"
  if len(parts) < 3 then return "";
  return parts[len(parts) - 1];
end;

// ============================================================
// Router
// ============================================================
function handler(req) begin
  var reqMethod := req["method"];
  var path := req["path"];
  var body := req["body"];
  
  // Health check
  if path == "/health" then
    return jsonResponse(200, {"ok": true, "status": "healthy"});
  
  // /users (list + create)
  if path == "/users" then
  begin
    if reqMethod == "GET" then return listUsers();
    if reqMethod == "POST" then return createUser(body);
    return errorResponse(405, "Method not allowed: " + reqMethod);
  end
  
  // /users/:id (get + delete)
  if path.startsWith("/users/") then
  begin
    var idStr := extractIdFromPath(path);
    var id := toInteger(idStr);
    
    if id <= 0 then
      return errorResponse(400, "Invalid user ID: " + idStr);
    
    if reqMethod == "GET" then return getUser(id);
    if reqMethod == "DELETE" then return deleteUser(id);
    return errorResponse(405, "Method not allowed: " + reqMethod);
  end
  
  // 404 fallback
  return errorResponse(404, "Not found: " + path);
end;

// ============================================================
// Main
// ============================================================

begin
  println("=== REST API Server ===");
  println("");
  
  initDb();
  println("SQLite opened: rest_api.db");
  
  var server := http.serve(8080, handler);
  if server < 0 then begin
    println("Failed to start server");
    return;
  end
  
  println("Server listening on http://localhost:8080");
  println("");
  println("Endpoints:");
  println("  GET    /health");
  println("  GET    /users");
  println("  POST   /users          (JSON body)");
  println("  GET    /users/:id");
  println("  DELETE /users/:id");
  println("");
  println("Press Ctrl+C to stop.");
  
  var served := http.listen(server);
  println("Server stopped. Total requests: ", served);
  
  sqliteClose(DB);
end.