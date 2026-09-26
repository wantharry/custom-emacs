# Custom Emacs (research build)

A from-source build of GNU Emacs `master` (32.0.50), set up to be **fast,
minimal and customizable**, with the long-term goal of running on Linux,
Windows and macOS.

This repo holds **only what is ours**: the configuration, the build recipe and
the pruning tool. The Emacs source itself is cloned separately into
`emacs-src/` (gitignored) so it stays a clean upstream checkout that
`git pull` can update.

> Status as of 2026-09-25. Everything marked *verified* was run and checked on
> the machine below. Everything marked *untested* has not been tried.

## Status

| Area | State |
|---|---|
| Linux build (Ubuntu 24.04 on WSL2, GTK/Wayland) | **Verified.** Builds, launches a GUI window, all smoke tests pass |
| Native compilation, tree-sitter, SQLite, HarfBuzz | **Verified** enabled and working |
| Starter config (`config/`) | **Verified** loads cleanly. No theme; the only packages are Evil (optional, `C-c v`) and Magit (`C-x g`) |
| Read-only files | **Verified.** Every file opens read-only; `C-c e e` or `M-x allow-editing` is the one deliberate way to edit (a three-key chord, so no slip can do it) |
| Magit | **Verified**, including a real commit typed through its message buffer in a real terminal. Loads only on first use (0.5 s once, then 0.05 s per status). See [docs/MAGIT.md](docs/MAGIT.md) |
| Project search and Java navigation | **Verified** with a real `jdtls`: `C-x p f` (files), `C-x p g` (text, via ripgrep), definitions, implementations and references from keys, Ctrl+Click and right-click. Instant fuzzy file finder with a whole-disk index and a live fallback, no package: `C-c f f`, `C-c f g` (checked in a real window and terminal, with screenshots) |
| Java and Rust | **Verified.** Tree-sitter modes plus `rust-analyzer` and `jdtls` via Eglot, started by hand (`M-x eglot`); no measurable startup cost |
| Test suite | **378 tests offline (about 5 s), 425 with `--gui` (about 20 s)**, all passing: headless, plus inside a real Emacs window and a real terminal (`./build.sh test --gui`); checked to catch deliberate breakage |
| Pruning unused built-in Lisp | **Verified.** 308 MB → 258 MB install; 17 realistic workflows pass on the pruned build (see [PRUNING.md](docs/PRUNING.md)) |
| Windows | **Verified as a portable bundle**: unzip and double-click `Emacs.exe` (official Emacs 31.1 + these settings, Evil, Magit, grammars, ripgrep, Git). 0 test failures on Windows, a real Magit commit checked, with screenshots. Building Emacs 32 itself for Windows is *untested*. See [docs/DISTRIBUTION.md](docs/DISTRIBUTION.md) |
| macOS build | *Untested.* Placeholder in `build.sh` only |
| CI (GitHub Actions) for all three OSes | *Not written yet* |
| Theme, mode line, final fonts | *Deliberately deferred* (see [Customizing](docs/CUSTOMIZING.md)) |

## Quick start (Linux)

```sh
# 1. system packages (needs sudo)
sudo apt-get install -y build-essential texinfo libgnutls28-dev libncurses-dev \
  libxml2-dev libjansson-dev libsqlite3-dev libtree-sitter-dev libgccjit-13-dev \
  libgtk-3-dev librsvg2-dev libjpeg-dev libtiff-dev libgif-dev libwebp-dev \
  liblcms2-dev libharfbuzz-dev libcairo2-dev libxpm-dev libotf-dev

# 2. upstream source (git:// is used because Savannah's HTTPS often returns HTTP 500)
git clone --depth=1 git://git.savannah.gnu.org/emacs.git emacs-src

# 3. configure, compile, install, prune (the compile takes a long time)
./build.sh

# 4. run it
install/bin/emacs --init-directory=$PWD/config

# 5. run the tests (do this after every change)
./build.sh test
```

