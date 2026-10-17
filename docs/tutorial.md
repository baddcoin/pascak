# Pascak Tutorial — Dari Hello World ke REST API

Panduan langkah demi langkah untuk mempelajari Pascak VM.
Setiap bab punya contoh kode yang bisa langsung dijalankan.

**Prasyarat**: `pascak_noASTnet` sudah di-compile, working directory
di folder project.

```markdown
## Daftar Bab

1. [Setup & Hello World](#1-setup--hello-world)
2. [Variabel & Tipe Dasar](#2-variabel--tipe-dasar)
3. [Control Flow](#3-control-flow)
4. [Fungsi & Lambda](#4-fungsi--lambda)
5. [Array & Dict](#5-array--dict)
6. [String & F-String](#6-string--f-string)
7. [Error Handling](#7-error-handling)
8. [File I/O](#8-file-io)
9. [JSON](#9-json)
10. [FFI — Panggilan Native Pertama](#10-ffi--panggilan-native-pertama)
11. [FFI — Callback](#11-ffi--callback)
12. [FFI — Struct](#12-ffi--struct)
13. [HTTP Client](#13-http-client)
14. [HTTP Server](#14-http-server)
15. [HTTPS Server](#15-https-server)
16. [SQLite](#16-sqlite)
17. [Async](#17-async)
18. [REST API — Capstone](#18-rest-api--capstone)
19. [WebSocket Server](#19-websocket-server)
20. [WebSocket Lanjutan](#20-websocket-lanjutan)
21. [WebSocket TLS Event Mode](#21-websocket-tls-event-mode)
22. [Security: Exec Policy](#22-security-exec-policy)
23. [Async File I/O](#23-async-file-io)
24. [Parser Quirk](#24-parser-quirk)
25. [Timer & JSON Path](#25-timer--json-path)
```

## 1. Setup & Hello World

Buat file `hello.pas`:

```pascal
begin
  println("Hello, Pascak!");
end.
```

Jalankan:

```bash
./pascak_noASTnet hello.pas
```

Output:
```
Hello, Pascak!
```

**Struktur script**: dimulai dengan `begin`, diakhiri `end.` (dengan titik).
Setiap statement diakhiri `;` (kecuali yang terakhir sebelum `end`).

---

## 2. Variabel & Tipe Dasar

```pascal
begin
  var nama := "Alice";         // string
  var umur := 30;               // numeric
  var aktif := true;            // boolean
  var alamat := null;           // null

  println(nama);
  println(umur);
  println(aktif);
  println(alamat);

  // Reassignment
  umur := 31;
  println("Umur baru: ", umur);

  // Konstanta
  const MAX := 100;
  println("Max: ", MAX);
  // MAX := 200;   // ✗ Error — tidak bisa ubah konstanta
end.
```

**Tipe data**: string, numeric (double), boolean, null, array, dict,
object, function, native function, class, pointer, dll.

**Konversi**:

```pascal
var s := "123";
var n := toInteger(s);    // 123
var f := toFloat("3.14"); // 3.14
var str := toString(42);  // "42"
println(typeOf(n));       // "numeric"
```

---

## 3. Control Flow

### If / Else

```pascal
var x := 10;

if x > 5 then
  println("besar")
else
  println("kecil");

// Dengan blok
if x > 100 then begin
  println("sangat besar");
  println("nilai: ", x);
end else if x > 10 then begin
  println("besar");
end else begin
  println("sedang atau kecil");
end;
```

**Catatan**: `elif` **bukan keyword**. Gunakan sequential `if` atau
nested `if` di dalam `else`.

### While

```pascal
var i := 0;
while i < 5 do
begin
  println("i = ", i);
  i := i + 1;
end;
```

### Repeat..Until

```pascal
var n := 1;
repeat
  println("n = ", n);
  n := n * 2;
until n > 100;
```

### For (numeric)

```pascal
for i := 1 to 5 do
  println("i = ", i);

// Dengan step
for i := 0 to 10 step 2 do
  println("genap: ", i);

// Downto
for i := 5 downto 1 do
  println("countdown: ", i);
```

### For..in

```pascal
var arr := [10, 20, 30];
for x in arr do
  println(x);

var dict := {"a": 1, "b": 2};
for key in dict do
  println(key, " = ", dict[key]);
```

### Case

```pascal
var kode := 2;
case kode of
  1: println("satu");
  2: println("dua");
  3: println("tiga");
else
  println("lainnya");
end;
```

### Ternary

```pascal
var status := x > 5 ? "besar" : "kecil";
```

---

## 4. Fungsi & Lambda

### Fungsi Bernama

```pascal
function tambah(a, b) begin
  return a + b
end;

function sapa(nama) begin
  return "Halo, " + nama + "!"
end;

begin
  println(tambah(3, 4));     // 7
  println(sapa("Alice"));    // Halo, Alice!
end.
```

### Lambda

```pascal
// Lambda ekspresi (satu baris)
var kuadrat := lambda x : x * x;
println(kuadrat(5));   // 25

// Lambda dengan parameter ganda
var max := lambda a, b : a > b ? a : b;
println(max(10, 20));  // 20

// Lambda dengan blok
var greet := lambda nama : begin
  if nama == "" then
    return "Halo, dunia!"
  else
    return "Halo, " + nama + "!"
end;

println(greet("Bob"));
```

**Aturan penting**: `if..then..else` adalah **statement**, bukan expression.
Untuk conditional di lambda body, gunakan **ternary `?:`** atau
**block body** (`lambda : begin ... end`).

---

## 5. Array & Dict

### Array

```pascal
var arr := [1, 2, 3, 4, 5];

println(len(arr));         // 5
println(arr[0]);           // 1
println(arr[-1]);          // 5 (negative index dari belakang)

// Mutasi
arr[0] := 100;
println(arr[0]);           // 100

// Push & pop
push(arr, 6);
println(arr);              // [100, 2, 3, 4, 5, 6]
var last := pop(arr);
println(last);             // 6

// Slicing
var sub := arr[1:4];       // [2, 3, 4]
var reversed := arr[::-1]; // reverse

// Higher-order methods
var dobel := arr.map(lambda x : x * 2);
println(dobel);            // [200, 4, 6, 8, 10]

var genap := arr.filter(lambda x : x % 2 == 0);
println(genap);

var total := arr.reduce(lambda acc, x : acc + x, 0);
println(total);

// Sort dengan comparator
var arr2 := [3, 1, 4, 1, 5, 9, 2, 6];
arr2.sort(lambda a, b : a - b);   // ascending
println(arr2);                     // [1, 1, 2, 3, 4, 5, 6, 9]
```

### Dict

```pascal
var user := {"nama": "Alice", "umur": 30};

println(user["nama"]);       // Alice (indexing)
println(user.nama);           // Alice (dot, kalau bukan keyword)
println(user.hasKey("email")); // false

user["email"] := "alice@example.com";
user.umur := 31;

println(user.keys());         // ["nama", "umur", "email"]
println(user.values());

// Iterasi
for k in user.keys() do
  println(k, ": ", user[k]);

// Hapus
delete(user, "email");
```

**Peringatan keyword**: field dengan nama keyword (`method`, `in`,
`class`, `if`, dll) **wajib** diakses via indexing `user["method"]`.

---

## 6. String & F-String

```pascal
var nama := "Pascak";
var versi := 3;

// Concatenation
println("Hello, " + nama + " v" + str(versi));

// F-string
println(f"Hello, {nama} v{versi}!");
println(f"2 + 2 = {2 + 2}");
println(f"Nama panjang: {upper(nama)}");

// Manipulasi
println(upper("halo"));      // HALO
println(lower("HALO"));      // halo
println(trim("  spasi  "));  // spasi
println(copy("abcdef", 1, 3)); // bcd (0-based)
println(pos("cd", "abcdef")); // 2 (0-based)
println(len("hello"));       // 5 (UTF-8 aware)

// Split & join
var parts := "a,b,c".split(",");
println(parts);               // ["a", "b", "c"]
var joined := parts.join("-");
println(joined);              // "a-b-c"

// Replace
println("hello world".replace("world", "Pascak")); // "hello Pascak"

// Starts/ends with
println("hello".startsWith("he"));  // true
println("hello".endsWith("lo"));    // true
```

---

## 7. Error Handling

```pascal
function bagi(a, b) begin
  if b == 0 then
    throw("Pembagian oleh nol!");
  return a / b
end;

begin
  // Catch wildcard
  try
    var hasil := bagi(10, 0);
    println(hasil);
  catch e do
    println("Error: ", e);
  end;

  // Catch dengan filter tipe
  try
    throw(new ErrorClass("pesan"));
  catch e: ErrorClass do
    println("Error class: ", e.message);
  catch e do
    println("Error lain: ", e);
  end;

  // Finally
  try
    println("coba");
  finally
    println("selalu dieksekusi");
  end;
end.
```

---

## 8. File I/O

```pascal
begin
  // Write
  fileWrite("output.txt", "Hello, file!");

  // Read
  var content := fileRead("output.txt");
  println(content);

  // Append
  fileAppend("output.txt", "\nBaris kedua");

  // Cek
  if fileExists("output.txt") then
    println("File ada");

  // Hapus
  // fileDelete("output.txt");

  // Listing
  var files := getFiles(".");
  for f in files do
    println(f);

  // Direktori
  makeDir("subfolder");
  var dirs := getDirs(".");
  for d in dirs do
    println("dir: ", d);
end.
```

**Sandbox**: file I/O hanya di dalam direktori script dan
subdirektori. Tidak bisa akses path absolut.

