# Architecture: what Emacs is made of

All numbers were measured on the checkout in `emacs-src/` (Emacs 32.0.50,
commit `7bc4f49a3686`, 2026-09-25) unless stated otherwise.

## Two layers

Emacs is a small C engine hosting a very large Lisp system. Most of the
behavior you see is Lisp, which you can change live without recompiling.

| Layer | Size | Role |
|---|---|---|
| `lisp/` (Elisp) | ~2,027,000 lines | Modes, UI, LSP client, VC, package manager, the compilers |
| `src/` (C) | ~567,000 lines | The runtime: Lisp interpreter, buffers, redisplay, windowing, processes |
| `lib/` | ~69,000 lines | Portability shims (gnulib) |
| `lib-src/` | ~21,000 lines | Helper programs (`emacsclient`, `etags`, ...) |
| `nt/` | ~3,300 lines | Windows build support |

## The C core (`src/`)

Largest files, by lines:

| File | Lines | What it does |
|---|---|---|
| `xdisp.c` | 39,800 | **Redisplay engine**: text layout and drawing. The most complex file, and the one that most affects "feels fast" |
| `xterm.c` | 33,100 | X11 backend |
| `sfnt.c` | 21,200 | TrueType font file parsing |
| `keyboard.c` | 14,700 | Command loop and input |
| `image.c` | 13,800 | Image decoding and display |
| `w32fns.c` | 12,500 | Windows backend (window functions) |
| `coding.c` | 12,300 | Text encodings |
| `w32.c` | 11,400 | Windows system layer |
| `xfns.c` | 10,700 | X11 window functions |
| `window.c` | 9,700 | Window model |
| `process.c` | 9,100 | Subprocess I/O (matters for language-server speed) |

### Platform backends

Cross-platform support is implemented as separate display backends selected at
configure time:

| Platform | Files | Configure flag |
|---|---|---|
| Linux, Wayland/GTK (what we built) | `pgtkterm.c` | `--with-pgtk` |
| Linux, X11 | `xterm.c`, `xfns.c` | `--with-x-toolkit=gtk3` |
| Windows | `w32term.c`, `w32fns.c`, `w32*.c` | `--with-w32` (default under MSYS2) |
| macOS | `nsterm.m` | `--with-ns` |
| Haiku, Android | `haikuterm.c`, `androidterm.c` | separate ports |
| Terminal | `term.c` | any build |

**Consequence:** a change in Lisp works on every platform for free. A change in
shared C (`xdisp.c`, `keyboard.c`, ...) also applies everywhere. A change in a
backend file has to be repeated and tested per platform.

## The Lisp layer (`lisp/`)

Largest directories by source size: `progmodes/` (language modes, Eglot,
tree-sitter modes), `org/`, `gnus/`, `emacs-lisp/` (byte-compiler and native
compiler), `net/`, `textmodes/`, `cedet/`, `international/`, `vc/`, `calc/`.

There are about 1,538 `.el` files (excluding `obsolete/` and `leim/`),
65.9 MB of source. package.el reports **513 bundled packages**.

## How startup is fast

- Emacs ships a **portable dump** (`emacs.pdmp`, 17.7 MB here): a memory
  snapshot of ~127 preloaded Lisp features that is mapped in at launch instead
  of loaded from disk.
- Measured headless startup: **0.03 s** bare (`-Q`), **0.07 s** with
  `config/`. Headless numbers exclude drawing the window.

## Byte code and native code

| Form | File | How it runs |
|---|---|---|
| Source | `.el` | Interpreted (slow) |
| Byte code | `.elc` | Bytecode interpreter |
| Native | `.eln` | Machine code, via `libgccjit` |

Native compilation typically speeds up Lisp-heavy work by a few times. Our build
uses `--with-native-compilation=aot`, so all built-in Lisp is native-compiled
during the build (1,627 `.eln` files, 150 MB). Of the compiled functions
present at startup, 71% (4,118 of 5,823) were native. I did not investigate why
the rest are not.

`.eln` files are specific to the machine and the exact Emacs build: **they
cannot be shared across Linux, Windows and macOS.**

## Where a change belongs

| I want to change... | Edit | Recompile? |
|---|---|---|
| My settings, keys, fonts, theme | `config/init.el` | No |
| Built-in behavior (a mode, Eglot, VC) | the `.el` in `emacs-src/lisp/` | No (evaluate it live); `make` recompiles only that file to keep it fast |
| Rendering, input, buffers, processes | `emacs-src/src/*.c` | Yes; incremental `make` rebuilds only touched files |
| One platform's windowing/fonts | that backend's file | Yes, and test on that platform |

Editing `emacs-src/` makes it diverge from upstream, so `git pull` may
conflict. Prefer Lisp changes in `config/`, and keep any C changes as a small
patch set.

## Measuring before optimizing

No slow spot was found in this build, and none should be guessed at. Profile
the real problem first; see [CUSTOMIZING.md](CUSTOMIZING.md#profiling).