Details and alternatives: [docs/BUILD.md](docs/BUILD.md). Moving to a new computer or a
new Emacs version: see ["A new computer, or a new version of Emacs"](docs/BUILD.md#a-new-computer-or-a-new-version-of-emacs).
Needs Emacs 30 or newer (tested on 32.0.50).

## What is in this repo

```
research-emacs/
├── README.md            this file
├── build.sh             configure / make / install / prune
├── prune.list           which built-in Lisp to remove (edit this)
├── prune.py             dependency-aware pruning tool
├── tools/               verification scripts for a pruned build
├── tests/               the automated test suite (run it after every change)
├── config/
│   ├── early-init.el    runs before the window exists (startup speed)
│   └── init.el          the actual configuration
├── docs/                guides (below)
├── emacs-src/           upstream Emacs (NOT tracked; you clone it)
├── build/               compile output (NOT tracked)
└── install/             installed + pruned copy (NOT tracked)
```

## Documentation

| Guide | Read it for |
|---|---|
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | What Emacs is made of and where a given change belongs |
| [docs/BUILD.md](docs/BUILD.md) | Dependencies, configure flags, building, updating from upstream |
| [docs/CUSTOMIZING.md](docs/CUSTOMIZING.md) | The config files, adding a theme/fonts, live editing, profiling |
| [docs/PRUNING.md](docs/PRUNING.md) | Removing unused packages: method, results, limits, how to test |
| [docs/CROSS-PLATFORM.md](docs/CROSS-PLATFORM.md) | Plan for Windows and macOS and CI (untested) |
| [docs/LANGUAGES.md](docs/LANGUAGES.md) | Java and Rust: what is installed, what it costs (measured), how to use and extend it |
| [docs/START-SCREEN.md](docs/START-SCREEN.md) | The screen Emacs opens on: your last 5 files, folders and projects as links, expandable, and `C-c h` to get back to it |
| [docs/DISTRIBUTION.md](docs/DISTRIBUTION.md) | Portable bundles: unzip and run. The Windows zip (built and tested), what is inside, how it differs from the Linux build, limits, how to rebuild it |
| [docs/MAGIT.md](docs/MAGIT.md) | Git inside Emacs with Magit: `C-x g`, stage, commit, push, with screenshots; how it works with the read-only lock |
| [docs/NAVIGATING-CODE.md](docs/NAVIGATING-CODE.md) | Find a file in a project, search across it, and in Java click a method to see its definition, implementations and references (measured on a real server) |
| [docs/TYPING.md](docs/TYPING.md) | How to press Control and Meta comfortably and fast, type fewer chords, and a four-week plan with a practice file. Every key is machine-checked |
| [docs/KEYBOARD.md](docs/KEYBOARD.md) | Learning Emacs: movement, editing, search, Dired, help, Evil. Every key is machine-checked |
| [docs/TESTING.md](docs/TESTING.md) | The test suite: what it covers, how to run it, how to add tests |
| [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) | Problems hit while building this, and their fixes |

## Key numbers (measured)

| Measure | Value |
|---|---|
| Emacs version / commit | 32.0.50, `7bc4f49a3686` (master, 2026-09-25) |
| Elisp in `lisp/` | ~2.03 M lines |
| C in `src/` | ~567 K lines |
| Startup, headless, bare `-Q` | 0.03 s |
| Startup, headless, with our config | 0.05 s |
| Install size, unpruned → pruned | 308 MB → 258 MB |
| Native-compiled files, unpruned → pruned | 1,627 → 1,228 |
| Built-in packages loading, unpruned → pruned | 512/513 → 476/513 (the 36 missing are the removed ones; `nxml` fails in both) |

## Open decisions

1. **Scope.** General coding editor, or a single-purpose tool? The current
   config assumes a coding editor.
2. **Magit.** Included (`C-x g`), see [docs/MAGIT.md](docs/MAGIT.md). A separate project, *gitmacs*
   (`~/projects/emacs/magit`), is a Magit-only launcher; it was used as a
   reference for look and feel and is **not modified or part of this repo**.
3. **Theme and mode line.** Removed for now, to be added later. The reference
   setup used `doom-tokyo-night`, `doom-modeline` and `nerd-icons`.
4. **Languages** to set up tree-sitter grammars and language servers for.
5. **Linux bundle, macOS** bundle, and CI. (The Windows bundle exists: [docs/DISTRIBUTION.md](docs/DISTRIBUTION.md).)