---

## 9. JSON

```pascal
begin
  // Buat dict
  var data := {
    "nama": "Alice",
    "umur": 30,
    "hobi": ["baca", "coding", "hiking"],
    "alamat": {
      "kota": "Jakarta",
      "kode": "12345"
    }
  };

  // Serialize ke JSON string
  var jsonStr := jsonStringify(data);
  println(jsonStr);

  // Parse JSON string
  var parsed := jsonParse(jsonStr);
  println(parsed.nama);         // Alice
  println(parsed.hobi[0]);      // baca
  println(parsed.alamat.kota);  // Jakarta

  // Write ke file
  fileWriteRecord("data.json", data);

  // Read dari file
  var loaded := fileReadRecord("data.json");
  println(loaded.nama);
end.
```

**Catatan**: integer dirender sebagai number (`30`), bukan float
(`3.0E+001`). Field keyword perlu indexing.

---

## 10. FFI — Panggilan Native Pertama

Panggil fungsi dari shared library C.

```pascal
begin
  // Load library (nama bare — dicari oleh linker)
  var lib := dll.load("libm.so.6");

  // Ambil fungsi: double sqrt(double)
  var sqrtFn := lib.func("sqrt", "f->f");

  println(sqrtFn(2.0));      // 1.414...
  println(sqrtFn(16.0));     // 4.0

  lib.close();
end.
```

**Signature syntax**: `<args>-><return>`

| Huruf | C Type |
|---|---|
| `i` | `int64_t` |
| `f` | `double` |
| `s` | `char*` (string) |
| `p` | `void*` (pointer) |
| `v` | `void` (hanya untuk return) |

**Contoh signature**:
- `i->i` — `int64(int64)`
- `ii->i` — `int64(int64, int64)`
- `s->i` — `int64(const char*)` (seperti `strlen`)
- `ff->f` — `double(double, double)`

### Contoh dengan library test kita

```pascal
begin
  var lib := dll.load("libpascak_ffi_test.so");

  var strlenFn := lib.func("pascak_strlen", "s->i");
  println(strlenFn("hello"));   // 5

  var add4 := lib.func("pascak_add4", "iiii->i");
  println(add4(1, 2, 3, 4));    // 10

  lib.close();
end.
```

---

## 11. FFI — Callback

Kirim fungsi script ke library C sebagai callback.

```pascal
// Comparator ascending
function cmpAsc(a, b) begin
  if a < b then return -1;
  if a > b then return 1;
  return 0
end;

begin
  var lib := dll.load("libpascak_ffi_test.so");
  var qsortFn := lib.func("pascak_qsort_ints", "pip->v");

  // Array angka
  var arr := [42, 17, 93, 8, 56, 3];
  var buf := native.fromArray(arr);

  // Bungkus fungsi script sebagai callback C
  var cmp := dll.callback("ii->i", cmpAsc);

  // Panggil qsort
  qsortFn(native.bufferPtr(buf), native.bufferSize(buf), cmp);

  // Baca hasil
  var sorted := native.bufferToArray(buf);
  println(sorted);   // [3, 8, 17, 42, 56, 93]

  // Cleanup
  dll.freeCallback(cmp);
  native.bufferFree(buf);
  lib.close();
end.
```

**Native buffer** — untuk kirim array ke C:
- `native.fromArray(arr)` — array → buffer
- `native.bufferPtr(buf)` — pointer ke data
- `native.bufferSize(buf)` — jumlah elemen
- `native.bufferToArray(buf)` — buffer → array
- `native.bufferFree(buf)` — free

---

## 12. FFI — Struct

Kirim struct by value ke fungsi C.

```pascal
begin
  // 1. Deklarasi struct
  var PointType := native.structType("Point", [
    ["x", "i32"],
    ["y", "i32"]
  ]);

  // 2. Load library
  var lib := dll.load("libpascak_ffi_test.so");

  // 3. Ambil fungsi — S = struct
  //    "Sii->S" = Point(Point, int64, int64)
  var translate := lib.func("point_translate", "Sii->S",
    [PointType, PointType]);

  // 4. Buat instance struct
  var p := native.newStruct(PointType);
  native.structSet(p, "x", 10);
  native.structSet(p, "y", 20);

  // 5. Panggil
  var r := translate(p, 5, 7);
  println("Hasil: (", native.structGet(r, "x"), ", ",
                     native.structGet(r, "y"), ")");
  // Hasil: (15, 27)

  // 6. Cleanup
  native.structFree(p);
  native.structFree(r);
  native.structTypeFree(PointType);
  lib.close();
end.
```

**Field kinds**: `i8`, `i16`, `i32`, `i64`, `f32`, `f64`, `ptr`, `bool`.

**Alignment**: struct di-align sesuai aturan POSIX C.

---

## 13. HTTP Client

```pascal
begin
  // GET
  var res := http.get("https://example.com");
  println("Status: ", res.status);          // 200
  println("Body length: ", len(res.body));
  println("Content-Type: ", res.headers["Content-Type"]);

  // POST
  var post := http.post("https://httpbin.org/post",
    {"Content-Type": "application/json"},
    '{"name": "Alice"}');
  println(post.status);

  // Request dengan header custom
  var custom := http.get("https://httpbin.org/headers", {
    "X-Custom": "value",
    "User-Agent": "Pascak/1.0"
  });
  println(custom.body);

  // Error handling
  try
    var bad := http.get("https://nonexistent-xyz.com");
  catch e do
    println("Gagal: ", e.message);
  end;
end.
```

**TLS verify aktif secara default** — chain + hostname.
Override via `PASCAK_TLS_NO_VERIFY=1` untuk dev.

---

## 14. HTTP Server

```pascal
function handler(req) begin
  var method := req["method"];   // keyword — pakai indexing
  var path := req["path"];
  var body := req["body"];

  if path == "/" then
    return {
      "status": 200,
      "headers": {"Content-Type": "text/html"},
      "body": "<h1>Hello!</h1>"
    };

  if path == "/api/info" then
    return {
      "status": 200,
      "headers": {"Content-Type": "application/json"},
      "body": jsonStringify({"time": time.now(), "version": "1.0"})
    };

  if path == "/echo" and method == "POST" then
    return {
      "status": 200,
      "body": "You sent: " + body
    };

  return {
    "status": 404,
    "body": "Not Found: " + path
  };
end;

begin
  println("Server di http://localhost:8080");
  var srv := http.serve(8080, handler);
  http.listen(srv);   // blocking
end.
```

Test dengan `curl`:

```bash
curl http://localhost:8080/
curl http://localhost:8080/api/info
curl -X POST -d "hello" http://localhost:8080/echo
```

---

```markdown
## 15. HTTPS Server

Setelah bisa bikin HTTP server, langkah selanjutnya adalah HTTPS. Pascak punya `http.serveTLS` untuk server dengan cert + key.

### Generate Cert (Development)

```bash
cd ~
openssl req -x509 -newkey rsa:2048 \
    -keyout server.key -out server.crt \
    -days 365 -nodes -subj "/CN=localhost"
```

Menghasilkan server.crt (public) dan server.key (private, jangan commit).

Server HTTPS

```pascal
function handler(req) begin
  var path := req["path"];

  if path == "/" then
    return {
      "status": 200,
      "headers": {"Content-Type": "text/html"},
      "body": "<h1>HTTPS Server</h1>"
    };

  return {"status": 404, "body": "Not Found"};
end;

begin
  var home := sys.env("HOME");
  var srv := http.serveTLS(8443,
    home + "/server.crt",
    home + "/server.key",
    handler);

  if srv < 0 then begin
    println("Failed to start server");
    return;
  end

  println("HTTPS server on https://localhost:8443");
  http.listenAsync(srv);
end.
```

Test dengan curl

```bash
curl -sk https://localhost:8443/
```

Async HTTPS

```pascal
http.listenAsync(srv);   // worker pool, 8 concurrent
```

Verify TLS Version

```bash
curl -skv https://localhost:8443/ 2>&1 | grep "SSL connection"
```

Output:

```
SSL connection using TLSv1.3 / TLS_AES_256_GCM_SHA384
```

Production Cert

```bash
certbot certonly --standalone -d example.com
```

```pascal
var srv := http.serveTLS(443,
  "/etc/letsencrypt/live/example.com/fullchain.pem",
  "/etc/letsencrypt/live/example.com/privkey.pem",
  handler);
```

Contoh Lengkap

Lihat examples/rest_api_tls.pas.

```


## 16. SQLite

```pascal
begin
  // Buka / buat database
  var db := sqliteConnect("myapp.db");

  // Buat tabel
  sqliteExec(db, "CREATE TABLE IF NOT EXISTS users (" +
                 "id INTEGER PRIMARY KEY AUTOINCREMENT, " +
                 "name TEXT NOT NULL, " +
                 "email TEXT, age INTEGER)");

  // Insert dengan parameter (positional `?`)
  sqliteExec(db, "INSERT INTO users (name, email, age) VALUES (?, ?, ?)",
             ["Alice", "alice@example.com", 30]);
  sqliteExec(db, "INSERT INTO users (name, email, age) VALUES (?, ?, ?)",
             ["Bob", "bob@example.com", 25]);

  // Query
  var rows := sqliteQuery(db,
    "SELECT id, name, email, age FROM users ORDER BY age");
  for r in rows do
    println(r.id, ". ", r.name, " (", r.age, ") — ", r.email);

  // Query dengan filter
  var young := sqliteQuery(db,
    "SELECT * FROM users WHERE age < ?", [28]);
  println("Young users: ", len(young));

  // Delete
  sqliteExec(db, "DELETE FROM users WHERE id = ?", [1]);

  sqliteClose(db);
end.
```

