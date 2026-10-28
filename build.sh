#!/usr/bin/env bash
# Build the research Emacs from ./emacs-src into ./build, install it into
# ./install, and optionally prune unused built-in Lisp from the install.
# Verified on: Ubuntu 24.04 (WSL2), Emacs 32.0.50 (master @ 7bc4f49).
#
# Usage: ./build.sh [configure|make|install|prune|packages|grammars|screenshots|dist|doctor|test|all]   (default: all)
#   configure  run autogen.sh (if needed) and configure, into ./build
#   make       compile (slow the first time: native-comp is ahead-of-time)
#   install    make install into ./install (gitignored)
#   prune      remove the Lisp listed in prune.list from ./install
#   packages   install the chosen ELPA packages (evil) into config/elpa
#   grammars   build the tree-sitter grammars (java, rust) into config/tree-sitter
#   screenshots OUTDIR FILE...   save PNGs of files as a real Emacs window draws them
#   doctor     check what makes Emacs slow or stuck (esp. on WSL): PATH, disk, fonts, processes
#   test       run the whole test suite (see docs/TESTING.md)
#   dist       windows|linux|macos   build a portable bundle (a zip you can unpack anywhere and run) into ./dist
#   all        configure + make + install + prune
# EMACS=/path/to/emacs makes packages, grammars, screenshots, doctor and test use that Emacs
# instead of building one (needs Emacs 30 or newer).
# See docs/BUILD.md and docs/PRUNING.md.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
SRC="$ROOT/emacs-src"
BUILD="$ROOT/build"
INSTALL="$ROOT/install"

# Common flags. --with-native-compilation=aot precompiles all built-in Lisp
# (slow build, fast startup); use =yes to compile lazily instead.
FLAGS=(--prefix="$INSTALL"
       --with-native-compilation=aot
       --with-tree-sitter --with-sqlite3 --with-harfbuzz --with-modules)

case "$(uname -s)" in
  Linux)  FLAGS+=(--with-pgtk) ;;      # Wayland/WSLg; use --with-x-toolkit=gtk3 for X11
  Darwin) FLAGS+=(--with-ns) ;;        # UNTESTED
  MINGW*|MSYS*) ;;                     # UNTESTED: run inside an MSYS2 MinGW64 shell
esac

