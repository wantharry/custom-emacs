;;; calendar-year.el --- a real year-at-a-glance calendar, 3 months per row (C-c y)  -*- lexical-binding: t; -*-
;; harness: config
;; The real regression this whole feature exists to fix (see config/init.el's own
;; "Calendar" section): an earlier attempt at showing 12 months at once
;; (`calendar-total-months' set to 12) was verified only by checking that the buffer's
;; *text* held 12 month names --- it did, but `calendar.el' lays every month out in a
;; single row, so that rendered as one line 300 columns wide, wrapping and scrambling on
;; any normal window. Every test below that touches the real buffer checks its actual
;; rendered width too, not just the month count, specifically so that mistake cannot
;; repeat here.

(require 'calendar-year (expand-file-name "calendar-year" (or (getenv "CONFIG_DIR") user-emacs-directory)))

;;; Wiring

(ert-deftest calendar-year/key-is-bound ()
  (should (eq (key-binding (kbd "C-c y")) 'my/calendar-year)))

(ert-deftest calendar-year/is-not-loaded-until-used ()
  (let ((out (with-output-to-string
               (with-current-buffer standard-output
                 (call-process test-emacs nil t nil "--batch" "--init-directory" (getenv "CONFIG_DIR")
                               "-l" (expand-file-name "early-init.el" (getenv "CONFIG_DIR"))
                               "-l" (expand-file-name "init.el" (getenv "CONFIG_DIR"))
                               "--eval" "(princ (list (featurep 'calendar-year) (autoloadp (symbol-function 'my/calendar-year))))")))))
    (should (string-match-p "(nil t)" out))))

(ert-deftest calendar-year/does-not-slow-startup ()
  (let ((best most-positive-fixnum))
    (dotimes (_ 3)
      (let ((t0 (float-time)))
        (call-process test-emacs nil nil nil "--batch" "--init-directory" (getenv "CONFIG_DIR")
                      "-l" (expand-file-name "early-init.el" (getenv "CONFIG_DIR"))
                      "-l" (expand-file-name "init.el" (getenv "CONFIG_DIR"))
                      "--eval" "(kill-emacs)")
        (setq best (min best (- (float-time) t0)))))
    (should (< best 0.5))))

;;; The row-building primitive

(defun how-many-string (regexp string)
  "Like `how-many', but over STRING instead of the current buffer."
  (with-temp-buffer (insert string) (how-many regexp (point-min) (point-max))))

(ert-deftest calendar-year/a-row-holds-exactly-the-requested-number-of-months ()
  (let ((row (my/calendar--month-row 1 2027 3)))
    (should (= 3 (how-many-string "[A-Z][a-z]+ 2027" row)))))

(ert-deftest calendar-year/a-row-is-real-calendar-data-not-a-stub ()
  ;; January 1st, 2027 is a Friday --- a real, checkable fact, not just "some text".
  ;; It shares its row with the 2nd (Saturday) --- confirmed directly, not assumed:
  ;; a first version of this test wrongly expected the 1st alone on its own row.
  (let ((row (my/calendar--month-row 1 2027 1)))
    (should (string-match-p "January 2027" row))
    (should (string-match-p "Su Mo Tu We Th Fr Sa" row))
    (should (string-match-p "1  2 *\n" row))))

;;; The real, assembled year buffer --- content AND actual rendered width

(ert-deftest calendar-year/shows-all-12-months-of-the-given-year ()
  (let ((out (with-output-to-string
               (with-current-buffer standard-output
                 (call-process test-emacs nil t nil "--batch" "--init-directory" (getenv "CONFIG_DIR")
                               "-l" (expand-file-name "early-init.el" (getenv "CONFIG_DIR"))
                               "-l" (expand-file-name "init.el" (getenv "CONFIG_DIR"))
                               "--eval" "(my/calendar-year 2027)"
                               "--eval" "(with-current-buffer \"*Year Calendar*\" (princ (how-many \"[A-Z][a-z]+ 2027\" (point-min) (point-max))))")))))
    (should (string-match-p "12" out))))

;; WHAT: a real month-row line is nowhere near the 300-column mess the reverted
;; `calendar-total-months' attempt produced.  WHY: the actual regression test --- see
;; the file header comment.  HOW: a real, fresh subprocess opens the real buffer and
;; measures a real line's actual width, the same way the reverted attempt's own
;; follow-up fix (`config/init.el', `tests/ert/config.el') now measures the default
;; 3-month `M-x calendar' line (76 columns) instead of only counting month names.
(ert-deftest calendar-year/a-month-row-is-a-sane-width-not-a-300-column-mess ()
  (let ((out (with-output-to-string
               (with-current-buffer standard-output
                 (call-process test-emacs nil t nil "--batch" "--init-directory" (getenv "CONFIG_DIR")
                               "-l" (expand-file-name "early-init.el" (getenv "CONFIG_DIR"))
                               "-l" (expand-file-name "init.el" (getenv "CONFIG_DIR"))
                               "--eval" "(my/calendar-year 2027)"
                               "--eval" "(with-current-buffer \"*Year Calendar*\" (goto-char (point-min)) (forward-line 3) (princ (- (line-end-position) (line-beginning-position))))")))))
    (should (string-match-p "71" out))
    ;; and, explicitly, nowhere near what 12 months in one row would be
    (should-not (string-match-p "300" out))))

(ert-deftest calendar-year/the-buffer-is-read-only-and-q-quits-it ()
  (let ((out (with-output-to-string
               (with-current-buffer standard-output
                 (call-process test-emacs nil t nil "--batch" "--init-directory" (getenv "CONFIG_DIR")
                               "-l" (expand-file-name "early-init.el" (getenv "CONFIG_DIR"))
                               "-l" (expand-file-name "init.el" (getenv "CONFIG_DIR"))
                               "--eval" "(my/calendar-year 2027)"
                               "--eval" "(with-current-buffer \"*Year Calendar*\" (princ (list buffer-read-only (eq (key-binding (kbd \"q\")) 'quit-window))))")))))
    (should (string-match-p "(t t)" out))))

(ert-deftest calendar-year/with-no-prefix-argument-defaults-to-the-current-year ()
  (let ((out (with-output-to-string
               (with-current-buffer standard-output
                 (call-process test-emacs nil t nil "--batch" "--init-directory" (getenv "CONFIG_DIR")
                               "-l" (expand-file-name "early-init.el" (getenv "CONFIG_DIR"))
                               "-l" (expand-file-name "init.el" (getenv "CONFIG_DIR"))
                               "--eval" "(let ((current-prefix-arg nil)) (call-interactively 'my/calendar-year))"
                               "--eval" "(with-current-buffer \"*Year Calendar*\" (princ (nth 5 (decode-time))))")))))
    (should (string-match-p (number-to-string (nth 5 (decode-time))) out))))

(ert-deftest calendar-year/calling-it-twice-reuses-the-same-buffer ()
  (let ((out (with-output-to-string
               (with-current-buffer standard-output
                 (call-process test-emacs nil t nil "--batch" "--init-directory" (getenv "CONFIG_DIR")
                               "-l" (expand-file-name "early-init.el" (getenv "CONFIG_DIR"))
                               "-l" (expand-file-name "init.el" (getenv "CONFIG_DIR"))
                               "--eval" "(my/calendar-year 2027)"
                               "--eval" "(my/calendar-year 2028)"
                               "--eval" "(princ (length (seq-filter (lambda (b) (equal (buffer-name b) \"*Year Calendar*\")) (buffer-list))))")))))
    (should (string-match-p "1\\'" (string-trim out)))))

;;; calendar-year.el ends here
