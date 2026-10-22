;;; doom-modeline.el --- the mode-line replacement, nerd-icons gated on a real font check  -*- lexical-binding: t; -*-
;; harness: config
;; `find-font' needs a real display connection to mean anything (confirmed directly:
;; it returns nil for every font, installed or not, in a real --batch run with no
;; display) --- every test here mocks it instead of relying on this machine's own,
;; real, but untestable-in-batch set of installed fonts; see tests/ert/fonts.el's
;; own header comment for the same reasoning.

(defmacro dm-test-with-mocked-find-font (installed-names &rest body)
  "Run BODY with `find-font' faked to report exactly INSTALLED-NAMES (a list of
font family strings) as present, nothing else."
  (declare (indent 1))
  `(cl-letf (((symbol-function 'find-font)
              (lambda (spec) (and (member (font-get spec :name) ,installed-names) t))))
     ,@body))

(ert-deftest doom-modeline/feature-is-loadable ()
  (skip-unless (locate-library "doom-modeline"))
  (should (featurep 'doom-modeline)))

(ert-deftest doom-modeline/enabling-turns-the-mode-on ()
  ;; Does NOT start by forcing the mode off: `doom-modeline-mode''s own disable
  ;; path (`(setq helm-ag-show-status-function (default-value ...))') assumes the
  ;; ENABLE path already ran at least once in this process --- confirmed directly,
  ;; a real `void-variable' error toggling it off before ever toggling it on, in a
  ;; fresh `--batch' process where it genuinely never has been. A fresh process
  ;; already starts with the mode off, so there is nothing to force here anyway.
  (skip-unless (locate-library "doom-modeline"))
  (unwind-protect
      (progn
        (dm-test-with-mocked-find-font '("JetBrainsMono Nerd Font Mono")
          (my/doom-modeline-maybe-enable))
        (should doom-modeline-mode))
    (doom-modeline-mode -1)))

(ert-deftest doom-modeline/icon-font-is-the-one-actually-bundled ()
  ;; See tools/fonts/ and init.el's own font-selection comment --- this must stay the
  ;; exact real installed name `fc-scan' reports for tools/fonts/
  ;; JetBrainsMonoNerdFontMono.ttf, not a guessed/prettied-up version of the filename.
  (skip-unless (locate-library "doom-modeline"))
  (should (equal my/doom-modeline-icon-font "JetBrainsMono Nerd Font Mono")))

(ert-deftest doom-modeline/icons-enabled-when-the-bundled-font-is-installed ()
  (skip-unless (locate-library "doom-modeline"))
  (unwind-protect
      (dm-test-with-mocked-find-font (list my/doom-modeline-icon-font)
        (my/doom-modeline-maybe-enable)
        (should doom-modeline-icon)
        (should (equal nerd-icons-font-family my/doom-modeline-icon-font)))
    (doom-modeline-mode -1)))

(ert-deftest doom-modeline/icons-disabled-cleanly-when-the-font-is-not-installed ()
  "A real, checked-not-assumed gap: `doom-modeline' does not itself check whether
its configured icon font is actually present, and would otherwise silently try to
render glyphs from a non-existent font (a row of empty tofu boxes) instead of
falling back cleanly."
  (skip-unless (locate-library "doom-modeline"))
  (unwind-protect
      (dm-test-with-mocked-find-font '()   ; nothing is "installed"
        (my/doom-modeline-maybe-enable)
        (should-not doom-modeline-icon))
    (doom-modeline-mode -1)))

(ert-deftest doom-modeline/does-not-slow-startup ()
  (skip-unless (locate-library "doom-modeline"))
  (let ((best most-positive-fixnum))
    (dotimes (_ 3)
      (let ((t0 (float-time)))
        (call-process test-emacs nil nil nil "--batch" "--init-directory" (getenv "CONFIG_DIR")
                      "-l" (expand-file-name "early-init.el" (getenv "CONFIG_DIR"))
                      "-l" (expand-file-name "init.el" (getenv "CONFIG_DIR")) "--eval" "(kill-emacs)")
        (setq best (min best (- (float-time) t0)))))
    (should (< best (test-startup-budget)))))

;;; doom-modeline.el ends here
