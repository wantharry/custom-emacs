;;; calendar-year.el --- a real year-at-a-glance calendar, 3 months per row  -*- lexical-binding: t; -*-

;; `M-x my/calendar-year' shows all 12 months of a year in a grid --- 4 rows of 3
;; months each --- something Emacs's own `M-x calendar' cannot do: that command always
;; lays every month out in a *single* row, so asking it for 12 months at once
;; (`calendar-total-months') produces one line 12 * calendar-month-width columns wide
;; (300 on this build), which wraps and scrambles on any normal window rather than
;; showing a sensible grid. Confirmed for real, the hard way: an earlier attempt in this
;; same session set `calendar-total-months' to 12 and only checked that the resulting
;; buffer's *text* held 12 month names --- it did, but that is not the same as checking
;; what 12 months laid out in one row actually renders as, and the user found out before
;; this file did. Reverted that (see `config/init.el''s own "Calendar" section for the
;; full story) and built this instead: a real grid, using the exact same primitive
;; `calendar-generate' (the code behind the real `M-x calendar') itself calls to lay out
;; one row --- `calendar-generate-month' --- just called once per row (3 months, same
;; width `calendar-total-months' already uses safely today) instead of once for all 12
;; in a row nothing can wrap sanely.
;;
;; A separate, plain, read-only buffer (`*Year Calendar*'), not the real `*Calendar*'
;; buffer `M-x calendar'/the diary use --- this never touches `calendar-total-months',
;; `displayed-month'/`displayed-year', or anything else the real calendar's own state
;; depends on, so using one has no effect on the other.

;; WHAT: Emacs's own calendar package, for `calendar-generate-month'/`calendar-increment-
;; month'/`calendar-month-width' and friends.  WHY: this file is a thin layer entirely
;; on top of those --- no month/day/leap-year arithmetic of its own.  HOW: `require',
;; not `autoload', since this file is itself already lazily autoloaded (see init.el) and
;; every one of its own functions needs calendar.el loaded anyway; requiring it up front
;; here is simpler than autoloading each individual calendar.el symbol this file uses.
(require 'calendar)

;; WHAT: how many months make up one row of the grid.  WHY: 3 --- deliberately the same
;; width `calendar-total-months' already uses by default (a real, measured 76-column
;; line; see `config/init.el'), since that is already known to fit comfortably on any
;; normal window, rather than guessing at a wider row and risking the exact mistake this
;; whole file exists to fix.  4 rows of 3 is also a natural way to lay out 12 months;
;; changing this to (say) 4 widens each row to 4 * calendar-month-width columns instead.
(defvar my/calendar-year-months-per-row 3
  "How many months wide each row of `my/calendar-year''s grid is.")

;; WHAT: the plain text for one row of COUNT months starting at MONTH/YEAR, side by
;; side.  WHY/HOW: exactly what `calendar-generate' itself does to lay out a single row
;; --- call `calendar-generate-month' once per month, each one indented `calendar-month-
;; width' columns further right than the last, incrementing the month/year in between
;; --- just done here in a scratch `with-temp-buffer' so the resulting text can be
;; captured and inserted into `my/calendar-year''s own buffer, rather than writing
;; directly into the real `*Calendar*' buffer the way `calendar-generate' does.
(defun my/calendar--month-row (month year count)
  "Return, as a string, one row of COUNT months starting at MONTH/YEAR."
  (with-temp-buffer
    (dotimes (i count)
      (calendar-generate-month month year (* calendar-month-width i))
      (calendar-increment-month month year 1))
    (buffer-string)))

;; WHAT: the results buffer's major mode --- read-only, `q' to close, nothing else
;; needed.  WHY: `special-mode' already provides exactly that (the same base Magit's
;; status buffer and `M-x list-processes' use), so there is nothing to add by hand.
(define-derived-mode my/calendar-year-mode special-mode "Year Calendar"
  "Major mode for `my/calendar-year''s results buffer.")

;;;###autoload
(defun my/calendar-year (&optional year)
  "Show all 12 months of YEAR (the current year, unless a prefix argument is given) in
a grid, `my/calendar-year-months-per-row' months per row --- a real year-at-a-glance
view Emacs's own `M-x calendar' cannot produce (see this file's own header comment for
why). A plain, separate, read-only buffer; does not touch the real `*Calendar*' buffer
or the diary."
  (interactive (list (if current-prefix-arg
                         (read-number "Year: " (nth 5 (decode-time)))
                       (nth 5 (decode-time)))))
  (let ((buf (get-buffer-create "*Year Calendar*"))
        (month 1)
        (rows (/ 12 my/calendar-year-months-per-row)))
    (with-current-buffer buf
      (unless (derived-mode-p 'my/calendar-year-mode) (my/calendar-year-mode))
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert (format "%d\n\n" year))
        (dotimes (row rows)
          (insert (my/calendar--month-row month year my/calendar-year-months-per-row))
          (setq month (+ month my/calendar-year-months-per-row))
          (unless (= row (1- rows)) (insert "\n")))
        (goto-char (point-min))))
    (switch-to-buffer buf)))

;; WHAT/WHY/HOW: register this file under the Emacs feature name `calendar-year',
;; matching the `(require 'calendar-year ...)' the relevant test file uses, same as
;; every sibling config file in this project.
(provide 'calendar-year)
;;; calendar-year.el ends here
