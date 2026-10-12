## 3. `README.md` — Update Feature List (Optional)

Kalau `README.md` punya section `## Features`, tambahkan baris WebSocket:

```markdown
- **WebSocket server** (RFC 6455) — text/binary frames, fragmentasi, ping/pong, TLS (`wss://`), worker thread per connection
```

Atau kalau ada table "Capability Matrix", tambahkan row:

```markdown
| WebSocket | ✓ `ws.serve` / `ws.serveTLS` | RFC 6455 full |
```

---