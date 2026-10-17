;;; diff-hl.el --- live git change indicators, wired in and really working  -*- lexical-binding: t; -*-
;; harness: config
;; Needs diff-hl installed (./build.sh packages); skips without it, the same pattern
;; this config itself uses everywhere else.
;;
;; The real, found-while-researching-this fact this file exists to pin down: diff-hl's
;; default indicators use the FRINGE, which --- confirmed directly in its own source
;; (`(when (window-system) ...)' guards that code) --- does not exist at all in a `-nw'
;; terminal session; without also turning on `diff-hl-margin-mode' there, this feature
;; would be silently invisible in exactly the environment this project's own test
;; harness (and the user's own daily use) both run through. See tests/test_tui.py for
;; the real, visual confirmation (a `+' character actually drawn in the margin); this
;; file checks the underlying plumbing in a real git repo instead, which --batch can do
;; without a display.

(require 'vc-git)

(defmacro dhl-need (&rest body)
  (declare (indent 0))
  `(if (locate-library "diff-hl") (progn ,@body)
     (ert-skip "diff-hl is not installed (./build.sh packages)")))

(ert-deftest diff-hl/global-mode-is-on ()
  (dhl-need
    (should (bound-and-true-p global-diff-hl-mode))))

(ert-deftest diff-hl/dired-mode-is-hooked ()
  (dhl-need
    (should (memq 'diff-hl-dired-mode dired-mode-hook))))

(ert-deftest diff-hl/margin-mode-is-on-in-a-terminal-session ()
  ;; A real --batch process has no display either, the same as `-nw' --- confirmed
  ;; directly: `(display-graphic-p)' returns nil here too, so this is a faithful stand-in
  ;; for the terminal case init.el's own `(unless (display-graphic-p) ...)' guard means
  ;; to cover.
  (dhl-need
    (should-not (display-graphic-p))
    (should (bound-and-true-p diff-hl-margin-mode))))

(ert-deftest diff-hl/detects-a-real-uncommitted-change ()
  (dhl-need
    (test-with-temp-dir d
      (test-git d "init" "-q")
      (test-write-file (concat d "a.txt") "one\ntwo\nthree\n")
      (test-git d "add" "a.txt")
      (test-git d "commit" "-q" "-m" "first")
      (test-write-file (concat d "a.txt") "one\nTWO\nthree\nfour\n")
      (let ((default-directory d))
        (with-current-buffer (find-file-noselect (concat d "a.txt"))
          (unwind-protect
              (progn
                (vc-file-clearprops (concat d "a.txt"))
                (should (diff-hl-changes)))
            (kill-buffer)))))))

;;; diff-hl.el ends here
