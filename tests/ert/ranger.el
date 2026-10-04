;;; ranger.el --- a genuinely separate ranger-style file manager  -*- lexical-binding: t; -*-
;; harness: config
;; Needs ranger installed (./build.sh packages); skips without it.
;;
;; The real finding this file exists to pin down: `dirvish' (a newer, more popular
;; alternative) was tried FIRST and rejected for the explicit "keep plain Dired as-is,
;; add this as a genuinely separate thing" requirement --- confirmed directly, not
;; assumed, that its own standalone `dirvish' command does nothing at all (no Miller
;; columns, no session tracking) unless the GLOBAL `dirvish-override-dired-mode' is
;; also turned on, which would then apply to plain `dired'/`C-x d' too. `ranger-mode'
;; has no such requirement --- see init.el's own, much longer comment for the full
;; account.

(defmacro ranger-need (&rest body)
  (declare (indent 0))
  `(if (locate-library "ranger") (progn (require 'ranger) ,@body)
     (ert-skip "ranger is not installed (./build.sh packages)")))

(ert-deftest ranger/key-is-bound ()
  (ranger-need
    (should (eq (key-binding (kbd "C-c R")) 'ranger))))

(ert-deftest ranger/override-dired-is-off ()
  ;; The one thing that would silently turn this back into "mingled with Dired" ---
  ;; confirmed off, not just never explicitly turned on, in case some future change
  ;; (or the package's own default) flips it.
  (ranger-need
    (should-not (bound-and-true-p ranger-override-dired))))

(ert-deftest ranger/does-not-silently-rebind-c-p-in-plain-dired ()
  ;; A real, found-the-hard-way regression: `ranger.el' has a top-level `(when
  ;; ranger-key (add-hook 'dired-mode-hook ...))' that installs its own `C-p' binding
  ;; (its default `ranger-key') into the SHARED, GLOBAL `dired-mode-map' the first time
  ;; ANY Dired buffer is opened after `ranger.el' has loaded --- confirmed directly by
  ;; loading it for real and opening a plain Dired buffer afterward, with `C-p'
  ;; (normally `previous-line' everywhere) silently becoming `deer-from-dired'.
  ;; init.el pre-sets `ranger-key' to nil before the library ever loads specifically to
  ;; stop this; this test opens a REAL, fresh Dired buffer (not reusing one already
  ;; open before `ranger' loaded, which wouldn't re-trigger the hook) to confirm it.
  (ranger-need
    (test-with-temp-dir d
      (let ((buf (dired-noselect d)))
        (unwind-protect
            (should-not (eq (lookup-key dired-mode-map (kbd "C-p")) 'deer-from-dired))
          (kill-buffer buf))))))

(ert-deftest ranger/surviving-ranger-autoloads-loading-on-its-own ()
  ;; The REAL failure mode this whole fix exists for, reproduced directly rather than
  ;; just trusting the first-layer fix above: something outside this config's control
  ;; (not fully traced down; possibly this build's own async native-compilation queue)
  ;; was observed, in a real `-nw' session, to load `ranger-autoloads' --- without
  ;; `ranger' itself ever loading --- early enough that a plain `(setq ranger-key nil)'
  ;; in init.el had already lost the race, breaking `C-p' in every Dired buffer with a
  ;; real "Wrong type argument: arrayp, nil" error the moment one was opened. Loading
  ;; `ranger-autoloads' here directly (not `ranger') is the one way to reproduce that
  ;; exact scenario; init.el's `with-eval-after-load' fix must survive it regardless of
  ;; what triggers that load or when. A fresh subprocess, not the shared test-file
  ;; process, is required for this one --- another test in this very file
  ;; (`does-not-silently-rebind-c-p-in-plain-dired', via `ranger-need') may already
  ;; have `require'd `ranger' itself for real by the time this runs, which would make
  ;; `(require 'ranger-autoloads)' here a complete no-op (feature already satisfied)
  ;; and silently not reproduce anything --- the same reasoning
  ;; tests/ert/completion.el's own `embark-is-lazy-not-loaded-until-used' test uses.
  (if (not (locate-library "ranger-autoloads"))
      (ert-skip "ranger is not installed (./build.sh packages)")
    (let ((out (with-output-to-string
                 (with-current-buffer standard-output
                   (call-process test-emacs nil t nil "--batch" "--init-directory" (getenv "CONFIG_DIR")
                                 "-l" (expand-file-name "early-init.el" (getenv "CONFIG_DIR"))
                                 "-l" (expand-file-name "init.el" (getenv "CONFIG_DIR"))
                                 "--eval" "(require 'ranger-autoloads)"
                                 "--eval" "(let ((buf (dired-noselect \"/tmp\"))) (princ (eq (lookup-key dired-mode-map (kbd \"C-p\")) 'deer-from-dired)) (kill-buffer buf))")))))
      (should (string-suffix-p "nil" out)))))

(ert-deftest ranger/is-a-real-derived-mode-not-advice-based ()
  ;; The actual architectural fact that made `ranger' the right choice over `dirvish':
  ;; confirmed directly against the real installed source, not cited from memory.
  (ranger-need
    (should (eq (get 'ranger-mode 'derived-mode-parent) 'dired-mode))))

(ert-deftest ranger/reference-panel-is-excluded-so-it-does-not-fight-rangers-own-layout ()
  ;; A real, found-in-a-live-terminal-session bug this test pins down: `ranger-mode' IS
  ;; `dired-mode' underneath (the test above), so without an explicit exclusion,
  ;; `my/mode-reference-mode' (mode-reference.el, hooked to `dired-mode-hook') would
  ;; claim the exact side-window slot `ranger''s own Miller-columns preview pane needs
  ;; --- confirmed visually in a real `-nw' session before this exclusion was added.
  (ranger-need
    (test-with-temp-dir d
      (let ((buf (dired-noselect d)))
        (unwind-protect
            (with-current-buffer buf
              (ranger-mode)
              (should-not (my/mode-reference--relevant-mode)))
          (kill-buffer buf))))))

(ert-deftest ranger/plain-dired-still-shows-the-reference-panel ()
  ;; The other half of "genuinely separate": plain Dired (not opened through `ranger')
  ;; must be completely unaffected by any of this.
  (test-with-temp-dir d
    (with-current-buffer (dired-noselect d)
      (unwind-protect
          (should (eq (my/mode-reference--relevant-mode) 'dired-mode))
        (kill-buffer)))))

;;; ranger.el ends here
