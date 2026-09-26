#!/usr/bin/env bash
# Run the offline ERT tests with the Windows Emacs from an unpacked bundle, from WSL.
#
#   tools/test-windows.sh BUNDLE_DIR [FILTER]     BUNDLE_DIR is on the Windows drive (/mnt/c/...)
#
# Prints one line per test file (tests, passed, failed, skipped).  The logs are kept in
# dist/win-test-logs/.  Many tests assume Unix (symlinks, /tmp, sh); see docs/DISTRIBUTION.md.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
B="${1:?usage: tools/test-windows.sh BUNDLE_DIR [FILTER]}"; FILTER="${2:-}"
TMPWIN="$(cd /mnt/c && cmd.exe /c 'echo %TEMP%' 2>/dev/null | tr -d '\r')"
WT="$(wslpath "$TMPWIN")/custom-emacs-tests"
LOGS="$ROOT/dist/win-test-logs"; rm -rf "$WT" "$LOGS"; mkdir -p "$WT" "$LOGS"
cp -r "$ROOT/tests" "$WT/tests"; cp -r "$ROOT/tools" "$WT/tools"; cp -r "$ROOT/docs" "$WT/docs"; cp "$ROOT/README.md" "$ROOT/prune.list" "$WT/" 2>/dev/null
W() { wslpath -w "$1"; }
BW="$(W "$B")"
printf '%-24s %6s %6s %6s %7s\n' "FILE" "TESTS" "PASS" "FAIL" "SKIPPED"
for f in "$ROOT"/tests/ert/*.el; do
  name="$(basename "$f" .el)"; [ "$name" = helper ] && continue
  [ -n "$FILTER" ] && [[ "$name" != *"$FILTER"* ]] && continue
  harness="$(head -5 "$f" | grep -o 'harness: [a-z]*' | head -1 | cut -d' ' -f2)"; harness="${harness:-bare}"
  bat="$WT/run-$name.bat"; log="$WT/$name.log"
  {
    echo "@echo off"
    echo "set \"PATH=$BW\\tools\\git\\cmd;$BW\\tools\\git\\usr\\bin;$BW\\tools\\rg;%PATH%\""
    echo "set \"ROOT=$(W "$WT")\""
    echo "set \"EMACS_BIN=$BW\\emacs\\bin\\emacs.exe\""
    echo "set \"CUSTOM_EMACS_PORTABLE=1\""
    case "$harness" in
      bare) echo "\"%EMACS_BIN%\" -Q --batch -l \"%ROOT%\\tests\\ert\\helper.el\" -l \"%ROOT%\\tests\\ert\\$name.el\" -f ert-run-tests-batch-and-exit > \"$(W "$log")\" 2>&1" ;;
      *)
        dir="$WT/init-$name"; mkdir -p "$dir"
        cp "$B"/config/{early-init.el,init.el,fastfind.el,startpage.el} "$dir/"
        if [ "$harness" = config ]; then cp -r "$B/config/elpa" "$dir/elpa"; fi
        cp -r "$B/config/tree-sitter" "$dir/tree-sitter"
        echo "set \"CONFIG_DIR=$(W "$dir")\""
        echo "\"%EMACS_BIN%\" --batch --init-directory=\"%CONFIG_DIR%\" -l \"%CONFIG_DIR%\\early-init.el\" -l \"%CONFIG_DIR%\\init.el\" -l \"%ROOT%\\tests\\ert\\helper.el\" -l \"%ROOT%\\tests\\ert\\$name.el\" -f ert-run-tests-batch-and-exit > \"$(W "$log")\" 2>&1" ;;
    esac
  } > "$bat"
  ( cd /mnt/c && timeout 300 cmd.exe /c "$(W "$bat")" >/dev/null 2>&1 )
  cp "$log" "$LOGS/$name.log" 2>/dev/null
  line="$(grep -a -E '^Ran [0-9]+ tests' "$log" | tail -1)"
  if [ -z "$line" ]; then printf '%-24s %s\n' "$name" "DID NOT FINISH"; continue; fi
  total="$(echo "$line" | sed -E 's/^Ran ([0-9]+) tests.*/\1/')"
  unexp="$(echo "$line" | grep -o '[0-9]* unexpected' | cut -d' ' -f1)"; unexp="${unexp:-0}"
  skipped="$(echo "$line" | grep -o '[0-9]* skipped' | cut -d' ' -f1)"; skipped="${skipped:-0}"
  printf '%-24s %6s %6s %6s %7s\n' "$name" "$total" "$((total-unexp-skipped))" "$unexp" "$skipped"
done
