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
- **Node:** 657 ms
- **Pascak:** 3,568 ms

We were **5.4x slower** on raw compute. Why? Because Pascak is a
*tree-walking interpreter*. Node uses V8's JIT. Python 3.14 uses loop
specialization. We don't have those optimizations.

We had a choice: hide the numbers, or be honest.

We chose honesty. We documented the benchmark, explained the tradeoffs,
and optimized what we could (switching to `for` loops over `while` loops
improved performance by 2.65x).

## Why Startup Matters

Where Pascak *does* win is startup time:
- **Node:** 1,279 ms
- **Pascak:** 63 ms

That's a **20x difference**. For a CLI tool or a serverless handler, 1.2
seconds of waiting is an eternity. Pascak executes instantly.

## What's Next?

We are 103 tags in with zero technical debt. The native GUI is 100%
complete. The documentation is 6,000+ lines. The benchmark suite is
honest.

Now, we need users. If you are tired of juggling dependencies and just
want a single binary that can spin up a GUI and an HTTP/2 server in
milliseconds, give Pascak a try.

*Check out the repo on GitHub: github.com/baddcoin/pascak*