**Termux quirk**: DB harus di `$HOME` (Termux private dir), bukan
di shared storage (`/storage/emulated/0/`). Shared storage read-only
untuk journal file SQLite.

---

## 17. Async

Request HTTPS paralel tanpa blocking.

```pascal
var counter := 0;
var totalSize := 0;

function onResult(res) begin
  counter := counter + 1;

  if res.hasKey("error") then
    println("[", counter, "] GAGAL: ", res.error)
  else begin
    totalSize := totalSize + len(res.body);
    println("[", counter, "] ", res.status, " — ", len(res.body), " bytes");
  end
end;

begin
  println("Fetch 4 URL paralel...");

  http.getAsync("https://example.com", onResult);
  http.getAsync("https://httpbin.org/get", onResult);
  http.getAsync("https://example.org", onResult);
  http.getAsync("https://1.1.1.1", onResult);

  // Script selesai — event loop tunggu callback
end.
```

**Batasan**: max 8 concurrent (worker pool size).
Callback jalan di main thread — jangan blocking lama.

---

## 18. REST API — Capstone

Gabungan semua — HTTP server + SQLite + JSON.

Lihat `examples/rest_api.pas` untuk versi lengkap. Ringkasan:

```pascal
var DB := 0;

function jsonResponse(status, data) begin
  return {
    "status": status,
    "headers": {"Content-Type": "application/json"},
    "body": jsonStringify(data)
  };
end;

function initDb() begin
  DB := sqliteConnect("app.db");
  sqliteExec(DB, "CREATE TABLE IF NOT EXISTS items (" +
                 "id INTEGER PRIMARY KEY AUTOINCREMENT, " +
                 "name TEXT, price REAL)");
end;

function listItems() begin
  var rows := sqliteQuery(DB, "SELECT * FROM items");
  return jsonResponse(200, {"ok": true, "items": rows});
end;

function createItem(body) begin
  var data := jsonParse(body);
  if data == null then
    return jsonResponse(400, {"ok": false, "error": "Invalid JSON"});

  sqliteExec(DB, "INSERT INTO items (name, price) VALUES (?, ?)",
             [data["name"], data["price"]]);

  return jsonResponse(201, {"ok": true});
end;

function handler(req) begin
  var reqMethod := req["method"];
  var path := req["path"];
  var body := req["body"];

  if path == "/items" then begin
    if reqMethod == "GET" then return listItems();
    if reqMethod == "POST" then return createItem(body);
  end;

  return jsonResponse(404, {"ok": false, "error": "Not found"});
end;

begin
  initDb();
  println("REST API on :8080");
  var srv := http.serve(8080, handler);
  http.listen(srv);
  sqliteClose(DB);
end.
```

Test:

```bash
curl -X POST -H "Content-Type: application/json" \
  -d '{"name":"Widget","price":9.99}' \
  http://localhost:8080/items

curl http://localhost:8080/items
```

```markdown
## Bab 19 — WebSocket Server

WebSocket memungkinkan komunikasi **bidirectional real-time** — server bisa push data ke client tanpa client harus polling. Ini fundamental untuk chat, live dashboard, game multiplayer, dan notifikasi real-time.

### 19.1 — Echo Server Minimal

```pascal
function onMessage(conn, msg) begin
  conn.send("echo: " + msg);
end;

begin
  var srv := ws.serve(9001, {"onMessage": onMessage});
  println("listening on 9001...");
  ws.listen(srv);
end.
```

Test dengan Python:

```bash
python3 -c "
import asyncio, websockets
async def main():
    async with websockets.connect('ws://localhost:9001') as ws:
        await ws.send('hello')
        print(await ws.recv())
asyncio.run(main())
"
```

Output client: echo: hello

19.2 — Handler Callback

Tiga callback utama:

```pascal
function onOpen(conn) begin
  println("client ", conn["id"], " dari ", conn["peerIP"], " connect");
end;

function onMessage(conn, msg) begin
  println("dari ", conn["id"], ": ", msg);
  conn.send("diterima!");
end;

function onClose(conn, code) begin
  println("client ", conn["id"], " close (code=", code, ")");
end;
```

Pass ke ws.serve sebagai dict:

```pascal
var srv := ws.serve(9001, {
  "onOpen":    onOpen,
  "onMessage": onMessage,
  "onClose":   onClose
});
```

19.3 — Menjalankan Server di Background

ws.listen blocking — thread utama tidak bisa lanjut kalau langsung dipanggil. Solusinya: jalankan di thread terpisah dengan thread():

```pascal
var SRV := -1;

function serverThread() begin
  ws.listen(SRV);
end;

begin
  SRV := ws.serve(9001, {...});
  thread(serverThread);
  
  // Main thread lanjut — bisa jalankan hal lain
  println("server jalan di background");
  
  // Tunggu forever (atau sampai Ctrl+C)
  while true do sleep(1000);
end.
```

19.4 — Chat Room dengan Broadcast

Contoh lengkap: setiap pesan dari satu client dipush ke semua client lain.

```pascal
var SRV := -1;

function onOpen(conn) begin
  ws.broadcast(SRV, "*** " + conn["id"] + " bergabung ***");
end;

function onMessage(conn, msg) begin
  ws.broadcast(SRV, conn["id"] + ": " + msg);
end;

function onClose(conn, code) begin
  ws.broadcast(SRV, "*** " + conn["id"] + " keluar ***");
end;

function serverThread() begin
  ws.listen(SRV);
end;

begin
  SRV := ws.serve(9002, {
    "onOpen":    onOpen,
    "onMessage": onMessage,
    "onClose":   onClose
  });
  thread(serverThread);
  
  println("chat room di ws://localhost:9002");
  while true do sleep(1000);
end.
```

Test dengan 3 terminal wscat:

```bash
wscat -c ws://localhost:9002   # Terminal 1
wscat -c ws://localhost:9002   # Terminal 2
wscat -c ws://localhost:9002   # Terminal 3
```

Ketik pesan di satu terminal — muncul di semua terminal.

19.5 — Command Handling

Pola umum: intercept pesan yang dimulai dengan / sebagai command, sebelum broadcast.

```pascal
function onMessage(conn, msg) begin
  if msg == "/whoami" then begin
    conn.send("id=" + conn["id"] + " peer=" + conn["peerIP"]);
    return;
  end;
  
  if msg == "/clients" then begin
    var list := ws.clients(SRV);
    conn.send("active: " + str(len(list)));
    return;
  end;
  
  if msg == "/quit" then begin
    conn.close(1000);
    return;
  end;
  
  // Default: broadcast
  ws.broadcast(SRV, conn["id"] + ": " + msg);
end;
```

19.6 — WebSocket Secure (wss://)

Untuk production, gunakan TLS. Sama seperti HTTP, butuh cert + key:

```bash
openssl req -x509 -newkey rsa:2048 \
    -keyout server.key -out server.crt \
    -days 365 -nodes -subj "/CN=localhost"
```

Server:

```pascal
begin
  var home := sys.env("HOME");
  var srv := ws.serveTLS(9443,
    home + "/server.crt",
    home + "/server.key",
    {"onMessage": onMessage});
  ws.listen(srv);
end.
```

Test:

```bash
wscat -c wss://localhost:9443 --no-check
```

--no-check skip cert verification (self-signed).

19.7 — Race Condition pada Counter

Callback dijalankan di worker thread. Kalau dua client kirim pesan bersamaan, COUNTER := COUNTER + 1 bisa race:

```
Thread A: baca COUNTER = 5
Thread B: baca COUNTER = 5     ← sama-sama baca 5
Thread A: tulis COUNTER = 6
Thread B: tulis COUNTER = 6    ← kehilangan 1 increment
```

Solusi: lock block.

```pascal
var COUNTER := 0;

function onMessage(conn, msg) begin
  lock begin
    COUNTER := COUNTER + 1;
  end;
  conn.send("msg #" + str(COUNTER));
end;
```

lock block mengakuisisi global script lock — semua thread lain yang mencoba lock akan queue.

19.8 — Graceful Shutdown

ws.stop(handle) memicu close frame 1001 Going Away ke semua client, lalu listen loop keluar.

```pascal
// Kirim stop signal (mis. dari timer atau route HTTP)
ws.stop(SRV);
```

Engine shutdown (Ctrl+C, sys.exit()) juga memicu stop otomatis.

19.9 — Fragmentasi dan Payload Besar

WebSocket frame punya batas ukuran di field length (max 2^63). Untuk payload besar, frame dipecah jadi beberapa bagian (fragmentasi):

```
Frame 1: FIN=0, opcode=text,      payload="Hello "
Frame 2: FIN=0, opcode=continuation, payload="world, "
Frame 3: FIN=1, opcode=continuation, payload="how are you?"
```

Engine otomatis mengakumulasi sampai FIN=1 sebelum memanggil onMessage. Anda tidak perlu handle ini manual. Batas total akumulasi = maxPayload (default 16 MB).

19.10 — Best Practices

Saran Alasan
Pakai lock untuk counter/state bersama Callback di worker thread
Gunakan try/catch di callback Exception di callback akan matikan connection
Set pingInterval untuk deteksi client mati Client di jaringan mobile bisa disconnect diam-diam
Pakai wss:// untuk production ws:// plain text — MITM bisa baca/modif
Broadcast jangan dari dalam onMessage kalau ragu Bisa rekursif — tapi aman karena broadcast tidak trigger onMessage
Limit maxPayload sesuai use case Cegah DoS dari client nakal

19.11 — Contoh di Repo

· examples/ws_echo.pas — echo server minimal
· examples/ws_chat.pas — chat room dengan command handling
· test/test_websocket.pas — E2E test dengan Python client
· test/test_websocket_unit.pas — protocol layer unit test (54 cases)

---

## Bab 20 — WebSocket Lanjutan

Bab 19 sudah cover dasar WebSocket. Bab ini menambahkan fitur production: non-blocking listen, subprotocol, kompresi, dan keepalive.

### 20.1 — Non-Blocking Listen

Fase sebelumnya: `ws.listen(srv)` blocking — butuh `thread(serverThread)` untuk jalan di background.

Sekarang: `ws.listenAsync(srv)` spawn listener thread otomatis.

```pascal
var srv := ws.serve(9001, {"onMessage": onMessage});
ws.listenAsync(srv);   // return immediately

