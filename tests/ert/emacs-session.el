;;; emacs-session.el --- crash-safe auto-save and session restore (C-c w)  -*- lexical-binding: t; -*-
;; harness: config
;;
;; Several of these tests exist specifically because the real behavior surprised the real
;; testing that built this feature, not just because "more tests are good":
;;
;; - `desktop-save's second argument is RELEASE, not "force save" --- passing it non-nil
;;   (an easy mistake, made here at first) releases the desktop lock instead of claiming
;;   it, silently defeating the whole periodic-autosave mechanism forever.  Caught only by
;;   a real crash-and-restore cycle, not by reading the source. See `emacs-session/save-and-
;;   claim-ownership-never-release-the-lock' below, which pins this down for good.
;; - The read-only lock (init.el's `my/make-file-buffer-read-only') really does reapply to
;;   a buffer `desktop-read' restores, since desktop.el restores buffers via `find-file-
;;   noselect' --- confirmed for real (see `emacs-session/restore-round-trip...' below).

(require 'emacs-session (expand-file-name "emacs-session" (or (getenv "CONFIG_DIR") user-emacs-directory)))

;;; Wiring

(ert-deftest emacs-session/keys-are-bound ()
  (should (eq (key-binding (kbd "C-c w s")) 'my/session-save))
  (should (eq (key-binding (kbd "C-c w r")) 'my/session-reset))
  (should (eq (key-binding (kbd "C-c w l")) 'my/session-list)))

(ert-deftest emacs-session/is-loaded-eagerly-not-autoloaded ()
  ;; Unlike most feature files here (dictate.el, llm.el, ...), this one has to be loaded
  ;; while init.el itself is still loading --- see the file header comment in
  ;; config/emacs-session.el for why (desktop.el's own `after-init-hook' entry is what
  ;; actually restores a saved session, and that only works if desktop-save-mode is
  ;; already on by the time it fires).
  (let ((out (with-output-to-string
               (with-current-buffer standard-output
                 (call-process test-emacs nil t nil "--batch" "--init-directory" (getenv "CONFIG_DIR")
                               "-l" (expand-file-name "early-init.el" (getenv "CONFIG_DIR"))
                               "-l" (expand-file-name "init.el" (getenv "CONFIG_DIR"))
                               "--eval" "(princ (list (featurep 'emacs-session) desktop-save-mode auto-save-visited-mode))")))))
    (should (string-match-p "(t t t)" out))))

;; WHAT: `org-mode' works, in the real, fully-loaded config, with this file already
;; loaded (which it always is by the time anything else runs --- see the test just
;; above).  WHY: this is the actual regression this file's own name change fixed, not a
;; hypothetical --- confirmed directly, reproduced first, only fixed after: with this
;; file `(provide 'session)' (its name before this fix), simply running `M-x org-mode'
;; after a completely normal startup errored with "Symbol's value as variable is void:
;; session-globals-exclude". Cause: Org's own `org-compat.el' registers
;; `(eval-after-load 'session ...)', expecting the real, well-known third-party
;; `session' package (`session-globals-exclude' is one of its variables) --- this file
;; satisfied that same trigger under its old name purely by coincidence, running Org's
;; hook against a file that never defined that variable at all. A plain `(require
;; 'org)' with no config loaded never hit this (nothing had registered the `session'
;; feature name yet); only going through the real, fully-loaded config did --- exactly
;; why this checks the real thing end to end, in a fresh subprocess, rather than
;; `(require 'org)' in isolation.
(ert-deftest emacs-session/does-not-collide-with-orgs-own-session-package-hook ()
  (skip-unless (locate-library "org"))
  (let ((out (with-output-to-string
               (with-current-buffer standard-output
                 (call-process test-emacs nil t nil "--batch" "--init-directory" (getenv "CONFIG_DIR")
                               "-l" (expand-file-name "early-init.el" (getenv "CONFIG_DIR"))
                               "-l" (expand-file-name "init.el" (getenv "CONFIG_DIR"))
                               "--eval" "(with-temp-buffer (org-mode))"
                               "--eval" "(princ \"org-mode-worked\")")))))
    (should (string-match-p "org-mode-worked" out))
    (should-not (string-match-p "session-globals-exclude" out))))

(ert-deftest emacs-session/does-not-slow-startup ()
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
;;; config/emacs-session.el's own comments for the real reasoning (and, for desktop-auto-save-
;;; timeout and desktop-load-locked-desktop, the real bugs/gaps that led to each one).

(ert-deftest emacs-session/desktop-points-at-its-own-directory ()
  (should (equal desktop-dirname my/session-dir))
  (should (equal desktop-path (list my/session-dir)))
  (should (file-directory-p my/session-dir)))

(ert-deftest emacs-session/saves-automatically-with-no-prompts ()
  (should (eq desktop-save t)))

(ert-deftest emacs-session/a-stale-lock-from-a-crash-is-recovered-not-asked-about ()
  ;; `check-pid': load anyway if the process that owned the lock is no longer running
  ;; locally (exactly the situation after a crash) --- never the built-in default `ask',
  ;; which would block an automatic startup restore on a question nothing answers.
  (should (eq desktop-load-locked-desktop 'check-pid)))

(ert-deftest emacs-session/auto-save-timeout-is-short-not-the-30s-default ()
  ;; Confirmed for real: with the stock 30s default (`auto-save-timeout'), a session
  ;; crashed well before that idle threshold elapsed had no saved desktop at all.
  (should (integerp desktop-auto-save-timeout))
  (should (<= desktop-auto-save-timeout 10)))

(ert-deftest emacs-session/restore-eager-is-a-small-number-not-unbounded ()
  ;; Keeps a big saved session from blocking startup --- this config measures and cares
  ;; about startup speed; a huge session should restore lazily, not synchronously.
  (should (integerp desktop-restore-eager))
  (should (<= desktop-restore-eager 25)))

;;; The real regression test: `desktop-save's RELEASE argument

(ert-deftest emacs-session/save-and-claim-ownership-never-release-the-lock ()
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

(ert-deftest emacs-session/reset-clears-then-removes-then-keeps-dirname-usable ()
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

(ert-deftest emacs-session/restore-round-trip-reopens-files-and-reapplies-the-read-only-lock ()
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

(ert-deftest emacs-session/tracked-buffers-uses-desktops-own-real-filter ()
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

(ert-deftest emacs-session/list-buffer-shows-every-tracked-file-and-marks-modified-ones ()
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

(ert-deftest emacs-session/list-buffer-close-key-is-real ()
  (unwind-protect
      (progn
        (my/session-list)
        (with-current-buffer my/session-list-buffer-name
          (should (eq (key-binding (kbd "q")) 'quit-window))))
    (when (get-buffer my/session-list-buffer-name) (kill-buffer my/session-list-buffer-name))))

;;; Named sessions (C-c w S/O/D/L): "how many can be saved, is that a possibility?"
;;;
;;; Several of these exist for the same reason as the top-of-file ones: `desktop-save'
;;; and `desktop-read' both have real side effects beyond their obvious job (confirmed by
;;; reading their source, and by two real prompts/errors a naive implementation hit) that
;;; a naive "just call desktop-save/-read on a different directory" implementation would
;;; have let leak into the live, auto-saving session.

(defmacro session--with-isolated-dirs (&rest body)
  "Run BODY with the live session and the named-session root both pointed at fresh
temp directories, so these tests never touch the real config's own session state."
  (declare (indent 0))
  `(test-with-temp-dir live-dir
     (test-with-temp-dir named-root
       (let ((my/session-dir live-dir) (my/session-named-root named-root)
             (desktop-dirname live-dir) (desktop-path (list live-dir)))
         ,@body))))

(ert-deftest emacs-session/named-keys-are-bound ()
  (should (eq (key-binding (kbd "C-c w S")) 'my/session-save-as))
  (should (eq (key-binding (kbd "C-c w O")) 'my/session-open))
  (should (eq (key-binding (kbd "C-c w D")) 'my/session-delete))
  (should (eq (key-binding (kbd "C-c w L")) 'my/session-named-list)))

(ert-deftest emacs-session/name-is-sanitized ()
  (should-error (my/session--sanitize-name "") :type 'user-error)
  (should-error (my/session--sanitize-name "a/b") :type 'user-error)
  (should-error (my/session--sanitize-name ".") :type 'user-error)
  (should-error (my/session--sanitize-name "..") :type 'user-error)
  (should (equal (my/session--sanitize-name "  work  ") "work")))

(ert-deftest emacs-session/save-as-does-not-disturb-the-live-session ()
  (session--with-isolated-dirs
    (let ((f (concat live-dir "live.txt")))
      (with-temp-file f (insert "x"))
      (unwind-protect
          (progn
            (find-file f)
            (my/session-save-as "work")
            ;; the live session's own pointer is untouched
            (should (equal desktop-dirname live-dir))
            (should (equal desktop-path (list live-dir)))
            ;; the named snapshot really was written, in its own directory
            (should (file-exists-p (expand-file-name desktop-base-file-name
                                                      (my/session--named-dir "work"))))
            (should-not (file-exists-p (expand-file-name desktop-base-file-name live-dir))))
        (when (get-buffer "live.txt") (kill-buffer "live.txt"))))))

(ert-deftest emacs-session/open-restores-the-snapshot-and-keeps-the-live-dir-anchored ()
  (session--with-isolated-dirs
    (let ((f (concat live-dir "live.txt")))
      (with-temp-file f (insert "x"))
      (unwind-protect
          (progn
            (find-file f)
            (my/session-save-as "work")
            (kill-buffer "live.txt")
            (should-not (get-buffer "live.txt"))
            (my/session-open "work")
            (should (get-buffer "live.txt"))
            ;; still anchored at the live dir, not the named one, after opening
            (should (equal desktop-dirname live-dir)))
        (when (get-buffer "live.txt") (kill-buffer "live.txt"))))))

(ert-deftest emacs-session/open-can-be-repeated-without-the-lock-blocking-it ()
  ;; The real bug: `desktop-read' claims the lock of whatever it reads and never
  ;; releases it, so a second `desktop-read' of the SAME directory by the same process
  ;; silently declines ("Not reloading the desktop"). `my/session-open' must release the
  ;; named directory's lock after every open, so opening the same name twice both times
  ;; genuinely restores it.
  (session--with-isolated-dirs
    (let ((f (concat live-dir "live.txt")))
      (with-temp-file f (insert "x"))
      (unwind-protect
          (progn
            (find-file f)
            (my/session-save-as "work")
            (kill-buffer "live.txt")
            (my/session-open "work")
            (should (get-buffer "live.txt"))
            (kill-buffer "live.txt")
            (my/session-open "work")               ; second open of the same name
            (should (get-buffer "live.txt")))       ; must still restore it, not skip
        (when (get-buffer "live.txt") (kill-buffer "live.txt"))))))

(ert-deftest emacs-session/save-as-can-be-repeated-under-the-same-name-with-no-prompt ()
  ;; The other real bug: leaving `desktop-file-modtime' at the live session's own value
  ;; made a second save under the same name think the file had changed out from under
  ;; it and ask "Overwrite this desktop file?" -- which, with no terminal attached,
  ;; doesn't wait forever, it errors ("Error reading from stdin"). A plain re-save must
  ;; not prompt or error at all.
  (session--with-isolated-dirs
    (let ((f (concat live-dir "live.txt")))
      (with-temp-file f (insert "x"))
      (unwind-protect
          (progn
            (find-file f)
            (my/session-save-as "work")
            (should-not (condition-case nil (progn (my/session-save-as "work") nil)
                          (error t))))
        (when (get-buffer "live.txt") (kill-buffer "live.txt"))))))

(ert-deftest emacs-session/open-with-no-such-name-is-a-clear-error ()
  (session--with-isolated-dirs
    (should-error (my/session-open "does-not-exist") :type 'user-error)))

(ert-deftest emacs-session/open-and-delete-with-nothing-saved-yet-is-a-clear-error ()
  (session--with-isolated-dirs
    (cl-letf (((symbol-function 'completing-read) (lambda (&rest _) "")))
      (should-error (call-interactively #'my/session-open) :type 'user-error)
      (should-error (call-interactively #'my/session-delete) :type 'user-error))))

(ert-deftest emacs-session/delete-asks-first-and-only-deletes-on-yes ()
  (session--with-isolated-dirs
    (let ((f (concat live-dir "live.txt")))
      (with-temp-file f (insert "x"))
      (unwind-protect
          (progn
            (find-file f)
            (my/session-save-as "work")
            (let ((dir (my/session--named-dir "work")))
              (cl-letf (((symbol-function 'yes-or-no-p) (lambda (&rest _) nil)))
                (my/session-delete "work")
                (should (file-directory-p dir)))     ; declined: still there
              (cl-letf (((symbol-function 'yes-or-no-p) (lambda (&rest _) t)))
                (my/session-delete "work")
                (should-not (file-directory-p dir)))))  ; confirmed: gone
        (when (get-buffer "live.txt") (kill-buffer "live.txt"))))))

(ert-deftest emacs-session/named-list-shows-every-saved-name-and-none-yet-message ()
  (session--with-isolated-dirs
    (unwind-protect
        (progn
          (should (string-match-p "none yet" (with-current-buffer (progn (my/session-named-list)
                                                                          (current-buffer))
                                                (buffer-string))))
          (let ((f (concat live-dir "live.txt")))
            (with-temp-file f (insert "x"))
            (find-file f)
            (my/session-save-as "alpha")
            (my/session-save-as "beta")
            (kill-buffer "live.txt"))
          (my/session-named-list)
          (let ((txt (with-current-buffer my/session-named-list-buffer-name (buffer-string))))
            (should (string-match-p "alpha" txt))
            (should (string-match-p "beta" txt))
            (should (string-match-p "2 saved" txt))))
      (when (get-buffer my/session-named-list-buffer-name) (kill-buffer my/session-named-list-buffer-name)))))

(ert-deftest emacs-session/named-list-close-key-is-real ()
  (unwind-protect
      (progn
        (my/session-named-list)
        (with-current-buffer my/session-named-list-buffer-name
          (should (eq (key-binding (kbd "q")) 'quit-window))))
    (when (get-buffer my/session-named-list-buffer-name) (kill-buffer my/session-named-list-buffer-name))))

;;; emacs-session.el ends here
