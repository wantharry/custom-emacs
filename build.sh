#!/usr/bin/env bash
# Build the research Emacs from ./emacs-src into ./build, install it into
# ./install, and optionally prune unused built-in Lisp from the install.
# Verified on: Ubuntu 24.04 (WSL2), Emacs 32.0.50 (master @ 7bc4f49).
#
# Usage: ./build.sh [configure|make|install|prune|packages|grammars|screenshots|doctor|test|all]   (default: all)
#   configure  run autogen.sh (if needed) and configure, into ./build
#   make       compile (slow the first time: native-comp is ahead-of-time)
#   install    make install into ./install (gitignored)
#   prune      remove the Lisp listed in prune.list from ./install
#   packages   install the chosen ELPA packages (evil) into config/elpa
#   grammars   build the tree-sitter grammars (java, rust) into config/tree-sitter
#   screenshots OUTDIR FILE...   save PNGs of files as a real Emacs window draws them
#   doctor     check what makes Emacs slow or stuck (esp. on WSL): PATH, disk, fonts, processes
#   test       run the whole test suite (see docs/TESTING.md)
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
build()   { make -C "$BUILD" -j"$(ncpus)"; }
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
  cp "$ROOT/config/early-init.el" "$ROOT/config/init.el" "$dir/"
  for d in elpa tree-sitter; do [ -d "$ROOT/config/$d" ] && ln -s "$ROOT/config/$d" "$dir/$d"; done
  SHOT_DIR="$out" SHOT_FILES="$(IFS=:; echo "$*")" "$emacs" --init-directory="$dir" -l "$dir/early-init.el" -l "$dir/init.el" -l "$ROOT/tools/gui-screenshot.el" >/dev/null 2>&1
  ls "$out"/*.png
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
  doctor)    shift; run_doctor "$@" ;;
  test)      shift; run_tests "$@" ;;
  all)       configure && build && install_ && prune ;;
  *) echo "usage: $0 [configure|make|install|prune|packages|grammars|screenshots|doctor|test|all]" >&2; exit 2 ;;
esac
echo "Run: $INSTALL/bin/emacs --init-directory=$ROOT/config"
echo "  (unpruned, straight from the build tree: $BUILD/src/emacs)"
