;;; files-dired.el --- files, backups, dired, recent files  -*- lexical-binding: t; -*-
;; harness: config
;; Files open read-only in this config, so tests that edit call `allow-editing'
;; first, exactly as a user would.

(defun fd--visit-editable (file)
  (let ((b (find-file-noselect file))) (with-current-buffer b (allow-editing)) b))

(ert-deftest files/write-and-read-back ()
  (test-with-temp-dir d
    (let ((f (test-write-file (concat d "a.txt") "hello\n")))
      (should (equal (test-read-file f) "hello\n"))
      (should (= 6 (file-attribute-size (file-attributes f)))))))

(ert-deftest files/final-newline-added-on-save ()
  (test-with-temp-dir d
    (let* ((f (concat d "n.txt")) (buf (fd--visit-editable f)))
      (unwind-protect (with-current-buffer buf (insert "abc") (save-buffer))
        (kill-buffer buf))
      (should (equal (test-read-file f) "abc\n")))))

(ert-deftest files/backup-holds-previous-contents ()
  ;; Emacs never backs up files under /tmp by default, and tests live there.
  (let ((backup-enable-predicate (lambda (_) t)))
   (test-with-temp-dir d
    (let* ((f (test-write-file (concat d "b.txt") "one\n")) (buf (fd--visit-editable f)))
      (unwind-protect (with-current-buffer buf (insert "two\n") (save-buffer))
        (kill-buffer buf))
      (let ((backup (make-backup-file-name f)))
        (should (file-exists-p backup))
        (should (equal (test-read-file backup) "one\n"))
        (should (string-prefix-p (expand-file-name "backups/" user-emacs-directory) backup)))))))

(ert-deftest files/no-lockfile-created ()
  (test-with-temp-dir d
    (let* ((f (test-write-file (concat d "l.txt") "x")) (buf (fd--visit-editable f)))
      (unwind-protect
          (with-current-buffer buf
            (insert "y")
            (should-not (file-locked-p f))
            (should-not (file-exists-p (concat d ".#l.txt")))
            (set-buffer-modified-p nil))
        (kill-buffer buf)))))

(ert-deftest files/auto-revert-picks-up-external-changes ()
  ;; Batch Emacs never switches globalized modes on for file buffers (true of
  ;; Emacs 29 too), so enable the mode explicitly and check the behavior.
  (should global-auto-revert-mode)
  (test-with-temp-dir d
    (let* ((f (test-write-file (concat d "r.txt") "old\n")) (buf (fd--visit-editable f)))
      (unwind-protect
          (with-current-buffer buf
            (auto-revert-mode 1)
            (test-write-file f "new\n")
            (set-file-times f (time-add (current-time) 10))
            (auto-revert-handler)
            (should (equal (buffer-string) "new\n")))
        (with-current-buffer buf (set-buffer-modified-p nil))
        (kill-buffer buf)))))

(ert-deftest files/dired-lists-directory ()
  (test-with-temp-dir d
    (test-write-file (concat d "alpha.txt") "")
    (test-write-file (concat d "beta.txt") "")
    (let ((buf (dired-noselect d)))
      (unwind-protect
          (with-current-buffer buf
            (should (eq major-mode 'dired-mode))
            (should (string-match-p "alpha\\.txt" (buffer-string)))
            (should (string-match-p "beta\\.txt" (buffer-string))))
        (kill-buffer buf)))))

(ert-deftest files/copy-rename-delete ()
  (test-with-temp-dir d
    (let ((a (test-write-file (concat d "a") "data")) (b (concat d "b")) (c (concat d "c")))
      (copy-file a b)
      (should (equal (test-read-file b) "data"))
      (rename-file b c)
      (should-not (file-exists-p b))
      (should (file-exists-p c))
      (delete-file c)
      (should-not (file-exists-p c)))))

(ert-deftest files/symbolic-links ()
  (test-with-temp-dir d
    (let ((a (test-write-file (concat d "a") "x")) (l (concat d "l")))
      (condition-case nil (make-symbolic-link a l)
        (file-error (ert-skip "this system will not create symbolic links (Windows needs Developer Mode)")))
      (should (equal (file-symlink-p l) a))
      (should (file-equal-p a l)))))

(ert-deftest files/name-manipulation ()
  (should (equal (file-name-directory "/a/b/c.txt") "/a/b/"))
  (should (equal (file-name-nondirectory "/a/b/c.txt") "c.txt"))
  (should (equal (file-name-extension "c.tar.gz") "gz"))
  (should (equal (file-name-sans-extension "c.txt") "c"))
  (should (equal (expand-file-name "../x" "/a/b/") (expand-file-name "/a/x")))   ; "c:/a/x" on Windows
  (should (equal (file-relative-name "/a/b/c" "/a/") "b/c")))

(ert-deftest files/directory-listing ()
  (test-with-temp-dir d
    (make-directory (concat d "sub/deep") t)
    (test-write-file (concat d "sub/deep/x.el") "")
    (test-write-file (concat d "y.txt") "")
    (should (equal (mapcar (lambda (f) (file-relative-name f d))
                           (directory-files-recursively d "\\.el\\'"))
                   '("sub/deep/x.el")))
    (should (equal (directory-files d nil "\\`[^.]") '("sub" "y.txt")))))

(ert-deftest files/recentf-tracks-files ()
  (test-with-temp-dir d
    (let ((f (test-write-file (concat d "rc.txt") "")))
      (recentf-add-file f)
      (should (member f recentf-list)))))

;;; files-dired.el ends here
