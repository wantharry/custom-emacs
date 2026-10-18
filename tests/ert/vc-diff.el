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

(defun vd--wait-for-process (buf)
  "`vc-git-print-log'/`vc-git-annotate-command' run git asynchronously ---
batch Emacs has no real event loop driving that on its own, so poll for the
process BUF's command started to finish before reading its output."
  (with-current-buffer buf
    (let ((proc (get-buffer-process (current-buffer))) (n 0))
      (while (and proc (process-live-p proc) (< n 50))
        (accept-process-output proc 0.1) (setq n (1+ n))))))

(ert-deftest vc/print-log-shows-the-commit-message ()
  (vd-with-repo d
    (let ((default-directory d))
      (vc-git-print-log (list (concat d "a.txt")) "*vc-test-log*")
      (vd--wait-for-process "*vc-test-log*")
      (with-current-buffer "*vc-test-log*"
        (should (string-match-p "first" (buffer-string)))
        (kill-buffer)))))

(ert-deftest vc/annotate-shows-line-attribution ()
  (vd-with-repo d
    (let ((default-directory d) (f (concat d "a.txt")))
      (with-current-buffer (get-buffer-create "*vc-test-annotate*")
        (unwind-protect
            (progn
              (vc-git-annotate-command f (current-buffer))
              (vd--wait-for-process (current-buffer))
              (should (string-match-p "one" (buffer-string))))
          (kill-buffer))))))

(ert-deftest vc/revert-restores-the-last-committed-content ()
  ;; `vc-git-revert' directly, not the dispatching `vc-revert' --- the latter deduces
  ;; its fileset/default-directory from window-selection state `vc-revert' assumes an
  ;; interactive caller already set up, which a plain --batch `--eval' never does
  ;; (confirmed directly: it ran `git reset' against the wrong cwd, a real but
  ;; harness-only quirk, not a config bug --- `vc-git-revert' takes the file
  ;; explicitly and is what `vc-revert' itself calls once dispatch is done).
  (vd-with-repo d
    (let* ((default-directory d) (f (concat d "a.txt")) (buf (find-file-noselect f)))
      (unwind-protect
          (with-current-buffer buf
            (goto-char (point-max))
            (insert "local change\n")
            (save-buffer)
            (vc-git-revert f)
            (should (equal (test-read-file f) "one\n")))
        (kill-buffer buf)))))

(ert-deftest vc/rename-file-is-tracked-by-git ()
  (vd-with-repo d
    (let ((default-directory d))
      (vc-rename-file (concat d "a.txt") (concat d "renamed.txt"))
      (should-not (file-exists-p (concat d "a.txt")))
      (should (file-exists-p (concat d "renamed.txt")))
      (should (eq (vc-backend (concat d "renamed.txt")) 'Git)))))

(ert-deftest vc/delete-file-removes-it-and-stages-the-removal ()
  (vd-with-repo d
    (let ((default-directory d) (f (concat d "a.txt")))
      (vc-delete-file f t) ; NOCONFIRM, so this never needs a prompt stub
      (should-not (file-exists-p f))
      (should (/= 0 (test-git d "diff" "--cached" "--quiet"))))))

(ert-deftest vc/create-tag-adds-a-real-git-tag ()
  (vd-with-repo d
    (vc-create-tag d "v1" nil)
    (with-temp-buffer
      (let ((default-directory d)) (call-process "git" nil t nil "tag" "-l"))
      (should (string-match-p "\\`v1$" (string-trim (buffer-string)))))))

(ert-deftest vc/git-root-found-from-a-nested-subdirectory ()
  (vd-with-repo d
    (make-directory (concat d "sub/deeper") t)
    (should (equal (file-truename (vc-git-root (concat d "sub/deeper/"))) (file-truename d)))))

(ert-deftest vc/file-outside-any-repo-has-no-backend ()
  (test-with-temp-dir d
    (let ((f (test-write-file (concat d "x.txt") "x")))
      (should-not (vc-backend f)))))

(ert-deftest vc/ignore-adds-the-pattern-to-gitignore ()
  (vd-with-repo d
    (vc-ignore "*.log" d)
    (should (equal (test-read-file (concat d ".gitignore")) "*.log\n"))))

(ert-deftest diff/diff-buffer-with-file-shows-unsaved-changes ()
  (test-with-temp-dir d
    (let* ((f (test-write-file (concat d "f.txt") "old\n")) (buf (find-file-noselect f)))
      (unwind-protect
          (with-current-buffer buf
            (goto-char (point-max))
            (insert "new\n")
            (diff-buffer-with-file buf)
            (with-current-buffer "*Diff*"
              (should (string-match-p "\\+new" (buffer-string)))
              (kill-buffer)))
        (kill-buffer buf)))))

(ert-deftest diff/includes-context-lines-around-a-change ()
  (test-with-temp-dir d
    (let ((a (test-write-file (concat d "a") "ctx1\nctx2\nold\nctx3\nctx4\n"))
          (b (test-write-file (concat d "b") "ctx1\nctx2\nnew\nctx3\nctx4\n")))
      (with-current-buffer (diff-no-select a b '("-u") t)
        (should (string-match-p "ctx2" (buffer-string)))
        (should (string-match-p "ctx3" (buffer-string)))
        (kill-buffer)))))

(ert-deftest smerge/next-and-prev-move-between-conflicts ()
  (test-in-buffer #'text-mode
      "a\n<<<<<<< HEAD\nx1\n=======\ny1\n>>>>>>> other\nmid\n<<<<<<< HEAD\nx2\n=======\ny2\n>>>>>>> other\nb\n"
    (smerge-mode 1)
    (goto-char (point-min))
    (smerge-next)
    (should (looking-at "<<<<<<<"))
    (let ((first (point)))
      (smerge-next)
      (should (looking-at "<<<<<<<"))
      (should (> (point) first))
      (smerge-prev)
      (should (= (point) first)))))

(ert-deftest smerge/keep-base-keeps-the-common-ancestor-text ()
  (test-in-buffer #'text-mode "<<<<<<< HEAD\nours\n||||||| base\nbase\n=======\ntheirs\n>>>>>>> other\n"
    (smerge-mode 1)
    (smerge-find-conflict)
    (smerge-keep-base)
    (should (equal (buffer-string) "base\n"))))

;;; vc-diff.el ends here
