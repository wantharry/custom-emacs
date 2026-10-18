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

(ert-deftest calendar/day-number-counts-days-since-the-start-of-the-year ()
  (should (= 1 (calendar-day-number '(1 1 2026))))
  (should (= 365 (calendar-day-number '(12 31 2026))))
  (should (= 366 (calendar-day-number '(12 31 2028)))))

(ert-deftest calendar/month-and-day-name-arrays-are-populated ()
  (should (equal (aref calendar-month-name-array 0) "January"))
  (should (equal (aref calendar-day-name-array 0) "Sunday")))

(ert-deftest calendar/days-between-two-dates-via-absolute-numbers ()
  (should (= 365 (- (calendar-absolute-from-gregorian '(1 1 2027))
                    (calendar-absolute-from-gregorian '(1 1 2026)))))
  (should (= 366 (- (calendar-absolute-from-gregorian '(1 1 2029))
                    (calendar-absolute-from-gregorian '(1 1 2028))))))

(ert-deftest calc/trigonometric-functions-in-degree-mode ()
  (let ((calc-angle-mode 'deg))
    (should (equal (calc-eval "sin(90)") "1"))
    (should (equal (calc-eval "cos(0)") "1"))))

(ert-deftest calc/gcd-and-lcm ()
  (should (equal (calc-eval "gcd(12,18)") "6"))
  (should (equal (calc-eval "lcm(4,6)") "12")))

(ert-deftest calc/boolean-comparisons-return-one-or-zero ()
  (should (equal (calc-eval "5>3") "1"))
  (should (equal (calc-eval "2>5") "0"))
  (should (equal (calc-eval "3=3") "1")))

(ert-deftest time/time-less-p-and-time-equal-p ()
  (let ((a (encode-time '(0 0 0 1 1 2026 nil nil t)))
        (b (encode-time '(0 0 0 2 1 2026 nil nil t))))
    (should (time-less-p a b))
    (should-not (time-less-p b a))
    (should (time-equal-p a a))
    (should-not (time-equal-p a b))))

(ert-deftest time/format-seconds-is-human-readable ()
  (should (string-match-p "2" (format-seconds "%m minutes" 125)))
  (should (string-match-p "1" (format-seconds "%h hours" 3665))))

(ert-deftest help/where-is-internal-finds-a-local-keybinding ()
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "C-c C-z") 'ignore)
    (should (equal (key-description (car (where-is-internal 'ignore map)))
                   (key-description (kbd "C-c C-z"))))))

(ert-deftest help/functionp-and-commandp-predicates ()
  (should (functionp 'car))
  (should (commandp 'save-buffer))
  (should-not (commandp 'car)))

(ert-deftest customize/facep-recognizes-real-faces ()
  (should (facep 'bold))
  (should-not (facep 'definitely-not-a-real-face)))

;;; calendar-calc-help.el ends here
