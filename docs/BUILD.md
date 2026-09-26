# Building

Verified on **Ubuntu 24.04.4 (WSL2)**, 16 cores, gcc 13, with WSLg for the GUI.
Windows and macOS are covered in [CROSS-PLATFORM.md](CROSS-PLATFORM.md)
and are untested.

## 1. System packages

```sh
sudo apt-get install -y build-essential texinfo libgnutls28-dev libncurses-dev \
  libxml2-dev libjansson-dev libsqlite3-dev libtree-sitter-dev libgccjit-13-dev \
  libgtk-3-dev librsvg2-dev libjpeg-dev libtiff-dev libgif-dev libwebp-dev \
  liblcms2-dev libharfbuzz-dev libcairo2-dev libxpm-dev libotf-dev
```

| Package | Why it is needed |
|---|---|
| `texinfo` | `makeinfo`. **Required** for a git checkout (release tarballs ship pre-built manuals, git does not) |
| `libncurses-dev` | Terminal support. configure fails without a terminfo library |
| `libgccjit-13-dev` | Native compilation (the main speed feature) |
| `libtree-sitter-dev` | Tree-sitter parsing and highlighting |
| `libgtk-3-dev`, `libcairo2-dev`, `libharfbuzz-dev` | GUI toolkit, drawing, font shaping |
| `libgnutls28-dev` | HTTPS, needed to download packages |
| `libsqlite3-dev`, `libjansson-dev`, `libxml2-dev` | SQLite, JSON, XML |
| `librsvg2-dev`, `libjpeg/tiff/gif/webp-dev`, `liblcms2-dev`, `libxpm-dev` | Image formats |
| `libotf-dev` | OpenType font support |

`libwebkit2gtk-4.1-dev` is deliberately left out: it is only for embedded web
views (xwidgets), is large, and is not needed.

If `apt-get update` fails because of a dead third-party repository, skip the
update and run only the install (see [TROUBLESHOOTING.md](TROUBLESHOOTING.md)).

## 2. Get the source

```sh
git clone --depth=1 git://git.savannah.gnu.org/emacs.git emacs-src
```

- Source is the official GNU repository on Savannah.
- The `git://` form is used on purpose: the HTTPS form returned **HTTP 500**
  when serving the packfile, for both full and shallow clones.
- `--depth=1` is a shallow clone (~264 MB). To get full history later:
  `git -C emacs-src fetch --unshallow` (this may hit the same server errors).
- The latest **release** is `emacs-31.1`. `master` is the development line
  (32.0.50). To build the release instead, run `git -C emacs-src fetch --depth=1
  origin tag emacs-31.1 && git -C emacs-src checkout emacs-31.1` (untested here).
- `autogen.sh` (run automatically by `build.sh`) also installs Emacs's own git
  hooks into `emacs-src/.git/hooks/`. That is normal and stays inside the clone.

## 3. Build

```sh
./build.sh            # configure + make + install + prune
./build.sh configure  # or one step at a time: configure | make | install | prune
./build.sh packages   # install Evil into config/elpa (network)
./build.sh grammars   # build the Java and Rust tree-sitter grammars (network, C compiler)
./build.sh test       # run the test suite
./build.sh doctor     # check what makes Emacs slow or stuck (PATH, disk, fonts, processes)
```

### What `build.sh` configures

```
--prefix=$PWD/install
--with-native-compilation=aot
--with-tree-sitter --with-sqlite3 --with-harfbuzz --with-modules
--with-pgtk                      (Linux only)
```

| Flag | Meaning and trade-off |
|---|---|
| `--with-native-compilation=aot` | Compile all built-in Lisp to machine code **during the build**. Slow build, fast from first launch. Use `=yes` for a faster build that compiles lazily in the background instead |
| `--with-tree-sitter` | Built-in modern syntax parsing |
| `--with-sqlite3` | Built-in SQLite (used by some packages) |
| `--with-harfbuzz` | Correct font shaping (ligatures, glyph fallback) |
| `--with-modules` | Dynamic modules. Not currently used |
| `--with-pgtk` | Pure-GTK toolkit for Wayland. Works under WSLg. For X11 use `--with-x-toolkit=gtk3` instead |

Confirmed in the configure summary: native compiler, tree-sitter, GnuTLS,
HarfBuzz, dynamic modules, threading, portable dumper all reported **yes**.

Not enabled (nothing uses them): xwidgets, systemd, SELinux, ACLs.

### Build time and size

