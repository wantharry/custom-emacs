#!/usr/bin/env bash
# Build the research Emacs from ./emacs-src into ./build, install it into
# ./install, and optionally prune unused built-in Lisp from the install.
# Verified on: Ubuntu 24.04 (WSL2), Emacs 32.0.50 (master @ 7bc4f49).
#
# Usage: ./build.sh [configure|make|install|prune|packages|grammars|test|all]   (default: all)
#   configure  run autogen.sh (if needed) and configure, into ./build
#   make       compile (slow the first time: native-comp is ahead-of-time)
#   install    make install into ./install (gitignored)
#   prune      remove the Lisp listed in prune.list from ./install
#   packages   install the chosen ELPA packages (evil) into config/elpa
#   grammars   build the tree-sitter grammars (java, rust) into config/tree-sitter
#   test       run the whole test suite (see docs/TESTING.md)
#   all        configure + make + install + prune
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
ncpus() { nproc 2>/dev/null || sysctl -n hw.ncpu; }
build()   { make -C "$BUILD" -j"$(ncpus)"; }
install_() { make -C "$BUILD" install; }
prune()   { python3 "$ROOT/prune.py" --apply "$INSTALL"; }
packages() {
  local emacs="$INSTALL/bin/emacs"; [ -x "$emacs" ] || emacs="$BUILD/src/emacs"
  "$emacs" --batch --init-directory="$ROOT/config" -l "$ROOT/tools/install-packages.el"
}
grammars() {
  local emacs="$INSTALL/bin/emacs"; [ -x "$emacs" ] || emacs="$BUILD/src/emacs"
  "$emacs" --batch --init-directory="$ROOT/config" -l "$ROOT/tools/install-grammars.el"
}
run_tests() { "$ROOT/tests/run-all.sh" "$@"; }

case "${1:-all}" in
  configure) configure ;;
  make)      build ;;
  install)   install_ ;;
  prune)     prune ;;
  packages)  packages ;;
  grammars)  grammars ;;
  test)      shift; run_tests "$@" ;;
  all)       configure && build && install_ && prune ;;
  *) echo "usage: $0 [configure|make|install|prune|packages|grammars|test|all]" >&2; exit 2 ;;
esac
echo "Run: $INSTALL/bin/emacs --init-directory=$ROOT/config"
echo "  (unpruned, straight from the build tree: $BUILD/src/emacs)"
