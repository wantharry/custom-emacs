;;; bigfile-bench.el --- on-demand stress test for a real multi-million-line file  -*- lexical-binding: t; -*-

;; WHAT: real keystroke/edit timing on a genuinely huge file (built fresh by
;; tools/stress-bigfile.sh, same recipe as the one used to find and fix the
;; `display-line-numbers-mode' slowdown --- see `my/line-numbers-max-buffer-size's
;; own docstring in config/init.el). Navigation (next-line, page-down, isearch,
;; buffer extremes) runs on the real file-visiting buffer; edits (insert, delete,
;; kill/yank, undo, a buffer-wide regexp count) run on a throwaway in-memory COPY,
;; never on the file-visiting buffer and never saved to disk --- so this can never
;; corrupt the real test file, and there is nothing fragile to restore between
;; rounds (the copy is just discarded and remade).
;;
;; WHY NOT an ERT test / NOT run by tests/run-all.sh: explicit user request --- a
;; full run takes several minutes and needs a real GUI frame (a plain --batch
;; invocation never exercises real redisplay, so timings there would be
;; meaningless; this project's own testing already established that). Run this by
;; hand, on demand, via tools/stress-bigfile.sh --- never wired into the regular
;; regression suite.
;;
;; HOW: driven the same way this project's own GUI timing investigation was ---
;; `execute-kbd-macro' + explicit `redisplay' calls through a real `--fg-daemon'
;; frame, not plain function calls in `--batch' (confirmed directly, more than
;; once in this project's history, that `--batch' redisplay is not representative).

(defconst bt/file "words-20x.txt"
  "The buffer name of the real huge file, built by tools/stress-bigfile.sh.")

(defun bt/goto-line-fast (n)
  "Jump to line N without `goto-line' (which can itself be slow on a huge
buffer) --- plain `forward-line' from `point-min' is the honest primitive."
  (goto-char (point-min))
  (forward-line (1- n)))

;;; Navigation --- real commands, on the real file-visiting buffer.

(defun bt/time-next-lines (n)
  (let ((start (float-time)))
    (dotimes (_ n) (execute-kbd-macro (kbd "C-n")) (redisplay t))
    (- (float-time) start)))

(defun bt/time-page-downs (n)
  (let ((start (float-time)))
    (dotimes (_ n) (execute-kbd-macro (kbd "C-v")) (redisplay t))
    (- (float-time) start)))

(defun bt/time-isearch (needle)
  (let ((start (float-time)))
    (goto-char (point-min))
    (search-forward needle nil t)
    (- (float-time) start)))

(defun bt/time-extremes ()
  "`end-of-buffer'/`beginning-of-buffer' are O(1) in character terms, so this
should stay instant regardless of file size; a real regression here (not just
a line-number-specific one) would show up as a growing time."
  (let ((start (float-time)))
    (end-of-buffer) (beginning-of-buffer) (end-of-buffer) (beginning-of-buffer)
    (- (float-time) start)))

(defun bt/rss-kb ()
  (let ((status (with-temp-buffer
                   (insert-file-contents (format "/proc/%d/status" (emacs-pid)))
                   (buffer-string))))
    (when (string-match "VmRSS:[ \t]*\\([0-9]+\\)" status)
      (string-to-number (match-string 1 status)))))

(defun bt/nav-round (label)
  "One full navigation round: start, middle, end of the huge buffer, plus a
whole-buffer isearch, buffer extremes, and the daemon's own RSS."
  (with-current-buffer bt/file
    (let (results)
      (bt/goto-line-fast 1000)
      (push (list :label label :where "near start" :line (line-number-at-pos)
                   :next-line-50 (bt/time-next-lines 50) :page-down-5 (bt/time-page-downs 5))
            results)
      (bt/goto-line-fast 4665500)
      (push (list :label label :where "middle" :line (line-number-at-pos)
                   :next-line-50 (bt/time-next-lines 50) :page-down-5 (bt/time-page-downs 5))
            results)
      (bt/goto-line-fast 9320000)
      (push (list :label label :where "near end" :line (line-number-at-pos)
                   :next-line-50 (bt/time-next-lines 50) :page-down-5 (bt/time-page-downs 5))
            results)
      (push (list :label label :where "isearch for a rare token" :isearch (bt/time-isearch "zzyzx")) results)
      (bt/goto-line-fast 4665500)
      (push (list :label label :where "buffer extremes (end/beginning x2)" :extremes (bt/time-extremes)) results)
      (push (list :label label :where "daemon RSS KB" :rss (bt/rss-kb)) results)
      (nreverse results))))

;;; Edits --- real insert/delete/kill-yank/undo/regexp-count, on a throwaway COPY.

