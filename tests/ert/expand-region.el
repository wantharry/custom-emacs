;;; expand-region.el --- grow/shrink the selection by semantic units  -*- lexical-binding: t; -*-
;; harness: config
;; Needs expand-region installed (./build.sh packages); skips without it.

(defmacro er-need (&rest body)
  (declare (indent 0))
  `(if (locate-library "expand-region") (progn ,@body)
     (ert-skip "expand-region is not installed (./build.sh packages)")))

(ert-deftest expand-region/keys-are-bound ()
  (er-need
    (should (eq (key-binding (kbd "C-=")) 'er/expand-region))
    (should (eq (key-binding (kbd "C-M--")) 'er/contract-region))))

(ert-deftest expand-region/grows-from-word-to-the-whole-sexp ()
  ;; Real step sequence, checked directly rather than assumed: word, then the content
  ;; inside the enclosing pair, THEN the pair itself with its parens --- three steps,
  ;; not two.
  (er-need
    (test-in-buffer #'emacs-lisp-mode "(foo (bar baz) qux)"
      (goto-char (point-min))
      (search-forward "bar")
      (er/expand-region 1)
      (should (equal (buffer-substring (region-beginning) (region-end)) "bar"))
      (er/expand-region 1)
      (should (equal (buffer-substring (region-beginning) (region-end)) "bar baz"))
      (er/expand-region 1)
      (should (equal (buffer-substring (region-beginning) (region-end)) "(bar baz)")))))

(ert-deftest expand-region/contracts-back-one-step ()
  (er-need
    (test-in-buffer #'emacs-lisp-mode "(foo (bar baz) qux)"
      (goto-char (point-min))
      (search-forward "bar")
      (er/expand-region 1)
      (er/expand-region 1)
      (er/expand-region 1)
      (should (equal (buffer-substring (region-beginning) (region-end)) "(bar baz)"))
      (er/contract-region 1)
      (should (equal (buffer-substring (region-beginning) (region-end)) "bar baz")))))

(ert-deftest expand-region/contracts-all-the-way-back-to-the-original-word ()
  (er-need
    (test-in-buffer #'emacs-lisp-mode "(foo (bar baz) qux)"
      (goto-char (point-min))
      (search-forward "bar")
      (er/expand-region 1) (er/expand-region 1) (er/expand-region 1)
      (er/contract-region 1) (er/contract-region 1)
      (should (equal (buffer-substring (region-beginning) (region-end)) "bar")))))

(ert-deftest expand-region/grows-through-a-string-literal-then-its-enclosing-sexp ()
  ;; Confirmed directly, not assumed: the content first, THEN the literal with its own
  ;; quotes as a separate step, before reaching the enclosing parens.
  (er-need
    (test-in-buffer #'emacs-lisp-mode "(foo \"hello world\" bar)"
      (goto-char (point-min))
      (search-forward "hello")
      (er/expand-region 1)
      (should (equal (buffer-substring (region-beginning) (region-end)) "hello"))
      (er/expand-region 1)
      (should (equal (buffer-substring (region-beginning) (region-end)) "hello world"))
      (er/expand-region 1)
      (should (equal (buffer-substring (region-beginning) (region-end)) "\"hello world\"")))))

(ert-deftest expand-region/numeric-prefix-does-several-steps-in-one-call ()
  (er-need
    (test-in-buffer #'emacs-lisp-mode "(foo (bar baz) qux)"
      (goto-char (point-min))
      (search-forward "bar")
      (er/expand-region 3)
      (should (equal (buffer-substring (region-beginning) (region-end)) "(bar baz)")))))

(ert-deftest expand-region/grows-outward-through-two-levels-of-nested-lists ()
  (er-need
    (test-in-buffer #'emacs-lisp-mode "(outer (middle (inner val) more) end)"
      (goto-char (point-min))
      (search-forward "val")
      (er/expand-region 3) ; val -> inner val -> (inner val)
      (should (equal (buffer-substring (region-beginning) (region-end)) "(inner val)"))
      (er/expand-region 2) ; middle (inner val) more -> (middle (inner val) more)
      (should (equal (buffer-substring (region-beginning) (region-end))
                      "(middle (inner val) more)")))))

(ert-deftest expand-region/text-mode-grows-word-then-sentence-then-whole-buffer ()
  ;; Real step sequence in `text-mode', confirmed directly: word, then the word with its
  ;; trailing period, then the whole first sentence, eventually reaching the whole buffer
  ;; --- a genuinely different unit progression than Lisp's sexp-based one above.
  (er-need
    (test-in-buffer #'text-mode "Hello world. Second sentence here.\n\nSecond paragraph."
      (goto-char (point-min))
      (search-forward "world")
      (er/expand-region 1)
      (should (equal (buffer-substring (region-beginning) (region-end)) "world"))
      (er/expand-region 1)
      (should (equal (buffer-substring (region-beginning) (region-end)) "world."))
      (er/expand-region 1)
      (should (equal (buffer-substring (region-beginning) (region-end)) "Hello world."))
      (er/expand-region 2)
      (should (equal (buffer-substring (region-beginning) (region-end)) (buffer-string))))))

