;;; config.el --- our init.el / early-init.el take effect  -*- lexical-binding: t; -*-
;; harness: config

(ert-deftest config/init-file-reloads-cleanly ()
  (let ((init (expand-file-name "init.el" user-emacs-directory)))
    (should (file-exists-p init))
    (should (load init nil t))))

(ert-deftest config/no-theme-enabled ()
  (should (null custom-enabled-themes)))

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
  (should (eq (key-binding (kbd "M-o")) 'other-window))
  (should (eq (key-binding (kbd "C-c r")) 'recentf-open))
  (should (eq (key-binding (kbd "C-c v")) 'my/toggle-evil))
  (should (eq (key-binding (kbd "C-c w s")) 'my/session-save))
  (should (eq (key-binding (kbd "C-c w r")) 'my/session-reset))
  (should (eq (key-binding (kbd "C-c w l")) 'my/session-list))
  (should (eq (key-binding (kbd "C-c w S")) 'my/session-save-as))
  (should (eq (key-binding (kbd "C-c w O")) 'my/session-open))
  (should (eq (key-binding (kbd "C-c w D")) 'my/session-delete))
  (should (eq (key-binding (kbd "C-c w L")) 'my/session-named-list)))

(ert-deftest config/source-files-are-well-formed ()
  (dolist (name '("init.el" "early-init.el"))
    (with-temp-buffer
      (insert-file-contents (expand-file-name name user-emacs-directory))
      (should (string-match-p "lexical-binding: t" (buffer-substring 1 (line-end-position))))
      (emacs-lisp-mode)
      (check-parens))))

;;; config.el ends here
