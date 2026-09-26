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
