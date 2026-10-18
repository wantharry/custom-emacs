;;; editing-extras.el --- bindings copied from another Emacs user's own dotfiles  -*- lexical-binding: t; -*-
;; harness: config
;; Covers the batch read directly from that public dotfiles repo's `.emacs' and
;; `.emacs.rc/misc-rc.el' and ported here: `my/duplicate-line', `my/unfill-paragraph',
;; `find-file-at-point', the Emacs-Lisp-only `C-c C-j', and the two extra
;; `multiple-cursors'/`move-text' bindings. See docs/KEYBOARD.md and this file's own
;; entry in init.el for which of those bindings were deliberately left out, and why.

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

(ert-deftest editing-extras/duplicate-line-works-on-a-blank-line ()
  (test-in-buffer #'text-mode "before\n\nafter"
    (goto-char (point-min)) (forward-line 1) ; the blank line
    (my/duplicate-line)
    (should (equal (buffer-string) "before\n\n\nafter"))))

(ert-deftest editing-extras/unfill-paragraph-leaves-other-paragraphs-alone ()
  ;; `my/unfill-paragraph' is `fill-paragraph' itself under an oversized `fill-column'
  ;; (see its own comment in init.el) --- it should only ever touch the CURRENT
  ;; paragraph, the same boundary-respecting behavior `fill-paragraph' already has.
  (test-in-buffer #'text-mode "one\ntwo\n\nthree\nfour\n"
    (goto-char (point-min))
    (my/unfill-paragraph)
    (should (equal (buffer-string) "one two\n\nthree\nfour\n"))))

;; The real `multiple-cursors' package this config binds `mc/mark-next-like-this'/
;; `mc/mark-previous-like-this'/`mc/mark-all-like-this'/`mc/edit-lines'/`mc/skip-to-
;; next-like-this'/`mc/skip-to-previous-like-this' to (see init.el) --- driven through
;; `execute-kbd-macro', not a plain `insert' call, because `multiple-cursors' only
;; replicates a command across every fake cursor from inside the real command loop
;; (`post-command-hook'); a raw Lisp `insert' only ever touches the one real cursor,
;; confirmed directly the hard way while writing these.
(defmacro mcx--with-marked-region (text &rest body)
  "Run BODY in a buffer containing TEXT with the first word already region-marked,
the state every `mc/mark-*' command expects to find before it is called."
  (declare (indent 1))
  `(test-in-buffer #'text-mode ,text
     (goto-char (point-min))
     (push-mark (point) t t) (forward-word 1) (activate-mark)
     ,@body))

;; No `deactivate-mark' before typing in any of these: every `mc/mark-*' command
;; leaves its matches actively MARKED (that is the point --- type a replacement once,
;; every marked occurrence gets it), and this config turns on `delete-selection-mode'
;; (see editing-commands.el), so typing replaces each marked word rather than
;; appending after it. An earlier version of these tests called `deactivate-mark'
;; first, expecting an append --- that only clears the REAL cursor's mark (each FAKE
;; cursor keeps its own, separately), so it produced an inconsistent mix of one
;; appended word and the rest replaced. Confirmed directly, the hard way.

(ert-deftest editing-extras/mc-mark-next-like-this-edits-both-occurrences ()
  (mcx--with-marked-region "foo bar foo"
    (mc/mark-next-like-this 1)
    (execute-kbd-macro "X")
    (should (= (mc/num-cursors) 2))
    (should (equal (buffer-string) "X bar X"))))

(ert-deftest editing-extras/mc-mark-previous-like-this-edits-the-earlier-occurrence ()
  (test-in-buffer #'text-mode "foo bar foo"
    (goto-char (point-max))
    (push-mark (point) t t) (backward-word 1) (activate-mark)
    (mc/mark-previous-like-this 1)
    (execute-kbd-macro "X")
    (should (= (mc/num-cursors) 2))
    (should (equal (buffer-string) "X bar X"))))

(ert-deftest editing-extras/mc-mark-all-like-this-edits-every-occurrence ()
  (mcx--with-marked-region "foo bar foo baz foo"
    (mc/mark-all-like-this)
    (execute-kbd-macro "X")
    (should (= (mc/num-cursors) 3))
    (should (equal (buffer-string) "X bar X baz X"))))

(ert-deftest editing-extras/mc-edit-lines-puts-a-cursor-on-each-line-of-the-region ()
  ;; `mc/edit-lines' places every cursor at the COLUMN point was on when called (see
  ;; its own source, `mc-edit-lines.el') --- starting at column 0 (beginning of the
  ;; last line) keeps that column trivially the same on every shorter line above it.
  ;; POINT, not mark, must be the one left on that last line: the real (not fake)
  ;; cursor ends up wherever point started, so getting this backwards silently drops
  ;; the last line from the edit instead of erroring --- confirmed directly, the hard
  ;; way, after a first version of this test had them swapped.
  (test-in-buffer #'text-mode "one\ntwo\nthree"
    (goto-char (point-min))
    (push-mark (point) t t) (goto-char (point-max)) (beginning-of-line) (activate-mark)
    (mc/edit-lines)
    (execute-kbd-macro "X")
    (should (= (mc/num-cursors) 3))
    (should (equal (buffer-string) "Xone\nXtwo\nXthree"))))

