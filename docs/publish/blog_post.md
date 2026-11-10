# Building a Native GUI Toolkit in a 3MB Scripting Language

*How we built Pascak, crossed 100 tags, and survived the benchmark reality check.*

When I started building Pascak, I wanted a scripting language that felt
like Python but started as fast as a C binary. No `npm install`. No
virtual environments. Just a single 3MB executable that runs everywhere.

This week, we crossed **103 release tags**. Here is the story of how we
built a native GUI toolkit from scratch, and why we decided to be
brutally honest about our benchmarks.

## The GUI Toolkit Journey (v1.11.14 to v1.11.43)

Building a GUI in a scripting language usually means wrapping HTML in a
browser window. We didn't want that. We wanted native SDL2 rendering.

Over 30 releases, we built:
- A widget hierarchy (Button, Edit, Memo, ComboBox, ListBox, Checkbox,
  Radio).
- Mouse drag-selection and dynamic line-number gutters.
- A layout engine (`layoutFlow`, `layoutGrid`).
- Full per-widget theming (RGB backgrounds, text colors, hover states).

The result? You can create a fully themed, database-backed desktop app
in ~100 lines of code, and ship it as a single binary.

## The Benchmark Reality Check

For a long time, we assumed we were "pretty fast." Then we ran the
numbers against Node and Python.

We wrote an arithmetic loop (1M iterations):
- **Node:** 616–723 ms
- **Python:** 688 ms
- **Pascak:** 685 ms

We were **at parity**. But three months earlier, we'd been 5.4x slower.
What changed?

A profiling tool (`--profile`, v1.11.46) revealed our for-loop compiler
was emitting a redundant bottom check — 8 opcodes per iteration when 3
would suffice. Removing 30 lines of redundant bytecode gave a **5.2x
speedup** (3,568 ms → 685 ms). The lesson: **measure before rewriting**.
We almost spent 15 sessions refactoring to a register VM. One profiling
session saved us 13.

## Why Startup Matters

Startup time is where Pascak's advantage is most dramatic:
- **Node:** 1,048–1,430 ms
- **Python:** 191–233 ms
- **Pascak:** 52–134 ms (warm/cold cache)

That's an **8–27x difference vs Node**. For a CLI tool or serverless
handler, 1.2 seconds of waiting is eternity. Pascak executes in a blink.

## What's Next?

We are 103 tags in with zero technical debt. The native GUI is 100%
complete. The documentation is 6,000+ lines. The benchmark suite is
honest.

Now, we need users. If you are tired of juggling dependencies and just
want a single binary that can spin up a GUI and an HTTP/2 server in
milliseconds, give Pascak a try.

*Check out the repo on GitHub: github.com/baddcoin/pascak*
