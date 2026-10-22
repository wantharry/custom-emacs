;;; emacs-session.el --- crash-safe, persistent editing sessions --- no package needed  -*- lexical-binding: t; -*-

;; Named `emacs-session', not the shorter `session', on purpose: a real, found-the-hard-
;; way collision --- a well-known third-party ELPA package is also called `session'
;; (`session-globals-exclude' is one of its own variables), and Org's own compatibility
;; code registers `(eval-after-load 'session ...)' expecting exactly that package. Once
;; Org was restored to this build (see docs/PRUNING.md), simply opening any Org buffer
;; after this file had already loaded (which it always has, by then) triggered Org's
;; hook against THIS file instead, erroring with "Symbol's value as variable is void:
;; session-globals-exclude" the moment `(require 'org)' ran --- confirmed directly, not
;; assumed: a plain `(require 'org)' outside this config never hit it; only loading it
;; through this config, where this file's own `(provide 'session)' had already
;; satisfied Org's `eval-after-load' trigger, did. Renaming the feature (and the file,
;; to match this project's own "feature name = filename" convention throughout) is the
;; fix, not disabling or working around Org's own hook, which is legitimate and correct
;; for anyone who actually has the real `session' package installed.

;; Two layers, both built into Emacs:
;;
;; 1. Auto-save the actual file, not just a shadow copy (`auto-save-visited-mode'): a
;;    buffer you deliberately unlocked (see init.el's read-only lock, C-c e e) and then
;;    edited is written back to its real file a few seconds after you stop typing, with
;;    no manual C-x C-s.  A buffer you never unlocked has nothing to save, so nothing
;;    changes for it.
;;
;; 2. Save and restore the whole session --- which files/buffers were open, and the
;;    window layout (splits) --- with `desktop-save-mode'.  Saved automatically while
;;    Emacs runs (every `auto-save-timeout' seconds of idle time) and on a clean exit, so
;;    a crash loses at most the last few seconds; restored automatically the next time
;;    Emacs starts.  `C-c w r' discards it instead, back to the usual start screen.
;;
;; See docs/SESSION.md.

;; WHAT: Emacs's built-in session-persistence library.  WHY: loaded eagerly (not
;; autoloaded like most of this config's own optional features) because `desktop-save-
;; mode' has to be turned on WHILE init.el is still loading --- its own `after-init-hook'
;; (installed unconditionally by this library, whether or not the mode is on) is what
;; actually restores a saved session, and that hook fires once, right after init.el
;; finishes; there would be nothing to defer loading until, since by the time any key
;; press could trigger a lazy autoload, that moment has already passed.  HOW: `require'
;; pulls in `desktop-save-mode', `desktop-clear', `desktop-remove' and every `desktop-*'
;; variable this file sets, all used below.
(require 'desktop)
;; WHAT: Emacs's built-in clickable-link library.  WHY: `C-c w l' (my/session-list,
;; further down) shows each tracked buffer as a real button.  HOW: provides `insert-
;; text-button', the same mechanism `my/find-git-repos'/`my/start' use for their own
;; listing buffers.
(require 'button)

;; WHAT: the directory Emacs was actually started from, captured as early as possible.
;; WHY: this config's Dired/Treemacs defaults further down (a direct user request: "a
;; few more buffers default like dired, ranger, treemacs, may be default to current
;; directory") need wherever Emacs was *launched* from, not wherever the user happens to
;; be editing by the time `emacs-startup-hook' runs --- captured here, at the very top of
;; this file, since this file loads eagerly, before anything else in `init.el' could
;; plausibly change `default-directory' out from under it.
(defvar my/session--launch-directory default-directory
  "The directory Emacs was started from.  See the comment just above.")

;; WHAT: turn on real-file auto-save globally.  WHY: this is the direct answer to "any
;; buffer opened should be automatically saved" --- unlike classic `auto-save-mode'
;; (already on by default; writes to a separate `#file#' shadow copy you would need to
;; notice and manually recover), this mode saves the buffer's own real, visited file, so
;; there is nothing separate to recover in the first place.  HOW: `auto-save-visited-
;; interval' (a few seconds of idle time) is left at its built-in default --- Emacs's own
;; default is already sensible here, so there is no reason to override it.  Only buffers
;; that are both file-visiting AND actually modified are ever touched, silently
;; (`save-some-buffers :no-prompt'), so a read-only-locked buffer (nothing to save) or an
;; unmodified one is simply skipped every time the idle timer fires.
(auto-save-visited-mode 1)

;; WHAT: where the saved session (window layout + buffer list) lives.  WHY: a dedicated
;; subdirectory, matching this config's existing pattern for other generated, per-machine
;; state (`backups/', `fastfind/') --- keeps `user-emacs-directory' itself tidy.  HOW:
;; created up front so `desktop-save-mode' never has to create it lazily mid-session.
(defvar my/session-dir (expand-file-name "session/" user-emacs-directory)
  "Where the saved desktop (open buffers, window layout) is kept.")
(make-directory my/session-dir t)

;; WHAT: point desktop.el at that directory.  WHY/HOW: `desktop-path' is the list of
;; places `desktop-read' searches; overwritten (not appended to) with just our one
;; directory, so a session is never accidentally read from `~' (`desktop-path's own
;; built-in default) if a stray desktop file happens to exist there for some other
;; reason. `desktop-dirname' is where a save actually goes; set to the same place so
;; there is exactly one location involved, not two that could disagree.
(setq desktop-path (list my/session-dir)
      desktop-dirname my/session-dir)

;; WHAT: never prompt when saving.  WHY: this whole feature is meant to be fully
;; automatic --- the built-in default (`ask-if-new') would interrupt the very first
;; save with a yes/no question, defeating that.  HOW: `t' means always save on exit
;; (and, combined with `desktop-save-mode', periodically while running too --- see
;; `desktop-auto-save-timeout' below), no question asked either way.
(setq desktop-save t)

;; WHAT: how to handle a lock file left behind by an unclean exit.  WHY: `desktop-save-
;; mode' writes a `.lock' file (naming the Emacs process using the session) while
;; running, to stop two Emacs instances from silently overwriting each other's saved
;; session; the built-in default (`ask') would interrupt an automatic crash-recovery
;; startup with a prompt.  HOW: `check-pid' is the one value that solves this correctly
;; without ever silently stealing a session out from under a Emacs that is genuinely
;; still running: it loads anyway only if the process ID recorded in the lock file is
;; not actually running on this machine right now (exactly the situation after a crash),
;; and otherwise falls back to asking, same as before.
(setq desktop-load-locked-desktop 'check-pid)

;; WHAT: how many buffers to restore immediately at startup versus lazily afterward.
;; WHY: this config measures and cares about startup speed (see startup-perf.el's own
;; tests); restoring every single saved buffer synchronously, before Emacs is even ready
;; to use, would undo that for anyone who tends to leave many files open. HOW: only the
;; first `my/session-restore-eager' buffers (in the order they were saved) load
;; synchronously; the rest load one at a time whenever Emacs is next idle for
;; `desktop-lazy-idle-delay' seconds (a built-in desktop.el variable, left at its
;; default), so a big session still finishes restoring on its own, just without blocking
;; startup to do it.
(defvar my/session-restore-eager 10
  "How many saved buffers `desktop-read' restores immediately at startup; the rest
restore lazily, in the background, the next time Emacs is idle.")
(setq desktop-restore-eager my/session-restore-eager)

;; WHAT: how many seconds of idle time before the desktop (window layout + buffer list)
;; is auto-saved.  WHY: this is a real, measured gap, not a guess --- confirmed by
;; actually crashing a real Emacs (`kill -9') 6 seconds after opening files and
;; splitting the window: the edited file's own content survived (`auto-save-visited-
;; mode', 5s idle default), but the desktop file did not exist yet at all, because
;; `desktop-auto-save-timeout' defaults to `auto-save-timeout' (30s of idle time) ---
;; too long a window for what "the state of Emacs should be preserved" is actually
;; asking for.  HOW: overridden to 10s here, deliberately shorter than the 30s idle-
;; timer convention this config otherwise uses for cheap, small state (`recentf-save-
;; list', `my/start-save' in startpage.el) --- losing the desktop means losing the
;; *entire* window layout and buffer list, not one list entry, so it is worth checking
;; more often even though writing it costs a little more.  Re-verified after this change
;; with the same real kill -9 test: the desktop file existed after the crash.
(setq desktop-auto-save-timeout 10)

;; WHAT: actually turn the whole thing on.  WHY/HOW: this alone is also what makes
;; Emacs's own startup sequence restore the saved session automatically --- desktop.el
;; installs its own `after-init-hook' (unconditionally, whether or not this mode is
;; enabled) that checks `desktop-save-mode' and, if non-nil, calls `desktop-read' once
;; this config has finished loading.  That happens to run AFTER `initial-buffer-choice'
;; (config/init.el's own `my/start-initial-buffer', which decides whether to show the
;; start screen) has already been applied --- so on a genuine restore, whatever the
;; start screen set up is promptly replaced by the restored windows; with nothing saved
;; yet (a fresh install, or right after `C-c w r'), `desktop-read' finds no file and
;; does nothing, leaving the start screen showing exactly as it already does today.
;; This ordering was confirmed for real, not assumed --- see docs/SESSION.md.
;;
;; A direct, explicit user request refines this further: a genuine restore should not
;; just replace the start screen outright --- the `*start*' buffer `my/start-initial-
;; buffer' already created moments earlier must still be reachable afterward (in the
;; buffer list, `C-x C-b'/`C-c w l', switchable back to), not silently gone. Confirmed
;; directly, not assumed: `desktop-read' only recreates the buffers IT saved; it never
;; kills buffers that already exist and are not part of that list, so the `*start*'
;; buffer `initial-buffer-choice' created a moment before genuinely does survive a real
;; restore untouched, just no longer the VISIBLE one (replaced by the restored window
;; configuration, same as the first paragraph above describes) --- verified with a real
;; round trip on the actual macOS bundle, not read from source alone: opened a file,
;; waited past the auto-save window, quit, reopened; the previously open file came back
;; exactly as left, and `*start*' was still present and switchable to from the buffer
;; list, not killed.
(desktop-save-mode 1)

;; WHAT: save the desktop once, right after startup finishes.  WHY: a real, measured gap
;; found while testing the periodic autosave above: `desktop-auto-save' (the timer
;; callback) only ever updates a desktop this Emacs process already OWNS --- it checks
;; `(eq (emacs-pid) (desktop-owner))', and `desktop-owner' reads a `.lock' file that only
;; gets created by an actual, successful `(desktop-claim-lock)', which a plain
;; `desktop-save' only does as a side effect (see the next paragraph for a real bug that
;; briefly defeated exactly this).  On a brand new session (nothing to restore yet, so
;; `desktop-read' above never got as far as claiming a lock either) that lock never gets
;; written, so the periodic autosave silently declines forever, no matter how long you
;; wait --- confirmed for real: a session left running well past the 10s timeout still
;; had no desktop file at all, until this fix.  HOW: one explicit `desktop-save' claims
;; ownership immediately; every later periodic autosave then works as intended.  Added to
;; `after-init-hook' at a late depth (90, this config's own convention for "run after
;; everything else", e.g. `my/make-file-buffer-read-only' in this same file)
;; specifically so it runs AFTER desktop.el's own `after-init-hook' entry (added when
;; `desktop.el' was `require'd above, at the default depth) has already had its chance to
;; restore a previous session first --- otherwise this could save an empty desktop before
;; the real one was ever read back in, overwriting it with nothing.
;;
;; A real bug, caught only by actually testing a full crash cycle (not just reading the
;; source): `desktop-save's second argument is RELEASE, not "force save" --- passing it a
;; non-nil value, as this function first did, means "I'm done with this desktop, let go
;; of the lock", the exact opposite of "claim ownership".  With that bug, `desktop-owner'
;; stayed nil forever and the periodic autosave never once wrote a real file even after
;; 10+ idle seconds; confirmed fixed by the same real test once corrected to call
;; `desktop-save' with no second argument, which claims (or keeps) the lock instead.
;;
;; A direct, further user request: a buffer with no file at all (never once saved) should
;; survive a crash too --- not just its name and window slot (already possible via
;; `desktop-save-buffer', the same opt-in flag `my/start-mode'/`my/shortcuts-mode' already
;; use below) but its actual TEXT, with no recovery prompt, just there next time, the same
;; way Notepad++ keeps unsaved tabs. Confirmed as a real gap, not assumed: neither
;; `auto-save-visited-mode' above (requires a real file already) nor plain `desktop-save-
;; buffer' set to `t' (remembers a no-file buffer's name/window slot, never its text ---
;; there is nothing for a mode handler to put back) protects this today; a quick, real
;; test (`C-x b scratch-pad', type something, never save, restart) came back to an empty
;; buffer, exactly the gap described.
;;
;; No package needed for this, same as the rest of this file --- `desktop-save-buffer' may
;; be a FUNCTION, not just `t' (confirmed directly in `desktop.el''s own source: `(when
;; (functionp desktop-save-buffer) (funcall desktop-save-buffer desktop-dirname))'), and
;; whatever it returns is stored as that buffer's own "misc" data, right inside the same
;; `.emacs.desktop' file already written every `desktop-auto-save-timeout' seconds by
;; `my/session--claim-ownership' below --- no separate file, directory, or timer of its
;; own. `desktop-buffer-mode-handlers' is given that misc data back on restore, the
;; exact same extension point `my/start-mode'/`my/shortcuts-mode' already use, just
;; returning real content this time instead of nothing to regenerate. Point is restored
;; automatically by `desktop-create-buffer' itself afterward (confirmed in its own source:
;; every buffer's point is saved/restored independently of any mode handler), so this
;; needs to recreate only the text and the major mode, nothing else.
(defun my/session--unsaved-misc-data (_dirname)
  "Saved as this buffer's own desktop misc-data: enough to recreate it from scratch."
  (list :my/session-unsaved t
        :mode major-mode
        :content (buffer-substring-no-properties (point-min) (point-max))))

(defun my/session--restore-unsaved-buffer (file name misc)
  "`desktop-buffer-mode-handlers' entry that recreates NAME from this feature's own
MISC data (see `my/session--unsaved-misc-data'), instead of the empty buffer `desktop-
read' would otherwise create for a no-file buffer with no handler at all.

A real, caught-by-testing bug this fixes: `desktop-buffer-mode-handlers' dispatches on
major mode ALONE, with no idea whether the buffer being restored actually has a file ---
so a real file-backed buffer that merely happens to open in one of the common modes
registered below (a plain `.txt' file in `text-mode', say) was ALSO being routed through
this handler, which found no `:my/session-unsaved' marker in its (real desktop.el) misc
data, returned nil, and left desktop.el reporting \"failed to restore\" instead of ever
falling back to the normal file-restore path --- broke four real, pre-existing restore
tests the moment this feature's mode list included `text-mode'/`fundamental-mode'.
FILE is desktop.el's own first argument to every mode handler for exactly this reason:
non-nil means a real file is involved, so this delegates straight back to the function
`desktop-create-buffer' would have used with no handler registered at all."
  (if file
      (desktop-restore-file-buffer file name misc)
    (when (plist-get misc :my/session-unsaved)
      (with-current-buffer (get-buffer-create name)
        (let ((inhibit-read-only t))
          (erase-buffer)
          (insert (or (plist-get misc :content) ""))
          (let ((mode (plist-get misc :mode)))
            (when (fboundp mode) (ignore-errors (funcall mode))))
          (set-buffer-modified-p nil)
          (setq-local desktop-save-buffer #'my/session--unsaved-misc-data))
        (current-buffer)))))

;; WHAT: which major modes this covers.  WHY: `desktop-buffer-mode-handlers' dispatches on
;; a buffer's EXACT major mode, no inheritance (confirmed directly in `desktop-create-
;; buffer''s own source: a plain `assq', not `derived-mode-p') --- these are the modes a
;; plain "just typed something, never saved it" buffer actually shows up in in practice
;; (`*scratch*' itself is `lisp-interaction-mode'), not an attempt to cover literally every
;; mode that exists; a no-file buffer in some other, unlisted mode (a `java-ts-mode'
;; buffer with no file, say) is already an edge case nobody asked about, and would need
;; its own entry here if it ever comes up.
(dolist (mode '(fundamental-mode text-mode lisp-interaction-mode org-mode))
  (when (fboundp mode)
    (add-to-list 'desktop-buffer-mode-handlers (cons mode #'my/session--restore-unsaved-buffer))))

;; WHAT: opt a qualifying buffer in to the mechanism just above.  WHY excluded, each
;; confirmed directly rather than guessed: a buffer with a real file (`auto-save-visited-
;; mode' above already protects it; no reason to duplicate that here) or already
;; opted-in (`desktop-save-buffer' already non-nil --- never overwritten, so this never
;; steals a buffer another feature already claimed, e.g. `my/start-mode'); a minibuffer;
;; an internal, space-prefixed buffer; anything `special-mode'-derived --- confirmed this
;; one check alone is enough to exclude `*Messages*' (`messages-buffer-mode'), `*Warnings*'
;; and `*Help*' with no separate by-name denylist needed, since all three really are
;; `special-mode'-derived (checked directly, not assumed); and any READ-ONLY buffer --- a
;; real, caught-by-testing gap this config's own `*docs*' (`my/docs-mode', derived from
;; `outline-mode', not `special-mode') exposed: a generated, read-only, regenerate-on-
;; demand listing buffer with no file still matched every other check, got tracked, and
;; then failed to restore (no entry for `my/docs-mode' in the small mode list below, so
;; `desktop-create-buffer' fell through to its default file-buffer handler and gave up).
;; `buffer-read-only' is the real, principled signal this file was actually missing: if
;; you cannot type into it, it is not something you typed, so it is not this feature's to
;; preserve --- every one of this config's own generated buffers (`*docs*', `*session*',
;; `*sessions*', git-repos, disk-usage, ...) already sets this, confirmed directly, with no
;; need to list them out by name or mode one at a time. HOW: re-run every periodic tick
;; (cheap: `buffer-list' plus a handful of buffer-local checks), so a buffer created since
;; the last tick is picked up within one `desktop-auto-save-timeout' window, same latency
;; as the rest of this file's own periodic save.
(defun my/session--track-unsaved-buffers ()
  "Opt every qualifying file-less buffer in, so its actual text (not just its name) is
saved and restored like any other buffer."
  (dolist (buf (buffer-list))
    (with-current-buffer buf
      (when (and (not buffer-file-name)
                 (not desktop-save-buffer)
                 (not buffer-read-only)
                 (not (minibufferp buf))
                 (not (string-prefix-p " " (buffer-name buf)))
                 (not (derived-mode-p 'special-mode)))
        (setq-local desktop-save-buffer #'my/session--unsaved-misc-data)))))

(defun my/session--claim-ownership ()
  (when desktop-save-mode
    (my/session--track-unsaved-buffers)
    (desktop-save my/session-dir)))

;; Two more real bugs, caught only by a genuine round trip (open a file via the command
;; line, wait, quit, reopen) --- a real user hit both, not hypothetical:
;;
;; 1. `after-init-hook' (what the first version of this hook used) runs BEFORE Emacs
;;    processes any files named on the command line --- confirmed directly in
;;    `startup.el''s own doc for `emacs-startup-hook': "run after loading init files AND
;;    HANDLING THE COMMAND LINE" (`after-init-hook' has no such second half). So the one
;;    explicit save meant to "claim ownership immediately" was claiming it over an empty
;;    buffer list every time --- any file opened from the command line (exactly how this
;;    config's own macOS/Linux/Windows launchers all start Emacs, `emacs somefile', or
;;    just plain `emacs' with nothing) was never in it.
;; 2. Once that first (empty) save has already claimed the lock, desktop.el's OWN
;;    periodic autosave (`desktop-auto-save-enable', which hooks
;;    `window-configuration-change-hook') never fires again for the common case of
;;    simply opening/switching buffers in a single, never-split window --- confirmed
;;    directly: `desktop-auto-save-timer' stayed `nil' after a plain `find-file' with no
;;    split, meaning the ONLY real-world action that reliably re-triggers it is actually
;;    changing the window layout, not just working in it. A session spent entirely in
;;    one window, however long, would otherwise never save again after that first, empty
;;    snapshot.
;;
;; Fixed by not relying on either of desktop.el's own two hooks for this at all: one
;; one-shot save on `emacs-startup-hook' (after command-line files ARE open) claims
;; ownership correctly the first time, and this config's own idle timer (re-using
;; `desktop-auto-save-timeout', the same value desktop.el's own timer would have used)
;; keeps it updated from then on, regardless of whether the window layout ever changes.
;; Verified fixed with the same real round trip: opened a file via the command line,
;; waited past this timeout with no split, quit cleanly, reopened --- the file came back.
(defvar my/session--autosave-timer nil)
(defun my/session--start-autosave ()
  (my/session--claim-ownership)
  (setq my/session--autosave-timer
        (run-with-idle-timer (max 1 desktop-auto-save-timeout) t #'my/session--claim-ownership)))
(add-hook 'emacs-startup-hook #'my/session--start-autosave 90)

;; A third real bug, found the same way (a genuine round trip, not reading the source):
;; a direct user request was for the `*start*' buffer to always exist after a restore,
;; reachable from the buffer list, even though a real session is what is actually shown
;; --- confirmed, with a FIRST fix, to work in an isolated simulation that created
;; `*start*' before simulating the restore... which turned out to not match the real
;; order at all. The real order, confirmed directly in `startup.el' itself (not assumed
;; from this file's own earlier, wrong comment above): `after-init-hook' --- where
;; `desktop-read' actually restores a session --- runs BEFORE `command-line-1', and
;; `initial-buffer-choice' (`my/start-initial-buffer' in startpage.el) is only evaluated
;; well inside THAT function, checking "is `current-buffer' still `*scratch*'" to decide
;; whether to create the start screen at all. By the time that check runs, a real
;; restore has already made some OTHER buffer current --- so the check correctly (by
;; its own, narrower logic) declines, and `my/start-buffer' is never called at all.
;; Reproduced directly: restoring a saved session left `*start*' simply not existing
;; (`(get-buffer "*start*")' => nil), confirmed with the real startup order, not the
;; earlier, backwards simulation. Fixed here instead, since `my/start-buffer' itself
;; never disturbs the display (`with-current-buffer', not `switch-to-buffer' --- see
;; its own definition in startpage.el): called unconditionally alongside the autosave
;; claim above, this always ensures the buffer exists and is freshly drawn, with no
;; effect on whatever a real restore (or the start screen itself) actually shows.
(with-eval-after-load 'startpage (add-hook 'emacs-startup-hook #'my/start-buffer 95))

;; A direct, further user request: keep `*shortcuts*' always in the buffer list too, the
;; same guarantee as `*start*' just above, for the same real reason --- it is normally
;; only created by `my/shortcuts--maybe-show-at-startup' (shortcuts.el), itself gated on
;; the start screen actually being what is showing (`(eq (window-buffer) (get-buffer
;; "*start*"))'), so a real restore skips it exactly like it used to skip `*start*'
;; itself. `my/shortcuts-buffer' (the create-and-draw half, called by that display logic)
;; has the same `with-current-buffer' shape as `my/start-buffer' --- confirmed in its own
;; definition in shortcuts.el --- so calling it unconditionally here is safe the same way:
;; it cannot disturb whatever a real restore (or the start screen's own automatic split)
;; actually shows, only ensure the buffer object itself always exists.
(with-eval-after-load 'shortcuts (add-hook 'emacs-startup-hook #'my/shortcuts-buffer 95))

;; A further, direct user request: a few more buffers should just be "there" by default
;; too, the same guarantee as `*start*'/`*shortcuts*' just above --- a Dired buffer for
;; wherever Emacs was actually launched from (`my/session--launch-directory', defined at
;; the top of this file), reachable from the buffer list (`C-x b'/`C-c w l') without
;; asking for it first. Confirmed, not assumed: the user explicitly wants this ready, NOT
;; shown on screen --- the start screen's own layout must look exactly the same as before.
;;
;; Treemacs was considered and deliberately left out (a direct, later user request: "lets
;; not add treemacs").
;;
;; `ranger' is also deliberately NOT included here: unlike Dired, it has no "just create
;; the buffer, don't show it" mode at all --- confirmed directly in its own `ranger-to-
;; dired' (see init.el's own comment on `my/ranger-to-dired'): invoking `ranger'
;; unconditionally calls `delete-other-windows' and takes over the frame with its 3-pane
;; layout the moment it runs. Pre-creating it here would visibly disrupt whatever the
;; start screen or a restored session is already showing --- the exact opposite of what
;; was asked for. `C-c R' already opens it instantly wherever you are; there is nothing to
;; pre-warm.
(defun my/session--ensure-default-dired ()
  "A Dired buffer for `my/session--launch-directory', always present in the buffer
list. `dired-noselect' (not `dired'/`dired-other-window') never selects or displays
anything, so this cannot disturb whatever is already on screen; Dired itself
deduplicates by directory (its own, built-in behavior), so calling this again on an
already-open directory is harmless, not a second copy."
  (dired-noselect my/session--launch-directory))
(add-hook 'emacs-startup-hook #'my/session--ensure-default-dired 95)

;; WHAT: `C-c w s' --- save the session right now, by hand.  WHY: a deliberate
;; checkpoint before doing something risky, rather than waiting for the periodic
;; autosave or a clean exit.  HOW: same call, and the same RELEASE-argument bug and fix,
;; as `my/session--claim-ownership' just above --- omitting the second argument keeps
;; (or claims) the lock, rather than releasing it.
;;;###autoload
(defun my/session-save ()
  "Save the current session (open buffers, window layout) right now."
  (interactive)
  (desktop-save my/session-dir)
  (message "Session saved (%s)" my/session-dir))

;; WHAT: `C-c w r' --- discard the saved session, back to the ordinary start screen.
;; WHY: this is the "they can reset the state to default" half of the request: without
;; it, once a session exists, it would restore forever with no way back to a clean
;; start. HOW: `desktop-clear' (built into desktop.el) closes every real buffer and
;; window in THIS running Emacs right now; `desktop-remove' deletes the saved file so
;; the NEXT startup has nothing to restore (falling through to the start screen exactly
;; as it does on a first run) --- but `desktop-remove' also sets `desktop-dirname' to
;; nil as a side effect, which would otherwise make Emacs prompt "Directory for desktop
;; file?" on its next exit; resetting it back to `my/session-dir' right after keeps
;; future saves fully automatic, with no prompt, same as before the reset.
;;;###autoload
(defun my/session-reset ()
  "Discard the saved session: close every buffer and window in this Emacs right now,
and delete the saved file so the next start shows the usual start screen instead of
restoring anything.  A later exit still saves a fresh session normally."
  (interactive)
  (desktop-clear)
  (desktop-remove)
  (setq desktop-dirname my/session-dir)
  (message "Session reset: nothing will be restored the next time Emacs starts"))

;; WHAT: `C-c w l' --- show exactly which open buffers are part of the session (would be
;; saved if it saved right now).  WHY: without this, "what's actually in my session" is
;; invisible --- the answer to "can it list states like buffers?".  HOW: `desktop-save-
;; buffer-p' is desktop.el's OWN real filter (the exact same predicate `desktop-save'
;; itself consults for every buffer) --- called here with each buffer's real filename/
;; name/major-mode, so this list is never a guess or an approximation of desktop.el's
;; rules (which files/modes are excluded, e.g. remote files, `tags-table-mode', buffers
;; with no visible name) --- it reflects them exactly, automatically staying correct even
;; if those rules are ever customized.  Rendered as a real, clickable buffer (RET/click
;; switches to it), the same pattern as `my/find-git-repos'/`my/start': a `special-mode'-
;; derived, read-only, `q'-to-close buffer, not just an echo-area message, since a real
;; session can easily have more buffers than fit on one message line.
(defvar my/session-list-buffer-name "*session*")

(defun my/session--tracked-buffers ()
  "Every live buffer `desktop-save-buffer-p' says belongs in the session right now."
  (seq-filter
   (lambda (buf)
     (with-current-buffer buf
       (desktop-save-buffer-p buffer-file-name (buffer-name) major-mode)))
   (buffer-list)))

(defvar my/session-list-mode-map
  (let ((m (make-sparse-keymap)))
    (set-keymap-parent m special-mode-map)
    (define-key m "g" #'my/session-list)
    m))

(define-derived-mode my/session-list-mode special-mode "Session"
  "Every buffer currently part of the saved session.  See `my/session-list'.")

;;;###autoload
(defun my/session-list ()
  "Show every buffer that is currently part of the session (would be saved if it
saved right now), each a link to switch to it."
  (interactive)
  (let ((buffers (my/session--tracked-buffers))
        (buf (get-buffer-create my/session-list-buffer-name)))
    (with-current-buffer buf
      (let ((inhibit-read-only t))
        (unless (derived-mode-p 'my/session-list-mode) (my/session-list-mode))
        (erase-buffer)
        (insert (propertize "This session\n\n" 'face '(:height 1.2 :weight bold)))
        (insert (format "  %d buffer%s will be saved (RET/click opens one; g refreshes; q closes)\n"
                        (length buffers) (if (= (length buffers) 1) "" "s")))
        (insert (format "  Saved to: %s\n\n" my/session-dir))
        (if (null buffers)
            (insert "  (none yet)\n")
          (dolist (b buffers)
            (insert "  ")
            (insert-text-button
             (or (buffer-file-name b) (buffer-name b))
             'action (let ((b b)) (lambda (_) (switch-to-buffer b)))
             'follow-link t 'help-echo (buffer-name b))
            (when (buffer-modified-p b) (insert (propertize "  (modified)" 'face 'shadow)))
            (insert "\n")))
        (goto-char (point-min))
        (set-buffer-modified-p nil)))
    (switch-to-buffer buf)))

;;; Named sessions: more than one, saved side by side -------------------------------------
;;
;; Answers "how many sessions/states can be saved, is that a possibility": yes --- as many
;; as you like.  Each named session is just its own small directory (a `.emacs.desktop'
;; file, typically a few KB) under `my/session-named-root'; there is no limit coded here,
;; only disk space.  These are separate from, and never disturb, the one always-auto-
;; saving LIVE session above (`my/session-dir') --- opening or saving a named snapshot
;; never repoints where crash protection is writing to.  That separation is real, not
;; just intended: `desktop-save' and `desktop-read' both have several undocumented-in-
;; the-docstring side effects (confirmed by reading their source, and by a real test
;; catching two real prompts/hangs a naive implementation would have hit --- see below),
;; every one of which is let-bound around every named-session call so none of it leaks
;; into the live session's own bookkeeping.

(defvar my/session-named-root (expand-file-name "session-named/" user-emacs-directory)
  "Where named session snapshots are kept, one subdirectory per name.")
(make-directory my/session-named-root t)

;; WHAT: the four small helpers `my/session-save-as'/`-open'/`-delete'/`-named-list' below
;; all go through to turn a typed NAME into a real, safe filesystem path and back.  WHY: a
;; named session's NAME becomes a literal subdirectory name under `my/session-named-root'
;; --- taken straight from user input (`interactive "s..."' or `completing-read'), so it has
;; to be checked before ever reaching `expand-file-name'/`make-directory': a slash would let
;; it escape into an unrelated subdirectory instead of naming one directly inside
;; `my/session-named-root', and "." or ".." are reserved by the filesystem itself (the
;; current/parent directory), not a real session name at all.  HOW: `--sanitize-name' is the
;; one gate every path-building call (`--named-dir') goes through; `--named-names' lists only
;; real, non-dotfile subdirectories (so a stray dotfile some other tool left there is never
;; mistaken for a saved session); `--read-name' wraps that listing for the two different ways
;; callers need to ask for a name --- REQUIRE-MATCH t for "pick an existing one" (`my/session-
;; open'/`-delete', which refuse outright if none exist yet), nil for "type a new one"
;; (`my/session-save-as', where no match is expected).
(defun my/session--sanitize-name (name)
  "NAME as a single, safe directory name: no slashes, not empty, not \".\" or \"..\"."
  (let ((name (string-trim name)))
    (when (string-empty-p name) (user-error "Session name can't be empty"))
    (when (string-match-p "[/\\]" name) (user-error "Session name can't contain a slash"))
    (when (member name '("." "..")) (user-error "That name is reserved"))
    name))

(defun my/session--named-dir (name)
  (file-name-as-directory (expand-file-name (my/session--sanitize-name name) my/session-named-root)))

(defun my/session--named-names ()
  "Every existing named session, alphabetically."
  (when (file-directory-p my/session-named-root)
    (sort (seq-filter (lambda (n) (file-directory-p (expand-file-name n my/session-named-root)))
                      (directory-files my/session-named-root nil "\\`[^.]"))
          #'string<)))

(defun my/session--read-name (prompt &optional require-match)
  (let ((names (my/session--named-names)))
    (when (and require-match (null names)) (user-error "No named sessions saved yet"))
    (completing-read prompt names nil require-match)))

;; WHAT: `C-c w S' --- save the current buffers/window layout as a separate, named
;; snapshot.  WHY/HOW: `desktop-save' unconditionally does `(setq desktop-dirname
;; DIRNAME)' as its very first line, and also mutates `desktop-io-file-version',
;; `desktop-file-checksum' and `desktop-saved-frameset' --- every one of which, left
;; alone, would silently repoint the LIVE session's own bookkeeping at this named
;; directory instead.  All four are let-bound here, so none of it leaks out: once this
;; returns, `desktop-dirname' (and friends) are exactly what they were before, still
;; `my/session-dir'.  `desktop-file-modtime' is let-bound too, but to the NAMED
;; directory's own real, current file modtime (or nil, if saving under this name for the
;; first time) rather than left alone --- confirmed for real to matter: leaving it at the
;; live session's own (unrelated) modtime made `desktop-save' think the named file had
;; changed out from under it on every re-save, and ask \"Overwrite this desktop file?\"
;; (in a script with no terminal attached, this doesn't wait forever; it fails outright
;; with \"Error reading from stdin\" --- either way, not what a plain re-save should do).
;;;###autoload
(defun my/session-save-as (name)
  "Save the current buffers and window layout as a separate, named snapshot, without
disturbing the live, automatically-saved session."
  (interactive "sSave session as: ")
  (let* ((dir (my/session--named-dir name))
         (target (expand-file-name desktop-base-file-name dir))
         (desktop-dirname desktop-dirname)
         (desktop-io-file-version desktop-io-file-version)
         (desktop-file-checksum desktop-file-checksum)
         (desktop-saved-frameset desktop-saved-frameset)
         (desktop-file-modtime (and (file-exists-p target)
                                    (file-attribute-modification-time (file-attributes target)))))
    (make-directory dir t)
    (desktop-save dir)
    (message "Session saved as \"%s\" (%s)" name dir)))

;; WHAT: `C-c w O' --- replace the current buffers/window layout with a named snapshot.
;; WHY/HOW: `desktop-clear' first (same as `my/session-reset'), so opening one replaces
;; what's open rather than piling on top of it; called as a plain function, not
;; interactively, so it never also tries to delete frames (that part of `desktop-clear'
;; is itself guarded on `called-interactively-p').  `desktop-read' has the same real
;; side-effects problem as `desktop-save' above (confirmed by reading its source too) ---
;; the same four variables are let-bound for the same reason, so the buffers this opens
;; become part of the LIVE session going forward (the next autosave, or `C-c w s', saves
;; them into `my/session-dir', not back into the named snapshot); opening a snapshot
;; loads it into your live workspace, it does not switch which directory is \"live\".
;; One more real thing this catches: `desktop-read' claims the lock of whatever directory
;; it reads from and never releases it --- left alone, opening the SAME named session a
;; second time later would silently do nothing at all (`desktop-read' declines outright
;; once `(desktop-owner)' already equals `(emacs-pid)', confirmed for real: the message
;; is literally \"Not reloading the desktop\"), since this process would already
;; \"own\" it from the first open.  Releasing the lock right after keeps every named
;; session freely re-openable, not just once.
;;;###autoload
(defun my/session-open (name)
  "Replace the current buffers and window layout with the named session snapshot NAME."
  (interactive (list (my/session--read-name "Open session: " t)))
  (let ((dir (my/session--named-dir name)))
    (unless (file-exists-p (expand-file-name desktop-base-file-name dir))
      (user-error "No saved session named \"%s\"" name))
    (desktop-clear)
    (let ((desktop-dirname desktop-dirname)
          (desktop-io-file-version desktop-io-file-version)
          (desktop-file-checksum desktop-file-checksum)
          (desktop-saved-frameset desktop-saved-frameset)
          (noninteractive nil))         ; desktop-read is a no-op under noninteractive
      (desktop-read dir)
      (desktop-release-lock dir))
    (message "Opened session \"%s\"" name)))

;; WHAT: `C-c w D' --- delete a named session snapshot for good.  WHY/HOW: just removes
;; its directory, after confirming --- unlike `C-c w r' (the live session, which the
;; periodic autosave would recreate anyway), a named snapshot is the only copy of itself.
;;;###autoload
(defun my/session-delete (name)
  "Delete the named session snapshot NAME for good."
  (interactive (list (my/session--read-name "Delete session: " t)))
  (when (yes-or-no-p (format "Delete the saved session \"%s\"? " name))
    (delete-directory (my/session--named-dir name) t)
    (message "Deleted session \"%s\"" name)))

;; WHAT: `C-c w L' --- list every named session (distinct from `C-c w l', which lists the
;; live session's own buffers).  WHY/HOW: same real, clickable-buffer pattern as
;; `my/session-list'; RET/click on a name opens it (`my/session-open'); `d' deletes it.
(defvar my/session-named-list-buffer-name "*sessions*")

(defvar my/session-named-list-mode-map
  (let ((m (make-sparse-keymap)))
    (set-keymap-parent m special-mode-map)
    (define-key m "g" #'my/session-named-list)
    (define-key m "d" #'my/session-delete)
    m))

(define-derived-mode my/session-named-list-mode special-mode "Sessions"
  "Every named session snapshot.  See `my/session-named-list'.")

;;;###autoload
(defun my/session-named-list ()
  "List every named session snapshot, each a link to open it."
  (interactive)
  (let ((names (my/session--named-names))
        (buf (get-buffer-create my/session-named-list-buffer-name)))
    (with-current-buffer buf
      (let ((inhibit-read-only t))
        (unless (derived-mode-p 'my/session-named-list-mode) (my/session-named-list-mode))
        (erase-buffer)
        (insert (propertize "Named sessions\n\n" 'face '(:height 1.2 :weight bold)))
        (insert (format "  %d saved (RET/click opens one; d deletes; g refreshes; q closes)\n"
                        (length names)))
        (insert "  C-c w S saves the current one under a new name\n\n")
        (if (null names)
            (insert "  (none yet)\n")
          (dolist (n names)
            (insert "  ")
            (insert-text-button n 'action (let ((n n)) (lambda (_) (my/session-open n)))
                                'follow-link t 'help-echo (format "Open %s" n))
            (insert "\n")))
        (goto-char (point-min))
        (set-buffer-modified-p nil)))
    (switch-to-buffer buf)))

(defvar my/session-mode-map (make-sparse-keymap))
(define-key my/session-mode-map "s" #'my/session-save)
(define-key my/session-mode-map "r" #'my/session-reset)
(define-key my/session-mode-map "l" #'my/session-list)
(define-key my/session-mode-map "S" #'my/session-save-as)
(define-key my/session-mode-map "O" #'my/session-open)
(define-key my/session-mode-map "D" #'my/session-delete)
(define-key my/session-mode-map "L" #'my/session-named-list)
(global-set-key (kbd "C-c w") my/session-mode-map)

;; WHAT: `C-c N' --- a one-key "just give me a blank page", the same thing Notepad++'s
;; own New button does. WHY: plain `C-x b' (already documented in KEYBOARD.md) needs a
;; name typed first every time --- fine for a buffer you already have in mind, not for
;; "as many as possible, as fast as possible" the way the user asked for this. WHY `C-c
;; N', not the more obvious `C-c n': already bound to `newsticker-treeview' (see
;; shortcuts.el's own reference list) --- checked first, not assumed free.
;; HOW: `generate-new-buffer' (not `get-buffer-create') is what actually makes repeated
;; presses give a DIFFERENT buffer every time --- `untitled', `untitled<2>', `untitled<3>',
;; ... automatically, never colliding with an existing one, confirmed directly in its own
;; docstring. No file, so no extra wiring needed to make it crash-safe: it immediately
;; qualifies for `my/session--track-unsaved-buffers' above (no file, not read-only, not
;; `special-mode'-derived, not already claimed) --- the SAME auto-save/restore every
;; other no-file buffer already gets, the next periodic tick after you start typing.
(defun my/new-empty-buffer ()
  "Create and switch to a brand-new, empty, unnamed buffer --- Notepad++'s own New
button, one key, as many times as you like."
  (interactive)
  (switch-to-buffer (generate-new-buffer "untitled")))
(global-set-key (kbd "C-c N") #'my/new-empty-buffer)

(provide 'emacs-session)
;;; emacs-session.el ends here
