;;; magit.el --- Magit is wired in, lazy, and does not fight the read-only lock  -*- lexical-binding: t; -*-
;; harness: config
(require (quote ert))
(defun sp--startup-seconds ()
  (let ((best most-positive-fixnum))
    (dotimes (_ 3)
      (let ((t0 (float-time)))
        (call-process test-emacs nil nil nil "--batch" "--init-directory" (getenv "CONFIG_DIR")
                      "-l" (expand-file-name "early-init.el" (getenv "CONFIG_DIR"))
                      "-l" (expand-file-name "init.el" (getenv "CONFIG_DIR")) "--eval" "(kill-emacs)")
        (setq best (min best (- (float-time) t0)))))
    best))
;; Needs Magit installed (./build.sh packages); the tests that use it skip without it.

(defmacro mg-with-repo (&rest body)
  "Run BODY in a fresh Git repository with one commit and one uncommitted change."
  (declare (indent 0))
  `(test-with-temp-dir mg-dir
     (let ((default-directory mg-dir))
       (dolist (c '(("init" "-q") ("config" "user.email" "t@t") ("config" "user.name" "t")))
         (apply #'call-process "git" nil nil nil c))
       (with-temp-file (concat mg-dir "a.txt") (insert "one\n"))
       (call-process "git" nil nil nil "add" "a.txt")
       (call-process "git" nil nil nil "commit" "-qm" "first")
       (with-temp-file (concat mg-dir "a.txt") (insert "one\ntwo\n"))
       ,@body)))

(defmacro mg-need-magit ()
  `(progn (unless (locate-library "magit") (ert-skip "magit is not installed (./build.sh packages)"))
          (require 'magit)))

;;; Wiring

(ert-deftest magit/keys-are-bound-to-autoloads ()
  (unless (locate-library "magit") (ert-skip "magit is not installed"))
  (should (eq (key-binding (kbd "C-x g")) 'magit-status))
  (should (eq (key-binding (kbd "C-c g")) 'magit-file-dispatch)))

(ert-deftest magit/is-not-loaded-until-used ()
  ;; In a fresh Emacs, because other tests here load Magit into this one.
  (let ((out (with-output-to-string
               (with-current-buffer standard-output
                 (call-process test-emacs nil t nil "--batch" "--init-directory" (getenv "CONFIG_DIR")
                               "-l" (expand-file-name "early-init.el" (getenv "CONFIG_DIR"))
                               "-l" (expand-file-name "init.el" (getenv "CONFIG_DIR"))
                               "--eval" "(princ (list (featurep 'magit) (featurep 'magit-section) (featurep 'with-editor) (autoloadp (symbol-function 'magit-status))))")))))
    ;; not loaded, and `magit-status' is still an autoload stub
    (should (string-match-p "(nil nil nil t)" out))))

(ert-deftest magit/is-in-the-package-list ()
  (with-temp-buffer
    (insert-file-contents (expand-file-name "tools/install-packages.el" test-root))
    (should (re-search-forward "(defconst my/packages '([^)]*\\bmagit\\b" nil t))))

(ert-deftest magit/its-packages-are-on-the-load-path ()
  (mg-need-magit)
  (should (locate-library "magit"))
  (should (locate-library "magit-section"))
  (should (locate-library "with-editor")))

;;; The read-only lock and Git's message files

(ert-deftest magit/git-message-files-are-recognised ()
  (dolist (f '("/r/.git/COMMIT_EDITMSG" "/r/.git/MERGE_MSG" "/r/.git/TAG_EDITMSG"
               "/r/.git/NOTES_EDITMSG" "/r/.git/git-rebase-todo"
               "/r/.git/worktrees/w/COMMIT_EDITMSG" "/r/.git/modules/sub/COMMIT_EDITMSG"))
    (should (string-match-p my/always-editable-file-regexp f)))
  (dolist (f '("/r/src/COMMIT_EDITMSG" "/r/COMMIT_EDITMSG.txt" "/r/git/notes.txt" "/r/.gitignore"
               "/r/.git/config" "/r/.git/HEAD"))
    (should-not (string-match-p my/always-editable-file-regexp f))))

(ert-deftest magit/commit-message-file-opens-editable-but-other-files-stay-locked ()
  (mg-with-repo
    (make-directory (concat mg-dir ".git") t)
    (let* ((msg (concat mg-dir ".git/COMMIT_EDITMSG"))
           (other (concat mg-dir "a.txt"))
           (mb (find-file-noselect msg)) (ob (find-file-noselect other)))
      (unwind-protect
          (progn (should-not (buffer-local-value 'buffer-read-only mb))
                 (should (buffer-local-value 'buffer-read-only ob)))
        ;; with-editor (loaded by other tests) refuses a plain kill of a commit message buffer
        (with-current-buffer mb (setq-local kill-buffer-query-functions nil)
                                (when (fboundp 'with-editor-mode) (remove-hook 'kill-buffer-query-functions 'with-editor-kill-buffer-noop t)))
        (let ((kill-buffer-query-functions nil)) (ignore-errors (kill-buffer mb)))
        (kill-buffer ob)))))

;;; Using it

(ert-deftest magit/status-lists-the-uncommitted-change ()
  (mg-need-magit)
  (mg-with-repo
    (let ((buf (magit-status-setup-buffer mg-dir)))
      (unwind-protect
          (with-current-buffer buf
            (should (derived-mode-p 'magit-status-mode))
            (should (string-match-p "Unstaged changes" (buffer-string)))
            (should (string-match-p "a\\.txt" (buffer-string)))
            (should (string-match-p "Recent commits" (buffer-string))))
        (kill-buffer buf)))))

(ert-deftest magit/staging-moves-the-change-to-staged ()
  (mg-need-magit)
  (mg-with-repo
    (magit-stage-files '("a.txt"))
    (let ((buf (magit-status-setup-buffer mg-dir)))
      (unwind-protect
          (with-current-buffer buf
            (should (string-match-p "Staged changes" (buffer-string)))
            (should-not (string-match-p "Unstaged changes" (buffer-string))))
        (kill-buffer buf)))))

(ert-deftest magit/a-folder-that-is-not-a-repository-is-not-one ()
  (mg-need-magit)
  (test-with-temp-dir d
    (let ((default-directory d))
      (should-not (magit-toplevel d)))))

(ert-deftest magit/log-shows-the-commit ()
  (mg-need-magit)
  (mg-with-repo
    (let ((default-directory mg-dir))
      (should (equal (magit-git-string "log" "-1" "--format=%s") "first"))
      (let ((buf (magit-log-setup-buffer '("HEAD") nil nil)))
        (unwind-protect (with-current-buffer buf
                          (should (derived-mode-p 'magit-log-mode))
                          (should (string-match-p "first" (buffer-string))))
          (kill-buffer buf))))))

(ert-deftest magit/does-not-slow-startup ()
  ;; Same threshold as startup/under-half-a-second; Magit must add nothing at startup.
  (should (< (sp--startup-seconds) 0.5)))

;;; magit.el ends here