println("server jalan di background");
while true do sleep(1000);
```

Kapan pakai:

· Server + task lain di main thread (scheduler, timer)
· Test E2E yang perlu spawn server dari script yang sama
· Production server multi-tugas

20.2 — Subprotocol Negotiation

Subprotocol adalah cara client dan server sepakat soal "dialek" aplikasi. Contoh:

· chat — server ini khusus chat
· json-v1 — payload selalu JSON skema v1
· bin-v2 — payload biner skema v2

Client request:

```
Sec-WebSocket-Protocol: chat, json-v1
```

Server daftar:

```pascal
var srv := ws.serve(9001, {
  "onMessage": onMessage,
  "subprotocols": ["chat", "json-v1"]
});
```

Server pilih match pertama (dalam urutan client) → chat. Akses hasil di callback:

```pascal
function onOpen(conn) begin
  println("client pakai proto: ", conn["protocol"]);
end;
```

Kalau tidak match: client minta superchat tapi server tidak punya → server tetap terima dengan conn["protocol"] = ''. Ini lenient mode per RFC 6455 §4.2.2.

20.3 — Performat-Deflate Compression

Aktifkan kompresi di config:

```pascal
var srv := ws.serve(9001, {
  "onMessage": onMessage,
  "compression": "on",
  "compressionThreshold": 128
});
```

Server akan otomatis:

· Kompres frame text/binary yang ≥ threshold
· Decompress frame masuk yang RSV1=1
· Echo extension header di handshake

Tidak ada perubahan di kode handler — kompresi transparan:

```pascal
function onMessage(conn, msg) begin
  // msg sudah otomatis di-decompress oleh engine
  // conn.send juga otomatis di-compress kalau perlu
  conn.send("echo: " + msg);
end;
```

Sizing:

· Threshold 128 byte = default. Payload < 128 byte tidak dikompresi (overhead tidak worth)
· Data JSON chat: hemat 70-90% bandwidth
· Data biner incompressible (JPEG, ZIP): server auto-fallback ke uncompressed per-frame

Verifikasi kompresi bekerja:

```pascal
function onMessage(conn, msg) begin
  var payload := "";
  var i := 0;
  while i < 500 do begin
    payload := payload + "The quick brown fox jumps over the lazy dog. ";
    i := i + 1;
  end;
  // payload ~22 KB → wire ~1 KB setelah kompresi
  conn.send(payload);
end;
```

Cek di browser DevTools → Network → WS frames, lihat Length vs Payload.

20.4 — Auto-Ping Idle Detection

Default: server kirim ping setiap 30 detik idle, tunggu pong 10 detik.

```pascal
var srv := ws.serve(9001, {
  "onMessage": onMessage,
  "pingInterval": 30000,
  "pongTimeout": 10000
});
```

Behavior:

· Client kirim frame apa pun → timer reset
· Idle > pingInterval → server kirim ping
· Client harus balas pong dalam pongTimeout ms
· Kalau tidak → close(1001 Going Away)

Browser, wscat, websockets Python — semua auto-balas ping tanpa kode client. Ini deteksi koneksi mati (mobile network drop, wifi handoff) yang tidak selalu trigger TCP FIN.

Disable:

```pascal
var srv := ws.serve(9001, {
  "pingEnabled": false
});
```

Test idle detection:

Set interval kecil:

```pascal
var srv := ws.serve(9001, {
  "pingInterval": 200,
  "pongTimeout": 500
});
```

Client mati (mis. cabut WiFi) → server deteksi dalam ~700ms, close koneksi.

20.5 — Contoh Lengkap: Chat Production

```pascal
var SRV := -1;

function onOpen(conn) begin
  println("[join] ", conn["id"], " proto=", conn["protocol"]);
  ws.broadcast(SRV, "*** " + conn["id"] + " bergabung ***");
end;

function onMessage(conn, msg) begin
  if msg == "/quit" then begin
    conn.close(1000);
    return;
  end;
  ws.broadcast(SRV, conn["id"] + ": " + msg);
end;

function onClose(conn, code) begin
  ws.broadcast(SRV, "*** " + conn["id"] + " keluar ***");
end;

begin
  SRV := ws.serve(9200, {
    "onOpen":    onOpen,
    "onMessage": onMessage,
    "onClose":   onClose,
    "subprotocols": ["chat"],
    "compression": "on",
    "pingInterval": 20000,
    "pongTimeout": 10000
  });

  ws.listenAsync(SRV);
  println("chat room production di ws://localhost:9200");

  while true do sleep(1000);
end.
```

Test dengan browser console:

```javascript
var ws = new WebSocket('ws://localhost:9200', 'chat');
ws.onopen = () => ws.send('hello from browser');
ws.onmessage = e => console.log('recv:', e.data);
```

20.6 — Ringkasan A.2

Fitur Config key Default Efek
Non-blocking listen (method call) — ws.listenAsync(srv)
Subprotocol subprotocols [] Array string
Compression compression "off" "on" untuk aktifkan
Compression threshold compressionThreshold 128 Byte
Ping interval pingInterval 30000 ms
Pong timeout pongTimeout 10000 ms
Ping enable pingEnabled true bool

Semua fitur backward compatible — kode Fase A (ws.serve + ws.listen + handler callback) jalan tanpa perubahan.

---

## Selamat!

Anda sudah menguasai seluruh kemampuan Pascak VM:

- **Bahasa**: variabel, control flow, fungsi, lambda, class, exception
- **Data**: array, dict, string, JSON, file I/O
- **FFI**: panggil library C, kirim callback, struct by value
- **Jaringan**: HTTP client, HTTP server, async
- **Database**: SQLite via FFI
- **REST API**: gabungan semuanya

Untuk referensi lengkap setiap fungsi, lihat `PASCAK_API.md`.
Untuk contoh kode siap-pakai, lihat direktori `examples/`.

---



## Bab 21 — WebSocket TLS Event Mode

Bab 20 bahas WebSocket event-driven untuk `ws://` plain. Tapi `wss://` (TLS) masih fallback ke thread mode. Bab ini melengkapi: **TLS di event mode** — 10.000+ concurrent dengan TLS.

### 21.1 — Kenapa Bab Ini Ada

Sebelum B.2, ada gap arsitektural:

| Mode | `ws://` plain | `wss://` TLS |
|------|---------------|--------------|
| Event mode | 10.000+ concurrent | ✗ (fallback) |
| Thread mode | ~500 concurrent | ~500 concurrent |

Production hampir selalu pakai HTTPS. Tanpa TLS event mode, event loop kita **tidak efektif** untuk deployment serius.

Setelah B.2: **keduanya** support event mode.

### 21.2 — Cara Pakai

Sama seperti plain `ws://`, hanya ganti `ws.serve` → `ws.serveTLS`:

```pascal
var home := sys.env("HOME");

var srv := ws.serveTLS(9443,
  home + "/server.crt",
  home + "/server.key",
  {
    "onMessage": onMessage,
    "compression": "on",
    "pingInterval": 20000
  });

ws.listenAsync(srv);   // ← TLS event mode

while true do sleep(1000);
```

**Tidak ada API baru** — signature `serveTLS` + `listenAsync` sama seperti sebelumnya. Engine yang deteksi TLS dan switch state machine internal.

### 21.3 — Generate Cert Self-Signed untuk Dev

```bash
cd ~
openssl req -x509 -newkey rsa:2048 \
    -keyout server.key -out server.crt \
    -days 365 -nodes -subj "/CN=localhost"
```

Untuk production, pakai cert asli dari Let's Encrypt / CA.

### 21.4 — Contoh Chat TLS Production

```pascal
var SRV := -1;

function onOpen(conn) begin
  ws.broadcast(SRV, "*** " + conn["id"] + " bergabung ***");
end;

function onMessage(conn, msg) begin
  if msg == "/quit" then begin
    conn.close(1000);
    return;
  end;
  ws.broadcast(SRV, conn["id"] + ": " + msg);
end;

function onClose(conn, code) begin
  ws.broadcast(SRV, "*** " + conn["id"] + " keluar ***");
end;

begin
  var home := sys.env("HOME");
  SRV := ws.serveTLS(9443,
    home + "/server.crt",
    home + "/server.key",
    {
      "onOpen":    onOpen,
      "onMessage": onMessage,
      "onClose":   onClose,
      "subprotocols": ["chat"],
      "compression": "on",
      "pingInterval": 20000,
      "pongTimeout": 10000
    });

  if SRV < 0 then begin
    println("FAIL: serveTLS return -1");
    sys.exit(1);
  end;

  ws.listenAsync(SRV);
  println("wss:// chat di port 9443, event mode");

  while true do sleep(1000);
end.
```

