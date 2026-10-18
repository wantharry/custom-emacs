;;; language-modes.el --- programming-language and file-type modes  -*- lexical-binding: t; -*-
;; harness: config
;; Most of these languages have no pinned tree-sitter grammar (python/c/sh), so their
;; classic mode is expected; each check also accepts the -ts- variant so installing a
;; grammar for one later is fine.  js/css/json/html DO have a pinned, installed grammar
;; (see languages-web.el for real parse/highlight/indent coverage of those) and so are
;; expected to already be in their tree-sitter mode here; the `memq' is kept anyway, so
;; this file still passes in an environment where `./build.sh grammars' was never run.

(defun lm--open-mode (name content)
  "Visit a temporary file NAME containing CONTENT and return its major mode."
  (test-with-temp-dir d
    (let* ((f (test-write-file (concat d name) content)) (buf (find-file-noselect f)))
      (unwind-protect (buffer-local-value 'major-mode buf)
        (kill-buffer buf)))))

(ert-deftest langmodes/mode-chosen-by-extension ()
  (should (eq 'emacs-lisp-mode (lm--open-mode "a.el" "")))
  (should (memq (lm--open-mode "a.py" "") '(python-mode python-ts-mode)))
  (should (memq (lm--open-mode "a.c" "") '(c-mode c-ts-mode)))
  (should (memq (lm--open-mode "a.js" "") '(js-mode js-ts-mode)))
  (should (memq (lm--open-mode "a.json" "{}") '(js-json-mode json-ts-mode)))
  (should (memq (lm--open-mode "a.css" "") '(css-mode css-ts-mode)))
  (should (eq 'text-mode (lm--open-mode "a.txt" ""))))

(ert-deftest langmodes/mode-chosen-by-name-and-shebang ()
  (should (provided-mode-derived-p (lm--open-mode "Makefile" "all:\n") 'makefile-mode))
  (should (memq (lm--open-mode "run.sh" "") '(sh-mode bash-ts-mode)))
  (should (memq (lm--open-mode "script" "#!/bin/bash\necho hi\n") '(sh-mode bash-ts-mode)))
  (should (memq (lm--open-mode "p" "#!/usr/bin/env python3\n") '(python-mode python-ts-mode))))

(ert-deftest langmodes/unknown-extension-is-fundamental ()
  (should (eq 'fundamental-mode (lm--open-mode "a.unknownext" "x"))))

(ert-deftest langmodes/html-mode ()
  (should (provided-mode-derived-p (lm--open-mode "a.html" "<p>x</p>") 'html-mode)))

(ert-deftest langmodes/python-indents-after-colon ()
  (test-in-buffer #'python-mode "def f():\n"
    (goto-char (point-max))
    (newline-and-indent)
    (should (= 4 (current-indentation)))))

(ert-deftest langmodes/python-highlights-keywords-and-names ()
  (test-in-buffer #'python-mode "def f():\n    return 1\n"
    (font-lock-ensure)
    (should (memq 'font-lock-keyword-face (ensure-list (get-text-property 1 'face))))
    (should (memq 'font-lock-function-name-face (ensure-list (get-text-property 5 'face))))))

(ert-deftest langmodes/python-imenu-lists-definitions ()
  (test-in-buffer #'python-mode "def alpha():\n    pass\n\nclass Beta:\n    def gamma(self):\n        pass\n"
    (let ((idx (imenu--make-index-alist t)))
      (should (cl-some (lambda (e) (string-prefix-p "alpha" (car e))) idx))
      (should (cl-some (lambda (e) (string-match-p "Beta" (car e))) idx)))))

(ert-deftest langmodes/python-comments ()
  (test-in-buffer #'python-mode "x = 1\n"
    (comment-region (point-min) (point-max))
    (should (string-prefix-p "# " (buffer-string)))))

(ert-deftest langmodes/elisp-indentation ()
  (test-in-buffer #'emacs-lisp-mode "(if a\nb\nc)\n"
    (indent-region (point-min) (point-max))
    (should (equal (buffer-string) "(if a\n    b\n  c)\n"))))

(ert-deftest langmodes/c-indentation ()
  (test-in-buffer #'c-mode "int main() {\nreturn 0;\n}\n"
    (indent-region (point-min) (point-max))
    (should (string-match-p "\n +return 0;" (buffer-string)))))

(ert-deftest langmodes/js-indentation ()
  (test-in-buffer #'js-mode "function f() {\nreturn 1;\n}\n"
    (indent-region (point-min) (point-max))
    (should (string-match-p "\n    return 1;" (buffer-string)))))

(ert-deftest langmodes/json-pretty-print ()
  (test-in-buffer #'js-json-mode "{\"a\":[1,2],\"b\":null}"
    (json-pretty-print-buffer)
    (should (string-match-p "\"a\": \\[" (buffer-string)))
    (should (> (count-lines (point-min) (point-max)) 3))))

(ert-deftest langmodes/shell-indentation ()
  (test-in-buffer #'sh-mode "if true; then\necho hi\nfi\n"
    (indent-region (point-min) (point-max))
    (should (string-match-p "\n    echo hi" (buffer-string)))))

;;; Other stock modes --- all built into Emacs itself, no extra package needed
;;; (unlike markdown-mode/yaml-mode, which this distribution does not bundle).

(ert-deftest langmodes/xml-mode-is-really-nxml-mode ()
  ;; `xml-mode' (what `a.xml' resolves to in `auto-mode-alist') is a plain alias for
  ;; `nxml-mode' in modern Emacs, confirmed directly rather than assumed.
  (should (provided-mode-derived-p (lm--open-mode "a.xml" "<a><b>x</b></a>") 'nxml-mode)))

(ert-deftest langmodes/xml-indentation ()
  (test-in-buffer #'nxml-mode "<a>\n<b>x</b>\n</a>\n"
    (indent-region (point-min) (point-max))
    (should (equal (buffer-string) "<a>\n  <b>x</b>\n</a>\n"))))

(ert-deftest langmodes/ini-and-toml-files-get-a-real-conf-mode ()
  (should (provided-mode-derived-p (lm--open-mode "a.ini" "[section]\nkey=value\n") 'conf-mode))
  (should (provided-mode-derived-p (lm--open-mode "a.toml" "[section]\nkey = 1\n") 'conf-mode)))

(ert-deftest langmodes/js-imenu-lists-function-definitions ()
  (test-in-buffer #'js-mode "function alpha() {}\nfunction beta() {}\n"
    (let ((idx (imenu--make-index-alist t)))
      (should (cl-some (lambda (e) (string-prefix-p "alpha" (car e))) idx))
      (should (cl-some (lambda (e) (string-prefix-p "beta" (car e))) idx)))))

(ert-deftest langmodes/c-comments-use-the-real-block-style ()
  (test-in-buffer #'c-mode "int x = 1;"
    (comment-region (point-min) (point-max))
    (should (equal (buffer-string) "/* int x = 1; */"))
    (uncomment-region (point-min) (point-max))
    (should (equal (buffer-string) "int x = 1;"))))

(ert-deftest langmodes/elisp-comments-use-a-real-semicolon ()
  (test-in-buffer #'emacs-lisp-mode "(+ 1 2)"
    (comment-region (point-min) (point-max))
    (should (string-prefix-p ";" (buffer-string)))
    (uncomment-region (point-min) (point-max))
    (should (equal (buffer-string) "(+ 1 2)"))))

(ert-deftest langmodes/shell-comments-use-a-real-hash ()
  (test-in-buffer #'sh-mode "echo hi"
    (comment-region (point-min) (point-max))
    (should (string-prefix-p "#" (buffer-string)))
    (uncomment-region (point-min) (point-max))
    (should (equal (buffer-string) "echo hi"))))

;;; language-modes.el ends here
