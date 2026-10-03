;;; mode-reference.el --- every key the reference panel claims is real  -*- lexical-binding: t; -*-
;; harness: config

(require 'dired)
(require 'org)

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

;;; mode-reference.el ends here