### 21.5 — Test dari Browser

```javascript
// Chrome/Firefox: self-signed cert butuh bypass
// 1. Buka https://localhost:9443 dulu, accept cert warning
// 2. Baru jalankan:
var ws = new WebSocket('wss://localhost:9443', 'chat');
ws.onopen = () => ws.send('hello from browser');
ws.onmessage = e => console.log('recv:', e.data);
```

### 21.6 — Test dari Python (Cert Verify Dimatikan)

```python
import asyncio, websockets, ssl

ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

async def main():
    async with websockets.connect(
        'wss://localhost:9443',
        ssl=ctx,
        subprotocols=['chat']
    ) as ws:
        await ws.send('hello')
        print(await ws.recv())

asyncio.run(main())
```

### 21.7 — Implementasi Internal (Untuk Yang Ingin Tahu)

TLS event mode bukan magic. State machine `pascak_wsevloop` tambah state:

```
nbsTLSHandshake → nbsReadHTTP → nbsOpen → nbsClosing → nbsClosed
       ↑                           ↑
   SSL_accept loop            HTTP upgrade
   (non-blocking)             parsing
```

**Handshake loop:**
1. Client connect → `TLSAcceptInit` (SSL_new + SSL_set_fd)
2. State = `nbsTLSHandshake`
3. EPOLLIN event → panggil `SSL_accept` berulang
4. Kalau `WANT_READ` → tunggu EPOLLIN berikutnya
5. Kalau `WANT_WRITE` → retry langsung (socket selalu writable)
6. Kalau `DONE` → state = `nbsReadHTTP`, fall through ke HTTP parsing
7. Setelah upgrade 101 → state = `nbsOpen` → frame loop normal

**Key insight:** seteleh TLS handshake selesai, **data HTTP request dari client sudah ter-buffer** di OpenSSL internal buffer. Jangan `Exit` setelah handshake done — fall through ke read loop untuk consume buffer ini.

### 21.8 — Performance

| Metrik | Plain WS | TLS WS (B.2) |
|--------|----------|--------------|
| Handshake overhead | ~1 RTT | 2 RTT (~200-500ms) |
| Setelah handshake | Full speed | ~sama (kernel offload) |
| Memory/conn | ~5 KB | ~8 KB (SSL state) |
| Concurrent max | 10K+ | 10K+ |

TLS handshake lebih lambat dari plain (2 RTT vs 1), tapi setelah handshake, throughput sama. Memory +3 KB per connection untuk SSL state.

### 21.9 — Kapan Pakai Event Mode vs Thread Mode

**Event mode** (`listenAsync`):
- Concurrent > 500
- Callback ringan (broadcast, kirim balik)
- Production deployment
- **Butuh TLS** → B.2 sudah support

**Thread mode** (`listenThreads`):
- Concurrent < 500
- Callback berat (blocking `sys.exec`, `sleep` lama)
- Debug lebih mudah (stack per connection)
- Legacy kompatibilitas

**Rule of thumb:** default `listenAsync`. Switch ke `listenThreads` kalau callback butuh blocking ops.

### 21.10 — Ringkasan

| Config | Event mode | Thread mode |
|--------|-----------|-------------|
| `ws://` plain | ✓ `listenAsync` | ✓ `listenThreads` |
| `wss://` TLS | ✓ `listenAsync` | ✓ `listenThreads` |
| Concurrent max | 10K+ | ~500 |
| Callback blocking | Freeze loop | Isolated |

Semua feature existing (`compression`, `pingInterval`, `subprotocols`) bekerja identik di TLS event mode.

---

## Bab 22 — Security: Exec Policy

Bab ini menjelaskan bagaimana `sys.exec` diamankan. **Baca sebelum menggunakan `sys.exec` di production.**

### 22.1 — Deny By Default

`sys.exec` **deny by default**. Ini breaking change disengaja — aman dari awal.

```pascal
begin
  var r := sys.exec("ls", ["-la"]);
  if r["denied"] then begin
    println("blocked: ", r["error"]);
    sys.exit(1);
  end;
  println(r["stdout"]);
end.
```

Output:
```
blocked: exec denied: exec policy: DENY ALL (default aman)
```

### 22.2 — Mengaktifkan Exec

Tiga cara:

**A. Env var (untuk CLI):**
```bash
PASCAK_EXEC_POLICY=whitelist:ls,git ~/pascak_noASTnet --dev script.pas
```

**B. Script-level (dev/test):**
```pascal
begin
  sys.execWhitelist(["ls", "git"]);
  var r := sys.exec("ls", ["-la"]);
  println(r["stdout"]);
end.
```

**C. Host-level (production):**
```pascal
Engine.SetExecPolicy({
  "mode":     "whitelist",
  "binaries": ["git", "python3"],
  "cwd":      "/sandbox"
});
Engine.LockExecPolicy;   // script tidak bisa override
```

### 22.3 — Env Sanitization

Child process **tidak inherit** semua env. Default yang di-allow:

```
HOME, LANG, LC_ALL, PATH, PREFIX, TERM, TMPDIR, USER
```

Yang **selalu di-strip** (security):

```
LD_PRELOAD, LD_LIBRARY_PATH, LD_AUDIT,
PYTHONPATH, PYTHONSTARTUP,
NODE_OPTIONS, NODE_PATH, RUBYOPT
```

Alasan: `LD_PRELOAD` bisa inject shared library ke binary. `PYTHONPATH` bisa inject module. Env vars ini classic privilege escalation vectors.

**Override:**
```pascal
sys.execPolicy({
  "mode": "whitelist",
  "binaries": ["python3"],
  "envAllow": ["HOME", "PATH", "PYTHONPATH"],   // explicitly allow
  "envSet": {"PYTHONUNBUFFERED": "1"}           // force set
});
```

### 22.4 — Resource Limits

Setiap subprocess dibatasi rlimit:

| Resource | Default |
|----------|---------|
| CPU time | 60 detik |
| Memory | 512 MB |
| File size | 50 MB |
| Open files | 256 |
| Subprocesses | 64 |

Kalau subprocess melewati limit, kernel kill otomatis.

**Customize:**
```pascal
sys.execPolicy({
  "mode": "whitelist",
  "binaries": ["python3"],
  "limits": {
    "enabled":       true,
    "cpuSec":        10,
    "memoryBytes":   67108864,     // 64 MB
    "subprocesses":  4
  }
});
```

### 22.5 — Concurrent & Output Limit

**Concurrent:** max subprocess bersamaan. Default 8.

```pascal
// Kalau sudah 8 subprocess jalan, spawn ke-9 di-reject
var r := sys.exec("sleep", ["100"]);
// r.denied = true
// r.error = "concurrent exec limit tercapai: 8"
```

**Output:** max stdout+stderr. Default 10 MB.

```pascal
// Kalau output > 10 MB, subprocess di-kill
var r := sys.exec("cat", ["/dev/urandom"]);
// r.exitCode != 0 (di-kill), stdout truncated
```

### 22.6 — Audit Log

Optional — log setiap exec ke file:

```pascal
sys.execPolicy({
  "mode": "whitelist",
  "binaries": ["git"],
  "auditLog": "./exec-audit.log"
});

sys.exec("git", ["status"]);
```

Log format:
```
[2025-10-07 20:15:30] pid=12345 cmd=git args=status allowed=yes reason=ok
[2025-10-07 20:15:31] pid=12345 cmd=rm args=-rf / allowed=no reason=binary "rm" tidak ada di whitelist
```

Log file di-flush per entry.

### 22.7 — Attack Scenarios yang Dicegah

| Attack | Dicegah oleh |
|--------|-------------|
| `sys.exec("rm", ["-rf", "$HOME"])` | Whitelist |
| `sys.exec("/tmp/evil.sh")` | Path restrict + whitelist |
| Fork bomb | Concurrent limit + rlimit NPROC |
| `sys.exec("cat", ["/dev/urandom"])` | Output limit |
| LD_PRELOAD injection | Env sanitize |
| Orphan `tail -f` | Shutdown SIGKILL |
| Zombie accumulation | Reap di ProcIsRunning |
| Env poisoning via PATH | Path resolution strict |

### 22.8 — Best Practices

| Saran | Alasan |
|-------|--------|
| **Selalu set whitelist di production** | Deny-all default, allow just-in-time |
| **Pakai `Engine.LockExecPolicy`** | Script tidak bisa override |
| **Set `cwd` ke sandbox** | Prevent access ke `/` root |
| **Aktifkan audit log** | Forensik kalau ada insiden |
| **Test `sys.exec` gagal dengan benar** | Jangan asumsi sukses |
| **Jangan interpolate user input ke args** | `sys.exec("sh", ["-c", userInput])` = RCE |

**Anti-pattern:**
```pascal
// DANGEROUS
var name := input("File: ");
sys.exec("sh", ["-c", "cat " + name]);   // ← RCE!
```

**Pattern yang aman:**
```pascal
// OK — arg terpisah, tidak lewat shell
sys.exec("cat", [filename]);
```

### 22.9 — Contoh Production

```pascal
function processUpload(filename) begin
  // Whitelist: hanya pandoc untuk convert
  sys.execWhitelist(["pandoc"]);

  var safe := "./uploads/" + filename;
  var r := sys.exec("pandoc", [
    "-f", "markdown",
    "-t", "html",
    "-o", "./out/" + filename + ".html",
    safe
  ]);

  if r["denied"] then begin
    println("Security: ", r["error"]);
    return false;
  end;

  if r["exitCode"] != 0 then begin
    println("pandoc fail: ", r["stderr"]);
    return false;
  end;

  return true;
end;
```

