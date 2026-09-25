#!/usr/bin/env bash
# Verify a pruned install against the unpruned build.
#  1. Run realistic workflows on both binaries (network needed for package/url).
#  2. Trace the files the workflows load on the UNPRUNED build and report any
#     that are on the removal list (those would break after pruning).
#  3. `require` every bundled package on both and list new failures.
# Needs build/src/emacs and install/bin/emacs. Exit status 1 if a problem found.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$(mktemp -d)"
FULL="$ROOT/build/src/emacs"
PRUNED="$ROOT/install/bin/emacs"
WFS="package-refresh package-install package-install-signed url-https shr vc diff-ediff dired-grep-find help customize calendar tramp compile-edebug-ert compose-mail eglot-project-xref treesit-python-js misc-ui"
fail=0

run_all() {   # $1 = binary
  for w in $WFS; do
    line=$(S="$OUT" R="$ROOT" timeout 240 "$1" -Q --batch --init-directory="$OUT/home" \
           -l "$ROOT/tools/workflows.el" --eval "(run-workflow \"$w\")" 2>&1 \
           | grep -E '^[a-z-]+ +(OK|ERROR)' || echo "$w  ERROR: no result")
    echo "$line"; case "$line" in *ERROR*) fail=1 ;; esac
  done
}

echo "== 1. workflows on the UNPRUNED build (also records loaded files)"
run_all "$FULL"
echo
echo "== 2. files those workflows loaded that are on the removal list"
python3 - "$OUT" "$ROOT" <<'PY' || fail=1
import sys, re, glob, os, subprocess
out, root = sys.argv[1:3]
prune = set(subprocess.run(["python3", f"{root}/prune.py", "--list"], capture_output=True, text=True, cwd=root).stdout.split())
hits = {}
for f in sorted(glob.glob(f"{out}/trace-*.txt")):
    wf = os.path.basename(f)[6:-4]
    for line in open(f):
        m = re.search(r"emacs-src/lisp/(.*?)\.elc?$", line.strip())
        if m and m.group(1) in prune:
            hits.setdefault(m.group(1), set()).add(wf)
if hits:
    for k, v in sorted(hits.items()):
        print(f"  PROBLEM {k:30} loaded by: {', '.join(sorted(v))}")
    print("  -> add '!<path>.el' lines to prune.list, then ./build.sh install && ./build.sh prune")
    sys.exit(1)
print("  none")
PY
echo
echo "== 3. the same workflows on the PRUNED install"
run_all "$PRUNED"
echo
echo "== 4. require every bundled package: failures only on the pruned build"
"$FULL"   -Q --batch -l "$ROOT/tools/requireall.el" 2>&1 | grep -E '^(FAIL|SUMMARY)' > "$OUT/full.txt"
"$PRUNED" -Q --batch -l "$ROOT/tools/requireall.el" 2>&1 | grep -E '^(FAIL|SUMMARY)' > "$OUT/pruned.txt"
grep SUMMARY "$OUT/full.txt" "$OUT/pruned.txt" | sed "s#$OUT/##"
echo "new failures (should be exactly the packages you removed):"
diff <(grep ^FAIL "$OUT/full.txt" | sed 's/:.*//;s/^FAIL //' | sort) \
     <(grep ^FAIL "$OUT/pruned.txt" | sed 's/:.*//;s/^FAIL //' | sort) | grep '^>' | sed 's/^> //' | tr '\n' ' '
echo
[ "$fail" = 0 ] && echo "RESULT: all checks passed" || echo "RESULT: PROBLEMS FOUND (see above)"
exit $fail
