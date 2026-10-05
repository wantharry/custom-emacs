;;; init.el --- personal config for the research Emacs  -*- lexical-binding: t; -*-

;; This configuration uses features from Emacs 30 (completion preview, built-in
;; which-key, Eglot's log setting).  Fail with a clear message instead of an obscure
;; "void function" halfway through.  Built and tested on 32.0.50.
(when (< emacs-major-version 30)
  (error "This configuration needs Emacs 30 or newer; this is Emacs %s" emacs-version))

;;; Startup / performance ----------------------------------------------------

;; Restore a sane GC threshold after startup (early-init.el raised it).
(add-hook 'emacs-startup-hook
          (lambda ()
            (setq gc-cons-threshold (* 64 1024 1024)   ; 64 MB
                  gc-cons-percentage 0.2)))

;; Reading from subprocesses (LSP servers etc.) is faster with a bigger buffer.
(setq read-process-output-max (* 1024 1024))

;; Keep machine-generated settings out of this file.
(setq custom-file (expand-file-name "custom.el" user-emacs-directory))
(when (file-exists-p custom-file) (load custom-file nil t))

;;; UI -----------------------------------------------------------------------

(menu-bar-mode 1)
(column-number-mode 1)
(global-display-line-numbers-mode 1)
(global-hl-line-mode 1)
(setq-default indicate-empty-lines t
              fill-column 80)

;; User request: always know where you are, at a glance, without reading the mode
;; line's own (just the bare buffer NAME, not its location) --- the full path for a
;; file-visiting buffer, or the directory for one that isn't (Dired, `ranger',
;; `*scratch*', ...), `abbreviate-file-name'd the same way Emacs's own minibuffer
;; prompts already shorten the home directory to `~'. `setq-default' here, not a
;; global minor mode: a plain default only ever applies to a buffer that has not set
;; its OWN `header-line-format' --- confirmed directly in `ranger.el''s own source,
;; it already sets one buffer-locally (`ranger-header-func', the "openclaw@host :
;; /path" line already visible at the top of a `ranger' session) --- so this adds
;; the one real gap (plain Dired, file buffers, everything else) without touching or
;; fighting ranger's own, already-informative header.
(setq-default header-line-format
              '(:eval (propertize (abbreviate-file-name (or buffer-file-name default-directory))
                                  'face 'header-line)))

