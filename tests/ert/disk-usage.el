;;; disk-usage.el --- the custom, dua-powered disk usage browser  -*- lexical-binding: t; -*-
;; harness: config
;; Needs the real `dua' binary on PATH (not an ELPA package; see docs/DISK-USAGE.md).

(require 'disk-usage (expand-file-name "disk-usage" user-emacs-directory))

(defmacro disk-usage-test-needs-dua (&rest body)
  (declare (indent 0))
  `(progn (skip-unless (executable-find my/disk-usage-dua-command)) ,@body))

(defun disk-usage-test--scan-sync (dir &optional force)
  "A synchronous wrapper around `my/disk-usage--scan-async', for tests that only
care about the resulting PAIRS, not async timing itself (covered separately by
`disk-usage/async-scan-really-runs-in-the-background'). Binds `my/disk-usage-async'
to nil for the duration, so the callback --- real `dua' or a cache hit either way
--- always runs before this returns."
  (let (result (my/disk-usage-async nil))
    (my/disk-usage--scan-async dir force (lambda (pairs) (setq result pairs)))
    result))

(ert-deftest disk-usage/key-is-bound ()
  (should (eq (key-binding (kbd "C-c W")) 'my/disk-usage)))

(ert-deftest disk-usage/parse-line-reads-a-real-dua-line ()
  (should (equal (my/disk-usage--parse-line "      4096 b somefile.txt") '(4096 . "somefile.txt")))
  (should (equal (my/disk-usage--parse-line "  10080256 b eln-cache") '(10080256 . "eln-cache")))
  ;; names with spaces (confirmed real, from `dua' on an actual Windows C:\ scan: "System
  ;; Volume Information") must still parse --- only the FIRST two fields are fixed-shape.
  (should (equal (my/disk-usage--parse-line "      20480 b System Volume Information")
                 '(20480 . "System Volume Information")))
  ;; a stray line that is not one of `dua''s own entries (a warning, blank line, ...)
  ;; is simply not a match, not an error.
  (should-not (my/disk-usage--parse-line ""))
  (should-not (my/disk-usage--parse-line "some random warning text")))

(ert-deftest disk-usage/scan-returns-real-children-biggest-first ()
  (disk-usage-test-needs-dua
    (test-with-temp-dir dir
      (let ((small (expand-file-name "small.txt" dir))
            (big (expand-file-name "big.txt" dir)))
        (with-temp-buffer (insert (make-string 10 ?x)) (write-file small))
        (with-temp-buffer (insert (make-string 10000 ?x)) (write-file big))
        (let ((entries (disk-usage-test--scan-sync dir)))
          (should (= (length entries) 2))
          ;; biggest first: `big.txt' before `small.txt'.
          (should (equal (cdr (nth 0 entries)) "big.txt"))
          (should (equal (cdr (nth 1 entries)) "small.txt"))
          (should (> (car (nth 0 entries)) (car (nth 1 entries)))))))))

(ert-deftest disk-usage/entries-mark-directories-and-use-real-paths ()
  (disk-usage-test-needs-dua
    (test-with-temp-dir dir
      (make-directory (expand-file-name "sub" dir))
      (with-temp-buffer (insert "x") (write-file (expand-file-name "f.txt" dir)))
      (let ((entries (my/disk-usage--entries-from-pairs (disk-usage-test--scan-sync dir) dir)))
        (should (= (length entries) 2))
        (dolist (e entries)
          (should (file-exists-p (car e)))
          (if (file-directory-p (car e))
              (should (string-suffix-p "/" (aref (cadr e) 1)))
            (should-not (string-suffix-p "/" (aref (cadr e) 1)))))))))

