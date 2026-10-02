;;; config.el --- our init.el / early-init.el take effect  -*- lexical-binding: t; -*-
;; harness: config

(ert-deftest config/init-file-reloads-cleanly ()
  (let ((init (expand-file-name "init.el" user-emacs-directory)))
    (should (file-exists-p init))
    (should (load init nil t))))

(ert-deftest config/a-real-known-theme-is-enabled-by-default ()
  ;; Was `config/no-theme-enabled' (asserted `null custom-enabled-themes') until
  ;; `theme-buffet' was added: a theme is now deliberately enabled automatically at
  ;; startup (light in the morning/afternoon, dark in the evening/night --- see
  ;; config/init.el's own "Themes" section; tests/ert/themes.el covers that switching
  ;; logic itself in depth). This just confirms the one enabled at startup is real and
  ;; known (one of `my/themes''s own values), not stray or undefined --- skipped
  ;; entirely if theme-buffet isn't installed, in which case nothing is enabled, same
  ;; as before.
  (if (locate-library "theme-buffet")
      (progn
        (should (= (length custom-enabled-themes) 1))
        (should (memq (car custom-enabled-themes) (mapcar #'cdr my/themes))))
    (should (null custom-enabled-themes))))

(ert-deftest config/line-column-and-hl-line ()
  (should global-display-line-numbers-mode)
  (should column-number-mode)
  (should global-hl-line-mode))

;; WHAT: long lines wrap at the last word boundary that fits, not mid-word.  WHY: a
;; real, reported problem --- Emacs's own default (`word-wrap' nil) wraps at the exact
;; character the window edge lands on, splitting a word in two if it straddles that
;; boundary, with the continuation arrow (shown whenever a line wraps at all, marking it
;; as "not a real newline") then sitting in the middle of the split word. `word-wrap' t
;; does not remove that arrow --- it still marks every wrapped line --- it just moves
;; the wrap point back to the nearest word boundary, so a whole word moves to the next
;; line together instead of being cut in half.
(ert-deftest config/long-lines-wrap-at-word-boundaries-not-mid-word ()
  (should (default-value 'word-wrap)))

;; WHAT: `M-x calendar' stays at the stock 3-month display --- a real reversal, not the
;; original design.  WHY: `calendar-total-months' was briefly set to 12 here, verified
;; only by counting month names in the buffer's *text*, which did hold 12 --- but
;; `calendar.el' lays every month out in a single row, so 12 months rendered as one
;; line 300 columns wide, wrapping and scrambling on any normal window (reported by the
;; user immediately). Emacs's calendar has no multi-row year-grid view to switch to
;; instead, so this stays at 3. HOW: a real, fresh subprocess that actually opens a real
;; calendar buffer and counts real month headers in it, not just that the variable
;; holds the default --- the same real-buffer-content check that should have caught the
;; width problem the first time, had it also measured the line width, not just the
;; month count.
(ert-deftest config/calendar-stays-at-the-default-3-months ()
  (let ((out (with-output-to-string
               (with-current-buffer standard-output
                 (call-process test-emacs nil t nil "--batch" "--init-directory" (getenv "CONFIG_DIR")
                               "-l" (expand-file-name "early-init.el" (getenv "CONFIG_DIR"))
                               "-l" (expand-file-name "init.el" (getenv "CONFIG_DIR"))
                               "--eval" "(calendar)"
                               "--eval" "(with-current-buffer calendar-buffer (princ (list (how-many \"[A-Z][a-z]+ 20[0-9][0-9]\" (point-min) (point-max)) (- (line-end-position 1) (line-beginning-position 1)))))")))))
    (should (string-match-p "(3 76)" out))))

(ert-deftest config/indentation-defaults ()
  (should-not (default-value 'indent-tabs-mode))
  (should (= 4 (default-value 'tab-width)))
  (should (= 80 (default-value 'fill-column))))

(ert-deftest config/editing-modes-enabled ()
  (dolist (m '(electric-pair-mode show-paren-mode delete-selection-mode
               global-auto-revert-mode save-place-mode recentf-mode savehist-mode))
    (should (symbol-value m))))

(ert-deftest config/recentf-autosaves-periodically-not-only-on-a-clean-exit ()
  ;; Confirmed for real on the Windows bundle: without this, a forced kill (a crash, Task
  ;; Manager, a real hang) loses the whole session's recent-files history, since `recentf'
  ;; only saves via `kill-emacs-hook' by default.
  (should (cl-some (lambda (tm) (and (eq (timer--function tm) #'recentf-save-list)
                                     (timer--repeat-delay tm)))       ; non-nil: a repeating idle timer
                   timer-idle-list)))

;; WHAT: that periodic autosave (every 30s, while idle) does not print "Wrote .../
;; recentf.eld" to the echo area each time.  WHY: a real, reported problem ---
;; `recentf-show-messages' defaults to `t' in stock Emacs, so it did, every 30s, until
;; this was set.  HOW: confirmed directly against `recentf-save-list' itself (not just
;; that the variable is nil, which would not catch a future stock-Emacs version wiring
;; the message some other way) --- mocks `message' to record calls, then asserts none
;; happened across a real (non-interactive) call.
(ert-deftest config/recentf-autosave-does-not-message ()
  (should-not recentf-show-messages)
  (let (messages)
    (cl-letf (((symbol-function 'message)
               (lambda (fmt &rest args) (push (apply #'format fmt args) messages))))
      (recentf-save-list))
    (should-not messages)))

;;; News (newsticker): C-c n, real feeds, nothing loaded until used

(ert-deftest config/news-key-is-bound ()
  (should (eq (key-binding (kbd "C-c n")) 'newsticker-treeview)))

(ert-deftest config/news-feeds-are-configured ()
  (should (equal newsticker-url-list
                 '(("Top Stories"   "http://feeds.bbci.co.uk/news/rss.xml")
                   ("World"         "http://feeds.bbci.co.uk/news/world/rss.xml")
                   ("USA"           "https://rss.nytimes.com/services/xml/rss/nyt/US.xml")
                   ("Business"      "http://feeds.bbci.co.uk/news/business/rss.xml")
                   ("Technology"    "http://feeds.bbci.co.uk/news/technology/rss.xml")
                   ("Politics"      "https://rss.nytimes.com/services/xml/rss/nyt/Politics.xml")
                   ("Science"       "http://feeds.bbci.co.uk/news/science_and_environment/rss.xml")
                   ("Health"        "http://feeds.bbci.co.uk/news/health/rss.xml")
                   ("Entertainment" "http://feeds.bbci.co.uk/news/entertainment_and_arts/rss.xml")
                   ("Sports"        "https://www.espn.com/espn/rss/news"))))
  ;; every URL really is one (catches a typo before it ever reaches a real fetch)
  (dolist (feed newsticker-url-list)
    (should (string-match-p "\\`https?://" (nth 1 feed))))
  ;; every category name is unique (newsticker groups headlines by this name)
  (let ((names (mapcar #'car newsticker-url-list)))
    (should (= (length names) (length (delete-dups (copy-sequence names)))))))

(ert-deftest config/news-uses-built-in-networking-not-an-external-program ()
  ;; So this works the same on the Windows bundle, which has no `wget'. A guard against
  ;; newsticker's own upstream default ever changing, not something this config sets
  ;; itself --- so load it first to see its real default.
  (require 'newst-backend)
  (should (eq newsticker-retrieval-method 'intern)))

(ert-deftest config/news-every-feed-is-really-live ()
  ;; Opt-in only (a real HTTP round trip to 10 real, external services): confirms each
  ;; configured feed is not just a plausible-looking URL but a real, currently-live RSS
  ;; feed with at least one item, using this project's own retrieval path (`url-
  ;; retrieve-synchronously', matching `newsticker-retrieval-method's `intern' default)
  ;; rather than an external `curl'.
  (test-skip-unless-network)
  (dolist (feed newsticker-url-list)
    (with-current-buffer (url-retrieve-synchronously (nth 1 feed) t t 15)
      (unwind-protect
          (progn
            (goto-char (point-min))
            (should (re-search-forward "\n\n" nil t))    ; end of the HTTP headers
            (should (re-search-forward "<item>\\|<entry>" nil t)))  ; RSS or Atom
        (kill-buffer)))))

(ert-deftest config/news-is-not-loaded-or-fetched-at-startup ()
  (let ((out (with-output-to-string
               (with-current-buffer standard-output
                 (call-process test-emacs nil t nil "--batch" "--init-directory" (getenv "CONFIG_DIR")
                               "-l" (expand-file-name "early-init.el" (getenv "CONFIG_DIR"))
                               "-l" (expand-file-name "init.el" (getenv "CONFIG_DIR"))
                               "--eval" "(princ (list (featurep 'newsticker) (autoloadp (symbol-function 'newsticker-treeview))))")))))
    (should (string-match-p "(nil t)" out))))

(ert-deftest config/completion-setup ()
  ;; vertico/orderless/marginalia when installed (the normal case here); the built-in
  ;; fido-vertical-mode as a fallback otherwise --- matches how this config treats every
  ;; other package as optional.
  (if (locate-library "vertico")
      (progn
        (should vertico-mode)
        (should marginalia-mode)
        (should (memq 'orderless completion-styles))
        (should-not fido-vertical-mode))
    (should fido-vertical-mode))
  (should global-completion-preview-mode)
  (should which-key-mode)
  ;; kept in both cases: `C-x p f' relies on it (see init.el's own comment on the real
  ;; regression this caught: jnav/a-partial-name-finds-the-file-by-fuzzy-matching).
  (should (memq 'flex completion-styles))
  (should completion-ignore-case))

(ert-deftest config/treesit-highlight-level ()
  (should (= 4 treesit-font-lock-level)))

(ert-deftest config/backups-go-to-one-directory ()
  (let ((dir (expand-file-name "backups/" user-emacs-directory)))
    (should (file-directory-p dir))
    (should (string-prefix-p dir (make-backup-file-name
                                  (expand-file-name "x.txt" temporary-file-directory))))
    (should-not create-lockfiles)
    (should backup-by-copying)))

(ert-deftest config/custom-file-is-separate ()
  (should (equal custom-file (expand-file-name "custom.el" user-emacs-directory))))

(ert-deftest config/misc-preferences ()
  (should (eq ring-bell-function #'ignore))
  (should use-short-answers)
  (should require-final-newline)
  (should-not sentence-end-double-space)
  (should (= read-process-output-max (* 1024 1024))))

(ert-deftest config/gc-threshold-restored-after-startup ()
  (run-hooks 'emacs-startup-hook)
  (should (= gc-cons-threshold (* 64 1024 1024))))

(ert-deftest config/early-init-frame-defaults ()
  (should (equal (assq 'tool-bar-lines default-frame-alist) '(tool-bar-lines . 0)))
  (should inhibit-startup-screen))

(ert-deftest config/key-bindings ()
  (should (eq (key-binding (kbd "C-x C-b")) 'ibuffer))
  (should (eq (key-binding (kbd "M-o")) 'ace-window))
  (should (eq (key-binding (kbd "C-c r")) 'recentf-open))
  (should (eq (key-binding (kbd "C-c v")) 'my/toggle-evil))
  (should (eq (key-binding (kbd "C-c w s")) 'my/session-save))
  (should (eq (key-binding (kbd "C-c w r")) 'my/session-reset))
  (should (eq (key-binding (kbd "C-c w l")) 'my/session-list))
  (should (eq (key-binding (kbd "C-c w S")) 'my/session-save-as))
  (should (eq (key-binding (kbd "C-c w O")) 'my/session-open))
  (should (eq (key-binding (kbd "C-c w D")) 'my/session-delete))
  (should (eq (key-binding (kbd "C-c w L")) 'my/session-named-list)))

(ert-deftest config/toggle-frame-chrome-hides-and-shows-everything-together ()
  ;; A real, found-by-using-it problem: the menu bar, tool bar and window decorations
  ;; were toggled separately, by hand, one `eval-expression' at a time --- `C-c u' makes
  ;; all three move together instead.
  ;;
  ;; A real design mistake this test itself caught on the first version: deciding which
  ;; way to toggle by reading `menu-bar-mode''s own current state assumed all three
  ;; start out matching. They do not here --- `early-init.el' starts the tool bar OFF
  ;; (a startup-speed optimization) while the menu bar starts ON --- so a per-component
  ;; flip could leave the tool bar visible after only two presses, never asked for.
  ;; Fixed with `my/frame-chrome-hidden', a single tracked flag all three are set FROM,
  ;; not independently flipped --- this test checks exactly that: after one toggle, all
  ;; three agree with the new flag (not with their own, possibly mismatched, prior
  ;; state), and a second toggle returns the flag to where it started.
  (let ((menu-before menu-bar-mode) (tool-before tool-bar-mode)
        (undecorated-before (frame-parameter nil 'undecorated))
        (hidden-before my/frame-chrome-hidden))
    (unwind-protect
        (progn
          (my/toggle-frame-chrome)
          (should (eq menu-bar-mode (not my/frame-chrome-hidden)))
          (should (eq tool-bar-mode (not my/frame-chrome-hidden)))
          (should (eq (and (frame-parameter nil 'undecorated) t) (and my/frame-chrome-hidden t)))
          (my/toggle-frame-chrome)
          (should (eq my/frame-chrome-hidden hidden-before))
          (should (eq menu-bar-mode (not my/frame-chrome-hidden)))
          (should (eq tool-bar-mode (not my/frame-chrome-hidden))))
      ;; Restore exactly, regardless of pass or fail: these are real global minor modes
      ;; and a real frame parameter, not test-local state.
      (menu-bar-mode (if menu-before 1 -1))
      (tool-bar-mode (if tool-before 1 -1))
      (set-frame-parameter nil 'undecorated undecorated-before)
      (setq my/frame-chrome-hidden hidden-before))))

(ert-deftest config/reset-to-defaults-restores-frame-and-theme-and-saves-cleanly ()
  ;; The real, repeatedly-hit two-part problem `C-c U' exists to fix: (1) messing with
  ;; the menu bar/tool bar/decorations/theme by hand never puts the LIVE frame back to
  ;; this config's own actual defaults on its own, and (2) even after fixing the live
  ;; state, forgetting the separate "now save it" step meant the old, messed-up state
  ;; got auto-saved again on the very next exit anyway. This test checks both halves:
  ;; the live frame/theme values end up at this config's real defaults, AND a save
  ;; right afterward succeeds with no interactive prompt --- which only happens if the
  ;; session was properly "owned" first (a real `desktop-read', not skipped the way
  ;; `--batch' mode always skips it; see tests/ert/emacs-session.el's own note on this
  ;; exact point) --- matching what a real interactive launch always does before a user
  ;; could ever press `C-c U'.
  (test-with-temp-dir dir
    (let ((my/session-dir dir) (desktop-dirname dir) (desktop-path (list dir)) (desktop-save t)
          (menu-before menu-bar-mode) (tool-before tool-bar-mode)
          (undecorated-before (frame-parameter nil 'undecorated))
          (themes-before custom-enabled-themes) (hidden-before my/frame-chrome-hidden))
      (unwind-protect
          (progn
            ;; a real `desktop-read' first, exactly like a real interactive startup
            ;; (and tests/ert/emacs-session.el's own established pattern for this) ---
            ;; otherwise `desktop-save' below would hit an interactive
            ;; "Overwrite this desktop file?" prompt instead of just saving, since it
            ;; would not yet consider itself to own this directory.
            (desktop-save dir) (desktop-release-lock dir)
            (let ((noninteractive nil)) (desktop-read dir))
            ;; mess everything up, the way the real sequence that motivated this did
            (menu-bar-mode -1) (tool-bar-mode 1)
            (set-frame-parameter nil 'undecorated t)
            (when (fboundp 'my/load-theme-by-number) (my/load-theme-by-number ?1))
            (my/reset-to-defaults)
            (should menu-bar-mode)
            (should-not tool-bar-mode)
            (should-not (frame-parameter nil 'undecorated))
            (should-not custom-enabled-themes)
            (should-not my/frame-chrome-hidden))
        (mapc #'disable-theme custom-enabled-themes)
        (menu-bar-mode (if menu-before 1 -1))
        (tool-bar-mode (if tool-before 1 -1))
        (set-frame-parameter nil 'undecorated undecorated-before)
        (dolist (theme themes-before) (load-theme theme t))
        (setq my/frame-chrome-hidden hidden-before)
        (ignore-errors (desktop-release-lock dir))))))

(ert-deftest config/source-files-are-well-formed ()
  (dolist (name '("init.el" "early-init.el"))
    (with-temp-buffer
      (insert-file-contents (expand-file-name name user-emacs-directory))
      (should (string-match-p "lexical-binding: t" (buffer-substring 1 (line-end-position))))
      (emacs-lisp-mode)
      (check-parens))))

;;; config.el ends here
