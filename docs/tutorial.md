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
26. [Embedding In-Process](#bab-26--embedding-in-process)
27. [GUI Browser-Based](#bab-27--gui-browser-based)
28. [Native GUI (SDL2)](#bab-28--native-gui-sdl2)
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

### 24.7 — `var` Inline vs For-Loop Iterator

Deklarasi `var` reguler harus di awal blok, tidak bisa di tengah:

```pascal
// ❌ Tidak valid — var di tengah if-body
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

**Exception 1 — top-level & awal function**: `var a, b := ...` di
top-level dan di awal function body OK. Tapi tidak boleh di tengah
block.

**Exception 2 — For-loop iterator (sejak v0.8.1)**: variabel loop
**tidak** butuh prior `var`. Parser auto-scope di dalam loop:

```pascal
// ✅ Semua valid tanpa `var x` di awal:

for x in [1, 2, 3] do
  println(x);

for i := 1 to 5 do
  println(i);

for k in {"a": 1, "b": 2} do
  println(k);

var doubled := [x * 2 for x in [1, 2, 3]];
```

**Histori**: Sebelum v0.8.1, pattern di atas error
"belum dideklarasikan" — DCE (`TDeadCodeAnalyzer.Analyze`) memanggil
`MarkUsed` **sebelum** `DeclareSymbol`. Fix v0.8.1: `MarkUsedIfExists`
yang silently skip jika loop var belum ada di scope. Shadowing tetap
bekerja — kalau `x` sudah ada di scope luar, tetap ditandai `used`
(captured). 8 regression test pass.

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
| Tidak ada inline var | Deklarasi di awal blok (kecuali for-loop iterator — auto-scoped sejak v0.8.1) |
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

---

## Bab 26 — Embedding In-Process

Bab-bab sebelumnya menjalankan script via `pascak_noASTnet script.pas` — **subprocess**. Setiap call spawn proses baru, ~2 detik startup overhead.

**In-process embedding** berbeda: host Pascal code `uses pascak_engine` dan panggil VM langsung. Overhead per call = microseconds.

### 26.1 — Subprocess vs In-Process

| Aspek | Subprocess | In-Process |
|-------|-----------|------------|
| Overhead/call | ~2 detik | ~microseconds |
| Isolasi | Full (new process) | Shared engine |
| Native callback | ❌ | ✅ |
| Requires binary | ✅ | ❌ (linked in) |
| Failure isolation | ✅ Safe | ⚠️ Host crash risk |
| Use case | Untrusted script | Trusted, hot-path |

**Kapan pakai subprocess:**
- CLI tool (`--test`, `--lint`, `--fmt`)
- Untrusted plugin (safety isolation)
- One-shot script

**Kapan pakai in-process:**
- Trusted script dari host app (game, editor, rule engine)
- Hot-path evaluation (per HTTP request, per user action)
- Native callback host↔script

### 26.2 — Quick Start: Hello Embed

Minimal host program:

    program my_host;

    {$MODE OBJFPC}{$H+}

    uses
      {$IFDEF UNIX}
        cthreads,       { MANDATORY on Unix — must be first unit }
      {$ENDIF}
      SysUtils, pascak_engine;

    var
      R: TPascakResult;
    begin
      R := ExecuteEngine('begin return 6 * 7; end.');
      if R.Success then
        WriteLn('Result: ', R.ValueAsString)   { 42 }
      else
        WriteLn('Error: ', R.Error);
    end.

**Build:**

    fpc -Mobjfpc -Sh -Fu/path/to/pascak my_host.pas

**Run:**

    ./my_host
    # Output: Result: 42

⚠️ **`cthreads` WAJIB jadi unit pertama di Unix** — tanpa ini, FPC's SysUtils initialization kadang crash karena thread primitives belum ready. Ini bug FPC yang tidak akan di-fix.


### 26.3 — TPascakResult

`ExecuteEngine` return `TPascakResult`:

| Field | Tipe | Deskripsi |
|-------|------|-----------|
| `Success` | Boolean | False kalau error, True otherwise |
| `ValueType` | string | `"numeric"` / `"string"` / `"boolean"` / `"null"` / `"other"` |
| `ValueAsString` | string | String representation (selalu diisi) |
| `ValueAsNum` | Double | Numeric (iff `ValueType="numeric"`) |
| `ValueAsBool` | Boolean | Boolean (iff `ValueType="boolean"`) |
| `Error` | string | `"EClassName: message"` on failure |

Handler standar:

    R := ExecuteEngine(source);
    if not R.Success then begin
      WriteLn('Error: ', R.Error);
      Exit;
    end;

    case R.ValueType of
      'numeric': WriteLn('Num: ',  R.ValueAsNum);
      'string':  WriteLn('Str: ',  R.ValueAsString);
      'boolean': WriteLn('Bool: ', R.ValueAsBool);
      'null':    WriteLn('Null');
    else
      WriteLn('Other: ', R.ValueAsString);
    end;

### 26.4 — ExecuteEngine + ShutdownEngine

**Singleton design**: call pertama create engine, call berikutnya reuse.

    // Call 1 — creates engine
    R := ExecuteEngine('begin return 1 + 1; end.');     { R.ValueAsNum = 2 }

    // Call 2 — reuses existing engine
    R := ExecuteEngine('begin return "hello"; end.');   { R.ValueAsString = "hello" }

    // Call 3 — same engine
    R := ExecuteEngine('begin return true; end.');      { R.ValueAsBool = True }

    // Optional explicit shutdown (auto-called at exit)
    ShutdownEngine;

**Thread-safe**: internal CriticalSection serializes access — multiple thread bisa call tanpa race.

**Global state persists antar call**:

    ExecuteEngine('begin var COUNTER := 0; end.');
    ExecuteEngine('begin COUNTER := COUNTER + 1; end.');
    ExecuteEngine('begin COUNTER := COUNTER + 1; end.');
    R := ExecuteEngine('begin return COUNTER; end.');
    { R.ValueAsNum = 2 — state preserved }

⚠️ **Tidak ada cara reset global env** tanpa `ShutdownEngine`. Kalau butuh fresh state, tutup engine lalu create ulang (tapi ini expensive ~100ms).


### 26.5 — RegisterNative — Callback ke Host

Ini fitur paling powerful dari in-process embedding: script bisa panggil Pascal function langsung.

    function MyAdd(const Args: TNativeValueArray): TNativeValue;
    begin
      if Length(Args) < 2 then Exit(NVNull);
      Result := NVNum(Args[0].Num + Args[1].Num);
    end;

    begin
      RegisterNative('add', @MyAdd);

      R := ExecuteEngine('begin return add(10, 20); end.');
      WriteLn('Result: ', R.ValueAsString);   { 30 }
    end.

**Types:**

| Type | Field |
|------|-------|
| `TNativeValueKind` | `(nvkNull, nvkNumber, nvkString, nvkBoolean)` |
| `TNativeValue` | record `{Kind, Num, Str, Bool}` |
| `TNativeValueArray` | `array of TNativeValue` |
| `TPascakNativeFunc` | `function(const Args: TNativeValueArray): TNativeValue` |

**Helper constructors:**

- `NVNull` — null value
- `NVNum(V: Double)` — numeric
- `NVStr(S: string)` — string
- `NVBool(B: Boolean)` — boolean

**Contoh — native callback dengan logic:**

    function HostLog(const Args: TNativeValueArray): TNativeValue;
    var
      Level, Msg: string;
    begin
      if Length(Args) < 2 then Exit(NVNull);
      Level := Args[0].Str;
      Msg := Args[1].Str;
      WriteLn('[', Level, '] ', Msg);   { host-side logging }
      Result := NVBool(True);
    end;

    RegisterNative('hostLog', @HostLog);

    ExecuteEngine(
      'begin'#10 +
      '  hostLog("INFO", "app started");'#10 +
      '  hostLog("WARN", "cache miss");'#10 +
      'end.');

Output di host stdout:

    [INFO] app started
    [WARN] cache miss

### 26.6 — Batasan Native Callback

- **1 fungsi = 1 dispatch point** — registration jalan sekali, callback persistent
- **Bukan zero-copy** — string di-copy Pascal→VM dan VM→Pascal
- **Return type terbatas** — numeric/string/boolean/null; tidak bisa return array/object (v1)
- **Exception di callback = host crash risk** — kalau callback raise exception, VM tidak catch. Bungkus dengan try/except di callback.


### 26.7 — Requirements

**Wajib:**

- **`cthreads` FIRST unit di Unix** — posisi unit ini menentukan init order. Kalau SysUtils jalan dulu, thread primitive belum ready.
- **`pascak_engine.ppu` exists** — build `pascak_engine.pas` dulu: `fpc -Mobjfpc -Sh pascak_engine.pas`
- **Semua unit `pascak_*.pas` di `-Fu` path** — engine butuh `pascak_net`, `pascak_proc`, `pascak_crypto`, `pascak_http`, dll.

**Build command minimal:**

    fpc -Mobjfpc -Sh -Fu. -Fuunits my_host.pas

**Windows:** `cthreads` tidak wajib, tapi tidak ada efek samping kalau pakai `{$IFDEF UNIX}`.

### 26.8 — Limitations v1

| Fitur | Status |
|-------|--------|
| Singleton engine | ✅ |
| Thread-safe (mutex) | ✅ |
| Native callback | ✅ |
| Structured error object | ❌ (string only) |
| Multi-engine instance | ❌ (singleton) |
| Stdout capture dari script | ❌ (script print ke actual stdout) |
| Bidirectional async (host→script mid-exec) | ❌ |

### 26.9 — Kapan Pakai In-Process

| Skenario | Recommendation |
|----------|---------------|
| Trusted script dalam host app | **In-process** |
| Hot-path evaluation (per request) | **In-process** |
| Native callback host→script | **In-process** |
| Game scripting layer | **In-process** |
| Rule engine evaluator | **In-process** |
| Untrusted user script | Subprocess (isolation) |
| CLI tool / plugin CLI | Subprocess |
| Test runner (`--test`) | Subprocess |
| Embed application launcher | Subprocess (`TPascakEmbed`) |

**Full example:** `examples/embed_inproc.pas` — 6 test pass (numeric, string, boolean, null, multi-call state, native callback).


---

## Bab 27 — GUI Browser-Based

Pascak punya GUI module yang memungkinkan script Anda membuat **aplikasi desktop dengan tampilan browser**. Bukan web app (yang butuh server terpisah) — GUI app yang jalan di device, buka browser otomatis, dan bisa panggil fungsi Pascal dari JavaScript.

### 27.1 — Konsep: WebView Tanpa WebView

Electron/Tauri pakai native webview library. Pascak pakai **browser yang sudah ada di device** — Chrome, Firefox, Safari, Edge.

Arsitektur:

    [Script Pascak]
         |
         |-- HTTP server (localhost:8080) → serve HTML/CSS/JS
         |-- WS server (localhost:8081)   → RPC bridge
         |-- Spawn browser via termux-open-url / xdg-open
         |
    [Browser] → tampil UI, WS call ke server → return ke script

**Keunggulan:**
- ✅ **Zero dependency** — tidak butuh GTK/Qt/CEF
- ✅ **Cross-platform** — Windows/Linux/Android/macOS sama
- ✅ **UI universal** — HTML/CSS/JS skill
- ✅ **Ringan** — ~5 MB binary vs ~100 MB Electron
- ✅ **Aman** — browser sandbox (JS tidak bisa akses filesystem langsung)

**Keterbatasan:**
- ❌ Butuh browser installed (biasanya ada)
- ❌ Localhost only (tidak bisa remote)
- ❌ Satu app per proses
- ❌ Tidak ada native window controls

### 27.2 — Quick Start: Hello GUI

    begin
      sys.execWhitelist(["termux-open-url", "xdg-open"]);

      var h := gui.create(8080, 8081, "My App");

      gui.bind(h, "add", lambda args : args[0] + args[1]);

      gui.serve(h, "<html><body>" +
        "<h1>Hello GUI!</h1>" +
        "<button onclick='go()'>Add 3 + 4</button>" +
        "<script>" +
        "async function go(){" +
        "  var v = await window.pascak.call('add', [3, 4]);" +
        "  alert('Result: ' + v);" +
        "}" +
        "</script>" +
        "</body></html>");

      gui.start(h);
      gui.open(h);
      gui.run(h);
    end.

**Yang terjadi:**
1. `gui.create` — buat instance, return handle
2. `gui.bind` — daftarkan function `add` callable dari JS
3. `gui.serve` — set HTML content
4. `gui.start` — bind HTTP :8080 + WS :8081
5. `gui.open` — spawn browser ke `http://localhost:8080/`
6. `gui.run` — event loop blocking

Setelah `gui.open`, browser terbuka dengan UI. Klik tombol → JS panggil `window.pascak.call('add', [3, 4])` → WS kirim ke server → server panggil `add` function → return 7 → alert tampil.

### 27.3 — gui.create(port, [wsPort], [title]) → handle

    var h := gui.create(8080);                          // default wsPort=8081, title="Pascak GUI"
    var h := gui.create(8080, 8082);                    // custom wsPort
    var h := gui.create(8080, 8081, "My Todo App");     // custom title

**Parameter:**

| Param | Tipe | Default | Deskripsi |
|-------|------|---------|-----------|
| `port` | int | wajib | HTTP port (1..65535) |
| `wsPort` | int | port+1 | WebSocket port |
| `title` | string | "Pascak GUI" | Default HTML `<h1>` |

**Return:** handle (int ≥ 1) atau `-1` on error.

**Handle** dipakai untuk semua API GUI berikutnya. Bisa punya multiple GUI app — tapi v1 hanya 1 yang aktif (last-created = active).

### 27.4 — gui.serve(handle, html) → bool

Set HTML content. Bisa dipanggil sebelum atau sesudah `gui.start`.

    var html := "<html><body>" +
      "<h1>My App</h1>" +
      "<p>Build with Pascak</p>" +
      "</body></html>";

    gui.serve(h, html);

**Behavior:**
- **Auto-inject** `<script>` block sebelum `</body>` untuk expose `window.pascak.call`
- Content-Type otomatis `text/html; charset=utf-8`
- Kalau tidak ada `</body>`, script di-append di akhir

**Return:** `true` kalau berhasil.


### 27.5 — gui.bind(handle, name, callback) → bool

Daftarkan server-side function yang callable dari JavaScript via `window.pascak.call(name, argsArray)`.

    gui.bind(h, "add", lambda args : args[0] + args[1]);
    gui.bind(h, "greet", lambda args : "Halo, " + args[0] + "!");
    gui.bind(h, "fetchUser", lambda args : fetchUserById(args[0]));

**Signature callback:** `function(args: array) → any`

**PENTING**: callback menerima **satu argumen** — array berisi semua argumen dari JS.

    // JS call:
    window.pascak.call('add', [3, 4])
    // Server callback: lambda args : args[0] + args[1]
    //                  args = [3, 4]
    //                  return 7

    // JS call no args:
    window.pascak.call('ping', [])
    // Server callback: lambda args : "pong"
    //                  args = []

**Return value**: JSON-serializable (number, string, boolean, dict, array, null).

**Error handling** — kalau callback throw:

    gui.bind(h, "risky", lambda args : begin
      if args[0] < 0 then
        throw("negative not allowed");
      return args[0] * 2
    end);

    // JS:
    try {
      var v = await window.pascak.call('risky', [-5]);
    } catch (e) {
      console.log('Error:', e.message);   // "negative not allowed"
    }

### 27.6 — gui.open(handle) → bool

Spawn browser ke `http://localhost:{port}/`.

    gui.open(h);

**Strategi spawn (fallback chain):**
1. `termux-open-url URL` (Android/Termux)
2. `xdg-open URL` (Linux)
3. `open URL` (macOS)

**Requirements**: binary di exec whitelist.

    sys.execWhitelist(["termux-open-url", "xdg-open", "open"]);

**Return:**
- `true` — salah satu spawn sukses
- `false` — semua spawn gagal (buka URL manual di browser)

**Manual fallback**: buka browser sendiri ke `http://localhost:8080/`.

### 27.7 — gui.start(handle) → bool

Bind HTTP + WS listener. Non-blocking.

    gui.start(h);

**Behavior:**
- HTTP bind ke `127.0.0.1:{port}` (loopback only — tidak bisa diakses network)
- WS serve + `ws.listenAsync` (event mode)
- Spawn poll timer 20ms untuk HTTP accept loop
- Return immediately

**Kenapa 127.0.0.1 bukan 0.0.0.0?**
- Security — GUI hanya untuk local user, bukan publik
- Termux Android sering reject 0.0.0.0 untuk loopback

**Return:**
- `true` — semua listener bound
- `false` — port conflict / permission denied

### 27.8 — gui.run(handle)

Blocking event loop. Script menunggu sampai `gui.close` atau `sys.exit`.

    gui.run(h);

**Behavior:**
- Tick event loop (timer, WS, async callback)
- Block sampai shutdown
- Return void

**Kapan selesai:**
- `gui.close(h)` dipanggil
- `sys.exit(code)`
- SIGINT/SIGTERM

**Kombinasi timer:**

    setTimeout(lambda : begin
      println("auto-close in 5s");
      gui.close(h);
    end, 5000);

    gui.run(h);   // blocking 5 detik, lalu close

### 27.9 — gui.close(handle) → bool

Graceful shutdown.

    gui.close(h);

**Cleanup yang dilakukan:**
1. Cancel poll timer
2. HTTP `StopRequested` flag
3. WS `StopRequested` flag + `RemoveServer` (dari event loop)
4. Free server entries
5. Free GUI state

**Return:** `true` kalau handle valid.

**Idempotent**: panggil dua kali aman — call kedua return `false`.


### 27.10 — Auto JS Injection

Setiap `gui.serve(h, html)` menyisipkan script ini sebelum `</body>`:

    <script>
    (function(){
      var ws = new WebSocket("ws://localhost:{wsPort}/");
      var pending = {};
      ws.onmessage = function(e){
        try {
          var m = JSON.parse(e.data);
          if (m.id && pending[m.id]) {
            pending[m.id](m);
            delete pending[m.id];
          }
        } catch(err) { console.error("[pascak] parse:", err); }
      };
      window.pascak = {
        call: function(method, args) {
          return new Promise(function(resolve, reject) {
            var id = Math.random().toString(36).slice(2);
            pending[id] = function(m) {
              if (m.error) reject(new Error(m.error));
              else resolve(m.result);
            };
            ws.send(JSON.stringify({
              id: id, method: method, args: args || []
            }));
          });
        }
      };
    })();
    </script>

**Exposed global:** `window.pascak.call(method, argsArray) → Promise`

**Anda tidak perlu include ini** — sudah otomatis.

**Cara pakai dari JS:**

    // Call server function
    var result = await window.pascak.call("add", [3, 4]);
    console.log(result);   // 7

    // Multiple parallel calls
    var [a, b, c] = await Promise.all([
      window.pascak.call("add", [1, 2]),
      window.pascak.call("add", [3, 4]),
      window.pascak.call("add", [5, 6])
    ]);

    // Error handling
    try {
      var v = await window.pascak.call("risky", [-5]);
    } catch (e) {
      alert("Error: " + e.message);
    }

### 27.11 — Contoh: Counter App (Server State)

Counter disimpan di server, dipanggil via RPC:

    var COUNTER := 0;

    begin
      sys.execWhitelist(["termux-open-url", "xdg-open"]);

      var h := gui.create(8080, 8081, "Counter");

      gui.bind(h, "get", lambda args : COUNTER);

      gui.bind(h, "increment", lambda args : begin
        COUNTER := COUNTER + 1;
        return COUNTER
      end);

      gui.bind(h, "decrement", lambda args : begin
        COUNTER := COUNTER - 1;
        return COUNTER
      end);

      gui.serve(h, "<html><body style='font-family:sans-serif;text-align:center;padding:50px'>" +
        "<h1>Counter</h1>" +
        "<h2 id='val' style='font-size:64px;color:#007bff'>0</h2>" +
        "<button onclick='inc()' style='padding:10px 30px;font-size:20px'>+1</button>" +
        "<button onclick='dec()' style='padding:10px 30px;font-size:20px'>-1</button>" +
        "<script>" +
        "async function refresh(){" +
        "  document.getElementById('val').textContent = await window.pascak.call('get', []);" +
        "}" +
        "async function inc(){" +
        "  await window.pascak.call('increment', []);" +
        "  refresh();" +
        "}" +
        "async function dec(){" +
        "  await window.pascak.call('decrement', []);" +
        "  refresh();" +
        "}" +
        "refresh();" +
        "</script></body></html>");

      gui.start(h);
      gui.open(h);
      gui.run(h);
    end.

**Key pattern:**
- `COUNTER` di server → persist antar call
- Button click → call → refresh — UI selalu sync dengan server
- Kalau user buka 2 tab, keduanya lihat counter yang sama

### 27.12 — Custom WS Port

Default `wsPort = port + 1`. Kalau port `8080` terpakai atau conflict, custom:

    var h := gui.create(9000, 9001);   // HTTP :9000, WS :9001

Auto JS injection otomatis pakai `wsPort` yang benar:

    ws = new WebSocket("ws://localhost:9001/");   // ← inject otomatis


### 27.13 — Contoh: Todo dengan SQLite

Server-side persistence, UI reactive:

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

      DB := sqliteConnect("todos.db");
      sqliteExec(DB, "CREATE TABLE IF NOT EXISTS todos (" +
                     "id INTEGER PRIMARY KEY AUTOINCREMENT, " +
                     "text TEXT, done INTEGER DEFAULT 0)");

      var h := gui.create(8080, 8081, "Todo");
      gui.bind(h, "list", lambda args : listTodos());
      gui.bind(h, "add", lambda args : addTodo(args[0]));
      gui.bind(h, "toggle", lambda args : toggleTodo(args[0]));
      gui.bind(h, "delete", lambda args : deleteTodo(args[0]));

      gui.serve(h, "<html><body style='font-family:sans-serif;max-width:600px;margin:40px auto;padding:20px'>" +
        "<h1>Todo</h1>" +
        "<input id='inp' placeholder='What to do?' style='width:70%;padding:8px'>" +
        "<button onclick='add()'>Add</button>" +
        "<ul id='list' style='list-style:none;padding:0'></ul>" +
        "<script>" +
        "async function render(todos){" +
        "  var ul = document.getElementById('list');" +
        "  ul.innerHTML = '';" +
        "  for (var t of todos) {" +
        "    var li = document.createElement('li');" +
        "    li.style.cssText = 'padding:10px;border-bottom:1px solid #eee;" +
        "      display:flex;justify-content:space-between;" +
        "      ' + (t.done ? 'text-decoration:line-through;color:#999' : '');" +
        "    li.innerHTML = '<span onclick=\\'toggle(' + t.id + ')\\' style=\\'cursor:pointer;flex:1\\'>' +" +
        "      t.text + '</span><button onclick=\\'del(' + t.id + ')\\'>X</button>';" +
        "    ul.appendChild(li);" +
        "  }" +
        "}" +
        "async function refresh(){ render(await window.pascak.call('list', [])); }" +
        "async function add(){" +
        "  var inp = document.getElementById('inp');" +
        "  if (!inp.value) return;" +
        "  await window.pascak.call('add', [inp.value]);" +
        "  inp.value = ''; refresh();" +
        "}" +
        "async function toggle(id){ await window.pascak.call('toggle', [id]); refresh(); }" +
        "async function del(id){ await window.pascak.call('delete', [id]); refresh(); }" +
        "refresh();" +
        "</script></body></html>");

      gui.start(h);
      gui.open(h);
      gui.run(h);

      sqliteClose(DB);
    end.

**Full example:** `examples/todo_gui.pas` (124 lines).

### 27.14 — Contoh: Chat Multi-User

Polling-based chat (v1 tidak support server→client push):

    var MESSAGES := [];

    function getMessages(since) begin
      var result := [];
      var i := since;
      while i < len(MESSAGES) do begin
        push(result, MESSAGES[i]);
        i := i + 1;
      end;
      return {"messages": result, "total": len(MESSAGES)}
    end;

    function sendMessage(user, text) begin
      push(MESSAGES, {
        "user": user, "text": text, "ts": time.now()
      });
      return true
    end;

    begin
      sys.execWhitelist(["termux-open-url", "xdg-open"]);

      var h := gui.create(8080, 8081, "Chat");

      gui.bind(h, "getMessages", lambda args : getMessages(args[0]));
      gui.bind(h, "sendMessage", lambda args : sendMessage(args[0], args[1]));

      gui.serve(h, "<html><body style='font-family:sans-serif;max-width:600px;margin:40px auto;padding:20px'>" +
        "<h1>Chat</h1>" +
        "<div id='msgs' style='border:1px solid #ccc;height:300px;overflow-y:auto;padding:10px'></div>" +
        "<input id='user' placeholder='Your name' value='Guest' style='width:100px;padding:6px'>" +
        "<input id='msg' placeholder='Message' style='width:60%;padding:6px'>" +
        "<button onclick='send()'>Send</button>" +
        "<script>" +
        "var lastCount = 0;" +
        "async function poll(){" +
        "  var r = await window.pascak.call('getMessages', [lastCount]);" +
        "  for (var m of r.messages) {" +
        "    var div = document.getElementById('msgs');" +
        "    div.innerHTML += '<div><b>' + m.user + ':</b> ' + m.text + '</div>';" +
        "    div.scrollTop = div.scrollHeight;" +
        "  }" +
        "  lastCount = r.total;" +
        "}" +
        "async function send(){" +
        "  var u = document.getElementById('user').value;" +
        "  var m = document.getElementById('msg').value;" +
        "  if (!m) return;" +
        "  await window.pascak.call('sendMessage', [u, m]);" +
        "  document.getElementById('msg').value = '';" +
        "  poll();" +
        "}" +
        "setInterval(poll, 500);" +
        "poll();" +
        "</script></body></html>");

      gui.start(h);
      gui.open(h);
      gui.run(h);
    end.

**Full example:** `examples/chat_gui.pas` (131 lines).

### 27.15 — Pattern: Native Callback Integration

GUI + RegisterNative (kalau host app):

    // Host Pascal code
    function MyNativeFeature(const Args: TNativeValueArray): TNativeValue;
    begin
      // ... akses native resource ...
      Result := NVStr('native result');
    end;

    RegisterNative('nativeFeature', @MyNativeFeature);

    // Script:
    gui.bind(h, "runNative", lambda args : nativeFeature(args[0]));


### 27.16 — Batasan v1

| Fitur | Status |
|-------|--------|
| HTTP + WS RPC | ✅ |
| Auto JS injection | ✅ |
| Browser spawn | ✅ (butuh exec whitelist) |
| HTTPS | ❌ (localhost only, tidak ada cert) |
| Multi-window | ❌ (satu GUI per proses) |
| Native window | ❌ (browser only) |
| Server→client push | ❌ (pakai polling) |
| File upload | ⚠️ (via `req["body"]`, max 10MB) |
| Auth | ❌ (localhost, tidak butuh) |
| Custom favicon | ❌ (default browser) |

**Workarounds:**

- **Server→client push**: polling 100ms–500ms. Kalau butuh realtime, buka WS sendiri via `ws.connect` atau `ws.serve` terpisah.
- **HTTPS**: tidak perlu untuk localhost — browser treat `localhost` sebagai secure context.
- **Multi-window**: buka tab baru via `window.open()`, share state via RPC.
- **File upload**: `gui.bind` menerima string; file biner via `base64Encode` di JS.

### 27.17 — Kapan Pakai GUI Browser-Based

**Cocok untuk:**
- ✅ Tools internal (dashboard, admin panel, debug UI)
- ✅ Editor / text tools
- ✅ Data viewer (SQLite, JSON, log)
- ✅ Game state debugger
- ✅ Prototype aplikasi desktop
- ✅ Cross-device app (buka di HP, tablet, laptop — asal satu network)

**Tidak cocok untuk:**
- ❌ Game realtime (render loop di JS via canvas → bisa, tapi butuh setup)
- ❌ Native OS integration (system tray, notification native, dll)
- ❌ Performance-critical UI (webview overhead)
- ❌ Fully offline (butuh browser)

### 27.18 — Ringkasan GUI API

| API | Signature | Return |
|-----|-----------|--------|
| `gui.create` | `(port, [wsPort], [title])` | `handle` |
| `gui.serve` | `(handle, html)` | `bool` |
| `gui.bind` | `(handle, name, callback)` | `bool` |
| `gui.open` | `(handle)` | `bool` |
| `gui.start` | `(handle)` | `bool` |
| `gui.run` | `(handle)` | `null` (blocking) |
| `gui.close` | `(handle)` | `bool` |

**JS bridge:** `window.pascak.call(method, argsArray) → Promise`

**4 contoh tersedia:**
- `examples/hello_gui.pas` — counter basic (82 lines)
- `examples/todo_gui.pas` — SQLite CRUD (124 lines)
- `examples/chat_gui.pas` — multi-user polling (131 lines)
- `examples/embed_inproc.pas` — host embedding (native callback)

**Kombinasi powerful:**
- GUI + SQLite → data-driven app
- GUI + HTTP client → consume external API
- GUI + FFI → akses native library
- GUI + Coroutine → background tasks dengan timer

### 27.19 — GUI dengan HTTPS (TLS)

Mulai **v0.7.0**, GUI module mendukung HTTPS + WSS via `gui.createTLS`.
Berguna untuk:

- Browser modern yang **wajib** HTTPS untuk `getUserMedia`, `serviceWorker`, `clipboard`
- Testing skenario `wss://` production-like
- LAN access dari device lain (HP/tablet connect ke GUI yang jalan di laptop)

#### Generate Cert (Self-Signed, Dev)

    openssl req -x509 -newkey rsa:2048 \
      -keyout ~/server.key -out ~/server.crt \
      -days 365 -nodes -subj "/CN=localhost" \
      -addext "subjectAltName=DNS:localhost,IP:127.0.0.1"

Hasil: `~/server.crt` (~1 KB) + `~/server.key` (~1.7 KB). Expired dalam 365 hari.

#### Server HTTPS

Ganti `gui.create` → `gui.createTLS`:

    var home := sys.env("HOME");
    var h := gui.createTLS(8090,
      home + "/server.crt",
      home + "/server.key",
      8091,                     // WS port (optional)
      "Counter TLS");           // title (optional)

    gui.bind(h, "add", lambda args : args[0] + args[1]);
    gui.serve(h, "<html>...<button onclick='go()'>+1</button>...</html>");

    gui.start(h);
    gui.open(h);       // spawn browser ke https://localhost:8090/
    gui.run(h);

**Yang terjadi otomatis:**

| Komponen | Protokol |
|----------|----------|
| HTTP listener | `https://localhost:8090/` |
| WS listener | `wss://localhost:8091/` |
| `gui.open()` URL | `https://localhost:8090/` |
| Auto-inject JS | `new WebSocket("wss://...")` |

**Tidak ada kode JS yang berubah** — semua `window.pascak.call()` tetap sama.

#### Test dengan curl

    curl -k https://localhost:8090/
    # HTML dengan wss:// di auto-inject script

    curl -k -o /dev/null -w "%{http_code}\n" https://localhost:8090/
    # 200

`-k` = ignore self-signed cert warning.

#### Buka di Browser

Buka `https://localhost:8090/` di browser → warning "Not secure" (self-signed):

- **Chrome/Edge**: klik **Advanced** → **Proceed to localhost (unsafe)**
- **Firefox**: klik **Advanced** → **Accept the Risk and Continue**
- **Safari**: klik **Show Details** → **visit this website** → **Visit Website**

Warning muncul **sekali per host**. Setelah accept, GUI berjalan normal.

#### Kapan Butuh TLS?

| Use case | Butuh TLS? |
|----------|-----------|
| Admin dashboard internal (localhost) | ❌ Optional |
| App yang butuh `getUserMedia` (kamera/mic) | ✅ Wajib |
| App yang butuh `serviceWorker` (offline) | ✅ Wajib |
| App yang butuh `clipboard.writeText()` | ✅ Wajib (Chrome) |
| Testing `wss://` production | ✅ Wajib |
| LAN access dari HP/tablet | ✅ Wajib (atau self-signed trust) |

#### Perbandingan

| Aspek | `gui.create` | `gui.createTLS` |
|-------|-------------|-----------------|
| HTTP | `http://localhost:PORT/` | `https://localhost:PORT/` |
| WS | `ws://localhost:WSPORT/` | `wss://localhost:WSPORT/` |
| Cert | Tidak butuh | Wajib (PEM + key) |
| Browser warning | Tidak ada | Sekali per host |
| Browser API access | Terbatas | Full (secure context) |
| Setup cost | 0 detik | ~5 detik (generate cert) |

#### Production Notes

**Self-signed cert cukup untuk dev/lokal**. Untuk production LAN access, pilihan:

1. **Custom CA** — generate CA root, install di device target, issue leaf cert
2. **mkcert** — tool lokal yang auto-generate CA + cert per domain (`mkcert localhost 127.0.0.1 ::1`), install CA di browser
3. **Reverse proxy** — GUI tetap HTTP localhost, reverse proxy (nginx/caddy) handle TLS publik

Untuk production deployment GUI ke **banyak device**, rekomendasi: pakai **mkcert** (browser trust CA-nya) atau reverse proxy.

#### Limitations v0.7.0

| Fitur | Status |
|-------|--------|
| HTTPS + WSS self-signed | ✅ |
| Custom CA / trusted cert | ✅ (drop-in cert + key) |
| Cert hot-reload | ❌ (restart needed) |
| Mutual TLS (client cert) | ❌ |
| ALPN / HTTP/2 untuk GUI | ❌ (pakai HTTP/1.1) |

**Full example:** `examples/todo_gui_tls.pas` — 120 lines, Todo dengan HTTPS + SQLite.

**Cheat sheet:**

    // Dev (HTTP)
    var h := gui.create(8080, 8081, "App");

    // Dev/prod-lokal (HTTPS + WSS)
    var cert := sys.env("HOME") + "/server.crt";
    var key  := sys.env("HOME") + "/server.key";
    var h := gui.createTLS(8080, cert, key, 8081, "App");


---

## Bab 28 — Native GUI (SDL2)

Bab 27 sudah bahas browser-based GUI. Bab ini bahas **native GUI** — window desktop real via SDL2 FFI, tanpa browser.

### 28.1 — Konsep: Native vs Browser

Pascak punya dua GUI stack yang bisa dipakai bersamaan:

| Aspek | `gui` (browser) | `gui2` (native SDL2) |
|-------|-----------------|----------------------|
| Render | HTML/CSS di browser | Pixel via SDL_Renderer |
| API call | `window.pascak.call()` | `gui2.text()`, `gui2.rect()` |
| Transport | HTTP + WebSocket | X11/Wayland display |
| Cross-platform | Universal | Linux/Windows/macOS/Termux:X11 |
| Latency per-call | ~1–5 ms (WS RPC) | ~0.1 ms (frame loop) |
| Game/realtime | Terbatas | Full 60+ FPS |
| Distribution | Browser included | Butuh SDL2 runtime |
| Distribution size | 0 KB (browser) | ~3–5 MB (SDL2 libs) |

**Kapan pakai `gui2`** — game, realtime UI, tool native, embed di host app, dashboard low-latency, live chart.
**Kapan pakai `gui`** — dashboard admin, CRUD form, app universal (mobile web), deployment zero-dependency.

Keduanya bisa dipakai di satu script — `gui` untuk admin panel di port 8080, `gui2` untuk overlay native di monitor lokal.

### 28.2 — Prerequisites Termux

Install SDL2 + display server:

    pkg install sdl2 sdl2-ttf x11-repo termux-x11-nightly x11-utils

Install **Termux:X11 APK** dari https://github.com/termux/termux-x11/releases/tag/nightly (pilih `termux-x11-universal-debug.apk`).

Setup:

    # Terminal 1 — start X11 server (biarkan foreground)
    termux-x11 :0 -ac

    # Terminal 2 — set display
    export DISPLAY=:0
    xdpyinfo | head -3

Buka **app Termux:X11** dari home screen Android → connect ke `:0`.

Verify: `xdpyinfo` harus print `name of display: :0` dan `X.Org version`.

Fonts (untuk text rendering):

    pkg install ttf-dejavu
    # atau pakai /system/fonts/Roboto-Regular.ttf

### 28.3 — Quick Start: Hello Window

    begin
      if not gui2.init() then sys.exit(1);
      if not gui2.window("Hello", 640, 480) then sys.exit(1);

      while gui2.isOpen() do begin
        var ev := gui2.poll();
        if ev == "quit" or ev == "key:ESC" then break;
        gui2.clear(50, 50, 150);   { dark blue }
        gui2.present();
        gui2.delay(16);            { ~60 FPS }
      end;

      gui2.close();
      gui2.quit();
    end.

Run:

    PASCAK_EXEC_POLICY=allow-all ./pascak_noASTnet --dev hello.pas

Window 640×480 biru muncul. ESC atau klik X → close.

**Struktur minimal**:
1. `init` — SDL_Init(VIDEO) + load libSDL2
2. `window` — create window + renderer
3. Loop: `poll` → `clear` → draw → `present` → `delay`
4. `close` + `quit` — cleanup


### 28.4 — Window Lifecycle

| API | Return | Deskripsi |
|-----|--------|-----------|
| `gui2.init()` | bool | SDL_Init(VIDEO). Idempotent. |
| `gui2.window(title, w, h)` | bool | Create window + renderer. |
| `gui2.isOpen()` | bool | True jika window masih terbuka. |
| `gui2.close()` | bool | Destroy window + renderer (SDL tetap init). |
| `gui2.quit()` | bool | Destroy semua + SDL_Quit. |

Contoh satu window seumur script:

    if not gui2.init() then sys.exit(1);
    if not gui2.window("App", 800, 600) then sys.exit(1);
    { ... event loop ... }
    gui2.close();
    gui2.quit();

**Catatan**: `gui2.window` hanya bisa dipanggil sekali sampai `close`. Kalau butuh multiple window, tutup dulu lalu buka window baru (v1 limit).

### 28.5 — Rendering Loop

| API | Deskripsi |
|-----|-----------|
| `gui2.clear(r, g, b, [a])` | Set draw color + clear renderer. `a` default 255. |
| `gui2.present()` | Flip back buffer ke screen. |
| `gui2.delay(ms)` | SDL_Delay, biasanya 16 ms (60 FPS) atau 33 ms (30 FPS). |
| `gui2.getTicks()` | Milliseconds sejak SDL_Init. Untuk timing, FPS counter, auto-close timer. |
| `gui2.setTitle(title)` | Ubah window title saat runtime. |

Pola frame loop standar:

    var start := gui2.getTicks();
    while gui2.isOpen() do begin
      if (gui2.getTicks() - start) > 10000 then break;   { auto-close 10s }
      { ... poll + draw ... }
      gui2.present();
      gui2.delay(16);
    end;

### 28.6 — Drawing Primitives

| API | Backing SDL2 |
|-----|--------------|
| `gui2.rect(x, y, w, h, r, g, b)` | `SDL_RenderFillRect` |
| `gui2.outlineRect(x, y, w, h, r, g, b)` | `SDL_RenderDrawRect` |
| `gui2.line(x1, y1, x2, y2, r, g, b)` | `SDL_RenderDrawLine` |
| `gui2.point(x, y, r, g, b)` | `SDL_RenderDrawPoint` |

Contoh layout 3 kotak:

    gui2.clear(30, 40, 80);
    gui2.rect(50, 50, 200, 100, 200, 60, 60);           { filled red }
    gui2.outlineRect(300, 50, 200, 100, 60, 200, 60);   { green border }
    gui2.line(50, 200, 750, 550, 250, 250, 100);        { yellow diagonal }
    var i := 0;
    while i < 100 do begin
      gui2.point(100 + i, 300 + i, 250, 80, 250);
      i := i + 2;
    end;
    gui2.present();

**Warna**: `r, g, b` clamp 0–255. Tidak ada alpha via `rect` (selalu 255) — untuk transparansi, gunakan `clear(r, g, b, alpha)` background.

### 28.7 — Input Events

| API | Return | Deskripsi |
|-----|--------|-----------|
| `gui2.poll()` | string | Ambil 1 event, non-blocking. |
| `gui2.mouseX()` / `gui2.mouseY()` | int | Live cursor position. |
| `gui2.mouseButton(n)` | bool | `n`=1 left, 2 middle, 3 right. |
| `gui2.keyMod(name)` | bool | `"SHIFT"`, `"CTRL"`, `"ALT"`. |
| `gui2.keyName(code)` | string | Konversi numeric → `"ESC"`, `"A"`, `"UP"`. |

**Format return `poll()`**:

| String | Event |
|--------|-------|
| `"none"` | Tidak ada event |
| `"quit"` | Window closed (X button) |
| `"key:ESC"` / `"key:A"` / `"key:UP"` | Keydown |
| `"keyup:ESC"` | Keyup |
| `"mousedown:1"` / `"mousedown:3"` | Mouse button pressed |
| `"mouseup:1"` | Mouse button released |
| `"mousemove"` | Cursor moved |

Contoh event handling:

    var ev := gui2.poll();
    if ev == "quit" or ev == "key:ESC" then break;

    if ev == "mousedown:1" then begin
      var mx := gui2.mouseX();
      var my := gui2.mouseY();
      if mx >= 100 and mx < 200 and my >= 100 and my < 150 then
        println("Click in button!");
    end;

    if ev == "mousemove" and gui2.mouseButton(1) then
      println("Drag at " + str(gui2.mouseX()) + "," + str(gui2.mouseY()));

**Key codes umum** (`gui2.keyName`): `ESC`, `ENTER`, `SPACE`, `BACKSPACE`, `TAB`, `DELETE`, `UP`, `DOWN`, `LEFT`, `RIGHT`, `F1`–`F12`, `LCTRL`, `LSHIFT`, `LALT`, `A`–`Z`, `0`–`9`.

### 28.8 — Text Rendering (SDL_ttf)

Prereq: `pkg install sdl2-ttf`.

| API | Deskripsi |
|-----|-----------|
| `gui2.setFont(path, [size])` | Load TTF, size default 16. Path absolute atau sandbox-relative. |
| `gui2.text(x, y, str, r, g, b)` | Render string di posisi. |
| `gui2.measureText(str)` | Return `{w, h}` untuk layout. |

Contoh text + centering:

    var ok := gui2.setFont("/system/fonts/Roboto-Regular.ttf", 24);
    if not ok then begin
      println("font load failed");
      sys.exit(1);
    end;

    gui2.clear(30, 40, 80);
    gui2.text(50, 50, "Hello, Pascak!", 250, 250, 100);

    { Center text }
    var m := gui2.measureText("Centered");
    var cx := toInteger((800 - toInteger(m["w"])) / 2);
    gui2.text(cx, 400, "Centered", 250, 250, 250);

**Font fallback** (tutorial pattern):

    var loaded := false;
    if not loaded then loaded := gui2.setFont("/system/fonts/Roboto-Regular.ttf", 24);
    if not loaded then loaded := gui2.setFont(
      "/data/data/com.termux/files/usr/share/fonts/TTF/DejaVuSans-Bold.ttf", 24);
    if not loaded then begin println("no font"); sys.exit(1); end;


### 28.9 — Contoh: Counter Interaktif

Gabungan window + text + button + mouse:

    var COUNT := 0;

    function pointInRect(px, py, rx, ry, rw, rh) begin
      return px >= rx and px < rx + rw and py >= ry and py < ry + rh;
    end;

    begin
      if not gui2.init() then sys.exit(1);
      if not gui2.window("Counter", 800, 600) then sys.exit(1);

      var loaded := false;
      if not loaded then loaded := gui2.setFont(
        "/system/fonts/Roboto-Regular.ttf", 40);

      while gui2.isOpen() do begin
        var ev := gui2.poll();
        if ev == "quit" or ev == "key:ESC" then break;

        if ev == "mousedown:1" then begin
          var mx := gui2.mouseX();
          var my := gui2.mouseY();
          if pointInRect(mx, my, 200, 400, 150, 80) then
            COUNT := COUNT - 1
          else if pointInRect(mx, my, 450, 400, 150, 80) then
            COUNT := COUNT + 1
          else if pointInRect(mx, my, 325, 500, 150, 60) then
            COUNT := 0;
        end;

        gui2.clear(40, 50, 90);
        gui2.text(30, 30, "Counter Demo", 250, 250, 200);

        var countStr := str(COUNT);
        var m := gui2.measureText(countStr);
        var cx := toInteger((800 - toInteger(m["w"])) / 2);
        gui2.text(cx, 150, countStr, 250, 250, 100);

        gui2.rect(200, 400, 150, 80, 180, 60, 60);
        gui2.text(250, 415, "-", 255, 255, 255);
        gui2.rect(450, 400, 150, 80, 60, 180, 60);
        gui2.text(510, 415, "+", 255, 255, 255);
        gui2.rect(325, 500, 150, 60, 80, 80, 180);
        gui2.text(340, 515, "RESET", 255, 255, 255);

        gui2.present();
        gui2.delay(16);
      end;

      gui2.close();
      gui2.quit();
    end.

**File lengkap**: `examples/gui2_counter.pas` (~68 lines).

### 28.10 — Contoh: Mouse Paint

Canvas drawing dengan stroke replay:

    var STROKES := [];
    var COLORS := [
      {"r": 220, "g": 60,  "b": 60},
      {"r": 60,  "g": 220, "b": 60},
      {"r": 60,  "g": 60,  "b": 220}
    ];
    var colorIdx := 0;
    var lastX := -1;
    var lastY := -1;
    var drawing := false;

    { ... dalam loop ... }
    var ev := gui2.poll();
    var mx := gui2.mouseX();
    var my := gui2.mouseY();

    if ev == "mousedown:1" and my < 540 then begin
      drawing := true;
      lastX := mx;
      lastY := my;
    end;

    if ev == "mouseup:1" then begin
      drawing := false;
      lastX := -1;
    end;

    if ev == "mousemove" and drawing then begin
      var col := COLORS[colorIdx];
      push(STROKES, {"x1": lastX, "y1": lastY, "x2": mx, "y2": my,
                     "r": col["r"], "g": col["g"], "b": col["b"]});
      lastX := mx;
      lastY := my;
    end;

    { Replay all strokes }
    gui2.clear(30, 30, 40);
    var i := 0;
    while i < len(STROKES) do begin
      var s := STROKES[i];
      gui2.line(s["x1"], s["y1"], s["x2"], s["y2"],
                s["r"], s["g"], s["b"]);
      i := i + 1;
    end;
    gui2.present();

**File lengkap**: `examples/gui2_paint.pas` (~100 lines).

### 28.11 — Limitations v1

| Fitur | Status |
|-------|--------|
| Window + render loop | ✅ |
| Drawing (4 primitives) | ✅ |
| Keyboard + mouse | ✅ |
| Text (TTF) | ✅ |
| Multiple windows | ❌ (1 window per process) |
| Alpha blending (rect) | ❌ (hanya background) |
| Texture loading (PNG/JPG) | ❌ (butuh SDL_image) |
| Audio | ❌ (butuh SDL_mixer) |
| Native menu/dialog | ❌ |
| HiDPI scaling | ⚠️ manual |
| GPU acceleration | ⚠️ software fallback di Termux:X11 |

**Untuk kebutuhan lebih**: load langsung via `dll.load("libSDL2_image.so")` dan pakai `native.struct` untuk surface — sama seperti FFI patterns di Bab 10-12.

### 28.12 — Ringkasan API

| Kategori | Fungsi |
|----------|--------|
| **Window** | `init`, `window`, `isOpen`, `close`, `quit`, `setTitle` |
| **Render** | `clear`, `present`, `delay`, `getTicks` |
| **Draw** | `rect`, `outlineRect`, `line`, `point` |
| **Input** | `poll`, `mouseX`, `mouseY`, `mouseButton`, `keyMod`, `keyName` |
| **Text** | `setFont`, `text`, `measureText` |

**19 fungsi** — cukup untuk build dashboard, form, game sederhana, tool native.

**Examples siap-pakai**:
- `examples/hello_gui2.pas` — window minimal
- `examples/drawing_demo_gui2.pas` — grid + shapes
- `examples/input_demo_gui2.pas` — crosshair + click + keyboard log
- `examples/text_demo_gui2.pas` — colored text + measureText
- `examples/gui2_counter.pas` — click counter
- `examples/gui2_paint.pas` — mouse drawing

**Untuk browser-based GUI** (HTTP + WS), lihat Bab 27.
**Untuk HTTP/2 client**, lihat Bonus chapter.


### 28.13 — Multi-Window (v1.0.0)

Sejak v1.0.0, `gui2` mendukung **multi-window** — lebih dari satu
window aktif bersamaan, masing-masing dengan renderer independen.

Backward compatible: script single-window (`gui2.window()`) tetap
jalan tanpa perubahan.

#### 28.13.1 — Kapan Butuh Multi-Window

Single window cukup untuk 90% app. Multi-window cocok untuk:

| Use case | Contoh |
|----------|--------|
| IDE / editor | Editor + preview + console |
| Dashboard | Main panel + detail sidebar |
| Media app | Library + player |
| Debug tool | App + log viewer |
| Multi-monitor setup | Main + auxiliary |

**Cost**: lebih banyak RAM (tiap window = renderer context sendiri),
event handling lebih kompleks.

#### 28.13.2 — API Overview

| API | Return | Deskripsi |
|-----|--------|-----------|
| `gui2.newWindow(title, w, h)` | int ID (0=error) | Buat window baru, auto-focus |
| `gui2.focusWindow(id)` | bool | Set target draw berikutnya |
| `gui2.closeWindow(id)` | bool | Destroy window tertentu |
| `gui2.listWindows()` | array of int | Semua window ID aktif |
| `gui2.getFocusedWindow()` | int | Window ID yang sedang focus |

`gui2.window(title, w, h)` (single-window legacy) tetap bekerja —
internally panggil `newWindow`, return bool (bukan ID).

#### 28.13.3 — Quick Start: 2 Windows

    begin
      if not gui2.init() then sys.exit(1);

      var w1 := gui2.newWindow("Editor", 600, 400);
      var w2 := gui2.newWindow("Preview", 600, 400);
      if w1 == 0 or w2 == 0 then begin
        println("failed to create window");
        gui2.quit();
        sys.exit(1);
      end;

      var fontOK := false;
      if not fontOK then
        fontOK := gui2.setFont("/system/fonts/Roboto-Regular.ttf", 20);

      while gui2.isOpen() do begin
        var ev := gui2.poll();
        if ev == "quit" or ev == "key:ESC" then break;

        // Render W1 (editor)
        gui2.focusWindow(w1);
        gui2.clear(30, 40, 60);
        if fontOK then gui2.text(30, 30, "Editor", 240, 240, 100);
        gui2.present();

        // Render W2 (preview)
        gui2.focusWindow(w2);
        gui2.clear(40, 50, 70);
        if fontOK then gui2.text(30, 30, "Preview", 100, 240, 100);
        gui2.present();

        gui2.delay(16);
      end;

      gui2.close();
      gui2.quit();
    end.

Kedua window render independen per frame. Panggil `focusWindow`
sebelum draw untuk switch target.

#### 28.13.4 — Focus Model

**Konsep kunci**: semua draw function (`rect`, `text`, `clear`,
`present`, `drawTexture`, dll) **target ke focused window**.

    gui2.focusWindow(w1);
    gui2.text(10, 10, "Hello", 255, 255, 255);  // → muncul di w1

    gui2.focusWindow(w2);
    gui2.text(10, 10, "Hello", 255, 255, 255);  // → muncul di w2

**Default focus**: window terakhir dibuat (`newWindow` auto-focus).

**Query current**: `gui2.getFocusedWindow()` → ID int.

#### 28.13.5 — Input Events

`gui2.poll()` mengembalikan event dari **focused window** saja. Untuk
switch, panggil `focusWindow`:

    var ev := gui2.poll();
    if ev == "key:1" then gui2.focusWindow(w1);
    if ev == "key:2" then gui2.focusWindow(w2);

**Format event**: sama seperti single-window (`key:ESC`, `mousedown:1`,
`mousemove`, `quit`, dll).

**Catatan**: `quit` event muncul saat window yang di-focus ditutup OS
(klik X).

#### 28.13.6 — Cleanup Patterns

**Tutup satu window**:

    gui2.closeWindow(w2);   // w2 destroyed, focus auto-switch ke w1

**Tutup semua, SDL tetap init**:

    gui2.close();           // semua window destroyed, SDL masih ready

**Full shutdown**:

    gui2.quit();            // semua destroyed + SDL_Quit

`closeWindow` pada focused window auto-focus ke window pertama yang
tersisa di list.

#### 28.13.7 — Backward Compatibility

`gui2.window(title, w, h)` (legacy single-window) internally:
1. Cek belum ada window lain
2. Panggil `newWindow`
3. Return `bool` (bukan ID)

Existing script (`examples/hello_gui2.pas`, dll) jalan tanpa perubahan.
Kalau butuh ID untuk multi-window, pakai `gui2.newWindow()`.

#### 28.13.8 — Contoh: Editor + Preview

Pola IDE-like app (kirim data antara window):

    var EDITOR := 0;
    var PREVIEW := 0;
    var CONTENT := "Hello, world";

    begin
      if not gui2.init() then sys.exit(1);
      EDITOR := gui2.newWindow("Editor", 600, 400);
      PREVIEW := gui2.newWindow("Preview", 600, 400);

      gui2.setFont("/system/fonts/Roboto-Regular.ttf", 20);

      while gui2.isOpen() do begin
        var ev := gui2.poll();
        if ev == "quit" or ev == "key:ESC" then break;

        // Editor window
        gui2.focusWindow(EDITOR);
        gui2.clear(30, 30, 50);
        gui2.text(20, 20, "Editor: " + CONTENT, 240, 240, 100);
        gui2.present();

        // Preview window
        gui2.focusWindow(PREVIEW);
        gui2.clear(50, 40, 30);
        gui2.text(20, 20, CONTENT, 100, 240, 100);
        gui2.present();

        gui2.delay(16);
      end;

      gui2.close();
      gui2.quit();
    end.

**File lengkap**: `examples/gui2_multi_window.pas` (73 lines, keys
1/2 untuk switch focus).

#### 28.13.9 — Limitations (v1.0.0)

| Feature | Status |
|---------|--------|
| Multiple concurrent windows | ✅ |
| Focus switching | ✅ |
| Independent draw per window | ✅ |
| Per-window textures | ⚠️ shared renderer context |
| Per-window font | ⚠️ shared (satu font aktif) |
| Per-window audio | ✅ global (music + SFX) |
| Window position | ❌ auto-positioned |
| Window resize | ❌ fixed at creation |
| Modal dialogs | ❌ separate feature |
| Drag-and-drop | ❌ |

**Untuk production multi-window app**: keep ukuran window konsisten,
pakai focus untuk switching, cache konten yang di-draw per window
kalau performance critical.

**Lihat juga**: `examples/gui2_multi_window.pas` — demo 2 window
dengan warna distinct (merah/hijau) + keyboard focus switch.

## Bab 29 — Optional Chaining & Null-Coalescing

Access property dari value yang mungkin `null` adalah source of crash di banyak bahasa. Pascak v1.1.0 tambah dua operator untuk handle ini dengan elegan.

### 29.1 — The Problem

Tanpa kedua operator ini, navigasi dict nested rawan:

    begin
      var cfg := {"db": null};
      var host := cfg["db"]["host"];  // RUNTIME ERROR: null has no [key]
    end.

Cek manual di setiap level — verbose dan error-prone:

    begin
      var cfg := {"db": null};
      var host := null;
      if cfg <> null and cfg["db"] <> null then
        host := cfg["db"]["host"];
    end.

### 29.2 — Optional Chaining `?.`

`?.` short-circuit kalau target `null`. Kalau `null`, expression return `null` (tidak error):

    begin
      var u := {"name": "Alice"};
      println(u?.name);       // "Alice"

      var n := null;
      println(n?.name);       // null (bukan crash)

      var cfg := {"db": null};
      println(cfg?.db?.host); // null (short-circuit di ?.db)
    end.

Chain `?.` aman untuk kedalaman berapa pun — begitu salah satu level `null`, semua sisa chain di-skip dan hasil akhir `null`.

### 29.3 — Null-Coalescing `??`

`a ?? b` return `a` kalau `a` bukan `null`, selain itu return `b`:

    begin
      println(null ?? 42);    // 42
      println(0 ?? 42);       // 0    (0 bukan null)
      println("" ?? "def");   // ""   (empty string bukan null)
      println(false ?? 42);   // false (false bukan null)
    end.

**Penting**: `??` **hanya** cek `null`, bukan falsy value. `0`, `""`, `false` semua considered valid (return as-is). Untuk fallback pada falsy juga, pakai ternary `?:`:

    begin
      var val := 0;
      var safe := val ?: 42;  // 42 karena 0 falsy (ternary, bukan ??)
    end.

### 29.4 — Combining `?.` + `??`

Pattern paling umum: safe access + fallback default:

    begin
      var cfg := {"db": null};
      var host := cfg?.db?.host ?? "localhost";
      println(host);          // "localhost"

      var cfg2 := {"db": {"host": "prod.example.com"}};
      var host2 := cfg2?.db?.host ?? "localhost";
      println(host2);         // "prod.example.com"
    end.

### 29.5 — Null-Safe Assignment (v1.6.2)

`obj?.prop := value` assigns only if target bukan null:

    var o := {"x": 1};
    o?.x := 42;
    println(o.x);         // 42

    var n := null;
    n?.x := 99;           // no-op, no crash
    println("ok");        // ok

**Short-circuit RHS** - RHS tidak dievaluasi kalau target null:

    var cnt := 0;
    function bump() begin cnt := cnt + 1; return 1; end;

    var n := null;
    n?.y := bump();       // bump() NOT called
    println(cnt);         // 0

    var o := {"y": 0};
    o?.y := bump();       // bump() called once
    println(cnt);         // 1

**Nested chain**:

    var cfg := {"db": {"host": "old"}};
    cfg?.db?.host := "new";       // assigned
    println(cfg.db.host);         // new

    var cfg2 := {"db": null};
    cfg2?.db?.host := "x";        // no-op, no crash

### 29.6 — Pitfalls

**1. `?.` di assignment tidak support**:

    u?.name := "Bob";   // SYNTAX ERROR

Pakai `if` explicit kalau perlu assign:

    if u <> null then
      u.name := "Bob";

**2. Precedence `??` lebih rendah dari `or`** — hati-hati chaining boolean:

    var x := a or b ?? c;   // parse sebagai a or (b ?? c)

Pakai parenthesis kalau ragu:

    var x := (a or b) ?? c;

**3. `?.` di method call tidak support (v1.1.0)**:

    u?.getName();       // SYNTAX ERROR

Workaround: extract property dulu, kemudian cek.

**File lengkap**: `examples/lang_v110.pas` — demo semua fitur v1.1.0.

---

## Bab 30 — Enum

Enum = symbolic constant dengan numeric auto-assign. Cocok untuk state machine, kategori, mode.

### 30.1 — Syntax

    enum Color { Red, Green, Blue }

    begin
      println(Color.Red);     // 0
      println(Color.Green);   // 1
      println(Color.Blue);    // 2
    end.

### 30.2 — Numeric Values

Member auto-numbered 0..N-1 (Pascal-like). Tidak bisa custom value di v1.1.0:

    enum Status { Pending, Active, Inactive }
    // Pending=0, Active=1, Inactive=2

### 30.3 — Accessing Members

Dua cara akses:

    // 1. Direct member access
    var c := Color.Green;
    println(c);             // 1

    // 2. Treat enum sebagai dict
    var all := Color;       // dict {Red:0, Green:1, Blue:2}
    println(all["Red"]);    // 0
    println(len(all));      // 3

### 30.4 — Immutable

Enum dideclare sebagai `const` — reassign akan error compile-time:

    Color := {"X": 99};     // COMPILE ERROR: Color is const

Tapi value yang di-extract **bisa** di-reassign (biasa untuk tipe numerik):

    var c := Color.Red;
    c := 99;                // OK — c adalah local var numeric

### 30.5 — Practical Patterns

**State machine**:

    enum State { Idle, Running, Done }

    var state := State.Idle;
    // ... proses ...
    state := State.Running;
    // ...
    state := State.Done;

**Iteration** (v1.1.0 belum support `for/in` untuk enum — pakai dict):

    for kv in Color do
      println(kv.key, " = ", kv.value);
    // Red = 0
    // Green = 1
    // Blue = 2

**File lengkap**: `examples/lang_v110.pas`.

---

### 30.6 — Enum di Function Scope (v1.2.0)

Sejak v1.2.0, enum boleh dideclare di dalam function atau block:

    function getStatus() begin
      enum Status { Pending, Active, Done }
      return Status.Active;
    end;

    begin
      println(getStatus());    // 1

      enum Local { X, Y, Z }
      println(Local.Z);        // 2
    end.

**Scope**: enum lokal hanya visible di function/block tempat dia
dideclare (sama seperti `var`). Tidak leaking ke outer scope.

**Cocok untuk**: state machine lokal per fungsi, konstanta helper
yang tidak perlu global.

## Bab 31 — Destructuring

Destructure dict atau array ke multiple variable dalam satu baris.

### 31.1 — Object Destructuring

    var {name, age} = {"name": "Alice", "age": 30};
    println(name);          // "Alice"
    println(age);           // 30

Parser desugar ke tiga deklarasi: satu temp `__pascak_dt_N` + dua variable `name` dan `age` (extract via `__pascak_dt_N.name` / `.age`). Zero overhead runtime — bytecode ekuivalen dengan manual.

### 31.2 — Array Destructuring

    var [x, y, z] = [10, 20, 30];
    println(x);             // 10
    println(y);             // 20
    println(z);             // 30

    // Partial — hanya ambil 2 dari 3 elemen (elemen ke-3 di-ignore)
    var [first, second] = [1, 2, 3];
    println(first);         // 1
    println(second);        // 2

### 31.3 — Top-level vs Statement Scope

Keduanya support:

    // Top-level (sebelum begin)
    var {cfg_host, cfg_port} = {"cfg_host": "localhost", "cfg_port": 8080};

    begin
      println(cfg_host);    // "localhost"

      // Statement-scope (di dalam begin)
      var {name, age} = {"name": "Bob", "age": 25};
      println(name);        // "Bob"
    end.

### 31.4 — Common Patterns

**Function return multiple values** (via dict):

    function getUser() begin
      return {"name": "Alice", "age": 30};
    end;

    var {name, age} = getUser();
    println(name, " is ", age);  // Alice is 30

**Extract nested dict** (kombinasi dengan `?.`):

    var cfg := {"db": {"host": "localhost", "port": 5432}};
    var {db} = cfg;              // db = {"host":"localhost","port":5432}
    println(db?.host);           // "localhost"

**Const destructuring**:

    const {PI} = {"PI": 3.14159};
    // PI tidak bisa di-reassign

**Missing key → null** (defensive):

    var {missing} = {"other": 1};
    println(missing);            // null (bukan crash)

### 31.5 — Limitations (v1.1.0)

| Feature | Status |
|---------|--------|
| Object destructuring `var {a,b} = obj` | ✅ |
| Array destructuring `var [x,y] = arr` | ✅ |
| Top-level + statement scope | ✅ |
| Const destructuring | ✅ |
| Missing key → `null` (defensive) | ✅ |
| Extra elements (ignored) | ✅ |
| Nested `var {a: {b}} = obj` | ❌ v1.1.1+ |
| Rest `var {a, ...rest} = obj` | ❌ v1.1.1+ |
| Default `var {a = 10} = obj` | ❌ v1.1.1+ |

**File lengkap**: `examples/lang_v110.pas`.

---

### 31.6 — Default Values (v1.2.0)

Berikan fallback kalau key missing atau index out-of-bounds:

    var {a = 10, b = 20} = {"a": 1};
    println(a);       // 1  (key ada)
    println(b);       // 20 (key missing → default)

    var [x = 0, y = 100] = [42];
    println(x);       // 42
    println(y);       // 100 (index 1 out-of-bounds → default)

**Semantik**: default **hanya** dipakai kalau extracted value `null`.
Falsy value (`0`, `""`, `false`) **pass-through** tanpa fallback:

    var {n = 99, s = "default"} = {"n": 0, "s": ""};
    println(n);       // 0  (bukan 99)
    println(s);       // "" (bukan "default")

Kalau butuh fallback pada falsy juga, pakai ternary `?:`:

    var safe_n := (n ?: 99);

**Kombinasi dengan optional chaining**:

    var cfg := {"db": null};
    var {db = {"host": "localhost"}} = cfg;
    println(db.host);  // "localhost" (default dipakai karena db=null)

### 31.7 - Array Rest Element (v1.2.1)

Capture sisa elemen array dalam satu variabel:

    var [first, ...tail] = [10, 20, 30, 40];
    println(first);         // 10
    println(tail);          // [20, 30, 40]

    var [...all] = [5, 6, 7];
    println(all);           // [5, 6, 7]

    var [a, b, ...rest] = [1, 2, 3, 4, 5];
    println(a);             // 1
    println(b);             // 2
    println(rest);          // [3, 4, 5]

**Aturan**:
- Rest element harus di posisi terakhir
- Rest tidak boleh punya default value
- Rest pada array pendek -> slice kosong `[]` (bukan error):

    var [x, ...tail2] = [100];
    println(x);             // 100
    println(tail2);         // []

**Implementasi**: rest element desugar jadi `TArraySliceNode(temp, idx, nil, nil)` - reuse slice syntax `temp[idx:]` yang sudah ada. Tidak ada overhead runtime tambahan.

**Belum didukung (v1.2.2)**:
- Object rest: `var {a, ...rest} = obj` (butuh runtime dict.omit())
- Nested rest: `var [a, [b, ...r]] = arr`

### 31.8 — Nested Destructuring (v1.2.2)

Extract nilai dari nested dict/array dalam satu deklarasi. Root pattern harus objek ({..}):

    var {a: {b, c}} = {"a": {"b": 1, "c": 2}};
    println(b);    // 1
    println(c);    // 2

    var {p: [m, n]} = {"p": [30, 40]};
    println(m);    // 30
    println(n);    // 40

**Mixed flat + nested**:

    var {q: {r}, s} = {"q": {"r": 100}, "s": 200};
    println(r);    // 100
    println(s);    // 200

**Multiple nested**:

    var {u: [i, j], v: {k, l}} = {"u": [1, 2], "v": {"k": 3, "l": 4}};
    println(i);    // 1
    println(l);    // 4

**Nested with default**:

    var {w: {z = 42}} = {"w": {}};
    println(z);    // 42

**Implementasi**: path disimpan sebagai string ("a.b" / "p.0"),
kemudian emit split di "." dan chain TMemberAccessNode /
TArrayAccessNode. Zero overhead runtime.

**Batasan (v1.2.2)**:
- Root harus objek: `var {..} = ...` (bukan `var [..] = ...`)
- Nested hanya 1 level: `{a: {b, c}}` OK, `{a: {b: {c}}}` = error
- Rest di dalam nested: belum support
- Array root nested: `var [a, {b}] = arr` = error

**Kombinasi nested + default (OK)**:

    var {a: {b = 10, c}} = {"a": {"c": 2}};
    // b = 10 (default, karena missing), c = 2

**Kombinasi nested + rest (error v1.2.2)**:

    var {a: {b, ...r}} = {"a": {"b": 1, "x": 2}};   // ERROR

### 31.9 — 2-Level Nested (v1.2.3)

Nested lebih dalam (2 level) untuk config pattern:

    var {p: {q: {r, s}}} = {"p": {"q": {"r": 10, "s": 20}}};
    println(r);    // 10
    println(s);    // 20

**Mixed 1-level sibling + 2-level**:

    var {u: {v}, w: {x: {y, z}}} =
      {"u": {"v": 100}, "w": {"x": {"y": 200, "z": 300}}};
    println(v);    // 100
    println(y);    // 200
    println(z);    // 300

**2-level dengan default**:

    var {m: {n: {o = 42, p2}}} = {"m": {"n": {"p2": 7}}};
    println(o);    // 42 (default)
    println(p2);   // 7

**2-level mixed obj → array**:

    var {cfg: {coords: [cx, cy]}} = {"cfg": {"coords": [1, 2]}};
    println(cx);   // 1
    println(cy);   // 2

**Batasan (v1.2.3)**:
- Root harus objek
- Max 2 level: `{a: {b: {c}}}` OK, `{a: {b: {c: {d}}}}` = error
- Array-root nested (var [a, {b}] = arr): belum support
- Rest di nested: belum support
- Object rest top-level: belum support

**Implementasi**: path disimpan flat dengan '.' separator
('p.q.r'), emit iterate split-by-dot dan chain member/array
access. Zero overhead runtime.

### 31.10 — Arbitrary Depth + Array-Root Nested (v1.2.4)

Sejak v1.2.4, nested destructuring **tidak dibatasi 2 level** dan **root boleh array**.

**Unlimited depth (obj-root)**:

    var {m: {n: {o: {u, v}}}} = {"m": {"n": {"o": {"u": 100, "v": 200}}}};
    println(u);    // 100
    println(v);    // 200

**Array-root nested**:

    var [a, {u, v}, c] = [10, {"u": 20, "v": 30}, 40];
    println(a);    // 10
    println(u);    // 20
    println(v);    // 30
    println(c);    // 40

**Array nested dalam array**:

    var [p, [q, r], s] = [1, [2, 3], 4];
    println(q);    // 2
    println(r);    // 3

**Kombinasi array nested + rest**:

    var [m, {n}, ...rest] = [100, {"n": 200}, 300, 400];
    println(m);     // 100
    println(n);     // 200
    println(rest);  // [300, 400]

**Array + 2-level obj nested**:

    var [x, {cfg: {h, pt}}] = [1, {"cfg": {"h": "host", "pt": 8080}}];
    println(h);     // "host"
    println(pt);    // 8080

**Implementasi**: recursive `ParsePattern` menyimpan flat path
('a.b.c.d') — unlimited depth. Emit iterate path split-by-dot,
chain access. Array index di path pakai format numeric.

**Batasan (v1.2.4)**:
- Object rest (var {a, ...rest} = obj): belum support (v1.2.5)
- Rest di dalam nested: belum support

### 31.11 — Object Rest (v1.2.5)

Capture sisa keys dari dict ke variabel baru:

    var {a, b, ...rest} = {"a": 1, "b": 2, "c": 3, "d": 4};
    println(a);           // 1
    println(b);           // 2
    println(rest);        // {"c": 3, "d": 4}

**Hanya rest (clone semua)**:

    var {...all} = {"x": 10, "y": 20};
    println(all.x);       // 10
    println(all.y);       // 20

**Empty rest (semua dikonsumsi)**:

    var {p, q, ...empty} = {"p": 1, "q": 2};
    println(empty.p);     // null (key 'p' sudah di-omit)

**Nested + rest** (rest excludes top-level key):

    var {cfg: {h}, ...rest2} = {"cfg": {"h": "localhost"}, "port": 8080};
    println(h);           // "localhost"
    println(rest2.port);  // 8080
    // rest2 tidak punya key 'cfg' (sudah di-extract nested)

**Runtime method `dict.omit(keys)`**:

Bisa juga dipakai manual (bukan hanya destructuring):

    var full := {"a": 1, "b": 2, "c": 3};
    var no_a := full.omit(["a"]);
    println(no_a);        // {"b": 2, "c": 3}

**Batasan (v1.2.5)**:
- Rest harus di posisi terakhir
- Rest di dalam nested (`{a: {b, ...r}}`): belum support (v1.2.6)
- Default tidak berlaku untuk rest

### 31.12 — Rest di Nested (v1.2.6)

Object rest bisa dipakai di dalam nested pattern:

    var {cfg: {host, ...rest}} =
      {"cfg": {"host": "h", "port": 80, "user": "u"}};
    println(host);          // "h"
    println(rest.port);     // 80
    println(rest.host);     // null (key 'host' sudah di-omit di level ini)

**2+ level nested rest**:

    var {a: {b: {x, ...r}}} = {"a": {"b": {"x": 1, "y": 2, "z": 3}}};
    println(x);       // 1
    println(r.y);     // 2
    println(r.z);     // 3

**Array + nested + rest**:

    var [first, {u, ...v}, last] = [10, {"u": 20, "w": 30}, 40];
    println(first);   // 10
    println(u);       // 20
    println(v.w);     // 30
    println(last);    // 40

**Array-nested di dalam obj + rest**:

    var {cfg: {items, ...others}} = {"cfg": {"items": [1, 2], "keep": true}};
    println(items);        // [1, 2]
    println(others.keep);  // true

**Semantik penting**: omit `rest` di nested hanya exclude key di level itu.

    var {a: {x, ...r}, b} = {"a": {"x": 1, "y": 2}, "b": 3};
    // r = {"y": 2} — r tidak punya key 'x', tapi juga tidak menyentuh 'b'
    // b = 3

**Implementasi**: path-aware emit — rest path di-split, target chain
dibangun bertingkat, numeric leaf → TArraySliceNode, string leaf →
omit() call dengan sibling names dari prefix path yang sama.

**Batasan (v1.2.6)**:
- Rest element harus di posisi terakhir dari pattern level-nya

### 31.13 — Optional Method Call ?.() (v1.2.7)

Method call via `?.()` short-circuit kalau target null:

    var obj := {"x": 1, "y": 2};
    println(obj?.hasKey("x"));      // true
    println(obj?.hasKey("zz"));     // false

    var n := null;
    println(n?.hasKey("x"));        // null (no crash)

**Dengan argumen**:

    var d := {"items": [1, 2, 3]};
    println(d?.keys());             // ["items"]
    println(n?.keys());             // null

**Short-circuit args** (argumen TIDAK dievaluasi kalau target null):

    var n := null;
    var r := n?.hasKey(n.undefined());   // null — n.undefined() tidak dipanggil
    // Kalau tidak short-circuit -> crash "call null as function"

Ini penting untuk performance (skip expensive arg) dan safety
(arg bisa side-effect/crash).

**Chain property + method**:

    var cfg := {"db": {"ping": null}};
    println(cfg?.db?.hasKey("ping"));    // true
    println(cfg?.missing?.hasKey("x"));  // null

**Method call tanpa ?. tetap jalan**:

    var d := {"x": 1};
    println(d.hasKey("x"));              // true (crash kalau null)

**Batasan (v1.2.7)**:
- Hanya method call (bukan constructor `new X?.()`)
- Single-call per `?.` (tidak support `obj?.a()?.b()` chained calls)

### 32 — Hot-Reload dengan --watch (v1.4.0)

Hot-reload untuk dev workflow: edit code -> auto-restart.

**Wrapper pattern**:

    while true; do
      pascak --dev --watch app.pas
      echo "restarting in 1s..."
      sleep 1
    done

**Behavior**:

    $ pascak --dev --watch app.pas
    [hot-reload] watching: app.pas
    [hot-reload] poll=500ms; file change -> exit(0)
    [boot] exec policy = allow-all
    === APP running ===

    # edit app.pas
    [hot-reload] detected change in: app.pas
    [hot-reload] exiting (0) — wrapper should restart process

**Deteksi**: mtime + size, poll 500ms. Cross-platform (no inotify needed).
Trade-off: 500ms delay max.

**Tanpa wrapper**: proses exit 0, tidak restart otomatis.

**Multi-file + directory watch (v1.4.1)**:

    # Single file
    pascak --dev --watch app.pas

    # Multi-file comma-separated
    pascak --dev --watch "app.pas,lib.pas,util.pas" app.pas

    # Directory — watch all *.pas inside (non-recursive)
    pascak --dev --watch src/ app.pas

    # Mixed: dir + extra file
    pascak --dev --watch "src/,extra.pas" app.pas

    # Wrapper loop
    while true; do
      pascak --dev --watch "src/,app.pas" app.pas
      sleep 1
    done

**Syntax**: `pascak --watch SPEC [script.pas]` — SPEC consumed as first
arg after `--watch`; script = next positional. Backward compat:
`--watch app.pas` (single-file spec, no explicit script) works as
before — SPEC auto-promoted to script.

**Browser auto-reload `--hot` (v1.4.2)**:

`--hot` = `--watch` + browser auto-reload:

    while true; do
      pascak --dev --hot "src/,app.pas" app.pas
      sleep 1
    done

**Flow**:
1. `--hot` activates watcher + JS injection
2. `gui.serve` injects script WS listener into HTML
3. Browser connects to WS (WSPort = HTTP port + 1)
4. File edit -> watcher detects -> broadcast reload message
5. Browser JS `location.reload()`
6. Wrapper restarts process -> fresh code live

**Batasan (v1.4.2)**:
- Proses exit, brief downtime ~1s
- State hilang tiap restart
- Directory watch non-recursive
- JS injection falls back to append if no closing body tag

### 31.13 — Function Param Destructuring (v1.6.0)

Function parameters can destructure directly:

    function f({a, b}, x) begin
      return a + b + x;
    end;
    println(f({"a": 1, "b": 2}, 3));    // 6

    function g([x, y]) begin
      return x + y;
    end;
    println(g([10, 20]));                // 30

**Nested + default**:

    function h({cfg: {port}, u, v = 5}) begin
      return port + u + v;
    end;
    println(h({"cfg": {"port": 80}, "u": 10}));   // 95

**Multiple patterns**:

    function two({x}, {y}) begin
      return x + y;
    end;
    println(two({"x": 100}, {"y": 200}));         // 300

**Mixed normal + pattern**:

    function mixed(a, {b, c}, d) begin
      return a + b + c + d;
    end;
    println(mixed(1, {"b": 2, "c": 3}, 4));       // 10

**Implementation**: parser detects pattern in param position, generates
synthetic `__fp_N`, injects `var {destructure} = __fp_N;` prelude at
body start. Zero overhead beyond equivalent manual destructuring.

**Rest element in param (v1.6.1)**:

    function f({a, b, ...rest}) begin
      return a + b + rest.c + rest.d;
    end;
    println(f({"a": 1, "b": 2, "c": 3, "d": 4}));    // 10

    function g([x, ...tail]) begin
      return x + len(tail);
    end;
    println(g([10, 20, 30, 40]));                     // 13

    function h({cfg: {port, ...other}}) begin
      return port + other.host;
    end;
    println(h({"cfg": {"port": 80, "host": 100}}));   // 180

Semantics match destructuring statement rest (v1.2.6).

**Batasan (v1.6.1)**:
- Rest must be at end of pattern (existing parser restriction)

**Dev wrapper tools/pascak_dev.sh (v1.8.0)**:

Production-grade wrapper combining graceful shutdown + auto-restart:

    # Basic usage
    tools/pascak_dev.sh app.pas app.pas

    # Watch multiple files with --hot
    tools/pascak_dev.sh 'src/,app.pas' app.pas --hot

    # Custom binary
    PASCAK_BIN=/path/to/pascak_noASTnet tools/pascak_dev.sh .

**Features**:
- Auto-restart on file change (exit 0) or error (exit 1/2)
- SIGINT/SIGTERM forwarded to child (graceful)
- 1s delay avoids TIME_WAIT on GUI ports
- Colored output
- PASCAK_BIN / RESTART_DELAY env overrides

**Graceful chain (v1.7.0 + v1.8.0)**:
1. Edit file -> watcher detects
2. IsShuttingDown -> gui.run returns
3. Shutdown hooks, WS clean close
4. Process exits 0 -> wrapper restarts fresh

Zero state leak, no port conflicts.

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