(ert-deftest editing-extras/mc-skip-to-next-like-this-leaves-the-skipped-one-untouched ()
  (mcx--with-marked-region "foo bar foo baz foo"
    (mc/mark-next-like-this 1)   ; marks occurrence 1 and 2
    (mc/skip-to-next-like-this)  ; drops 2, picks up 3 instead
    (execute-kbd-macro "X")
    (should (equal (buffer-string) "X bar foo baz X"))))

(ert-deftest editing-extras/mc-skip-to-previous-like-this-leaves-the-skipped-one-untouched ()
  (test-in-buffer #'text-mode "foo bar foo baz foo"
    (goto-char (point-max))
    (push-mark (point) t t) (backward-word 1) (activate-mark)
    (mc/mark-previous-like-this 1) ; marks occurrence 3 and 2
    (mc/skip-to-previous-like-this) ; drops 2, picks up 1 instead
    (execute-kbd-macro "X")
    (should (equal (buffer-string) "X bar foo baz X"))))

(ert-deftest editing-extras/move-text-up-swaps-with-the-line-above ()
  (test-in-buffer #'text-mode "one\ntwo\nthree\n"
    (forward-line 1) ; "two"
    (move-text-up nil nil 1)
    (should (equal (buffer-string) "two\none\nthree\n"))))

(ert-deftest editing-extras/move-text-down-swaps-with-the-line-below ()
  (test-in-buffer #'text-mode "one\ntwo\nthree\n"
    (forward-line 1) ; "two"
    (move-text-down nil nil 1)
    (should (equal (buffer-string) "one\nthree\ntwo\n"))))

(ert-deftest editing-extras/find-file-at-point-opens-a-real-file ()
  ;; `ffap' (what `find-file-at-point' is bound to) always confirms its own guess
  ;; through the minibuffer, even when `ffap-guesser' already found the right file ---
  ;; stubbing `read-file-name' to accept that guess, the same interactive-prompt-
  ;; stubbing pattern this project's own encryption/pass tests already use, rather than
  ;; a real one with no terminal to answer it.
  (test-with-temp-dir dir
    (let ((target (test-write-file (expand-file-name "target.txt" dir) "hi")))
      (test-in-buffer #'text-mode target
        (cl-letf (((symbol-function 'read-file-name) (lambda (&rest _) target)))
          (let ((buf (find-file-at-point)))
            (unwind-protect
                (should (equal (buffer-file-name buf) (file-truename target)))
              (kill-buffer buf))))))))

;;; editing-extras.el ends here
