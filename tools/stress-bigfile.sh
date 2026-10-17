#!/usr/bin/env bash
# On-demand stress test with a real, huge (multi-million-line) text file ---
# NEVER run by tests/run-all.sh or any regression/build path, by explicit user
# request: it takes several minutes and needs a real GUI frame, not something to
# pay for on every commit. Run this by hand whenever you actually want it:
#
#   tools/stress-bigfile.sh                 5 nav rounds + 2 edit rounds (~4 min)
#   tools/stress-bigfile.sh --rounds N       N nav rounds instead of 5
#   tools/stress-bigfile.sh --keep           leave the test file in place afterward
#
# Needs a real X11 DISPLAY (WSLg's :0, or any other) --- this drives a real
# `--fg-daemon' frame through `emacsclient', the same discipline this project's
# own line-numbers performance investigation established: a plain `--batch'
# invocation never exercises real redisplay, so timings there are meaningless.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EMACS="${EMACS:-$ROOT/install/bin/emacs}"
EMACSCLIENT="${EMACSCLIENT:-$ROOT/install/bin/emacsclient}"
[ -x "$EMACS" ] || EMACS="$ROOT/build/src/emacs"
[ -x "$EMACS" ] || { echo "no emacs binary found (build first, or set EMACS=)" >&2; exit 2; }
[ -n "${DISPLAY:-}" ] || { echo "no DISPLAY set --- this needs a real GUI frame" >&2; exit 2; }

ROUNDS=5
KEEP=0
for a in "$@"; do
  case "$a" in
    --rounds) shift_next=1 ;;
    --keep) KEEP=1 ;;
    [0-9]*) if [ "${shift_next:-0}" = 1 ]; then ROUNDS="$a"; shift_next=0; fi ;;
  esac
done

WORDS_SRC_URL="https://raw.githubusercontent.com/dwyl/english-words/refs/heads/master/words.txt"
WORK="$(mktemp -d)"
FILE="$WORK/words-20x.txt"
SOCK="stress-bigfile-$$"
TESTCFG="$WORK/config"

cleanup() {
  "$EMACSCLIENT" -s "$SOCK" -e '(kill-emacs)' >/dev/null 2>&1
  [ "$KEEP" = 1 ] || rm -rf "$WORK"
}
trap cleanup EXIT

echo "== building the test file (~20x a real word list, ~97MB/9.3M lines)"
curl -fsSL "$WORDS_SRC_URL" -o "$WORK/words.txt" || { echo "download failed" >&2; exit 1; }
: > "$FILE"
for _ in $(seq 1 20); do cat "$WORK/words.txt" >> "$FILE"; done
wc -l -c "$FILE"

echo "== staging an isolated copy of the real config (own session dir, never the real one)"
# WHY: config/emacs-session.el (desktop-save-mode) auto-restores previously open
# buffers at startup --- pointing straight at the real config/ dir would either
# disturb the user's real, persistent session, or (confirmed directly, the hard
# way, while building this script) reopen a STALE buffer left over from an
# earlier throwaway test daemon before this script's own large-file-warning
# override even takes effect, racing an unanswerable confirmation prompt and
# hanging every later `emacsclient' request to the same daemon. A fresh, empty
# session dir means `desktop-read' finds nothing to restore --- see emacs-
# session.el's own comment: "a fresh install ... desktop-read finds no file".
mkdir -p "$TESTCFG"
cp -r "$ROOT/config/." "$TESTCFG/"
rm -rf "$TESTCFG/session" "$TESTCFG"/*.eld "$TESTCFG/.emacs.desktop.lock" 2>/dev/null
rm -rf "$TESTCFG/elpa" "$TESTCFG/tree-sitter"
[ -d "$ROOT/config/elpa" ] && ln -s "$ROOT/config/elpa" "$TESTCFG/elpa"
[ -d "$ROOT/config/tree-sitter" ] && ln -s "$ROOT/config/tree-sitter" "$TESTCFG/tree-sitter"

echo "== starting a throwaway daemon with that isolated config"
DISPLAY="$DISPLAY" "$EMACS" --init-directory="$TESTCFG" --fg-daemon="$SOCK" \
  --eval '(setq large-file-warning-threshold most-positive-fixnum)' \
  > "$WORK/daemon.log" 2>&1 &
disown
sleep 3

BUFNAME="$(basename "$FILE")"
FILE_BYTES="$(wc -c < "$FILE" | tr -d ' ')"
"$EMACSCLIENT" -s "$SOCK" -c -n -e "(find-file \"$FILE\")" >/dev/null

echo "== waiting for the real 97MB read to finish (polling buffer-size, not a guessed sleep)"
for _ in $(seq 1 60); do
  SIZE="$("$EMACSCLIENT" -s "$SOCK" -e "(with-current-buffer \"$BUFNAME\" (buffer-size))" 2>&1)"
  [ "$SIZE" = "$FILE_BYTES" ] && break
  sleep 1
done
if [ "$SIZE" != "$FILE_BYTES" ]; then
  echo "file never finished loading (got $SIZE bytes, expected $FILE_BYTES) --- aborting" >&2
  exit 1
fi

echo "== line-number features after open (expect nil nil --- the 5MB auto-disable):"
"$EMACSCLIENT" -s "$SOCK" -e "
(progn (switch-to-buffer \"$BUFNAME\") (delete-other-windows)
       (list display-line-numbers-mode (bound-and-true-p my/absolute-line-numbers-margin-mode)))"
"$EMACSCLIENT" -s "$SOCK" -e "(load-file \"$ROOT/tests/stress/bigfile-bench.el\")" >/dev/null

echo "== $ROUNDS navigation rounds (reading/scrolling/searching), ~45s apart"
for i in $(seq 1 "$ROUNDS"); do
  echo "--- nav round $i at $(date +%H:%M:%S) ---"
  timeout 30 "$EMACSCLIENT" -s "$SOCK" -e "(bt/nav-round \"nav-$i\")"
  [ "$i" -lt "$ROUNDS" ] && sleep 40
done

echo "== 2 edit-stress rounds (insert/delete/kill-yank/undo/regexp-count on a throwaway copy)"
for i in 1 2; do
  echo "--- edit round $i at $(date +%H:%M:%S) ---"
  timeout 60 "$EMACSCLIENT" -s "$SOCK" -e "(bt/edit-round \"edit-$i\")"
done

echo "== done"
