;;; completion.el --- vertico/orderless/marginalia/embark, wired in and really working  -*- lexical-binding: t; -*-
;; harness: config
;; Needs vertico/orderless/marginalia/embark installed (./build.sh packages); the tests
;; that need them skip without them, falling back to checking the built-in
;; fido-vertical-mode instead -- the same pattern this config itself uses.
;;
;; `config/config.el's own `config/completion-setup' is the high-level "is everything on"
;; check; these are the deeper, functional ones -- real matching behavior, not just
;; "is the mode variable non-nil".

(defmacro cpl-need (&rest body)
  "Run BODY if vertico/orderless/marginalia are installed, else skip."
  (declare (indent 0))
  `(if (locate-library "vertico") (progn ,@body)
     (ert-skip "vertico/orderless/marginalia are not installed (./build.sh packages)")))

;;; Keys: embark, same optional-package-with-fallback shape as Consult

(ert-deftest completion/embark-keys-are-bound ()
  (if (locate-library "embark")
      (progn
        (should (eq (key-binding (kbd "C-.")) 'embark-act))
        (should (eq (key-binding (kbd "C-;")) 'embark-dwim))
        (should (eq (key-binding (kbd "C-h B")) 'embark-bindings)))
    (should (eq (key-binding (kbd "C-.")) 'my/embark-missing))))

(ert-deftest completion/embark-is-lazy-not-loaded-until-used ()
  ;; A fresh subprocess, not the shared test-file process: another test in this very
  ;; file (`embark-consult-loads-itself-automatically') deliberately `require's embark
  ;; for real, which would make embark-act look permanently loaded to any check run
  ;; afterward in the same process -- confirmed for real, that is exactly what happened
  ;; before this was rewritten this way.
  (if (locate-library "embark")
      (let ((out (with-output-to-string
                   (with-current-buffer standard-output
                     (call-process test-emacs nil t nil "--batch" "--init-directory" (getenv "CONFIG_DIR")
                                   "-l" (expand-file-name "early-init.el" (getenv "CONFIG_DIR"))
                                   "-l" (expand-file-name "init.el" (getenv "CONFIG_DIR"))
                                   "--eval" "(princ (list (featurep 'embark) (autoloadp (symbol-function 'embark-act))))")))))
        (should (string-match-p "(nil t)" out)))
    (ert-skip "embark is not installed (./build.sh packages)")))

(ert-deftest completion/embark-consult-loads-itself-automatically ()
  ;; No glue code was written for this on purpose -- Embark loads embark-consult on its
  ;; own once it notices Consult is also loaded (confirmed by reading its own commentary:
  ;; "The package will be loaded automatically by Embark"). This is what actually proves
  ;; that claim true here, not just cited.
  (if (and (locate-library "embark") (locate-library "embark-consult") (locate-library "consult"))
      (progn
        (require 'consult)
        (require 'embark)
        (should (featurep 'embark-consult)))
    (ert-skip "embark/embark-consult/consult are not all installed (./build.sh packages)")))

;;; The completion UI and style really are on, and really behave as intended

(ert-deftest completion/vertico-and-marginalia-are-on ()
  (cpl-need
    (should vertico-mode)
    (should marginalia-mode)
    (should-not fido-vertical-mode)))

(ert-deftest completion/orderless-matches-words-in-any-order ()
  ;; The actual point of orderless, not just "is it in completion-styles": space-
  ;; separated words match a candidate regardless of what order they're typed in.
  (cpl-need
    (should (completion-all-completions "to buf" '("switch-to-buffer" "unrelated") nil 5))
    (should (completion-all-completions "buf to" '("switch-to-buffer" "unrelated") nil 5))
    (should-not (completion-all-completions "xyz nomatch" '("switch-to-buffer") nil 5))))

(ert-deftest completion/flex-still-matches-a-fuzzy-skeleton ()
  ;; The real regression this whole setup caught: the previous completion-styles
  ;; (fido-vertical-mode's own) included `flex', which C-x p f (project-find-file) relies
  ;; on for exactly this kind of match; orderless's own default matching styles (literal
  ;; and regexp only) do not reproduce it on their own. See
  ;; tests/ert/java-navigation.el's jnav/a-partial-name-finds-the-file-by-fuzzy-matching
  ;; for the real, project-shaped version of this same check.
  (should (memq 'flex completion-styles))
  (should (completion-all-completions "gmtry" '("src/main/java/demo/Geometry.java") nil 5)))

(ert-deftest completion/file-completion-skips-orderless-but-keeps-flex ()
  ;; Deliberate: out-of-order matching is more useful for commands/buffers than file
  ;; paths (see init.el's own comment on why); flex stays available for files too.
  (cpl-need
    (let ((file-styles (cdr (assq 'styles (cdr (assq 'file completion-category-overrides))))))
      (should (memq 'flex file-styles))
      (should-not (memq 'orderless file-styles)))))

(ert-deftest completion/marginalia-gives-a-real-annotation-for-a-real-command ()
  (cpl-need
    (require 'marginalia)
    (let ((ann (marginalia-annotate-command "find-file")))
      (should (stringp ann))
      (should (string-match-p "Edit file" ann)))))

(ert-deftest completion/does-not-slow-startup ()
  (let ((best most-positive-fixnum))
    (dotimes (_ 3)
      (let ((t0 (float-time)))
        (call-process test-emacs nil nil nil "--batch" "--init-directory" (getenv "CONFIG_DIR")
                      "-l" (expand-file-name "early-init.el" (getenv "CONFIG_DIR"))
                      "-l" (expand-file-name "init.el" (getenv "CONFIG_DIR"))
                      "--eval" "(kill-emacs)")
        (setq best (min best (- (float-time) t0)))))
    (should (< best 0.5))))

;;; completion.el ends here
