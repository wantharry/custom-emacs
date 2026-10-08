;;; line-numbers.el --- dual line-number columns, and the %p position indicator  -*- lexical-binding: t; -*-
;; harness: config

(ert-deftest line-numbers/relative-type-is-the-default ()
  ;; User request, after the same setting turned up in another Emacs user's own
  ;; config: the native column shows DISTANCE from point, not absolute position.
  (should (eq (default-value 'display-line-numbers-type) 'relative)))

(ert-deftest line-numbers/current-line-still-shows-its-real-absolute-number ()
  ;; A real, built-in Emacs feature (`display-line-numbers-current-absolute',
  ;; confirmed directly on by default) --- the hybrid half of the request, before
  ;; the dual-margin column (below) covers the rest of it.
  (should display-line-numbers-current-absolute)
  (with-temp-buffer
    (text-mode)
    (dotimes (i 10) (insert (format "line %d\n" i)))
    (goto-char (point-min))
    (forward-line 4)
    (display-line-numbers-mode 1)
    (should (= (line-number-at-pos) 5))))

(ert-deftest line-numbers/margin-mode-key-is-not-bound-to-anything-global ()
  ;; Deliberately not a key the user presses --- the global minor mode below turns
  ;; it on everywhere automatically (GUI only); nothing to bind.
  (should (fboundp 'my/absolute-line-numbers-margin-mode))
  (should (fboundp 'my/global-absolute-line-numbers-margin-mode)))

;; The tests below all need the buffer shown in the SELECTED window, not just a
;; plain `with-temp-buffer' (invisible, in no window) --- a real, found-by-testing
;; distinction: `my/absolute-line-numbers--update' reads `window-start'/`window-end'
;; of `(selected-window)', which for an invisible buffer refers to whatever buffer
;; that window actually shows instead (confirmed directly: a first version of these
;; tests silently drew 0 overlays against the WRONG buffer). `test-in-buffer'
;; (tests/ert/helper.el) is this project's own existing fix for exactly that gap.

(ert-deftest line-numbers/enabling-sets-the-left-margin-and-draws-every-visible-line ()
  (test-in-buffer #'text-mode (mapconcat (lambda (i) (format "line %d" i)) (number-sequence 1 20) "\n")
    (unwind-protect
        (progn
          (my/absolute-line-numbers-margin-mode 1)
          (should (= (car (window-margins (selected-window))) my/absolute-line-numbers-margin-width))
          ;; One overlay per visible line --- the whole 20-line buffer fits in the
          ;; test harness's own (tall) window, so all 20 are drawn.
          (should (= (length my/absolute-line-numbers--overlays) 20)))
      (my/absolute-line-numbers-margin-mode -1))))

(ert-deftest line-numbers/overlay-text-is-the-real-absolute-number ()
  (test-in-buffer #'text-mode (mapconcat (lambda (i) (format "line %d" i)) (number-sequence 1 5) "\n")
    (unwind-protect
        (progn
          (my/absolute-line-numbers-margin-mode 1)
          ;; Overlays are pushed as drawn (line 1 first), so the list ends up
          ;; newest-first --- `(car (last ...))' is the very first one made, line 1.
          (let* ((ov (car (last my/absolute-line-numbers--overlays)))
                 (before (overlay-get ov 'before-string))
                 (display-spec (get-text-property 0 'display before))
                 (text (cadr display-spec)))
            (should (equal (car display-spec) '(margin left-margin)))
            (should (string-match-p "1\\'" (string-trim text)))))
      (my/absolute-line-numbers-margin-mode -1))))

(ert-deftest line-numbers/disabling-removes-the-margin-and-every-overlay ()
  (test-in-buffer #'text-mode (mapconcat (lambda (i) (format "line %d" i)) (number-sequence 1 10) "\n")
    (my/absolute-line-numbers-margin-mode 1)
    (should (window-margins (selected-window)))
    (my/absolute-line-numbers-margin-mode -1)
    (should-not (car (window-margins (selected-window))))
    (should-not my/absolute-line-numbers--overlays)))

(ert-deftest line-numbers/redraw-never-hangs-even-with-no-trailing-newline ()
  ;; A real bug, found the hard way (an actual hang during manual GUI testing, not
  ;; assumed): a buffer whose last line has no trailing newline is exactly the kind
  ;; of edge case that can desync `window-end'/`forward-line'. The hard iteration
  ;; cap in `my/absolute-line-numbers--update' is what actually guarantees this
  ;; returns; this test just confirms it still does, with a real such buffer, and
  ;; within a real, generous but finite timeout rather than hanging the test suite
  ;; itself if the cap were ever removed by accident.
  (test-in-buffer #'text-mode
      (concat (mapconcat (lambda (i) (format "line %d" i)) (number-sequence 1 10) "\n")
              "\nno trailing newline on this one")
    (unwind-protect
        (with-timeout (5 (ert-fail "my/absolute-line-numbers--update did not return in time"))
          (my/absolute-line-numbers-margin-mode 1)
          (should my/absolute-line-numbers--overlays))
      (my/absolute-line-numbers-margin-mode -1))))

(ert-deftest line-numbers/redraw-never-hangs-on-an-empty-buffer ()
  (test-in-buffer #'text-mode ""
    (unwind-protect
        (with-timeout (5 (ert-fail "my/absolute-line-numbers--update did not return in time"))
          (my/absolute-line-numbers-margin-mode 1))
      (my/absolute-line-numbers-margin-mode -1))))

(ert-deftest line-numbers/global-mode-only-auto-enables-in-a-real-gui-frame ()
  ;; `display-graphic-p' is nil in this real `--batch' harness --- confirmed
  ;; directly, not assumed --- so `my/absolute-line-numbers--maybe-enable' must
  ;; decline here, the same gate a real terminal (`-nw') session would hit too.
  (should-not (display-graphic-p))
  (test-in-buffer #'text-mode ""
    (my/absolute-line-numbers--maybe-enable)
    (should-not my/absolute-line-numbers-margin-mode)))

(ert-deftest line-numbers/size-indication-mode-is-on ()
  ;; User request: the current point's position through the buffer as a percentage
  ;; (or Top/Bot/All at the edges) --- a real, built-in Emacs feature
  ;; (`mode-line-percent-position', confirmed `(-3 "%p")' by default), just off by
  ;; default; this is the one setting that turns it on.
  (should size-indication-mode)
  (should (equal mode-line-percent-position '(-3 "%p"))))

;;; line-numbers.el ends here
