# Crash-safe auto-save and session restore (`C-c w`)

Status as of 2026-09-29. Everything below marked *measured* or *confirmed* was run here,
for real: real GUI frames under WSLg, real `kill -9` crashes, real restores.

## What is set up

Two layers, both built into Emacs --- no package:

| Piece | What it does |
|---|---|
| `auto-save-visited-mode` | Any buffer you deliberately unlock (`C-c e e`) and edit is written back to its real file a few seconds after you stop typing --- no manual `C-x C-s` needed, and nothing to separately "recover" after a crash, since the real file already has it. |
| `desktop-save-mode` | Saves which files/buffers are open and the window layout (splits), automatically, and restores them the next time Emacs starts. |

Both are on by default, no setup needed. `config/emacs-session.el` has the full WHAT/WHY/HOW
commentary; this doc is the narrative version, with the real numbers.

## The three keys

| Key | Does |
|---|---|
| `C-c w s` | Save the session right now, by hand (a deliberate checkpoint) |
| `C-c w r` | Discard the saved session: closes every buffer/window in this Emacs right now, and deletes the saved file, so the **next** start shows the plain start screen instead of restoring anything --- this is the "reset to default" |
| `C-c w l` | List every buffer currently part of the session (would be saved if it saved right now), each a link to switch to it |
| `C-c w S` | Save the current buffers/windows as a separate, **named** session --- as many as you like (see "Named sessions" below) |
| `C-c w O` | Replace what's open with a named session |
| `C-c w D` | Delete a named session for good |
| `C-c w L` | List every named session saved |

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

## Named sessions: how many can be saved?

As many as you like --- there is no limit coded here, only disk space. `C-c w s`/`C-c w r`
above operate on the one, always-auto-saving **live** session (your crash protection).
`C-c w S` is different: it saves a separate, **named** snapshot --- your current buffers
and window layout, under whatever name you give it, alongside any other named sessions
you've saved --- without touching or interrupting the live one. `C-c w O` replaces what's
currently open with a named snapshot (loading it *into* your live workspace: from then on
the regular autosave keeps protecting it, same as anything else you opened by hand); `C-c
w L` lists every named session you've saved, each a link to open it (or `d` to delete);
`C-c w D` deletes one for good.

Each named session is its own small folder under `config/session-named/NAME/` (never
committed to git, never bundled, same as the live session). Opening the same name twice
in a row both times genuinely reopens it (a real bug, fixed, made this NOT true at first
--- see below).

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

## A real bug found only after a much later, unrelated change (Org mode restored)

