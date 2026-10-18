# Pascak Cookbook

Composed patterns untuk task umum — **bukan** API reference atau tutorial.

## Apa Buku Ini?

Cookbook adalah kumpulan resep siap-pakai untuk masalah **task-level**:
"Bagaimana achieve X di production?" Bukan "Apa signature `http.serve`?"

Setiap resep:

- **Copy-paste ready** — satu file `.pas` yang langsung jalan
- **Composed** — kombinasi 3-5 module (HTTP + timer + dict + signal)
- **Cross-referenced** — link ke API dan Tutorial untuk detail feature
- **Production-oriented** — error handling, edge case, security

## Apa Buku Ini BUKAN?

Jika Anda mencari:

| Yang dicari | Buka |
|-------------|------|
| Signature fungsi / parameter | pascak_api.md |
| Belajar bahasa dari nol | tutorial.md |
| Pengenalan konsep | tutorial.md Bab 1-10 |
| Semua method satu modul | pascak_api.md |

Cookbook mengasumsikan Anda **sudah tahu dasar** (variabel, function,
loop, dict). Jika belum, mulai dari tutorial.md dulu.

## Konvensi

- **Path**: semua path file relatif ke direktori script (sandbox)
- **Error handling**: setiap recipe punya try/catch di titik yang bisa fail
- **Config**: pakai `config.get("KEY", "default")` — tidak hardcode
- **Logging**: pakai `log.info/warn/error` — tidak `println` untuk production
- **Exec policy**: recipe yang pakai `sys.exec` butuh `sys.execWhitelist`
  atau `allow-all`
- **Angka**: semua numeric = `double`. Untuk integer pakai `toInteger()`

## Legend Cross-Reference