### 22.10 — Ringkasan

| Fitur | Default | Config key |
|-------|---------|------------|
| Mode | `"none"` (deny all) | `mode` |
| Whitelist | `[]` | `binaries` |
| Env allow | 8 vars | `envAllow` |
| Env deny | 8 vars | `envDeny` |
| Env set | `{}` | `envSet` |
| CWD | `""` (inherit) | `cwd` |
| Concurrent | 8 | `maxConcurrent` |
| Output | 10 MB | `maxOutputBytes` |
| CPU limit | 60s | `limits.cpuSec` |
| Memory limit | 512 MB | `limits.memoryBytes` |
| Audit log | off | `auditLog` |
| Script override | allowed | `Engine.LockExecPolicy` |

### 22.11 — CLI Cheatsheet

```bash
# Development — env override AKTIF (butuh --dev)
PASCAK_EXEC_POLICY=allow-all ~/pascak_noASTnet --dev script.pas
PASCAK_EXEC_POLICY=whitelist:python3 ~/pascak_noASTnet --dev test.pas
PASCAK_TLS_NO_VERIFY=1 ~/pascak_noASTnet --dev debug.pas

# Production — env override DIABAIKAN
# Policy default = "none" (deny all)
~/pascak_noASTnet script.pas

# Production dengan policy host-level
# → set via TPascakEngine.SetExecPolicy + LockExecPolicy di host code
```

⚠️ Sejak Fase 1.4, env PASCAK_EXEC_POLICY dan PASCAK_TLS_NO_VERIFY
hanya dibaca bila --dev di-pass. Tanpa --dev, kedua env var ini
diabaikan total. Ini pertahanan terhadap env poisoning di production.


**Production tidak boleh pakai env var** — itu untuk dev/test only. Production **harus** pakai `Engine.SetExecPolicy` + `Engine.LockExecPolicy` dari host code.

---

## Bab 23 — Async File I/O

Bab 8 sudah bahas `fileRead`, `fileWrite`, `fileAppend` — semuanya
**blocking**. Di dalam event loop (HTTP/WS callback), blocking read
dari file besar akan freeze seluruh server.

Bab ini memperkenalkan **`fs.readAsync`** dan kawan-kawan — baca/tulis
file di worker thread, callback dipanggil saat selesai tanpa block
main thread.

### 23.1 — Kapan Async vs Sync

| Skenario | Pakai |
|---|---|
| Script top-level, file < 100 KB | `fileRead` (sync) |
| Di callback WS/HTTP | `fs.readAsync` (**wajib**) |
| Batch > 10 file | `fs.readAsync` paralel |
| File > 1 MB | `fs.readAsync` |
| Setup/init code | `fileRead` (sync) |
| Config kecil dibaca sekali | `fileRead` (sync) |

**Rule of thumb**: kalau ada event loop aktif → pakai async untuk I/O
apapun yang > 100 KB atau > 1 file.

### 23.2 — Pattern Callback (Recommended)

Cara paling bersih — auto-cleanup, tidak ada state manual.

```pascal
begin
  fs.readAsync("data.json", lambda r : begin
    if r["ok"] then
      println("read ", r["bytesRead"], " bytes")
    else
      println("error: ", r["error"]);
  end);

  println("background read started");
  // Script lanjut tanpa block
end.
```

Output (urutan bisa berubah):
```
background read started
read 4096 bytes
```

**Callback signature**: `fn(result)` — result adalah dict dengan field
`{ok, data, bytesRead, path}` (sukses) atau `{ok: false, error}` (gagal).

### 23.3 — Pattern Polling

Untuk kontrol manual — tidak pakai callback. **Wajib free manual.**

```pascal
var t := fs.readAsync("data.txt");

while true do begin
  var r := fs.pollAsync(t);
  if r != null then begin
    if r["ok"] then
      println(r["data"])
    else
      println("error: ", r["error"]);
    fs.freeAsync(t);   // ← WAJIB
    break;
  end;
  sleep(10);
end;
```

**Jangan lupa `fs.freeAsync(t)`** — kalau lupa, task nyangkut di
registry (memory leak).

### 23.4 — Batch Paralel

Baca N file sekaligus. Jauh lebih cepat dari sequential.

```pascal
var files := fs.glob("./logs", "*.log");
var done := 0;
var total := len(files);
var totalLines := 0;

function onRead(r) begin
  lock begin
    done := done + 1;
    if r["ok"] then
      totalLines := totalLines + len(r["data"].split("\n"));
  end;
end;

begin
  for f in files do
    fs.readAsync("./logs/" + f, onRead);

  // Tunggu semua selesai
  while done < total do
    sleep(50);

  println("Read ", total, " files, ", totalLines, " lines total");
end.
```

**Perhatikan `lock`**: callback jalan di main thread yang berbeda
dari script utama. Untuk counter/state bersama, pakai `lock` block.

### 23.5 — Write & Append Async

```pascal
// Write (overwrite)
fs.writeAsync("output.txt", "Hello world", lambda r : begin
  if r["ok"] then
    println("wrote ", r["bytesWritten"], " bytes");
end);

// Append (append ke akhir)
fs.appendAsync("log.txt", "[INFO] event\n");

// Multiple appends paralel — urutan TIDAK dijamin
fs.appendAsync("log.txt", "line 1\n");
fs.appendAsync("log.txt", "line 2\n");
fs.appendAsync("log.txt", "line 3\n");
// Hasil: mungkin [1, 3, 2] atau [2, 1, 3] — jangan andalkan urutan!
```

**Gotcha**: untuk append yang **harus** berurutan, pakai loop dengan
`waitAsync` per task:

```pascal
for line in lines do begin
  var t := fs.appendAsync("log.txt", line + "\n");
  fs.waitAsync(t, 5000);
  fs.freeAsync(t);
end;
```

### 23.6 — Timeout & Cancel

```pascal
// Baca dengan timeout 5 detik
var t := fs.readAsync("slow.dat");
var r := fs.waitAsync(t, 5000);

if r == null then begin
  fs.cancelAsync(t);   // task masih pending → cancel berhasil
  println("timeout, cancelled");
end else begin
  println("read: ", r["bytesRead"], " bytes");
end;

fs.freeAsync(t);
```

**Batasan cancel**: hanya bekerja kalau task masih `PENDING` (worker
belum mulai). Task `RUNNING` tidak bisa di-cancel.

### 23.7 — Di Dalam HTTP/WS Callback

**Ini alasan utama async FS ada.**

```pascal
function onMessage(conn, msg) begin
  // ❌ BURUK — block event loop
  var data := fileRead("huge.log");   // freeze semua client lain!
  conn.send(data);
end;

function onMessage(conn, msg) begin
  // ✅ BAIK — non-blocking
  fs.readAsync("huge.log", lambda r : begin
    if r["ok"] then
      conn.send(r["data"]);
    else
      conn.send("error: " + r["error"]);
  end);
end;
```

**Catatan**: `conn.send()` di dalam callback aman — callback jalan di
main thread (bukan worker), dan `conn.send` sudah thread-safe.

### 23.8 — Batasan & Caveat

| Batasan | Nilai | Alasan |
|---|---|---|
| Max read size | 64 MB | Cegah OOM dari worker |
| Max concurrent task | Tidak dibatasi (best practice < 32) | Setiap task spawn thread |
| Urutan append | Tidak dijamin | Parallel write |
| Cancel | Hanya PENDING | Worker tidak bisa di-interrupt |
| Auto-free | Hanya dengan callback | Pattern poll → manual free |

**Memory quota**: hasil `readAsync` masuk ke memory quota engine
(default 256 MB). File 64 MB × 4 paralel → 256 MB — akan trigger OOM.

**Best practice**: untuk batch besar, batasi concurrent via counter:

```pascal
var pending := 0;
var MAX_CONCURRENT := 8;

function readWithLimit(f, callback) begin
  while pending >= MAX_CONCURRENT do
    sleep(10);

  lock begin
    pending := pending + 1;
  end;

  fs.readAsync(f, lambda r : begin
    callback(r);
    lock begin
      pending := pending - 1;
    end;
  end);
end;
```

### 23.9 — Ringkasan API

| Fungsi | Return | Auto-free? |
|---|---|---|
| `fs.readAsync(path, [cb])` | taskID | ✓ (kalau pakai cb) |
| `fs.writeAsync(path, data, [cb])` | taskID | ✓ (kalau pakai cb) |
| `fs.appendAsync(path, data, [cb])` | taskID | ✓ (kalau pakai cb) |
| `fs.pollAsync(taskID)` | dict \| null | ✗ |
| `fs.waitAsync(taskID, [ms])` | dict \| null | ✗ |
| `fs.cancelAsync(taskID)` | bool | ✗ |
| `fs.freeAsync(taskID)` | bool | ✗ |

**Pola aman**: pakai callback → tidak perlu free manual.

### 23.10 — Contoh: Log Merger

Gabung 100 file `.log` dari folder ke satu file output.

```pascal
var SRCDIR := "./logs";
var OUTPATH := "./merged.log";

begin
  var files := fs.glob(SRCDIR, "*.log");
  println("Merging ", len(files), " files");

  var done := 0;
  var total := len(files);

  function onRead(r) begin
    if r["ok"] then begin
      // Tulis hasil ke output — append, tapi urutan tidak penting
      fs.appendAsync(OUTPATH, r["data"]);
    end;

    lock begin
      done := done + 1;
      if done mod 10 == 0 then
        println("  ", done, "/", total);
    end;
  end;

  // Buat file output baru (kosong)
  fs.writeAsync(OUTPATH, "");

  // Baca semua paralel
  for f in files do
    fs.readAsync(SRCDIR + "/" + f, onRead);

  while done < total do sleep(50);

  var stat := fs.stat(OUTPATH);
  println("Output: ", stat.size, " bytes");
end.
```

