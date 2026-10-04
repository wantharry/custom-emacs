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

;;; mode-reference.el ends here
