;;; mode-reference.el --- every key the reference panel claims is real  -*- lexical-binding: t; -*-
;; harness: config

(require 'dired)
(require 'org)

;; WHAT/WHY: user request --- the same always-visible reference panel, extended to
;; `ranger' and Treemacs, the two other file browsers this session built real cross-
;; navigation between. Every key in BOTH new texts was individually re-verified
;; against the real `ranger-mode-map'/`treemacs-mode-map' before being written here,
;; the same discipline the comment above describes for Dired/Org --- confirmed by the
;; two tests below, not just asserted.

;; The real bug this whole file exists to pin down, found by the user, not caught by
;; anything until then: an earlier version of the panel's text was transcribed from
;; Casual's own `C-o' menu labels, which look like real standalone keybindings but
;; mostly are not --- most of them only mean anything while that menu has focus. `F'
;; (claimed as "New file") did nothing as a bare keypress ("F is undefined"); several
;; Dired entries were bound to entirely different real commands than claimed; most Org
;; entries were simply missing their real `C-c' prefix. Spot-checking a couple of
;; substrings (what the existing `tests/test_tui.py' checks do) would not have caught
;; this --- this test parses every single KEY column out of the real panel text and
;; verifies each one directly against the real keymap, the same way `tests/ert/
;; keybindings.el' already does for the doc guides.

(defun mref--parse-keys (text)
  "Return every KEY from TEXT's own \"KEY   description\" lines (the panel's own
format: a title line, blank lines, \"-- Section --\" headers, then one entry per line).
Entries whose key field contains \"/\" (shorthand for two keys, e.g. \"p/n\") are
skipped --- not real `kbd' syntax on their own, manually double-checked instead when
the content was written."
  (let (keys)
    (dolist (line (split-string text "\n"))
      (when (and (string-match "\\`\\([^ ]+\\) +\\S-" line)
                 (not (string-prefix-p "--" line))
                 (not (string-match-p "/" (match-string 1 line))))
        (push (match-string 1 line) keys)))
    (nreverse keys)))

(ert-deftest mode-reference/off-by-default ()
  ;; WHAT/WHY: user request --- the panel used to turn itself on unconditionally at
  ;; startup; now nothing in config/init.el calls `(my/mode-reference-mode 1)' any
  ;; more, only `C-c H' itself does. Confirmed directly against the real global
  ;; state the config harness leaves it in, not just grepped for in the source.
  (should-not my/mode-reference-mode))

(ert-deftest mode-reference/every-dired-key-is-really-bound ()
  (let ((keys (mref--parse-keys my/mode-reference-dired-text)))
    (should (> (length keys) 20)) ; sanity: the parser itself found a reasonable amount
    (dolist (key keys)
      (should (lookup-key dired-mode-map (kbd key))))))

(ert-deftest mode-reference/every-org-key-is-really-bound ()
  (let ((keys (mref--parse-keys my/mode-reference-org-text)))
    (should (> (length keys) 15))
    (dolist (key keys)
      (should (lookup-key org-mode-map (kbd key))))))