**Output** (contoh):
```
Merging 47 files
  10/47
  20/47
  30/47
  40/47
Output: 1284932 bytes
```

---

## Bab 24 — Parser Quirk

Pascak punya beberapa quirk parser yang bisa bikin bingung kalau tidak
tahu. Bab ini katalog lengkap + workaround.

### 24.1 — try/catch di Loop Butuh begin..end

**Masalah**: ketika `try..catch` ada di dalam loop, dan setelah `catch`
ada statement lain, parser bisa salah anggap statement itu bagian dari
`catch` block.

```pascal
// ❌ Parser error atau behaviour tak terduga
while cond do begin
  try
    risky();
  catch e do
    handle(e);
    i := i + 1;        // ← di-parse sebagai bagian catch body!
end;                    // ← parser expect lebih banyak statement
```

**Solusi**: bungkus `catch` body dengan `begin..end` eksplisit.

```pascal
// ✅ Benar
while cond do begin
  try
    risky();
  catch e do begin
    handle(e);
  end;                  // ← explicit end untuk catch body
  i := i + 1;           // ← sekarang di-parse di luar catch
end;
```

**Kapan kena**: kalau ada statement setelah `try..catch` di dalam
loop body, dan tidak pakai `begin..end` di `catch`.

**Aturan aman**: **selalu pakai `begin..end` di catch body** kalau ada
statement setelahnya.

### 24.2 — eval() Return Value

`eval()` mengembalikan nilai dari `return` statement, **bukan** nilai
dari ekspresi terakhir.

```pascal
// ✅ Dapat nilai
var r := eval("begin return 6 * 7; end.");
println(r);   // 42

// ⚠️ Dapat null
var r := eval("begin 6 * 7; end.");
println(r);   // null — ekspresi tanpa return diabaikan

// ⚠️ Dapat null juga
var r := eval("6 * 7");
println(r);   // null
```

**Rule**: untuk dapat nilai dari `eval()`, **wajib** pakai `return`.

**Use case**: `eval()` untuk side-effect (define function) tanpa perlu
return value:

```pascal
eval("function greet(n) begin return 'Halo, ' + n; end;");
println(greet("World"));   // Halo, World
```

### 24.3 — eval() Share Global Scope

Function yang di-define di dalam `eval()` **persisten di global scope**
untuk sisa eksekusi script.

```pascal
begin
  eval("function helper(x) begin return x * 2; end;");
  println(helper(5));   // 10 — helper() sekarang ada di global

  // Di loop — perlu unique name supaya tidak overwrite
  for i := 1 to 3 do begin
    var name := "fn_" + str(i);
    eval("function " + name + "(x) begin return x + " + str(i) + "; end;");
  end;

  println(fn_1(10));   // 11
  println(fn_2(10));   // 12
  println(fn_3(10));   // 13
end.
```

**Gotcha**: kalau loop `eval("function f...")` dengan nama sama, versi
terakhir yang dipakai.

```pascal
// ❌ Function 'f' akan jadi versi terakhir
for i := 1 to 3 do
  eval("function f(x) begin return x + " + str(i) + "; end;");
println(f(10));   // 13 (versi i=3)

// ✅ Pakai unique name
for i := 1 to 3 do begin
  var name := "f_" + str(i);
  eval("function " + name + "(x) begin return x + " + str(i) + "; end;");
end;
```

### 24.4 — Tidak Ada Literal `#10` untuk Newline

Lexer Pascak **tidak** mengenali `#10`, `#13` sebagai escape karakter.
Karakter newline harus via escape sequence dalam string literal.

```pascal
// ❌ Tidak valid
var s := "line1" + #10 + "line2";

// ✅ Pakai escape sequence
var s := "line1\nline2";

// ✅ Atau pakai chr()
var s := "line1" + chr(10) + "line2";
```

**Escape sequences yang didukung**:

| Escape | Karakter |
|---|---|
| `\n` | Newline (LF, 0x0A) |
| `\r` | Carriage return (CR, 0x0D) |
| `\t` | Tab |
| `\"` | Double quote |
| `\'` | Single quote |
| `\\` | Backslash |

**Gotcha di script builder**: kalau Anda generate script via string
concatenation (mis. dari Pascal host), pastikan pakai `\n` bukan `#10`.

### 24.5 — Statement `if..then..else` Bukan Expression

Di Pascal, `if` adalah statement — bukan expression. Jadi tidak bisa
dipakai langsung sebagai nilai.

```pascal
// ❌ Tidak valid
var x := if cond then 1 else 2;

// ✅ Pakai ternary
var x := cond ? 1 : 2;

// ✅ Atau assign di dalam if
var x := 0;
if cond then x := 1 else x := 2;
```

**Konsekuensi di lambda**:

```pascal
// ❌ Lambda expression body tidak bisa if
var f := lambda a, b : if a < b then -1 else 1;

// ✅ Pakai ternary
var f := lambda a, b : a < b ? -1 : 1;

// ✅ Atau pakai block body
var f := lambda a, b : begin
  if a < b then return -1;
  return 1
end;
```

### 24.6 — Tidak Ada `elif`

Tidak ada keyword `elif` atau `else if` di Pascal. Pakai nested `else`
dengan `if`, atau sequential `if`.

```pascal
// ❌ Tidak valid
if x == 1 then println("satu")
elif x == 2 then println("dua")
elif x == 3 then println("tiga");

// ✅ Sequential if (paling ringkas)
if x == 1 then println("satu");
if x == 2 then println("dua");
if x == 3 then println("tiga");

// ✅ Nested else if (untuk grouping logis)
if x == 1 then
  println("satu")
else if x == 2 then
  println("dua")
else if x == 3 then
  println("tiga")
else
  println("lainnya");

// ✅ Case for numeric dispatch
case x of
  1: println("satu");
  2: println("dua");
  3: println("tiga");
else
  println("lainnya");
end;
```

### 24.7 — Tidak Ada `var` Inline

Deklarasi `var` harus di awal blok, tidak bisa di tengah.

```pascal
// ❌ Tidak valid
if cond then
  var x := 5;

// ✅ Deklarasi di awal
var x := 0;
if cond then x := 5;

// ✅ Atau pakai block
if cond then begin
  var x := 5;   // ← OK karena awal block
  println(x);
end;
```

**Exception**: statement `var a, b := ...` di top-level dan di awal
function body OK. Tapi tidak boleh di tengah block.

### 24.8 — Named Function vs Lambda di FFI Callback

Keduanya bisa dipakai di `dll.callback`:

```pascal
// Named function
function cmp(a, b) begin
  if a < b then return -1;
  if a > b then return 1;
  return 0
end;

var cb1 := dll.callback("ii->i", cmp);

// Lambda
var cb2 := dll.callback("ii->i", lambda a, b : a < b ? -1 : a > b ? 1 : 0);
```

**Kapan pakai named**: body multi-statement, butuh debug, dipakai
berulang.

**Kapan pakai lambda**: one-shot, short, inline.

**Catatan**: lambda `lambda : begin ... end` body tidak bisa pakai
`return` untuk nilai awal — harus `return` eksplisit di akhir body.

### 24.9 — Dot Notation vs Indexing untuk Keyword

Keyword tidak bisa diakses via dot notation. **Wajib** pakai indexing.

```pascal
var d := {"method": "GET", "path": "/", "class": "A"};

// ✅ Indexing selalu aman
println(d["method"]);    // "GET"
println(d["class"]);     // "A"

// ✅ Dot OK untuk non-keyword
println(d.path);         // "/"

// ❌ Dot untuk keyword → parse error
// println(d.method);    // ERROR
// println(d.class);     // ERROR
```

**Keyword list** (yang tidak bisa dipakai dot):
`if`, `then`, `else`, `case`, `of`, `while`, `do`, `begin`, `end`,
`var`, `const`, `function`, `method`, `class`, `record`, `new`, `and`,
`or`, `for`, `to`, `in`, `return`, `break`, `continue`, `not`, `mod`,
`try`, `catch`, `finally`, `true`, `false`, `null`, `nil`, `import`,
`repeat`, `until`, `lambda`, `lock`, `yield`, `defer`, `downto`,
`step`, `throw`.

**Best practice**: untuk dict dari user input atau JSON, **selalu**
pakai indexing `["key"]` — aman untuk semua key name.

### 24.10 — Ringkasan Cepat

| Quirk | Workaround |
|---|---|
| `try/catch` di loop | Wrap catch body dengan `begin..end` |
| `eval()` return | Pakai `return` eksplisit |
| `eval()` persist | Pakai unique name di loop |
| Literal newline | Pakai `\n` atau `chr(10)` |
| `if` bukan expression | Pakai ternary `?:` atau block lambda |
| Tidak ada `elif` | Sequential `if` atau nested else-if |
| Tidak ada inline var | Deklarasi di awal blok |
| Dot + keyword | Indexing `d["method"]` |
| FFI callback | Named function atau lambda |

### 24.11 — Debugging Tips

Kalau parser complain tapi syntax kelihatan OK:

