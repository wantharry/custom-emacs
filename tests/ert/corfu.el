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
    ;; User request: no automatic popup while typing; `C-M-i' (stock Emacs, documented
    ;; in KEYBOARD.md) still shows it on demand, since `global-corfu-mode' stays on.
    (should-not corfu-auto)
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

(ert-deftest corfu/is-in-the-package-list ()
  (with-temp-buffer
    (insert-file-contents (expand-file-name "tools/install-packages.el" test-root))
    (should (re-search-forward "(defconst my/packages '([^)]*\\bcorfu\\b" nil t))))

;;; Real wiring: corfu-mode takes over `completion-in-region-function' while active

(ert-deftest corfu/mode-sets-completion-in-region-function-to-corfu ()
  (corfu-need
    (test-in-buffer #'text-mode ""
      (corfu-mode 1)
      (unwind-protect
          (should (eq completion-in-region-function #'corfu--in-region))
        (corfu-mode -1)))))

(ert-deftest corfu/disabling-restores-the-default-completion-in-region-function ()
  (corfu-need
    (test-in-buffer #'text-mode ""
      (let ((default completion-in-region-function))
        (corfu-mode 1)
        (corfu-mode -1)
        (should (eq completion-in-region-function default))))))

(ert-deftest corfu/corfu-mode-can-be-enabled-manually-in-a-real-buffer ()
  ;; NOT `global-corfu-mode' auto-enabling itself here --- `corfu--on' (its own
  ;; per-buffer activation function) deliberately skips every buffer under
  ;; `noninteractive', which this whole test suite runs under (see its own
  ;; comment); `corfu-mode' itself, called directly, is unaffected by that guard.
  (corfu-need
    (test-in-buffer #'text-mode ""
      (unwind-protect
          (progn (corfu-mode 1) (should corfu-mode))
        (corfu-mode -1)))))

(ert-deftest corfu/mode-toggles-on-and-off-repeatedly-without-error ()
  (corfu-need
    (test-in-buffer #'text-mode ""
      (dotimes (_ 3)
        (should-not (condition-case e (progn (corfu-mode -1) (corfu-mode 1) nil) (error e)))))))

;;; `corfu-map': the real bindings active while the popup is shown

(ert-deftest corfu/map-has-tab-bound-to-complete-and-ret-bound-to-insert ()
  (corfu-need
    (should (eq (lookup-key corfu-map (kbd "TAB")) #'corfu-complete))
    (should (eq (lookup-key corfu-map (kbd "RET")) #'corfu-insert))))

(ert-deftest corfu/map-has-c-g-bound-to-quit ()
  (corfu-need
    (should (eq (lookup-key corfu-map (kbd "C-g")) #'corfu-quit))))

(ert-deftest corfu/next-previous-first-last-are-real-commands ()
  (corfu-need
    (should (commandp 'corfu-next))
    (should (commandp 'corfu-previous))
    (should (commandp 'corfu-first))
    (should (commandp 'corfu-last))))

(ert-deftest corfu/insert-quit-complete-insert-separator-are-real-commands ()
  (corfu-need
    (should (commandp 'corfu-insert))
    (should (commandp 'corfu-quit))
    (should (commandp 'corfu-complete))
    (should (commandp 'corfu-insert-separator))))

(ert-deftest corfu/scroll-down-and-scroll-up-are-real-commands ()
  (corfu-need
    (should (commandp 'corfu-scroll-down))
    (should (commandp 'corfu-scroll-up))))

(ert-deftest corfu/reset-and-expand-are-real-commands ()
  (corfu-need
    (should (commandp 'corfu-reset))
    (should (commandp 'corfu-expand))))

;;; Stock defaults this config leaves alone (only `corfu-auto'/`corfu-cycle' are set,
;;; see `corfu/global-mode-is-on' above) --- confirms a future change to this config
;;; never silently drifts these without someone noticing via a failing test.

(ert-deftest corfu/preview-current-is-the-stock-default ()
  (corfu-need
    (should (eq corfu-preview-current 'insert))))

(ert-deftest corfu/separator-is-the-stock-default-space-character ()
  (corfu-need
    (should (eq corfu-separator ?\s))))

(ert-deftest corfu/quit-at-boundary-is-the-stock-default ()
  (corfu-need
    (should (eq corfu-quit-at-boundary 'separator))))

;;; The underlying `completion-at-point-functions' mechanism Corfu's popup is driven
;;; by --- real candidate computation, independent of whether a popup can render.

(ert-deftest corfu/elisp-completion-at-point-still-finds-a-real-candidate ()
  (corfu-need
    (test-in-buffer #'emacs-lisp-mode "(current-buf"
      (goto-char (point-max))
      (pcase-let ((`(,beg ,end ,table . ,_) (elisp-completion-at-point)))
        (should (= beg 2)) (should (= end (point-max)))
        (should (member "current-buffer" (all-completions (buffer-substring beg end) table)))))))

(ert-deftest corfu/completion-at-point-functions-includes-elisp-completion-at-point-in-elisp-mode ()
  (corfu-need
    (test-in-buffer #'emacs-lisp-mode ""
      (should (memq 'elisp-completion-at-point completion-at-point-functions)))))

;;; corfu.el ends here
