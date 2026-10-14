📄 Handoff — Resume Point

Commit: d032575
Lokasi: ~/storage/downloads/termux/pascak/

Quick resume:

```bash
cd ~/storage/downloads/termux/pascak
git log --oneline -5
PASCAK_EXEC_POLICY=allow-all ~/pascak_noASTnet --test 2>&1 | grep RESULT
```

---

🗺️ Status Project Overview

Bundle Status
Fase 0/1 — Correctness + Hardening ✅
Bundle B — Observability ✅
Bundle A — HTTP Pooling ✅
Bundle C — WebSocket Client ✅
Production Ops — Metrics/Log/Health/Trace ✅
DX Bundle — Test/Fmt/Lint ✅
TOTAL ✅ All Complete

---

🚀 Pilihan Sesi Berikutnya

Priority Task Effort Impact
🥇 B.7 — Export public API (embed di Pascal host) 2-3 jam 🟠 DX besar
🥈 D.1 — Coroutine scheduler (async/await style) 2-3 jam 🟡 Async clean
🥉 A.1b — Chunked decoder (lengkapi HTTP pool) 1-2 jam 🟡 Pool polish
4 C.2 — WS auto-reconnect dengan backoff 1-2 jam 🟢 Reliability
5 C.3 — WS subprotocol negotiation 1 jam 🟢 Compat
6 D.2 — HTTP/2 client 6-8 jam 🟠 Modern
7 E.4 — VSCode extension / LSP 4-6 jam 🟢 DX

Rekomendasi saya: B.7 — Export API.

Alasan:

· Unlock use case baru: Pascak bisa di-embed di aplikasi Lazarus/Delphi/FPC
· Plugin system untuk host apps
· High DX impact untuk adopter
· Effort sedang (2-3 jam), well-scoped

Alternatif D.1 — kalau Anda lebih fokus ke language feature.

---

⚠️ Known Limitations (Backlog)

Isu Track
Chunked encoding tidak di-pool A.1b
http.listen blocking tanpa keep-alive A.1c
WS client tanpa subprotocol/compression C.2/C.3
Formatter tidak normalize operator spacing E.1b (optional)
Linter tidak cross-function analysis E.2b (optional)
Windows signal handling Backlog
REPL Windows tanpa bg-tick Platform

---

🎯 Sesi Highlight

Fitur production ops:

· Metrics Prometheus-compatible
· Request logging middleware
· Health checks (K8s readiness)
· Request ID tracking (distributed tracing)

DX tools:

· Test runner (29-file discovery, soft-skip)
· Formatter (dict literal handling)
· Linter (scope tracking, W001/W002/E001)

Pola produktif:

· 1 task = 1 commit
· Fix → test → commit
· Docs sync di akhir bundle
· Reuse existing infra (TDeadCodeAnalyzer, TNode types)

---

📄 Yang Bisa Dikerjakan Selanjutnya

Sesi #6 (berikutnya): B.7 Export API — 2-3 jam
Sesi #7: D.1 Coroutine scheduler — 2-3 jam
Sesi #8: A.1b + A.1c + C.2 (polish bundle) — 3-4 jam
Sesi #9: Docs overhaul (Bab 26-30 tutorial) — 2 jam