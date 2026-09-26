#!/usr/bin/env bash
# Run the whole test suite: every ERT file in tests/ert/ plus the Python tests.
#
#   tests/run-all.sh              offline tests (run this after every change)
#   tests/run-all.sh --network    also tests that need internet access
#   tests/run-all.sh --lsp        also start real language servers (rust-analyzer, jdtls)
#   tests/run-all.sh --gui        also run inside a real Emacs window and a real terminal
#                                 (needs a display and tmux; skipped without them)
#   tests/run-all.sh --full       everything: network, language servers, GUI/terminal, verify-prune.sh
#   tests/run-all.sh NAME         only ERT files whose name contains NAME
#
# EMACS=/path/to/emacs overrides the binary (default: install/bin/emacs, else
# build/src/emacs).  Exit status is non-zero if anything fails.
#
# Each tests/ert/*.el has a header line ";; harness: X":
#   bare    emacs -Q                       (default Emacs, no config)
#   config  our config loaded              (copied to a temp dir, elpa linked)
#   noelpa  our config, no installed packages
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EMACS="${EMACS:-}"
[ -z "$EMACS" ] && [ -x "$ROOT/install/bin/emacs" ] && EMACS="$ROOT/install/bin/emacs"
[ -z "$EMACS" ] && EMACS="$ROOT/build/src/emacs"
[ -x "$EMACS" ] || { echo "no emacs binary found (build first, or set EMACS=)" >&2; exit 2; }

NETWORK=0; FULL=0; LSP=0; GUI=0; FILTER=""
for a in "$@"; do
  case "$a" in
    --network) NETWORK=1 ;;
    --lsp) LSP=1 ;;
    --gui) GUI=1 ;;
    --full) FULL=1; NETWORK=1; LSP=1; GUI=1 ;;
    -*) echo "unknown option $a" >&2; exit 2 ;;
    *) FILTER="$a" ;;
  esac
done
[ "$NETWORK" = 1 ] && export RUN_NETWORK_TESTS=1
[ "$LSP" = 1 ] && export RUN_LSP_TESTS=1
[ "$GUI" = 1 ] && export RUN_TUI_TESTS=1

OUT="$(mktemp -d)"; trap 'rm -rf "$OUT"' EXIT
export ROOT EMACS_BIN="$EMACS"

run_one() {   # $1 = test file
  local f="$1" name; name="$(basename "$f" .el)"
  local harness; harness="$(head -5 "$f" | grep -o 'harness: [a-z]*' | head -1 | cut -d' ' -f2)"
  harness="${harness:-bare}"
  local t0=$(date +%s.%N) status=0
  case "$harness" in
    bare)
      "$EMACS" -Q --batch -l "$ROOT/tests/ert/helper.el" -l "$f" \
        -f ert-run-tests-batch-and-exit > "$OUT/$name.log" 2>&1 || status=$? ;;
    config|noelpa)
      local dir="$OUT/init-$name"; mkdir -p "$dir"
      cp "$ROOT/config/early-init.el" "$ROOT/config/init.el" "$ROOT/config/fastfind.el" "$dir/"
      [ "$harness" = config ] && [ -d "$ROOT/config/elpa" ] && ln -s "$ROOT/config/elpa" "$dir/elpa"
      [ -d "$ROOT/config/tree-sitter" ] && ln -s "$ROOT/config/tree-sitter" "$dir/tree-sitter"
      CONFIG_DIR="$dir" "$EMACS" --batch --init-directory="$dir" \
        -l "$dir/early-init.el" -l "$dir/init.el" -l "$ROOT/tests/ert/helper.el" -l "$f" \
        -f ert-run-tests-batch-and-exit > "$OUT/$name.log" 2>&1 || status=$? ;;
    *) echo "bad harness '$harness' in $f" > "$OUT/$name.log"; status=99 ;;
  esac
  local t1=$(date +%s.%N)
  echo "$status $(printf '%.1f' "$(echo "$t1 - $t0" | bc)")" > "$OUT/$name.status"
}

