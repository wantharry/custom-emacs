# Pruning unused built-in packages

Emacs bundles far more than any one person uses. This project removes the parts
you do not want from the **installed copy** (`install/`), never from
`emacs-src/`, so the upstream checkout stays clean and `git pull` keeps working.

Verified on the Linux build, 2026-09-29 (last re-measured when `org` was removed from
the prune list --- see "What is currently pruned" below). Windows and macOS: untested;
Windows in particular never runs this at all --- it uses the official prebuilt GNU
Emacs zip as-is, so nothing described here applies there, and `org` (along with
everything else this file prunes on Linux) has always been present on Windows.

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
| Mail and news readers | `gnus/`, `mh-e/`, `mail/rmail*`, `undigest`, `unrmail`, `feedmail`, `mspools`, `supercite` |
| Chat | `erc/`, `net/rcirc.el` |
| Legacy IDE tooling | `cedet/` (CEDET, EDE, Semantic, SRecode) |

**Kept on purpose** (not in the list): `eshell`, `eww`, `calc`, `calendar`,
`nxml`, `newsticker` (`C-c n`, see [README.md](../README.md)), `org` (kept as of
2026-09-29 --- the user explicitly asked for it back, having been pruned before that;
see the note under "Results" below), and every coding-related package (Eglot, Flymake,
tree-sitter modes, VC, TRAMP, Transient, ...). Add any of them to `prune.list` to
remove them too.

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

Plan: **264 of 1,678 files** removed (6.6 MB of source). Re-measured 2026-09-29 after
`org/` was removed from `prune.list` --- previously 410 of 1,678 (14.3 MB), back when
`org` itself was still pruned; see the note under "What is currently pruned" above for
why that changed.

| Directory | Removed |
|---|---|
| `cedet` | 87 of 154 |
| `gnus` | 71 of 105 (`mm-archive` is an exception, see below; fewer removed than before
  `org` was kept, since `org`'s own Gnus link support, `org/ol-gnus`, hard-requires a
  few more Gnus files than were otherwise needed) |
| `mh-e` | 25 of 25 |
| `erc` | 41 of 41 |
| `play` | 25 of 25 |
| `mail` | 14 of 41 |
| `net` | 1 of 83 (just `rcirc.el`) |

`org` (129 files) is no longer in this table at all --- it is kept in full, not pruned;
`org-element-ast` and `org-macs` are ordinary kept files now, not exceptions to
anything, though they were the two files rescued as exceptions back when the rest of
`org` was still being removed (the built-in calendar's newer parser hard-requires them
regardless of whether the rest of `org` is present).

Measured on the installed tree:

| | Before | After |
|---|---|---|
| Install size | 308 MB | 281 MB |
| Native `.eln` files | 1,627 | 1,371 |

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

Latest full run (2026-09-25, before `org` was restored): all 17 workflows pass on both
builds; no loaded file is on the removal list; the unpruned build loads 512 of 513
packages (`nxml` already fails) and the pruned one 476 of 513, the 36 differences being
exactly the removed packages (games, `erc`, `rcirc`, `mh-e`, `rmail`, `feedmail`,
`mspools`, `supercite`, `undigest`, `unrmail`, `newsticker`, `org`).

Re-checked 2026-09-29 after removing `org` from `prune.list`: just step 4 (the
require-sweep, `tools/requireall.el`), directly, not the full network-dependent
`verify-prune.sh` --- unpruned still 512 of 513 (`nxml`); pruned now 478 of 513, 35
differences, `org` no longer among them and otherwise the identical set minus
`newsticker` (kept since before this change too, see "What is currently pruned"
above).

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

- **Stale autoloads.** Emacs still lists removed commands. `(fboundp 'tetris)` is
  `t` but `(require 'tetris)` fails with *Cannot open load file*. Running
  `M-x tetris` gives that error rather than "no such command". (`org-mode` used
  to be the example here, back when `org` was pruned --- it is no longer, as of
  2026-09-29, so `M-x org-mode` now works normally.)
- **`gnus` is only partly removed** (34 files stay --- more than before `org`
  was kept, since `org`'s own Gnus link support, `org/ol-gnus`, hard-requires a
  few more Gnus internals). The chain is real: `eww` and `url` need `mm-url`,
  which needs part of `gnus`; `mail/emacsbug` needs `message`; `org/ol-gnus` and
  `org/ol-mhe`/`org/ol-rmail` (lazy) need still more. Removing more of `gnus`
  would also mean removing `eww`, the bug reporter, and parts of `org`'s own
  link-following.
- **`cedet` is only partly removed** (67 files stay). Core files such as
  `edebug`, `ert` and `dired-aux` load parts of it.
- **Lazy dependencies** (23 kept files; only fail if that path runs). Notable:
  - `net/mairix` → `rmail`.
  - `url/url` → `mm-view`, `gnus-*` internals: some mail/news URL schemes.
  - `mm-decode` → `mm-archive` is the one that *did* break package downloads; it is
    now an exception.
  - `org/ol-irc` → `erc`; `org/ol-mhe` → `mh-e`; `org/ol-rmail` → `rmail`: org's own
    optional link-following into still-pruned packages, only if you actually follow
    one of those link types.
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
