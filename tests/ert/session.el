;;; session.el --- crash-safe auto-save and session restore (C-c w)  -*- lexical-binding: t; -*-
;; harness: config
;;
;; Several of these tests exist specifically because the real behavior surprised the real
;; testing that built this feature, not just because "more tests are good":
;;
;; - `desktop-save's second argument is RELEASE, not "force save" --- passing it non-nil
;;   (an easy mistake, made here at first) releases the desktop lock instead of claiming
;;   it, silently defeating the whole periodic-autosave mechanism forever.  Caught only by
;;   a real crash-and-restore cycle, not by reading the source. See `session/save-and-
;;   claim-ownership-never-release-the-lock' below, which pins this down for good.
;; - The read-only lock (init.el's `my/make-file-buffer-read-only') really does reapply to
;;   a buffer `desktop-read' restores, since desktop.el restores buffers via `find-file-
;;   noselect' --- confirmed for real (see `session/restore-round-trip...' below).

(require 'session (expand-file-name "session" (or (getenv "CONFIG_DIR") user-emacs-directory)))

;;; Wiring

(ert-deftest session/keys-are-bound ()
  (should (eq (key-binding (kbd "C-c w s")) 'my/session-save))
  (should (eq (key-binding (kbd "C-c w r")) 'my/session-reset))
  (should (eq (key-binding (kbd "C-c w l")) 'my/session-list)))

(ert-deftest session/is-loaded-eagerly-not-autoloaded ()
  ;; Unlike most feature files here (dictate.el, llm.el, ...), this one has to be loaded
  ;; while init.el itself is still loading --- see the file header comment in
  ;; config/session.el for why (desktop.el's own `after-init-hook' entry is what actually
  ;; restores a saved session, and that only works if desktop-save-mode is already on by
  ;; the time it fires).
  (let ((out (with-output-to-string
               (with-current-buffer standard-output
                 (call-process test-emacs nil t nil "--batch" "--init-directory" (getenv "CONFIG_DIR")
                               "-l" (expand-file-name "early-init.el" (getenv "CONFIG_DIR"))
                               "-l" (expand-file-name "init.el" (getenv "CONFIG_DIR"))
                               "--eval" "(princ (list (featurep 'session) desktop-save-mode auto-save-visited-mode))")))))
    (should (string-match-p "(t t t)" out))))

(ert-deftest session/does-not-slow-startup ()
  (let ((best most-positive-fixnum))
    (dotimes (_ 3)
      (let ((t0 (float-time)))
        (call-process test-emacs nil nil nil "--batch" "--init-directory" (getenv "CONFIG_DIR")
                      "-l" (expand-file-name "early-init.el" (getenv "CONFIG_DIR"))
                      "-l" (expand-file-name "init.el" (getenv "CONFIG_DIR"))
                      "--eval" "(kill-emacs)")
        (setq best (min best (- (float-time) t0)))))
    (should (< best 0.5))))

;;; Configuration: every value here is deliberate, not a default left untouched --- see
;;; config/session.el's own comments for the real reasoning (and, for desktop-auto-save-
;;; timeout and desktop-load-locked-desktop, the real bugs/gaps that led to each one).

(ert-deftest session/desktop-points-at-its-own-directory ()
  (should (equal desktop-dirname my/session-dir))
  (should (equal desktop-path (list my/session-dir)))
  (should (file-directory-p my/session-dir)))

(ert-deftest session/saves-automatically-with-no-prompts ()
  (should (eq desktop-save t)))

(ert-deftest session/a-stale-lock-from-a-crash-is-recovered-not-asked-about ()
  ;; `check-pid': load anyway if the process that owned the lock is no longer running
  ;; locally (exactly the situation after a crash) --- never the built-in default `ask',
  ;; which would block an automatic startup restore on a question nothing answers.
  (should (eq desktop-load-locked-desktop 'check-pid)))

(ert-deftest session/auto-save-timeout-is-short-not-the-30s-default ()
  ;; Confirmed for real: with the stock 30s default (`auto-save-timeout'), a session
  ;; crashed well before that idle threshold elapsed had no saved desktop at all.
  (should (integerp desktop-auto-save-timeout))
  (should (<= desktop-auto-save-timeout 10)))

(ert-deftest session/restore-eager-is-a-small-number-not-unbounded ()
  ;; Keeps a big saved session from blocking startup --- this config measures and cares
  ;; about startup speed; a huge session should restore lazily, not synchronously.
  (should (integerp desktop-restore-eager))
  (should (<= desktop-restore-eager 25)))

;;; The real regression test: `desktop-save's RELEASE argument

(ert-deftest session/save-and-claim-ownership-never-release-the-lock ()
  "`desktop-save's SECOND argument is RELEASE (let go of the lock), not \"force
save\" --- an easy, real mistake (made once while building this feature) that
silently defeats the periodic autosave forever, since it never gets to claim
ownership in the first place.  Both functions that call `desktop-save' here must
call it with no second argument (or an explicitly nil one), never a non-nil one."
  (let (calls)
    (cl-letf (((symbol-function 'desktop-save)
               (lambda (&rest args) (push args calls) nil)))
      (my/session-save)
      (my/session--claim-ownership)
      (should (= 2 (length calls)))
      (dolist (args calls)
        (should (equal (car args) my/session-dir))
        (should-not (cadr args))))))         ; RELEASE must be nil/absent, never t

;;; Reset: `C-c w r' --- discard the saved session, but keep future saves working

(ert-deftest session/reset-clears-then-removes-then-keeps-dirname-usable ()
  (let (calls (my/session-dir "/tmp/fake-session-dir-for-test/"))
    (cl-letf (((symbol-function 'desktop-clear) (lambda () (push 'clear calls)))
              ((symbol-function 'desktop-remove)
               (lambda ()
                 (push 'remove calls)
                 (setq desktop-dirname nil)))     ; the real side effect that must be undone
              ((symbol-function 'message) (lambda (&rest _) nil)))
      (my/session-reset)
      ;; clear before remove: no point deleting the file before the live buffers are gone
      (should (equal (nreverse calls) '(clear remove)))
      ;; the real bug this guards: `desktop-remove' sets `desktop-dirname' to nil, which
      ;; would otherwise make Emacs prompt "Directory for desktop file?" on the next exit
      (should (equal desktop-dirname my/session-dir)))))

;;; A real, headless round trip: save a desktop with real file buffers (one left locked,
;;; one deliberately unlocked and edited), kill them, `desktop-read' it back, and confirm
;;; both the buffer list and the read-only lock come back correctly.  No real GUI frame is
;;; needed for this --- confirmed separately, by hand, that the same thing holds with a
;;; real window split and a real `kill -9'; this is the fast, always-run version of that.

(ert-deftest session/restore-round-trip-reopens-files-and-reapplies-the-read-only-lock ()
  (test-with-temp-dir dir
    (let* ((desktop-dirname dir) (desktop-path (list dir)) (desktop-save t)
           (a (concat dir "a.txt")) (b (concat dir "b.txt")))
      (with-temp-file a (insert "file a\n"))
      (with-temp-file b (insert "file b\n"))
      (unwind-protect
          (progn
            ;; open both (my/make-file-buffer-read-only locks them, same as any find-file)
            (find-file a)
            (find-file b)
            (allow-editing)                          ; deliberately unlock b, like a real edit session
            (should-not (buffer-local-value 'buffer-read-only (get-buffer "b.txt")))
            (desktop-save dir)
            ;; simulate a fresh Emacs: the buffers are gone, only the files on disk remain
            (kill-buffer "a.txt") (kill-buffer "b.txt")
            (should-not (get-buffer "a.txt"))
            ;; Two things `desktop-read' checks first, both real and both only relevant
            ;; because this test simulates "a fresh Emacs" inside the SAME process that
            ;; just saved, which real usage never does (a real restore always happens in
            ;; a different process, with a different PID, after this one already exited
            ;; or crashed):
            ;; 1. It is unconditionally a no-op under `noninteractive' (its own docstring
            ;;    says so; confirmed for real, this test failed outright before adding
            ;;    this) --- true in every ERT run, since `./build.sh test' always runs
            ;;    `emacs --batch'.  Real interactive use is never `noninteractive'.
            ;; 2. It also silently declines if `(desktop-owner)' already equals
            ;;    `(emacs-pid)' --- true here only because THIS SAME process claimed the
            ;;    lock two lines ago via `desktop-save'; a real second process reading
            ;;    the file back would have a different PID, so this never applies for
            ;;    real.  Releasing the lock first re-creates the real condition: the file
            ;;    exists, but nothing currently owns it.
            (desktop-release-lock dir)
            (let ((noninteractive nil)) (desktop-read dir))
            (should (get-buffer "a.txt"))
            (should (get-buffer "b.txt"))
            (should (buffer-local-value 'buffer-read-only (get-buffer "a.txt")))
            ;; the important one: b was left UNLOCKED before saving, but restoring it goes
            ;; through find-file-noselect again, which reapplies the lock from scratch ---
            ;; a session restore never silently hands back an already-unlocked buffer
            (should (buffer-local-value 'buffer-read-only (get-buffer "b.txt"))))
        (dolist (name '("a.txt" "b.txt"))
          (when (get-buffer name) (kill-buffer name)))
        (desktop-release-lock dir)))))

;;; Listing what's in the session (C-c w l): "can it list states like buffers?"

(ert-deftest session/tracked-buffers-uses-desktops-own-real-filter ()
  ;; Not a hand-rolled guess at which buffers count: `desktop-save-buffer-p' is the exact
  ;; predicate `desktop-save' itself uses, so this test (and the feature) automatically
  ;; stays correct even if that predicate's own rules ever change.
  (test-with-temp-dir dir
    (let ((f (concat dir "tracked.txt")))
      (with-temp-file f (insert "x"))
      (unwind-protect
          (progn
            (find-file f)
            (should (memq (get-buffer "tracked.txt") (my/session--tracked-buffers)))
            ;; a plain non-file buffer is excluded by desktop's own default filter
            (should-not (memq (get-buffer-create " *not-a-file*") (my/session--tracked-buffers))))
        (when (get-buffer "tracked.txt") (kill-buffer "tracked.txt"))
        (when (get-buffer " *not-a-file*") (kill-buffer " *not-a-file*"))))))

(ert-deftest session/list-buffer-shows-every-tracked-file-and-marks-modified-ones ()
  (test-with-temp-dir dir
    (let ((a (concat dir "a.txt")) (b (concat dir "b.txt")))
      (with-temp-file a (insert "a"))
      (with-temp-file b (insert "b"))
      (unwind-protect
          (progn
            (find-file a)
            (find-file b)
            (allow-editing)
            (insert "more")                    ; makes b.txt's buffer modified, a.txt's not
            (my/session-list)
            (let ((txt (with-current-buffer my/session-list-buffer-name (buffer-string))))
              (should (string-match-p (regexp-quote a) txt))
              (should (string-match-p (regexp-quote b) txt))
              (should (string-match-p (concat (regexp-quote b) ".*(modified)") txt))
              (should-not (string-match-p (concat (regexp-quote a) ".*(modified)") txt))))
        (dolist (name '("a.txt" "b.txt"))
          (when (get-buffer name) (kill-buffer name)))
        (when (get-buffer my/session-list-buffer-name) (kill-buffer my/session-list-buffer-name))))))

(ert-deftest session/list-buffer-close-key-is-real ()
  (unwind-protect
      (progn
        (my/session-list)
        (with-current-buffer my/session-list-buffer-name
          (should (eq (key-binding (kbd "q")) 'quit-window))))
    (when (get-buffer my/session-list-buffer-name) (kill-buffer my/session-list-buffer-name))))

;;; session.el ends here