;; WHAT: `C-c u' hides/shows the menu bar, tool bar and this frame's own window
;; decorations (title bar/border) together, as one switch, rather than three separate
;; `eval-expression'/`M-x' calls. WHY: a real, found-by-doing-it problem --- these three
;; were toggled by hand, one at a time, to try a cleaner-looking frame; all three are
;; also frame parameters/minor modes that this config's own session-restore system
;; (`config/emacs-session.el', `desktop-save-mode') saves and restores automatically,
;; so whichever state they were left in at the next save (on exit, or the periodic
;; auto-save) is exactly what every future launch comes back showing --- confirmed
;; directly, not assumed, after "it keeps showing no menu bar every time I open it"
;; turned out to be the session system faithfully doing its job, not a bug. This command
;; does not change anything about THAT persistence --- it is still true that whatever
;; state these three are in at the next save is what sticks --- it only makes getting
;; all three into a known, matching state (all shown, or all hidden) a single keystroke
;; instead of three manual forms to remember and re-type.
;; HOW: a real design mistake, caught by the test rather than assumed correct ---
;; a first version decided which way to toggle by reading `menu-bar-mode''s own current
;; state, on the assumption all three already started out matching. They do not: this
;; config's own `early-init.el' pushes `(tool-bar-lines . 0)' onto `default-frame-alist'
;; (a startup-speed optimization, unrelated to this feature), so the tool bar starts
;; OFF while the menu bar starts ON. Reading menu-bar's state to decide tool-bar's new
;; state meant two presses could leave the tool bar visible even though nothing had ever
;; asked for that. Fixed with its own dedicated tracking variable instead of inferring
;; from any one component's current (possibly mismatched) state.
(defvar my/frame-chrome-hidden nil
  "Whether `my/toggle-frame-chrome' last hid the menu bar/tool bar/decorations.")
(defun my/toggle-frame-chrome ()
  "Hide/show the menu bar, tool bar and this frame's window decorations together.
Tracked by `my/frame-chrome-hidden' rather than read back from any one of the three, so
repeated presses always alternate cleanly between \"all shown\" and \"all hidden\" no
matter what state each started in. The window-decoration change applies to this frame
only; the menu/tool bar change (like the modes themselves) applies to every frame."
  (interactive)
  (setq my/frame-chrome-hidden (not my/frame-chrome-hidden))
  (if my/frame-chrome-hidden
      (progn (menu-bar-mode -1) (tool-bar-mode -1)
             (set-frame-parameter nil 'undecorated t))
    (menu-bar-mode 1) (tool-bar-mode 1)
    (set-frame-parameter nil 'undecorated nil)))
(global-set-key (kbd "C-c u") #'my/toggle-frame-chrome)

;; WHAT: `C-c U' (paired with `C-c u') puts the menu bar, tool bar, window decorations
;; and color theme back to exactly what this config's own "UI"/"Themes" sections set at
;; a fresh start, then immediately saves that as the session restored next time.
;; WHY: a real, repeatedly-hit two-part problem, not something guessed at --- (1)
;; neither toggling these by hand nor `C-c w r' (`my/session-reset') actually puts the
;; LIVE frame back to this config's own defaults: `my/session-reset' only deletes the
;; *saved* file, so if the menu bar was off in the running Emacs at that moment, it
;; stays off, and (2) even after fixing the live state by hand, forgetting the separate
;; "now save it" step (`C-c w s') meant the old, hidden state got auto-saved again on
;; the very next exit anyway, undoing the fix before it ever took effect --- confirmed
;; directly, this exact sequence, more than once. This command does both halves at
;; once, in the right order, so there is no second step left to forget.
;; A real correction made along the way, after a user question about exactly this, not
;; assumed: menu-bar/tool-bar/decorations were ALREADY genuinely persisted by `my/
;; session-save' on their own --- confirmed directly by saving a real session and
;; inspecting the raw saved file, which shows `menu-bar-lines'/`tool-bar-lines'/
;; `undecorated' sitting right there as real, explicit frame parameters (stock
;; `desktop-save-mode' behavior: "remember my windows" and "remember my frame's
;; appearance" are the same underlying mechanism, a frameset, not two separate ones,
;; even though "session" sounds like it should mean "just the buffers"). The color
;; theme was NOT part of that, though --- confirmed the same way, restoring a saved
;; session used to bring back whatever `theme-buffet' happened to randomly pick for the
;; current time of day, never what was actually active when saved. Fixed separately
;; (see `my/session-theme'/`desktop-after-read-hook' in the "Themes" section above), so
;; by the time this function runs, disabling the theme here really does persist too,
;; the same as the other three.
;; HOW: reuses the same logic the rest of this config already trusts, rather than
;; re-stating what "default" means a second time in a second place: `my/load-theme-by-
;; number' with `?0' is exactly what `C-c c 0' already does to return to no theme
;; (disables every enabled theme, restores the fixed cursor color); `my/session-save' is
;; exactly `C-c w s'. The menu-bar/tool-bar/decoration values set here are this file's
;; own real startup defaults --- menu bar on (`(menu-bar-mode 1)' above), tool bar off
;; (`early-init.el''s `(tool-bar-lines . 0)'), decorations on --- not separately
;; invented ones.
(defun my/reset-to-defaults ()
  "Put the menu bar, tool bar, window decorations and color theme back to this config's
own startup defaults, then immediately save that as the session restored next time."
  (interactive)
  (setq my/frame-chrome-hidden nil)
  (menu-bar-mode 1)
  (tool-bar-mode -1)
  (set-frame-parameter nil 'undecorated nil)
  (my/load-theme-by-number ?0)
  ;; A real, user-reported bug: toggling menu-bar/tool-bar here changes the real
  ;; frame's pixel geometry in a GUI, which can leave `my/mode-reference-mode''s own
  ;; panel (if showing) scrolled a little way down from its own top --- confirmed
  ;; directly, not assumed, from a real screenshot. `window-size-change-functions'
  ;; (config/mode-reference.el) already catches this generally, but re-anchoring it
  ;; explicitly here too, right after the resize that actually causes it, means it
  ;; never has even a moment to look wrong.
  (when (fboundp 'my/mode-reference--update) (my/mode-reference--update))
  (my/session-save)
  (message "Frame and theme reset to defaults, and saved"))
(global-set-key (kbd "C-c U") #'my/reset-to-defaults)

;; WHAT: wrap long lines at the last word boundary that fits, not at the exact character
;; the window edge happens to land on.  WHY: Emacs's own default (`word-wrap' nil) wraps
;; mid-word whenever a word straddles that boundary --- the continuation arrow shown in
;; the right fringe then sits in the middle of a split word, which is what was actually
;; being asked about ("why does it break the word... can we make sure only show when the
;; word fits"). `word-wrap' t moves the wrap point back to the nearest space/word-break
;; before the edge instead, so a whole word moves down to the next line together rather
;; than being cut in half; the fringe arrow still appears (it is what marks any wrapped,
;; not-a-real-newline continuation), but now only at an actual word boundary.
(setq-default word-wrap t)

;; No theme yet: Emacs default colors. Add `load-theme' here later.

;; Use the first available font from the list; fall back to the default.
;; "JetBrainsMono Nerd Font Mono" comes first because that is this font's real installed name
;; here (`fc-list`); the plain "JetBrains Mono" name never matches on this machine, so it
;; silently fell through to DejaVu Sans Mono. Kept as a fallback for a machine that has the
;; non-Nerd-Font release installed instead.
(when (display-graphic-p)
  (let ((font (seq-find (lambda (f) (find-font (font-spec :name f)))
                        '("JetBrainsMono Nerd Font Mono" "JetBrains Mono" "Fira Code" "Cascadia Code"
                          "DejaVu Sans Mono" "Menlo" "Consolas"))))
    (when font
      (set-face-attribute 'default nil :font font :height 120))))

;;; Calendar (M-x calendar / C-c y for a whole year) ---------------------------

;; A real mistake, made and reverted in the same session: `calendar-total-months' was
;; briefly set to 12 here, on the assumption that "shows more months" meant a sensible
;; multi-row year grid.  It does not --- `calendar.el' lays every month out in a single
;; row, so 12 months is one line 12 * calendar-month-width columns wide (300 on this
;; build, measured directly, not guessed).  On any normal window that just wraps and
;; scrambles --- confirmed for real, reported by the user right after the first version
;; of this comment claimed it was "verified" (it was, but only that the *text* held 12
;; month names, never what that actually renders as in a real window --- the same
;; mistake category as the word-wrap fix earlier this session, and the org/session.el
;; bug before that: tested in isolation, not through the real, visible result). Left at
;; the stock default (3) as a result --- `M-x calendar'`'s own `<'/`>' scroll that same
;; three-month window forward/backward through the year one month at a time.
;;
;; `C-c y' (`my/calendar-year') is the real fix instead: a genuine year-at-a-glance grid
;; (4 rows of 3 months), built by hand in config/calendar-year.el on top of `calendar-
;; generate-month' --- the same primitive `M-x calendar' itself uses for one row, just
;; called once per row here instead of once for all 12 in a row nothing can wrap sanely.
;; See that file's own header comment for the full story.
(autoload 'my/calendar-year (expand-file-name "calendar-year" user-emacs-directory)
  "Show all 12 months of a year in a grid, 3 months per row." t)
(global-set-key (kbd "C-c y") #'my/calendar-year)

;;; Org mode -------------------------------------------------------------------
;; `.org' files auto-activate `org-mode' again (the stock default) --- this was
;; disabled for one session, then turned back on by request. Org's own ~103 `C-c'
;; bindings (confirmed directly, versus 19 on this config's own `C-c' outside one) are
;; mode-local to `org-mode-map' --- they only ever show up inside a real `.org' buffer,
;; confirmed directly (a plain `text-mode' buffer sees 25 `C-c' bindings, a real
;; `org-mode' buffer sees 109), never anywhere else, so this does not affect any other
;; file type at all.

;;; Editing ------------------------------------------------------------------

(setq-default indent-tabs-mode nil
              tab-width 4)
(setq require-final-newline t
      sentence-end-double-space nil
      ring-bell-function #'ignore
      use-short-answers t)

;; Windows would otherwise save new files with CRLF line endings; use UTF-8 with LF, as on Linux
;; and macOS, so a file is the same wherever you write it.  Files that already use CRLF keep it.
(when (eq system-type 'windows-nt)
  (prefer-coding-system 'utf-8-unix)
  ;; ... and do not print "(Unix)" in the mode line for it, which Linux does not
  (setq eol-mnemonic-unix ":"))

(electric-pair-mode 1)
(show-paren-mode 1)
(delete-selection-mode 1)
(global-auto-revert-mode 1)
(save-place-mode 1)
(recentf-mode 1)
;; `recentf' only saves its list via `kill-emacs-hook' by default, so an unclean exit
;; (a crash, a forced kill, a real hang needing Task Manager) loses the whole session's
;; history --- confirmed for real on the Windows bundle: after a forced kill, the very
;; next launch showed none of that session's files.  A periodic autosave closes most of
;; that window, the same way `my/start-save' (startpage.el) already protects the recent
;; folders/projects list.
(run-with-idle-timer 30 t #'recentf-save-list)
;; WHAT: stop that periodic autosave (and `recentf' startup cleanup) from printing to
;; the echo area every 30s.  WHY: a real, reported problem --- `recentf-show-messages'
;; defaults to `t' in stock Emacs, so every single autosave shows "Wrote .../
;; recentf.eld", stock Emacs behavior this config never touched before now, not
;; something this idle timer itself introduced.  Confirmed directly in `recentf.el's own
;; source: the "Wrote FILE" message comes from a plain `write-region' call whose quiet-
;; flag is exactly `(unless (or (called-interactively-p 'interactive) recentf-show-
;; messages) 'quiet)' --- an autosave from a timer is never "interactive", so this alone
;; is enough to silence it; the actual saving (and the crash-safety it exists for) is
;; unaffected, only the message. `my/start-save' (startpage.el)'s own `recents.eld'
;; autosave already writes silently by construction (`with-temp-file' uses `write-
;; region's undocumented-but-real "VISIT is an integer" form, which stock Emacs's own
;; `write-region' never messages for regardless of this setting) --- confirmed in
;; `fileio.c' directly, not assumed, so nothing else needed changing for that file.
(setq recentf-show-messages nil)
(savehist-mode 1)

;; Backups and auto-saves go to one place instead of littering projects.
;; WHY these two settings specifically, not just the redirect above: `backup-by-copying'
;; makes Emacs back a file up by copying it, rather than its own normal default of
;; renaming the original aside and writing a fresh file in its place --- the usual
;; default quietly breaks a hard-linked or symlinked file (the rename severs the link,
;; so the backup ends up holding the only copy of what used to be shared) and is also
;; the one that changes a file's ownership/permissions on every save; copying instead
;; never touches the original file's identity at all.  `create-lockfiles' nil turns off
;; Emacs's own `.#filename' lock files --- harmless on a single-user machine with nothing
;; else watching these directories, and otherwise just one more stray generated file
;; per edited buffer for no benefit here.
(let ((dir (expand-file-name "backups/" user-emacs-directory)))
  (make-directory dir t)
  (setq backup-directory-alist `(("." . ,dir))
        auto-save-file-name-transforms `((".*" ,dir t))
        backup-by-copying t
        create-lockfiles nil))

;;; Every file opens read-only -------------------------------------------------

;; Nothing on disk changes by accident, for example when a slip while learning
;; shortcuts turns into typed text.  Each file you visit is read-only until you
;; deliberately type  M-x allow-editing  or press  C-c e e  (C-c e l  or
;; M-x stop-editing  locks it again).
;; This also covers files that do not exist yet: allow editing to create them.
;;
;; The hook runs last (depth 90) so nothing else, such as version control, can make
;; the buffer writable again.  Emacs's own writers still work: `customize' saves
;; with `inhibit-read-only', and package/recentf/savehist write through temporary
;; buffers rather than visited files.
;; The exceptions: the message files Git asks you to write (a commit message, a merge message,
;; a tag, the rebase list), which Magit opens for you: locking them would make committing
;; impossible, and they only exist because you asked to commit.  And the file Treemacs uses to
;; remember its projects, which the program itself writes.
(defvar my/always-editable-file-regexp
  (concat "/\\.git/\\(?:.*/\\)?\\(?:COMMIT_EDITMSG\\|MERGE_MSG\\|TAG_EDITMSG\\|NOTES_EDITMSG\\|PULLREQ_EDITMSG\\|EDIT_DESCRIPTION\\|git-rebase-todo\\)\\'"
          ;; Treemacs keeps its list of projects in a small file it opens and writes itself
          "\\|/\\.cache/treemacs-persist\\(?:-at-last-error\\)?\\'")
  "Files whose buffers are left editable by the read-only lock.")

(defun my/make-file-buffer-read-only ()
  "Make the file-visiting buffer that was just opened read-only."
  (unless (and buffer-file-name (string-match-p my/always-editable-file-regexp buffer-file-name))
    (read-only-mode 1)))
(add-hook 'find-file-hook #'my/make-file-buffer-read-only 90)

(defun allow-editing ()
  "Make the current buffer editable.
Files open read-only.  This is the one deliberate way to change that;
`stop-editing' locks the buffer again."
  (interactive)
  (if (not buffer-read-only)
      (message "Already editable: %s" (buffer-name))
    (read-only-mode -1)
    (message "Editing ON for %s.  Save with C-x C-s; lock again with M-x stop-editing."
             (buffer-name))))

(defun stop-editing ()
  "Make the current buffer read-only again."
  (interactive)
  (read-only-mode 1)
  (message "Editing OFF for %s%s" (buffer-name)
           (if (and buffer-file-name (buffer-modified-p))
               " (it has UNSAVED changes; unlock and save with C-x C-s to keep them)"
             "")))

(defun my/read-only-hint ()
  "Tell how to edit.  Replaces the standard C-x C-q toggle on purpose.
A single shortcut must not be able to switch editing on, so that a mistyped
key sequence can never make a file editable."
  (interactive)
  (message "Files open read-only.  To edit, type:  C-c e e   (or M-x allow-editing)"))
(global-set-key (kbd "C-x C-q") #'my/read-only-hint)

;; Deliberate three-key chords under C-c (the prefix Emacs reserves for users), so a
;; single slipped key can never unlock a file:  C-c e e = edit,  C-c e l = lock.
(global-set-key (kbd "C-c e e") #'allow-editing)
(global-set-key (kbd "C-c e l") #'stop-editing)

;; WHAT: raise which-key's popup from its default 25% of the frame to 40%.  WHY: this is
;; a real regression fix, found by the GUI test suite, not a style tweak --- with the
;; `C-c n' (news), `C-c m' (dictation) and `C-c a c' (LLM council) bindings added this
;; session, `C-c''s own top-level binding list grew past what 25% of a normal frame can
;; show at once; confirmed for real, `my/toggle-evil' (bound to `C-c v') had scrolled out
;; of the visible, captured popup text.  HOW: 40% was measured, not guessed --- it's the
;; smallest height that comfortably shows every current `C-c' binding without cutting any
;; off; re-verified via the GUI test suite (36/36) after raising it.
(setq which-key-side-window-max-height 0.4)
;; A right-side placement (`which-key-side-window-location') was tried for a session,
;; specifically for Dired, but reverted on request --- back to the stock bottom strip.
(which-key-mode 1)                      ; shows available keys after a prefix

;;; Coding: tree-sitter + LSP (Eglot) -----------------------------------------

;; Highlight as much as tree-sitter offers. Grammars are installed on demand:
;;   M-x treesit-install-language-grammar   (needs a C compiler; we have one)
(setq treesit-font-lock-level 4)

;; Eglot is the built-in LSP client. Start it per buffer with M-x eglot,
;; or enable for a language, e.g.:
;;   (add-hook 'python-ts-mode-hook #'eglot-ensure)
(setq eglot-autoshutdown t)

;;; Packages -----------------------------------------------------------------

;; Only what we choose to use, installed into config/elpa (gitignored) by
;; `./build.sh packages' or on first use.
;;
;; package.el is deliberately NOT loaded at startup.  It loads `browse-url',
;; which searches PATH for browsers; on WSL, where PATH includes Windows
;; drives, that alone costs ~0.7 s per launch.  Installed packages are put on
;; `load-path' directly instead, and package.el is loaded only to install.
(defvar my/elpa-dir (expand-file-name "elpa" user-emacs-directory)
  "Where packages installed by this configuration live.")

;; WHY both `load-path' AND `custom-theme-load-path': `require'/`locate-library' only
;; ever consult `load-path', but `load-theme' (see the Themes section) never does ---
;; confirmed directly in `custom.el''s own source: it always does its own
;; `(locate-file (concat theme "-theme.el") (custom-theme--load-path) ...)', and the
;; `t' element `custom-theme-load-path' starts with expands to Emacs's *built-in*
;; `etc/themes' directory, never to `load-path' (a genuinely easy assumption to get
;; backwards --- the one most other packages don't need, since `require' is all they
;; use). Without this, every theme package installed below into `config/elpa' loads
;; fine as a *library* but `C-c c'/`consult-theme' still can't find its *theme file*.
(dolist (dir (file-expand-wildcards (expand-file-name "*" my/elpa-dir)))
  (when (and (file-directory-p dir)
             (not (member (file-name-nondirectory dir) '("archives" "gnupg"))))
    (add-to-list 'load-path dir)
    (add-to-list 'custom-theme-load-path dir)))

;;; Completion ------------------------------------------------------------------

;; The minibuffer completion UI and matching style: `vertico' (a vertical candidate
;; list), `orderless' (type the words of what you want in any order, not just a
;; prefix --- "ff bin" matches "bin/find-file.el"), and `marginalia' (extra info
;; alongside each candidate: a command's own doc string in `M-x', a file's size and
;; permissions in `C-x C-f', a buffer's major mode in `C-x b'). All three replace
;; the built-in `fido-vertical-mode' this config used before --- falls back to that,
;; unchanged, if they are not installed, matching how this config treats every
;; other package as optional. Installed into config/elpa by `./build.sh packages';
;; loaded eagerly here (not autoloaded like most packages in this file), since
;; minibuffer completion is used from the very first keystroke of any command ---
;; there is no later "first use" to defer loading until, the way there is for
;; Magit or Treemacs.  Placed here, right after `load-path' gets the elpa
;; directories added above (not up with the rest of the UI settings near the top
;; of this file): `locate-library'/`require' need those directories on `load-path'
;; first --- confirmed for real, this section originally sat above the `load-path'
;; loop and silently always took the fallback branch, `vertico'/etc. never found.
;; See docs/SEARCHING.md.
;;
;; `flex' (built into Emacs, matches letters in order but not contiguously, e.g.
;; "gmtry" matches "Geometry") is kept in both lists alongside `orderless' --- a
;; real regression, not a guess: the previous setup (`fido-vertical-mode''s own
;; `(basic partial-completion flex)') included it, and `C-x p f' (`project-find-
;; file', Emacs's own built-in finder, distinct from this config's `C-c f f')
;; relies on exactly this fuzzy/skeleton matching; `tests/ert/java-navigation.el's
;; own `jnav/a-partial-name-finds-the-file-by-fuzzy-matching' failed for real
;; without it, since `orderless''s own default matching styles (literal and
;; regexp only) do not reproduce that kind of match on their own.
;;
;; `file' completion is otherwise kept off `orderless' specifically: out-of-order,
;; space-separated matching is far more useful for commands and buffer names than
;; for file paths, where it can match surprising things. This config's own fast
;; finder (`C-c f f', fastfind.el) is unaffected either way --- it sets its own,
;; completely separate completion style for its one minibuffer session, which
;; takes priority over whatever the global default is.
(if (and (locate-library "vertico") (locate-library "orderless") (locate-library "marginalia"))
    (progn
      (require 'vertico)
      (require 'orderless)
      (require 'marginalia)
      (vertico-mode 1)
      (marginalia-mode 1)
      (setq completion-styles '(orderless basic flex)
            completion-category-overrides '((file (styles basic partial-completion flex)))))
  (fido-vertical-mode 1))               ; fallback: minibuffer completion, vertical list, all built in
(setq completion-ignore-case t
      read-file-name-completion-ignore-case t)
(global-completion-preview-mode 1)      ; inline suggestions as you type

;; `corfu' is the IN-BUFFER counterpart to `vertico' above: a popup of completion
;; candidates while editing code (a variable/function name, a snippet trigger, ...),
;; driven by whatever `completion-at-point-functions' the current buffer already has
;; --- Eglot sets those up per-buffer entirely on its own, confirmed directly, so this
;; needs no LSP-specific wiring here. Eager, like `vertico', not autoloaded like most
;; packages below: `global-corfu-mode' is a minor mode that has to already be active in
;; a buffer for its first completable keystroke to be caught, the same reasoning
;; `vertico-mode' above is eager for.
;; Its popup is a child frame --- on an OLDER Emacs that would need the separate
;; `corfu-terminal' package to show anything at all in a `-nw' terminal session (no
;; graphical child frames there). Confirmed directly, by watching a real completion
;; popup actually render in a real terminal session on this project's own Emacs
;; (32.0.50): it already has native tty-child-frame support, and Corfu's own source
;; detects this and warns `corfu-terminal' is not needed at all on Emacs 31+ --- so it
;; is deliberately not installed here (see tools/install-packages.el's own comment).
(when (locate-library "corfu")
  (require 'corfu)
  (setq corfu-auto t
        corfu-cycle t)
  (global-corfu-mode 1))

;; WHAT: install a single package on demand, straight from Lisp, rather than via
;; `./build.sh packages' (`tools/install-packages.el').  WHY: that script is how every
;; package this config actually uses gets onto disk normally --- but Evil and
;; `evil-collection' (the only callers of this function, see `my/toggle-evil' below)
;; are deliberately NOT among them, since most people running this config never turn
;; Evil on at all; this lets `C-c v' offer to install either one right there, the
;; first time it's actually asked for, instead of making everyone carry a vi-emulation
;; package they may never use.  HOW: `melpa' was added to this function's own archive
;; list specifically for `evil-collection' (confirmed directly: it is not published on
;; `gnu'/`nongnu', only `melpa' --- Evil itself ships on NonGNU ELPA and never needed
;; this before `evil-collection' became this function's second real caller).
(defun my/install-package (pkg)
  "Install PKG from ELPA into `my/elpa-dir'.  Loads package.el on demand."
  (require 'package)
  (setq package-user-dir my/elpa-dir
        package-archives '(("gnu"    . "https://elpa.gnu.org/packages/")
                           ("nongnu" . "https://elpa.nongnu.org/nongnu/")
                           ("melpa"  . "https://melpa.org/packages/")))
  (package-initialize)
  (package-refresh-contents)
  (package-install pkg))

;;; Evil (vi keybindings), off by default -------------------------------------

;; Compatibility shim.  Evil 1.15 reads `evil-mode-buffers', a variable the
;; globalized-minor-mode machinery defined in Emacs <= 31 but Emacs 32 no
;; longer does.  Without it, Evil signals (void-variable evil-mode-buffers)
;; from `post-command-hook' after commands.  Nil means "no buffer is being
;; initialized", which is the right answer outside Evil's own setup code.
;; Covered by tests/ert/evil.el; remove once Evil supports Emacs 32.
(defvar evil-mode-buffers nil
  "Compatibility shim for Evil on Emacs 32; see init.el.")

;; WHAT/WHY: user request, after asking whether `evil-collection' was worth adding ---
;; plain Evil leaves every OTHER mode's own default keys in place (Dired, Magit,
;; Treemacs, ...), which feels broken under vi emulation (e.g. `j'/`k' do not move
;; lines in Dired the vim way); `evil-collection' patches ~190 modes with proper,
;; idiomatic vi bindings instead. Deliberately NOT a separate toggle of its own ---
;; it only ever matters while Evil's own state keymaps are active, so it is
;; initialized once, right here, the first time Evil itself turns on, and needs no
;; separate "off" step: Evil's own state keymaps (what `evil-collection' adds to)
;; already stop being consulted the moment `evil-mode' turns off, same as before this
;; existed. A REAL, deliberate tradeoff worth knowing about: it WILL shadow some of
;; this session's own custom bindings (ranger's `r', Treemacs's `D'/`z'/`G', ...)
;; while Evil is on, same as it overrides any mode's own defaults, by design.
(defvar my/evil-collection-initialized nil
  "Whether `evil-collection-init' has already run this session; see `my/toggle-evil'.")

(defun my/toggle-evil ()
  "Toggle Evil (vi emulation) globally.
Evil (and `evil-collection', the first time Evil turns on) is loaded on first use,
so it costs nothing until then.  If either is not installed, offer to install it."
  (interactive)
  (unless (require 'evil nil t)
    (if (y-or-n-p "Evil (vi keys) is not installed.  Install from NonGNU ELPA? ")
        (progn (my/install-package 'evil)
               (require 'evil))
      (user-error "Evil is not installed")))
  (when (not evil-mode) ; about to turn ON
    (unless (require 'evil-collection nil t)
      (when (y-or-n-p "evil-collection (proper vi keys in Dired/Magit/Treemacs/...) is not installed.  Install from MELPA? ")
        (my/install-package 'evil-collection)
        (require 'evil-collection)))
    (when (and (featurep 'evil-collection) (not my/evil-collection-initialized))
      (evil-collection-init)
      (setq my/evil-collection-initialized t)))
  (evil-mode (if evil-mode -1 1))
  (message "Evil mode %s" (if evil-mode "enabled" "disabled")))

;;; Languages: tree-sitter grammars and language servers ----------------------

;; Grammar versions are pinned to ones built with parser ABI 14 or lower, which is
;; the most the tree-sitter library on this machine (0.20.x) can load.  Install
;; them with `./build.sh grammars' or `M-x treesit-install-language-grammar'.
(setq treesit-language-source-alist
      '((java "https://github.com/tree-sitter/tree-sitter-java" "v0.23.5")
        (rust "https://github.com/tree-sitter/tree-sitter-rust" "v0.23.2")
        (html "https://github.com/tree-sitter/tree-sitter-html" "v0.23.2")
        (css "https://github.com/tree-sitter/tree-sitter-css" "v0.23.2")
        (javascript "https://github.com/tree-sitter/tree-sitter-javascript" "v0.23.1")
        (jsdoc "https://github.com/tree-sitter/tree-sitter-jsdoc" "v0.23.2")
        (typescript "https://github.com/tree-sitter/tree-sitter-typescript" "v0.23.2" "typescript/src")
        (tsx "https://github.com/tree-sitter/tree-sitter-typescript" "v0.23.2" "tsx/src")
        (json "https://github.com/tree-sitter/tree-sitter-json" "v0.23.0")))

;; Rust: Emacs 32 already opens .rs files in `rust-ts-mode' when its grammar exists.
;; Java: .java opens in the older `java-mode' unless remapped, so remap it, but only
;; when the grammar is installed (otherwise keep the working classic mode).
(when (treesit-language-available-p 'java)
  (add-to-list 'major-mode-remap-alist '(java-mode . java-ts-mode)))

;; Web/UI languages: same idea as Java.  .ts/.tsx already open in `typescript-ts-mode'/
;; `tsx-ts-mode' automatically (core Emacs has no legacy TypeScript mode to fall back to,
;; so those two fall back to plain `fundamental-mode', not highlighted, until their
;; grammar is installed); .js/.css/.html need the same explicit remap Java does, since
;; each has a working legacy mode that would otherwise stay in charge forever.  .js/.jsx
;; are remapped from `javascript-mode' (what `auto-mode-alist' actually opens them in,
;; an alias of `js-mode'), not `js-mode' itself, or the remap silently never applies.
(when (treesit-language-available-p 'javascript)
  (add-to-list 'major-mode-remap-alist '(javascript-mode . js-ts-mode)))
(when (treesit-language-available-p 'css)
  (add-to-list 'major-mode-remap-alist '(css-mode . css-ts-mode)))
(when (treesit-language-available-p 'html)
  (add-to-list 'major-mode-remap-alist '(mhtml-mode . mhtml-ts-mode)))
(when (treesit-language-available-p 'json)
  (add-to-list 'major-mode-remap-alist '(js-json-mode . json-ts-mode)))

;; Windows bundle: it carries the Java language server itself (tools\jdtls), but no JDK ---
;; Java needs one installed, the same way Rust needs rust-analyzer installed (neither is
;; bundled).  Eglot's own entry looks for a program called `jdtls' (a Python script), so
;; tell it to start the bundled jdtls with whatever `java' it finds on PATH or JAVA_HOME
;; instead.  Only used when the launcher (Emacs.exe) says where the bundle is; anywhere
;; else Eglot's normal entry applies.
(defun my/bundled-jdtls-dir ()
  (let ((home (getenv "CUSTOM_EMACS_HOME")))
    (and home (expand-file-name "tools/jdtls/" home))))

(defun my/bundled-jdtls-command (&rest _)
  "The command line that runs the bundled jdtls on your own Java (none is bundled)."
  (let* ((dir (my/bundled-jdtls-dir))
         (java (or (executable-find "java")
                   (user-error "No Java found.  Install a JDK (17+) so `java' is on PATH or JAVA_HOME, then try M-x eglot again")))
         (jar (car (file-expand-wildcards (expand-file-name "plugins/org.eclipse.equinox.launcher_*.jar" dir))))
         (root (file-name-as-directory
                (expand-file-name (or (and (fboundp 'project-current) (when-let* ((pr (project-current)))
                                                                     (project-root pr)))
                                      default-directory))))
         ;; one workspace folder per project, kept with the settings (it must be writable)
         (data (expand-file-name (concat "jdtls-workspaces/" (md5 root)) user-emacs-directory)))
    (list java
          "-Declipse.application=org.eclipse.jdt.ls.core.id1"
          "-Dosgi.bundles.defaultStartLevel=4"
          "-Declipse.product=org.eclipse.jdt.ls.core.product"
          "-Xmx1G" "--add-modules=ALL-SYSTEM"
          "--add-opens" "java.base/java.util=ALL-UNNAMED"
          "--add-opens" "java.base/java.lang=ALL-UNNAMED"
          "-jar" jar
          "-configuration" (expand-file-name "config_win" dir)
          "-data" data)))

(when (and (eq system-type 'windows-nt) (my/bundled-jdtls-dir) (file-directory-p (my/bundled-jdtls-dir)))
  (with-eval-after-load 'eglot
    (add-to-list 'eglot-server-programs '((java-mode java-ts-mode) . my/bundled-jdtls-command))))

;; Language servers (rust-analyzer, jdtls) are started by hand with M-x eglot and
;; never automatically: a JVM-based server takes seconds and a large amount of
;; memory, and most editing does not need it.  Skip logging every protocol message.
(setq eglot-events-buffer-config '(:size 0))

;;; Clicking through code -------------------------------------------------------

;; Right-click a symbol in code for "Find Definition" and "Find References" (Emacs
;; adds these to the context menu only when `context-menu-mode' is on).
(context-menu-mode 1)

;; Ctrl+Click on a symbol jumps to its definition, as in VS Code, IntelliJ and Eclipse
;; (Emacs 31 and newer).
(when (fboundp 'global-xref-mouse-mode)
  (global-xref-mouse-mode 1))

;; When a language server (Eglot) manages the buffer, also offer implementations and
;; the type definition there.  Emacs has no default mouse route to them.
(defun my/eglot-find-implementation-at-mouse (event)
  "Show the implementations of the symbol clicked with EVENT."
  (interactive "e")
  (mouse-set-point event)
  (call-interactively #'eglot-find-implementation))

(defun my/eglot-find-type-definition-at-mouse (event)
  "Go to the type definition of the symbol clicked with EVENT."
  (interactive "e")
  (mouse-set-point event)
  (call-interactively #'eglot-find-type-definition))

(defun my/context-menu-eglot (menu click)
  "Add Eglot-only navigation items to the right-click MENU for CLICK."
  (when (and (featurep 'eglot) (eglot-managed-p)
             (save-excursion
               (mouse-set-point click)
               (thing-at-point 'symbol)))
    (define-key-after menu [my-find-impl]
      '(menu-item "Find Implementations" my/eglot-find-implementation-at-mouse
                  :help "Show the classes that implement this interface or method")
      'xref-find-def)
    (define-key-after menu [my-find-type]
      '(menu-item "Find Type Definition" my/eglot-find-type-definition-at-mouse
                  :help "Go to the type of this symbol")
      'my-find-impl))
  menu)
(add-hook 'context-menu-functions #'my/context-menu-eglot 20)

;; Text search across a project (C-x p g) is 4 to 10 times faster with ripgrep than with
;; grep (measured on the 5,629 files of the Emacs source: 56-63 ms against 226-670 ms,
;; same matches).  Applied when xref loads, so it costs nothing at startup; falls back to
;; grep on a machine without rg.
(with-eval-after-load 'xref
  (setq xref-search-program (if (executable-find "rg") 'ripgrep 'grep)))

;; jdtls, for a folder with no build file (no pom.xml or build.gradle), guesses the
;; source root wrongly (it warns "declared package does not match expected package")
;; and then finds no references to classes.  Tell it where the sources are.  Projects
;; with a build file ignore this.  Covers src/main/java/... and src/...
(setq-default eglot-workspace-configuration
              '(:java (:project (:sourcePaths ["src/main/java" "src"]))))

;; After a chord such as C-x o, keep pressing the last letter to repeat it (o, O for
;; other-window, u for undo, n/p for next/previous-error).  M-x repeat-mode to toggle.
(repeat-mode 1)

;;; Fast file finding ------------------------------------------------------------

;; Type a few letters of a file name and get the best matches at once, from an index of
;; the project or of the whole disk (matched with ripgrep), with a live search when the
;; index has nothing.  See fastfind.el and docs/NAVIGATING-CODE.md.
;;   C-c f f  project file (anywhere, outside a project)   C-c f g  anywhere on the disk
;;   C-c f d  the current directory only, recursively (ignores project and disk scope)
;;   C-c f a  anywhere on the disk, asynchronously (Consult/fd, never blocks)
;;   C-c f r  rebuild the whole-disk index now
;; Autoloaded by full path: putting `user-emacs-directory' itself on `load-path' makes
;; Emacs print a startup warning.
(defconst my/ff-library (expand-file-name "fastfind" user-emacs-directory))
(autoload 'my/ff-find-file my/ff-library "Find a file in the current project." t)
(autoload 'my/ff-find-file-here my/ff-library "Find a file under the current directory only." t)
(autoload 'my/ff-find-file-global my/ff-library "Find a file anywhere on the disk." t)
(autoload 'my/ff-find-file-global-async my/ff-library
  "Find a file anywhere on the disk, asynchronously (Consult/fd)." t)
(autoload 'my/ff-reindex my/ff-library "Rebuild the whole-disk file index." t)
(autoload 'my/ff-status my/ff-library "Show the state of the file indexes." t)

;; The whole-disk index is built in the background, once, after Emacs has been idle for
;; 90 seconds, and again when it is over 6 hours old.  Nothing runs at startup.  Set this
;; to nil to build it only when you press C-c f r.
(defvar my/ff-auto-refresh t)
(when my/ff-auto-refresh
  (run-with-idle-timer 90 nil (lambda () (require 'fastfind my/ff-library) (my/ff-maybe-refresh))))

;;; Treemacs: a file tree in a sidebar ------------------------------------------------

;; `C-c t' shows the file tree of the project you are in (and hides it if it is showing);
;; `C-c T' also moves to the current file in it.  Treemacs's own `treemacs' command asks for a
;; folder the first time; these find the project by themselves.  Installed into config/elpa by
;; `./build.sh packages'; nothing loads until first use, so it costs nothing at startup.
;; See docs/TREEMACS.md.
(defun my/treemacs ()
  "Show the file tree of the current project, or hide it if it is already showing."
  (interactive)
  (require 'treemacs)
  (cond
   ((eq (treemacs-current-visibility) 'visible) (treemacs))         ; hide
   ((treemacs-workspace->is-empty?)
    ;; the first time: use this buffer's project, or else its folder, so there is no prompt
    (let ((root (or (treemacs--find-current-user-project) default-directory)))
      (treemacs-do-add-project-to-workspace (treemacs-canonical-path root)
                                            (file-name-nondirectory (directory-file-name root)))
      (treemacs-select-window)))
   (t (treemacs))))

(defun my/treemacs-reveal ()
  "Show the file tree and move into it, on the file of this buffer --- or, in a
Dired/ranger buffer (which visits no file, just a directory), on that directory.
A real, found-while-wiring-up-ranger-cross-navigation gap: `treemacs-find-file'
(Treemacs's own command this wraps) only ever looks at `(buffer-file-name
(current-buffer))' --- confirmed directly in its own source --- which is always nil
in a directory-listing buffer, so calling this from Dired or `ranger' used to fall
straight into Treemacs's OWN interactive \"File to find: \" prompt instead of just
going there. Fixed by feeding it the right path directly: `cl-letf' temporarily
makes `buffer-file-name' return this buffer's `default-directory' (properly run
through `treemacs-canonical-path' first --- confirmed the hard way that skipping
this, a bare `default-directory''s own trailing slash, makes Treemacs's own project
lookup fail to match the very project it just added seconds earlier) only for the
duration of this one call, for a buffer that actually visits a file this changes
nothing at all, since `buffer-file-name' already returns that same path either way."
  (interactive)
  (require 'treemacs)
  ;; first time: add this buffer's project (without leaving this window, since
  ;; `treemacs-find-file' reads the file from the current buffer)
  (when (treemacs-workspace->is-empty?) (save-selected-window (my/treemacs)))
  (let* ((dir (treemacs-canonical-path default-directory))
         (real-buffer-file-name (symbol-function 'buffer-file-name)))
    (cl-letf (((symbol-function 'buffer-file-name)
               (lambda (&optional buf) (or (funcall real-buffer-file-name buf) dir))))
      (treemacs-find-file)))     ; marks this file/directory in the tree, showing it if hidden
  (treemacs-select-window))

(with-eval-after-load 'treemacs
  ;; Many Treemacs commands (delete, create, rename, the follow modes...) are only autoload stubs in its
  ;; autoloads file, which this config does not load at startup.  Load it now that Treemacs is in use.
  (when-let* ((f (locate-library "treemacs-autoloads"))) (load f nil t))
  (treemacs-follow-mode 1)            ; keep the current file highlighted in the tree
  (treemacs-project-follow-mode 1))   ; show the project of the buffer you move to

(defun my/treemacs-missing ()
  (interactive)
  (message "Treemacs is not installed.  Run ./build.sh packages"))
(global-set-key (kbd "C-c t") (if (locate-library "treemacs") #'my/treemacs #'my/treemacs-missing))
(global-set-key (kbd "C-c T") (if (locate-library "treemacs") #'my/treemacs-reveal #'my/treemacs-missing))

;; User request: complete the cross-navigation matrix the other way too --- from
;; Treemacs, jump to the directory at point (the file's own directory, if point is on
;; a file) in plain Dired or `ranger'.  `treemacs-current-button'/`treemacs--nearest-
;; path' are Treemacs's own real, public functions for "the path at point" (confirmed
;; directly: the exact same pair `treemacs-find-file''s own manual-entry fallback
;; uses) --- not reimplemented here. Window selection mirrors `treemacs-visit-node-no-
;; split''s own documented approach (`next-window', the window next to treemacs) ---
;; deliberately NOT one of Treemacs's own `:dir-action' button-action variants
;; (`treemacs-visit-node-no-split' etc.): those are for VISITING a file/directory the
;; normal way, whereas this always wants a directory BROWSER there, whether point is
;; on a file or a folder.
(defun my/treemacs--dir-at-point ()
  "The directory `D'/`z'/`G' (below) should open: the directory at point in the tree,
or the containing directory of the file at point --- always WITH a trailing slash
(`file-name-as-directory'). A real, found-while-testing-this bug without it: `ranger'
(confirmed directly in its own source, `ranger''s entry function) treats a path with
no trailing slash as a FILE path and opens its PARENT directory instead --- so
`my/treemacs-to-ranger' on a directory at point silently opened one level too high."
  (let ((path (treemacs--nearest-path (treemacs-current-button))))
    (file-name-as-directory (if (file-directory-p path) path (file-name-directory path)))))
(defun my/treemacs-to-dired ()
  "Open the directory at point, in the window next to Treemacs, in plain Dired."
  (interactive)
  (let ((dir (my/treemacs--dir-at-point)))
    (select-window (next-window))
    (dired dir)))
(defun my/treemacs-to-ranger ()
  "Open the directory at point, in the window next to Treemacs, in `ranger'."
  (interactive)
  (let ((dir (my/treemacs--dir-at-point)))
    (select-window (next-window))
    (ranger dir)))
(defun my/treemacs-to-magit ()
  "Open Magit status for the repository the directory at point belongs to.
A real, found-while-testing-this gotcha: `magit-status' called WITH an explicit
DIRECTORY argument (confirmed directly in its own source) requires that directory to
already BE a repository's own toplevel --- given any other subdirectory of an
existing repository instead (the likely case here: point is rarely on a project's
exact root), it asks to create a SEPARATE, NESTED repository there instead of just
showing the enclosing one's status. Calling it with NO argument instead, the same
way `C-x g' itself does, makes it fall back to its own `default-directory'-based
`magit-toplevel' search --- the correct, enclosing-repository behavior --- so this
only `let'-binds `default-directory' rather than passing the path as an argument."
  (interactive)
  (let ((default-directory (my/treemacs--dir-at-point)))
    (call-interactively #'magit-status)))
(with-eval-after-load 'treemacs
  (define-key treemacs-mode-map "D" #'my/treemacs-to-dired)
  (when (locate-library "ranger") (define-key treemacs-mode-map "z" #'my/treemacs-to-ranger))
  (when (locate-library "magit") (define-key treemacs-mode-map "G" #'my/treemacs-to-magit)))

;;; Consult: search built on the completion list -----------------------------------

;; A handful of `consult' commands, each a fast search over one kind of thing: `C-c s l'
;; this buffer, `C-c s g' text across the project (ripgrep), `C-c s f' files by
;; name across the project (fd), `C-c s b' buffers, recent files and bookmarks in one list.
;; For `C-c s l'/`s g'/`s b' (content/location searches), moving to a candidate shows it
;; at once in the window (the preview); `RET' or click stays there, `C-g' returns to where
;; you were.  `C-c s f' is the one exception: Consult's own `consult-fd' wires up no
;; preview at all (confirmed in its source, `consult--find' vs. `consult--grep') --- a
;; filename-only match has no location within the file to jump to and preview, unlike the
;; others here.  Installed into config/elpa by `./build.sh packages'; nothing loads until
;; first use.  Needs `rg' and `fd' for the fastest results; without them
;; `consult-ripgrep'/`consult-fd' fall back to slower built-in tools.
;; See docs/SEARCHING.md and docs/SEARCH-OPTIONS.md.
(when (locate-library "consult")
  (autoload 'consult-line "consult" "Search this buffer, with a live preview." t)
  (autoload 'consult-ripgrep "consult" "Search project text with ripgrep, with a live preview." t)
  (autoload 'consult-fd "consult" "Find a project file by name with fd (no live preview, unlike the others)." t)
  (autoload 'consult-buffer "consult" "Switch to a buffer, recent file or bookmark." t)
  (autoload 'consult-theme "consult" "Fuzzy-search any installed theme by name, with a live preview." t))
(defun my/consult-missing ()
  (interactive)
  (message "Consult is not installed.  Run ./build.sh packages"))
(dolist (binding '(("C-c s l" . consult-line) ("C-c s g" . consult-ripgrep)
                   ("C-c s f" . consult-fd) ("C-c s b" . consult-buffer)))
  (global-set-key (kbd (car binding))
                  (if (locate-library "consult") (cdr binding) #'my/consult-missing)))

;;; Contextual actions, at point or on a candidate (embark) -----------------------

;; `C-.' shows a menu of actions for whatever is at point, or the current candidate
;; in an active minibuffer completion session (a file, a buffer, a package, a line
;; of a `grep'-like search, ...) --- open it, but also copy its name, delete it,
;; run a shell command on it, and more, all without leaving where you are first.
;; `C-;' skips the menu and runs the single most likely action directly. `C-h B'
;; shows every action available right now, as its own `which-key'-style menu.
;; `embark-consult' (config/elpa's own separate, tiny package) needs no wiring here
;; at all: Embark loads it automatically, on its own, once it notices Consult is
;; also loaded --- this is what makes `C-.' understand a `consult-ripgrep'/`consult-
;; buffer' candidate specifically (act on one search match without jumping to it
;; first), not just a generic minibuffer string. Installed into config/elpa by
;; `./build.sh packages'; nothing loads until first use. See docs/SEARCHING.md.
(when (locate-library "embark")
  (autoload 'embark-act "embark" "Choose an action for the thing at point, or the current minibuffer candidate." t)
  (autoload 'embark-dwim "embark" "Run the default action for the thing at point." t)
  (autoload 'embark-bindings "embark" "Show every action available right now." t))
(defun my/embark-missing ()
  (interactive)
  (message "Embark is not installed.  Run ./build.sh packages"))
(dolist (binding '(("C-." . embark-act) ("C-;" . embark-dwim) ("C-h B" . embark-bindings)))
  (global-set-key (kbd (car binding))
                  (if (locate-library "embark") (cdr binding) #'my/embark-missing)))

;;; Small navigation/search extras: avy, ace-window, wgrep, helpful, symbol-overlay ----

;; `avy' and `ace-window' were already on disk before this (pulled in as dependencies of
;; Treemacs), just never bound to a key --- `C-'' now jumps the cursor to any visible
;; spot by typing a few characters of it (stops as soon as what you typed is
;; unambiguous, or shows a letter to pick from when it isn't); `M-o' replaces the plain
;; `other-window' (cycle blindly through however many windows exist) with jumping
;; straight to one by a letter shown in it --- with only 2 windows open (the common
;; case), `ace-window' behaves exactly like `other-window' did, so nothing is lost. A
;; real, found-while-wiring-this-up conflict: `M-o' was already separately bound to
;; plain `other-window' in this file's own "Keys" section (a pre-existing, deliberate
;; shortcut from earlier work, unrelated to this change) --- since that section runs
;; *after* this one, it was silently winning and this binding never took effect on the
;; first attempt. Removed that older, now-redundant line rather than picking a
;; different key for this, since `ace-window' is a strict superset of what it did.
(when (locate-library "avy")
  (autoload 'avy-goto-char-timer "avy" "Jump to a visible spot by typing its first few characters." t))
(defun my/avy-missing ()
  (interactive)
  (message "avy is not installed.  Run ./build.sh packages"))
(global-set-key (kbd "C-'") (if (locate-library "avy") #'avy-goto-char-timer #'my/avy-missing))
(when (locate-library "ace-window")
  (autoload 'ace-window "ace-window" "Jump to a window by the letter shown in it." t))
(global-set-key (kbd "M-o") (if (locate-library "ace-window") #'ace-window #'other-window))

;; `wgrep' makes a `grep'-shaped results buffer (`M-x rgrep', or one `embark-export'
;; builds from a `consult-ripgrep'/`C-x p g' search) directly editable: fix something
;; across every matched file at once, `C-c C-p' to start editing, `C-c C-e' to save it
;; back to all of them, `C-c C-k' to discard.  WHY `with-eval-after-load' rather than a
;; plain `require': `wgrep' only ever needs to exist by the time a real `grep'-mode
;; buffer is first created, which needs `grep.el' itself loaded anyway --- piggybacking
;; on that means this never costs anything until a real search actually happens, the
;; same "nothing loads until used" rule every other feature here follows.  HOW: `wgrep'
;; wires itself into `grep-mode' entirely on its own, via `grep-setup-hook' (confirmed
;; directly in its own source, not assumed) --- once required, nothing more to bind by
;; hand.
(when (locate-library "wgrep")
  (with-eval-after-load 'grep (require 'wgrep)))
;; A real, found-while-testing-this interaction: every file this config opens locks
;; itself read-only by default (see "Every file opens read-only" below), and by default
;; `wgrep' silently REFUSES to save into a read-only buffer --- `wgrep-finish-edit' would
;; report "(0 changed)" with no further explanation, and the file on disk would just
;; never change, confirmed directly by editing a real match and finding the real file
;; untouched afterwards. `wgrep-change-readonly-file' is wgrep's own documented escape
;; hatch for exactly this (any read-only file, not just this config's own lock) --- set
;; here so it can, since running `wgrep-finish-edit' in the first place already IS the
;; one deliberate action this config's read-only lock exists to gate behind (the same
;; reasoning as the git-commit-message/Treemacs-persist exceptions in
;; `my/always-editable-file-regexp' above).
(setq wgrep-change-readonly-file t)

;; `helpful' replaces the plain `C-h f'/`v'/`k'/`o' pages with much richer ones: the
;; real source, every place that calls it, a live demo where one exists --- strictly
;; more information, same keys, so there is nothing new to learn to get it.
(when (locate-library "helpful")
  (autoload 'helpful-callable "helpful" "Describe a function, richly." t)
  (autoload 'helpful-variable "helpful" "Describe a variable, richly." t)
  (autoload 'helpful-key "helpful" "Describe a key's command, richly." t)
  (autoload 'helpful-symbol "helpful" "Describe whatever a symbol is, richly." t))
(dolist (binding '(("C-h f" . helpful-callable) ("C-h v" . helpful-variable)
                   ("C-h k" . helpful-key) ("C-h o" . helpful-symbol)))
  (when (locate-library "helpful") (global-set-key (kbd (car binding)) (cdr binding))))

;; `M-i' (`symbol-overlay-put') highlights every occurrence of whatever symbol the
;; cursor is on, right in the buffer, until pressed again --- `tab-to-tab-stop' (its
;; default binding, a legacy command from manual typewriter-style tab stops that is not
;; otherwise used here) is safely free for this, its own package's own suggested key.
(when (locate-library "symbol-overlay")
  (autoload 'symbol-overlay-put "symbol-overlay" "Highlight every occurrence of the symbol at point." t))
(global-set-key (kbd "M-i") (if (locate-library "symbol-overlay") #'symbol-overlay-put #'tab-to-tab-stop))

;; `yasnippet' expands a short trigger word into a larger template on TAB. Eager, like
;; `vertico'/`corfu' above, not autoloaded like most of this section: `yas-global-mode'
;; has to already be active in a buffer for its own TAB handling
;; (`yas-minor-mode-map') to exist there at all. Nothing to lose by turning it on
;; everywhere --- confirmed directly in its own current source (NOT the older,
;; now-`make-obsolete-variable'd `yas-fallback-behavior', an easy thing to find first
;; and assume is still how this works): TAB is bound to a `menu-item' with a `:filter'
;; (`yas-maybe-expand-abbrev-key-filter', calling `yas--templates-for-key-at-point'),
;; Emacs's own standard conditional-keybinding idiom --- when no snippet matches the
;; text before point, the filter returns nil and Emacs's own key lookup falls straight
;; through to whatever TAB is bound to elsewhere (e.g. `indent-for-tab-command'),
;; unchanged, exactly as if this keymap entry were not even there. No snippet
;; collection (e.g. `yasnippet-snippets') is installed --- this adds exactly the one
;; package that was asked for; `M-x yas-new-snippet' writes one by hand, `C-c Y' lists
;; whatever exists.
(when (locate-library "yasnippet")
  (require 'yasnippet)
  (yas-global-mode 1))
(defun my/yasnippet-missing ()
  (interactive)
  (message "Yasnippet is not installed.  Run ./build.sh packages"))
(global-set-key (kbd "C-c Y") (if (locate-library "yasnippet") #'yas-insert-snippet #'my/yasnippet-missing))

;; `expand-region' grows the selection by semantic units each time it's pressed ---
;; word, then symbol, then string/sexp, then statement, then function, and so on ---
;; and `er/contract-region' shrinks it back one step if it goes too far. Lazily
;; autoloaded, like `avy'/`ace-window' above: just two commands, no mode to enable.
;; `C-=' and `C-M--' are the package's own suggested bindings, both confirmed free in
;; stock Emacs (`key-binding' returned nil for either beforehand).
(when (locate-library "expand-region")
  (autoload 'er/expand-region "expand-region" "Expand the selection by semantic units." t)
  (autoload 'er/contract-region "expand-region" "Shrink the selection back one step." t))
(defun my/expand-region-missing ()
  (interactive)
  (message "expand-region is not installed.  Run ./build.sh packages"))
(global-set-key (kbd "C-=") (if (locate-library "expand-region") #'er/expand-region #'my/expand-region-missing))
(global-set-key (kbd "C-M--") (if (locate-library "expand-region") #'er/contract-region #'my/expand-region-missing))

;; `diff-hl' marks every changed/added/removed line against the last git commit, live,
;; in the fringe --- and in Dired, a colored marker per changed file
;; (`diff-hl-dired-mode'), fitting right alongside this session's other Dired work.
;; Eager, like the other always-on indicators above: nothing to defer loading until,
;; it has to be watching from the first buffer that gets visited.
;; `diff-hl-margin-mode' is diff-hl's own documented terminal fallback --- confirmed
;; directly in its own source (`(when (window-system) ...)' guards its fringe code):
;; the default fringe indicators do not exist at all in a `-nw' terminal session, the
;; same real gap `corfu-terminal' above exists to close for Corfu.
(when (locate-library "diff-hl")
  (require 'diff-hl)
  (global-diff-hl-mode 1)
  (add-hook 'dired-mode-hook #'diff-hl-dired-mode)
  (unless (display-graphic-p)
    (require 'diff-hl-margin)
    (diff-hl-margin-mode 1)))

;; `vterm' is a real terminal emulator in a buffer (full curses app support --- htop,
;; vim, an ssh session --- unlike the built-in `shell'/`term', which only handle plain
;; line-based programs). Its one real cost: a native module (`vterm-module.so')
;; compiled from C at first real use, via `cmake' --- confirmed directly in its own
;; `CMakeLists.txt': it looks for a system `libvterm' first and, since none is
;; installed on this machine, downloads and builds its own copy automatically, so
;; nothing extra had to be installed by hand for this one (contrast `pdf-tools' below).
;; `C-c V' opens one in the current directory --- `C-c v' is already `my/toggle-evil'
;; here, the same lower/upper-case pairing this file already uses for unrelated-but-
;; similar features (`C-c m'/`C-c M', dictation/live dictation).
(when (locate-library "vterm")
  (autoload 'vterm "vterm" "Open a real terminal emulator in a new buffer." t))
(defun my/vterm-missing ()
  (interactive)
  (message "vterm is not installed (or still building its native module).  Run ./build.sh packages"))
(global-set-key (kbd "C-c V") (if (locate-library "vterm") #'vterm #'my/vterm-missing))

;; `pdf-tools' replaces the built-in `doc-view-mode' (a PDF shown only as a stack of
;; pre-rendered page IMAGES) with real searchable/selectable text and much faster
;; rendering. Like `vterm' above, it needs a native helper program (`epdfinfo', built
;; from C) --- but unlike `vterm', that build needs a real SYSTEM library's development
;; headers (`poppler-glib'), confirmed NOT present on this machine (`pkg-config --exists
;; poppler-glib' fails), and genuinely not something this build process can fetch on
;; its own the way `vterm' fetches `libvterm': it needs a real `apt-get install
;; libpoppler-glib-dev', which needs a password this process does not have.
;; `pdf-loader-install' is `pdf-tools''s own documented lazy entry point --- it builds
;; `epdfinfo' the FIRST time a real PDF is opened, not at package-install time, and
;; (passing NO-ERROR-P) fails silently rather than signaling an error if that build
;; fails.  Still gated here, the same way `magit-delta' above is gated on the external
;; `delta' binary existing: checked once at startup, so until that one system package
;; is installed by hand, nothing about how `.pdf' files already opened changes ---
;; `pdf-loader-install' is never even called while the dependency is missing, so
;; whatever handled `.pdf' files before this (`doc-view-mode-maybe' in a GUI frame with
;; `gs'/`pdftoppm' installed; a real, found-while-testing-this fact: it falls back to
;; plain `fundamental-mode' in a `-nw' terminal session regardless, since its own
;; `doc-view-mode-p' requires `(display-graphic-p)') still does, unchanged. Once that
;; one `apt-get install' is run and Emacs restarted, this picks it up with no other
;; change needed.
(when (and (locate-library "pdf-tools")
           (executable-find "pkg-config")
           (zerop (call-process "pkg-config" nil nil nil "--exists" "poppler-glib")))
  (require 'pdf-loader)
  (pdf-loader-install t nil t))

;; `docker'/`kubernetes': the same Magit-style transient-popup idea Magit itself uses,
;; applied to containers/images/volumes/networks (`docker') or a Kubernetes cluster
;; (`kubernetes') instead of git --- user request, after asking what exists in this
;; family. Grouped under one `C-c K' prefix (rather than hunting for two separate free
;; top-level letters: `D' is already `my/treemacs-reveal', `k' is already `my/
;; shortcuts') the same way `C-c f'/`C-c w'/`C-c e' already group several related
;; commands under one letter. `docker' itself (the `transient-define-prefix' in
;; `docker-core.el', confirmed directly) is the one entry point for everything ---
;; containers/images/volumes/networks/contexts are all reachable from its own menu,
;; the same way `magit-status' is the one entry point into Magit; `kubernetes-overview'
;; is `kubernetes''s own equivalent, a dedicated buffer rather than a transient menu.
;; Both need a real `docker'/`kubectl' binary on PATH to do anything once opened ---
;; not checked here, the same way `magit-status' does not check for a `git' binary
;; either; opening the menu with neither installed just means every action inside it
;; fails when actually run, same as Magit would.
;; A real, found-by-testing fact specific to THIS config, not these packages: `load-
;; path' only ever gets each `config/elpa/<pkg>' directory added directly (above, right
;; after it is computed) --- `package.el' itself is used only to DOWNLOAD packages
;; (`tools/install-packages.el'), never to ACTIVATE them, so none of their own
;; `-autoloads.el' files (which would otherwise register `docker'/`kubernetes-overview'
;; and dockerfile-mode's `auto-mode-alist' entries automatically) are ever loaded ---
;; confirmed directly, the hard way: both were `fboundp' nil even right after startup
;; until given their own explicit `autoload' calls here, same as every other optional
;; package in this file (`magit-status', `vterm', ...).
(when (locate-library "docker")
  (autoload 'docker "docker-core" "A transient menu of Docker containers/images/volumes/networks." t))
(when (locate-library "kubernetes")
  (autoload 'kubernetes-overview "kubernetes-overview" "A buffer listing a Kubernetes cluster's resources." t))
(defun my/docker-missing ()
  (interactive)
  (message "docker.el is not installed.  Run ./build.sh packages"))
(defun my/kubernetes-missing ()
  (interactive)
  (message "kubernetes.el is not installed.  Run ./build.sh packages"))
(global-set-key (kbd "C-c K d") (if (locate-library "docker") #'docker #'my/docker-missing))
(global-set-key (kbd "C-c K k") (if (locate-library "kubernetes") #'kubernetes-overview #'my/kubernetes-missing))

;; `dockerfile-mode': the same explicit-activation gap as above, for a plain major mode
;; instead of a command --- its own `auto-mode-alist' entries (`Dockerfile'/
;; `Containerfile', any extension, plus bare `*.dockerfile') are registered by its own
;; `-autoloads.el', which (see above) never loads here, so without this this project's
;; own `Dockerfile' would keep opening in plain `fundamental-mode' even with the
;; package installed. Mirrors the package's own two `auto-mode-alist' entries exactly
;; (`dockerfile-mode.el', confirmed directly) rather than guessing a simpler regexp.
(when (locate-library "dockerfile-mode")
  (autoload 'dockerfile-mode "dockerfile-mode" "Major mode for editing Dockerfiles." t)
  (add-to-list 'auto-mode-alist '("[/\\]\\(?:Containerfile\\|Dockerfile\\)\\(?:\\.[^/\\]*\\)?\\'" . dockerfile-mode))
  (add-to-list 'auto-mode-alist '("\\.dockerfile\\'" . dockerfile-mode)))

;; `multiple-cursors': edit several places at once (same pattern, different
;; locations) --- user request, chosen from a short menu of editing-enhancement
;; candidates. `C->'/`C-<'/`C-c C-<' are the package's own long-standing, widely
;; documented convention (its README uses exactly these), used as-is rather than
;; invented fresh, so existing muscle memory/tutorials elsewhere still apply.
(when (locate-library "multiple-cursors")
  (autoload 'mc/mark-next-like-this "mc-mark-more" nil t)
  (autoload 'mc/mark-previous-like-this "mc-mark-more" nil t)
  (autoload 'mc/mark-all-like-this "mc-mark-more" nil t))
(defun my/multiple-cursors-missing ()
  (interactive)
  (message "multiple-cursors is not installed.  Run ./build.sh packages"))
(global-set-key (kbd "C->") (if (locate-library "multiple-cursors") #'mc/mark-next-like-this #'my/multiple-cursors-missing))
(global-set-key (kbd "C-<") (if (locate-library "multiple-cursors") #'mc/mark-previous-like-this #'my/multiple-cursors-missing))
(global-set-key (kbd "C-c C-<") (if (locate-library "multiple-cursors") #'mc/mark-all-like-this #'my/multiple-cursors-missing))

;; `verb': a real HTTP client inside Emacs --- write and send requests from a plain
;; Org buffer, read the response inline. User's own words: "postman in eMacs."
;; `verb-command-map' (confirmed directly in `verb.el''s own docstring: "Bind this to
;; an easy-to-reach key in Org mode in order to use Verb comfortably") is deliberately
;; left unbound by the package itself, unlike `docker'/`kubernetes' above --- so unlike
;; those, this needs a prefix key chosen here, not just an autoload. Scoped to
;; `org-mode-map' only (verb extends Org, confirmed in `verb.el''s own `(require
;; 'org)'), not global --- confirmed `C-c C-h' is free there (`C-c C-r' already is
;; `org-fold-reveal', the obvious first guess).
;; `(autoload 'verb-command-map "verb" nil nil 'keymap)' was tried first and does NOT
;; work --- confirmed directly, a real `void-variable' error: unlike a function
;; autoload, TYPE='keymap' here does not make Emacs load the file when the variable's
;; VALUE is read; that mechanism only exists for the real `;;;###autoload (defvar
;; ...)' cookie package.el itself expands at install time (which, per the gap
;; documented above, never runs in this config). A plain `require' here is the
;; correct fix --- still only loads `verb' once, the first time `org' itself does
;; (never at bare startup), not any earlier.
(when (locate-library "verb")
  (with-eval-after-load 'org
    (require 'verb)
    (define-key org-mode-map (kbd "C-c C-h") verb-command-map)))

;; `devdocs': offline copies of real language/library documentation (each doc set
;; downloaded on first use with `devdocs-install', not bundled here) --- the same menu
;; `multiple-cursors'/`verb' above came from. `C-h D' alongside the existing `C-h f'/
;; `v'/`k'/`o' (`helpful-*') and `C-h B' (`embark-bindings') in the "Help" topic.
(when (locate-library "devdocs")
  (autoload 'devdocs-lookup "devdocs" "Look up a documentation entry." t))
(defun my/devdocs-missing ()
  (interactive)
  (message "devdocs is not installed.  Run ./build.sh packages"))
(global-set-key (kbd "C-h D") (if (locate-library "devdocs") #'devdocs-lookup #'my/devdocs-missing))

;; `ranger' is a real ranger-style file manager (Miller columns: parent directory,
;; current listing, and a live preview of whatever file the cursor is on). User
;; request, explicit: keep plain Dired (and everything already built on it this
;; session --- Casual's `C-o' menu, the always-visible reference panel, `diff-hl-
;; dired-mode') completely as-is, and add this as a genuinely SEPARATE thing to opt
;; into, not a replacement.
;; `dirvish' (a newer, more popular alternative) was tried FIRST and abandoned for
;; this specific requirement --- a real, found-the-hard-way architectural fact, not a
;; preference: Dirvish's own session tracking (the `:dv' buffer prop everything else
;; keys off, confirmed directly by tracing its source) is only ever set by advice on
;; `dired-noselect' that `dirvish-override-dired-mode' installs --- meaning Dirvish's
;; own standalone `dirvish' command does genuinely nothing (confirmed directly: calling
;; it produced a perfectly plain Dired buffer, no Miller columns at all) unless that
;; GLOBAL override mode is also turned on, which would then apply to plain `dired'/
;; `C-x d'/`dired-jump' too --- the exact opposite of "separate, not mingled."
;; `ranger-mode' has no such requirement: confirmed directly in its own source, it is
;; a real, self-contained `(define-derived-mode ranger-mode dired-mode ...)', and its
;; own `ranger' entry command (bound below) needs no global mode turned on anywhere to
;; build its Miller-columns layout --- verified for real in a terminal session, not
;; assumed. `ranger-override-dired' (the equivalent all-dired-becomes-ranger option)
;; defaults to nil and is deliberately left that way here.
;; Because `ranger-mode' is still *derived from* `dired-mode', `dired-mode-hook' does
;; still fire for it (so `diff-hl-dired-mode' above still activates there too, harmless
;; --- just margin markers); the one real exception, confirmed directly in a real
;; terminal session, is the reference panel, which claimed the exact side-window slot
;; `ranger''s OWN preview pane needs, visibly breaking its layout --- `my/mode-
;; reference--relevant-mode' (mode-reference.el) now excludes `ranger-mode' first, so
;; this stays genuinely separate the way it was asked to be.
;; A real, found-the-hard-way second mingling risk, beyond the reference-panel one
;; above: `ranger.el' has a TOP-LEVEL `(when ranger-key (add-hook 'dired-mode-hook
;; (lambda () (define-key dired-mode-map ranger-key 'deer-from-dired))))' --- confirmed
;; directly: `ranger-key' defaults to `C-p', which is `previous-line' everywhere else,
;; so the first real Dired buffer opened after this form runs silently breaks `C-p' in
;; `dired-mode-map' --- the SHARED, GLOBAL keymap every Dired buffer uses, plain or
;; not. A plain, early `(setq ranger-key nil)' was tried first and was NOT enough ---
;; a real, surprising fact confirmed the hard way, by opening a directory straight
;; from the command line and watching it error: that exact top-level form is tagged
;; `;;;###autoload', so it lives and runs from `ranger-autoloads.el', not `ranger.el'
;; itself (confirmed directly: `(featurep 'ranger)' was nil when the error happened,
;; `(featurep 'ranger-autoloads)' was t) --- something (not traced down to a single
;; cause; possibly this build's own async native-compilation queue, which runs
;; packages' code in a separate process to compile them) triggers that autoloads file
;; to load in a way this file's own startup-time `setq' cannot reliably race against.
;; Fixed at the one point that IS guaranteed to run right after, regardless of what
;; triggered the load or when: `with-eval-after-load' on `ranger-autoloads' itself,
;; undoing the hook the instant it finishes loading, before any real Dired buffer gets
;; the chance to run it.
(setq ranger-key nil)
(with-eval-after-load 'ranger-autoloads
  (remove-hook 'dired-mode-hook 'ranger-set-dired-key)
  (setq ranger-key nil))
;; User request, after actually seeing it: the DEFAULT 3-pane widths (confirmed
;; directly in `ranger.el''s own defcustoms) are `ranger-width-parents' 0.12 and
;; `ranger-width-preview' 0.65 --- parent 12%, middle (the pane you're actually
;; reading/navigating) only 23%, preview a full 65%, leaving the middle pane crammed
;; into the left third of the frame instead of sitting anywhere near its center.
;; A first rebalance (15/35/50) widened the middle pane but, confirmed directly with
;; a real screenshot, still left its own midpoint at ~32% of the frame, not the true
;; 50% center --- giving the preview pane the single biggest share necessarily pushes
;; everything else left of center, however the middle pane's own width is tuned.
;; 25/50/25 is the one ratio that puts the middle pane's own midpoint EXACTLY at the
;; frame's true center (`0.25 + 0.50/2 = 0.5'), at the real cost of a visibly smaller
;; preview pane than ranger's own default convention favors --- the user's own
;; explicit choice, offered directly as the tradeoff it is, not assumed.
(setq ranger-width-parents 0.25
      ranger-width-preview 0.25)
(when (locate-library "ranger")
  (autoload 'ranger "ranger" "Open a ranger-style file manager (Miller columns, a live preview pane)." t))
(defun my/ranger-missing ()
  (interactive)
  (message "ranger is not installed.  Run ./build.sh packages"))
(global-set-key (kbd "C-c R") (if (locate-library "ranger") #'ranger #'my/ranger-missing))

;; User request: jump between plain Dired and `ranger' without losing the directory
;; you're currently in, in both directions --- `r' in each (local to that one mode's
;; own keymap, never the shared global one, so this can't repeat the earlier `C-p'
;; mistake). Dired -> ranger is one line, since `ranger' itself needs no global mode
;; to work (see the big comment above); ranger -> Dired reuses `ranger-to-dired', a
;; real function already in `ranger.el' (confirmed directly in its source) that swaps
;; the CURRENT buffer back to plain `dired-mode' in place, at the same directory ---
;; it was simply never bound to a key here, since its own suggested binding is the
;; same `ranger-key' this config deliberately leaves nil.
(defun my/dired-to-ranger ()
  "Open `ranger' on this Dired buffer's own directory."
  (interactive)
  (ranger default-directory))
(defun my/ranger-to-dired ()
  "Switch back to plain Dired, on the same directory --- a real, found-live fact
about `ranger-to-dired' (the real function this wraps, confirmed directly in its own
docstring): it deliberately leaves ranger's OTHER panes (the parent directory, the
preview) open, meant for toggling ranger's visual style while staying in the same
multi-pane session, not for actually leaving it --- `delete-other-windows' here is
what actually gets back to a clean, single plain-Dired window afterward."
  (interactive)
  (ranger-to-dired)
  (delete-other-windows))
(with-eval-after-load 'dired
  (when (locate-library "ranger") (define-key dired-mode-map "r" #'my/dired-to-ranger)))
(with-eval-after-load 'ranger
  (define-key ranger-mode-map "r" #'my/ranger-to-dired))

;; `dired-du' --- user request ("Wiztree ... how to make that in eMacs"), the plain
;; package half of it: real recursive directory sizes shown right in the existing
;; Dired listing (not a separate buffer) --- the closest existing package to WizTree's
;; own idea. `C-c W' scoped to `dired-mode-map' specifically (not global) --- the SAME
;; letter also opens `my/disk-usage' (below), the custom, genuinely fast half of the
;; same request; the two deliberately share one mnemonic ("W"), just in two different
;; keymaps, so there is no real conflict (Dired's own local binding simply shadows the
;; global one while inside a Dired buffer, confirmed directly, not assumed). Off by
;; default and toggled, not auto-enabled everywhere --- confirmed the slow way, by
;; actually turning it on over this project's own `config/elpa' (thousands of files):
;; computing every directory's real recursive size takes real, noticeable time on a
;; big tree, the same reason `my/mode-reference-mode''s own panel and Casual's menu
;; are both opt-in rather than forced on.
;; A real repeat of the SAME gap `docker'/`kubernetes' already hit earlier this
;; session: `dired-du' is a real entry in `my/packages' (`tools/install-packages.el'),
;; but this config still never activates packages via `package.el', only `load-path'
;; --- so `dired-du-mode' needs this explicit `autoload' too, confirmed the hard way
;; again (`commandp'/`fboundp' both nil without it, caught by `tests/ert/
;; keybindings.el''s own `keys/every-documented-command-exists').
(when (locate-library "dired-du")
  (autoload 'dired-du-mode "dired-du" "Show recursive directory sizes in Dired." t))
(defun my/dired-du-missing ()
  (interactive)
  (message "dired-du is not installed.  Run ./build.sh packages"))
(with-eval-after-load 'dired
  (define-key dired-mode-map (kbd "C-c W")
    (if (locate-library "dired-du") #'dired-du-mode #'my/dired-du-missing)))

;; `my/disk-usage' (config/disk-usage.el) --- the custom, genuinely fast half of the
;; same WizTree request, see that file's own header comment for the full account.
;; Autoloaded lazily, the same shape as `my/llm-council' just below --- real, since
;; this file only ever loads the moment `C-c W' (global, outside Dired) is actually
;; used, same as that one only loads the first time `C-c a c' is.
(autoload 'my/disk-usage (expand-file-name "disk-usage" user-emacs-directory)
  "Browse a directory's disk usage, largest first, powered by `dua'." t)
(defun my/disk-usage-missing ()
  (interactive)
  (message "`dua' is not installed/not on PATH --- see docs/DISK-USAGE.md"))
(global-set-key (kbd "C-c W") (if (executable-find "dua") #'my/disk-usage #'my/disk-usage-missing))

;;; Start screen ---------------------------------------------------------------

;; What Emacs shows when started without a file: the last 5 files, folders and projects,
;; each expandable with a "+ N more" link.  `C-c h' brings it back from anywhere.
;; See startpage.el and docs/START-SCREEN.md.
;; WHAT/WHY: unlike most other feature files in this config (dictate.el, llm.el, ...),
;; startpage.el is `require'd directly here, not autoloaded --- it has to be, since
;; Emacs needs `my/start-initial-buffer' to actually exist the moment startup decides
;; what buffer to show (see `initial-buffer-choice' just below), which happens far too
;; early for a lazy, first-keypress autoload to help.  HOW: `my/start-library' resolves
;; the file's path once, reused so the `require' below and any other reference to this
;; file's own location stay in sync automatically.
(defconst my/start-library (expand-file-name "startpage" user-emacs-directory))
(require 'startpage my/start-library)
;; WHAT/WHY/HOW: this is the actual hook Emacs's own startup sequence checks --- setting
;; `initial-buffer-choice' to a function (rather than a fixed buffer name or "*scratch*",
;; its usual default) means Emacs calls that function to decide what buffer to show,
;; letting `my/start-initial-buffer' itself decide (in startpage.el) whether to show the
;; start screen at all, versus deferring to a file given on the command line.
(setq initial-buffer-choice #'my/start-initial-buffer)

;;; Session: crash-safe auto-save, and restoring open buffers/windows next time -----

;; C-c w s saves the session by hand; C-c w r discards it (back to the plain start
;; screen). Every visited, edited buffer is also auto-saved to its real file as you
;; type, not just to a recovery shadow copy. No package: `desktop-save-mode' and
;; `auto-save-visited-mode', both built into Emacs. Loaded eagerly, right after the
;; start screen, for the same reason startpage.el is: restoring a saved session has to
;; happen during startup, too early for a lazy autoload to help. See
;; config/emacs-session.el (named that, not the shorter `session', to avoid a real
;; collision with a well-known third-party package Org has its own compatibility code
;; for --- see that file's own header comment) and docs/SESSION.md.
(require 'emacs-session (expand-file-name "emacs-session" user-emacs-directory))

;;; Shortcuts reference ----------------------------------------------------------

;; This configuration's own keybindings (not the built-in Emacs ones docs/KEYBOARD.md
;; teaches), grouped by topic, foldable: `C-c k' shows it anytime; it also appears
;; automatically, split next to the start screen, the first time Emacs opens with no
;; file given.  Loaded at startup (like startpage.el/docsbuffer.el) since that startup
;; split needs its content ready immediately.  See shortcuts.el and docs/KEYBOARD.md.
(require 'shortcuts (expand-file-name "shortcuts" user-emacs-directory))
(global-set-key (kbd "C-c k") #'my/shortcuts)

;;; News (newsticker) ----------------------------------------------------------------

;; `C-c n' shows real news headlines, grouped by feed, covering the popular categories:
;; Top Stories, World, USA, Business, Technology, Politics, Science, Health,
;; Entertainment and Sports --- each verified to be a real, currently-live RSS feed, not
;; assumed.  Built into Emacs (net/newsticker.el); fetched over Emacs's own networking
;; (`url-retrieve', `newsticker-retrieval-method' is `intern' by default) --- no external
;; `wget' needed, so this works the same on the Windows bundle.  Nothing loads, and no
;; network request happens, until `C-c n' is actually pressed.
;; WHAT: which feeds newsticker fetches.  WHY: one real, currently-live source per
;; popular category (each URL curl-verified live before being added, not just assumed)
;; rather than one single "top stories" feed, so `C-c n' groups headlines the same way a
;; real newspaper's own sections do --- see docs/SEARCH-OPTIONS.md's sibling docs for
;; this project's general "verify, don't assume" convention applied here too.  HOW:
;; `newsticker-url-list' is the built-in variable `newsticker-treeview' (bound below)
;; itself reads to know what to fetch --- this `setq' is the only configuration
;; newsticker needed, since everything else (grouping by feed, the treeview UI, `intern'
;; HTTP retrieval) is Emacs's own code, un-pruned from prune.list this session (it used
;; to be stripped out of this minimal build) rather than written here.
(setq newsticker-url-list
      '(("Top Stories"   "http://feeds.bbci.co.uk/news/rss.xml")
        ("World"         "http://feeds.bbci.co.uk/news/world/rss.xml")
        ("USA"           "https://rss.nytimes.com/services/xml/rss/nyt/US.xml")
        ("Business"      "http://feeds.bbci.co.uk/news/business/rss.xml")
        ("Technology"    "http://feeds.bbci.co.uk/news/technology/rss.xml")
        ("Politics"      "https://rss.nytimes.com/services/xml/rss/nyt/Politics.xml")
        ("Science"       "http://feeds.bbci.co.uk/news/science_and_environment/rss.xml")
        ("Health"        "http://feeds.bbci.co.uk/news/health/rss.xml")
        ("Entertainment" "http://feeds.bbci.co.uk/news/entertainment_and_arts/rss.xml")
        ("Sports"        "https://www.espn.com/espn/rss/news")))
;; WHAT/WHY/HOW: bind the key straight to the built-in command; no autoload wrapper is
;; needed here the way `my/dictate'/`my/llm-chat' below get one, because `newsticker-
;; treeview' is already a normal autoloaded `net/newst-treeview.el' entry point once
;; that file is on the load path (restored by un-pruning), so Emacs's own autoload
;; machinery handles "nothing loads until first use" automatically.
(global-set-key (kbd "C-c n") #'newsticker-treeview)

;;; Dictation (local Whisper) ----------------------------------------------------------

;; `C-c m' starts recording from the microphone; press it again to stop, transcribe, and
;; insert the result at point. Fully local (no cloud, no API key) via a self-built
;; whisper.cpp; nothing is bundled, so it declines clearly if that is not set up yet.
;; See config/dictate.el and docs/DICTATE.md.
;; WHAT: an `autoload' stub, not a `require'.  WHY: matches this file's own established
;; pattern (see `my/find-git-repos', `my/llm-chat' nearby) of never loading a whole
;; feature just to bind its key --- dictate.el itself, and the (potentially slow to
;; start) whisper-cli/model files it points at, are only ever touched the first time
;; `C-c m' is actually pressed.  HOW: `expand-file-name "dictate" user-emacs-directory'
;; resolves to config/dictate.el next to this file; the docstring here is shown by `C-h
;; f'/which-key before the real file has ever been loaded.
(autoload 'my/dictate (expand-file-name "dictate" user-emacs-directory)
  "Toggle dictation: start recording, or (pressed again) stop and insert the result." t)
(global-set-key (kbd "C-c m") #'my/dictate)
;; `C-c M' (capital) is LIVE dictation: text appears every few seconds while you are still
;; speaking, via a second whisper.cpp binary (`whisper-server') kept running, instead of
;; only once, all at once, when you stop.  Same autoload-stub reasoning as `C-c m' just
;; above --- nothing here loads until first pressed. See config/dictate.el and docs/DICTATE.md.
(autoload 'my/dictate-live (expand-file-name "dictate" user-emacs-directory)
  "Toggle live dictation: transcribed a few seconds at a time while you speak." t)
(global-set-key (kbd "C-c M") #'my/dictate-live)

;;; Documentation buffer ----------------------------------------------------------

;; Every guide (README.md and docs/*.md) concatenated into one buffer, *docs*, built once
;; at startup so it is always there to read, with no network and no re-finding a file.
;; It does not pop up on its own: `C-c d' shows it, `C-c D' rebuilds it.  Reading and
;; building it takes about 2 ms for 290 KB of text, so this runs at startup, not lazily.
;; See config/docsbuffer.el and docs/CUSTOMIZING.md.
(require 'docsbuffer (expand-file-name "docsbuffer" user-emacs-directory))
(my/docs-rebuild)
(global-set-key (kbd "C-c d") #'my/docs)
(global-set-key (kbd "C-c D") #'my/docs-rebuild)

;;; Magit ------------------------------------------------------------------------

;; Git in a keyboard-driven interface: `C-x g' opens the status of the current repository
;; (see docs/MAGIT.md).  Installed into config/elpa by `./build.sh packages'; nothing
;; loads until the first use, so it costs nothing at startup.  Without it installed,
;; `C-x g' says so instead of failing.
;; WHAT: register a handful of Magit entry points as autoloads, only if Magit is actually
;; installed.  WHY: `locate-library' checks the package is present WITHOUT loading it, so
;; a machine that ran `./build.sh packages' without network access (Magit is one of the
;; optional installed packages, not bundled into this repo) still gets a working config
;; --- just with `C-x g' explaining why it can't run, via `my/magit-missing' below,
;; instead of `autoload' pointing at a file that doesn't exist and erroring obscurely.
;; HOW: each `autoload' names the real function, the literal package file it lives in
;; ("magit", one file among several this package ships), a docstring shown before the
;; real file has ever loaded, and `t' (interactive) so it can be bound to a key/called
;; with `M-x' immediately, before Magit itself has actually been loaded even once.
(when (locate-library "magit")
  (autoload 'magit-status "magit" "Show the status of the current Git repository." t)
  (autoload 'magit-dispatch "magit" "Show all Magit commands." t)
  (autoload 'magit-file-dispatch "magit" "Show Magit commands for this file." t)
  (autoload 'magit-log-buffer-file "magit" "Show the history of this file." t))
;; WHAT/WHY/HOW: the "Magit isn't installed" fallback command --- bound instead of the
;; real Magit commands whenever `locate-library "magit"' comes back nil, so pressing
;; `C-x g'/`C-c g' on a machine without Magit gives a clear, one-line explanation in the
;; echo area (with the exact command to fix it) rather than a "void function" error.
(defun my/magit-missing ()
  (interactive)
  (message "Magit is not installed.  Run ./build.sh packages"))
;; WHAT/WHY/HOW: `C-x g' (Magit's own conventional global keybinding, kept as-is rather
;; than moved under this config's own `C-c' prefix) opens the repository status buffer;
;; `C-c g' opens the file-specific command menu for whatever buffer you're currently in.
;; Both use the same "bind the real command if available, else the explainer" pattern as
;; `C-c a a'/`C-c a m'/`C-c a c' further down this file for gptel.
(global-set-key (kbd "C-x g") (if (locate-library "magit") #'magit-status #'my/magit-missing))
(global-set-key (kbd "C-c g") (if (locate-library "magit") #'magit-file-dispatch #'my/magit-missing))
;; WHAT/WHY: a real gap, found while adding Magit to the Custom menu (`my/shortcuts-
;; list', below) --- `magit-dispatch' (Magit's own top-level command hub: status, log,
;; branch, stash, everything, not just the one file `C-c g' covers) was already
;; autoloaded above but never actually bound to a key, so it could not have shown up in
;; either `C-c k' or the Custom menu no matter what was added to the list; `C-c G'
;; pairs with the existing lowercase `C-c g', the same upper/lowercase convention this
;; file already uses elsewhere (`C-c v'/`C-c V', `C-c m'/`C-c M').
(global-set-key (kbd "C-c G") (if (locate-library "magit") #'magit-dispatch #'my/magit-missing))

;; WHAT: render Magit's diffs through `delta' (https://github.com/dandavison/delta) for
;; syntax-highlighted, more readable hunks, instead of Magit's own plain diff faces.
;; WHY: a real, visible improvement to the single most-looked-at view in Magit, for the
;; cost of one more small Rust binary --- same "verified, portable, no installer" pattern
;; already used for `rg'/`fd' (see docs/SEARCH-OPTIONS.md).  HOW: only turns itself on
;; when BOTH the `magit-delta' package is installed (`locate-library') AND the `delta'
;; program is actually found on `PATH' (`executable-find') --- `magit-delta-mode' itself
;; has no such check and would error on `call-process-region' if `delta' were missing, so
;; this config checks first rather than letting that happen; on a machine with neither,
;; Magit just behaves exactly as it did before this was added, no error, nothing to fix.
;; `magit-mode-hook' turns the (buffer-local, non-global) minor mode on in every Magit
;; buffer automatically, matching `magit-delta''s own documented usage.
(when (and (locate-library "magit") (locate-library "magit-delta") (executable-find "delta"))
  (autoload 'magit-delta-mode "magit-delta" "Use Delta when displaying diffs in Magit." t)
  (add-hook 'magit-mode-hook #'magit-delta-mode))

;;; Casual Dired: a Magit-style transient menu, in Dired --------------------------------

;; WHAT: `C-o', pressed inside a Dired buffer, opens a Magit-style popup menu of Dired
;; commands (`casual-dired-tmenu') --- grouped, discoverable, built on `transient', the
;; same library Magit's own popups use.
;; WHY: user request, after asking whether anything like Magit's transient menus exists
;; for Dired --- `casual' (https://github.com/kickingvegas/casual, by Charles Choi) is
;; real and actively maintained, verified directly against MELPA's own archive (not
;; assumed from memory): confirmed present, confirmed `casual-dired.el' and
;; `casual-dired-tmenu' genuinely exist in its source, confirmed its own documentation's
;; recommended binding (`C-o', used consistently across every mode `casual' covers, "to
;; lower cognitive load" in its own words) before using it here.
;; A real, found-before-it-shipped collision, not discovered the hard way like `M-o'
;; earlier this session: `C-o' was already bound to `dired-display-file' (open the file
;; at point in another window, without switching to it). Kept `casual-dired-tmenu' on
;; `C-o' anyway, matching `casual''s own cross-mode convention (useful if any of its
;; other transient menus --- it covers many built-in modes, not just Dired --- ever get
;; added here too), rather than picking a different key for this one and breaking that
;; consistency. `dired-display-file' itself is not gone, just not on a dedicated key any
;; more: `o' (`dired-find-file-other-window') and `v' (`dired-view-file') already cover
;; closely related ground, and `M-x dired-display-file' still works directly if the
;; exact "other window, don't switch" behavior is ever specifically wanted.
;; HOW: `casual-dired-tmenu' carries its own `;;;###autoload' cookie (confirmed directly
;; in its source), so a plain `autoload' is enough --- nothing about Dired or `casual'
;; loads until `C-o' is actually pressed in a real Dired buffer. `transient' itself,
;; what this and Magit both depend on, is built into Emacs now (confirmed directly,
;; `emacs-src/lisp/transient.el'), not a separate package.
(when (locate-library "casual-dired")
  (autoload 'casual-dired-tmenu "casual-dired" "A Magit-style menu of Dired commands." t)
  (with-eval-after-load 'dired
    (keymap-set dired-mode-map "C-o" #'casual-dired-tmenu)))

;; Same idea, same key, in Org: `casual' bundles a menu for Org too
;; (`casual-org-tmenu'), and `C-o' is free there --- confirmed directly, `org-mode-map'
;; does not bind it to anything on its own (unlike Dired, where it collided with
;; `dired-display-file'; see above), so nothing is lost by using it here.
(when (locate-library "casual-org")
  (autoload 'casual-org-tmenu "casual-org" "A Magit-style menu of Org commands." t)
  (with-eval-after-load 'org
    (keymap-set org-mode-map "C-o" #'casual-org-tmenu)))

;; WHAT: both Casual menus above show as a column on the right instead of transient's
;; own stock bottom strip (the same layout Magit's popups use).
;; WHY: user request. WHY scoped to just these two prefixes rather than changing
;; `transient-display-buffer-action' globally: that variable is `transient''s shared
;; default for every prefix, Magit's own included --- changing it globally would have
;; silently moved every Magit popup too, never asked for, the same class of surprise
;; the which-key global change caused earlier this session (reverted for exactly that).
;; HOW: each `transient-prefix' object has its own `display-action' slot (confirmed
;; directly in `transient.el''s own source: `transient--display-action' checks `(oref
;; transient--prefix display-action)' FIRST, before ever consulting the global
;; variable), settable after the fact via `(get COMMAND 'transient--prefix)' --- so
;; this overrides only these two prefixes, nothing else that uses `transient'. Verified
;; directly, not assumed: a real terminal session showed Casual's menu on the right
;; while Magit's own branch transient (`C-x g' then `b'), in the same Emacs instance,
;; still showed at the bottom, exactly as it always has.
;; `slot . 0', explicit rather than left to the default --- `my/mode-reference-mode'
;; (config/mode-reference.el) puts its own always-visible panel in `slot . 1' on this
;; same edge specifically so the two can coexist, stacked, instead of fighting over one
;; slot (a real conflict, found by testing: see that file's own comment on it).
(with-eval-after-load 'casual-dired
  (oset (get 'casual-dired-tmenu 'transient--prefix) display-action
        '(display-buffer-in-side-window (side . right) (slot . 0))))
(with-eval-after-load 'casual-org
  (oset (get 'casual-org-tmenu 'transient--prefix) display-action
        '(display-buffer-in-side-window (side . right) (slot . 0))))

;; which-key itself stays at the stock bottom placement everywhere, including Dired and
;; Org --- tried scoped to just those two modes for a session, reverted on request in
;; favor of `C-o''s own menu (above) moving to the right instead, and
;; `my/mode-reference-mode' (below) for an always-visible version of the same idea.

;; WHAT: an always-visible, read-only command reference on the right while in Dired or
;; Org --- a deliberately different thing from `C-o''s own Casual menu just above:
;; never modal, never grabs focus, never closes mid-task, just a sidebar to glance at.
;; See config/mode-reference.el's own header comment for the full WHY/HOW, including
;; the real window-slot conflict with Casual's menu found and fixed while building
;; this (both now coexist, stacked, on the same edge).
(require 'mode-reference (expand-file-name "mode-reference" user-emacs-directory))
(my/mode-reference-mode 1)

;; `C-c H' turns the panel above off (or back on) --- user request, enabled by
;; default for now, with an explicit plan to turn it off once comfortable with
;; Dired/ranger/Treemacs without it. `my/mode-reference-mode' is a real `define-
;; minor-mode', so calling it interactively with no prefix argument already toggles
;; it on its own; this just gives that existing toggle a key, the same shape as
;; `C-c v' for `my/toggle-evil' just below. `C-c h' (lowercase, the start screen) is
;; already taken --- `H' (uppercase) is free.
(global-set-key (kbd "C-c H") #'my/mode-reference-mode)

;;; Finding git repositories --------------------------------------------------------

;; `C-c f p' lists every git repository on the Linux side; `C-u C-c f p' also scans every
;; mounted Windows drive (much slower).  Runs tools/find-repos.sh in the background, so
;; Emacs is never blocked while it searches.  Nothing loads until first use.
;; See config/gitfolders.el.
(autoload 'my/find-git-repos (expand-file-name "gitfolders" user-emacs-directory)
  "Show every git repository on this computer." t)

;;; Chat with an LLM (gptel) ----------------------------------------------------------

;; `C-c a a' opens a chat buffer: a local Ollama model, set up automatically (reading
;; whatever `ollama list' reports right now); `C-c a m' opens gptel's own menu to switch
;; model, backend or system prompt.  Installed into config/elpa by `./build.sh packages';
;; nothing loads until first use.  See config/llm.el and docs/LLM.md.
(when (locate-library "gptel")
  (autoload 'gptel-menu "gptel-transient" "Menu: pick a model, backend or system prompt." t)
  ;; WHAT: make Ollama the default backend the moment `gptel' is touched at all, however
  ;; that happens --- not only via `my/llm-chat' (`C-c a a').  WHY: a real, reported
  ;; problem --- `gptel' ships with its own factory default backend, "ChatGPT" (a real
  ;; OpenAI endpoint), and this config deliberately never puts an API key anywhere;
  ;; reaching `gptel' through `C-c a m' first (which autoloads `gptel-transient' directly
  ;; --- see just above --- and never touches `config/llm.el' at all before that) hit
  ;; that untouched default and failed with a real "401 Unauthorized" the moment anything
  ;; was actually sent.  HOW: this has to live here, at the top level of `init.el' (always
  ;; loaded), not inside `config/llm.el' itself --- that file is *itself* lazily
  ;; autoloaded (only the first time `my/llm-chat'/`my/llm-council' runs), so a
  ;; `with-eval-after-load' hook registered inside it would never even be registered yet
  ;; if `gptel' were reached some other way first, exactly the bug this fixes. Costs
  ;; nothing at startup either way: `with-eval-after-load' only registers a callback,
  ;; and `(require 'llm ...)' inside it does not run until `gptel' itself actually loads.
  (with-eval-after-load 'gptel
    (require 'llm (expand-file-name "llm" user-emacs-directory))
    (my/llm-setup-ollama)))
(autoload 'my/llm-chat (expand-file-name "llm" user-emacs-directory)
  "Open a chat buffer with the local Ollama backend." t)
;; `C-c a c' asks three different local models the same question in parallel, then has a
;; fourth, bigger model compare and summarize their answers --- the summary shows up
;; expanded, each model's own answer folded shut below it. See config/llm-council.el.
;; WHAT/WHY/HOW: autoloaded the same way as `my/llm-chat' just above, and for the same
;; reason --- config/llm-council.el (and the `require's it does at the top of itself,
;; including this same `llm.el') only actually loads the first time `C-c a c' is used.
(autoload 'my/llm-council (expand-file-name "llm-council" user-emacs-directory)
  "Ask several local models at once, then have a bigger one summarize." t)
(defun my/llm-missing ()
  (interactive)
  (message "gptel is not installed.  Run ./build.sh packages"))
(global-set-key (kbd "C-c a a") (if (locate-library "gptel") #'my/llm-chat #'my/llm-missing))
(global-set-key (kbd "C-c a m") (if (locate-library "gptel") #'gptel-menu #'my/llm-missing))
;; WHAT/WHY: same "bind to the real command if gptel is installed, otherwise to a command
;; that just explains why not" pattern as the two lines above it --- `my/llm-council'
;; itself calls `(require 'gptel)' and would error confusingly if gptel were missing, so
;; this check happens here, once, before the key is even bound.
(global-set-key (kbd "C-c a c") (if (locate-library "gptel") #'my/llm-council #'my/llm-missing))

;;; Themes ------------------------------------------------------------------------

;; `C-c c' then a character picks a color theme --- `C-c c 1' for the first, `C-c c 2'
;; for the second, and so on through `z' then uppercase `A'-`T'; `C-c c 0' is the
;; **default** theme, i.e. turns every theme off and goes back to Emacs's own plain,
;; un-themed look (what this config starts in --- see docs/MAGIT.md's own note that
;; Magit "looks plain" for exactly that reason), included here as its own numbered
;; choice rather than a special case you have to remember separately.
;;
;; WHAT/WHY: 55 real themes now (8 built-in Modus Themes + 47 from 15 separately
;; installed packages). `(interactive "c")' reads exactly one raw character, so once
;; digits 1-9 and lowercase a-z ran out (35 slots) the scheme continued into uppercase
;; A-Z rather than switching to a whole different, multi-keystroke mechanism --- but at
;; this scale, memorizing a specific character for most of these 55 stops being the
;; point. Two other ways in, for when the slot number doesn't matter: `C-c .'/`C-c ,'
;; (`my/cycle-theme'/`my/cycle-theme-previous', below) step forward/backward through
;; this same list one theme at a time, always starting from whatever theme is actually
;; active; `C-c C' (`consult-theme', below) fuzzy-searches any installed theme *by
;; name* with a live preview --- the practical way to reach `doom-themes''s own 50+
;; variants, pulled in only as `ember''s hard dependency and deliberately given no
;; `my/themes' slot of its own (nobody asked for doom-themes itself, just the two ember
;; variants built on it).
;;
;; Packages (MELPA unless noted): `atom-one-dark-theme' (https://github.com/
;; jonathanchu/atom-one-dark-theme); `catppuccin-theme' (https://github.com/catppuccin/
;; emacs --- one theme symbol, 4 palettes via `catppuccin-flavor', `mocha' is the
;; default used here); `solo-jazz-theme' (https://github.com/cstby/solo-jazz-emacs-
;; theme); `nimbus-theme' (https://github.com/mrcnski/nimbus-theme); `rebecca-theme'
;; (https://github.com/vic/rebecca-theme); `subatomic-theme' (https://github.com/cryon/
;; subatomic-theme); `night-owl-theme' (https://github.com/aaronjensen/night-owl-
;; emacs); `seti-theme' (https://github.com/caisah/seti-theme --- VC-installed, see
;; `my/vc-packages' in tools/install-packages.el, not on any archive); `shanty-themes'
;; (https://github.com/qhga/shanty-themes, 2 variants); `snazzy-theme' (https://
;; github.com/weijiangan/emacs-snazzy); `horizon-theme' (https://github.com/aodhneine/
;; horizon-theme.el); `xcode-theme' (https://github.com/juniorxxue/xcode-theme --- VC-
;; installed, 2 variants); `immaterial-theme' (https://github.com/petergardfjall/emacs-
;; immaterial-theme, 2 variants); `zenburn-theme' (https://github.com/bbatsov/zenburn-
;; emacs); `solarized-theme' (https://github.com/bbatsov/solarized-emacs, 12 variants);
;; `dracula-theme' (https://github.com/dracula/emacs); `kaolin-themes' (https://
;; github.com/ogdenwebb/emacs-kaolin-themes, 15 variants, every symbol prefixed
;; `kaolin-'); `ember-theme' (https://github.com/ember-theme/emacs --- VC-installed, 2
;; variants, requires `doom-themes' as a hard dependency, see the WHY note next to
;; `my/vc-packages' in tools/install-packages.el). All eight Modus Themes
;; (https://github.com/protesilaos/modus-themes, by Protesilaos Stavrou) are built
;; straight into this Emacs already --- no package, no download, confirmed directly:
;; `etc/themes/modus-*-theme.el' ships with every Emacs 28+ release.
;;
;; WHAT/WHY: a few of the 15 packages above (`rebecca-theme', `night-owl-theme', also
;; `seti-theme') are old enough that their main file never declares `;; -*-
;; lexical-binding: t; -*-' on its first line --- harmless (they still load and work
;; exactly as intended; `lexical-binding' only affects how *that file's own* code
;; captures variables, not anything this config does with the theme once loaded), but
;; Emacs warns about it loudly every single time one of those files is loaded, which
;; is every time its theme is actually switched to, not just once at startup. Silenced
;; by its own specific warning type (`files missing-lexbind-cookie', confirmed directly
;; in `files.el''s own source) rather than disabling file warnings generally, so a
;; genuinely different problem in some other file still surfaces normally.
(require 'warnings)   ; `warning-suppress-log-types' is void until this loads
(setq warning-suppress-log-types
      (cons '(files missing-lexbind-cookie) warning-suppress-log-types))
(defvar my/themes
  '((?1 . atom-one-dark)
    (?2 . catppuccin)                  ; mocha flavor
    (?3 . solo-jazz)
    (?4 . nimbus)
    (?5 . rebecca)
    (?6 . subatomic)
    (?7 . night-owl)
    (?8 . seti)
    (?9 . shanty-themes-dark)
    (?a . shanty-themes-light)
    (?b . snazzy)
    (?c . horizon)
    (?d . xcode-dark)
    (?e . xcode-light)
    (?f . immaterial-dark)
    (?g . immaterial-light)
    (?h . zenburn)
    (?i . solarized-dark)
    (?j . solarized-light)
    (?k . solarized-dark-high-contrast)
    (?l . solarized-light-high-contrast)
    (?m . solarized-gruvbox-dark)
    (?n . solarized-gruvbox-light)
    (?o . solarized-selenized-black)
    (?p . solarized-selenized-dark)
    (?q . solarized-selenized-light)
    (?r . solarized-selenized-white)
    (?s . solarized-wombat-dark)
    (?t . solarized-zenburn)
    (?u . dracula)
    (?v . kaolin-dark)
    (?w . kaolin-light)
    (?x . kaolin-aurora)
    (?y . kaolin-blossom)
    (?z . kaolin-breeze)
    (?A . kaolin-bubblegum)
    (?B . kaolin-eclipse)
    (?C . kaolin-galaxy)
    (?D . kaolin-mono-dark)
    (?E . kaolin-mono-light)
    (?F . kaolin-ocean)
    (?G . kaolin-shiva)
    (?H . kaolin-temple)
    (?I . kaolin-valley-dark)
    (?J . kaolin-valley-light)
    (?K . ember-light)                 ; needs `doom-themes'; manual pick only, see WHY above
    (?L . ember-soft)                  ; needs `doom-themes'; manual pick only, see WHY above
    (?M . modus-operandi)              ; light
    (?N . modus-operandi-tinted)       ; light, warmer background
    (?O . modus-operandi-deuteranopia) ; light, red/green colorblind-friendly
    (?P . modus-operandi-tritanopia)   ; light, blue/yellow colorblind-friendly
    (?Q . modus-vivendi)               ; dark
    (?R . modus-vivendi-tinted)        ; dark, warmer background
    (?S . modus-vivendi-deuteranopia)  ; dark, red/green colorblind-friendly
    (?T . modus-vivendi-tritanopia))   ; dark, blue/yellow colorblind-friendly
  "Character key (e.g. ?1, ?a or ?A) -> theme symbol, for `my/load-theme-by-number'.
Add more entries here (any theme on `custom-theme-load-path') to pick them with `C-c c'
the same way; `0' is reserved for the default (no theme applied). `C-c .'/`C-c ,' cycle
through this same list by position; `C-c C' (`consult-theme') reaches any installed
theme by name instead of by character.")

;; WHAT: `C-c c' + a digit --- switch to that numbered theme, or `0' for the default
;; (Emacs's own plain look, no theme applied). WHY/HOW: `(interactive "c")' reads
;; exactly one more character right after the prefix key is pressed, so `C-c c 1' is a
;; single 3-key sequence, not a separate prompt; every already-enabled theme is disabled
;; first (`custom-enabled-themes', built in) so themes never stack --- switching from 5
;; to 2 without this would layer modus-operandi-tinted's faces on top of modus-vivendi's
;; instead of replacing them, a real visual mess, and the same disabling step is what
;; makes `0' genuinely restore the default look rather than just doing nothing.  A
;; number with nothing bound to it (anything past what `my/themes' currently has) says so
;; clearly in the echo area rather than silently doing nothing.
(defun my/load-theme-by-number (n)
  "Load the theme bound to N (a character, e.g. ?1) in `my/themes'; 0 is the default (no theme)."
  (interactive "c")
  (mapc #'disable-theme custom-enabled-themes)
  (if (eq n ?0)
      (progn (my/ensure-visible-cursor) (message "Theme: default"))
    (let ((theme (alist-get n my/themes)))
      (if theme
          (progn (load-theme theme t) (message "Theme: %s" theme))
        (message "No theme bound to %c (see my/themes)" n)))))
(global-set-key (kbd "C-c c") #'my/load-theme-by-number)

;; WHAT/WHY/HOW: `C-c .'/`C-c ,' step forward/backward through `my/themes' one theme at
;; a time, for when which specific slot a theme is in doesn't matter --- always starting
;; from whichever theme (if any) is actually active (`custom-enabled-themes', built in),
;; not from a separately tracked position, so cycling stays in sync even after `C-c c'
;; or `C-c C' picked something by hand in between; the current theme not being in
;; `my/themes' at all (the default, i.e. no theme, or anything loaded some other way)
;; is treated the same as not having started cycling yet --- `C-c .' from there goes to
;; the first theme in the list, `C-c ,' to the last, both well-defined rather than an
;; error. Wraps around at either end (`mod') rather than stopping, so holding the key
;; down cycles through every theme in a loop.
(defun my/cycle-theme (&optional reverse)
  "Switch to the next theme in `my/themes' (the previous, if REVERSE is non-nil),
relative to whichever theme is currently active; wraps around at either end."
  (interactive "P")
  (let* ((themes (mapcar #'cdr my/themes))
         (pos (or (seq-position themes (car custom-enabled-themes)) -1))
         (next (nth (mod (+ pos (if reverse -1 1)) (length themes)) themes)))
    (mapc #'disable-theme custom-enabled-themes)
    (load-theme next t)
    (message "Theme: %s" next)))
(defun my/cycle-theme-previous ()
  "Switch to the previous theme in `my/themes'; see `my/cycle-theme'."
  (interactive)
  (my/cycle-theme t))
(global-set-key (kbd "C-c .") #'my/cycle-theme)
(global-set-key (kbd "C-c ,") #'my/cycle-theme-previous)

;; WHAT/WHY: `C-c C' --- fuzzy-search any installed theme *by name*, with a live
;; preview as different candidates are highlighted (reverted again on cancel) ---
;; the practical way to reach the long tail of themes above without memorizing a
;; character for each one, and the only numberless way to reach `doom-themes''s own
;; 50+ variants (pulled in only as `ember''s dependency, see `my/themes' above; never
;; given a slot of its own there). `consult-theme' ships with `consult' (already a
;; dependency here, see the Search section); same `-missing' fallback pattern as every
;; other optional-package key in this file.
(global-set-key (kbd "C-c C") (if (locate-library "consult") #'consult-theme #'my/consult-missing))

;; WHAT/WHY/HOW: make the actual cursor (not the current-line highlight from
;; `global-hl-line-mode', already on above) stay visible no matter which of the 55+
;; themes above is active --- several of them don't give enough contrast between their
;; own `cursor' face and their own `hl-line' face, so the real insertion point can
;; disappear into the highlighted line, confirmed directly by switching through a
;; sample of the new themes. `enable-theme-functions' (built into Emacs 29+) runs after
;; *any* theme is enabled, through every entry point here (`C-c c', `C-c .'/`C-c ,',
;; `C-c C' via `consult-theme', `theme-buffet''s automatic switching, or Emacs's own
;; startup) --- one hook here is simpler and more robust than overriding the `cursor'
;; face separately in each of those commands; `my/load-theme-by-number' calls it
;; directly too for `C-c c 0' (the plain default), since *disabling* every theme does
;; not run `enable-theme-functions' the way enabling one does.
(defun my/ensure-visible-cursor (&rest _)
  "Keep the cursor a fixed, highly visible color regardless of the active theme."
  (set-face-attribute 'cursor nil :background "DarkOrange"))
(add-hook 'enable-theme-functions #'my/ensure-visible-cursor)
(my/ensure-visible-cursor)

;; WHAT: `theme-buffet' (GNU ELPA --- not one of Protesilaos's own packages despite
;; appearing in his dotfiles; maintained separately, see
;; https://elpa.gnu.org/packages/theme-buffet.html) automatically switches between
;; light and dark Modus Themes through the day: light in the morning/afternoon, dark in
;; the evening/night, re-checked hourly. WHY: a sensible default that changes with
;; actual daylight, while `C-c c' above remains available any time as a manual override
;; --- the two are not in conflict, since the hourly check only fires again once the
;; time period actually changes, not continuously. HOW: `my/themes-light'/`-dark' list
;; which of `my/themes''s entries go in each of `theme-buffet''s two "light hours"
;; periods (morning, afternoon) and two "dark hours" periods (evening, night) --- kept
;; as its own explicit list rather than derived from `my/themes' by name-matching
;; ("operandi"/"vivendi"), since a future non-Modus theme (the user said "I will get
;; more") might not follow that naming convention at all; add a new theme to both
;; `my/themes' (for `C-c c') and whichever of these two lists it belongs in. Installed
;; into config/elpa by `./build.sh packages'. `theme-buffet-a-la-carte', called
;; non-interactively (confirmed in its own source: `called-interactively-p' gates the
;; prompt, so a Lisp call always takes the "pick at random from the current period"
;; branch), applies a theme for right now at startup, instead of waiting up to an hour
;; for the first timer tick.
(defvar my/themes-light '(modus-operandi modus-operandi-tinted
                          modus-operandi-deuteranopia modus-operandi-tritanopia)
  "Themes `theme-buffet' may pick from during the day (morning/afternoon).")
(defvar my/themes-dark '(modus-vivendi modus-vivendi-tinted
                         modus-vivendi-deuteranopia modus-vivendi-tritanopia)
  "Themes `theme-buffet' may pick from in the evening/night.")
(when (locate-library "theme-buffet")
  (require 'theme-buffet)
  (setq theme-buffet-menu 'end-user
        theme-buffet-end-user
        `(:morning   ,my/themes-light
          :afternoon ,my/themes-light
          :evening   ,my/themes-dark
          :night     ,my/themes-dark))
  (theme-buffet-a-la-carte)
  (theme-buffet-timer-hours 1))

;; WHAT: the session system (`C-c w s'/`C-c w r', and the automatic save/restore) also
;; remembers and restores the active color theme, not just window placement, buffers,
;; files and frame chrome.
;; WHY: user request, after confirming for real (not assumed) that theme was the ONE
;; thing the session system did NOT already cover --- everything else (window
;; placement, buffers, files, frame chrome) already persists via `desktop-save-mode''s
;; own frameset mechanism, confirmed directly by saving a real session and inspecting
;; the raw saved file. Without this, `theme-buffet' always re-picks a fresh random theme
;; at every startup regardless of what was active when the session was saved --- a
;; sensible DEFAULT, but it meant there was no way to make a deliberately-chosen theme
;; stick across restarts the way the rest of the session already does.
;; HOW: `desktop-globals-to-save' is `desktop-save-mode''s own, already-built-in
;; mechanism for saving/restoring the VALUE of a plain variable (not a buffer or frame)
;; --- `my/session-theme' just records the name of whatever theme was active, updated
;; via `desktop-save-hook' (runs right before every save, whichever of the several
;; places that trigger one actually fired: `C-c w s', `C-c U', the periodic auto-save,
;; or exit). Restoring the VALUE alone would not actually re-enable the theme, though
;; (`load-theme' is a real function call, not just a variable) --- `desktop-after-read-
;; hook' does that explicitly, and runs from INSIDE the real `desktop-read' call that
;; this config's own `after-init-hook' entry (depth 90, in config/emacs-session.el)
;; triggers --- which happens AFTER `theme-buffet-a-la-carte''s own initial pick above
;; has already run (that call is plain top-level code, finished before `after-init-hook'
;; ever fires), so this always runs later and correctly wins, rather than `theme-buffet'
;; silently overriding it back on the very next startup.
(defvar my/session-theme nil
  "Name of the color theme active when the session was last saved, or nil for none.
Saved and restored automatically as part of the session (see `desktop-globals-to-save')
--- not meant to be set by hand.")
(add-to-list 'desktop-globals-to-save 'my/session-theme)
(defun my/session--remember-theme ()
  "Record the currently active theme into `my/session-theme', right before a save."
  (setq my/session-theme (car custom-enabled-themes)))
(add-hook 'desktop-save-hook #'my/session--remember-theme)
(defun my/session--restore-theme ()
  "Re-apply `my/session-theme' after a restore, overriding whatever `theme-buffet'
already picked at startup (this runs later, so it wins)."
  (mapc #'disable-theme custom-enabled-themes)
  (if my/session-theme
      (load-theme my/session-theme t)
    (my/ensure-visible-cursor)))
(add-hook 'desktop-after-read-hook #'my/session--restore-theme)

;;; Keys ---------------------------------------------------------------------

(global-set-key (kbd "C-c f f") #'my/ff-find-file)
(global-set-key (kbd "C-c f d") #'my/ff-find-file-here)
(global-set-key (kbd "C-c f g") #'my/ff-find-file-global)
;; Same "bind to the real command if its dependency is installed, otherwise to a command
;; that just explains why not" pattern as `C-c a c' above --- `my/ff-find-file-global-
;; async' itself also declines clearly if called some other way (`M-x'), but binding it
;; to `my/consult-missing' here means the key itself never even reaches that far.
(global-set-key (kbd "C-c f a") (if (locate-library "consult") #'my/ff-find-file-global-async #'my/consult-missing))
(global-set-key (kbd "C-c f r") #'my/ff-reindex)
(global-set-key (kbd "C-c f p") #'my/find-git-repos)
(global-set-key (kbd "C-c v") #'my/toggle-evil)
(global-set-key (kbd "C-x C-b") #'ibuffer)
(global-set-key (kbd "C-c r") #'recentf-open)
(global-set-key (kbd "C-c h") #'my/start)

;; Report how fast we started, once, so speed is measurable.
(add-hook 'emacs-startup-hook
          (lambda ()
            (message "Emacs %s ready in %.2fs (%d GCs), native-comp: %s"
                     emacs-version
                     (float-time (time-subtract after-init-time before-init-time))
                     gcs-done
                     (native-comp-available-p))))

;;; init.el ends here
