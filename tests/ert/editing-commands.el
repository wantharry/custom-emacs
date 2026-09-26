;;; editing-commands.el --- everyday editing commands  -*- lexical-binding: t; -*-
;; harness: config

(ert-deftest editing/kill-and-yank ()
  (test-in-buffer #'text-mode "hello world"
    (kill-region 1 7)
    (should (equal (buffer-string) "world"))
    (goto-char (point-max))
    (yank)
    (should (equal (buffer-string) "worldhello "))))

(ert-deftest editing/case-commands ()
  (test-in-buffer #'text-mode "hello world"
    (upcase-word 1)
    (should (equal (buffer-string) "HELLO world"))
    (capitalize-word 1)
    (should (equal (buffer-string) "HELLO World"))
    (downcase-region 1 6)
    (should (equal (buffer-string) "hello World"))))

(ert-deftest editing/transpose ()
  (test-in-buffer #'text-mode "ab cd"
    (goto-char 2) (transpose-chars 1)
    (should (equal (buffer-string) "ba cd"))
    (goto-char 4) (transpose-words 1)
    (should (equal (buffer-string) "cd ba"))))

(ert-deftest editing/whitespace-commands ()
  (test-in-buffer #'text-mode "a    b  \n"
    (goto-char 3) (just-one-space)
    (should (equal (buffer-string) "a b  \n"))
    (delete-trailing-whitespace)
    (should (equal (buffer-string) "a b\n"))))

(ert-deftest editing/electric-pair-closes-brackets ()
  (test-in-buffer #'text-mode ""
    (let ((last-command-event ?\[)) (self-insert-command 1))
    (should (equal (buffer-string) "[]"))
    (should (= (point) 2))))

(ert-deftest editing/electric-pair-closes-quotes ()
  (test-in-buffer #'text-mode ""
    (let ((last-command-event ?\")) (self-insert-command 1))
    (should (equal (buffer-string) "\"\""))))

(ert-deftest editing/typing-replaces-selection ()
  (should (get 'self-insert-command 'delete-selection))
  (test-in-buffer #'text-mode "hello world"
    (set-mark 1) (goto-char 6) (activate-mark)
    (delete-active-region)
    (should (equal (buffer-string) " world"))))

(ert-deftest editing/comment-region-in-lisp ()
  (test-in-buffer #'emacs-lisp-mode "(foo)\n(bar)\n"
    (comment-region (point-min) (point-max))
    (should (string-prefix-p ";;" (buffer-string)))
    (uncomment-region (point-min) (point-max))
    (should (equal (buffer-string) "(foo)\n(bar)\n"))))

(ert-deftest editing/indent-region-in-lisp ()
  (test-in-buffer #'emacs-lisp-mode "(defun f (x)\n(+ x 1))\n"
    (indent-region (point-min) (point-max))
    (should (equal (buffer-string) "(defun f (x)\n  (+ x 1))\n"))
    (should-not (string-match-p "\t" (buffer-string)))))

(ert-deftest editing/fill-respects-fill-column ()
  (test-in-buffer #'text-mode (mapconcat #'identity (make-list 40 "word") " ")
    (fill-region (point-min) (point-max))
    (dolist (l (split-string (buffer-string) "\n"))
      (should (<= (length l) 80)))
    (should (> (count-lines (point-min) (point-max)) 1))))

(ert-deftest editing/sort-and-dedupe-lines ()
  (test-in-buffer #'text-mode "b\na\nb\nc\n"
    (sort-lines nil (point-min) (point-max))
    (should (equal (buffer-string) "a\nb\nb\nc\n"))
    (delete-duplicate-lines (point-min) (point-max))
    (should (equal (buffer-string) "a\nb\nc\n"))))

(ert-deftest editing/rectangles ()
  (test-in-buffer #'text-mode "abcd\nefgh\nijkl\n"
    (should (equal (extract-rectangle 2 14) '("bc" "fg" "jk")))
    (delete-rectangle 2 14)
    (should (equal (buffer-string) "ad\neh\nil\n"))))

(ert-deftest editing/registers ()
  (test-in-buffer #'text-mode "hello world"
    (copy-to-register ?a 1 6)
    (goto-char (point-max))
    (insert-register ?a)
    (should (equal (buffer-string) "hello worldhello"))))

(ert-deftest editing/keyboard-macro ()
  (test-in-buffer #'text-mode ""
    (execute-kbd-macro "ab")
    (should (equal (buffer-string) "ab"))))

;;; editing-commands.el ends here