Setiap resep punya line:

    API:      [fn](pascak_api.md#anchor) · [fn2](...)
    Tutorial: [Bab X](tutorial.md#anchor)

Ini memandu Anda ke reference kalau butuh detail signature.

## Daftar Resep

1. [Retry with exponential backoff](#1-retry-with-exponential-backoff) — HTTP client resilient
2. [Auth middleware layer](#2-auth-middleware-layer) — token validation + error handling
3. [Rate limiter per-IP](#3-rate-limiter-per-ip) — HTTP server + dict + metrics
4. [Circuit breaker](#4-circuit-breaker) — HTTP client + state + timer
5. [Graceful shutdown with in-flight drain](#5-graceful-shutdown-with-in-flight-drain) — signal + counter
6. [JWT-like token issuance](#6-jwt-like-token-issuance) — HMAC + base64 + expiry
7. [File upload validation](#7-file-upload-validation) — HTTP POST + size check
8. [Request batching + dedup](#8-request-batching--dedup) — async + cache
9. [Scheduled job runner](#9-scheduled-job-runner) — setInterval + SQLite + DLQ
10. [Broadcast backpressure](#10-broadcast-backpressure) — WS + queue + drop

---

## 1. Retry with exponential backoff

**Kapan pakai**: HTTP request ke external service yang bisa transient fail
(network blip, 503, rate limit). Jangan pakai untuk 4xx client error.

**Cross-ref**: http.get · math.pow · math.random · sleep

    function httpGetWithRetry(url, maxAttempts) begin
      var attempt := 1;
      var baseDelayMs := 500;
      var maxDelayMs := 30000;

      while attempt <= maxAttempts do begin
        try
          var r := http.get(url);
          if r["status"] >= 200 and r["status"] < 300 then
            return r;
          if r["status"] >= 400 and r["status"] < 500 then
            return r;  // 4xx: client error, no retry
        catch e do
          log.warn("attempt ", attempt, " failed: ", e.message);
        end;

        if attempt = maxAttempts then
          break;

        // exponential: 500, 1000, 2000, 4000, ...
        var delay := toInteger(baseDelayMs * math.pow(2, attempt - 1));
        if delay > maxDelayMs then
          delay := maxDelayMs;

        // jitter 0..delay/2 — cegah thundering herd
        var jitterMax := toInteger(delay / 2);
        var jitter := toInteger(math.random(jitterMax + 1));
        delay := delay + jitter;

        log.info("retry in ", delay, "ms (attempt ", attempt + 1, ")");
        sleep(delay);
        attempt := attempt + 1;
      end;

      throw("all ", maxAttempts, " attempts failed: " + url);
    end;

    begin
      var r := httpGetWithRetry("https://api.example.com/data", 5);
      println(r["status"]);
    end.

**Notes**:

- **Jangan retry 4xx** — client error, retry tidak akan berhasil
- **Jitter** — hindari thundering herd saat banyak client retry bersamaan
- **Cap maxDelayMs** — batasi agar tidak retry terlalu lama (max 30s)
- **Idempotent only** — GET/PUT/DELETE aman, POST tidak (bisa double-charge)
- **maxAttempts = 3-5** — lebih tinggi cuma memperpanjang outage

---

## 2. Auth middleware layer

**Kapan pakai**: HTTP server dengan endpoint yang butuh authentication.
Validasi token sebelum handler dijalankan, dengan skip untuk public route.

**Cross-ref**: http.serve · crypto.constantTimeEqual · crypto.hmacSha256

    var SECRET := config.get("AUTH_SECRET", "change-me-in-production");
    var PUBLIC_PATHS := ["/login", "/health", "/metrics"];

    function isPublic(path) begin
      for p in PUBLIC_PATHS do
        if path == p then
          return true;
      return false;
    end;

    function verifyToken(token) begin
      if token == null or typeOf(token) != "string" then
        return null;

      var parts := token.split(".");
      if len(parts) != 2 then
        return null;

      // Recompute HMAC, constant-time compare
      var expected := crypto.hmacSha256(SECRET, parts[0]);
      if not crypto.constantTimeEqual(expected, parts[1]) then
        return null;

      // parts[0] = base64({user, exp})
      var payload := jsonParse(base64Decode(parts[0]));
      if payload == null then
        return null;
      if toInteger(payload["exp"]) < time.now() then
        return null;  // expired

      return payload;  // {user, role, exp, ...}
    end;

    function withAuth(req, handler) begin
      if isPublic(req["path"]) then
        return handler(req, null);

      var token := req["headers"]["Authorization"];
      if token == null then
        return {"status": 401, "body": "missing Authorization"};
      if token.startsWith("Bearer ") then
        token := copy(token, 7, len(token) - 7);

      var user := verifyToken(token);
      if user == null then
        return {"status": 401, "body": "invalid or expired token"};

      return handler(req, user);
    end;

    function handler_dashboard(req, user) begin
      return {"status": 200, "body": "welcome, " + user["user"]};
    end;

    begin
      var srv := http.serve(8080, lambda req :
        withAuth(req, handler_dashboard));
      http.listenAsync(srv);
    end.

**Notes**:

- **Constant-time compare** — `crypto.constantTimeEqual` cegah timing attack
- **Never log token** — bahkan di error path
- **exp check** — selalu validasi expiry, jangan andalkan client
- **Skip public paths** — jangan require auth untuk `/login`, `/health`
- **HMAC not hash** — `hmacSha256` (bukan `sha256`) agar token tidak bisa forge
- **SECRET dari config** — jangan hardcode; rotate via `config.set`

---

## 3. Rate limiter per-IP

**Kapan pakai**: HTTP server yang butuh proteksi abuse — login brute-force,
API scraping, DDoS ringan. Sliding window counter per IP.

**Cross-ref**: http.serve · metrics.observe · dict (hasKey, remove)

    var BUCKETS := {};                    // ip -> {count, resetAt}
    var WINDOW_MS := 60000;               // 1 menit
    var MAX_REQUESTS := 60;               // 60 req/menit per IP
    var CLEANUP_EVERY_MS := 300000;       // 5 menit

    function allowRequest(ip) begin
      var now := toInteger(time.now() * 1000);   // time.now() = detik
      var entry := BUCKETS[ip];

      if entry == null or now >= toInteger(entry["resetAt"]) then begin
        BUCKETS[ip] := {"count": 1, "resetAt": now + WINDOW_MS};
        return true;
      end;

      if toInteger(entry["count"]) >= MAX_REQUESTS then
        return false;

      BUCKETS[ip] := {
        "count": toInteger(entry["count"]) + 1,
        "resetAt": toInteger(entry["resetAt"])
      };
      return true;
    end;

    function cleanupBuckets() begin
      var now := toInteger(time.now() * 1000);
      var keys := BUCKETS.keys();
      var removed := 0;
      for k in keys do begin
        var e := BUCKETS[k];
        if e != null and now >= toInteger(e["resetAt"]) then begin
          delete(BUCKETS, k);
          removed := removed + 1;
        end;
      end;
      if removed > 0 then
        log.debug("rate-limit cleanup: ", removed, " buckets removed");
    end;

    function rateLimitHandler(req) begin
      var ip := req["headers"]["X-Forwarded-For"];
      if ip == null then
        ip := "unknown";
      else begin
        var parts := ip.split(",");
        ip := trim(parts[0]);  // first hop
      end;

      if not allowRequest(ip) then begin
        metrics.increment("http_rate_limited_total", {"ip": ip});
        return {
          "status": 429,
          "headers": {"Retry-After": "60"},
          "body": "too many requests"
        };
      end;

      return {"status": 200, "body": "ok"};
    end;

    begin
      setInterval(cleanupBuckets, CLEANUP_EVERY_MS);
      var srv := http.serve(8080, rateLimitHandler);
      http.listenAsync(srv);
    end.

**Notes**:

- **Fixed window**, bukan sliding — cukup untuk 90% kasus; sliding butuh
  list timestamp per IP (memory 10× lebih besar)
- **X-Forwarded-For** — ambil hop pertama, hanya reliable di belakang proxy
  yang Anda kontrol. Kalau tidak, pakai `conn.peerIP`
- **Cleanup timer** — tanpa cleanup, dict bocor memory perlahan
- **429 + Retry-After** — standar HTTP untuk rate limit
- **Jangan lock global** — `BUCKETS` dict sudah thread-safe per-method
- **Metrics** — increment counter untuk observability

---

## 4. Circuit breaker

**Kapan pakai**: HTTP client ke dependency yang bisa down total (bukan
transient). Cegah request terus-menerus ke service yang jelas sedang mati,
beri waktu recovery.

**Cross-ref**: http.get · time.now · dict

State machine: `CLOSED` (normal) → `OPEN` (fail fast) → `HALF_OPEN` (probe).

    var CB := {
      "state": "CLOSED",         // CLOSED | OPEN | HALF_OPEN
      "failures": 0,
      "successes": 0,
      "openedAt": 0,
      "threshold": 5,            // 5 gagal berturut → OPEN
      "recoveryMs": 30000,       // 30s di OPEN sebelum HALF_OPEN
      "probeSuccesses": 2        // 2 sukses di HALF_OPEN → CLOSED
    };

    function cbBeforeCall() begin
      var now := toInteger(time.now() * 1000);
      if CB["state"] == "OPEN" then begin
        if now - toInteger(CB["openedAt"]) >= toInteger(CB["recoveryMs"]) then
          CB["state"] := "HALF_OPEN";
        else
          throw("circuit open — service unhealthy");
      end;
    end;

    function cbOnSuccess() begin
      if CB["state"] == "HALF_OPEN" then begin
        CB["successes"] := toInteger(CB["successes"]) + 1;
        if toInteger(CB["successes"]) >= toInteger(CB["probeSuccesses"]) then begin
          CB["state"] := "CLOSED";
          CB["failures"] := 0;
          CB["successes"] := 0;
          log.info("circuit CLOSED");
        end;
      end else begin
        CB["failures"] := 0;  // reset on success in CLOSED
      end;
    end;

    function cbOnFailure() begin
      CB["failures"] := toInteger(CB["failures"]) + 1;
      if CB["state"] == "HALF_OPEN" then begin
        // probe fail → back to OPEN, reset timer
        CB["state"] := "OPEN";
        CB["openedAt"] := toInteger(time.now() * 1000);
        CB["successes"] := 0;
        log.warn("circuit re-OPEN from HALF_OPEN");
      end else if toInteger(CB["failures"]) >= toInteger(CB["threshold"]) then begin
        CB["state"] := "OPEN";
        CB["openedAt"] := toInteger(time.now() * 1000);
        log.warn("circuit OPEN after ", CB["failures"], " failures");
      end;
    end;

    function callDependency(url) begin
      cbBeforeCall();
      try begin
        var r := http.get(url);
        if r["status"] >= 200 and r["status"] < 300 then begin
          cbOnSuccess();
          return r;
        end;
        cbOnFailure();
        throw("status " + str(r["status"]));
      end catch e do
        cbOnFailure();
        throw(e.message);
      end;
    end;

    begin
      var r := callDependency("https://api.example.com/health");
      println(r["status"]);
    end.

**Notes**:

- **Threshold = 5** — titik di mana kita percaya service memang down,
  bukan transient. Tuning sesuai SLA dependency
- **recoveryMs = 30s** — cukup untuk restart pod/instance, tidak terlalu
  lama agar client lambat tahu service sudah recover
- **HALF_OPEN probe 2×** — 1 sukses bisa noise; 2 lebih stabil
- **Different threshold per dependency** — DB = threshold 3, payment = 10
- **Log state transition** — wajib, untuk forensic
- **Circuit breaker ≠ retry** — retry tetap perlu di luar circuit
- **Per-endpoint, bukan global** — 1 breaker per dependency, bukan 1 untuk semua

---

## 5. Graceful shutdown with in-flight drain

**Kapan pakai**: HTTP server di production yang tidak boleh drop request
saat restart/deploy. Signal handler tunggu request aktif selesai sebelum exit.

**Cross-ref**: signal.on · onShutdown · http.stop · sys.exit

    var SRV := -1;
    var IN_FLIGHT := 0;              // active handler count
    var SHUTTING_DOWN := false;
    var DRAIN_TIMEOUT_MS := 25000;   // k8s default terminationGracePeriod=30s
    var DRAIN_POLL_MS := 200;

    function trackHandler(req) begin
      if SHUTTING_DOWN then
        return {"status": 503, "body": "server shutting down"};

      lock begin
        IN_FLIGHT := IN_FLIGHT + 1;
      end;
      try begin
        // ... actual business logic ...
        var status := 200;
        var body := "ok";
        return {"status": status, "body": body};
      end finally
        lock begin
          IN_FLIGHT := IN_FLIGHT - 1;
        end;
      end;
    end;

    function drainAndStop() begin
      log.info("shutdown: draining ", IN_FLIGHT, " in-flight requests");

      // Stop accepting new connections
      if SRV >= 0 then
        http.stop(SRV);

      // Wait for in-flight to finish (poll)
      var waited := 0;
      while IN_FLIGHT > 0 and waited < DRAIN_TIMEOUT_MS do begin
        sleep(DRAIN_POLL_MS);
        waited := waited + DRAIN_POLL_MS;
        if waited mod 2000 = 0 then
          log.info("draining: ", IN_FLIGHT, " left, ", 
                   DRAIN_TIMEOUT_MS - waited, "ms budget");
      end;

      if IN_FLIGHT > 0 then
        log.warn("drain timeout: ", IN_FLIGHT, " requests killed");

      log.info("shutdown complete");
      sys.exit(0);
    end;

    begin
      SRV := http.serve(8080, trackHandler);
      log.info("server on :8080");

      signal.on("SIGTERM", drainAndStop);
      signal.on("SIGINT", drainAndStop);

      onShutdown(lambda : begin
        log.info("final cleanup");
      end);

      http.listenAsync(SRV);
      while true do sleep(1000);
    end.

**Notes**:

- **Signal vs onShutdown** — `signal.on` fire di main thread, `onShutdown`
  fire setelah exit() — gunakan signal untuk drain, shutdown untuk cleanup
- **503 saat draining** — client tahu retry ke instance lain (load balancer
  aware)
- **DRAIN_TIMEOUT < k8s gracePeriod** — kalau 25s, gracePeriod=30s beri
  buffer 5s untuk force kill
- **Lock untuk counter** — `IN_FLIGHT` diakses dari handler thread + main
  thread (race condition tanpa lock)
- **Poll, bukan blocking wait** — tidak ada `wait_until` di Pascak, poll
  200ms cukup responsif
- **http.stop vs http.closeServer** — `stop` graceful (drain), `closeServer`
  paksa tutup

---

## 6. JWT-like token issuance

**Kapan pakai**: Butuh token yang self-contained (user + role + exp ada
di dalam token) tanpa database session. Sama seperti JWT HS256, tapi
lebih simpel — 2 part (payload + signature), bukan 3.

**Cross-ref**: crypto.hmacSha256 · crypto.constantTimeEqual · base64Encode

    var SECRET := config.get("AUTH_SECRET", "change-me-in-production");
    var DEFAULT_TTL_SEC := 3600;    // 1 jam

    function issueToken(user, role, ttlSec) begin
      if ttlSec == null or ttlSec <= 0 then
        ttlSec := DEFAULT_TTL_SEC;

      var now := toInteger(time.now());    // detik
      var payload := {
        "user": user,
        "role": role,
        "iat": now,                      // issued at
        "exp": now + ttlSec              // expires at
      };

      var payloadB64 := base64Encode(jsonStringify(payload));
      var sig := crypto.hmacSha256(SECRET, payloadB64);
      return payloadB64 + "." + sig;
    end;

    function verifyToken(token) begin
      if token == null or typeOf(token) != "string" then
        return null;

      var parts := token.split(".");
      if len(parts) != 2 then
        return null;

      // Constant-time HMAC check
      var expected := crypto.hmacSha256(SECRET, parts[0]);
      if not crypto.constantTimeEqual(expected, parts[1]) then begin
        log.warn("token signature mismatch");
        return null;
      end;

      // Decode + parse payload
      var payloadJson := base64Decode(parts[0]);
      if payloadJson == null then
        return null;

      var payload := jsonParse(payloadJson);
      if payload == null then
        return null;

      // Expiry check
      var now := toInteger(time.now());
      var exp := toInteger(payload["exp"]);
      if exp <= now then begin
        log.info("token expired at ", exp, " (now ", now, ")");
        return null;
      end;

      return payload;
    end;

    function refreshToken(oldToken) begin
      var payload := verifyToken(oldToken);
      if payload == null then
        return null;
      // Issue new token dengan user/role yang sama, TTL baru
      return issueToken(payload["user"], payload["role"], DEFAULT_TTL_SEC);
    end;

    begin
      // Issue
      var t := issueToken("alice", "admin", 3600);
      println("token: ", t);

      // Verify
      var p := verifyToken(t);
      if p != null then
        println("welcome ", p["user"], " (role=", p["role"], ")");

      // Tamper test
      var tampered := copy(t, 1, len(t) - 1) + "X";
      println("tampered valid? ", verifyToken(tampered) != null);
    end.

**Notes**:

- **2 part, bukan 3** — JWT asli punya header+payload+sig; kita skip header
  karena alg fixed (HS256)
- **Constant-time compare** — wajib, kalau tidak attacker bisa forge via
  timing leak
- **TTL default 1 jam** — tuning sesuai sensitivity; banking 15 menit,
  blog 24 jam
- **Tidak ada revocation** — kalau butuh revoke, tambah `jti` (token ID) +
  blacklist di dict
- **SECRET rotation** — issue token baru dengan SECRET baru, token lama
  expire natural
- **Exp check di server** — jangan andalkan client; attacker bisa ignore
- **Payload plaintext** — siapa pun bisa baca payload (base64 bukan enkripsi),
  jangan taruh password/credit card
- **Bukan JWT standard** — kalau butuh interop dengan library JWT lain,
  pakai JWT asli 3-part

---

## 7. File upload validation

**Kapan pakai**: HTTP endpoint yang terima file dari user (image, PDF,
CSV). Validasi size, extension, magic bytes SEBELUM simpan ke disk.

**Cross-ref**: http.serve · fs.tempFile · fileWrite · fileRead · fs.stat

    var MAX_SIZE := 10 * 1024 * 1024;        // 10 MB
    var ALLOWED_EXT := [".png", ".jpg", ".jpeg", ".pdf"];
    var UPLOAD_DIR := "./uploads";

    // Magic bytes: format file dari header, bukan extension
    // Extension bisa dipalsukan, magic bytes tidak
    var MAGIC_SIGS := {
      "png":  "\x89PNG\r\n\x1a\n",
      "jpg":  "\xFF\xD8\xFF",
      "pdf":  "%PDF"
    };

    function detectFormat(header) begin
      for k in MAGIC_SIGS.keys() do begin
        var sig := MAGIC_SIGS[k];
        if len(header) >= len(sig) and copy(header, 1, len(sig)) == sig then
          return k;
      end;
      return null;
    end;

    function getExtension(filename) begin
      var dot := -1;
      var i := len(filename);
      while i > 0 do begin
        if copy(filename, i, 1) == "." then begin
          dot := i;
          break;
        end;
        i := i - 1;
      end;
      if dot = -1 then
        return "";
      return lower(copy(filename, dot, len(filename) - dot + 1));
    end;

    function handleUpload(req) begin
      if req["method"] != "POST" then
        return {"status": 405, "body": "method not allowed"};

      // Size check BEFORE reading body into memory
      var contentLength := req["headers"]["Content-Length"];
      if contentLength == null then
        return {"status": 411, "body": "length required"};
      var declaredSize := toInteger(contentLength);
      if declaredSize > MAX_SIZE then
        return {"status": 413, "body": "file too large (max 10MB)"};

      var body := req["body"];
      if body == null or len(body) == 0 then
        return {"status": 400, "body": "empty body"};
      if len(body) > MAX_SIZE then
        return {"status": 413, "body": "file too large (actual)"};

      // Extension check
      var filename := req["headers"]["X-Filename"];
      if filename == null then
        return {"status": 400, "body": "missing X-Filename header"};
      var ext := getExtension(filename);
      if not ext in ALLOWED_EXT then
        return {"status": 415, "body": "extension not allowed: " + ext};

      // Magic bytes check (first 8 bytes)
      var header := copy(body, 1, 8);
      var fmt := detectFormat(header);
      if fmt == null then
        return {"status": 415, "body": "unrecognized file format"};

      // Sanitize filename — strip path, keep safe chars
      var safe := "";
      var i := 1;
      while i <= len(filename) do begin
        var c := copy(filename, i, 1);
        if c in "abcdefghijklmnopqrstuvwxyz" or
           c in "ABCDEFGHIJKLMNOPQRSTUVWXYZ" or
           c in "0123456789" or c == "." or c == "_" or c == "-" then
          safe := safe + c;
        i := i + 1;
      end;
      if safe == "" then
        return {"status": 400, "body": "invalid filename"};

      // Write to sandboxed path
      var path := UPLOAD_DIR + "/" + time.now() + "_" + safe;
      makeDir(UPLOAD_DIR);
      fileWrite(path, body);

      return {
        "status": 201,
        "headers": {"Content-Type": "application/json"},
        "body": jsonStringify({"path": path, "size": len(body), "format": fmt})
      };
    end;

    begin
      var srv := http.serve(8080, handleUpload);
      http.listenAsync(srv);
    end.

**Notes**:

- **Content-Length dulu** — kalau > MAX_SIZE, reject sebelum baca body
  (hemat memory)
- **Magic bytes > extension** — extension bisa dipalsukan, `evil.png`
  berisi script PHP akan lolos extension check
- **Sanitize filename** — strip `../`, `\`, null bytes; alowlist char
  bukan blocklist
- **Timestamp prefix** — cegah overwrite file lain dengan nama sama
- **Sandbox path** — semua path relatif ke script dir, engine block
  `../etc/passwd`
- **Magic bytes limitation** — `\xFF\xD8\xFF` (JPEG) cuma 3 byte, cukup
  untuk 99% detection tapi bukan 100%. Untuk security critical (upload
  executable), tambahkan deep validation
- **Store di filesystem, bukan DB** — DB untuk metadata, file untuk
  binary; jangan simpan 10MB blob di SQLite
- **Virus scan optional** — kalau pakai `sys.exec("clamav")`, integrate
  di dalam handler

---

## 8. Request batching + dedup

**Kapan pakai**: Banyak client request key yang sama secara bersamaan
(mis. 100 user buka profil user #42). Dedup in-flight, jadi 1 HTTP call
ke backend bukan 100.

**Cross-ref**: http.getAsync · dict · lock

    var IN_FLIGHT := {};        // key -> {waiters: [], result: null}
    var CACHE := {};            // key -> {data, exp}
    var CACHE_TTL_MS := 5000;   // 5 detik

    function cachedFetch(key, url) begin
      // 1. Cache hit?
      var c := CACHE[key];
      if c != null and toInteger(time.now() * 1000) < toInteger(c["exp"]) then
        return c["data"];

      // 2. In-flight? Attach to existing batch
      var entry := IN_FLIGHT[key];
      if entry != null then
        // Wait for the caller that started the fetch
        // Simple poll — for production use event, but poll works
        var waited := 0;
        while IN_FLIGHT[key] != null and waited < 10000 do begin
          sleep(10);
          waited := waited + 10;
        end;
        // Now check cache (should be populated)
        var c2 := CACHE[key];
        if c2 != null then
          return c2["data"];
        return null;

      // 3. First caller — do the actual fetch
      lock begin
        IN_FLIGHT[key] := {"startedAt": time.now()};
      end;

      try begin
        var r := http.get(url);
        var data := r["body"];

        // Populate cache
        lock begin
          CACHE[key] := {
            "data": data,
            "exp": toInteger(time.now() * 1000) + CACHE_TTL_MS
          };
        end;

        return data;
      end finally
        lock begin
          delete(IN_FLIGHT, key);
        end;
      end;
    end;

    function cleanupCache() begin
      var now := toInteger(time.now() * 1000);
      var keys := CACHE.keys();
      for k in keys do begin
        var c := CACHE[k];
        if c != null and now >= toInteger(c["exp"]) then
          delete(CACHE, k);
      end;
    end;

    function handler(req) begin
      var userId := req["query"];   // e.g. "id=42"
      var data := cachedFetch(userId, "https://api.example.com/user/" + userId);
      if data == null then
        return {"status": 500, "body": "fetch failed"};
      return {"status": 200, "body": data};
    end;

    begin
      setInterval(cleanupCache, 30000);
      var srv := http.serve(8080, handler);
      http.listenAsync(srv);
    end.

**Notes**:

- **Dedup window kecil** — hanya bekerja untuk request yang **bersamaan**.
  Request 100ms kemudian akan trigger fetch baru (atau cache hit)
- **Cache TTL 5s** — kompromi freshness vs load reduction. 60s untuk data
  yang jarang berubah
- **Poll, bukan event** — sederhana, tapi busy-wait. Untuk 1000 concurrent
  dedup, pakai event emitter + wait
- **Race condition** — `IN_FLIGHT[key]` check dan set harus atomik; lock
  di dalam `lock begin ... end` block
- **Different key format** — hash URL + params untuk key (`sha256(url)`)
  kalau URL panjang
- **Cache invalidation** — kalau ada update user, delete cache manual:
  `delete(CACHE, "id=42")`
- **Thundering herd setelah cache expire** — 100 request di detik 5.001
  akan trigger 100 fetch baru. Untuk fix, gunakan singleflight pattern
  dengan fallback stale data
- **Memory cap** — kalau CACHE tidak dibatasi, akan tumbuh terus. Tambah
  LRU eviction kalau key space besar

---

## 9. Scheduled job runner

**Kapan pakai**: Butuh jalankan job berkala (cleanup, sync, report) yang
**tahan restart** — job tetap jalan walau proses mati. SQLite sebagai
queue persistent.

**Cross-ref**: setInterval · sqliteExec · sqliteQuery · setInterval

    var DB := -1;
    var JOB_INTERVAL_MS := 60000;   // cek setiap menit
    var MAX_RETRIES := 3;

    function initDb() begin
      DB := sqliteConnect("jobs.db");
      sqliteExec(DB, "CREATE TABLE IF NOT EXISTS jobs (" +
        "id INTEGER PRIMARY KEY AUTOINCREMENT, " +
        "name TEXT NOT NULL, " +
        "payload TEXT, " +
        "run_at INTEGER NOT NULL, " +
        "attempts INTEGER DEFAULT 0, " +
        "status TEXT DEFAULT 'pending')");
      sqliteExec(DB, "CREATE INDEX IF NOT EXISTS idx_status_run " +
        "ON jobs (status, run_at)");
    end;

    function enqueue(name, payload, delaySec) begin
      var runAt := toInteger(time.now()) + delaySec;
      sqliteExec(DB, 
        "INSERT INTO jobs (name, payload, run_at) VALUES (?, ?, ?)",
        [name, jsonStringify(payload), runAt]);
      log.info("enqueued job: ", name, " in ", delaySec, "s");
    end;

    function claimNextJob() begin
      var now := toInteger(time.now());
      var rows := sqliteQuery(DB,
        "SELECT id, name, payload, attempts FROM jobs " +
        "WHERE status = 'pending' AND run_at <= ? " +
        "ORDER BY run_at ASC LIMIT 1", [now]);
      if len(rows) == 0 then
        return null;

      var job := rows[0];
      // Claim atomically — ubah status dulu, baru proses
      sqliteExec(DB, "UPDATE jobs SET status = 'running' WHERE id = ?",
        [job["id"]]);
      return job;
    end;

    function completeJob(id) begin
      sqliteExec(DB, "UPDATE jobs SET status = 'done' WHERE id = ?", [id]);
    end;

    function failJob(job, errorMsg) begin
      var attempts := toInteger(job["attempts"]) + 1;
      if attempts >= MAX_RETRIES then begin
        // Dead letter — berhenti retry, keep untuk manual inspect
        sqliteExec(DB, 
          "UPDATE jobs SET status = 'dead', attempts = ? WHERE id = ?",
          [attempts, job["id"]]);
        log.error("job dead (max retries): ", job["name"], 
                  " id=", job["id"], " err=", errorMsg);
      end else begin
        // Requeue dengan backoff exponential
        var backoff := 60 * math.pow(2, attempts);
        var nextRunAt := toInteger(time.now()) + toInteger(backoff);
        sqliteExec(DB,
          "UPDATE jobs SET status = 'pending', attempts = ?, run_at = ? " +
          "WHERE id = ?",
          [attempts, nextRunAt, job["id"]]);
        log.warn("job retry ", attempts, "/", MAX_RETRIES, 
                 ": ", job["name"], " in ", toInteger(backoff), "s");
      end;
    end;

    function executeJob(job) begin
      var name := job["name"];
      var payload := jsonParse(job["payload"]);

      try begin
        if name == "cleanup_temp" then begin
          // Business logic — cleanup
          var files := getFiles("./tmp");
          for f in files do
            fileDelete("./tmp/" + f);
          log.info("cleanup: removed ", len(files), " files");

        end else if name == "send_report" then begin
          http.post("https://api.example.com/reports",
            {"Content-Type": "application/json"},
            job["payload"]);
          log.info("sent report");

        end else begin
          throw("unknown job: " + name);
        end;

        completeJob(job["id"]);
      end catch e do
        failJob(job, e.message);
      end;
    end;

    function tick() begin
      // Claim max 5 jobs per tick — avoid starvation
      var processed := 0;
      while processed < 5 do begin
        var job := claimNextJob();
        if job == null then
          break;
        executeJob(job);
        processed := processed + 1;
      end;
    end;

    function recoverStuck() begin
      // Kalau proses crash saat 'running', job stuck.
      // Reset job yang running > 5 menit kembali ke pending
      var cutoff := toInteger(time.now()) - 300;
      sqliteExec(DB,
        "UPDATE jobs SET status = 'pending' " +
        "WHERE status = 'running' AND run_at < ?", [cutoff]);
    end;

    begin
      initDb();
      recoverStuck();
      setInterval(tick, JOB_INTERVAL_MS);
      setInterval(recoverStuck, 300000);   // 5 menit
      log.info("job runner started");
      while true do sleep(1000);
    end.

**Notes**:

- **SQLite persistent** — job tetap ada setelah restart, tidak hilang
  seperti in-memory queue
- **Claim atomically** — `UPDATE status='running'` dulu, baru proses.
  Kalau crash sebelum update, job akan di-pick lagi
- **Recover stuck** — startup scan job yang stuck di 'running' (proses
  sebelumnya crash) → reset ke pending
- **MAX_RETRIES = 3** — retry exponential: 1m, 2m, 4m. Setelah 3x →
  dead letter (bisa inspect manual)
- **Dead letter table** — `status='dead'` job tidak akan dieksekusi lagi,
  tapi preserved untuk diagnosa
- **Batch limit** — `processed < 5` per tick, cegah starvation: job
  lain tetap dapat slot
- **Idempotent job** — critical! Job bisa dipanggil 2× kalau ada race
  (claim + crash). Buat cleanup/send_report tahan double-execute
- **Payload JSON string** — SQLite store as TEXT, parse di executeJob
- **Upsert dedup** — kalau enqueue `cleanup_temp` 5×, bisa dedup:
  `WHERE name=? AND status='pending'` sebelum insert
- **Monitoring** — query `SELECT status, COUNT(*) FROM jobs GROUP BY status`
  untuk dash

---

## 10. Broadcast backpressure

**Kapan pakai**: WebSocket server yang broadcast ke banyak client. Client
lambat (network buruk) tidak boleh bikin server OOM — antrikan di buffer
per-client, drop kalau penuh.

**Cross-ref**: ws.serve · ws.broadcast · ws.clients · setInterval

    var SRV := -1;
    var QUEUES := {};        // connID -> array of message
    var QUEUE_LIMIT := 100;  // max 100 message per client
    var DROP_OLDEST := true; // true: drop old, false: drop new

    function sendWithBackpressure(conn, msg) begin
      var q := QUEUES[conn["id"]];
      if q == null then begin
        QUEUES[conn["id"]] := [msg];
        conn.send(msg);
        return true;
      end;

      if len(q) >= QUEUE_LIMIT then begin
        // Queue penuh — client terlalu lambat
        if DROP_OLDEST then begin
          // Buang message terlama, antrikan yang baru
          delete(q, 0);
          push(q, msg);
          log.debug("drop oldest for ", conn["id"]);
        end else begin
          // Buang message baru — pertahankan yang lama
          log.debug("drop new for ", conn["id"]);
          return false;
        end;
      end else begin
        push(q, msg);
      end;

      conn.send(msg);
      return true;
    end;

    function flushQueues() begin
      // Background flush — kalau client sudah bisa terima lagi,
      // coba kirim queue berikutnya. Dipanggil via setInterval.
      var ids := QUEUES.keys();
      for id in ids do begin
        var q := QUEUES[id];
        if q == null or len(q) == 0 then
          continue;
        // Ambil 1 message per tick (throttle, bukan flood)
        var msg := q[0];
        delete(q, 0);
        // Kirim via lookup — ws.clients() to find conn
        var clients := ws.clients(SRV);
        for cid in clients do begin
          if cid == id then begin
            ws.broadcast(SRV, msg);  // simplified; real: per-conn send
            break;
          end;
        end;
      end;
    end;

    function onOpen(conn) begin
      QUEUES[conn["id"]] := [];
      log.info("client ", conn["id"], " joined");
    end;

    function onMessage(conn, msg) begin
      // Broadcast dengan backpressure per-client
      var clients := ws.clients(SRV);
      for cid in clients do begin
        // Simulated — in real code, need per-conn lookup
        // to check queue state, then ws.broadcast or targeted send
        ws.broadcast(SRV, conn["id"] + ": " + msg);
      end;
    end;

    function onClose(conn, code) begin
      delete(QUEUES, conn["id"]);
      log.info("client ", conn["id"], " left (", code, ")");
    end;

    begin
      SRV := ws.serve(9001, {
        "onOpen": onOpen,
        "onMessage": onMessage,
        "onClose": onClose
      });
      ws.listenAsync(SRV);
      setInterval(flushQueues, 100);
      log.info("broadcast server on :9001");
      while true do sleep(1000);
    end.

**Notes**:

- **Queue per client** — bukan satu queue global. Client A lambat tidak
  boleh blok client B
- **DROP_OLDEST vs DROP_NEW** — old: pertahankan message terbaru (chat,
  stock ticker); new: pertahankan message terlama (transaction log)
- **QUEUE_LIMIT = 100** — tuning: 100 message × 200 byte = 20KB per client,
  100 client = 2MB buffer. Sesuaikan
- **Throttle flush** — 1 msg per 100ms per client, cegah flood network
- **No per-conn send di v1** — `ws.broadcast` broadcast ke semua. Untuk
  targeted send, butuh `conn.send()` (tersedia di callback arg, bukan
  global lookup)
- **Real backpressure** — TCP buffer biasanya cukup untuk 100 message
  burst. Untuk sustained, tambah flow control WS-level
- **Monitoring** — track `max(len(QUEUES[id]))` untuk detect client lambat
- **Disconnect on full queue** (optional) — kalau client terus drop
  message, mungkin lebih baik close dengan code 1008 (policy)
- **Bukan flow control** — ini buffer-then-drop, bukan TCP-like
  backpressure. Untuk strict flow control, butuh protocol di atas WS

---

## Kontribusi Resep

Punya pola yang terbukti di production? Kirim PR dengan struktur:

1. Judul `## N. <Task>` — task-level, bukan feature-level
2. **Kapan pakai** — 1-2 line, spesifik scenario
3. **Cross-ref** — API + Tutorial link (jangan restate)
4. **Code** — 4-space indent, copy-paste ready
5. **Notes** — gotcha, security, perf, anti-pattern

Review checklist:

- [ ] Tidak duplikasi pascak_api.md (signature) atau tutorial.md (bab)
- [ ] Code jalan tanpa modifikasi (test manual dulu)
- [ ] Cross-ref valid (buka link, pastikan anchor ada)
- [ ] Notes minimal 3 (gotcha, security, atau perf)
- [ ] Naming konsisten (`http.get`, bukan `HTTP Get`)

---

## Referensi Terkait

- [pascak_api.md](pascak_api.md) — Reference lengkap semua module & fungsi
- [tutorial.md](tutorial.md) — Tutorial dari nol sampai REST API
- [CHANGELOG.md](../CHANGELOG.md) — Riwayat versi & fitur baru
- [DEBUG_NOTES.md](DEBUG_NOTES.md) — Catatan debugging internal

---

## Lisensi

MIT — sama dengan proyek Pascak VM.
