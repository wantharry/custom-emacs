;;; calendar-calc-help.el --- calendar, calc, time, help, info, customize  -*- lexical-binding: t; -*-
;; harness: bare

(require 'calendar) (require 'calc) (require 'time-date) (require 'help-fns) (require 'info)

(ert-deftest calendar/day-of-week ()
  (should (= 5 (calendar-day-of-week '(9 25 2026))))
  (should (equal (calendar-day-name '(9 25 2026)) "Friday")))

(ert-deftest calendar/leap-years-and-month-lengths ()
  (should (calendar-leap-year-p 2028))
  (should-not (calendar-leap-year-p 2100))
  (should (= 29 (calendar-last-day-of-month 2 2028)))
  (should (= 28 (calendar-last-day-of-month 2 2027))))

(ert-deftest calendar/absolute-date-roundtrip ()
  (should (equal (calendar-gregorian-from-absolute (calendar-absolute-from-gregorian '(2 29 2028)))
                 '(2 29 2028))))

(ert-deftest calc/arithmetic ()
  (should (equal (calc-eval "2+3*4") "14"))
  (should (equal (calc-eval "sqrt(16)") "4"))
  (should (equal (calc-eval "2^100") "1267650600228229401496703205376"))
  (should (equal (calc-eval "10 % 3") "1")))

(ert-deftest time/format-and-arithmetic ()
  (let ((d25 (encode-time '(0 0 0 25 9 2026 nil nil t)))
        (d26 (encode-time '(0 0 0 26 9 2026 nil nil t))))
    (should (equal (format-time-string "%F %T" d25 t) "2026-09-25 00:00:00"))
    (should (= 86400.0 (float-time (time-subtract d26 d25))))))

(ert-deftest time/parsing ()
  (should (= 2026 (decoded-time-year (parse-time-string "2026-09-25 10:11:12"))))
  (should (equal (seq-take (iso8601-parse "2026-09-25T10:11:12Z") 6) '(12 11 10 25 9 2026))))

(ert-deftest help/documentation-strings ()
  (should (string-match-p "car" (documentation 'car)))
  (defun help-test-fn (alpha &optional beta) "Doc." (list alpha beta))
  (should (equal (help-function-arglist 'help-test-fn) '(alpha &optional beta)))
  (should (> (length (documentation-property 'fill-column 'variable-documentation)) 10)))

(ert-deftest help/apropos-finds-symbols ()
  (should (equal (apropos-internal "\\`calendar-day-name\\'") '(calendar-day-name))))

(ert-deftest help/info-manuals-are-installed ()
  (should (Info-find-file "elisp" t))
  (should (Info-find-file "emacs" t)))

(ert-deftest customize/knows-user-options ()
  (should (custom-variable-p 'fill-column))
  (should (get 'calendar 'custom-group))
  (should-not (custom-variable-p 'lisp-test-not-an-option)))

;;; calendar-calc-help.el ends here