configure() {
  [ -x "$SRC/configure" ] || (cd "$SRC" && ./autogen.sh)
  mkdir -p "$BUILD" && cd "$BUILD" && "$SRC/configure" "${FLAGS[@]}"
}
pick_emacs() {   # EMACS=/path overrides; else the pruned install; else the build tree
  if [ -n "${EMACS:-}" ]; then echo "$EMACS"
  elif [ -x "$INSTALL/bin/emacs" ]; then echo "$INSTALL/bin/emacs"
  else echo "$BUILD/src/emacs"; fi
}
ncpus() { nproc 2>/dev/null || sysctl -n hw.ncpu; }
# WHAT/WHY: a real, confirmed bug in upstream Emacs's own top-level Makefile.in, not
# this script or this machine --- its own `info_dir_deps'/doc-translations machinery
# (the comment right next to it in Makefile.in even names this exact class of problem:
# "two sub-makes producing the same outputs race under 'make -j'") can fail parallel
# `make -jN' with `Makefile:NNNN: *** multiple target patterns.  Stop.', a parse-time
# error from a generated Makefile fragment caught mid-write by a second, concurrent
# sub-make reading it --- confirmed directly: the exact same source, built serially
# (`-j1'), compiled cleanly every time. Retrying serially ONLY on failure keeps parallel
# compilation (the slow part, native-comp AOT) fast on the common path, while never
# leaving a real race looking like a broken build.
build() {
  make -C "$BUILD" -j"$(ncpus)" || {
    echo "build.sh: parallel build failed (a known upstream make -jN race, not" \
         "necessarily a broken source tree) --- retrying serially (-j1)..." >&2
    make -C "$BUILD" -j1
  }
}
install_() { make -C "$BUILD" install; }
prune()   { python3 "$ROOT/prune.py" --apply "$INSTALL"; }
packages() {
  local emacs; emacs="$(pick_emacs)"
  "$emacs" --batch --init-directory="$ROOT/config" -l "$ROOT/tools/install-packages.el"
}
grammars() {
  local emacs; emacs="$(pick_emacs)"
  "$emacs" --batch --init-directory="$ROOT/config" -l "$ROOT/tools/install-grammars.el"
}
screenshots() {
  local out="${1:?usage: build.sh screenshots OUTDIR FILE...}"; shift
  local emacs; emacs="$(pick_emacs)"
  local dir; dir="$(mktemp -d)"
  cp "$ROOT/config/early-init.el" "$ROOT/config/init.el" "$ROOT/config/fastfind.el" "$ROOT/config/startpage.el" "$ROOT/config/docsbuffer.el" "$ROOT/config/gitfolders.el" "$ROOT/config/llm.el" "$ROOT/config/llm-council.el" "$ROOT/config/shortcuts.el" "$ROOT/config/dictate.el" "$ROOT/config/emacs-session.el" "$ROOT/config/calendar-year.el" "$ROOT/config/mode-reference.el" "$ROOT/config/disk-usage.el" "$dir/"
  for d in elpa tree-sitter; do [ -d "$ROOT/config/$d" ] && ln -s "$ROOT/config/$d" "$dir/$d"; done
  SHOT_DIR="$out" SHOT_FILES="$(IFS=:; echo "$*")" "$emacs" --init-directory="$dir" -l "$dir/early-init.el" -l "$dir/init.el" -l "$ROOT/tools/gui-screenshot.el" >/dev/null 2>&1
  ls "$out"/*.png
}
dist_env() {   # the two tools the bundles need, kept in dist/.venv so nothing is installed system-wide
  # On CI (GitHub Actions' Windows runner, this script's own WSL job), $ROOT sits on
  # the slow DrvFs-mounted Windows drive (/mnt/d/...) --- a venv plus ziglang's own
  # hefty wheel (it bundles the real zig compiler) is dramatically slower to create and
  # to run there than on WSL's native filesystem, DrvFs's well-known weak point being
  # many-small-files I/O, which both venv creation and an unpacked compiler toolchain
  # are full of. Confirmed directly: ~14 minutes for venv creation + pip install alone
  # on that mount, a step that takes well under a minute natively, and every later
  # `zig cc' invocation paying the same slow-I/O tax reading the toolchain back from
  # there. Local dev (already on a native filesystem) keeps the original, repo-local
  # dist/.venv; CI redirects to WSL's own home directory instead. PATCHELF/ZIG_PYTHON
  # exported either way so dist-linux.sh/dist-windows.sh pick this up transparently,
  # without each needing their own copy of this same CI check.
  local venv="$ROOT/dist/.venv"
  [ -n "${CI:-}" ] && venv="$HOME/.cache/custom-emacs-dist-venv"
  if [ ! -x "$venv/bin/python" ]; then
    mkdir -p "$(dirname "$venv")" && python3 -m venv "$venv"
    "$venv/bin/pip" install -q patchelf ziglang
  fi
  export PATCHELF="$venv/bin/patchelf" ZIG_PYTHON="$venv/bin/python"
}
dist() {
  case "${1:-}" in
    windows) dist_env; "$ROOT/tools/dist-windows.sh" ;;
    linux)   dist_env; "$ROOT/tools/dist-linux.sh" ;;
    macos)   "$ROOT/tools/dist-macos.sh" ;;
    *) echo "usage: $0 dist windows|linux|macos" >&2; exit 2 ;;
  esac
}
run_doctor() { "$ROOT/tools/doctor.sh" "$@"; }
run_tests() { "$ROOT/tests/run-all.sh" "$@"; }

case "${1:-all}" in
  configure) configure ;;
  make)      build ;;
  install)   install_ ;;
  prune)     prune ;;
  packages)  packages ;;
  grammars)  grammars ;;
  screenshots) shift; screenshots "$@" ;;
  dist)      shift; dist "$@" ;;
  doctor)    shift; run_doctor "$@" ;;
  test)      shift; run_tests "$@" ;;
  all)       configure && build && install_ && prune ;;
  *) echo "usage: $0 [configure|make|install|prune|packages|grammars|screenshots|dist|doctor|test|all]" >&2; exit 2 ;;
esac
echo "Run: $INSTALL/bin/emacs --init-directory=$ROOT/config"
echo "  (unpruned, straight from the build tree: $BUILD/src/emacs)"
