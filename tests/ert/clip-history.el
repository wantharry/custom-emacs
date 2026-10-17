;;; clip-history.el --- C-c C-y, kept genuinely separate from the kill-ring  -*- lexical-binding: t; -*-
;; harness: config

;; WHAT/WHY: `my/clip-history--poll' itself is timer-driven and reads the REAL
;; system clipboard, so it is not exercised directly here (no real display
;; connection in a `--batch' harness) --- these tests call it as a plain
;; function instead, same as any other unit under test, and isolate its own
;; state (`my/clip-history'/`--last'/`--skip') so tests cannot see each
;; other's leftovers.

(defmacro ch-isolated (&rest body)
  (declare (indent 0))
  `(let (my/clip-history my/clip-history--last my/clip-history--skip)
     ,@body))

(ert-deftest clip-history/key-is-bound ()
  (should (eq (key-binding (kbd "C-c C-y")) #'my/clip-history-browse)))

(ert-deftest clip-history/m-y-is-consult-yank-pop-when-consult-is-installed ()
  (if (locate-library "consult")
      (should (eq (key-binding (kbd "M-y")) #'consult-yank-pop))
    (should (eq (key-binding (kbd "M-y")) #'yank-pop))))

(ert-deftest clip-history/poll-is-a-no-op-without-a-real-display ()
  ;; The real, found-the-hard-way guard this whole feature exists because of:
  ;; checked on EVERY tick, not once at config-load time (see the function's
  ;; own docstring) --- confirmed directly here, in the one context (`--batch')
  ;; where `display-graphic-p' really is nil, exactly like a `--fg-daemon'
  ;; with no frame attached yet.
  (ch-isolated
    (should-not (display-graphic-p))
    (my/clip-history--poll)
    (should-not my/clip-history)))

(ert-deftest clip-history/poll-logs-a-real-new-clipboard-value ()
  (ch-isolated
    (cl-letf (((symbol-function 'display-graphic-p) (lambda (&rest _) t))
              ((symbol-function 'gui-get-selection) (lambda (&rest _) "a real clipboard value")))
      (my/clip-history--poll))
    (should (equal my/clip-history '("a real clipboard value")))))

(ert-deftest clip-history/poll-never-logs-the-same-unchanged-value-twice ()
  (ch-isolated
    (cl-letf (((symbol-function 'display-graphic-p) (lambda (&rest _) t))
              ((symbol-function 'gui-get-selection) (lambda (&rest _) "steady value")))
      (my/clip-history--poll)
      (my/clip-history--poll)
      (my/clip-history--poll))
    (should (equal my/clip-history '("steady value")))))

(ert-deftest clip-history/poll-logs-each-new-distinct-value-newest-first ()
  (ch-isolated
    (let ((current "first"))
      (cl-letf (((symbol-function 'display-graphic-p) (lambda (&rest _) t))
                ((symbol-function 'gui-get-selection) (lambda (&rest _) current)))
        (my/clip-history--poll)
        (setq current "second")
        (my/clip-history--poll)))
    (should (equal my/clip-history '("second" "first")))))

(ert-deftest clip-history/poll-caps-at-clip-history-max ()
  (ch-isolated
    (let ((my/clip-history-max 3) (current nil))
      (cl-letf (((symbol-function 'display-graphic-p) (lambda (&rest _) t))
                ((symbol-function 'gui-get-selection) (lambda (&rest _) current)))
        (dolist (v '("a" "b" "c" "d" "e"))
          (setq current v)
          (my/clip-history--poll))))
    (should (equal my/clip-history '("e" "d" "c")))))

(ert-deftest clip-history/poll-never-logs-a-value-marked-as-a-pass-secret ()
  ;; The real security carve-out `my/pass-find'/`my/pass-generate' rely on
  ;; (config/init.el): a secret they just copied must never join this
  ;; separate, persisted history, even though the poller reads the exact
  ;; same real system clipboard they just wrote to.
  (ch-isolated
    (setq my/clip-history--skip "a real secret")
    (cl-letf (((symbol-function 'display-graphic-p) (lambda (&rest _) t))
              ((symbol-function 'gui-get-selection) (lambda (&rest _) "a real secret")))
      (my/clip-history--poll))
    (should-not my/clip-history)
    ;; And the skip flag is a one-shot --- consumed the moment it is actually
    ;; seen, not a permanent block on that string ever appearing again.
    (should-not my/clip-history--skip)))

(ert-deftest clip-history/poll-never-logs-something-equal-to-an-empty-clipboard ()
  (ch-isolated
    (cl-letf (((symbol-function 'display-graphic-p) (lambda (&rest _) t))
              ((symbol-function 'gui-get-selection) (lambda (&rest _) "")))
      (my/clip-history--poll))
    (should-not my/clip-history)))

(ert-deftest clip-history/poll-tolerates-gui-get-selection-signaling-an-error ()
  ;; A real edge case this config's own `ignore-errors' guards against ---
  ;; no clipboard owner at all, or a non-text selection, both real things
  ;; `gui-get-selection' can signal on rather than just returning nil.
  (ch-isolated
    (cl-letf (((symbol-function 'display-graphic-p) (lambda (&rest _) t))
              ((symbol-function 'gui-get-selection) (lambda (&rest _) (error "no selection owner"))))
      (should-not (condition-case nil (progn (my/clip-history--poll) nil) (error t))))
    (should-not my/clip-history)))

(ert-deftest clip-history/browse-copies-the-chosen-entry-and-says-so ()
  (ch-isolated
    (setq my/clip-history '("newest" "older"))
    (cl-letf (((symbol-function 'completing-read) (lambda (&rest _) "older"))
              ((symbol-function 'message) (lambda (fmt &rest _) fmt)))
      (should (equal (my/clip-history-browse) "Copied back to the clipboard")))
    (should (equal (car kill-ring) "older"))))

(ert-deftest clip-history/browse-says-so-plainly-when-empty-rather-than-erroring ()
  (ch-isolated
    (let (msg)
      (cl-letf (((symbol-function 'message) (lambda (fmt &rest a) (setq msg (apply #'format fmt a)))))
        (my/clip-history-browse))
      (should (string-match-p "empty" msg)))))

(ert-deftest clip-history/is-added-to-desktop-globals-to-save ()
  (should (memq 'my/clip-history desktop-globals-to-save)))

;;; clip-history.el ends here
