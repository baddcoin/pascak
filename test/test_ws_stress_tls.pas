// ═══════════════════════════════════════════════════════════════
//  test_ws_stress_tls.pas — Concurrent stress (plain + TLS)
// ═══════════════════════════════════════════════════════════════
//  Bukti skalabilitas event loop: 200 plain + 100 TLS paralel
//  dengan 1 thread (main event loop).
//
//  Prasyarat: ulimit -n >= 1024 (default Termux)
// ═══════════════════════════════════════════════════════════════

var SRV_PLAIN := -1;
var SRV_TLS := -1;
var PLAIN_OPENS := 0;
var TLS_OPENS := 0;
var PLAIN_ECHOES := 0;
var TLS_ECHOES := 0;

function onPlainOpen(conn) begin
  PLAIN_OPENS := PLAIN_OPENS + 1;
end;

function onPlainMsg(conn, msg) begin
  PLAIN_ECHOES := PLAIN_ECHOES + 1;
  conn.send("p:" + msg);
end;

function onTLSOpen(conn) begin
  TLS_OPENS := TLS_OPENS + 1;
end;

function onTLSMsg(conn, msg) begin
  TLS_ECHOES := TLS_ECHOES + 1;
  conn.send("t:" + msg);
end;

function runStress() begin
  var py := "
import asyncio, websockets, ssl, sys

ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

PLAIN_N = 200
TLS_N = 100

async def plain_client(i):
    try:
        async with websockets.connect(
            'ws://localhost:9170',
            ping_interval=None,
            open_timeout=15
        ) as ws:
            await ws.send('p-' + str(i))
            r = await ws.recv()
            return r
    except Exception as e:
        print(f'plain {i} error: {type(e).__name__}: {e}', flush=True, file=sys.stderr)
        return None

async def tls_client(i):
    try:
        async with websockets.connect(
            'wss://localhost:9171',
            ssl=ctx,
            ping_interval=None,
            open_timeout=15
        ) as ws:
            await ws.send('t-' + str(i))
            r = await ws.recv()
            return r
    except Exception as e:
        print(f'tls {i} error: {type(e).__name__}: {e}', flush=True, file=sys.stderr)
        return None

async def main():
    tasks = []
    for i in range(PLAIN_N):
        tasks.append(asyncio.create_task(plain_client(i)))
    for i in range(TLS_N):
        tasks.append(asyncio.create_task(tls_client(i)))

    results = await asyncio.gather(*tasks, return_exceptions=True)
    ok = sum(1 for r in results if isinstance(r, str))
    print(f'ok={ok} of {PLAIN_N + TLS_N}', flush=True)

asyncio.run(main())
";
  var r := sys.exec("python3", ["-c", py], 40000);
  println(r["stdout"]);
  if len(r["stderr"]) > 0 then begin
    println("--- stderr (first 500) ---");
    var s := r["stderr"];
    if len(s) > 500 then s := copy(s, 1, 500);
    println(s);
  end;
end;

begin
  println("=== WS stress: 200 plain + 100 TLS ===");

  // B.SEC: naikkan fd limit untuk client spawn
  // Default policy cap OpenFiles=256 — tidak cukup untuk 300 koneksi
  sys.execPolicy({
    "mode": "allow-all",
    "limits": {
      "enabled": true,
      "openFiles": 2048
    }
  });

  SRV_PLAIN := ws.serve(9170, {
    "onOpen":    onPlainOpen,
    "onMessage": onPlainMsg,
    "pingEnabled": false
  });

  var home := sys.env("HOME");
  SRV_TLS := ws.serveTLS(9171,
    home + "/server.crt",
    home + "/server.key",
    {
      "onOpen":    onTLSOpen,
      "onMessage": onTLSMsg,
      "pingEnabled": false
    });

  if SRV_PLAIN < 0 then begin
    println("FAIL: plain serve return -1");
    sys.exit(1);
  end;
  if SRV_TLS < 0 then begin
    println("FAIL: tls serve return -1");
    sys.exit(1);
  end;

  println("plain server: ", SRV_PLAIN, " on 9170");
  println("tls server:   ", SRV_TLS, " on 9171");

  ws.listenAsync(SRV_PLAIN);
  ws.listenAsync(SRV_TLS);
  sleep(500);

  thread(runStress);
  sleep(25000);

  println();
  println("=== Results ===");
  println("plain opens:  ", PLAIN_OPENS);
  println("plain echoes: ", PLAIN_ECHOES);
  println("tls opens:    ", TLS_OPENS);
  println("tls echoes:   ", TLS_ECHOES);

  ws.stop(SRV_PLAIN);
  ws.stop(SRV_TLS);
  sleep(1000);

  var plain_ok := PLAIN_OPENS >= 180;
  var tls_ok := TLS_OPENS >= 90;

  println();
  if plain_ok and tls_ok then begin
    println("PASS");
    sys.exit(0);
  end else begin
    println("FAIL: plain=", PLAIN_OPENS, " tls=", TLS_OPENS);
    sys.exit(1);
  end;
end.