**This file used to be named `session.el`, providing the feature `session`** --- until
2026-09-29, when restoring Org mode to the Linux build (see [PRUNING.md](PRUNING.md))
turned that into a real, live collision: a well-known third-party ELPA package is also
called `session` (`session-globals-exclude` is one of its own variables), and Org's own
`org-compat.el` registers `(eval-after-load 'session ...)` expecting exactly that
package. Since this file also `(provide 'session)`d, simply running `M-x org-mode` in a
completely normal, fully-loaded session started erroring with "Symbol's value as
variable is void: session-globals-exclude" --- confirmed directly, not assumed: a bare
`(require 'org)` outside this config never hit it (nothing had registered the `session`
feature name yet); only going through the real, already-loaded config did. Renamed the
file and the feature to `emacs-session` (matching this project's own "feature name =
filename" convention throughout, not a special case) rather than working around or
disabling Org's own hook, which is entirely legitimate for anyone who actually has the
real `session` package installed. `tests/ert/emacs-session.el`'s own
`emacs-session/does-not-collide-with-orgs-own-session-package-hook` runs `M-x org-mode`
through the real, fully-loaded config (not `(require 'org)` in isolation) specifically
so this can't silently come back.

## Two real bugs found while testing this for real (not just reading the source)

- **`desktop-save`'s second argument is `RELEASE`, not "force save."** Passing it a non-
  nil value (an easy, natural-looking mistake, made once here) means "let go of the
  desktop lock," the *opposite* of what a "claim ownership" or "save now" call wants. With
  that bug, the periodic 10-second autosave silently never wrote a single file, no matter
  how long a session ran, because it only ever updates a desktop this Emacs process
  already *owns* (`(eq (emacs-pid) (desktop-owner))`), and ownership never got claimed.
  Caught only by an actual crash-and-restore cycle; `tests/ert/emacs-session.el`'s
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

Two more, found while adding named sessions (`C-c w S`/`O`), both the same lesson --- these
two functions have real side effects beyond "save/load a file" that the docstring alone
doesn't make obvious:

- **`desktop-save` unconditionally sets `desktop-dirname` (and mutates `desktop-io-file-
  version`/`desktop-file-checksum`/`desktop-saved-frameset`) as its very first action.**
  A naive "just call `desktop-save` on a different directory" implementation of `C-c w S`
  would have silently repointed the *live* session's own bookkeeping at the named
  snapshot's directory --- breaking crash protection until some unrelated later save
  happened to fix it back. Every one of those variables is let-bound around every named-
  session save/open now, confirmed for real (`equal desktop-dirname live-dir` still holds
  after `my/session-save-as`) that none of it leaks out.
- **`desktop-read` claims the lock of whatever directory it reads and never releases it.**
  Left alone, opening the same named session a *second* time later would have silently
  done nothing (`desktop-read` declines outright once `(desktop-owner)` already equals
  `(emacs-pid)`, printing "Not reloading the desktop") --- confirmed for real, reproduced
  with a plain two-line repro before fixing it. `my/session-open` now releases the named
  directory's lock right after reading it, so every open is a real, fresh open.
- A smaller related one: re-saving under the **same** name a second time initially hit
  `desktop-save`'s own "Desktop file isn't the one loaded. Overwrite it?" prompt, since
  `desktop-file-modtime` was left at the *live* session's unrelated value rather than the
  named directory's own. In a script with no terminal attached this doesn't wait forever,
  it fails outright ("Error reading from stdin") --- either way, not what a plain re-save
  should do. Fixed by setting `desktop-file-modtime` to the named file's own real, current
  modtime (or nil, the first time) right before saving.

## Limits

- `desktop-read` (the actual restore function) is **unconditionally a no-op under
  `noninteractive`** (Emacs's own documented behavior) --- meaning it never does anything
  in `--batch` mode. This doesn't affect real use (interactive Emacs is never
  `noninteractive`), but it does mean the automated test for a real restore round trip
  (`tests/ert/emacs-session.el`) has to briefly let-bind `noninteractive` to `nil` around the
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

`tests/ert/emacs-session.el` (25 tests): keys bound; loaded eagerly (not autoloaded, and why);
does not slow startup; every deliberate configuration choice (where the desktop lives,
`desktop-save`/`desktop-load-locked-desktop`/`desktop-auto-save-timeout`/`desktop-
restore-eager`); a real regression test pinning down the `RELEASE`-argument bug for good;
`C-c w r`'s clear-then-remove-then-keep-dirname-usable sequence; a real, headless save →
kill buffers → restore round trip confirming both the buffer list and the read-only lock
come back correctly; and `C-c w l`'s listing (uses desktop.el's own real filter, shows
every tracked file, marks modified ones, real close/refresh keys).

Named sessions: name sanitizing (empty, a slash, `.`/`..`); saving as a name never
disturbs the live session's own `desktop-dirname`/`desktop-path` and really writes into
its own separate directory; opening restores the snapshot's buffers while keeping the
live directory anchored; opening the *same* name twice both times genuinely restores it
(the lock-release regression test); saving under the *same* name twice never prompts or
errors (the modtime regression test); a clear `user-error` for an unknown name, or for
open/delete with nothing saved yet; delete only removes the directory after `yes-or-no-p`
confirms (mocked both ways); the named-sessions list shows every saved name (and a "none
yet" message with none), with a real close key.
