;;; treesit.el --- tree-sitter integration  -*- lexical-binding: t; -*-
;; harness: bare
;; No grammars are installed yet.  Tests that need one skip themselves and
;; start running as soon as a grammar is installed.
;;
;; The tests below DO find real grammars, though: this repo already bundles several
;; (`./build.sh grammars', see `config/tree-sitter/') even though the `bare' harness
;; (plain `emacs -Q', no config loaded) never puts them on `treesit-extra-load-path'
;; the way `config/init.el' does --- `ts-need' sets that path directly, to the real
;; grammar files on disk, which is enough on its own regardless of harness; these tests
;; exercise `treesit.el''s own API (parsing, navigation, queries, incremental reparse),
;; deliberately NOT the major-mode/`my/*' wiring around Java/Rust/web editing support,
;; which tests/ert/language-modes.el, languages-java-rust.el and languages-web.el
;; already cover.

(defmacro ts-need (lang &rest body)
  "Run BODY with `treesit-extra-load-path' pointed at this repo's real bundled
grammars, skipping if LANG (a symbol) is still not available even so."
  (declare (indent 1))
  `(let ((treesit-extra-load-path (list (expand-file-name "config/tree-sitter" test-root))))
     (if (treesit-language-available-p ,lang)
         (progn ,@body)
       (ert-skip (format "%s grammar is not installed (./build.sh grammars)" ,lang)))))

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

(ert-deftest treesit/extra-load-path-makes-a-bundled-grammar-available ()
  (ts-need 'json
    (should (treesit-language-available-p 'json))))

(ert-deftest treesit/node-type-and-source-text-round-trip ()
  (ts-need 'json
    (with-temp-buffer
      (insert "{\"a\": 1, \"b\": [1,2,3]}")
      (let ((root (treesit-parser-root-node (treesit-parser-create 'json))))
        (should (equal (treesit-node-type root) "document"))
        (should (equal (buffer-substring-no-properties (treesit-node-start root) (treesit-node-end root))
                       (buffer-string)))))))

(ert-deftest treesit/node-navigation-parent-child-sibling ()
  (ts-need 'json
    (with-temp-buffer
      (insert "{\"a\": 1, \"b\": 2}")
      (let* ((root (treesit-parser-root-node (treesit-parser-create 'json)))
             (obj (treesit-node-child root 0))
             (pair1 (treesit-node-child obj 0 t))
             (pair2 (treesit-node-next-sibling pair1 t)))
        (should (equal (treesit-node-type obj) "object"))
        (should (equal (treesit-node-type pair1) "pair"))
        (should (equal (treesit-node-type pair2) "pair"))
        (should (treesit-node-eq (treesit-node-parent pair1) obj))
        (should (treesit-node-eq (treesit-node-prev-sibling pair2 t) pair1))))))

(ert-deftest treesit/named-child-and-field-name-access ()
  (ts-need 'json
    (with-temp-buffer
      (insert "{\"a\": 1}")
      (let* ((root (treesit-parser-root-node (treesit-parser-create 'json)))
             (pair (treesit-node-child (treesit-node-child root 0) 0 t)))
        (should (equal (treesit-node-type (treesit-node-child-by-field-name pair "key")) "string"))
        (should (equal (treesit-node-type (treesit-node-child-by-field-name pair "value")) "number"))))))

(ert-deftest treesit/query-capture-finds-real-matches ()
  (ts-need 'json
    (with-temp-buffer
      (insert "{\"a\": 1, \"b\": 2}")
      (let* ((root (treesit-parser-root-node (treesit-parser-create 'json)))
             (caps (treesit-query-capture root '((pair key: (_) @k)))))
        (should (= 2 (length caps)))
        (should (equal (mapcar (lambda (c) (buffer-substring-no-properties
                                            (treesit-node-start (cdr c)) (treesit-node-end (cdr c))))
                               caps)
                       '("\"a\"" "\"b\"")))))))

(ert-deftest treesit/search-subtree-finds-a-node-by-predicate ()
  (ts-need 'json
    (with-temp-buffer
      (insert "{\"a\": [1, 2, 3]}")
      (let* ((root (treesit-parser-root-node (treesit-parser-create 'json)))
             (n (treesit-search-subtree root (lambda (n) (equal (treesit-node-type n) "array")))))
        (should n)
        (should (equal (buffer-substring-no-properties (treesit-node-start n) (treesit-node-end n)) "[1, 2, 3]"))))))

(ert-deftest treesit/incremental-reparse-reflects-a-real-edit ()
  (ts-need 'json
    (with-temp-buffer
      (insert "{\"a\": 1}")
      (let ((p (treesit-parser-create 'json)))
        (should (= 1 (treesit-node-child-count (treesit-node-child (treesit-parser-root-node p) 0) t)))
        (goto-char (1- (point-max)))
        (insert ", \"b\": 2")
        (should (= 2 (treesit-node-child-count (treesit-node-child (treesit-parser-root-node p) 0) t)))))))

(ert-deftest treesit/node-descendant-for-range-finds-the-right-node ()
  (ts-need 'json
    (with-temp-buffer
      (insert "{\"a\": 1}")
      (let* ((root (treesit-parser-root-node (treesit-parser-create 'json)))
             (pos (1+ (string-match "1" (buffer-string))))
             (n (treesit-node-descendant-for-range root pos pos)))
        (should (equal (treesit-node-type n) "number"))))))

(ert-deftest treesit/malformed-syntax-is-flagged-has-error ()
  (ts-need 'json
    (with-temp-buffer
      (insert "{\"a\": }")
      (let ((root (treesit-parser-root-node (treesit-parser-create 'json))))
        (should (treesit-node-check root 'has-error))))
    (with-temp-buffer
      (insert "{\"a\": 1}")
      (let ((root (treesit-parser-root-node (treesit-parser-create 'json))))
        (should-not (treesit-node-check root 'has-error))))))

(ert-deftest treesit/parser-list-tracks-parsers-created-in-the-buffer ()
  (ts-need 'json
    (with-temp-buffer
      (should (null (treesit-parser-list)))
      (treesit-parser-create 'json)
      (should (= 1 (length (treesit-parser-list))))
      (should (eq (treesit-parser-language (car (treesit-parser-list))) 'json)))))

(ert-deftest treesit/java-grammar-parses-a-real-class ()
  (ts-need 'java
    (with-temp-buffer
      (insert "public class Foo { void bar() {} }")
      (let ((root (treesit-parser-root-node (treesit-parser-create 'java))))
        (should (equal (treesit-node-type root) "program"))
        (should (treesit-search-subtree root (lambda (n) (equal (treesit-node-type n) "class_declaration"))))))))

(ert-deftest treesit/rust-grammar-parses-a-real-function ()
  (ts-need 'rust
    (with-temp-buffer
      (insert "fn add(a: i32, b: i32) -> i32 { a + b }")
      (let ((root (treesit-parser-root-node (treesit-parser-create 'rust))))
        (should (equal (treesit-node-type root) "source_file"))
        (should (treesit-search-subtree root (lambda (n) (equal (treesit-node-type n) "function_item"))))))))

(ert-deftest treesit/node-start-end-are-valid-buffer-positions ()
  (ts-need 'json
    (with-temp-buffer
      (insert "{\"a\": 1}")
      (let ((root (treesit-parser-root-node (treesit-parser-create 'json))))
        (should (= (treesit-node-start root) (point-min)))
        (should (= (treesit-node-end root) (point-max)))))))

(ert-deftest treesit/node-p-distinguishes-real-nodes-from-other-values ()
  (ts-need 'json
    (with-temp-buffer
      (insert "{}")
      (should (treesit-node-p (treesit-parser-root-node (treesit-parser-create 'json))))
      (should-not (treesit-node-p "not a node"))
      (should-not (treesit-node-p nil)))))

(ert-deftest treesit/an-unknown-language-is-cleanly-unavailable ()
  (should-not (treesit-language-available-p 'this-language-does-not-exist-anywhere)))

;;; treesit.el ends here