(ert-deftest expand-region/contracting-past-the-smallest-step-does-not-error ()
  ;; A real, confirmed edge case: once already at the smallest (word) step, one more
  ;; `er/contract-region' does not signal --- it simply leaves nothing selected, rather
  ;; than erroring out of whatever command sequence called it.
  (er-need
    (test-in-buffer #'emacs-lisp-mode "(bar baz)"
      (goto-char (point-min))
      (search-forward "bar")
      (er/expand-region 1)
      (should-not (condition-case nil (progn (er/contract-region 1) nil) (error t))))))

(ert-deftest expand-region/a-fresh-expansion-after-moving-point-starts-over-at-the-new-word ()
  ;; `er/expand-region' tracks its own step history for repeated presses; moving point
  ;; and expanding again must start a brand new word-sized selection at the new spot,
  ;; not keep growing from wherever the previous sequence left off.
  (er-need
    (test-in-buffer #'emacs-lisp-mode "(foo (bar baz) qux)"
      (goto-char (point-min))
      (search-forward "bar")
      (er/expand-region 1) (er/expand-region 1) (er/expand-region 1)
      (deactivate-mark)
      (goto-char (point-min))
      (search-forward "qux")
      (er/expand-region 1)
      (should (equal (buffer-substring (region-beginning) (region-end)) "qux")))))

(ert-deftest expand-region/a-hyphenated-symbol-expands-word-first-then-the-whole-symbol ()
  ;; Confirmed directly, not assumed: with point mid-symbol in "my-bar-baz", the FIRST
  ;; step is only the hyphen-delimited word under point ("bar"), not the whole symbol ---
  ;; the whole symbol is a separate, second step.
  (er-need
    (test-in-buffer #'emacs-lisp-mode "(foo (my-bar-baz qux) end)"
      (goto-char (point-min))
      (search-forward "bar")
      (er/expand-region 1)
      (should (equal (buffer-substring (region-beginning) (region-end)) "bar"))
      (er/expand-region 1)
      (should (equal (buffer-substring (region-beginning) (region-end)) "my-bar-baz")))))

(ert-deftest expand-region/missing-fallback-message-when-the-package-is-not-installed ()
  ;; `my/expand-region-missing' is always defined (config/init.el), regardless of whether
  ;; `expand-region' itself is installed --- this is what `C-=`/`C-M--` fall back to on a
  ;; machine that skipped `./build.sh packages'.
  (let (msg)
    (cl-letf (((symbol-function 'message) (lambda (fmt &rest args) (setq msg (apply #'format fmt args)))))
      (my/expand-region-missing))
    (should (string-match-p "not installed" msg))))

(ert-deftest expand-region/eventually-reaches-the-whole-top-level-defun ()
  (er-need
    (test-in-buffer #'emacs-lisp-mode "(defun foo (x) (bar x))"
      (goto-char (point-min))
      (search-forward "bar")
      (er/expand-region 5)
      (should (equal (buffer-substring (region-beginning) (region-end))
                      "(defun foo (x) (bar x))")))))

(ert-deftest expand-region/grows-through-a-vector-the-same-way-as-a-list ()
  (er-need
    (test-in-buffer #'emacs-lisp-mode "[1 2 3]"
      (goto-char (point-min))
      (search-forward "2")
      (er/expand-region 1)
      (should (equal (buffer-substring (region-beginning) (region-end)) "2"))
      (er/expand-region 1)
      (should (equal (buffer-substring (region-beginning) (region-end)) "1 2 3")))))

(ert-deftest expand-region/numeric-prefix-contract-undoes-several-steps-at-once ()
  (er-need
    (test-in-buffer #'emacs-lisp-mode "(bar baz qux)"
      (goto-char (point-min))
      (search-forward "bar")
      (er/expand-region 3)
      (should (equal (buffer-substring (region-beginning) (region-end)) "(bar baz qux)"))
      (er/contract-region 2)
      (should (equal (buffer-substring (region-beginning) (region-end)) "bar")))))

(ert-deftest expand-region/a-real-key-press-expands-just-like-calling-the-command ()
  (er-need
    (test-in-buffer #'emacs-lisp-mode "(foo (bar baz) qux)"
      (goto-char (point-min))
      (search-forward "bar")
      (execute-kbd-macro (kbd "C-="))
      (should (equal (buffer-substring (region-beginning) (region-end)) "bar")))))

(ert-deftest expand-region/a-real-key-press-contracts-just-like-calling-the-command ()
  (er-need
    (test-in-buffer #'emacs-lisp-mode "(foo (bar baz) qux)"
      (goto-char (point-min))
      (search-forward "bar")
      (er/expand-region 1) (er/expand-region 1)
      (execute-kbd-macro (kbd "C-M--"))
      (should (equal (buffer-substring (region-beginning) (region-end)) "bar")))))

(ert-deftest expand-region/expanding-again-after-contracting-reaches-the-same-step ()
  (er-need
    (test-in-buffer #'emacs-lisp-mode "(foo (bar baz) qux)"
      (goto-char (point-min))
      (search-forward "bar")
      (er/expand-region 1) (er/expand-region 1) (er/expand-region 1)
      (er/contract-region 1)
      (er/expand-region 1)
      (should (equal (buffer-substring (region-beginning) (region-end)) "(bar baz)")))))

;;; expand-region.el ends here
