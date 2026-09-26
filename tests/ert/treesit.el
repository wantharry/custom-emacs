;;; treesit.el --- tree-sitter integration  -*- lexical-binding: t; -*-
;; harness: bare
;; No grammars are installed yet.  Tests that need one skip themselves and
;; start running as soon as a grammar is installed.

(ert-deftest treesit/engine-is-built-in ()
  (should (treesit-available-p))
  (should (fboundp 'treesit-install-language-grammar))
  (should (fboundp 'treesit-parser-create)))

(ert-deftest treesit/library-abi-version-is-reported ()
  (should (integerp (treesit-library-abi-version))))

(ert-deftest treesit/missing-grammar-fails-cleanly ()
  (skip-unless (not (treesit-language-available-p 'python)))
  (with-temp-buffer
    (should-error (treesit-parser-create 'python) :type 'treesit-load-language-error)))

(ert-deftest treesit/python-grammar-parses-when-installed ()
  (skip-unless (treesit-language-available-p 'python))
  (with-temp-buffer
    (insert "def f(): pass\n")
    (let ((root (treesit-parser-root-node (treesit-parser-create 'python))))
      (should (equal (treesit-node-type root) "module")))))

;;; treesit.el ends here
