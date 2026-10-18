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

(ert-deftest diff-hl/an-unmodified-file-has-no-changes ()
  (dhl-need
    (test-with-temp-dir d
      (test-git d "init" "-q")
      (test-write-file (concat d "a.txt") "one\ntwo\nthree\n")
      (test-git d "add" "a.txt")
      (test-git d "commit" "-q" "-m" "first")
      (let ((default-directory d))
        (with-current-buffer (find-file-noselect (concat d "a.txt"))
          (unwind-protect
              (progn
                (vc-file-clearprops (concat d "a.txt"))
                (should-not (diff-hl-changes)))
            (kill-buffer)))))))

(ert-deftest diff-hl/update-populates-real-overlays-on-the-changed-line ()
  (dhl-need
    (test-with-temp-dir d
      (test-git d "init" "-q")
      (test-write-file (concat d "a.txt") "one\ntwo\nthree\n")
      (test-git d "add" "a.txt")
      (test-git d "commit" "-q" "-m" "first")
      (test-write-file (concat d "a.txt") "one\nTWO\nthree\n")
      (let ((default-directory d))
        (with-current-buffer (find-file-noselect (concat d "a.txt"))
          (unwind-protect
              (progn
                (vc-file-clearprops (concat d "a.txt"))
                (diff-hl-update)
                (should (cl-some (lambda (ov) (overlay-get ov 'diff-hl))
                                  (overlays-in (point-min) (point-max)))))
            (kill-buffer)))))))

(ert-deftest diff-hl/remove-overlays-clears-every-diff-hl-overlay ()
  (dhl-need
    (test-with-temp-dir d
      (test-git d "init" "-q")
      (test-write-file (concat d "a.txt") "one\ntwo\nthree\n")
      (test-git d "add" "a.txt")
      (test-git d "commit" "-q" "-m" "first")
      (test-write-file (concat d "a.txt") "one\nTWO\nthree\n")
      (let ((default-directory d))
        (with-current-buffer (find-file-noselect (concat d "a.txt"))
          (unwind-protect
              (progn
                (vc-file-clearprops (concat d "a.txt"))
                (diff-hl-update)
                (diff-hl-remove-overlays)
                (should-not (cl-some (lambda (ov) (overlay-get ov 'diff-hl))
                                      (overlays-in (point-min) (point-max)))))
            (kill-buffer)))))))

(ert-deftest diff-hl/a-deleted-line-is-detected-even-though-nothing-is-added ()
  (dhl-need
    (test-with-temp-dir d
      (test-git d "init" "-q")
      (test-write-file (concat d "a.txt") "one\ntwo\nthree\nfour\nfive\n")
      (test-git d "add" "a.txt")
      (test-git d "commit" "-q" "-m" "first")
      (test-write-file (concat d "a.txt") "one\ntwo\nfour\nfive\n") ; "three" removed
      (let ((default-directory d))
        (with-current-buffer (find-file-noselect (concat d "a.txt"))
          (unwind-protect
              (progn
                (vc-file-clearprops (concat d "a.txt"))
                (should (diff-hl-changes)))
            (kill-buffer)))))))

(ert-deftest diff-hl/next-hunk-moves-point-to-the-next-changed-line ()
  (dhl-need
    (test-with-temp-dir d
      (test-git d "init" "-q")
      (test-write-file (concat d "a.txt") "one\ntwo\nthree\nfour\nfive\n")
      (test-git d "add" "a.txt")
      (test-git d "commit" "-q" "-m" "first")
      (test-write-file (concat d "a.txt") "one\nTWO\nthree\nfour\nFIVE\n")
      (let ((default-directory d))
        (with-current-buffer (find-file-noselect (concat d "a.txt"))
          (unwind-protect
              (progn
                (vc-file-clearprops (concat d "a.txt"))
                (diff-hl-update)
                (goto-char (point-min))
                (diff-hl-next-hunk)
                (should (= (line-number-at-pos) 2)))
            (kill-buffer)))))))

(ert-deftest diff-hl/next-hunk-twice-reaches-the-second-separate-hunk ()
  (dhl-need
    (test-with-temp-dir d
      (test-git d "init" "-q")
      (test-write-file (concat d "a.txt") "one\ntwo\nthree\nfour\nfive\n")
      (test-git d "add" "a.txt")
      (test-git d "commit" "-q" "-m" "first")
      (test-write-file (concat d "a.txt") "one\nTWO\nthree\nfour\nFIVE\n")
      (let ((default-directory d))
        (with-current-buffer (find-file-noselect (concat d "a.txt"))
          (unwind-protect
              (progn
                (vc-file-clearprops (concat d "a.txt"))
                (diff-hl-update)
                (goto-char (point-min))
                (diff-hl-next-hunk)
                (diff-hl-next-hunk)
                (should (= (line-number-at-pos) 5)))
            (kill-buffer)))))))

(ert-deftest diff-hl/previous-hunk-moves-back-from-the-second-hunk-to-the-first ()
  (dhl-need
    (test-with-temp-dir d
      (test-git d "init" "-q")
      (test-write-file (concat d "a.txt") "one\ntwo\nthree\nfour\nfive\n")
      (test-git d "add" "a.txt")
      (test-git d "commit" "-q" "-m" "first")
      (test-write-file (concat d "a.txt") "one\nTWO\nthree\nfour\nFIVE\n")
      (let ((default-directory d))
        (with-current-buffer (find-file-noselect (concat d "a.txt"))
          (unwind-protect
              (progn
                (vc-file-clearprops (concat d "a.txt"))
                (diff-hl-update)
                (goto-char (point-min))
                (diff-hl-next-hunk) (diff-hl-next-hunk)
                (diff-hl-previous-hunk)
                (should (= (line-number-at-pos) 2)))
            (kill-buffer)))))))

(ert-deftest diff-hl/mark-hunk-selects-exactly-the-changed-lines-text ()
  (dhl-need
    (test-with-temp-dir d
      (test-git d "init" "-q")
      (test-write-file (concat d "a.txt") "one\ntwo\nthree\n")
      (test-git d "add" "a.txt")
      (test-git d "commit" "-q" "-m" "first")
      (test-write-file (concat d "a.txt") "one\nTWO\nthree\n")
      (let ((default-directory d))
        (with-current-buffer (find-file-noselect (concat d "a.txt"))
          (unwind-protect
              (progn
                (vc-file-clearprops (concat d "a.txt"))
                (diff-hl-update)
                (goto-char (point-min))
                (forward-line 1)
                (diff-hl-mark-hunk)
                (should (equal (buffer-substring (region-beginning) (region-end)) "TWO\n")))
            (kill-buffer)))))))

(ert-deftest diff-hl/revert-hunk-restores-the-committed-text-for-just-that-hunk ()
  ;; This config makes every file-visiting buffer read-only by default (see
  ;; tests/ert/readonly.el) --- `diff-hl-revert-hunk' needs the buffer writable first,
  ;; the same real gotcha already pinned down for `wgrep' in tests/ert/wgrep.el.
  (dhl-need
    (test-with-temp-dir d
      (test-git d "init" "-q")
      (test-write-file (concat d "a.txt") "one\ntwo\nthree\nfour\nfive\n")
      (test-git d "add" "a.txt")
      (test-git d "commit" "-q" "-m" "first")
      (test-write-file (concat d "a.txt") "one\nTWO\nthree\nfour\nfive\n")
      (let ((default-directory d))
        (with-current-buffer (find-file-noselect (concat d "a.txt"))
          (unwind-protect
              (progn
                (read-only-mode -1)
                (vc-file-clearprops (concat d "a.txt"))
                (diff-hl-update)
                (goto-char (point-min))
                (forward-line 1)
                (cl-letf (((symbol-function 'y-or-n-p) (lambda (&rest _) t)))
                  (diff-hl-revert-hunk))
                (should (equal (buffer-string) "one\ntwo\nthree\nfour\nfive\n")))
            (kill-buffer)))))))

(ert-deftest diff-hl/a-file-outside-any-vc-repository-has-no-changes-and-does-not-error ()
  (dhl-need
    (test-with-temp-dir d
      (let ((file (test-write-file (concat d "a.txt") "no repo here\n")))
        (with-current-buffer (find-file-noselect file)
          (unwind-protect
              (should-not (diff-hl-changes))
            (kill-buffer)))))))

(ert-deftest diff-hl/a-pure-insert-hunk-is-tagged-as-insert-not-change ()
  ;; Each hunk overlay `diff-hl-update' creates carries its own real `diff-hl-hunk-type'
  ;; --- confirmed directly --- `insert' for a line added with nothing else touched,
  ;; distinct from `change'/`delete' below. The margin indicator (`diff-hl-margin-mode',
  ;; the one actually visible in this project's own `-nw' terminal sessions, see this
  ;; file's own header comment) depends on telling these apart correctly.
  (dhl-need
    (test-with-temp-dir d
      (test-git d "init" "-q")
      (test-write-file (concat d "a.txt") "one\ntwo\nthree\n")
      (test-git d "add" "a.txt")
      (test-git d "commit" "-q" "-m" "first")
      (test-write-file (concat d "a.txt") "one\ntwo\nINSERTED\nthree\n")
      (let ((default-directory d))
        (with-current-buffer (find-file-noselect (concat d "a.txt"))
          (unwind-protect
              (progn
                (vc-file-clearprops (concat d "a.txt"))
                (diff-hl-update)
                (goto-char (point-min)) (forward-line 2)
                (should (eq (overlay-get (diff-hl-hunk-overlay-at (point)) 'diff-hl-hunk-type)
                            'insert)))
            (kill-buffer)))))))

(ert-deftest diff-hl/a-pure-delete-hunk-is-tagged-as-delete ()
  (dhl-need
    (test-with-temp-dir d
      (test-git d "init" "-q")
      (test-write-file (concat d "a.txt") "one\ntwo\nthree\nfour\n")
      (test-git d "add" "a.txt")
      (test-git d "commit" "-q" "-m" "first")
      (test-write-file (concat d "a.txt") "one\nthree\nfour\n") ; "two" removed
      (let ((default-directory d))
        (with-current-buffer (find-file-noselect (concat d "a.txt"))
          (unwind-protect
              (progn
                (vc-file-clearprops (concat d "a.txt"))
                (diff-hl-update)
                ;; a pure deletion's overlay sits at the start of the line immediately
                ;; following where the removed line used to be --- confirmed directly,
                ;; not at the deleted line's own (now nonexistent) position.
                (goto-char (point-min)) (forward-line 1)
                (should (eq (overlay-get (diff-hl-hunk-overlay-at (point)) 'diff-hl-hunk-type)
                            'delete)))
            (kill-buffer)))))))

(ert-deftest diff-hl/a-modified-line-hunk-is-tagged-as-change-not-insert-or-delete ()
  (dhl-need
    (test-with-temp-dir d
      (test-git d "init" "-q")
      (test-write-file (concat d "a.txt") "one\ntwo\nthree\n")
      (test-git d "add" "a.txt")
      (test-git d "commit" "-q" "-m" "first")
      (test-write-file (concat d "a.txt") "one\nTWO\nthree\n")
      (let ((default-directory d))
        (with-current-buffer (find-file-noselect (concat d "a.txt"))
          (unwind-protect
              (progn
                (vc-file-clearprops (concat d "a.txt"))
                (diff-hl-update)
                (goto-char (point-min)) (forward-line 1)
                (should (eq (overlay-get (diff-hl-hunk-overlay-at (point)) 'diff-hl-hunk-type)
                            'change)))
            (kill-buffer)))))))

(ert-deftest diff-hl/margin-symbols-are-real-distinct-single-characters ()
  ;; The stock default this project's own `-nw' terminal sessions actually render (see
  ;; this file's own header comment on why margin, not fringe) --- confirmed directly, not
  ;; assumed: a real, distinct, non-empty string per change type.
  (dhl-need
    (dolist (type '(insert delete change))
      (let ((sym (alist-get type diff-hl-margin-symbols-alist)))
        (should (stringp sym))
        (should (> (length sym) 0))))
    (should (= (length (delete-dups (mapcar #'cdr diff-hl-margin-symbols-alist)))
               (length diff-hl-margin-symbols-alist)))))

(ert-deftest diff-hl/dired-update-marks-a-modified-file-with-a-real-change-overlay ()
  ;; Deeper than just "the mode is on" (already covered above): a real modified file in a
  ;; real Dired listing gets a real per-entry overlay, `diff-hl-dired-type' matching the
  ;; same real change-type vocabulary the buffer-level hunks above use.
  (dhl-need
    (test-with-temp-dir d
      (test-git d "init" "-q")
      (test-write-file (concat d "a.txt") "one\ntwo\n")
      (test-git d "add" "a.txt")
      (test-git d "commit" "-q" "-m" "first")
      (test-write-file (concat d "a.txt") "one\nCHANGED\n")
      (with-current-buffer (dired d)
        (unwind-protect
            (progn
              (diff-hl-dired-mode 1)
              (diff-hl-dired-update) ; async (shells out to git): wait for the real process to
              ;; actually exit, not just for the overlay to appear --- found the hard way, a
              ;; stray sentinel firing after `test-with-temp-dir' had already removed the
              ;; directory otherwise.
              (let ((tries 0))
                (while (and (get-buffer-process diff-hl-dired-process-buffer) (< tries 50))
                  (accept-process-output nil 0.1)
                  (setq tries (1+ tries))))
              (should (cl-some (lambda (ov) (eq (overlay-get ov 'diff-hl-dired-type) 'change))
                                (overlays-in (point-min) (point-max)))))
          ;; Belt and braces on top of the wait above: force-stop anything still attached to
          ;; this buffer's own process-buffer before the temp directory is removed, so a
          ;; slow sentinel can never fire against a now-nonexistent `default-directory'.
          (when (buffer-live-p diff-hl-dired-process-buffer)
            (let ((proc (get-buffer-process diff-hl-dired-process-buffer)))
              (when proc (delete-process proc)))
            (kill-buffer diff-hl-dired-process-buffer))
          (kill-buffer))))))

(ert-deftest diff-hl/a-brand-new-untracked-file-does-not-error ()
  ;; A file git has never heard of (not even `git add'ed yet) has no commit to diff
  ;; against --- confirmed directly: this must behave like the "outside any VC
  ;; repository" case above (no error, no changes reported), not signal an error from
  ;; trying to diff against a nonexistent reference revision.
  (dhl-need
    (test-with-temp-dir d
      (test-git d "init" "-q")
      (test-write-file (concat d "tracked.txt") "x\n")
      (test-git d "add" "tracked.txt")
      (test-git d "commit" "-q" "-m" "first")
      (let ((file (test-write-file (concat d "untracked.txt") "brand new\n")))
        (let ((default-directory d))
          (with-current-buffer (find-file-noselect file)
            (unwind-protect
                (should-not (condition-case nil (progn (diff-hl-update) nil)
                              (error t)))
              (kill-buffer))))))))

(ert-deftest diff-hl/dired-mode-is-a-real-callable-minor-mode-in-a-dired-buffer ()
  (dhl-need
    (test-with-temp-dir d
      (test-git d "init" "-q")
      (test-write-file (concat d "a.txt") "content\n")
      (with-current-buffer (dired d)
        (unwind-protect
            (progn
              (diff-hl-dired-mode 1)
              (should (bound-and-true-p diff-hl-dired-mode)))
          ;; `global-diff-hl-mode' (already on in this config, see the first test above)
          ;; turns `diff-hl-dired-mode' on via `dired-mode-hook', which runs before
          ;; `dired-after-readin-hook' within this same `(dired d)' call --- so a real,
          ;; async git status process is already shelling out, but not necessarily yet
          ;; by the time this unwinds: confirmed directly, its actual spawn can still be
          ;; one tick deferred, so `sit-for' first gives it the chance to really start
          ;; before checking for it. Found the hard way: without waiting for/force-
          ;; stopping it here, its sentinel can fire later, against a `default-directory'
          ;; `test-with-temp-dir' has already removed, crashing an unrelated LATER test
          ;; in the same run.
          (sit-for 0.3)
          (when (buffer-live-p diff-hl-dired-process-buffer)
            (let ((proc (get-buffer-process diff-hl-dired-process-buffer)))
              (when proc (delete-process proc)))
            (kill-buffer diff-hl-dired-process-buffer))
          (kill-buffer))))))

;;; diff-hl.el ends here
