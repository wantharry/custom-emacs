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
| Starter config (`config/`) | **Verified** loads cleanly. No theme; the only package is Evil, optional, toggled with `C-c v` |
| Read-only files | **Verified.** Every file opens read-only; `C-c e e` or `M-x allow-editing` is the one deliberate way to edit (a three-key chord, so no slip can do it) |
| Project search and Java navigation | **Verified** with a real `jdtls`: `C-x p f` (files), `C-x p g` (text, via ripgrep), definitions, implementations and references from keys, Ctrl+Click and right-click. Whole-disk indexed search: measured, **not built yet** |
| Java and Rust | **Verified.** Tree-sitter modes plus `rust-analyzer` and `jdtls` via Eglot, started by hand (`M-x eglot`); no measurable startup cost |
| Test suite | **347 tests offline (about 5 s), 384 with `--gui` (about 20 s)**, all passing: headless, plus inside a real Emacs window and a real terminal (`./build.sh test --gui`); checked to catch deliberate breakage |
| Pruning unused built-in Lisp | **Verified.** 308 MB → 258 MB install; 17 realistic workflows pass on the pruned build (see [PRUNING.md](docs/PRUNING.md)) |
| Windows build | *Untested.* Placeholder in `build.sh` only |
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
2. **Magit.** Not included. A separate project, *gitmacs*
   (`~/projects/emacs/magit`), is a Magit-only launcher; it was used as a
   reference for look and feel and is **not modified or part of this repo**.
3. **Theme and mode line.** Removed for now, to be added later. The reference
   setup used `doom-tokyo-night`, `doom-modeline` and `nerd-icons`.
4. **Languages** to set up tree-sitter grammars and language servers for.
5. **Windows / macOS** builds and CI.
