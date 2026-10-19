#!/usr/bin/env bash
# Run THIS project's own custom-emacs in a browser tab, local machine only.
#   tools/cloudmacs.sh [PORT]        (default port 8080)
# Same trick as the real "Cloudmacs" project (karlicoss/cloudmacs): Gotty serves
# `emacsclient --tty` as a web terminal, so closing the tab (or losing the
# connection) does not kill the session --- it is just a real Emacs daemon,
# reachable again next time. Deliberately NOT that project's own Docker image:
# its Dockerfile (github.com/karlicoss/cloudmacs) is built on `silex/emacs:
# master-alpine`, a different Emacs entirely, musl-linked --- this project's own
# native-compiled `.eln' files are glibc-linked (built on Ubuntu) and simply will
# not load under musl, the exact "machine-specific native-build artifact" problem
# `tests/test_dist.py' already guards the Windows/Linux dist zips against. Running
# Gotty directly against this host's own already-built `install/bin/emacs' avoids
# that mismatch entirely and needs no Docker at all.
# Bound to 127.0.0.1 only (not 0.0.0.0): this is local-machine convenience, not a
# self-hosted server --- no auth is set up, so it must not be reachable from
# anywhere else. See docs/CLOUDMACS.md before changing that.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PORT="${1:-8080}"
CACHE="$ROOT/dist/cache"
GOTTY_VERSION=1.10.0

# Picks the Gotty asset for whatever machine this actually is, and an Emacs/emacsclient to
# run: EMACS=/EMACSCLIENT= override first; else this repo's own from-source Linux build
# (install/bin/emacs, the original target this script was written for); else, on macOS, a
# Homebrew emacs-plus install (brew --prefix emacs-plus@31, falling back to plain `emacs` on
# PATH) -- there is no from-source Darwin build here (see docs/CROSS-PLATFORM.md), the same
# reason tools/dist-macos.sh uses emacs-plus instead of ./build.sh for the macOS bundle.
os="$(uname -s)"; arch="$(uname -m)"
case "$os-$arch" in
  Linux-x86_64)  GOTTY_ASSET="gotty_v${GOTTY_VERSION}_linux_amd64.tar.gz" ;;
  Linux-aarch64) GOTTY_ASSET="gotty_v${GOTTY_VERSION}_linux_arm64.tar.gz" ;;
  Darwin-arm64)  GOTTY_ASSET="gotty_v${GOTTY_VERSION}_darwin_arm64.tar.gz" ;;
  Darwin-x86_64) GOTTY_ASSET="gotty_v${GOTTY_VERSION}_darwin_amd64.tar.gz" ;;
  *) echo "No known gotty asset for $os-$arch; see https://github.com/sorenisanerd/gotty/releases/tag/v$GOTTY_VERSION" >&2; exit 1 ;;
esac
GOTTY_BIN="$CACHE/gotty"

if [ -n "${EMACS:-}" ]; then
  : # explicit override, used as-is
elif [ -x "$ROOT/install/bin/emacs" ]; then
  EMACS="$ROOT/install/bin/emacs"
  EMACSCLIENT="${EMACSCLIENT:-$ROOT/install/bin/emacsclient}"
elif [ "$os" = Darwin ] && command -v brew >/dev/null && brew --prefix emacs-plus@31 >/dev/null 2>&1; then
  EMACS="$(brew --prefix emacs-plus@31)/bin/emacs"
  EMACSCLIENT="${EMACSCLIENT:-$(brew --prefix emacs-plus@31)/bin/emacsclient}"
elif command -v emacs >/dev/null; then
  EMACS="$(command -v emacs)"
  EMACSCLIENT="${EMACSCLIENT:-$(command -v emacsclient)}"
else
  echo "No Emacs found --- set EMACS=/path/to/emacs (and EMACSCLIENT= if it is not alongside it)," >&2
  echo "or run ./build.sh first (Linux) / brew install emacs-plus@31 (macOS)." >&2
  exit 1
fi
EMACSCLIENT="${EMACSCLIENT:-$(dirname "$EMACS")/emacsclient}"
[ -x "$EMACS" ] || { echo "No built Emacs at $EMACS" >&2; exit 1; }
[ -x "$EMACSCLIENT" ] || { echo "No emacsclient at $EMACSCLIENT" >&2; exit 1; }

# shasum -a 256 on macOS, sha256sum on Linux -- no single name both ship by default.
sha256() { command -v sha256sum >/dev/null && sha256sum | cut -d' ' -f1 || shasum -a 256 | cut -d' ' -f1; }

if [ ! -x "$GOTTY_BIN" ]; then
  echo "== fetching gotty v$GOTTY_VERSION (sorenisanerd/gotty, the same fork the real Cloudmacs Dockerfile uses)"
  mkdir -p "$CACHE"
  curl -fsSL -o "$CACHE/$GOTTY_ASSET" \
    "https://github.com/sorenisanerd/gotty/releases/download/v${GOTTY_VERSION}/${GOTTY_ASSET}"
  curl -fsSL -o "$CACHE/gotty-SHA256SUMS" \
    "https://github.com/sorenisanerd/gotty/releases/download/v${GOTTY_VERSION}/SHA256SUMS"
  want="$(grep " $GOTTY_ASSET\$" "$CACHE/gotty-SHA256SUMS" | cut -d' ' -f1)"
  got="$(sha256 < "$CACHE/$GOTTY_ASSET")"
  [ -n "$want" ] && [ "$got" = "$want" ] || { echo "CHECKSUM MISMATCH for $GOTTY_ASSET" >&2; exit 1; }
  echo "   $GOTTY_ASSET matches the checksum published by GitHub"
  tar -xzf "$CACHE/$GOTTY_ASSET" -C "$CACHE" ./gotty
  chmod +x "$GOTTY_BIN"
fi

# `-e '(+ 1 1)'` is just a cheap, side-effect-free ping --- if a daemon using this
# same install (same default socket) is already up, reuse it instead of starting
# a second one.
if ! "$EMACSCLIENT" -e '(+ 1 1)' >/dev/null 2>&1; then
  echo "== starting the Emacs daemon ($EMACS --init-directory=$ROOT/config --daemon)"
  "$EMACS" --init-directory="$ROOT/config" --daemon
fi

echo "== Cloudmacs (local): http://127.0.0.1:$PORT  (Ctrl-C here stops serving it; the Emacs daemon itself keeps running)"
exec "$GOTTY_BIN" --address 127.0.0.1 --port "$PORT" --permit-write --reconnect \
  "$EMACSCLIENT" --tty -c
