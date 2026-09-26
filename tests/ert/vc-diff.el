;;; vc-diff.el --- version control, diff, merge  -*- lexical-binding: t; -*-
;; harness: bare

(require 'vc) (require 'vc-git) (require 'diff-mode) (require 'smerge-mode)

(defmacro vd-with-repo (dir &rest body)
  "Run BODY with DIR bound to a fresh git repo holding one committed file a.txt."
  (declare (indent 1))
  `(test-with-temp-dir ,dir
     (test-git ,dir "init" "-q")
     (test-write-file (concat ,dir "a.txt") "one\n")
     (test-git ,dir "add" "a.txt")
     (test-git ,dir "commit" "-q" "-m" "first")
     ,@body))

(ert-deftest vc/finds-repository-root ()
  (vd-with-repo d
    (should (equal (file-truename (vc-git-root d)) (file-truename d)))
    (should (eq 'Git (vc-backend (concat d "a.txt"))))))

(ert-deftest vc/reports-file-state ()
  (vd-with-repo d
    ;; vc computes paths relative to `default-directory', which Emacs sets to the
    ;; file's directory when a file is visited.
    (let* ((default-directory d) (f (concat d "a.txt")) (u (concat d "new.txt")))
      ;; Visiting a file normally registers it; do that explicitly here.
      (should (vc-registered f))
      (should (eq 'up-to-date (vc-state f)))
      (test-write-file f "one\ntwo\n")
      (vc-file-clearprops f)
      (vc-registered f)
      (should (eq 'edited (vc-state f)))
      (test-write-file u "x")
      (should-not (vc-registered u)))))

(ert-deftest vc/working-revision-is-a-commit-hash ()
  (vd-with-repo d
    (should (string-match-p "\\`[0-9a-f]\\{40\\}\\'" (vc-working-revision (concat d "a.txt"))))))

(ert-deftest diff/produces-hunks ()
  (test-with-temp-dir d
    (let ((a (test-write-file (concat d "a") "x\n")) (b (test-write-file (concat d "b") "y\n")))
      (with-current-buffer (diff-no-select a b nil t)
        (should (eq major-mode 'diff-mode))
        (should (string-match-p "^-x$" (buffer-string)))
        (should (string-match-p "^\\+y$" (buffer-string)))
        (kill-buffer)))))

(ert-deftest diff/navigates-hunks ()
  (test-in-buffer #'diff-mode "--- a\n+++ b\n@@ -1 +1 @@\n-x\n+y\n@@ -9 +9 @@\n-p\n+q\n"
    (diff-hunk-next)
    (should (looking-at "@@ -1"))
    (diff-hunk-next)
    (should (looking-at "@@ -9"))))

(ert-deftest merge/smerge-resolves-conflicts ()
  (test-in-buffer #'text-mode "a\n<<<<<<< HEAD\nours\n=======\ntheirs\n>>>>>>> other\nb\n"
    (smerge-mode 1)
    (should (smerge-find-conflict))
    (smerge-keep-upper)
    (should (equal (buffer-string) "a\nours\nb\n"))))

(ert-deftest merge/smerge-can-keep-the-other-side ()
  (test-in-buffer #'text-mode "<<<<<<< HEAD\nours\n=======\ntheirs\n>>>>>>> other\n"
    (smerge-mode 1)
    (smerge-find-conflict)
    (smerge-keep-lower)
    (should (equal (buffer-string) "theirs\n"))))

;;; vc-diff.el ends here