(ert-deftest disk-usage/visit-drills-in-and-up-goes-back ()
  (disk-usage-test-needs-dua
    (test-with-temp-dir dir
      (make-directory (expand-file-name "sub" dir))
      (with-temp-buffer (insert "x") (write-file (expand-file-name "sub/f.txt" dir)))
      (let (buf (my/disk-usage-async nil)) ; sync: no need to wait on a real process here
        (unwind-protect
            (progn
              (my/disk-usage dir)
              ;; `my/disk-usage--refresh' renames the buffer away from the plain
              ;; `my/disk-usage-buffer-name' constant (to "*Disk Usage: DIR*") on
              ;; every real use --- `switch-to-buffer' inside `my/disk-usage' makes
              ;; it `current-buffer' right here regardless of its current name.
              (setq buf (current-buffer))
              (with-current-buffer buf
                (should (equal (file-truename my/disk-usage--directory) (file-truename dir)))
                (goto-char (point-min))
                (my/disk-usage-visit)
                (should (equal (file-truename my/disk-usage--directory)
                               (file-truename (expand-file-name "sub" dir))))
                (my/disk-usage-up)
                (should (equal (file-truename my/disk-usage--directory) (file-truename dir)))))
          (when (buffer-live-p buf) (kill-buffer buf)))))))

(ert-deftest disk-usage/async-scan-really-runs-in-the-background ()
  ;; A real, user-raised concern: the first version of this file used `call-process',
  ;; which blocks all of Emacs for as long as `dua' takes --- confirmed directly
  ;; (`my/disk-usage-async' is t, the real default) that a scan now returns a LIVE
  ;; process immediately, without waiting for it, and the real result only lands via
  ;; the callback once that process actually exits.
  (disk-usage-test-needs-dua
    (test-with-temp-dir dir
      (with-temp-buffer (insert "x") (write-file (expand-file-name "f.txt" dir)))
      (clrhash my/disk-usage--cache)
      ;; `let*', not `let' --- a real bug, found by actually timing this test (it
      ;; silently ran for the full timeout and passed vacuously): a plain `let'
      ;; evaluates every binding's init expression in the OUTER scope before any of
      ;; this `let''s own new bindings take effect, so a lambda created while
      ;; computing `proc' (this let's OWN second binding) would capture some OTHER,
      ;; unbound/dynamic `result', never the real lexical one the body below reads
      ;; back --- confirmed directly: that mismatch is exactly what made `result'
      ;; never visibly update, forcing the `while' loop to run out its full
      ;; deadline instead of ever actually seeing the real completion.
      (let* (result (proc (my/disk-usage--scan-async dir nil (lambda (pairs) (setq result pairs)))))
        (should (process-live-p proc))
        (should-not result) ; the callback cannot have run yet --- nothing was awaited
        (let ((deadline (+ (float-time) 10)))
          (while (and (not result) (< (float-time) deadline))
            (accept-process-output proc 0.2)))
        (should-not (process-live-p proc)) ; it genuinely finished, not just timed out
        (should-not (and (consp result) (eq (car result) :error)))
        ;; `dua' reports real DISK usage (whole filesystem blocks allocated), not
        ;; apparent byte size --- confirmed directly: a real 1-byte file reported as
        ;; 4096 b, one block, not "1" --- so only the NAME is checked exactly.
        (should (= (length result) 1))
        (should (equal (cdr (car result)) "f.txt"))
        (should (> (car (car result)) 0))))))

(ert-deftest disk-usage/scan-is-cached-until-the-directory-actually-changes ()
  ;; User request: do not re-run `dua' every single time, only when something in
  ;; that directory actually changed (or `g' explicitly asks for a real re-scan).
  ;; Mocks `my/disk-usage--scan-sync' itself (counts real scans) rather than `dua'/
  ;; `call-process' --- what is under test here is the CACHE GATE in front of it,
  ;; not `dua' itself (already covered by the tests above). Forces sync mode so the
  ;; mocked call always runs synchronously, same reasoning as `disk-usage-test--scan-sync'.
  (test-with-temp-dir dir
    (let ((calls 0) (my/disk-usage-async nil))
      (clrhash my/disk-usage--cache)
      (cl-letf (((symbol-function 'my/disk-usage--scan-sync)
                 ;; Must still populate the real cache (via the real `--finish-scan',
                 ;; not mocked) --- a mock that only counts calls without that would
                 ;; never actually get reused, defeating the very thing under test.
                 (lambda (dir mtime callback)
                   (setq calls (1+ calls))
                   (my/disk-usage--finish-scan dir mtime callback nil))))
        (disk-usage-test--scan-sync dir)
        (should (= calls 1))
        ;; same directory, nothing changed: reused from cache, no second real scan.
        (disk-usage-test--scan-sync dir)
        (should (= calls 1))
        ;; `g' (FORCE) always bypasses the cache, real `dua' or not.
        (disk-usage-test--scan-sync dir t)
        (should (= calls 2))
        ;; a real change DIRECTLY inside the directory moves its own mtime forward,
        ;; which must invalidate the cache even without FORCE.
        (sleep-for 1) ; mtimes have only whole-second resolution on some filesystems
        (with-temp-buffer (insert "x") (write-file (expand-file-name "new.txt" dir)))
        (disk-usage-test--scan-sync dir)
        (should (= calls 3))
        ;; unchanged again since that last real scan: back to reusing the cache.
        (disk-usage-test--scan-sync dir)
        (should (= calls 3))))))

(ert-deftest disk-usage/cache-persists-to-disk-and-reloads ()
  ;; Second, later user request, on top of the session-only cache above: "make sure
  ;; it indexes and save ... so we don't have to do it every time" --- across
  ;; restarts too, not just within one. Uses a real temp file (not the real
  ;; `my/disk-usage-cache-file', so a test run never touches the user's own real
  ;; cache), and real `my/disk-usage--save-cache'/`--load-cache', not mocked ---
  ;; what is under test here is the round-trip itself.
  (let* ((tmp (make-temp-file "disk-usage-cache-test" nil ".eld"))
         (my/disk-usage-cache-file tmp)
         (my/disk-usage--cache (make-hash-table :test #'equal)))
    (unwind-protect
        (progn
          (puthash "/some/dir" (cons (current-time) '((10 . "a") (20 . "b")))
                   my/disk-usage--cache)
          (my/disk-usage--save-cache)
          (should (file-exists-p tmp))
          (let ((reloaded (my/disk-usage--load-cache)))
            (should (equal (gethash "/some/dir" reloaded)
                           (gethash "/some/dir" my/disk-usage--cache)))))
      (delete-file tmp))))

(ert-deftest disk-usage/missing-cache-file-loads-a-fresh-empty-table ()
  (let ((my/disk-usage-cache-file (make-temp-name "/tmp/nonexistent-disk-usage-cache-")))
    (should (hash-table-p (my/disk-usage--load-cache)))
    (should (zerop (hash-table-count (my/disk-usage--load-cache))))))

(ert-deftest disk-usage/toggle-async-flips-the-variable ()
  (let ((my/disk-usage-async t))
    (my/disk-usage-toggle-async)
    (should-not my/disk-usage-async)
    (my/disk-usage-toggle-async)
    (should my/disk-usage-async)))

(ert-deftest disk-usage/missing-dua-shows-a-message-not-an-error ()
  (let ((real (symbol-function 'executable-find)))
    (cl-letf (((symbol-function 'executable-find)
               (lambda (cmd) (if (equal cmd my/disk-usage-dua-command) nil (funcall real cmd)))))
      (should-error (my/disk-usage default-directory) :type 'user-error))))

;;; disk-usage.el ends here