1. **Cek `try/catch` di loop** — tambah `begin..end`
2. **Cek keyword sebagai dot** — ganti ke indexing
3. **Cek lambda body** — pastikan single expression atau `begin..end`
4. **Cek `var` placement** — semua var di awal block
5. **Cek escape sequence** — ganti `#10` dengan `\n`

Kalau masih bingung, parse error message biasanya menunjukkan **baris
dan kolom spesifik** — titik itu biasanya 1-2 karakter setelah masalah
sebenarnya.

---
```
## Bab 25 — Timer & JSON Path

Dua fitur DX kecil tapi sering dipakai: timer asinkron dan path-based access untuk JSON.

### 25.1 — Timer API

Empat fungsi timer yang tersedia global:

| Fungsi | Efek |
|---|---|
| `setTimeout(fn, ms) → timerID` | Fire `fn` sekali setelah `ms` |
| `setInterval(fn, ms) → timerID` | Fire `fn` berulang setiap `ms` |
| `clearTimeout(timerID)` | Cancel timer |
| `clearInterval(timerID)` | Alias `clearTimeout` |

Semua callback jalan di **main event loop thread** — aman akses state script langsung, tanpa `lock` (kecuali multi-thread).

#### Contoh — Delayed Message

```pascal
begin
  println("start");

  setTimeout(lambda : println("3 detik kemudian"), 3000);

  println("ini jalan duluan");
end.
```

Output:
```
start
ini jalan duluan
3 detik kemudian
```

#### Contoh — Countdown

```pascal
var counter := 5;
var t := 0;

t := setInterval(lambda : begin
  println(counter);
  counter := counter - 1;

  if counter < 0 then
    clearInterval(t);
end, 1000);

sleep(7000);   // tunggu selesai
```

Output:
```
5
4
3
2
1
0
```

#### Contoh — Cancel Timer

```pascal
function longOperation() begin
  println("operasi selesai");
end;

begin
  var t := setTimeout(longOperation, 10000);
  println("timer diset. Cancel dalam 100ms...");

  sleep(100);
  clearTimeout(t);
  println("cancelled");

  sleep(500);   // tunggu sebentar untuk buktikan tidak fire
end.
```

Output:
```
timer diset. Cancel dalam 100ms...
cancelled
```
(tidak ada "operasi selesai" — timer di-cancel)

#### Kapan Pakai Timer

| Skenario | Pakai |
|---|---|
| Delay aksi (soft retry, backoff) | `setTimeout` |
| Background polling | `setInterval` |
| Cancel timer dari user action | `clearTimeout` |
| Animasi loop | `setInterval` |

**Jangan pakai timer untuk**:
- **Precision timing** — `setTimeout(fn, 16)` bisa fire di 20ms, tidak dijamin 16ms
- **Blocking sleep** — pakai `sleep(ms)` untuk itu
- **Long-running loop tanpa stop** — pastikan ada `clearInterval` di suatu kondisi

#### Catatan

- `ms < 1` di-clamp ke 1ms untuk `setInterval`
- Timer auto-cancel saat script selesai
- Callback tidak punya argumen — closure via lambda
- `clearTimeout` return `true` kalau timer valid, `false` kalau sudah fire / invalid

---

### 25.2 — JSON Path

`jsonPath(dict, "a.b.c")` — ekstrak nilai nested dict tanpa cek `hasKey` berlapis.

```pascal
var data := jsonParse('{
  "user": {
    "profile": {
      "name": "Alice",
      "age": 30
    }
  }
}');

println(jsonPath(data, "user.profile.name"));   // "Alice"
println(jsonPath(data, "user.profile.age"));    // 30
println(jsonPath(data, "user.missing"));        // null
println(jsonPath(data, "nonexistent.deep"));    // null
```

**Tanpa `jsonPath`**, akses nested butuh:

```pascal
// ❌ Verbose
if data.hasKey("user") then
  var u := data["user"];
  if u.hasKey("profile") then
    var p := u["profile"];
    if p.hasKey("name") then
      println(p["name"]);

// ✅ Ringkas
println(jsonPath(data, "user.profile.name"));
```

#### Perilaku

| Input path | Hasil |
|---|---|
| `"user.profile.name"` (ada) | nilai |
| `"user.profile.name"` (tidak ada) | `null` |
| `"user.missing.deep"` | `null` |
| `"a.b.c"` di mana `a` = string | `null` |
| `"a..b"` (empty segment) | skip, treat sebagai `"a.b"` |

**Selalu return `null`** — bukan raise. Aman untuk probe:

```pascal
var timeout := jsonPath(config, "server.timeout");
if timeout == null then
  timeout := 30000;   // default
```

#### Contoh — Config Parser

```pascal
function getConfig() begin
  return jsonParse('{
    "database": {
      "host": "localhost",
      "port": 5432,
      "credentials": {
        "user": "admin",
        "password": "secret"
      }
    },
    "server": {
      "port": 8080
    }
  }');
end;

begin
  var cfg := getConfig();

  var dbHost := jsonPath(cfg, "database.host");
  var dbPort := jsonPath(cfg, "database.port");
  var dbUser := jsonPath(cfg, "database.credentials.user");
  var srvPort := jsonPath(cfg, "server.port");

  println("DB: ", dbUser, "@", dbHost, ":", dbPort);
  println("Server: :", srvPort);
end.
```

Output:
```
DB: admin@localhost:5432
Server: :8080
```

#### Contoh — API Response Parsing

```pascal
var res := http.get("https://api.example.com/user/42");

if res.status == 200 then begin
  var data := jsonParse(res.body);

  var name := jsonPath(data, "data.user.name");
  var email := jsonPath(data, "data.user.email");
  var role := jsonPath(data, "data.user.role");

  println("User: ", name);
  println("Email: ", email);
  println("Role: ", role);
end else
  println("API error: ", res.status);
```

#### Kapan Pakai `jsonPath`

| Skenario | Pakai |
|---|---|
| Config berlapis (2+ level) | `jsonPath` |
| API response nested | `jsonPath` |
| Dict flat 1 level | indexing biasa `d["key"]` |
| Butuh iterate semua keys | `.keys()` + loop |

**Batasan v1**: hanya support dict. Array indexing (`jsonPath(d, "users.0.name")`) belum — pakai indexing manual dulu:

```pascal
var users := jsonPath(data, "users");
if users != null then
  println(users[0].name);
```

---

### 25.3 — Kombinasi Timer + JSON

Contoh: poll API setiap 5 detik, stop setelah dapat response valid.

```pascal
var pollTimer := 0;

function pollApi() begin
  var res := http.get("https://api.example.com/status");

  if res.status != 200 then begin
    println("API belum siap, retry dalam 5s...");
    return;   // timer tetap running
  end;

  var data := jsonParse(res.body);
  var ready := jsonPath(data, "status.ready");

  if ready == true then begin
    println("API siap!");
    println("Version: ", jsonPath(data, "version"));
    println("Uptime: ", jsonPath(data, "status.uptime"));

    clearInterval(pollTimer);   // stop polling
  end;
end;

begin
  println("Polling API setiap 5 detik...");
  pollTimer := setInterval(pollApi, 5000);

  sleep(60000);   // safety timeout 60 detik
  clearInterval(pollTimer);
end.
```

**Pattern ini berguna untuk**: startup dependency check, health probe, wait-for-service.

---

### 25.4 — Ringkasan

| API | Signature | Return |
|---|---|---|
| `setTimeout` | `(fn, ms)` | `timerID` |
| `setInterval` | `(fn, ms)` | `timerID` |
| `clearTimeout` | `(timerID)` | `bool` |
| `clearInterval` | `(timerID)` | `bool` |
| `jsonPath` | `(dict, "a.b.c")` | `value \| null` |

**Best practices**:
1. **Simpan timerID** kalau mau bisa cancel nanti
2. **jsonPath** untuk config/API nested — jangan untuk dict flat
3. **Callback timer** jalan di main thread — akses state langsung OK
4. **Cleanup** timer di script akhir supaya tidak fire setelah selesai

---
## Bonus — HTTP/2 Client

Pascak juga mendukung HTTP/2 client via ALPN negotiation (RFC 7301).
Ini bukan pengganti http.get untuk semua kasus. Berguna saat server
hanya mendukung h2 (jarang) atau untuk verifikasi endpoint h2.

Contoh:

    begin
      var r := http.get2("https://httpbin.org/get");
      println("status: ", r["status"]);      // 200
      println("version: ", r["version"]);    // "h2"
      println("body len: ", len(r["body"]));
    end.

Kapan pakai http.get2:

- Server hanya dukung h2         -> http.get2
- Sequential requests ke host sama -> http.get (pooling)
- Verifikasi versi h2             -> http.get2
- Server tidak support h2         -> http.get

Batasan v1:

- Single-stream: satu request per connection, tidak ada multiplexing
- HTTPS-only: h2c cleartext tidak diimplementasi
- No pooling: koneksi baru per request (lebih lambat dari http.get
  untuk sequential)
- No h1 fallback: kalau server tidak negotiate h2, error raised

Yang akan datang (v2): multiplexing, connection pooling, h2c.

Untuk detail lengkap: lihat pascak_api.md, bagian http.get2.

---

## Latihan Lanjutan

Setelah tutorial ini, coba bangun:

1. **Todo API** — REST API untuk todo list dengan SQLite
2. **URL shortener** — POST short URL, GET redirect
3. **Markdown blog** — file-based, tanpa database
4. **Log viewer** — baca file log besar, filter, tampilkan via API
5. **Chat backend** — REST + polling atau async

Semua komponen yang dibutuhkan sudah tersedia. Selamat berkarya!
