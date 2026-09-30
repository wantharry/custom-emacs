;;; wgrep.el --- wgrep loads lazily, and really saves edits back to disk  -*- lexical-binding: t; -*-
;; harness: config
;; The other 4 small extras this same batch added (avy, ace-window, helpful,
;; symbol-overlay) are plain global keys, already checked by tests/ert/keybindings.el
;; (against docs/KEYBOARD.md's own tables) and tests/ert/shortcuts.el (against
;; config/shortcuts.el) --- nothing bespoke needed for those here.  `wgrep' is different:
;; its one binding is mode-local (only exists inside a real `grep-mode' buffer, and only
;; once `wgrep' itself has loaded), and its real value is the edit-and-save-to-disk
;; round trip, which only a real `grep' invocation over a real file can exercise.
;;
;; Deliberately does NOT `(require 'grep)' at the top level: `grep'/`grep-mode' are
;; themselves autoloaded (confirmed directly), so requiring it here would load `grep.el'
;; --- and with it `wgrep', via this config's own `with-eval-after-load' --- before a
;; single real grep ever ran, hiding exactly the lazy-loading this file means to check.

(defun wg--run-grep-and-wait (dir pattern)
  "Run a real, synchronous grep for PATTERN in DIR and return its `*grep*' buffer."
  (let ((default-directory dir))
    (grep (format "grep -rn -e %s ." pattern)))
  (let ((buf (get-buffer "*grep*")) (tries 0))
    (while (and (get-buffer-process buf) (< tries 50))
      (accept-process-output nil 0.1)
      (setq tries (1+ tries)))
    buf))

(ert-deftest wgrep/is-not-loaded-at-startup ()
  ;; A real, separate subprocess, not an in-process check: this file's other tests
  ;; themselves use real grep and would otherwise leave `grep'/`wgrep' loaded for good in
  ;; the same Emacs image, making an in-process "still nil" check order-dependent on
  ;; which test ERT happens to run first (a real mistake, caught before it shipped).
  (should (locate-library "wgrep"))
  (let ((out (with-output-to-string
               (with-current-buffer standard-output
                 (call-process test-emacs nil t nil "--batch" "--init-directory" (getenv "CONFIG_DIR")
                               "-l" (expand-file-name "early-init.el" (getenv "CONFIG_DIR"))
                               "-l" (expand-file-name "init.el" (getenv "CONFIG_DIR"))
                               "--eval" "(princ (list (featurep 'grep) (featurep 'wgrep)))")))))
    (should (string-match-p "(nil nil)" out))))

(ert-deftest wgrep/loads-once-a-real-grep-actually-runs ()
  (test-with-temp-dir dir
    (test-write-file (concat dir "a.txt") "hello world\n")
    (unwind-protect
        (progn
          (wg--run-grep-and-wait dir "hello")
          (should (featurep 'wgrep)))
      (when (get-buffer "*grep*") (kill-buffer "*grep*")))))

(ert-deftest wgrep/c-c-c-p-is-bound-in-a-real-grep-buffer ()
  (test-with-temp-dir dir
    (test-write-file (concat dir "a.txt") "hello world\n")
    (unwind-protect
        (with-current-buffer (wg--run-grep-and-wait dir "hello")
          (should (eq (key-binding (kbd "C-c C-p")) 'wgrep-change-to-wgrep-mode)))
      (when (get-buffer "*grep*") (kill-buffer "*grep*")))))

(ert-deftest wgrep/editing-and-saving-really-writes-the-file-on-disk ()
  ;; The one bug this test exists to pin down: this config makes every file-visiting
  ;; buffer read-only by default (see tests/ert/readonly.el), and by default `wgrep'
  ;; silently REFUSES to save into a read-only buffer --- `wgrep-finish-edit' reports
  ;; "(0 changed)" with no further explanation, and the file on disk never actually
  ;; changes.  Confirmed for real (not assumed) before the fix: this exact scenario, run
  ;; against a real file, left it unmodified on disk.  Fixed with
  ;; `wgrep-change-readonly-file' set to `t' in config/init.el.
  (should (eq wgrep-change-readonly-file t))
  (test-with-temp-dir dir
    (let ((file (test-write-file (concat dir "a.txt") "hello world\n")))
      (unwind-protect
          (progn
            (with-current-buffer (wg--run-grep-and-wait dir "hello")
              (wgrep-change-to-wgrep-mode)
              (goto-char (point-min))
              (search-forward "./a.txt:1:")
              (kill-word 1)
              (insert "GOODBYE")
              (call-interactively #'wgrep-finish-edit)
              (call-interactively #'wgrep-save-all-buffers))
            (should (equal (test-read-file file) "GOODBYE world\n")))
        (when (get-buffer "*grep*") (kill-buffer "*grep*"))
        (when (get-file-buffer file) (kill-buffer (get-file-buffer file)))))))

;;; wgrep.el ends here
