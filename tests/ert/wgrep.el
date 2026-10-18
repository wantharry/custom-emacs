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

(ert-deftest wgrep/mode-turns-the-buffer-editable-and-exit-turns-it-back-read-only ()
  (test-with-temp-dir dir
    (test-write-file (concat dir "a.txt") "hello world\n")
    (unwind-protect
        (with-current-buffer (wg--run-grep-and-wait dir "hello")
          (should buffer-read-only)
          (wgrep-change-to-wgrep-mode)
          (should-not buffer-read-only)
          (call-interactively #'wgrep-exit)
          (should (eq major-mode 'grep-mode))
          (should buffer-read-only))
      (when (get-buffer "*grep*") (kill-buffer "*grep*")))))

(ert-deftest wgrep/editing-two-different-matched-files-and-saving-writes-both ()
  (test-with-temp-dir dir
    (let ((a (test-write-file (concat dir "a.txt") "hello world\n"))
          (b (test-write-file (concat dir "b.txt") "hello again\n")))
      (unwind-protect
          (progn
            (with-current-buffer (wg--run-grep-and-wait dir "hello")
              (wgrep-change-to-wgrep-mode)
              (goto-char (point-min))
              (search-forward "./a.txt:1:")
              (kill-word 1) (insert "AEDIT")
              (goto-char (point-min))
              (search-forward "./b.txt:1:")
              (kill-word 1) (insert "BEDIT")
              (call-interactively #'wgrep-finish-edit)
              (call-interactively #'wgrep-save-all-buffers))
            (should (equal (test-read-file a) "AEDIT world\n"))
            (should (equal (test-read-file b) "BEDIT again\n")))
        (when (get-buffer "*grep*") (kill-buffer "*grep*"))
        (when (get-file-buffer a) (kill-buffer (get-file-buffer a)))
        (when (get-file-buffer b) (kill-buffer (get-file-buffer b)))))))

(ert-deftest wgrep/marking-a-match-for-deletion-really-removes-that-line-on-save ()
  (test-with-temp-dir dir
    (let ((file (test-write-file (concat dir "a.txt") "hello world\nhello there\n")))
      (unwind-protect
          (progn
            (with-current-buffer (wg--run-grep-and-wait dir "hello")
              (wgrep-change-to-wgrep-mode)
              (goto-char (point-min))
              (search-forward "./a.txt:2:")
              (call-interactively #'wgrep-mark-deletion)
              (call-interactively #'wgrep-finish-edit)
              (call-interactively #'wgrep-save-all-buffers))
            (should (equal (test-read-file file) "hello world\n")))
        (when (get-buffer "*grep*") (kill-buffer "*grep*"))
        (when (get-file-buffer file) (kill-buffer (get-file-buffer file)))))))

(ert-deftest wgrep/aborting-changes-leaves-every-file-untouched-on-disk ()
  (test-with-temp-dir dir
    (let ((a (test-write-file (concat dir "a.txt") "hello world\n"))
          (b (test-write-file (concat dir "b.txt") "hello again\n")))
      (unwind-protect
          (progn
            (with-current-buffer (wg--run-grep-and-wait dir "hello")
              (wgrep-change-to-wgrep-mode)
              (goto-char (point-min))
              (search-forward "./a.txt:1:")
              (kill-word 1) (insert "EDITED")
              (goto-char (point-min))
              (search-forward "./b.txt:1:")
              (kill-word 1) (insert "CHANGED")
              (call-interactively #'wgrep-finish-edit)
              (ignore-errors (call-interactively #'wgrep-abort-changes)))
            (should (equal (test-read-file a) "hello world\n"))
            (should (equal (test-read-file b) "hello again\n")))
        (when (get-buffer "*grep*") (kill-buffer "*grep*"))
        (when (get-file-buffer a) (kill-buffer (get-file-buffer a)))
        (when (get-file-buffer b) (kill-buffer (get-file-buffer b)))))))

(ert-deftest wgrep/abort-changes-returns-to-plain-read-only-grep-mode ()
  (test-with-temp-dir dir
    (test-write-file (concat dir "a.txt") "hello world\n")
    (unwind-protect
        (with-current-buffer (wg--run-grep-and-wait dir "hello")
          (wgrep-change-to-wgrep-mode)
          (goto-char (point-min))
          (search-forward "./a.txt:1:")
          (kill-word 1) (insert "EDITED")
          (ignore-errors (call-interactively #'wgrep-abort-changes))
          (should (eq major-mode 'grep-mode))
          (should buffer-read-only))
      (when (get-buffer "*grep*") (kill-buffer "*grep*")))))

(ert-deftest wgrep/removing-one-change-keeps-the-other-edit-intact ()
  (test-with-temp-dir dir
    (let ((a (test-write-file (concat dir "a.txt") "hello world\n"))
          (b (test-write-file (concat dir "b.txt") "hello again\n")))
      (unwind-protect
          (progn
            (with-current-buffer (wg--run-grep-and-wait dir "hello")
              (wgrep-change-to-wgrep-mode)
              (goto-char (point-min))
              (search-forward "./a.txt:1:")
              (let ((beg (point)))
                (kill-word 1) (insert "AEDIT")
                (wgrep-remove-change beg (point))
                (goto-char (point-min))
                (search-forward "./b.txt:1:")
                (kill-word 1) (insert "BEDIT"))
              (call-interactively #'wgrep-finish-edit)
              (call-interactively #'wgrep-save-all-buffers))
            (should (equal (test-read-file a) "hello world\n"))
            (should (equal (test-read-file b) "BEDIT again\n")))
        (when (get-buffer "*grep*") (kill-buffer "*grep*"))
        (when (get-file-buffer a) (kill-buffer (get-file-buffer a)))
        (when (get-file-buffer b) (kill-buffer (get-file-buffer b)))))))

(ert-deftest wgrep/removing-all-changes-at-once-leaves-every-file-untouched ()
  (test-with-temp-dir dir
    (let ((a (test-write-file (concat dir "a.txt") "hello world\n"))
          (b (test-write-file (concat dir "b.txt") "hello again\n")))
      (unwind-protect
          (progn
            (with-current-buffer (wg--run-grep-and-wait dir "hello")
              (wgrep-change-to-wgrep-mode)
              (goto-char (point-min))
              (search-forward "./a.txt:1:")
              (kill-word 1) (insert "AEDIT")
              (goto-char (point-min))
              (search-forward "./b.txt:1:")
              (kill-word 1) (insert "BEDIT")
              (call-interactively #'wgrep-remove-all-change)
              (call-interactively #'wgrep-finish-edit)
              (call-interactively #'wgrep-save-all-buffers))
            (should (equal (test-read-file a) "hello world\n"))
            (should (equal (test-read-file b) "hello again\n")))
        (when (get-buffer "*grep*") (kill-buffer "*grep*"))
        (when (get-file-buffer a) (kill-buffer (get-file-buffer a)))
        (when (get-file-buffer b) (kill-buffer (get-file-buffer b)))))))

(ert-deftest wgrep/editing-two-matches-in-the-same-file-saves-both ()
  (test-with-temp-dir dir
    (let ((file (test-write-file (concat dir "a.txt") "hello world\nhello there\n")))
      (unwind-protect
          (progn
            (with-current-buffer (wg--run-grep-and-wait dir "hello")
              (wgrep-change-to-wgrep-mode)
              (goto-char (point-min))
              (search-forward "./a.txt:1:")
              (kill-word 1) (insert "FIRST")
              (goto-char (point-min))
              (search-forward "./a.txt:2:")
              (kill-word 1) (insert "SECOND")
              (call-interactively #'wgrep-finish-edit)
              (call-interactively #'wgrep-save-all-buffers))
            (should (equal (test-read-file file) "FIRST world\nSECOND there\n")))
        (when (get-buffer "*grep*") (kill-buffer "*grep*"))
        (when (get-file-buffer file) (kill-buffer (get-file-buffer file)))))))

(ert-deftest wgrep/finish-edit-updates-the-file-buffer-before-any-explicit-save ()
  ;; `wgrep-finish-edit' alone (no `wgrep-save-all-buffers' yet) already propagates the
  ;; edit into the real file-visiting buffer in memory --- confirmed directly --- even
  ;; though nothing has reached disk until the separate save step runs.
  (test-with-temp-dir dir
    (let ((file (test-write-file (concat dir "a.txt") "hello world\n")))
      (unwind-protect
          (progn
            (with-current-buffer (wg--run-grep-and-wait dir "hello")
              (wgrep-change-to-wgrep-mode)
              (goto-char (point-min))
              (search-forward "./a.txt:1:")
              (kill-word 1) (insert "EDITED")
              (call-interactively #'wgrep-finish-edit))
            (should (buffer-modified-p (get-file-buffer file)))
            (with-current-buffer (get-file-buffer file)
              (should (equal (buffer-string) "EDITED world\n")))
            (should (equal (test-read-file file) "hello world\n")))
        (when (get-buffer "*grep*") (kill-buffer "*grep*"))
        (when (get-file-buffer file) (kill-buffer (get-file-buffer file)))))))

(ert-deftest wgrep/finishing-edit-with-no-changes-reports-nothing-to-do ()
  (test-with-temp-dir dir
    (test-write-file (concat dir "a.txt") "hello world\n")
    (unwind-protect
        (with-current-buffer (wg--run-grep-and-wait dir "hello")
          (wgrep-change-to-wgrep-mode)
          (should-not (buffer-modified-p))
          (should (equal (call-interactively #'wgrep-finish-edit) "(No changes to be performed)")))
      (when (get-buffer "*grep*") (kill-buffer "*grep*")))))

(ert-deftest wgrep/c-x-c-s-in-wgrep-mode-finishes-the-edit-not-plain-save-buffer ()
  ;; A real, found-by-testing gotcha: `wgrep-mode-map' rebinds `C-x C-s' itself (alongside
  ;; `C-c C-e'/`C-c C-c') to `wgrep-finish-edit' --- confirmed directly against the real
  ;; keymap --- so the muscle-memory save chord does the right thing here too, not a
  ;; buffer-read-only error from plain `save-buffer'.
  (test-with-temp-dir dir
    (let ((file (test-write-file (concat dir "a.txt") "hello world\n")))
      (unwind-protect
          (progn
            (with-current-buffer (wg--run-grep-and-wait dir "hello")
              (wgrep-change-to-wgrep-mode)
              (should (eq (key-binding (kbd "C-x C-s")) 'wgrep-finish-edit))
              (goto-char (point-min))
              (search-forward "./a.txt:1:")
              (kill-word 1) (insert "SAVED")
              (call-interactively (key-binding (kbd "C-x C-s")))
              (call-interactively #'wgrep-save-all-buffers))
            (should (equal (test-read-file file) "SAVED world\n")))
        (when (get-buffer "*grep*") (kill-buffer "*grep*"))
        (when (get-file-buffer file) (kill-buffer (get-file-buffer file)))))))

(ert-deftest wgrep/editing-a-context-line-under--c-also-saves-to-disk ()
  ;; `grep -C' context lines (the ones without their own `:' match marker, shown as
  ;; `file-N-text' instead of `file:N:text') are NOT read-only in wgrep-mode --- confirmed
  ;; directly against the real text properties --- so editing the surrounding context, not
  ;; just the matched line itself, is real, supported wgrep behavior worth pinning down.
  (test-with-temp-dir dir
    (let ((file (test-write-file (concat dir "a.txt") "hello world\nplain line\nhello again\n")))
      (unwind-protect
          (progn
            (with-current-buffer (wg--run-grep-and-wait dir "hello")
              (kill-buffer) ; the -C run below needs its own fresh *grep* buffer
              nil)
            (let ((default-directory dir))
              (grep "grep -rn -C1 -e hello ."))
            (let ((buf (get-buffer "*grep*")) (tries 0))
              (while (and (get-buffer-process buf) (< tries 50))
                (accept-process-output nil 0.1) (setq tries (1+ tries))))
            (with-current-buffer "*grep*"
              (wgrep-change-to-wgrep-mode)
              (goto-char (point-min))
              (search-forward "plain line")
              (backward-word 2) (kill-word 1) (insert "CONTEXT")
              (call-interactively #'wgrep-finish-edit)
              (call-interactively #'wgrep-save-all-buffers))
            (should (equal (test-read-file file) "hello world\nCONTEXT line\nhello again\n")))
        (when (get-buffer "*grep*") (kill-buffer "*grep*"))
        (when (get-file-buffer file) (kill-buffer (get-file-buffer file)))))))

(ert-deftest wgrep/the-filename-and-line-number-prefix-cannot-be-edited ()
  ;; The `./a.txt:1:' prefix itself carries a real `read-only' text property (confirmed
  ;; directly) --- unlike the matched text after it, trying to delete so much as one
  ;; character of the prefix must signal `text-read-only', not silently succeed.
  (test-with-temp-dir dir
    (test-write-file (concat dir "a.txt") "hello world\n")
    (unwind-protect
        (with-current-buffer (wg--run-grep-and-wait dir "hello")
          (wgrep-change-to-wgrep-mode)
          (goto-char (point-min))
          (search-forward "./a.txt:1:")
          (backward-char 2)
          (should-error (delete-char -1) :type 'text-read-only))
      (when (get-buffer "*grep*") (kill-buffer "*grep*")))))

(ert-deftest wgrep/removing-a-deletion-mark-restores-the-line-instead-of-deleting-it ()
  ;; `wgrep-remove-change' undoes a specific pending change --- including a deletion mark
  ;; from `wgrep-mark-deletion', not just a text edit --- confirmed directly: the line
  ;; comes back exactly as it was, rather than staying scheduled for removal.
  (test-with-temp-dir dir
    (let ((file (test-write-file (concat dir "a.txt") "hello world\nhello there\n")))
      (unwind-protect
          (progn
            (with-current-buffer (wg--run-grep-and-wait dir "hello")
              (wgrep-change-to-wgrep-mode)
              (goto-char (point-min))
              (search-forward "./a.txt:2:")
              (let ((beg (line-beginning-position)))
                (call-interactively #'wgrep-mark-deletion)
                (wgrep-remove-change beg (line-end-position)))
              (should (equal (call-interactively #'wgrep-finish-edit) "(No changes to be performed)")))
            (should (equal (test-read-file file) "hello world\nhello there\n")))
        (when (get-buffer "*grep*") (kill-buffer "*grep*"))
        (when (get-file-buffer file) (kill-buffer (get-file-buffer file)))))))

(ert-deftest wgrep/two-separate-grep-sessions-save-independently ()
  ;; No leftover state from one wgrep session (pending edits, the `*grep*' buffer itself)
  ;; bleeds into a completely separate later one --- run two full edit-and-save round
  ;; trips in a row, each against its own directory, and confirm both land correctly.
  (test-with-temp-dir dir1
    (test-with-temp-dir dir2
      (let ((a (test-write-file (concat dir1 "a.txt") "hello first\n"))
            (b (test-write-file (concat dir2 "b.txt") "hello second\n")))
        (unwind-protect
            (progn
              (with-current-buffer (wg--run-grep-and-wait dir1 "hello")
                (wgrep-change-to-wgrep-mode)
                (goto-char (point-min))
                (search-forward "./a.txt:1:")
                (kill-word 1) (insert "ONE")
                (call-interactively #'wgrep-finish-edit)
                (call-interactively #'wgrep-save-all-buffers))
              (kill-buffer "*grep*")
              (with-current-buffer (wg--run-grep-and-wait dir2 "hello")
                (wgrep-change-to-wgrep-mode)
                (goto-char (point-min))
                (search-forward "./b.txt:1:")
                (kill-word 1) (insert "TWO")
                (call-interactively #'wgrep-finish-edit)
                (call-interactively #'wgrep-save-all-buffers))
              (should (equal (test-read-file a) "ONE first\n"))
              (should (equal (test-read-file b) "TWO second\n")))
          (when (get-buffer "*grep*") (kill-buffer "*grep*"))
          (when (get-file-buffer a) (kill-buffer (get-file-buffer a)))
          (when (get-file-buffer b) (kill-buffer (get-file-buffer b))))))))

(ert-deftest wgrep/toggle-readonly-area-command-is-interactive-and-runs-without-error ()
  ;; The one wgrep command this file does not otherwise exercise --- just confirm it is
  ;; a real, callable command in a real wgrep buffer, since its own effect (whether the
  ;; non-match header text becomes directly editable) is an internal detail wgrep itself
  ;; does not document as a stable return value to assert on.
  (test-with-temp-dir dir
    (test-write-file (concat dir "a.txt") "hello world\n")
    (unwind-protect
        (with-current-buffer (wg--run-grep-and-wait dir "hello")
          (wgrep-change-to-wgrep-mode)
          (should (commandp 'wgrep-toggle-readonly-area))
          (should-not (condition-case nil (progn (call-interactively #'wgrep-toggle-readonly-area) nil)
                        (error t))))
      (when (get-buffer "*grep*") (kill-buffer "*grep*")))))

;;; wgrep.el ends here
