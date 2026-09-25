# Cross-platform plan (Windows and macOS)

> **Status: plan only, nothing here has been run.** Only the Linux build is
> verified. Treat every step below as a hypothesis until it is tried. Where I
> rely on a source, it is named.

## The core constraint

Emacs's source supports all three systems, but **each binary has to be built on
(or for) its own platform**. It cannot be produced from this Linux machine
in any practical way:

| Target | Realistic way to build | Why not from Linux |
|---|---|---|
| Linux | `./build.sh` (done) | n/a |
| Windows | Natively in **MSYS2 / MinGW-w64** on Windows or a Windows CI runner | Cross-compiling with `mingw-w64` is possible but every dependency (GnuTLS, tree-sitter, HarfBuzz, ...) must be cross-built too |
| macOS | On a Mac or a macOS CI runner | Needs Apple's SDK and toolchain |

Upstream's own instructions, in the source tree:

- Windows: `emacs-src/nt/INSTALL.W64` (MSYS2 and MinGW-w64; it states about 3 GB
  of disk space is required) and `emacs-src/nt/INSTALL`.
- macOS: `emacs-src/nextstep/INSTALL`.

## What is shared and what is not

| Part | Portable? |
|---|---|
| `config/init.el`, `early-init.el` | Yes. Uses only built-in features |
| Themes, mode line | Yes (Lisp), same colors everywhere |
| Fonts | **No.** They come from the OS; the font list has fallbacks but names differ per machine |
| `prune.list` / `prune.py` | List: yes. Script: only tested on the Linux `make install` layout |
| Native-compiled `.eln` files | **No.** Tied to machine and exact build; each platform compiles its own |
| `build.sh` | Linux verified; macOS and Windows branches are untested placeholders |

## Per-platform configure flags (hypothesis)

| Platform | Toolkit flag | Notes |
|---|---|---|
| Linux | `--with-pgtk` (Wayland) or `--with-x-toolkit=gtk3` (X11) | verified |
| Windows | default under MSYS2 (`w32`) | Run from an MSYS2 MinGW64 shell |
| macOS | `--with-ns` (Cocoa) | Or `--with-pgtk` with Homebrew GTK |

Keep the shared flags identical everywhere for consistent behavior:
`--with-native-compilation=aot --with-tree-sitter --with-sqlite3
--with-harfbuzz`.

## The hardest part: native compilation

- It needs a working C compiler and `libgccjit` at build time.
- On Windows and macOS, `libgccjit` availability is the first thing to check.
  If it cannot be made to work, fall back to `--with-native-compilation=no`
  (bytecode only) on that platform; the editor still works, only slower.
- Precompiled `.eln` files cannot be moved between machines.

## Prior art in this workspace

The separate **gitmacs** project (`~/projects/emacs/magit`) already ships on
Windows and documents these platform behaviors in its README. They are worth
checking on any Windows build here, but I have not verified them for this
project:

- It uses the **official Windows Emacs binary**, with the native-compiled code
  trimmed to the preloaded subset ("~250 MB of pre-compiled native code" dropped).
- Windows `emacsclient` does not support `-s` (socket name); it uses a
  `--server-file` instead.
- `package.el` GPG signature checks reportedly fail with `bad-signature` on
  Windows for untampered downloads; gitmacs disables the check on Windows only.

## Proposed CI (not written yet)

A GitHub Actions matrix, one job per OS:

| Job | Runner | Setup |
|---|---|---|
| Linux | `ubuntu-latest` | `apt-get install` the packages in [BUILD.md](BUILD.md), then `./build.sh` |
| Windows | `windows-latest` | `msys2/setup-msys2` action with MinGW-w64 toolchain and libraries, then configure and make per `nt/INSTALL.W64` |
| macOS | `macos-latest` | Homebrew for build tools and libraries, `--with-ns` |

Each job would upload its build as an artifact (zip / tarball / `.dmg`).
The repo to run it in already exists:
`git@github.com:wantharry/custom-emacs.git`.

Expect several rounds of fixes for Windows and macOS. Build the pruned tree on
each OS and rerun the verification in [PRUNING.md](PRUNING.md#verification-performed).

## Suggested order

1. Windows via MSYS2 with `--with-native-compilation=no` first, to prove the
   build itself works.
2. Add native compilation once `libgccjit` is confirmed.
3. macOS.
4. Only then automate in CI.