- The `aot` compile is the slow part (tens of minutes on 16 cores; I did not
  time it precisely).
- `build/` is ~434 MB. The binary is 25 MB plus a 17.7 MB `emacs.pdmp`.
- `install/` is 308 MB before pruning and 257 MB after.

## 4. Run

```sh
# pruned install (the normal way)
install/bin/emacs --init-directory=$PWD/config

# straight from the build tree (unpruned, no install needed)
build/src/emacs --init-directory=$PWD/config
```

`--init-directory` points Emacs at `config/` instead of `~/.emacs.d`, so your
other Emacs (Ubuntu's 29.3) and its files are untouched.

To open a window from a script, run it in the background:
`install/bin/emacs --init-directory=$PWD/config &`.

## A new computer, or a new version of Emacs

**What comes with the repository** (a fresh clone is 56 files, about 400 KB): the config,
the build and pruning scripts, the tests and the docs. **What does not** (recreate it, each
by one command): the Emacs source and build, the installed packages, the tree-sitter
grammars, the language servers, your fonts, and the commit hook.

On a new Linux machine:

```sh
git clone git@github.com:wantharry/custom-emacs.git && cd custom-emacs
git config core.hooksPath .githooks            # the commit-time test hook
./build.sh doctor --no-gui                     # what is missing, and what will be slow
# get an Emacs: either build one (see above) ...
./build.sh                                     # source + configure + compile + install + prune
# ... or use one you already have (Emacs 30 or newer):
export EMACS=/path/to/emacs
./build.sh packages                            # Evil
./build.sh grammars                            # tree-sitter grammars (needs git and a C compiler)
./build.sh test                                # everything should say ALL TESTS PASSED
```

Tested exactly this way from a fresh GitHub clone (using the Emacs built here): after
`packages` and `grammars`, **all tests pass**, including the real downloads, the real
`rust-analyzer` and `jdtls` sessions, the real window and the real terminal. The language
servers themselves (JDK, Rust, `jdtls`) are installed separately; see
[LANGUAGES.md](LANGUAGES.md).

**Versions.** The config needs **Emacs 30 or newer** and is built and tested on 32.0.50. On
Ubuntu's Emacs 29.3 it stops at startup with a clear message (measured: it lacks
`global-completion-preview-mode`, the built-in `which-key`, and Eglot's log setting).
`EMACS=/path ./build.sh test` runs the whole suite against any Emacs.

**When a new Emacs version comes out** (the tests exist for exactly this):

1. Build or install it and run `EMACS=/path/to/new/emacs ./build.sh test --gui`.
2. A failure names the exact thing that changed. This has already happened: Evil 1.15 read an
   internal variable that Emacs 32 removed, and the test
   `evil/no-post-command-hook-errors-on-emacs-32` caught it.
3. After a source upgrade, also run `./tools/verify-prune.sh`: a new version can change which
   built-in files depend on which, so the pruning list must be re-verified.
4. Update the pinned tree-sitter grammar versions only if the new Emacs bundles a newer
   tree-sitter library (see [LANGUAGES.md](LANGUAGES.md#why-the-grammars-are-pinned)).

**Other operating systems.** macOS and Windows have not been tried. Linux other than
Ubuntu 24.04 needs the equivalent of the package list in "System packages" above. See
[CROSS-PLATFORM.md](CROSS-PLATFORM.md).

## Rebuilding after changes

| You changed | Run |
|---|---|
| `config/*.el` | Nothing. Restart, or evaluate live |
| A file in `emacs-src/lisp/` | `./build.sh make` (recompiles only that file) |
| A file in `emacs-src/src/` | `./build.sh make` (rebuilds and relinks only what changed) |
| `prune.list` | `./build.sh install && ./build.sh prune` (see below) |
| Anything | `./build.sh test`, **always** (see [TESTING.md](TESTING.md)) |

Changing `prune.list` to keep something that was pruned needs a fresh
`./build.sh install`, because pruning deletes files from `install/`.

## Updating from upstream

```sh
git -C emacs-src pull            # uses the git:// remote
./build.sh make
./build.sh install && ./build.sh prune
```

If the pull changes `configure.ac`, run `./build.sh configure` first. Because
this is `master`, expect occasional breakage between commits; the tag
`emacs-31.1` is the stable alternative.

## Using `make` directly

```sh
make -C build -j16            # compile
make -C build install         # install to ./install
make -C build check           # run Emacs's own test suite (not run here)
```
