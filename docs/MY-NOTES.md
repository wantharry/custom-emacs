# My notes

A running, personal log of things learned while actually using this config day to day ---
gotchas, "why does it do that", real facts dug out of the source when something didn't
behave the way it looked like it should. Different from [KEYBOARD.md](KEYBOARD.md) and
the other guides: those are the polished, general reference; this one is just "things I
asked about and the real answer", added to as they come up, in the order discovered.

## Opening Emacs

| Command | What it opens |
|---|---|
| `install/bin/emacs --init-directory=$PWD/config` | this repo, Linux/WSL, the normal pruned install |
| `build/src/emacs --init-directory=$PWD/config` | this repo, straight from the build tree, unpruned |
| double-click `Emacs.exe` inside the unzipped folder | the portable Windows bundle |
| `./Emacs` inside the unzipped folder | the portable Linux bundle |

`--init-directory=` is what makes it *this* config; without it, Emacs falls back to its own stock default.

## Exiting Emacs

| Command | What it does |
|---|---|
| `C-x C-c` | quit Emacs entirely (asks to save any unsaved files first) |
| `q` (in Magit/Treemacs/Dired/ibuffer/start screen/docs/shortcuts buffers) | closes just that buffer/window --- does **not** quit Emacs |
| `C-x 5 0` | close just the current frame (OS window) --- doesn't quit Emacs if other frames are open |

## Opening/closing the browsing buffers

| Open | Close | What |
|---|---|---|
| `C-x d` (asks for a directory) / `C-x C-j` (current file's own directory) | `q` | Dired |
| `C-c t` (toggle) / `C-c T` (reveal the current file in it) | `q` (hide) / `Q` (fully reset) | Treemacs |
| `C-c h` | `q` | Start screen --- recent files/folders/projects |
| `C-c f p` | `q` | Git repos list --- every git repo on this computer |
| `C-x g` (also `C-c g` for file-specific commands) | `q` (`C-u q` kills the buffer instead of just hiding it) | Magit status |
| `C-c a a` | no dedicated key: `C-x k` / `kill-buffer` | LLM chat (gptel) |
| `C-c a c` | `q` | LLM council --- 3 local models at once, summarized |
| `C-c n` | `q` | News (newsticker) |
| `C-c d` (`C-c D` rebuilds it) | `q` | Docs buffer --- every guide, one buffer |
| `C-c k` | `q` | Shortcuts buffer --- this config's own keybindings |
| `C-c w l` | `q` | Session list --- buffers in the current session |
| `C-c w L` | `q` | Named sessions list |
| `C-c y` | `q` | Year calendar |
| `C-c m` starts recording | `C-c m` again --- stops, transcribes, inserts the result | Dictation |
| `C-c M` starts recording | `C-c M` again --- stops (text already appeared as you spoke) | Live dictation |
| `C-c v` turns it on | `C-c v` again turns it off | Evil, vi keys |

## Ways to open a file, by scope

| Scope | Command | What it does | Method |
|---|---|---|---|
| Folder | `C-x C-f` | open a file, completion starts from the current buffer's own directory | built-in completion (`basic`/`partial-completion`/`flex`) --- a directory listing, not a search engine |
| Folder | `C-x d` then `RET` / `C-x C-j` | browse the directory in Dired, then open | directory listing (browse, no query typed) |
| Folder | `C-c t` then `RET` | browse the Treemacs tree (whatever root was added), then open | tree listing (browse, no query typed) |
| Folder | `C-c f d` | fuzzy search, current directory's subtree only, recursive | live only, no index --- ripgrep, else grep, else plain Elisp |
| Project | `C-c f f` | fuzzy search, current buffer's project (falls back to whole disk if not in one) | cached per-project index, live fallback if the index has nothing --- same matcher tiers as `C-c f d` |
| Project | `C-x p f` | Emacs's own built-in project file finder, same project-following behavior as `C-c f f` | built-in completion over `project-files`, same `basic`/`partial-completion`/`flex` styles as `C-x C-f` --- not fuzzy the way the fast finder is |
| Project | `C-x p d` | open the project's root directory in Dired | directory listing (browse) |
| Project | `C-c s f` | `consult-fd`: literal/regexp name match across the project, no live preview | external `fd` (falls back to `find`), async as-you-type, literal/regexp --- not fuzzy |
| Disk | `C-c f g` | fuzzy search, the whole disk | cached whole-disk index, live fallback --- same matcher tiers as `C-c f f`/`C-c f d` |
| Disk | `C-c f a` | same as `C-c f g`, but asynchronous (Consult/fd), never blocks Emacs | external `fd`, async as-you-type, literal/regexp --- different engine than the rest of this family |
| History | `C-c h` then `RET`/number | reopen a recent file, folder or project from the start screen | stored history list (`recentf`/this config's own tracker) --- no query typed, just click/select |

`gmtry` finds `Geometry.java` through the fuzzy-matcher commands (`C-c f f`/`f g`/`f d`) but
not through `C-x p f`/`C-c s f` --- the real, practical difference between "fuzzy" and
"literal/regexp/completion-style" above.

## Searching text, by scope

| Scope | Command | Match type | Live preview |
|---|---|---|---|
| This buffer | `C-s` / `C-r` | simple (`M-r` inside isearch toggles regexp) | yes |
| This buffer | `C-M-s` / `C-M-r` | regexp | yes |
| This buffer | `C-c s l` (`consult-line`) | completion-style word match | yes |
| This buffer | `M-s o` (`occur`) | regexp | no --- lists matches in a separate buffer |
| This buffer | `M-%` / `C-M-%` (`query-replace`/`-regexp`) | simple / regexp | no --- steps through matches asking `y`/`n`, not a jump-to-preview |
| Directory (ask) | `C-u C-c s g` | ripgrep literal/regexp, prompts you to pick the directory | yes |
| Directory (ask) | `C-u C-x p g` | regexp, prompts you to pick the directory | no --- static results buffer (`M-g n`/`p` to step) |
| Project | `C-c s g` (`consult-ripgrep`) | ripgrep literal/regexp, grouped by file | yes |
| Project | `C-x p g` (`project-find-regexp`) | regexp | no --- static results buffer (`M-g n`/`p` to step) |
| Multiple open buffers | `M-x consult-line-multi` (no key bound) | completion-style word match | yes |
| Multiple open buffers | `M-x multi-occur`/`multi-occur-in-matching-buffers` (no key bound) | regexp | no --- separate results buffer |

"This buffer" and "a single file" are the same thing here --- a buffer visiting a file
*is* that file, so there's no separate "search one file" scope beyond the buffer rows
above. Directory scoping for text search isn't its own dedicated key (unlike `C-c f d` for
file-name search) --- it piggybacks on the project-search commands' own prefix-argument
handling (`C-u`), confirmed directly in both `consult.el` and `project.el`'s source.

## Fast finder (`C-c f f` / `C-c f g` / `C-c f d`)

- **`C-c f f` always follows whichever project the *current buffer* belongs to** --- it is
  not fixed to one project. Switch to a file in a different project and `C-c f f` now
  searches that one instead. `C-x p f` (Emacs's own built-in finder) does the exact same
  thing, confirmed directly in `project.el`'s source (`project-find-file` calls
  `(project-current t)`, the identical mechanism `C-c f f` uses) --- the only difference is
  `C-x p f` will prompt you to register a project if the current buffer isn't in one yet;
  `C-c f f` just silently falls back to a whole-disk search instead.
- **`C-c f f`/`C-c f g` are indexed, not a live scan every time.** Each keeps a cached
  index file (per-project for `f f`, whole-disk for `f g`), rebuilt only when actually
  stale --- by age, and for the project index, also the instant git's own index is newer
  (so a commit/add/checkout invalidates it right away, not just after the time limit).
  Matching uses ripgrep when installed, else grep, else plain Elisp. If the index has
  nothing for what you typed, it automatically falls back to a live search of that same
  scope (so a brand-new, not-yet-indexed file still shows up) --- the minibuffer marks
  those results "(not in the index: live search)" so you can tell which path was used.
- **`C-c f d`** (added this session): same fuzzy search, but scoped to just the current
  directory's own subtree, recursively --- ignores both the enclosing project and the
  whole disk. Deliberately has no index of its own (a single directory is normally small
  enough that live search alone is already fast).

## Consult (`C-c s l` / `s g` / `s f` / `s b`)

- **`C-c s f` (`consult-fd`) has no live preview**, unlike the other three Consult keys
  here. This is Consult's own deliberate design, not a setting in this config --- checked
  directly in Consult's source: `consult--grep` (backing `consult-ripgrep`) and the
  location-search commands pass a `:state` argument that wires up preview-on-move;
  `consult--find` (backing `consult-fd`) passes none at all. The reasoning: a filename-only
  match has no location *inside* the file to jump to and preview, unlike a text/line match.

## Magit

- **"pathspec '...' did not match any file(s) known to git"** when checking out a branch
  means exactly what it says: git has no branch (or tag) by that name, not a Magit bug.
  Either the name's wrong/not fetched yet (`b b` to pick from a real completion list of
  what actually exists, or `f a` to fetch first), or you meant to **create** a new branch,
  which plain checkout can't do --- use `b c` (`magit-branch-and-checkout`) instead.
