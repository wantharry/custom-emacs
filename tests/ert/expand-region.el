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

;;; expand-region.el ends here
