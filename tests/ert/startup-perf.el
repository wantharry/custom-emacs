;;; startup-perf.el --- startup stays fast and lazy  -*- lexical-binding: t; -*-
;; harness: config
;; Regression guards.  On WSL, loading package.el costs ~0.7 s (PATH lookups
;; across Windows drives), so it must not happen at startup.

(defun sp--startup-seconds ()
  "Best of three wall-clock times to start Emacs with our config and exit."
  (let ((best most-positive-fixnum))
    (dotimes (_ 3)
      (let ((t0 (float-time)))
        (call-process test-emacs nil nil nil "--batch"
                      "--init-directory" (getenv "CONFIG_DIR")
                      "-l" (expand-file-name "early-init.el" (getenv "CONFIG_DIR"))
                      "-l" (expand-file-name "init.el" (getenv "CONFIG_DIR"))
                      "--eval" "(kill-emacs)")
        (setq best (min best (- (float-time) t0)))))
    best))

(ert-deftest startup/under-half-a-second ()
  (should (< (sp--startup-seconds) 0.5)))

(ert-deftest startup/package-el-not-loaded ()
  (should-not (featurep 'package))
  (should-not (featurep 'browse-url)))

(ert-deftest startup/evil-not-loaded ()
  (should-not (featurep 'evil))
  (should-not (bound-and-true-p evil-mode)))

(ert-deftest startup/language-support-costs-nothing-until-used ()
  ;; Grammars and language servers are only touched when a Java/Rust file is opened.
  (should-not (featurep 'treesit))
  (should-not (featurep 'eglot))
  (should-not (featurep 'jsonrpc)))

(ert-deftest startup/no-third-party-features-loaded ()
  (dolist (f '(magit doom-themes doom-modeline company lsp-mode projectile))
    (should-not (featurep f))))

;;; startup-perf.el ends here
