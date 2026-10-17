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
EMACS="$ROOT/install/bin/emacs"
EMACSCLIENT="$ROOT/install/bin/emacsclient"
CACHE="$ROOT/dist/cache"
GOTTY_VERSION=1.10.0
GOTTY_ASSET="gotty_v${GOTTY_VERSION}_linux_amd64.tar.gz"
GOTTY_BIN="$CACHE/gotty"

[ -x "$EMACS" ] || { echo "No built Emacs at $EMACS --- run ./build.sh first." >&2; exit 1; }

if [ ! -x "$GOTTY_BIN" ]; then
  echo "== fetching gotty v$GOTTY_VERSION (sorenisanerd/gotty, the same fork the real Cloudmacs Dockerfile uses)"
  mkdir -p "$CACHE"
  curl -fsSL -o "$CACHE/$GOTTY_ASSET" \
    "https://github.com/sorenisanerd/gotty/releases/download/v${GOTTY_VERSION}/${GOTTY_ASSET}"
  curl -fsSL -o "$CACHE/gotty-SHA256SUMS" \
    "https://github.com/sorenisanerd/gotty/releases/download/v${GOTTY_VERSION}/SHA256SUMS"
  want="$(grep " $GOTTY_ASSET\$" "$CACHE/gotty-SHA256SUMS" | cut -d' ' -f1)"
  got="$(sha256sum "$CACHE/$GOTTY_ASSET" | cut -d' ' -f1)"
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
