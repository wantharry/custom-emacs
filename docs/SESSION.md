# Crash-safe auto-save and session restore (`C-c w`)

Status as of 2026-09-29. Everything below marked *measured* or *confirmed* was run here,
for real: real GUI frames under WSLg, real `kill -9` crashes, real restores.

> **Update.** A real bug, found only by a genuine command-line-file round trip (open a
> file, wait, quit, reopen), not by reading the source: the automatic restore used to
> come back empty every time a session was started with a file named on the command line
> (`emacs somefile`, how every launcher in this project starts it) --- the one-time "claim
> ownership" save ran on `after-init-hook`, which fires *before* Emacs opens any files
> named on the command line, so that first save always saw an empty buffer list; and
> desktop.el's own periodic autosave never got another chance after that, since it only
> re-arms on an actual window-configuration change (a split), not plain buffer switching
> in a single, never-split window. Fixed: see "How it works" below for the real mechanism
> now in place. Separately, a direct user request is also reflected here: the `*start*`
> buffer a fresh launch creates is always still present in the buffer list (`C-x C-b`,
> `C-c w l`) even when a real session restores on top of it, confirmed directly ---
> `desktop-read` only recreates the buffers it saved, it never kills ones that already
> exist and are not part of that list.

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
  git, never bundled --- see `.gitignore` and `tests/test_dist.py`). This config does
  **not** rely on desktop.el's own two built-in triggers for this (see the real bug noted
  at the top of this doc for why): instead, `my/session--start-autosave` runs once on
  `emacs-startup-hook` --- confirmed, not assumed, to run *after* Emacs has already opened
  any files named on the command line (`startup.el`'s own doc for that hook: "run after
  loading init files and handling the command line") --- which immediately claims
  ownership of the session with a real, non-empty buffer list, then arms this config's own
  repeating idle timer (re-using `desktop-auto-save-timeout`, overridden here to **10
  seconds**, shorter than this config's usual 30-second idle-save convention; see
  "Measured" below for why) that keeps re-saving from then on, regardless of whether the
  window layout ever changes. It also saves on a clean exit (`desktop-save` is `t`: never
  asks).
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

## A buffer with no file at all: still protected, no recovery prompt

A direct user request: "I typed something, closed it, and open Emacs it shows up a start
screen why is that" --- followed by "I need to save all the buffers automatically that
[are] without file ... I don't want a prompt to recover ... if I open it should be on the
screen if it was on the screen before closing or should be in the buffer, like Notepad++".

Before this, neither layer above protected a buffer with no file at all: `auto-save-
visited-mode` only acts on buffers that already have a real filename, and plain `desktop-
save-buffer' (the opt-in flag `my/start-mode`/`my/shortcuts-mode` already use) only
remembers a no-file buffer's *name* and window slot, never its text --- there is nothing
for a mode handler to put back. Confirmed as a real gap: type something into a brand-new
buffer, never save it, restart --- it comes back empty, if it comes back at all.

No separate file, directory, or timer needed for this --- `desktop-save-buffer` may be a
**function**, not just `t` (confirmed directly in `desktop.el`'s own source:
`(when (functionp desktop-save-buffer) (funcall desktop-save-buffer desktop-dirname))`),
and whatever it returns is stored as that buffer's own "misc" data, right inside the same
`.emacs.desktop` file already written every 10 seconds of idle time
(`my/session--claim-ownership`). `desktop-buffer-mode-handlers` gets that data back on
restore --- the same extension point `my/start-mode`/`my/shortcuts-mode` already use, just
returning real content this time instead of regenerating a fixed display. Point is
restored automatically by `desktop-create-buffer` itself afterward, independent of any
handler, so the handler only needs to recreate the text and the major mode.

A qualifying buffer is opted in automatically, every periodic tick (same ~10-second
cadence as the rest of the session): no real file (`auto-save-visited-mode` already has
that case), not already claimed by another feature, not a minibuffer, not internal
(space-prefixed), not **read-only**, and not `special-mode`-derived. The read-only check
matters more than it looks: this config's own `*docs*` buffer (`my/docs-mode`, derived
from `outline-mode`, not `special-mode`) is a real, generated, read-only listing with no
file --- it matched every other check and got swept in during testing, then failed to
restore (no mode handler registered for `my/docs-mode`). `buffer-read-only` is the
actually-principled signal this was missing: if you cannot type into it, it is not
something you typed, so it is not this feature's to preserve.

Only a short, fixed list of common "just typed something, never saved it" major modes is
registered (`fundamental-mode`, `text-mode`, `lisp-interaction-mode` --- covers `*scratch*`
--- and `org-mode`), not every mode that exists: `desktop-buffer-mode-handlers` dispatches
on a buffer's *exact* major mode, no inheritance, so a no-file buffer in some other,
unlisted mode is an edge case nobody asked about yet.

**A real regression this almost shipped with**: registering a handler by major mode alone
also intercepts a REAL file-backed buffer that happens to share one of these same modes
--- a plain `.txt` file opens in `text-mode` too. Caught only by running the *full*
existing test suite after adding this feature, not by testing it in isolation: four
pre-existing restore tests started failing ("failed to restore") the moment `text-
mode`/`fundamental-mode` were added to the handler list. Fixed by checking the handler's
own `FILE` argument first --- non-nil means a real file is involved, so it delegates
straight back to `desktop-restore-file-buffer`, the same function `desktop-create-buffer`
would have used with no handler registered at all.

Window placement, the "should be on screen if it was before" half of the request: best-
effort, via the same mechanism that already makes the `*start*`/`*shortcuts*` split
survive a restore (see above) --- works for anything in the short mode list above; a
no-file buffer in some other mode isn't covered yet.

## A few more buffers "just there" by default

A direct follow-up request: a Dired buffer for wherever Emacs was actually launched from
(`my/session--launch-directory`, captured as early as possible, at the top of
`config/emacs-session.el`), always present in the buffer list (`C-x b`/`C-c w l`) without
being asked for first --- same guarantee, same mechanism, as `*start*`/`*shortcuts*`
above. Confirmed deliberately *not* shown on screen: `dired-noselect` (not `dired`)
never selects or displays anything, so it cannot disturb whatever the start screen or a
restored session is already showing.

Treemacs was considered and deliberately dropped (a direct, later user request: "lets not
add treemacs"). `ranger` was never attempted: unlike Dired, it has no "just create the
buffer, don't show it" mode at all --- confirmed directly in its own source (see
`my/ranger-to-dired`'s own comment in `init.el`): invoking it unconditionally calls
`delete-other-windows` and takes over the frame with its 3-pane layout the moment it
runs. `C-c R` already opens it instantly wherever you are; there was nothing to pre-warm
without visibly disrupting the display, the opposite of what was asked for.

## `C-c N`: a brand-new, empty buffer, as many as you like

A direct follow-up request: "as we press new windows in notepad++ ... how can I create
similar to that". Plain `C-x b` (see [KEYBOARD.md](KEYBOARD.md)) already does this, but
needs a name typed first every time --- not the "as many as possible, as fast as
possible" one-key feel being asked for. `C-c N` calls `generate-new-buffer`, so repeated
presses give a genuinely different buffer every time (`untitled`, `untitled<2>`, ...,
never colliding with an existing one) --- not `C-c n`, already bound to
`newsticker-treeview` (checked first, not assumed free).

No extra wiring needed to make these crash-safe: a buffer from `C-c N` is just another
no-file buffer, so it immediately qualifies for the auto-save/restore feature above
(no file, not read-only, not `special-mode`-derived) the moment you start typing into
it --- the exact same protection `*scratch*` or any other plain buffer already gets.

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
- A no-file buffer's text/mode is only preserved for a short, fixed list of common modes
  (`fundamental-mode`, `text-mode`, `lisp-interaction-mode`, `org-mode`) --- see "A buffer
  with no file at all" above for why (`desktop-buffer-mode-handlers` has no mode-
  inheritance); a no-file buffer in some other mode still gets its name/window slot
  tracked, but not its text, until that mode is added to the list.

## Tests

`tests/ert/emacs-session.el` (44 tests): keys bound; loaded eagerly (not autoloaded, and why);
does not slow startup; every deliberate configuration choice (where the desktop lives,
`desktop-save`/`desktop-load-locked-desktop`/`desktop-auto-save-timeout`/`desktop-
restore-eager`); a real regression test pinning down the `RELEASE`-argument bug for good;
`C-c w r`'s clear-then-remove-then-keep-dirname-usable sequence; a real, headless save →
kill buffers → restore round trip confirming both the buffer list and the read-only lock
come back correctly; and `C-c w l`'s listing (uses desktop.el's own real filter, shows
every tracked file, marks modified ones, real close/refresh keys). Also: the no-file-
buffer feature above --- opt-in and every real exclusion case (file, read-only, special-
mode, already-claimed), the registered mode-handler list, a full real round trip (save,
kill, restore, in a simulated separate process) confirming text and major mode both come
back, and the regression test pinning down the file-backed-buffer-in-a-shared-mode bug
for good. Also: the default Dired buffer --- wired to `emacs-startup-hook`, uses
`my/session--launch-directory` without disturbing whatever is on screen, and does not
duplicate an already-open directory.

Named sessions: name sanitizing (empty, a slash, `.`/`..`); saving as a name never
disturbs the live session's own `desktop-dirname`/`desktop-path` and really writes into
its own separate directory; opening restores the snapshot's buffers while keeping the
live directory anchored; opening the *same* name twice both times genuinely restores it
(the lock-release regression test); saving under the *same* name twice never prompts or
errors (the modtime regression test); a clear `user-error` for an unknown name, or for
open/delete with nothing saved yet; delete only removes the directory after `yes-or-no-p`
confirms (mocked both ways); the named-sessions list shows every saved name (and a "none
yet" message with none), with a real close key.
