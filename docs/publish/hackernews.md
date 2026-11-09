Title: Show HN: Pascak – A scripting language with native GUI and 20x faster startup than Node

Body:

Hi HN,

I've been building Pascak, a Pascal-style scripting language written in
FreePascal. It compiles to a single 3MB static binary with zero runtime
dependencies.

The core idea is "batteries included, fast to start":
- 63ms cold start (Node: 1,279ms, Python: 373ms).
- Built-in HTTP/2, WebSocket, TLS, SQLite, and crypto.
- A native SDL2 GUI toolkit (7 widgets, layouts, theming).

We just crossed 100 release tags (v1.11.45) and hit zero technical debt.

To be completely honest: we are 5.4x slower than Node on raw numeric
loops. We use a tree-walking interpreter without a JIT. But for CLIs,
one-shot scripts, and desktop GUI tools, that startup speed and built-in
toolkit make it a joy to use.

Repo: https://github.com/baddcoin/pascak
Docs: 34-chapter tutorial + full API reference.
Benchmarks: https://github.com/baddcoin/pascak/blob/main/benchmarks/cross_lang/results_v1.11.44.md

Would love to hear your feedback on the GUI API or the language design!
