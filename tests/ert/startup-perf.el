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
  ;; `browse-url' is checked here, not for its own sake, but as a second, independent
  ;; witness that `package.el' itself never got loaded: `package.el' loads `browse-url',
  ;; which is the actual PATH-searching cost init.el's own comment on this says to avoid
  ;; (see init.el on why `package.el' is deliberately not loaded at startup) --- so this
  ;; would catch `package' sneaking in some other way that left `featurep' on `package'
  ;; itself looking clean.
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
  (dolist (f '(magit treemacs consult doom-themes doom-modeline company lsp-mode projectile))
    (should-not (featurep f))))

(ert-deftest startup/load-path-does-not-contain-the-config-directory ()
  ;; Emacs prints a startup warning (visible in the terminal) if it does.
  (should-not (member (file-name-as-directory user-emacs-directory)
                      (mapcar #'file-name-as-directory load-path))))

(ert-deftest startup/file-finder-not-loaded-and-no-search-until-idle ()
  ;; The finder is autoloaded: nothing is read or indexed at startup.
  (should-not (featurep 'fastfind))
  (should (autoloadp (symbol-function 'my/ff-find-file)))
  (should (autoloadp (symbol-function 'my/ff-find-file-global))))

;;; startup-perf.el ends here
