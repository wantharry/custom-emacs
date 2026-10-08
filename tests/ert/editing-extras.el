;;; editing-extras.el --- bindings copied from tsoding/rexim's own dotfiles  -*- lexical-binding: t; -*-
;; harness: config
;; Covers the batch read directly from github.com/rexim/dotfiles's `.emacs' and
;; `.emacs.rc/misc-rc.el' and ported here: `my/duplicate-line', `my/unfill-paragraph',
;; `find-file-at-point', the Emacs-Lisp-only `C-c C-j', and the two extra
;; `multiple-cursors'/`move-text' bindings. See docs/KEYBOARD.md and this file's own
;; entry in init.el for which of his bindings were deliberately left out, and why.

(ert-deftest editing-extras/duplicate-line-key-is-bound ()
  (should (eq (key-binding (kbd "C-,")) #'my/duplicate-line)))

(ert-deftest editing-extras/duplicate-line-inserts-a-copy-right-below ()
  (test-in-buffer #'text-mode "hello\nworld"
    (forward-char 2) ; column 2 on "hello"
    (my/duplicate-line)
    (should (equal (buffer-string) "hello\nhello\nworld"))
    ;; Cursor lands on the new copy, same column as before.
    (should (= (line-number-at-pos) 2))
    (should (= (- (point) (line-beginning-position)) 2))))

(ert-deftest editing-extras/duplicate-line-works-on-the-last-line-too ()
  ;; A real edge case his own `thing-at-point' + `string-remove-suffix "\n"' logic
  ;; has to handle: the last line of a buffer has no trailing newline to strip.
  (test-in-buffer #'text-mode "only line"
    (my/duplicate-line)
    (should (equal (buffer-string) "only line\nonly line"))))

(ert-deftest editing-extras/unfill-paragraph-key-is-bound ()
  (should (eq (key-binding (kbd "C-c M-q")) #'my/unfill-paragraph)))

(ert-deftest editing-extras/unfill-paragraph-joins-every-line-into-one ()
  (test-in-buffer #'text-mode "one\ntwo\nthree"
    (my/unfill-paragraph)
    (should (equal (buffer-string) "one two three"))))

(ert-deftest editing-extras/find-file-at-point-key-is-bound ()
  ;; Built into Emacs itself (`ffap.el'); just confirming it is actually reachable
  ;; from this config's own global map, not re-testing Emacs's own command.
  (should (eq (key-binding (kbd "C-x C-g")) #'find-file-at-point)))

(ert-deftest editing-extras/eval-print-last-sexp-is-local-to-emacs-lisp-mode-only ()
  ;; His own binding is mode-local (an `emacs-lisp-mode-hook'), not global --- confirm
  ;; it really only applies inside Emacs Lisp buffers, so it cannot shadow `C-c C-j'
  ;; anywhere else.
  (should-not (eq (key-binding (kbd "C-c C-j")) #'eval-print-last-sexp))
  (test-in-buffer #'emacs-lisp-mode "(+ 1 2)"
    (should (eq (key-binding (kbd "C-c C-j")) #'eval-print-last-sexp))))

;; The two extra `multiple-cursors' conventions (`mc/edit-lines', `mc/skip-to-next-
;; like-this', `mc/skip-to-previous-like-this') and `move-text-up'/`move-text-down'
;; all follow this project's own "real command if installed, else an explainer"
;; pattern (`tests/ert/keybindings.el' already checks the real commands end up bound
;; whenever the package is actually on disk); these two tests only cover the part
;; that table-driven check does not: the explainer itself still works correctly on a
;; machine missing the package, same as every other optional package in this config.
(ert-deftest editing-extras/missing-fallbacks-explain-how-to-fix-it ()
  (should (string-match-p "multiple-cursors.*\\./build.sh packages"
                           (let ((msg nil))
                             (cl-letf (((symbol-function 'message) (lambda (fmt &rest args) (setq msg (apply #'format fmt args)))))
                               (my/multiple-cursors-missing))
                             msg)))
  (should (string-match-p "move-text.*\\./build.sh packages"
                           (let ((msg nil))
                             (cl-letf (((symbol-function 'message) (lambda (fmt &rest args) (setq msg (apply #'format fmt args)))))
                               (my/move-text-missing))
                             msg))))

;;; editing-extras.el ends here
