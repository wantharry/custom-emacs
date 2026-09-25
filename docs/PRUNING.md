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
| `prune.py` | `--plan` shows what would go and why; `--list` prints the final list; `--apply DIR` deletes it from an installed tree |
| `tools/verify-prune.sh` | The full check of a pruned install against the unpruned build (see [Verification](#verification-performed)) |
| `tools/workflows.el`, `tools/requireall.el` | What the check runs |

A line in `prune.list` starting with `!` is an **exception**: that path is never
removed, and anything it hard-requires is kept too. Exceptions are for files that
are loaded lazily at run time, which the dependency scan cannot see.

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

Plan: **410 of 1,678 files** removed (14.3 MB of source).

| Directory | Removed |
|---|---|
| `org` | 127 of 129 (`org-element-ast` and `org-macs` stay: the new calendar parser hard-requires them) |
| `cedet` | 92 of 154 |
| `gnus` | 79 of 105 (`mm-archive` is an exception, see below) |
| `mh-e` | 25 of 25 |
| `erc` | 41 of 41 |
| `play` | 25 of 25 |
| `mail` | 14 |
| `net` | 7 |

Measured on the installed tree:

| | Before | After |
|---|---|---|
| Install size | 308 MB | 258 MB |
| Native `.eln` files | 1,627 | 1,228 |

## Verification performed

Run everything with one command (needs network for the package and URL tests):

```sh
./tools/verify-prune.sh
```

It does four things, and exits non-zero if anything is wrong:

1. **Runs 17 realistic workflows** on the unpruned build: package refresh,
   install (unsigned and signed), HTTPS fetch, HTML rendering, VC, diff/ediff,
   dired/grep/find, help, customize, calendar, TRAMP, compile/edebug/ERT, mail
   composition, Eglot/project/xref/Flymake, tree-sitter Python/JS/C, and a broad
   UI/mode sweep.
2. **Traces every Lisp file those workflows load** and reports any that are on
   the removal list. Any hit is a file you must keep (add a `!` line).
3. **Runs the same 17 workflows on the pruned install.**
4. **`require`s all 513 bundled packages** on both builds and lists failures that
   appear only after pruning. Those must be exactly the packages you removed.

Latest result (2026-09-25): all 17 workflows pass on both builds; no loaded
file is on the removal list; the unpruned build loads 512 of 513 packages (`nxml`
already fails) and the pruned one 476 of 513, the 36 differences being exactly
the removed packages (games, `erc`, `rcirc`, `mh-e`, `rmail`, `feedmail`,
`mspools`, `supercite`, `undigest`, `unrmail`, `newsticker`, `org`).

Also done by hand on the pruned install: the terminal UI in `emacs -nw` (menu,
line numbers, electric pairing, ibuffer, window keys, clean exit), a GUI launch
with `config/`, and native compilation of a new function at run time.

### What went wrong the first time

The first version was checked only by `require`-ing every package, and it
looked clean. It was **not**: package downloads were broken. `url` loads
`gnus/mm-archive` lazily when Emacs fetches anything, and that file had been
pruned, so `package-refresh-contents` failed with *Cannot open load file ...
mm-archive*. It was found only when installing a package failed.

The lesson is that **loading a package is not the same as using it.** A static
scan cannot see requires made at run time, so the check now traces real
workflows and the fix is a `!gnus/mm-archive.el` exception in `prune.list`.
A workflow you rely on that is not in `tools/workflows.el` is not covered.
Add it there.

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
  - `mm-decode` → `mm-archive` is the one that *did* break package downloads; it is
    now an exception.
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
3. `./build.sh install` (a fresh copy, so previously pruned files come back),
   then `./build.sh prune`.
4. `./tools/verify-prune.sh`. If step 2 of it reports a file, add a `!` line for
   it and repeat from step 3.
5. Use it for the things you actually do, and add any workflow the script does
   not cover to `tools/workflows.el`.
