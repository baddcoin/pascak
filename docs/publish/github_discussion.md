# 🚀 Pascak v1.11.45: 103 Tags, Native GUI Toolkit, Honest Benchmarks

Hi everyone! I'm excited to share the latest milestone for **Pascak** —
a Pascal-style scripting language designed for instant startup, zero
dependencies, and built-in batteries.

We just crossed **103 tags** (v1.11.45). Here is what's new.

## 🎨 Native GUI Toolkit (100% Complete)

Forget Electron or browser wrappers. Pascak ships with a native SDL2 GUI
toolkit built directly into the 3MB binary.

- **7 Production-Ready Widgets:** Button, Edit, Memo, ComboBox, ListBox,
  Checkbox, Radio.
- **Layout API:** `gui2.layoutFlow()` (auto-wrap) and `gui2.layoutGrid()`.
- **Theming:** Full RGB control over background, text, border, and hover
  states per-widget.

## ⚡ Honest Benchmarks (v1.11.45)

We benchmarked Pascak against Python 3.14, Node 26, and Lua 5.4 on a
Termux (aarch64) device. We believe in honest numbers:

**Startup Time**
- **Pascak:** 52–134 ms (warm/cold)
- **Python:** 191–373 ms
- **Node:** 1,048–1,430 ms
- **Lua:** 39–59 ms

Pascak is **8–27x faster to start** than Node — perfect for CLIs and
one-shot scripts.

**Arithmetic Loop (1M iterations)**
- **Pascak:** 685 ms
- **Python:** 688 ms
- **Node:** 616–723 ms
- **Lua:** 84 ms

Pascak is **at parity** with Python and Node on numeric loops. v1.11.47
closed a 5.2x gap via profiler-driven bytecode cleanup (removed
redundant for-loop bottom check). Lua's register VM remains ~8x faster.

## 💡 Why Pascak?

If you need raw compute, use Node or Lua. Use Pascak when you want to:

1. Write a full GUI app (with SQLite) in 100 lines of code.
2. Deploy by scp-ing a single 3MB binary (no npm install or pip).
3. Start executing code in 63 milliseconds.

## 🛠️ Try It

    git clone https://github.com/baddcoin/pascak
    cd pascak
    fpc -Mobjfpc -Sh pascak_noASTnet.pas
    cp pascak_noASTnet $PREFIX/bin/pascak
    pascak examples/todo_gui.pas

**We want your feedback!** What features are missing? What do you think
of the GUI API? Let us know in the replies.
