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

## LLM chat (`C-c a a`) and LLM council (`C-c a c`)

- **Ollama is the default backend, set up automatically** the first time you use `C-c a
  a` --- it queries Ollama's own `/api/tags` HTTP endpoint directly (not the `ollama`
  CLI, which doesn't even need to be on `PATH`) for whatever models are actually pulled
  right now, so the model list always matches reality with nothing to hand-edit. Works
  identically from WSL/Linux Emacs and the Windows bundle: Ollama only needs to run once
  (in WSL/Linux), and WSL2 forwards `localhost` both ways so Windows reaches the same
  `http://localhost:11434` with no extra setup.
- **`C-c a m`** opens `gptel-menu` to switch model, backend, or system prompt.
  ChatGPT/Claude/Gemini are pre-registered as selectable backends (so they show up in
  that menu with nothing to configure for that part), but **none is active by default**
  --- registering a backend in `gptel` only adds it as a menu choice, it doesn't switch
  to it. To actually use one: put a real API key in `~/.authinfo.gpg` (never in
  `llm.el` itself, which is tracked by git), one line per service, then pick it from
  `C-c a m` → Backend.
- **`C-c a c`** (LLM council) asks **three small/fast local models in parallel**, then a
  **separate, bigger model** compares and summarizes all three answers --- one buffer,
  summary expanded at the top, each model's full raw answer folded shut below it (`TAB`
  to expand, same outline mechanism as `C-c d`/`C-c k`). The three "council" models are
  chosen automatically by size (closest to ~2--3GB on disk) so asking three at once
  doesn't noticeably slow the machine; the summarizer is chosen separately (closest to
  ~7B parameters) and **deliberately never the largest model pulled** --- a real, explicit
  choice, since the largest model visibly slows this machine down for a task that
  doesn't need it. Degrades gracefully with fewer models pulled: with only one model
  available at all, it fills both roles (the only council answer, and its own
  summarizer) instead of erroring.

## Dictation (`C-c m` / `C-c M`)

- **Fully local** --- no cloud, no API key, no network --- via a local `whisper.cpp`
  build; verified for real on both platforms (a synthesized test sentence came back
  100% correct on WSL/Linux and on real Windows).
- **Recording start/stop genuinely differs by platform**, both confirmed necessary the
  hard way, not just "for consistency": Linux/WSL uses `parecord` (PulseAudio), stopped
  with an explicit `SIGTERM` and waited out --- `delete-process` alone doesn't give it a
  chance to finalize the WAV header (the file exists but is missing its fmt/data
  chunks, confirmed directly). Windows uses `ffmpeg` with a dshow audio input, stopped
  by sending it `"q"` on stdin --- the only way it finalizes cleanly, since there's no
  `SIGTERM`-equivalent signal on Windows.
- Neither `whisper.cpp`/`ffmpeg` nor the actual model is bundled with this project (the
  model alone is hundreds of MB) --- see [DICTATE.md](DICTATE.md) for setup.

## Session (`C-c w ...`, crash-safe auto-save and restore)

- Named `emacs-session.el`, **not** the shorter, more obvious `session.el` --- a real
  collision found the hard way: a well-known third-party ELPA package is also called
  `session`, and Org's own compatibility code expects exactly that package to be
  loaded; a same-named file here satisfied Org's `eval-after-load` trigger and caused a
  real crash (`Symbol's value as variable is void: session-globals-exclude`) the moment
  Org loaded. Renaming the feature (and the file, matching this project's own
  "feature name = filename" convention) was the fix, not disabling Org's hook, which is
  legitimate for anyone with the real `session` package installed.
- Two layers, both built into Emacs, no package: `auto-save-visited-mode` writes a
  buffer you've unlocked (`C-c e e`) and edited back to its real file a few seconds
  after you stop typing --- no manual `C-x C-s` needed. A buffer you never unlocked has
  nothing to save, so nothing changes for it.

## Year calendar (`C-c y`)

- `M-x calendar` on its own **cannot** show 12 months in a sensible grid --- it always
  lays every month out in a single row, so asking for 12 at once produces one line ~300
  columns wide that wraps and scrambles. `my/calendar-year` instead calls
  `calendar-generate-month` (the same primitive real `M-x calendar` itself uses) once
  per row of 3 months, 4 rows total --- a real grid, not a wider single row.
- It's a **separate, plain, read-only buffer** (`*Year Calendar*`), not the real
  `*Calendar*` buffer `M-x calendar`/the diary use --- never touches
  `calendar-total-months`, so it can't collide with or affect the stock calendar.

## News (`C-c n`)

- **Built entirely into Emacs** (`net/newsticker.el`) --- nothing installed, nothing
  this config wrote beyond which feeds to fetch. Un-pruned from `prune.list` this
  session specifically to get this back (it used to be stripped out of this minimal
  build).
- **No external tool needed, not even on Windows** --- fetches over Emacs's own
  networking (`url-retrieve`), not by shelling out to `wget`/`curl`, so it works
  identically in the portable Windows bundle with nothing extra bundled for it.
- **10 real, currently-live feeds, one per category** (Top Stories, World, USA,
  Business, Technology, Politics, Science, Health, Entertainment, Sports) --- each URL
  was actually curl-verified live before being added, not assumed --- so `C-c n` groups
  headlines the way a real newspaper's sections do, rather than one single "top
  stories" firehose.
- **Nothing loads and no network request happens until you actually press `C-c n`** ---
  it's a normal autoloaded entry point, same lazy-load behavior as everything else in
  this config.

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
