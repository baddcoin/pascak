# 🗺️ Roadmap Performa Pascak: Menuju "Cepat & Tangguh"

**Tujuan:** Mengubah posisi Pascak dari *"Cepat startup, lambat compute"* menjadi *"Kompetitif di segala metrik"*.
**Baseline v1.11.45:** 1M iterasi `for` loop = 3,568 ms (Node: 657 ms, Gap 5.4x).

## 📊 Diagnosis Saat Ini
- Pascak setara Python 3.10 (sebelum loop specialization).
- Gap utama bukan di compiler, tapi **VM dispatch overhead** (~3 μs/iterasi).
- **Batasan Jujur:** Tidak mungkin mengalahkan V8/LuaJIT tanpa full JIT (butuh tahun). Target realistis: **Paritas dengan Node/Python dalam ~2 bulan**.

---

## FASE 0 — Measurement Infrastructure ✅ DONE v1.11.46
**Tool:** `--dump-bytecode` (disassembler), `--profile` (opcode counter).
**Data actual (arith.pas 1M iter):** 8 opcodes/iterasi, `opcGetLocal` 25% hotspot.
**Finding:** For-loop compile has redundancy — `opcForLoopCond` coexist with unfused opcodes.
**Priority update:** Phase 5 (fix redundancy) may give 40% win faster than Phase 1.
- `--dump-bytecode`: Disassembler per chunk.
- `--profile`: Hit-count per opcode, waktu per fungsi.
- `--trace`: Log eksekusi per-instruksi.
- Benchmark harness reproducible (3-run median).

---

## FASE 1 — Stack VM → Register VM (3-4 minggu) ⭐ Biggest Win
**Root cause:** Arsitektur stack-based (`Push`/`Pop`) sangat lambat dibanding register-based.
**Perubahan:**
- Ubah arsitektur VM menjadi register-based (seperti Lua 5.x atau CPython 3.11+).
- Contoh: `GetLocal 0; GetLocal 1; Add; SetLocal 0` (4 opcode) menjadi `AddR R0, R0, R1` (1 opcode).
- Register allocation di compiler (linear scan).

**Expected speedup:** **2–4x**.
**Target:** `for` loop ~3,568 ms → **~900–1,800 ms**.
**Risk:** HIGH (Refactor core VM, dual-VM selama transisi).

---

## FASE 2 — Type Specialization (2 minggu)
**Root cause:** Setiap operasi `Add` memeriksa tipe runtime (boxing/unboxing).
**Perubahan:**
- Opcode spesialis: `opcAddIntInt`, `opcAddIntFloat`, `opcAddStrStr`.
- Compiler emits opcode spesifik berdasarkan type inference lokal.
- Fallback ke `opcAdd` polymorphic jika inference gagal.
**Expected speedup:** **1.5–2x**.
**Target:** `for` loop ~900–1,800 ms → **~500–900 ms**.
**Risk:** MEDIUM (Butuh type inference lokal).

---

## FASE 3 — Inline Caching (1-2 minggu)
**Root cause:** Symbol lookup di setiap `GetLocal`/`SetLocal` tidak di-cache.
**Perubahan:**
- Monomorphic inline cache di setiap bytecode site.
- First hit: lookup + cache. Subsequent hits: direct pointer deref.
**Expected speedup:** **1.3–1.5x**.
**Target:** `for` loop ~500–900 ms → **~400–700 ms** (Paritas dengan Node/Python).
**Risk:** LOW-MEDIUM (Pattern standard).

---

## FASE 4 — Memory & GC Optimization (2-3 minggu)
**Root cause:** Alokasi `TValue` di setiap operasi = GC pressure.
**Perubahan:**
- Arena allocator untuk AST node + TValue sementara.
- Unboxed int/float di hot path.
- Generational GC opsional (Fase 4b).
**Expected speedup:** **1.2–1.5x** + stabilitas runtime.
**Target:** `for` loop ~400–700 ms → **~300–500 ms**.
**Risk:** MEDIUM (GC bug sulit di-debug).

---

## FASE 5 — Superinstruction Polishing
**Status:** ✅ DONE local (v1.11.47), ⚠️ ATTEMPTED global (v1.11.48, no win)

### 5a — Local for-loop (v1.11.47) ✅
Remove redundant bottom check → 5.2x speedup (3568ms → 685ms).

### 5b — Global for-loop (v1.11.48) ⚠️ Negative result
Attempted: fuse 8 opcodes → 3 for global for-loop + inline cache.
Result: -53% opcode count, **0% runtime improvement**.
Root cause: Generation counter invalidation on every SetGlobal forces cache
miss. Plus TValue boxing + AtomicAdd locking.
**Conclusion:** Global for-loop cannot be optimized without Register VM or
arena allocator. Do not attempt further global loop optimizations. See
`benchmarks/cross_lang/results_v1.11.48.md` for full analysis.

---

## FASE 6 — Baseline JIT (3-6 bulan, OPSIONAL)
**Syarat:** Hanya jika ada user report bottleneck ekstrem setelah Fase 1-5.
**Perubahan:** Detect hot function, compile ke native x86/ARM64.
**Expected speedup:** **5–10x**.
**Risk:** EXTREME (Assembly generation, calling convention).
