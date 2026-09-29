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
                 '(("World"  "http://feeds.bbci.co.uk/news/world/rss.xml")
                   ("USA"    "https://rss.nytimes.com/services/xml/rss/nyt/US.xml")
                   ("Sports" "https://www.espn.com/espn/rss/news"))))
  ;; every URL really is one (catches a typo before it ever reaches a real fetch)
  (dolist (feed newsticker-url-list)
    (should (string-match-p "\\`https?://" (nth 1 feed)))))

(ert-deftest config/news-uses-built-in-networking-not-an-external-program ()
  ;; So this works the same on the Windows bundle, which has no `wget'. A guard against
  ;; newsticker's own upstream default ever changing, not something this config sets
  ;; itself --- so load it first to see its real default.
  (require 'newst-backend)
  (should (eq newsticker-retrieval-method 'intern)))

(ert-deftest config/news-is-not-loaded-or-fetched-at-startup ()
  (let ((out (with-output-to-string
               (with-current-buffer standard-output
                 (call-process test-emacs nil t nil "--batch" "--init-directory" (getenv "CONFIG_DIR")
                               "-l" (expand-file-name "early-init.el" (getenv "CONFIG_DIR"))
                               "-l" (expand-file-name "init.el" (getenv "CONFIG_DIR"))
                               "--eval" "(princ (list (featurep 'newsticker) (autoloadp (symbol-function 'newsticker-treeview))))")))))
    (should (string-match-p "(nil t)" out))))

(ert-deftest config/completion-setup ()
  (should fido-vertical-mode)
  (should global-completion-preview-mode)
  (should which-key-mode)
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
  (should (eq (key-binding (kbd "C-c v")) 'my/toggle-evil)))

(ert-deftest config/source-files-are-well-formed ()
  (dolist (name '("init.el" "early-init.el"))
    (with-temp-buffer
      (insert-file-contents (expand-file-name name user-emacs-directory))
      (should (string-match-p "lexical-binding: t" (buffer-substring 1 (line-end-position))))
      (emacs-lisp-mode)
      (check-parens))))

;;; config.el ends here
