# My notes

A running, personal log of things learned while actually using this config day to day ---
gotchas, "why does it do that", real facts dug out of the source when something didn't
behave the way it looked like it should. Different from [KEYBOARD.md](KEYBOARD.md) and
the other guides: those are the polished, general reference; this one is just "things I
asked about and the real answer", added to as they come up, in the order discovered.

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