- **Transient switches are genuinely bound to keys that include a literal `-`.** In a
  Magit popup like the log transient (`l`), lines like "`-n` Limit number of commits" or
  "`-A` Limit to author" are not decoration --- confirmed directly in `magit-log.el`
  (`:shortarg "-n"`, `:key "-A"`, etc., which *is* the actual keybinding). You press `-`
  then the letter, as two real keystrokes. This is deliberate: it visually and mechanically
  separates **options/switches** (dash-prefixed, just set a flag, don't run anything by
  themselves) from **actions** (plain letters, no dash, e.g. `l` to actually run the log)
  in the same popup. Set whatever switches you want first, then press a plain-letter
  action key to run the command with those applied.

## Dist bundles / GitHub Actions

- A freshly unzipped bundle has **no recent-files/folders history at all**, by design ---
  `recentf.eld`/`recents.eld` (personal state) are deliberately never shipped inside a
  built zip (`tests/test_dist.py`'s `test_no_personal_state_is_shipped`). Re-unzipping a
  new build always starts that session's start screen (`C-c h`) from a clean slate.
- The GitHub Actions release workflow (`.github/workflows/release.yml`) only builds the
  **Linux** bundle --- `tools/dist-windows.sh` genuinely requires WSL (it runs a real
  Windows `Emacs.exe` through `cmd.exe` to compile packages for it), which a plain Linux
  CI runner can't do. Windows stays a manual local build via WSL, attached to the same
  release by hand if wanted. Triggers only on a pushed version tag (`v*`), confirmed
  working end to end in a real test run (~26 minutes, `workflow_dispatch`).
