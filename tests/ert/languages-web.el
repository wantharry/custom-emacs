;;; languages-web.el --- HTML/CSS/JS/TS/JSX/JSON support (tree-sitter only, phase 1)  -*- lexical-binding: t; -*-
;; harness: config
;; Grammar-dependent tests skip themselves if the grammar is not installed
;; (./build.sh grammars).  No language server is set up for these yet (unlike Java/Rust
;; in languages-java-rust.el): this is editing support only --- highlighting, indent,
;; imenu --- via tree-sitter, deliberately, since these servers need a Node.js runtime
;; this project does not (yet) bundle.  See docs/LANGUAGES.md.

(require 'treesit) (require 'imenu) (require 'eglot)

(defmacro lw-with-grammar (lang &rest body)
  (declare (indent 1))
  `(progn (skip-unless (treesit-language-available-p ,lang)) ,@body))

(defun lw--flatten-imenu (alist)
  (cl-loop for e in alist
           if (imenu--subalist-p e) append (lw--flatten-imenu (cdr e))
           else collect (car e)))

(defun lw--open-mode (name text)
  (test-with-temp-dir d
    (let ((buf (find-file-noselect (test-write-file (concat d name) text))))
      (unwind-protect (buffer-local-value 'major-mode buf) (kill-buffer buf)))))

(defconst lw--js "function add(a, b) {\n  return a + b;\n}\n")
(defconst lw--ts "interface Point {\n  x: number;\n}\n\nfunction dist(p) {\n  return p.x;\n}\n")
(defconst lw--tsx "function App() {\n  return <div>hi</div>;\n}\n")
(defconst lw--css ".box {\n  color: red;\n}\n")
(defconst lw--html "<html>\n<body>\n<p>hi</p>\n</body>\n</html>\n")
(defconst lw--json "{\"a\": 1, \"b\": [1, 2, 3]}")

;;; Grammars and modes

(ert-deftest langsweb/grammars-installed-and-loadable ()
  ;; A hard requirement, not a skip: other tests skip without a grammar, so this
  ;; is what stops a missing grammar from hiding behind green results.
  (dolist (l '(html css javascript jsdoc typescript tsx json))
    (unless (treesit-language-available-p l)
      (ert-fail (format "tree-sitter grammar for %s is not installed; run ./build.sh grammars" l)))
    (should (<= (treesit-language-abi-version l) (treesit-library-abi-version)))))

(ert-deftest langsweb/grammar-sources-are-pinned ()
  (dolist (l '(html css javascript jsdoc typescript tsx json))
    (let ((src (assq l treesit-language-source-alist)))
      (should src)
      (should (string-match-p "\\`v[0-9]+\\.[0-9]+\\.[0-9]+\\'" (nth 2 src))))))

(ert-deftest langsweb/js-and-jsx-open-in-the-tree-sitter-mode ()
  (lw-with-grammar 'javascript
    (should (eq 'js-ts-mode (lw--open-mode "a.js" lw--js)))
    (should (eq 'js-ts-mode (lw--open-mode "a.jsx" lw--js)))))

(ert-deftest langsweb/css-opens-in-the-tree-sitter-mode ()
  (lw-with-grammar 'css
    (should (eq 'css-ts-mode (lw--open-mode "a.css" lw--css)))))

(ert-deftest langsweb/html-opens-in-the-tree-sitter-mode ()
  (lw-with-grammar 'html
    (should (eq 'mhtml-ts-mode (lw--open-mode "a.html" lw--html)))))

(ert-deftest langsweb/json-opens-in-the-tree-sitter-mode ()
  (lw-with-grammar 'json
    (should (eq 'json-ts-mode (lw--open-mode "a.json" lw--json)))))

(ert-deftest langsweb/ts-and-tsx-open-automatically-with-no-remap-needed ()
  ;; Core Emacs has no legacy TypeScript mode, so .ts/.tsx map straight to the
  ;; tree-sitter modes via their own auto-mode-alist entries; unlike js/css/html,
  ;; init.el adds no remap for these.
  (lw-with-grammar 'typescript
    (should (eq 'typescript-ts-mode (lw--open-mode "a.ts" lw--ts))))
  (lw-with-grammar 'tsx
    (should (eq 'tsx-ts-mode (lw--open-mode "a.tsx" lw--tsx)))))

(ert-deftest langsweb/legacy-modes-remain-when-their-grammar-is-absent ()
  ;; init.el only remaps javascript-mode/css-mode/mhtml-mode/js-json-mode when their
  ;; grammar exists --- the same pattern languages-java-rust.el checks for Java.
  (dolist (pair '((javascript-mode . javascript) (css-mode . css)
                  (mhtml-mode . html) (js-json-mode . json)))
    (should (eq (and (assq (car pair) major-mode-remap-alist) t)
                (and (treesit-language-available-p (cdr pair)) t)))))

;;; Parsing and highlighting

(ert-deftest langsweb/js-parses-to-a-program-tree ()
  (lw-with-grammar 'javascript
    (test-in-buffer #'js-ts-mode lw--js
      (should (equal "program" (treesit-node-type (treesit-buffer-root-node 'javascript))))
      (should (treesit-search-subtree (treesit-buffer-root-node 'javascript) "function_declaration")))))

(ert-deftest langsweb/ts-parses-to-a-program-tree ()
  (lw-with-grammar 'typescript
    (test-in-buffer #'typescript-ts-mode lw--ts
      (should (treesit-search-subtree (treesit-buffer-root-node 'typescript) "interface_declaration")))))

(ert-deftest langsweb/css-parses-to-a-stylesheet-tree ()
  (lw-with-grammar 'css
    (test-in-buffer #'css-ts-mode lw--css
      (should (equal "stylesheet" (treesit-node-type (treesit-buffer-root-node 'css))))
      (should (treesit-search-subtree (treesit-buffer-root-node 'css) "rule_set")))))

(ert-deftest langsweb/html-parses-and-embeds-no-error-node ()
  (lw-with-grammar 'html
    (test-in-buffer #'mhtml-ts-mode lw--html
      (should (equal "document" (treesit-node-type (treesit-buffer-root-node 'html))))
      (should-not (treesit-search-subtree (treesit-buffer-root-node 'html) "ERROR")))))

(ert-deftest langsweb/json-parses-with-no-error-node ()
  (lw-with-grammar 'json
    (test-in-buffer #'json-ts-mode lw--json
      (should-not (treesit-search-subtree (treesit-buffer-root-node 'json) "ERROR")))))

(ert-deftest langsweb/js-highlighting ()
  (lw-with-grammar 'javascript
    (test-in-buffer #'js-ts-mode lw--js
      (font-lock-ensure)
      (should (memq 'font-lock-keyword-face (ensure-list (get-text-property 1 'face))))
      (search-forward "add")
      (should (memq 'font-lock-function-name-face (ensure-list (get-text-property (- (point) 2) 'face)))))))

(ert-deftest langsweb/ts-highlighting ()
  (lw-with-grammar 'typescript
    (test-in-buffer #'typescript-ts-mode lw--ts
      (font-lock-ensure)
      (search-forward "interface")
      (should (memq 'font-lock-keyword-face (ensure-list (get-text-property (- (point) 5) 'face)))))))

(ert-deftest langsweb/css-highlighting ()
  (lw-with-grammar 'css
    (test-in-buffer #'css-ts-mode lw--css
      (font-lock-ensure)
      (search-forward ".box")
      (should (memq 'css-selector (ensure-list (get-text-property (- (point) 3) 'face)))))))

(ert-deftest langsweb/html-highlighting ()
  (lw-with-grammar 'html
    (test-in-buffer #'mhtml-ts-mode lw--html
      (font-lock-ensure)
      (search-forward "<p")
      (should (memq 'font-lock-function-name-face (ensure-list (get-text-property (1- (point)) 'face)))))))

;;; Editing: indentation, comments, imenu

(ert-deftest langsweb/js-indentation ()
  (lw-with-grammar 'javascript
    (test-in-buffer #'js-ts-mode "function f() {\nreturn 1;\n}\n"
      (indent-region (point-min) (point-max))
      (should (string-match-p "\n *return 1;" (buffer-string))))))

(ert-deftest langsweb/ts-indentation ()
  (lw-with-grammar 'typescript
    (test-in-buffer #'typescript-ts-mode "function f(): number {\nreturn 1;\n}\n"
      (indent-region (point-min) (point-max))
      (should (string-match-p "\n *return 1;" (buffer-string))))))

(ert-deftest langsweb/css-indentation ()
  (lw-with-grammar 'css
    (test-in-buffer #'css-ts-mode ".box {\ncolor: red;\n}\n"
      (indent-region (point-min) (point-max))
      (should (string-match-p "\n *color: red;" (buffer-string))))))

(ert-deftest langsweb/js-comments ()
  (lw-with-grammar 'javascript
    (test-in-buffer #'js-ts-mode "let x = 1;\n"
      (comment-region (point-min) (point-max))
      (should (string-prefix-p "//" (buffer-string))))))

(ert-deftest langsweb/html-comments ()
  (lw-with-grammar 'html
    (test-in-buffer #'mhtml-ts-mode "<p>hi</p>\n"
      (comment-region (point-min) (point-max))
      (should (string-prefix-p "<!--" (buffer-string))))))

(ert-deftest langsweb/js-imenu-lists-functions ()
  (lw-with-grammar 'javascript
    (test-in-buffer #'js-ts-mode lw--js
      (let ((names (lw--flatten-imenu (imenu--make-index-alist t))))
        (should (cl-some (lambda (n) (string-match-p "add" n)) names))))))

(ert-deftest langsweb/ts-imenu-lists-interfaces-and-functions ()
  (lw-with-grammar 'typescript
    (test-in-buffer #'typescript-ts-mode lw--ts
      (let ((names (lw--flatten-imenu (imenu--make-index-alist t))))
        (should (cl-some (lambda (n) (string-match-p "Point" n)) names))
        (should (cl-some (lambda (n) (string-match-p "dist" n)) names))))))

(ert-deftest langsweb/js-knows-the-function-around-point ()
  (lw-with-grammar 'javascript
    (test-in-buffer #'js-ts-mode lw--js
      (search-forward "a + b")
      (should (equal "add" (treesit-defun-name (treesit-defun-at-point)))))))

;;; No language server is bundled or set up for these yet (phase 1: tree-sitter only).
;;; Eglot itself already knows the *name* of a server for js/ts/css (it ships its own
;;; entries in `eglot-server-programs', same as for Java/Rust), but none of those
;;; servers is installed here, and --- same as Java/Rust --- nothing auto-starts one
;;; just from opening a file.  mhtml-mode has no built-in entry at all yet (a real gap
;;; in Eglot's own table, not this project's), so `M-x eglot' on an .html file fails to
;;; guess a server until this project adds one, same as the jdtls override for Java.

(ert-deftest langsweb/opening-files-does-not-start-servers ()
  (lw-with-grammar 'javascript
    (test-in-buffer #'js-ts-mode lw--js
      (should-not (and (fboundp 'eglot-current-server) (eglot-current-server)))
      (should-not (cl-some (lambda (p) (string-match-p "EGLOT" (process-name p))) (process-list))))))

;;; languages-web.el ends here
