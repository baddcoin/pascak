# 🗺️ Roadmap Performa Pascak: Menuju "Cepat & Tangguh"

**Tujuan:** Mengubah posisi Pascak dari *"Cepat startup, lambat compute"* menjadi *"Kompetitif di segala metrik"*.
**Baseline v1.11.45:** 1M iterasi `for` loop = 3,568 ms (Node: 657 ms, Gap 5.4x).

## 📊 Diagnosis Saat Ini
- Pascak setara Python 3.10 (sebelum loop specialization).
- Gap utama bukan di compiler, tapi **VM dispatch overhead** (~3 μs/iterasi).
- **Batasan Jujur:** Tidak mungkin mengalahkan V8/LuaJIT tanpa full JIT (butuh tahun). Target realistis: **Paritas dengan Node/Python dalam ~2 bulan**.

---

## FASE 0 — Measurement Infrastructure (2-3 hari)
**Tanpa data, semua optimisasi adalah tebakan.**
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

## FASE 5 — Superinstruction Polishing (1 minggu)
**Root cause:** `TryEmit*` saat ini hanya jalan untuk local scope, miss untuk global.
**Perubahan:**
- Extend `TryEmit*` untuk global scope.
- Tambah superinstruction untuk `while` loop (`Lt + JumpIfFalse`).
- Tambah `opcLtLocalConst`.
**Expected speedup:** **1.2–1.3x**.
**Target:** `for` loop ~300–500 ms → **~250–400 ms**.
**Risk:** LOW (Tinggal extend pattern).

---

## FASE 6 — Baseline JIT (3-6 bulan, OPSIONAL)
**Syarat:** Hanya jika ada user report bottleneck ekstrem setelah Fase 1-5.
**Perubahan:** Detect hot function, compile ke native x86/ARM64.
**Expected speedup:** **5–10x**.
**Risk:** EXTREME (Assembly generation, calling convention).
