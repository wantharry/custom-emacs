;;; gui-runner.el --- run the tests in tests/gui/ inside a real Emacs window  -*- lexical-binding: t; -*-
;; Started by tests/run-all.sh --gui, WITHOUT --batch, so a graphical frame exists.
;; A graphical session prints nothing to stdout, so results are written to the file
;; named by $GUI_LOG in the same format ERT's batch runner uses.

(require 'ert)
(require 'cl-lib)

(defvar gui-runner--log (getenv "GUI_LOG"))
(defvar gui-runner--lines nil)

(defun gui-runner--clean (string)
  "STRING with control and non-printing characters replaced, and cut to a sane length.
Failure conditions can print compiled-code objects; raw bytes in the log would make
`grep' treat it as binary."
  (let ((s (replace-regexp-in-string "[^[:print:]\n\t]" "?" string)))
    (if (> (length s) 700) (concat (substring s 0 700) " ...") s)))

(defun gui-runner--say (fmt &rest args)
  (push (gui-runner--clean (apply #'format fmt args)) gui-runner--lines))

(defun gui-runner--flush ()
  (with-temp-file gui-runner--log
    (insert (mapconcat #'identity (reverse gui-runner--lines) "\n") "\n")))

(defun gui-runner--listener (event-type &rest args)
  (pcase event-type
    ('test-ended
     (let* ((test (nth 1 args)) (result (nth 2 args)) (name (ert-test-name test)))
       (cond
        ((ert-test-skipped-p result)
         (gui-runner--say "   SKIPPED  %s" name))
        ((ert-test-result-expected-p test result)
         (gui-runner--say "   passed  %s" name))
        (t
         (gui-runner--say "Test %s condition:" name)
         (gui-runner--say "    %S" (let ((print-length 12) (print-level 5))
                             (ignore-errors (ert-test-result-with-condition-condition result))))
         (gui-runner--say "   FAILED  %s" name)))))
    ('run-ended
     (let ((stats (nth 0 args)))
       (gui-runner--say "\nRan %d tests, %d results as expected, %d unexpected, %d skipped"
                        (ert-stats-total stats)
                        (ert-stats-completed-expected stats)
                        (ert-stats-completed-unexpected stats)
                        (ert-stats-skipped stats))))))

(condition-case err
    (progn
      (dolist (f (directory-files (expand-file-name "tests/gui" test-root) t "\\.el\\'"))
        (unless (string-match-p "gui-runner" f) (load f nil t)))
      (let* ((sel (getenv "GUI_TESTS"))   ; optional regexp to run a subset
             (stats (ert-run-tests (if (and sel (not (string= sel ""))) `(and (tag gui) ,sel) '(tag gui))
                                   #'gui-runner--listener)))
        (gui-runner--flush)
        (kill-emacs (if (zerop (ert-stats-completed-unexpected stats)) 0 1))))
  (error
   (gui-runner--say "RUNNER ERROR: %S" err)
   (gui-runner--flush)
   (kill-emacs 2)))

;;; gui-runner.el ends here
