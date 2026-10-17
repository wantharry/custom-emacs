#!/usr/bin/env bash
# On-demand timing for everyday operations (open/type/page/save/search/Magit/
# theme/isearch/multiple-cursors) --- NEVER run by tests/run-all.sh or any
# regression/build path, by explicit user request. Run this by hand whenever
# you actually want it:
#
#   tools/stress-everyday.sh              3 rounds (~20s)
#   tools/stress-everyday.sh --rounds N   N rounds instead of 3
#   tools/stress-everyday.sh --startup N  also time N real cold starts (headless)
#
# Needs a real X11 DISPLAY --- this drives a real `--fg-daemon' frame through
# `emacsclient', the same discipline tools/stress-bigfile.sh already
# established: a plain `--batch' invocation never exercises real redisplay,
# so timings there would be meaningless.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EMACS="${EMACS:-$ROOT/install/bin/emacs}"
EMACSCLIENT="${EMACSCLIENT:-$ROOT/install/bin/emacsclient}"
[ -x "$EMACS" ] || EMACS="$ROOT/build/src/emacs"
[ -x "$EMACS" ] || { echo "no emacs binary found (build first, or set EMACS=)" >&2; exit 2; }
[ -n "${DISPLAY:-}" ] || { echo "no DISPLAY set --- this needs a real GUI frame" >&2; exit 2; }

ROUNDS=3
STARTUPS=0
for a in "$@"; do
  case "$a" in
    --rounds) shift_next=rounds ;;
    --startup) shift_next=startup ;;
    [0-9]*)
      case "${shift_next:-}" in
        rounds) ROUNDS="$a"; shift_next= ;;
        startup) STARTUPS="$a"; shift_next= ;;
      esac ;;
  esac
done

WORK="$(mktemp -d)"
TESTCFG="$WORK/config"
SOCK="stress-everyday-$$"

cleanup() {
  "$EMACSCLIENT" -s "$SOCK" -e '(kill-emacs)' >/dev/null 2>&1
  rm -rf "$WORK"
}
trap cleanup EXIT

echo "== staging an isolated copy of the real config (own session dir, never the real one)"
mkdir -p "$TESTCFG"
cp -r "$ROOT/config/." "$TESTCFG/"
rm -rf "$TESTCFG/session" "$TESTCFG"/*.eld "$TESTCFG/.emacs.desktop.lock" 2>/dev/null
rm -rf "$TESTCFG/elpa" "$TESTCFG/tree-sitter"
[ -d "$ROOT/config/elpa" ] && ln -s "$ROOT/config/elpa" "$TESTCFG/elpa"
[ -d "$ROOT/config/tree-sitter" ] && ln -s "$ROOT/config/tree-sitter" "$TESTCFG/tree-sitter"

if [ "$STARTUPS" -gt 0 ]; then
  echo "== $STARTUPS real cold starts (headless, --batch, the full real config)"
  for i in $(seq 1 "$STARTUPS"); do
    T0=$(date +%s.%N)
    "$EMACS" --batch --init-directory="$TESTCFG" -l "$TESTCFG/early-init.el" -l "$TESTCFG/init.el" --eval '(kill-emacs)' 2>/dev/null
    T1=$(date +%s.%N)
    echo "  cold start $i: $(echo "$T1 - $T0" | bc)s"
  done
fi

echo "== starting a throwaway daemon with that isolated config"
DISPLAY="$DISPLAY" "$EMACS" --init-directory="$TESTCFG" --fg-daemon="$SOCK" > "$WORK/daemon.log" 2>&1 &
disown
sleep 3

"$EMACSCLIENT" -s "$SOCK" -c -n -e '(find-file "/tmp/stress-everyday-scratch.txt")' >/dev/null
sleep 1
"$EMACSCLIENT" -s "$SOCK" -e "(progn (switch-to-buffer \"stress-everyday-scratch.txt\") (delete-other-windows))" >/dev/null
"$EMACSCLIENT" -s "$SOCK" -e "(setq eb/demo-dir \"$WORK/demo-project/\")" >/dev/null
"$EMACSCLIENT" -s "$SOCK" -e "(load-file \"$ROOT/tests/stress/everyday-bench.el\")" >/dev/null

echo "== $ROUNDS rounds of everyday operations"
for i in $(seq 1 "$ROUNDS"); do
  echo "--- round $i ---"
  timeout 30 "$EMACSCLIENT" -s "$SOCK" -e "(eb/round \"round-$i\")"
  "$EMACSCLIENT" -s "$SOCK" -e '(eb/cleanup-buffers)' >/dev/null
done

echo "== done"
