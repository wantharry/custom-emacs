;;; pruning.el --- what the pruned install does and does not contain  -*- lexical-binding: t; -*-
;; harness: bare
;; Skipped on an unpruned build.

(ert-deftest pruning/removed-applications-are-gone ()
  (test-skip-unless-pruned)
  (dolist (l '("org" "org-agenda" "erc" "rcirc" "rmail" "mh-e" "newsticker"
               "tetris" "snake" "dunnet" "doctor" "zone" "pong"))
    (should-not (locate-library l))))

(ert-deftest pruning/coding-essentials-are-present ()
  (dolist (l '("eglot" "flymake" "project" "xref" "eldoc" "tramp" "transient" "use-package"
               "vc-git" "ediff" "smerge-mode" "dired" "compile" "grep" "treesit" "python"
               "js" "c-ts-mode" "which-key" "completion-preview" "ibuffer" "recentf"
               "ido" "icomplete" "package" "url" "json"))
    (should (locate-library l))))

(ert-deftest pruning/lazily-needed-exceptions-are-kept ()
  (dolist (l '("mm-archive" "mm-decode" "message" "org-macs" "org-element-ast"))
    (should (locate-library l))))

(ert-deftest pruning/other-applications-are-kept-on-purpose ()
  (dolist (l '("eshell" "eww" "calc" "calendar" "shr" "info"))
    (should (locate-library l))))

(ert-deftest pruning/requiring-a-removed-feature-fails-cleanly ()
  (test-skip-unless-pruned)
  (should-error (require 'org) :type 'file-missing)
  (should-error (require 'tetris) :type 'file-missing))

(ert-deftest pruning/stale-autoload-fails-with-a-load-error ()
  (test-skip-unless-pruned)
  (should (fboundp 'org-mode))
  (with-temp-buffer
    (should-error (org-mode) :type 'file-missing)))

(ert-deftest pruning/no-native-code-left-for-removed-packages ()
  (test-skip-unless-pruned)
  (let ((found (cl-loop for d in native-comp-eln-load-path
                        append (file-expand-wildcards (concat d "*/org-agenda-*.eln")))))
    (should-not found)))

;;; pruning.el ends here
