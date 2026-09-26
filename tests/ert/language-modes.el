;;; language-modes.el --- programming-language and file-type modes  -*- lexical-binding: t; -*-
;; harness: config
;; Tree-sitter grammars are not installed yet, so classic modes are expected;
;; each check also accepts the -ts- variant so installing grammars later is fine.

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

;;; language-modes.el ends here
