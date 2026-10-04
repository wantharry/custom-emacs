;;; pruning.el --- what the pruned install does and does not contain  -*- lexical-binding: t; -*-
;; harness: bare
;; Skipped on an unpruned build.

(ert-deftest pruning/removed-applications-are-gone ()
  (test-skip-unless-pruned)
  (dolist (l '("erc" "rcirc" "rmail" "mh-e"
               "tetris" "snake" "dunnet" "doctor" "zone" "pong"))
    (should-not (locate-library l))))

(ert-deftest pruning/coding-essentials-are-present ()
  (dolist (l '("eglot" "flymake" "project" "xref" "eldoc" "tramp" "transient" "use-package"
               "vc-git" "ediff" "smerge-mode" "dired" "compile" "grep" "treesit" "python"
               "js" "c-ts-mode" "which-key" "completion-preview" "ibuffer" "recentf"
               "ido" "icomplete" "package" "url" "json"))
    (should (locate-library l))))

;; `mm-archive' is the one real breakage this caught: the first pruned build was
;; checked only by `require'-ing every package and looked clean, but `url' loads
;; `gnus/mm-archive' lazily --- only when something actually fetches a URL --- so a
;; static dependency scan never saw it, and it was pruned anyway. Nothing failed until
;; `package-refresh-contents' itself broke with "Cannot open load file ... mm-archive".
;; Fixed with an explicit exception in `prune.list'; see docs/PRUNING.md ("What went
;; wrong the first time").
(ert-deftest pruning/lazily-needed-exceptions-are-kept ()
  (dolist (l '("mm-archive" "mm-decode" "message"))
    (should (locate-library l))))

;; WHAT: org itself is present, not pruned.  WHY: a real reversal, not the original
;; design --- see prune.list's own header and docs/PRUNING.md for why; kept as its own
;; test (not folded into `coding-essentials-are-present') so it stays easy to find if
;; this decision ever changes again.  `org-agenda' specifically (not just `org' itself)
;; because that is the one other package this project's own workflows actually touch.
(ert-deftest pruning/org-is-present ()
  (dolist (l '("org" "org-agenda"))
    (should (locate-library l))))

(ert-deftest pruning/other-applications-are-kept-on-purpose ()
  (dolist (l '("eshell" "eww" "calc" "calendar" "shr" "info" "newsticker" "newst-treeview"))
    (should (locate-library l))))

(ert-deftest pruning/requiring-a-removed-feature-fails-cleanly ()
  (test-skip-unless-pruned)
  (should-error (require 'tetris) :type 'file-missing))

;; WHAT: a stale autoload (the function is known, but its real file was removed) fails
;; with a clear load error rather than some more confusing failure.  WHY: `org-mode'
;; itself used to be the example here, back when `org' was pruned --- now that it is
;; kept (see `pruning/org-is-present'), `tetris' (a genuinely still-pruned game with its
;; own normal, real autoload in stock Emacs) exercises the exact same real behavior.
(ert-deftest pruning/stale-autoload-fails-with-a-load-error ()
  (test-skip-unless-pruned)
  (should (fboundp 'tetris))
  (should-error (tetris) :type 'file-missing))

(ert-deftest pruning/no-native-code-left-for-removed-packages ()
  (test-skip-unless-pruned)
  (let ((found (cl-loop for d in native-comp-eln-load-path
                        append (file-expand-wildcards (concat d "*/erc-*.eln")))))
    (should-not found)))

;;; pruning.el ends here
