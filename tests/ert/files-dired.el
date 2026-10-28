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
      ;; `recentf-list' stores `abbreviate-file-name''s result, not the raw path ---
      ;; harmless to compare directly everywhere the temp directory isn't under
      ;; `$HOME' (true on Linux: `/tmp' isn't), but found the hard way on Windows,
      ;; where the real per-user temp directory IS under the profile folder
      ;; `abbreviate-file-name' abbreviates to `~', so `recentf-list' there held
      ;; "~/AppData/Local/Temp/..." while `f' was still the unabbreviated form.
      (should (member (abbreviate-file-name f) recentf-list)))))

(defmacro fd--with-dired (dir &rest body)
  "Run BODY with a Dired buffer on DIR current, killed afterward."
  (declare (indent 1))
  `(let ((buf (dired-noselect ,dir)))
     (unwind-protect (with-current-buffer buf ,@body)
       (kill-buffer buf))))

(ert-deftest dired/mark-and-get-marked-files ()
  (test-with-temp-dir d
    (test-write-file (concat d "alpha.txt") "")
    (test-write-file (concat d "beta.txt") "")
    (fd--with-dired d
      (goto-char (point-min))
      (dired-goto-file (concat d "alpha.txt"))
      (dired-mark 1)
      (should (equal (dired-get-marked-files)
                     (list (concat d "alpha.txt")))))))

(ert-deftest dired/unmark-clears-the-mark ()
  (test-with-temp-dir d
    (test-write-file (concat d "a.txt") "")
    (fd--with-dired d
      (dired-goto-file (concat d "a.txt"))
      (dired-mark 1)
      (should (dired-get-marked-files nil 'marked))
      (dired-goto-file (concat d "a.txt"))
      (dired-unmark 1)
      (should-not (dired-get-marked-files nil 'marked)))))

(ert-deftest dired/mark-all-files-regexp ()
  (test-with-temp-dir d
    (test-write-file (concat d "a.txt") "")
    (test-write-file (concat d "b.txt") "")
    (test-write-file (concat d "c.el") "")
    (fd--with-dired d
      (dired-mark-files-regexp "\\.txt\\'")
      (should (= 2 (length (dired-get-marked-files nil 'marked)))))))

(ert-deftest dired/flag-file-deletion-and-expunge ()
  (test-with-temp-dir d
    (let ((f (test-write-file (concat d "doomed.txt") "")))
      (fd--with-dired d
        (dired-goto-file f)
        (dired-flag-file-deletion 1)
        (save-window-excursion
          (cl-letf (((symbol-function 'yes-or-no-p) (lambda (&rest _) t)))
            (dired-do-flagged-delete)))
        (should-not (file-exists-p f))
        (should-not (dired-goto-file f))))))

(ert-deftest dired/do-copy-regular-file ()
  (test-with-temp-dir d
    (let* ((src (test-write-file (concat d "src.txt") "payload"))
           (dst (concat d "dst.txt")))
      (fd--with-dired d
        (dired-goto-file src)
        (dired-copy-file src dst nil))
      (should (equal (test-read-file dst) "payload"))
      (should (file-exists-p src)))))

(ert-deftest dired/do-rename-regular-file ()
  (test-with-temp-dir d
    (let* ((src (test-write-file (concat d "old.txt") "data"))
           (dst (concat d "new.txt")))
      (fd--with-dired d
        (dired-goto-file src)
        (dired-rename-file src dst nil))
      (should-not (file-exists-p src))
      (should (equal (test-read-file dst) "data")))))

;; User request, explicit: "I was trying to test regex move to another folder in
;; dired." The real, full workflow (not just marking, and not just a plain same-
;; directory rename, both already covered separately above): `% m REGEXP' marks
;; every matching file, then `R' (`dired-do-rename') moves every MARKED file to a
;; directory you are prompted for --- the move destination is a SEPARATE folder
;; here, confirmed by using two distinct temp directories, not the same one
;; `dired-rename-file' already covers. `dired-mark-read-file-name' (confirmed
;; directly, reading `dired-do-create-files' in `dired-aux.el': this is the exact
;; function that prompts "Move %s to: ") is mocked to return the target directory
;; immediately --- the real, correct way to drive an otherwise-interactive Dired
;; command non-interactively in a test, rather than faking keyboard input.
(ert-deftest dired/regex-mark-then-move-to-another-folder ()
  (test-with-temp-dir src
    (test-with-temp-dir dst
      (test-write-file (concat src "report1.txt") "one")
      (test-write-file (concat src "report2.txt") "two")
      (test-write-file (concat src "notes.el") "(ignored)")
      (fd--with-dired src
        (dired-mark-files-regexp "\\`report")
        (should (= 2 (length (dired-get-marked-files nil 'marked))))
        (cl-letf (((symbol-function 'dired-mark-read-file-name)
                   (lambda (&rest _) dst)))
          (dired-do-rename)))
      ;; moved: gone from the source, present (with real content) in the target.
      (should-not (file-exists-p (concat src "report1.txt")))
      (should-not (file-exists-p (concat src "report2.txt")))
      (should (equal (test-read-file (concat dst "report1.txt")) "one"))
      (should (equal (test-read-file (concat dst "report2.txt")) "two"))
      ;; the regex only matched "report*" --- the unrelated file never moved.
      (should (file-exists-p (concat src "notes.el")))
      (should-not (file-exists-p (concat dst "notes.el"))))))

(ert-deftest dired/create-directory-appears-in-listing ()
  (test-with-temp-dir d
    (fd--with-dired d
      (dired-create-directory "fresh")
      (should (file-directory-p (concat d "fresh")))
      (revert-buffer)
      (should (string-match-p "fresh" (buffer-string))))))

(ert-deftest dired/up-directory-visits-the-parent ()
  (test-with-temp-dir d
    (make-directory (concat d "child"))
    (fd--with-dired (concat d "child")
      (dired-up-directory)
      (should (equal (expand-file-name default-directory) (expand-file-name d))))))

(ert-deftest dired/find-file-opens-the-file-at-point ()
  (test-with-temp-dir d
    (let ((f (test-write-file (concat d "target.txt") "hi")))
      (fd--with-dired d
        (dired-goto-file f)
        (let ((opened (dired-find-file)))
          (ignore opened)
          (should (equal (buffer-file-name) f))
          (kill-buffer))))))

(ert-deftest dired/hide-details-mode-hides-the-permissions-column ()
  (test-with-temp-dir d
    (let ((f (test-write-file (concat d "a.txt") "")))
      (fd--with-dired d
        (dired-hide-details-mode 1)
        (dired-goto-file f)
        (should (invisible-p (+ 2 (line-beginning-position))))
        (dired-hide-details-mode -1)
        (dired-goto-file f)
        (should-not (invisible-p (+ 2 (line-beginning-position))))))))

(ert-deftest dired/revert-buffer-picks-up-new-files ()
  (test-with-temp-dir d
    (fd--with-dired d
      (should-not (string-match-p "later\\.txt" (buffer-string)))
      (test-write-file (concat d "later.txt") "")
      (revert-buffer)
      (should (string-match-p "later\\.txt" (buffer-string))))))

;;; files-dired.el ends here
