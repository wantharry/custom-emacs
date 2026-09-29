# Crash-safe auto-save and session restore (`C-c w`)

Status as of 2026-09-29. Everything below marked *measured* or *confirmed* was run here,
for real: real GUI frames under WSLg, real `kill -9` crashes, real restores.

## What is set up

Two layers, both built into Emacs --- no package:

| Piece | What it does |
|---|---|
| `auto-save-visited-mode` | Any buffer you deliberately unlock (`C-c e e`) and edit is written back to its real file a few seconds after you stop typing --- no manual `C-x C-s` needed, and nothing to separately "recover" after a crash, since the real file already has it. |
| `desktop-save-mode` | Saves which files/buffers are open and the window layout (splits), automatically, and restores them the next time Emacs starts. |

Both are on by default, no setup needed. `config/session.el` has the full WHAT/WHY/HOW
commentary; this doc is the narrative version, with the real numbers.

## The three keys

| Key | Does |
|---|---|
| `C-c w s` | Save the session right now, by hand (a deliberate checkpoint) |
| `C-c w r` | Discard the saved session: closes every buffer/window in this Emacs right now, and deletes the saved file, so the **next** start shows the plain start screen instead of restoring anything --- this is the "reset to default" |
| `C-c w l` | List every buffer currently part of the session (would be saved if it saved right now), each a link to switch to it |

## How it works

- Auto-saving the real file: `auto-save-visited-mode`, left at Emacs's own default
  interval (a few seconds of idle time after an edit). Only buffers that are both file-
  visiting and actually modified are touched --- a buffer you never unlocked (see
  [KEYBOARD.md](KEYBOARD.md)'s "every file opens read-only") has nothing to save, so
  nothing happens for it, silently.
- Saving the session: `desktop-save-mode`, saved to `config/session/` (never committed to
  git, never bundled --- see `.gitignore` and `tests/test_dist.py`). It saves
  automatically both periodically while Emacs runs (whenever the window configuration has
  changed and then stayed idle for `desktop-auto-save-timeout` seconds --- overridden here
  to **10 seconds**, shorter than this config's usual 30-second idle-save convention;
  see "Measured" below for why) and on a clean exit (`desktop-save` is `t`: never asks).
- Restoring: automatic, at startup, via desktop.el's own `after-init-hook` entry --- this
  runs *after* the start screen's own startup logic (`initial-buffer-choice`), so a real
  saved session replaces the start screen; with nothing saved yet (a fresh install, or
  right after `C-c w r`), nothing happens and the start screen shows exactly as it always
  does. A stale lock file left behind by a crash (rather than a clean exit) is handled
  automatically too: `desktop-load-locked-desktop` is `check-pid`, which loads anyway
  only if the process that owned the lock is confirmed not running on this machine
  anymore, and otherwise falls back to asking --- never silently steals a session from an
  Emacs that is genuinely still running.
- The read-only lock (every file opens read-only until `C-c e e`, see KEYBOARD.md) is
  **not** something the session remembers as "stay unlocked" --- restoring a buffer goes
  through the exact same `find-file` machinery as opening it by hand, so it always comes
  back locked, even if it was unlocked and being edited right when Emacs was last used.
  This is deliberate: a session restore should never silently hand you back a file already
  primed to be edited by a stray keystroke.

## Measured

A real, live test, done by hand while building this: opened two files, split the window,
unlocked and edited one of them, then killed the process outright (`kill -9`, no clean
exit, no chance for any exit hook to run) and started a fresh Emacs pointed at the same
config.

| Check | Result |
|---|---|
| Edited file's real content survived the `kill -9` | Yes (`auto-save-visited-mode`) |
| Window split (2 windows) restored | Yes |
| Both files reopened | Yes |
| The file that was unlocked before the crash came back **locked** again | Yes |
| `C-c w r`, then a fresh start | Nothing restored; plain start screen, as on a first run |
| A clean exit right after `C-c w r` | No prompt (a real risk found and fixed --- see below) |

## Two real bugs found while testing this for real (not just reading the source)

- **`desktop-save`'s second argument is `RELEASE`, not "force save."** Passing it a non-
  nil value (an easy, natural-looking mistake, made once here) means "let go of the
  desktop lock," the *opposite* of what a "claim ownership" or "save now" call wants. With
  that bug, the periodic 10-second autosave silently never wrote a single file, no matter
  how long a session ran, because it only ever updates a desktop this Emacs process
  already *owns* (`(eq (emacs-pid) (desktop-owner))`), and ownership never got claimed.
  Caught only by an actual crash-and-restore cycle; `tests/ert/session.el`'s
  `session/save-and-claim-ownership-never-release-the-lock` pins this down for good.
- **The stock `desktop-auto-save-timeout` default (30 seconds, `auto-save-timeout`) is too
  long for real crash protection.** A session crashed 6-13 idle seconds in had no desktop
  file at all yet. Shortened to 10 seconds here --- still longer than `auto-save-visited`'s
  own (much cheaper) file-content save, but short enough that losing the *window
  layout specifically* in a crash is a real edge case, not the common one.

Also, ownership only ever gets claimed by an actual `desktop-save` call --- on a brand
new session (nothing to restore, so `desktop-read` at startup never got that far either),
nothing would ever claim it on its own. Fixed with one explicit `desktop-save` right after
startup finishes (`my/session--claim-ownership`, on `after-init-hook` at a late depth, so
it runs after any real restore has already happened).

## Limits

- `desktop-read` (the actual restore function) is **unconditionally a no-op under
  `noninteractive`** (Emacs's own documented behavior) --- meaning it never does anything
  in `--batch` mode. This doesn't affect real use (interactive Emacs is never
  `noninteractive`), but it does mean the automated test for a real restore round trip
  (`tests/ert/session.el`) has to briefly let-bind `noninteractive` to `nil` around the
  call to test it at all.
- Restoring frame *geometry* (exact size/position on screen) across very different
  displays/window managers is inherently less reliable than restoring buffers and window
  splits --- desktop.el has its own safety nets for this (`desktop-restore-in-current-
  display`, `desktop-restore-forces-onscreen`), left at their defaults here; not stress-
  tested across multiple monitors or window managers.
- A very large session (many buffers) restores the first `my/session-restore-eager` (10)
  buffers synchronously at startup and the rest lazily in the background, to keep startup
  fast --- not exhaustively measured with a huge session.

## Tests

`tests/ert/session.el` (14 tests): keys bound; loaded eagerly (not autoloaded, and why);
does not slow startup; every deliberate configuration choice (where the desktop lives,
`desktop-save`/`desktop-load-locked-desktop`/`desktop-auto-save-timeout`/`desktop-
restore-eager`); a real regression test pinning down the `RELEASE`-argument bug for good;
`C-c w r`'s clear-then-remove-then-keep-dirname-usable sequence; a real, headless save →
kill buffers → restore round trip confirming both the buffer list and the read-only lock
come back correctly; and `C-c w l`'s listing (uses desktop.el's own real filter, shows
every tracked file, marks modified ones, real close/refresh keys).
