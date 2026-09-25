# Pruning unused built-in packages

Emacs bundles far more than any one person uses. This project removes the parts
you do not want from the **installed copy** (`install/`), never from
`emacs-src/`, so the upstream checkout stays clean and `git pull` keeps working.

Verified on the Linux build, 2026-09-25. Windows and macOS: untested.

## Why not just delete folders?

Because Emacs's own code depends on some of them. For example `cedet/` holds
`mode-local` and `pulse`, and `mail/` holds `rfc822` and `mail-utils`, which
`url`, `eww` and others need. Deleting blindly produces errors that only appear
when you later use an unrelated feature.

So `prune.py` computes the dependencies first and refuses to remove anything a
kept file needs.

## Files

| File | Role |
|---|---|
| `prune.list` | What you want gone. Paths are relative to `emacs-src/lisp/`. A trailing `/` means a whole directory; other lines are globs. `#` starts a comment |
| `prune.py` | `--plan` shows what would go; `--apply DIR` deletes it from an installed tree |

```sh
python3 prune.py --plan            # dry run, prints what is pruned/kept/why
./build.sh prune                   # apply to ./install
```

## What is currently pruned

| Group | Removed from `prune.list` |
|---|---|
| Games and toys | `play/` |
| Notes / organizer | `org/` |
| Mail and news readers | `gnus/`, `mh-e/`, `mail/rmail*`, `undigest`, `unrmail`, `feedmail`, `mspools`, `supercite`, `net/newst-*`, `newsticker` |
| Chat | `erc/`, `net/rcirc.el` |
| Legacy IDE tooling | `cedet/` (CEDET, EDE, Semantic, SRecode) |

**Kept on purpose** (not in the list): `eshell`, `eww`, `calc`, `calendar`,
`nxml`, and every coding-related package (Eglot, Flymake, tree-sitter modes,
VC, TRAMP, Transient, ...). Add them to `prune.list` to remove them too.

## How the tool decides

1. Start from the files matched by `prune.list`.
2. Never remove files **preloaded into the startup image** (read from the
   built Emacs's `load-history`); they are baked in.
3. Scan every other Lisp file for `(require ...)` and `(load ...)`:
   - A **hard** dependency (at column 0, or directly inside a top-level
     `eval-and-compile`) is needed the moment the file loads. Anything hard-
     required by a kept file is **rescued** from removal, repeatedly, until
     nothing kept depends on something removed.
   - A **lazy** dependency (indented, inside a function) only fails if that
     specific code path runs. These are reported but do not keep a file.
4. Ignored as sources of dependencies:
   - Generated autoload registries (`ldefs-boot.el`, `loaddefs.el`,
     `*-loaddefs.el`, `*-autoloads.el`): they mention every function in Emacs.
   - `obsolete/`: deprecated code should not pin anything alive.
   - Lines inside `eval-when-compile`, `declare-function`, comments.
5. `--apply` deletes the `.el`, `.el.gz`, `.elc` and native `.eln` files.
   `.eln` names are flat, so they are skipped if a kept file shares the same
   base name.

## Results

Plan: **411 of 1,678 files** removed (14.3 MB of source).

| Directory | Removed |
|---|---|
| `org` | 127 of 129 (`org-element-ast` and `org-macs` stay: the new calendar parser hard-requires them) |
| `cedet` | 92 of 154 |
| `gnus` | 80 of 105 |
| `mh-e` | 25 of 25 |
| `erc` | 41 of 41 |
| `play` | 25 of 25 |
| `mail` | 14 |
| `net` | 7 |

Measured on the installed tree:

| | Before | After |
|---|---|---|
| Install size | 308 MB | 257 MB |
| Native `.eln` files | 1,627 | 1,227 |

## Verification performed

1. **Require every bundled package** on the original build and the pruned
   install, then compared:
   - Original: 512 of 513 load (`nxml` already fails; it has no `nxml.el`).
   - Pruned: 476 of 513 load. The 37 failures are `nxml` plus exactly the
     removed packages: the games, `erc`, `rcirc`, `mh-e`, `rmail`, `feedmail`,
     `mspools`, `supercite`, `undigest`, `unrmail`, `newsticker`, `org`.
   - **No coding or editing package regressed.**
2. **Smoke tests** on the pruned install all passed: the project's own
   `init.el`; Eglot, Flymake, xref, project, eldoc, jsonrpc; tree-sitter and
   the C/Python/JS/TypeScript/Go/Rust/JSON/CSS modes; vc-git, diff-mode, ediff,
   smerge, log-view; TRAMP; Transient; dired, compile, grep, ibuffer; recentf,
   savehist; use-package, which-key; package.el; eshell, eww, calc; opening a
   Python buffer with fontification; SQLite and JSON; and **native compilation
   of a new function at runtime** (correct result, `native-comp-function-p` true).
3. **GUI launch** of the pruned install with `config/`: window started, no
   errors in the log.

## Known limitations

- **Stale autoloads.** Emacs still lists removed commands. `(fboundp
  'org-mode)` is `t` but `(require 'org)` fails with *Cannot open load file*.
  Running `M-x org-mode` gives that error rather than "no such command".
- **`gnus` is only partly removed** (25 files stay, `gnus` still loads). The
  chain is real: `eww` and `url` need `mm-url`, which needs part of `gnus`, and
  `mail/emacsbug` needs `message`. Removing more would also mean removing `eww`
  and the bug reporter.
- **`cedet` is only partly removed** (62 files stay). Core files such as
  `edebug`, `ert` and `dired-aux` load parts of it.
- **Lazy dependencies** (25 kept files; only fail if that path runs). Notable:
  - `transient` → `org`: only the date-picker prompt.
  - `emacs-lisp/package-vc` → `org/ox`, `ox-texinfo`: only when building
    package documentation.
  - `textmodes/markdown-ts-mode` → `org-entities`: HTML entity lookup.
  - `net/mairix` → `rmail`.
  - `url/url` → `mm-view`, `gnus-*` internals: some mail/news URL schemes.
  - The `comp`/`disass` "dependencies on `wisent/comp`" reported by the tool are a
    **name collision** (`comp` is also the native compiler) and are harmless;
    native compilation was verified to work.
- **The scan is textual**, not a full Lisp analysis. It can miss a dependency
  built dynamically (e.g. `(require (intern ...))`). Always run the checks
  below after changing `prune.list`.
- **Not pruned:** `etc/` data files and Info manuals for the removed packages.
- Only Linux was tested. `prune.py` assumes the `share/emacs/<ver>/lisp` and
  `lib/emacs/<ver>/native-lisp` layout of `make install` on Linux.

## Changing the list safely

1. Edit `prune.list`.
2. `python3 prune.py --plan`, and read the "rescued" and "lazy" sections.
3. `./build.sh install` (fresh copy, so previously pruned files come back),
   then `./build.sh prune`.
4. Re-run the verification: require every bundled package on the original
   `build/src/emacs` and on `install/bin/emacs`, and diff the failures. Any
   package that fails only on the pruned build and is not on your removal
   list is a regression.
5. Run your real workflows.

A snippet for step 4 (run with each binary and diff the `FAIL` lines):

```elisp
(require 'package)
(dolist (b (mapcar #'car (package--builtin-alist)))
  (condition-case e (require b)
    (error (princ (format "FAIL %s: %s\n" b (error-message-string e))))))
```

```sh
emacs -Q --batch -l requireall.el
```
