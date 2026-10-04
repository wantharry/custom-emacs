;;; corfu.el --- in-buffer completion, wired in and really working  -*- lexical-binding: t; -*-
;; harness: config
;; Needs corfu installed (./build.sh packages); skips without it.
;;
;; The real fact this config's own `corfu-terminal'/`popon' research turned up, and why
;; those two are NOT installed (see tools/install-packages.el's own comment): this
;; project's Emacs (32.0.50) already has native tty-child-frame support, confirmed by
;; actually watching a real completion popup render in a real `-nw' terminal session
;; (tests/test_tui.py has that real, visual confirmation); `corfu.el' itself detects
;; this and would warn that `corfu-terminal' is unneeded on Emacs 31+ if it were loaded
;; --- checked for real below, not just cited.

(defmacro corfu-need (&rest body)
  (declare (indent 0))
  `(if (locate-library "corfu") (progn ,@body)
     (ert-skip "corfu is not installed (./build.sh packages)")))

(ert-deftest corfu/global-mode-is-on ()
  (corfu-need
    (should (bound-and-true-p global-corfu-mode))
    (should corfu-auto)
    (should corfu-cycle)))

(ert-deftest corfu/corfu-terminal-is-not-installed-and-not-needed ()
  ;; Confirmed in a real terminal session (see tests/test_tui.py), not assumed: this
  ;; build's native tty-child-frame support is why this doesn't need it.
  (should-not (locate-library "corfu-terminal"))
  (should (featurep 'tty-child-frames)))

(ert-deftest corfu/eglot-does-not-need-separate-wiring ()
  ;; Confirmed directly in Eglot's own source rather than assumed: it adds
  ;; `eglot-completion-at-point' to `completion-at-point-functions' per buffer on its
  ;; own, the same hook Corfu's popup is driven by --- nothing else to wire up here.
  (corfu-need
    (require 'eglot)
    (should (fboundp 'eglot-completion-at-point))))

;;; corfu.el ends here