files=()
for f in "$ROOT"/tests/ert/*.el; do
  [ "$(basename "$f")" = helper.el ] && continue
  [ -n "$FILTER" ] && [[ "$(basename "$f")" != *"$FILTER"* ]] && continue
  files+=("$f")
done

for f in "${files[@]}"; do
  while (( $(jobs -r | wc -l) >= 8 )); do sleep 0.1; done
  run_one "$f" &
done
wait

printf '%-26s %6s %6s %6s %7s %6s\n' "ERT FILE" "TESTS" "PASS" "FAIL" "SKIPPED" "SECS"
tot=0; pass=0; fail=0; skip=0; bad=0
for f in "${files[@]}"; do
  name="$(basename "$f" .el)"
  read -r status secs < "$OUT/$name.status"
  line="$(grep -E '^Ran [0-9]+ tests' "$OUT/$name.log" | tail -1)"
  if [ -z "$line" ]; then
    printf '%-26s %6s %6s %6s %7s %6s   CRASHED (exit %s)\n' "$name" "?" "-" "-" "-" "$secs" "$status"
    bad=1; sed 's/^/    | /' "$OUT/$name.log" | tail -15; continue
  fi
  n=$(sed -E 's/^Ran ([0-9]+) tests.*/\1/' <<<"$line")
  ok=$(sed -E 's/.*, ([0-9]+) results as expected.*/\1/' <<<"$line")
  un=$(sed -E 's/.*expected, ([0-9]+) unexpected.*/\1/' <<<"$line")
  sk=$(grep -oE '[0-9]+ skipped' <<<"$line" | cut -d' ' -f1); sk=${sk:-0}
  printf '%-26s %6s %6s %6s %7s %6s\n' "$name" "$n" "$ok" "$un" "$sk" "$secs"
  tot=$((tot+n)); pass=$((pass+ok)); fail=$((fail+un)); skip=$((skip+sk))
  if [ "$un" != 0 ]; then
    bad=1
    awk '/^Test .* condition:$/ {p=1; print "    | " $0; next}
         /^ +(FAILED|passed|SKIPPED) / {p=0}
         /^Test .* backtrace:$/ {p=0}
         p {print "    | " $0}' "$OUT/$name.log" | head -40
  fi
done
printf '%-26s %6s %6s %6s %7s\n' "ERT TOTAL" "$tot" "$pass" "$fail" "$skip"

if [ "$GUI" = 1 ]; then
  echo
  if [ -z "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]; then
    echo "GUI (real window): SKIPPED, no display in this session"
  else
    gdir="$OUT/init-gui"; mkdir -p "$gdir"
    cp "$ROOT/config/early-init.el" "$ROOT/config/init.el" "$ROOT/config/fastfind.el" "$gdir/"
    [ -d "$ROOT/config/elpa" ] && ln -s "$ROOT/config/elpa" "$gdir/elpa"
    [ -d "$ROOT/config/tree-sitter" ] && ln -s "$ROOT/config/tree-sitter" "$gdir/tree-sitter"
    gt0=$(date +%s.%N)
    GUI_LOG="$OUT/gui.log" GUI_TESTS="$FILTER" timeout 300 "$EMACS" --init-directory="$gdir" \
      -l "$gdir/early-init.el" -l "$gdir/init.el" -l "$ROOT/tests/ert/helper.el" \
      -l "$ROOT/tests/gui/gui-runner.el" > "$OUT/gui.err" 2>&1
    gexit=$?
    gsecs=$(printf '%.1f' "$(echo "$(date +%s.%N) - $gt0" | bc)")
    gline="$(grep -a -E '^Ran [0-9]+ tests' "$OUT/gui.log" 2>/dev/null | tail -1)"
    if [ -z "$gline" ]; then
      printf '%-26s CRASHED or timed out (%ss, exit %s)\n' "GUI (real window)" "$gsecs" "$gexit"; bad=1
      echo "    | --- Emacs output:"; grep -v 'Gdk-WARNING' "$OUT/gui.err" | sed 's/^/    | /' | tail -12
      echo "    | --- test log:"; sed 's/^/    | /' "$OUT/gui.log" 2>/dev/null | tail -12
    else
      gn=$(sed -E 's/^Ran ([0-9]+) tests.*/\1/' <<<"$gline")
      gok=$(sed -E 's/.*, ([0-9]+) results as expected.*/\1/' <<<"$gline")
      gun=$(sed -E 's/.*expected, ([0-9]+) unexpected.*/\1/' <<<"$gline")
      gsk=$(grep -oE '[0-9]+ skipped' <<<"$gline" | cut -d' ' -f1); gsk=${gsk:-0}
      printf '%-26s %6s %6s %6s %7s %6s\n' "GUI (real window)" "$gn" "$gok" "$gun" "$gsk" "$gsecs"
      if [ "$gun" != 0 ]; then
        bad=1
        awk '/^Test .* condition:$/ {p=1; print "    | " $0; next} /^ +(FAILED|passed|SKIPPED) / {p=0} p {print "    | " $0}' "$OUT/gui.log" | tr -cd '\11\12\40-\176' | head -30
      fi
    fi
  fi
fi

echo
py_out="$(cd "$ROOT" && python3 -m unittest discover -s tests -p 'test_*.py' 2>&1)"; py_status=$?
py_line="$(grep -E '^Ran [0-9]+ test' <<<"$py_out")"
echo "PYTHON: $py_line  $(tail -1 <<<"$py_out")"
[ "$py_status" != 0 ] && { bad=1; echo "$py_out" | tail -30 | sed 's/^/    | /'; }

if [ "$FULL" = 1 ]; then
  echo; echo "VERIFY-PRUNE:"; "$ROOT/tools/verify-prune.sh" | tail -6 || bad=1
fi

echo
if [ "$bad" = 0 ]; then echo "ALL TESTS PASSED"; else echo "TESTS FAILED"; fi
exit "$bad"
