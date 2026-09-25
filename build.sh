#!/usr/bin/env bash
# Build the research Emacs from ./emacs-src into ./build.
# Verified on: Ubuntu 24.04 (WSL2), Emacs 32.0.50 (master @ 7bc4f49).
# Usage: ./build.sh [configure|make|all]   (default: all)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
SRC="$ROOT/emacs-src"
BUILD="$ROOT/build"

# Common flags. --with-native-compilation=aot precompiles all built-in Lisp
# (slow build, fast startup); use =yes to compile lazily instead.
FLAGS=(--prefix="$ROOT/install"
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
build() { make -C "$BUILD" -j"$(nproc 2>/dev/null || sysctl -n hw.ncpu)"; }

case "${1:-all}" in
  configure) configure ;;
  make)      build ;;
  all)       configure && build ;;
  *) echo "usage: $0 [configure|make|all]" >&2; exit 2 ;;
esac
echo "Run: $BUILD/src/emacs --init-directory=$ROOT/config"