(defvar bt/edit-buffer-name "*bigfile-edit-stress*")
(defvar bt/edit-content nil
  "The real file's content, read once and cached, so each round's fresh copy
is a plain `insert' of a string already in memory --- not a second 97MB disk
read per round.")

(defun bt/edit-buffer ()
  "A fresh scratch buffer with the same content as `bt/file', every time ---
never the file-visiting buffer itself, so destructive edit-stress can never
touch the real file on disk, and each round starts from clean, known content
with no need to undo anything to get back to it.

A REAL FINDING from building this test, not a self-inflicted problem to code
around quietly: `my/line-numbers--maybe-disable-for-huge-buffer' (config/
init.el) is only ever hooked to `find-file-hook', so a huge buffer that is
NOT created by visiting a file --- this one, or equally a huge `*compilation*'/
`*shell*'/`*grep*' output buffer in real use --- never gets it, and both line-
number features turn themselves back on via the global minor modes'
`after-change-major-mode-hook' the moment `text-mode' runs, with nothing to
turn them back off again. The first version of this benchmark hit exactly
that: 500 inserts/kills/yanks each forcing a full margin/line-number redraw on
a 9.3M-line buffer reintroduced the very slowdown the real fix exists to
prevent, and made the whole daemon look hung for minutes. Disabled explicitly
here so this benchmark measures EDIT cost, not that already-known, already-
fixed-for-file-buffers cost again --- see the stress-test report for whether
the real fix should be broadened to cover this buffer-size-based case too,
independent of how the buffer was created."
  (unless bt/edit-content
    (setq bt/edit-content
          (with-current-buffer bt/file (buffer-substring-no-properties (point-min) (point-max)))))
  (let ((buf (get-buffer-create bt/edit-buffer-name)))
    (with-current-buffer buf
      (let ((inhibit-read-only t))
        (erase-buffer)
        (buffer-disable-undo)
        (insert bt/edit-content)
        (text-mode)
        (display-line-numbers-mode -1)
        (when (bound-and-true-p my/absolute-line-numbers-margin-mode)
          (my/absolute-line-numbers-margin-mode -1))
        (goto-char (point-min))
        (buffer-enable-undo)))
    buf))

(defun bt/time-insert-burst (n)
  (let ((start (float-time)))
    (dotimes (i n) (insert (format "stress-inserted-line-%d\n" i)) (redisplay t))
    (- (float-time) start)))

(defun bt/time-delete-burst (n)
  (let ((start (float-time)))
    (dotimes (_ n)
      (forward-line -1)
      (let ((b (point))) (forward-line 1) (delete-region b (point)))
      (redisplay t))
    (- (float-time) start)))

(defun bt/time-kill-yank-burst (n)
  (let ((start (float-time)))
    (dotimes (_ n) (kill-whole-line) (yank) (redisplay t))
    (- (float-time) start)))

(defun bt/time-undo-chain (n)
  "Time `primitive-undo' over N undo entries, called directly rather than
looping the interactive `undo' command --- a real, found-the-hard-way trap:
`undo' decides whether to continue the SAME undo session or start over via
`(eq last-command 'undo)', which a plain Lisp loop never sets, so every
iteration calls `undo-start' again and reprocesses `buffer-undo-list' from
its current head. Not an infinite loop, but a real, practically-unbounded
stall --- confirmed directly while building this benchmark, not guessed."
  (let ((start (float-time)))
    (setq buffer-undo-list (primitive-undo n buffer-undo-list))
    (- (float-time) start)))

(defun bt/time-big-delete-region (chars)
  (let ((start (float-time)) (end (min (point-max) (+ (point) chars))))
    (delete-region (point) end)
    (redisplay t)
    (- (float-time) start)))

(defun bt/time-count-matches (regexp)
  (goto-char (point-min))
  (let ((start (float-time)))
    (how-many regexp)
    (- (float-time) start)))

(defun bt/edit-round (label)
  "A full edit-stress round on a fresh throwaway copy of the huge file:
insert, delete, kill/yank, a big single-call region delete, an undo chain, and
a whole-buffer regexp count."
  (with-current-buffer (bt/edit-buffer)
    (let (results)
      (bt/goto-line-fast 4665500)
      (push (list :label label :where "insert 200 lines at the middle"
                   :elapsed (bt/time-insert-burst 200)) results)
      (push (list :label label :where "delete those 200 lines back out"
                   :elapsed (bt/time-delete-burst 200)) results)
      (bt/goto-line-fast 4665500)
      (push (list :label label :where "50 kill-line+yank cycles"
                   :elapsed (bt/time-kill-yank-burst 50)) results)
      (bt/goto-line-fast 9320000)
      (push (list :label label :where "delete a 500KB region near the end"
                   :elapsed (bt/time-big-delete-region (* 500 1024))) results)
      (push (list :label label :where "undo everything above (up to 300 steps)"
                   :elapsed (bt/time-undo-chain 300)) results)
      (push (list :label label :where "count matches of a common word, whole buffer"
                   :elapsed (bt/time-count-matches "^the$")) results)
      (push (list :label label :where "daemon RSS KB" :rss (bt/rss-kb)) results)
      (nreverse results))))

;;; bigfile-bench.el ends here
