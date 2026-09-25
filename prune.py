#!/usr/bin/env python3
"""Plan or apply removal of unused built-in Emacs Lisp.

  prune.py --plan                 show what would go, and what was rescued
  prune.py --apply INSTALL_DIR    delete it from an installed tree (make install)

emacs-src/ is never modified. Anything in prune.list that a kept file still
loads (require/autoload/load) is rescued, repeatedly, until nothing kept
depends on something removed.
"""
import argparse, fnmatch, glob, os, re, sys

ROOT = os.path.dirname(os.path.abspath(__file__))
LISP = os.path.join(ROOT, "emacs-src", "lisp")
MANIFEST = os.path.join(ROOT, "prune.list")

# Only real load-time dependencies count. autoload calls are lazy (they fail
# only if that command is run), so they do not keep a file alive.
REQ = re.compile(r"\((?:require|load)\s+'?\"?([^\s)\"]+)")
# Generated autoload registries mention every function in Emacs, and obsolete/
# holds deprecated code nobody should be pinned by; ignore both as a source of
# dependencies.
SKIP_SRC = re.compile(r"(^obsolete/)|((^|/)(ldefs-boot|loaddefs|[^/]*-loaddefs|[^/]*-autoloads)$)")
COMPILE_ONLY = re.compile(r"eval-when-compile|declare-function|defvar\s|byte-compile")
EMACS = os.path.join(ROOT, "build", "src", "emacs")


def read_manifest():
    pats = []
    for line in open(MANIFEST):
        line = line.split("#", 1)[0].strip()
        if line:
            pats.append(line)
    return pats


def all_files():
    """rel path without .el -> absolute .el path"""
    out = {}
    for root, _, files in os.walk(LISP):
        for f in files:
            if f.endswith(".el"):
                p = os.path.join(root, f)
                out[os.path.relpath(p, LISP)[:-3]] = p
    return out


def matches(rel, pats):
    for p in pats:
        if p.endswith("/"):
            if rel.startswith(p):
                return True
        elif fnmatch.fnmatch(rel + ".el", p):
            return True
    return False


def needs(path):
    """Return (hard, soft) feature-name sets.

    hard: a top-level (column 0) require/load, or one directly inside a
          top-level eval-and-compile -- needed the moment the file loads.
    soft: an indented require inside a function or conditional -- lazy; it
          only fails if that particular code path runs.
    """
    hard, soft = set(), set()
    prev = ""
    for l in open(path, errors="replace"):
        stripped = l.lstrip()
        if stripped.startswith(";") or COMPILE_ONLY.search(l):
            prev = l
            continue
        for a in REQ.findall(l):
            feat = os.path.basename(a)
            top = l.startswith("(") or prev.startswith("(eval-and-compile")
            (hard if top else soft).add(feat)
        if stripped.strip():
            prev = l
    return hard, soft


def preloaded():
    """Files baked into the startup image; they must stay."""
    import subprocess
    if not os.path.exists(EMACS):
        return set()
    out = subprocess.run(
        [EMACS, "-Q", "--batch", "--eval",
         '(dolist (e load-history) (when (stringp (car e)) (princ (concat (car e) "\\n"))))'],
        capture_output=True, text=True).stdout
    keep = set()
    for line in out.splitlines():
        m = re.search(r"emacs-src/lisp/(.*?)\.elc?$", line)
        if m:
            keep.add(m.group(1))
    return keep


def plan():
    files = all_files()
    allpats = read_manifest()
    pats = [p for p in allpats if not p.startswith("!")]
    keeps = [p[1:] for p in allpats if p.startswith("!")]
    by_base = {}
    for rel in files:
        by_base.setdefault(os.path.basename(rel), []).append(rel)
    prune = {r for r in files if matches(r, pats) and not matches(r, keeps)}
    scanned = {r: (needs(p) if not SKIP_SRC.search(r) else (set(), set()))
               for r, p in files.items()}
    deps = {r: h for r, (h, _) in scanned.items()}
    soft = {r: sf for r, (_, sf) in scanned.items()}
    rescued = {}
    for r in sorted(prune & preloaded()):
        prune.discard(r)
        rescued[r] = "(preloaded into the startup image)"
    changed = True
    while changed:
        changed = False
        for rel in sorted(set(files) - prune):
            for feat in deps[rel]:
                for target in by_base.get(feat, []):
                    if target in prune:
                        prune.discard(target)
                        rescued[target] = rel
                        changed = True
    return files, prune, rescued, by_base, soft


def sizes(files, rels):
    return sum(os.path.getsize(files[r]) for r in rels)


def cmd_plan():
    files, prune, rescued, by_base, soft = plan()
    print(f"prune {len(prune)} of {len(files)} files "
          f"({sizes(files, prune)/1e6:.1f} MB of source)")
    print(f"rescued {len(rescued)} (still required by kept files):")
    for t, by in sorted(rescued.items()):
        print(f"  keep {t:35} needed by {by}")
    lazy = {}
    for rel, feats in soft.items():
        if rel in prune:
            continue
        for f in feats:
            for t in by_base.get(f, []):
                if t in prune:
                    lazy.setdefault(rel, set()).add(t)
    print(f"\nlazy dependencies on pruned files ({len(lazy)} kept files; each "
          "errors only if that code path runs):")
    for rel, ts in sorted(lazy.items()):
        print(f"  {rel:38} -> {', '.join(sorted(ts))}")
    print()
    top = {}
    for r in prune:
        k = r.split("/")[0] if "/" in r else "(top)"
        top[k] = top.get(k, 0) + 1
    print("pruned per directory:", dict(sorted(top.items())))


def cmd_apply(inst):
    files, prune, _, by_base, _soft = plan()
    lisp_dirs = glob.glob(os.path.join(inst, "share/emacs/*/lisp"))
    native = glob.glob(os.path.join(inst, "lib/emacs/*/native-lisp/*"))
    if not lisp_dirs:
        sys.exit(f"no installed lisp dir under {inst} (run make install first)")
    ld = lisp_dirs[0]
    removed = 0
    for rel in sorted(prune):
        base = os.path.basename(rel)
        for ext in (".el", ".el.gz", ".elc", ".elc.gz"):
            p = os.path.join(ld, rel + ext)
            if os.path.exists(p):
                os.remove(p); removed += 1
        # .eln names are flat; skip if a kept file shares the basename
        if all(r in prune for r in by_base[base]):
            for nd in native:
                for p in glob.glob(os.path.join(nd, f"{base}-*.eln")):
                    if re.fullmatch(re.escape(base) + r"-[0-9a-f]+-[0-9a-f]+\.eln",
                                    os.path.basename(p)):
                        os.remove(p); removed += 1
    for root, dirs, fs in os.walk(ld, topdown=False):
        if root != ld and not os.listdir(root):
            os.rmdir(root)
    print(f"removed {removed} files from {inst}")


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    g = ap.add_mutually_exclusive_group(required=True)
    g.add_argument("--plan", action="store_true")
    g.add_argument("--list", action="store_true")
    g.add_argument("--apply", metavar="INSTALL_DIR")
    a = ap.parse_args()
    if a.plan:
        cmd_plan()
    elif a.list:
        print("\n".join(sorted(plan()[1])))
    else:
        cmd_apply(a.apply)
