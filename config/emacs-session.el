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
(defun my/session--claim-ownership ()
  (when desktop-save-mode (desktop-save my/session-dir)))
(add-hook 'after-init-hook #'my/session--claim-ownership 90)

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

(provide 'emacs-session)
;;; emacs-session.el ends here