(ert-deftest mode-reference/every-ranger-key-is-really-bound ()
  (if (not (locate-library "ranger"))
      (ert-skip "ranger is not installed (./build.sh packages)")
    (require 'ranger)
    (let ((keys (mref--parse-keys my/mode-reference-ranger-text)))
      (should (> (length keys) 15))
      (dolist (key keys)
        (should (lookup-key ranger-mode-map (kbd key)))))))

(ert-deftest mode-reference/every-treemacs-key-is-really-bound ()
  (if (not (locate-library "treemacs"))
      (ert-skip "treemacs is not installed (./build.sh packages)")
    (require 'treemacs)
    (let ((keys (mref--parse-keys my/mode-reference-treemacs-text)))
      (should (> (length keys) 15))
      (dolist (key keys)
        (should (lookup-key treemacs-mode-map (kbd key)))))))

(ert-deftest mode-reference/re-anchors-to-the-top-after-a-resize ()
  ;; A real, user-reported bug (a real screenshot, not assumed): `C-c U' (`my/reset-to-
  ;; defaults') toggles the menu bar/tool bar, which changes the real frame's pixel
  ;; geometry in a GUI --- that resize left the panel scrolled a little way down from
  ;; its own top, with nothing re-anchoring it afterward (`my/mode-reference--show'
  ;; only ever set `window-start' once, the moment the window was first created).
  ;; Confirmed the fix works directly: force the window to an artificially scrolled
  ;; position, call `--update' the same way a resize or `C-c U' itself now does, and
  ;; check it actually comes back to the top.
  (test-with-temp-dir dir
    (unwind-protect
        (progn
          (dired dir)
          (my/mode-reference--update)
          (let ((win (get-buffer-window my/mode-reference-buffer-name t)))
            (should win)
            (set-window-start win (with-current-buffer my/mode-reference-buffer-name (point-max)))
            (should-not (eq (window-start win)
                            (with-current-buffer my/mode-reference-buffer-name (point-min))))
            (my/mode-reference--update)
            (should (eq (window-start win)
                       (with-current-buffer my/mode-reference-buffer-name (point-min))))))
      (my/mode-reference--hide)
      (kill-buffer my/mode-reference-buffer-name))))

;; WHAT/WHY: user request --- after `C-c H' showing nothing at all outside Dired/
;; Org/`ranger'/Treemacs turned out to be exactly backwards, the panel now shows
;; SOMETHING in any other buffer too: a comprehensive Evil-keys reference if Evil
;; is actually active in that specific buffer, or a comprehensive plain-Emacs
;; reference otherwise. The tests below confirm the real selection logic in
;; `my/mode-reference--relevant-mode', not just that the two text constants exist.

(ert-deftest mode-reference/emacs-fallback-shown-in-a-plain-buffer-with-evil-off ()
  (test-in-buffer #'text-mode "plain text, no Evil"
    (should-not (bound-and-true-p evil-local-mode))
    (should (eq (my/mode-reference--relevant-mode) 'emacs-fallback))
    (should (eq (my/mode-reference--text-for (my/mode-reference--relevant-mode))
                my/mode-reference-emacs-text))))

(ert-deftest mode-reference/evil-fallback-shown-in-a-plain-buffer-with-evil-on ()
  (skip-unless (locate-library "evil"))
  (require 'evil)
  (test-in-buffer #'text-mode "plain text, Evil on"
    (unwind-protect
        (progn
          (evil-local-mode 1)
          (should (eq (my/mode-reference--relevant-mode) 'evil-fallback))
          (should (eq (my/mode-reference--text-for (my/mode-reference--relevant-mode))
                      my/mode-reference-evil-text)))
      (evil-local-mode -1))))

(ert-deftest mode-reference/evil-fallback-checks-the-buffer-local-state-not-the-global-one ()
  ;; WHY: `my/mode-reference--relevant-mode' deliberately reads the buffer-local
  ;; `evil-local-mode', not the global `evil-mode' --- Evil can exclude a specific
  ;; buffer even while globally on, so the global variable alone would give the
  ;; wrong answer for THIS buffer. Proven for real, not simulated: turn Evil on
  ;; globally, then explicitly exclude just this one buffer from it, and confirm
  ;; the panel still picks the plain-Emacs text, not the Evil one.
  (skip-unless (locate-library "evil"))
  (require 'evil)
  (test-in-buffer #'text-mode "plain text"
    (unwind-protect
        (progn
          (evil-mode 1)
          (evil-local-mode -1)
          (should evil-mode)
          (should-not evil-local-mode)
          (should (eq (my/mode-reference--relevant-mode) 'emacs-fallback)))
      (evil-local-mode -1)
      (evil-mode -1))))

(ert-deftest mode-reference/dired-still-wins-over-the-generic-fallback ()
  ;; A real priority check: a buffer that IS one of the four specific modes must
  ;; still get its own dedicated text, not the generic fallback, even with Evil on.
  (skip-unless (locate-library "evil"))
  (require 'evil)
  (test-with-temp-dir dir
    (let (buf)
      (unwind-protect
          (progn
            (dired dir)
            (setq buf (current-buffer))
            (evil-local-mode 1)
            (should (eq (my/mode-reference--relevant-mode) 'dired-mode)))
        (when (buffer-live-p buf)
          (with-current-buffer buf (when (bound-and-true-p evil-local-mode) (evil-local-mode -1)))
          (kill-buffer buf))))))

(ert-deftest mode-reference/minibuffer-shows-nothing ()
  ;; `minibufferp' is a real Emacs primitive (not this project's own), so it is
  ;; stubbed here rather than driven through a real, asynchronous minibuffer read
  ;; --- this isolates the one thing that IS this project's own code: that
  ;; `my/mode-reference--relevant-mode''s `cond' checks it FIRST, before any of
  ;; the mode-derived branches, and returns nil rather than falling through to a
  ;; fallback text.
  (cl-letf (((symbol-function 'minibufferp) (lambda (&rest _) t)))
    (should-not (my/mode-reference--relevant-mode))))

(ert-deftest mode-reference/c-c-h-toggles-the-panel-on-and-off ()
  ;; WHAT/WHY: user request --- a key to turn this always-on-by-default panel off (and
  ;; back on) once comfortable without it. `my/mode-reference-mode' is a real `define-
  ;; minor-mode' (`:global t'), so calling it with no argument --- exactly what
  ;; `global-set-key' binding the bare command to `C-c H' does --- already toggles it;
  ;; this just confirms the key really reaches it and that toggling genuinely
  ;; shows/hides the real window, not just flips the variable. Restores the mode to
  ;; whatever it was before (on, by default) so later tests in the same `--batch'
  ;; process still see the panel enabled, matching every other test file's assumption.
  (should (eq (key-binding (kbd "C-c H")) 'my/mode-reference-mode))
  (let ((was-on my/mode-reference-mode))
    (unwind-protect
        (test-with-temp-dir dir
          (dired dir)
          (unless was-on (my/mode-reference-mode 1))
          (my/mode-reference--update)
          (should (get-buffer-window my/mode-reference-buffer-name t))
          (call-interactively 'my/mode-reference-mode)
          (should-not my/mode-reference-mode)
          (should-not (get-buffer-window my/mode-reference-buffer-name t))
          (call-interactively 'my/mode-reference-mode)
          (should my/mode-reference-mode)
          (my/mode-reference--update)
          (should (get-buffer-window my/mode-reference-buffer-name t)))
      (unless (eq (and my/mode-reference-mode t) (and was-on t))
        (my/mode-reference-mode (if was-on 1 -1)))
      (ignore-errors (kill-buffer my/mode-reference-buffer-name)))))

;;; mode-reference.el ends here
