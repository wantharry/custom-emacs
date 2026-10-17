;;; treemacs.el --- the file tree sidebar (Treemacs) is wired in, lazy, and works with the lock  -*- lexical-binding: t; -*-
;; harness: config
;; Needs Treemacs installed (./build.sh packages); the tests that use it skip without it.

(defmacro tm-need ()
  `(progn (unless (locate-library "treemacs") (ert-skip "treemacs is not installed (./build.sh packages)"))
          (require 'treemacs)))

(defun tm--fresh ()
  "Forget every project and close the tree, so each test starts from an empty workspace."
  (when (treemacs-current-workspace)
    (dolist (p (copy-sequence (treemacs-workspace->projects (treemacs-current-workspace))))
      (treemacs-do-remove-project-from-workspace p t)))
  (dolist (b (buffer-list)) (when (string-prefix-p " *Treemacs" (buffer-name b)) (kill-buffer b)))
  (delete-other-windows))

(defun tm--kill-pending-git-status-processes ()
  "Kill any still-running `pfuture' process (what Treemacs's own extended git-status
integration uses for its background `treemacs-git-status.py' subprocess) and wait
for it to really exit.  A real, found-while-adding-the-cross-navigation-tests crash:
adding a project to the workspace kicks off this subprocess in the background, and
these processes are confirmed directly to be unidentifiable by anything useful in
`process-name' (just the generic \"Process Future\"/\"Process Future<1>\", no script
name) or `process-buffer' (nil) --- so every process left in a `run'/`open' state is
treated as one of these, since nothing legitimate in this test file's own fixtures
starts a real, intentionally-long-lived process of its own. Without this,
`tm-with-project''s own cleanup can delete the temp directory the subprocess is
still reading from before it finishes, crashing the whole batch process with an
unhandled \"Setting current directory\" error from its process sentinel, outside
ERT's own error handling."
  (dolist (p (process-list))
    (when (memq (process-status p) '(run open))
      (delete-process p)))
  (let ((tries 20))
    (while (and (> tries 0) (cl-some (lambda (p) (memq (process-status p) '(run open))) (process-list)))
      (accept-process-output nil 0.05)
      (setq tries (1- tries)))))

(defmacro tm-with-project (var &rest body)
  "Run BODY with VAR bound to a fresh git project holding two files, its README.md open."
  (declare (indent 1))
  `(test-with-temp-dir ,var
     (let* ((default-directory ,var)
            (treemacs-persist-file (concat ,var "persist"))
            (treemacs-last-error-persist-file (concat ,var "persist-error")))
       (tm--fresh)
       (make-directory (concat ,var "src") t)
       (dolist (f '("README.md" "src/Main.java")) (test-write-file (concat ,var f) "x\n"))
       (call-process "git" nil nil nil "init" "-q")
       (let ((tm--buf (find-file-noselect (concat ,var "README.md"))))
         (unwind-protect (progn (switch-to-buffer tm--buf) ,@body)
           (tm--fresh) (kill-buffer tm--buf))))))

(defun tm--tree-text ()
  (with-current-buffer (treemacs-get-local-buffer) (buffer-substring-no-properties (point-min) (point-max))))

;;; Wiring

(ert-deftest treemacs/keys-are-bound ()
  (unless (locate-library "treemacs") (ert-skip "treemacs is not installed"))
  (should (eq (key-binding (kbd "C-c t")) 'my/treemacs))
  (should (eq (key-binding (kbd "C-c T")) 'my/treemacs-reveal)))

(ert-deftest treemacs/is-not-loaded-until-used ()
  ;; In a fresh Emacs, because other tests here load it into this one.
  (let ((out (with-output-to-string
               (with-current-buffer standard-output
                 (call-process test-emacs nil t nil "--batch" "--init-directory" (getenv "CONFIG_DIR")
                               "-l" (expand-file-name "early-init.el" (getenv "CONFIG_DIR"))
                               "-l" (expand-file-name "init.el" (getenv "CONFIG_DIR"))
                               "--eval" "(princ (list (featurep 'treemacs) (featurep 'dash) (featurep 'hydra)))")))))
    (should (string-match-p "(nil nil nil)" out))))

(ert-deftest treemacs/is-in-the-package-list-and-melpa-is-a-source ()
  (with-temp-buffer
    (insert-file-contents (expand-file-name "tools/install-packages.el" test-root))
    (should (re-search-forward "(defconst my/packages '([^)]*\\btreemacs\\b" nil t))
    (goto-char (point-min))
    (should (search-forward "https://melpa.org/packages/" nil t))))          ; the only place Treemacs is published

(ert-deftest treemacs/its-packages-are-on-the-load-path ()
  (tm-need)
  (dolist (lib '("treemacs" "dash" "s" "ht" "hydra" "pfuture" "cfrs" "ace-window"))
    (should (locate-library lib))))

(ert-deftest treemacs/follow-modes-are-turned-on-when-it-loads ()
  (tm-need)
  (should (bound-and-true-p treemacs-follow-mode))
  (should (bound-and-true-p treemacs-project-follow-mode)))

;;; Every key in the tree works (they are autoload stubs, and this config does not load the autoloads at startup)

(ert-deftest treemacs/every-command-bound-in-the-tree-exists ()
  (tm-need)
  (let (missing)
    (map-keymap
     (lambda (_k b)
       (cond ((and (symbolp b) b (not (fboundp b))) (push b missing))
             ((keymapp b) (map-keymap (lambda (_k2 b2) (when (and (symbolp b2) b2 (not (fboundp b2))) (push b2 missing))) b))))
     treemacs-mode-map)
    (should-not missing)
    (dolist (c '(treemacs-create-file treemacs-create-dir treemacs-delete-file treemacs-rename-file treemacs-move-file))
      (should (commandp c)))))

;;; The read-only lock and Treemacs's own file

(ert-deftest treemacs/its-project-list-file-is-recognised ()
  (dolist (f '("/home/u/.emacs.d/.cache/treemacs-persist" "c:/x/config/.cache/treemacs-persist-at-last-error"))
    (should (string-match-p my/always-editable-file-regexp f)))
  ;; The negative cases are not just "any other file": they exercise the regexp's own
  ;; anchors --- a trailing ".txt" (the real pattern ends in `\'', right after the exact
  ;; name) and a missing "/.cache/" directory (the real pattern requires it) must each
  ;; fail on their own; a looser, unanchored substring match would wrongly pass both.
  (dolist (f '("/home/u/.cache/treemacs-persist.txt" "/home/u/treemacs-persist" "/home/u/notes.txt"))
    (should-not (string-match-p my/always-editable-file-regexp f))))

(ert-deftest treemacs/its-project-list-can-be-written-despite-the-lock ()
  ;; The first version showed "[Treemacs] Error (buffer-read-only treemacs-persist) when persisting workspace".
  (test-with-temp-dir d
    (make-directory (concat d ".cache") t)
    (let* ((f (test-write-file (concat d ".cache/treemacs-persist") "x")) (b (find-file-noselect f)))
      (unwind-protect
          (with-current-buffer b (should-not buffer-read-only) (insert "y") (set-buffer-modified-p nil))
        (kill-buffer b)))))

;;; Using it

(ert-deftest treemacs/c-c-t-shows-the-current-project-without-a-prompt ()
  (tm-need)
  (tm-with-project d
    (with-timeout (20 (ert-fail "it waited for input"))
      (my/treemacs))
    (should (eq (treemacs-current-visibility) 'visible))
    (should (string-match-p (regexp-quote (file-name-nondirectory (directory-file-name d))) (tm--tree-text)))
    (should (= 1 (length (treemacs-workspace->projects (treemacs-current-workspace)))))))

(ert-deftest treemacs/c-c-t-again-hides-it-and-a-third-time-shows-it-without-adding-the-project-twice ()
  (tm-need)
  (tm-with-project d
    (my/treemacs)
    (should (eq (treemacs-current-visibility) 'visible))
    (my/treemacs)
    (should-not (eq (treemacs-current-visibility) 'visible))
    (my/treemacs)
    (should (eq (treemacs-current-visibility) 'visible))
    (should (= 1 (length (treemacs-workspace->projects (treemacs-current-workspace)))))))

(ert-deftest treemacs/a-folder-that-is-not-a-project-is-used-as-it-is ()
  (tm-need)
  (test-with-temp-dir d
    (let* ((default-directory d) (treemacs-persist-file (concat d "persist"))
           (treemacs-last-error-persist-file (concat d "persist-error")))
      (tm--fresh)
      (test-write-file (concat d "notes.txt") "x")
      (let ((b (find-file-noselect (concat d "notes.txt"))))
        (unwind-protect
            (progn (switch-to-buffer b)
                   (with-timeout (20 (ert-fail "it waited for input")) (my/treemacs))
                   (should (eq (treemacs-current-visibility) 'visible))
                   (should (= 1 (length (treemacs-workspace->projects (treemacs-current-workspace))))))
          (tm--fresh) (kill-buffer b))))))

(ert-deftest treemacs/c-c-shift-t-moves-to-the-tree-on-the-current-file ()
  (tm-need)
  (tm-with-project d
    (my/treemacs-reveal)
    (should (eq (treemacs-current-visibility) 'visible))
    (should (equal (treemacs--prop-at-point :path) (expand-file-name "README.md" d)))))

(ert-deftest treemacs/visiting-a-file-from-the-tree-opens-it-read-only ()
  (tm-need)
  (tm-with-project d
    (my/treemacs-reveal)
    (with-current-buffer (treemacs-get-local-buffer)
      (goto-char (point-min))
      (search-forward "README.md")
      (treemacs-RET-action))
    (let ((b (find-buffer-visiting (concat d "README.md"))))
      (should b)
      (should (buffer-local-value 'buffer-read-only b)))))

(ert-deftest treemacs/c-c-shift-t-also-works-from-dired-on-a-subdirectory ()
  ;; A real gap, found while adding cross-navigation between Dired/ranger/Treemacs:
  ;; `treemacs-find-file' (what `my/treemacs-reveal' wraps) only ever looks at
  ;; `(buffer-file-name (current-buffer))' --- confirmed directly in its own source
  ;; --- always nil in a directory-listing buffer, so this used to fall into
  ;; Treemacs's own interactive "File to find: " prompt instead of just going there.
  (tm-need)
  (tm-with-project d
    (dired (concat d "src"))
    (my/treemacs-reveal)
    (should (eq (treemacs-current-visibility) 'visible))
    (should (equal (treemacs--prop-at-point :path) (directory-file-name (concat d "src"))))
    (tm--kill-pending-git-status-processes)))

(defun tm--buffer-with-mode-and-dir (mode dir)
  "The first live buffer in MODE whose `default-directory' is DIR, or nil.
Checked this way, rather than via `major-mode'/`default-directory' right after
calling the command under test, since `select-window' inside a real `--batch' ERT
process does not reliably make `(current-buffer)' follow along the way it would in
a real, displayed session --- the buffer existing at all, in the right place, is the
actual thing each of these commands promises."
  (cl-find-if (lambda (b)
                (and (buffer-live-p b)
                     (eq (buffer-local-value 'major-mode b) mode)
                     (equal (file-truename (file-name-as-directory (buffer-local-value 'default-directory b)))
                            (file-truename (file-name-as-directory dir)))))
              (buffer-list)))

(ert-deftest treemacs/to-dired-opens-plain-dired-on-the-directory-at-point ()
  (tm-need)
  (tm-with-project d
    (my/treemacs-reveal)
    (with-current-buffer (treemacs-get-local-buffer)
      (goto-char (point-min))
      (search-forward "src")
      (my/treemacs-to-dired))
    (let ((b (tm--buffer-with-mode-and-dir 'dired-mode (concat d "src"))))
      (should b)
      (kill-buffer b))
    (tm--kill-pending-git-status-processes)))

(ert-deftest treemacs/to-magit-opens-the-enclosing-repository-not-a-nested-one ()
  ;; The real gotcha this test pins down: `magit-status' called WITH an explicit
  ;; DIRECTORY argument (confirmed directly in its own source) requires that exact
  ;; directory to already be a repository's own toplevel, or it offers to create a
  ;; SEPARATE, NESTED repository there instead --- `my/treemacs-to-magit' instead
  ;; `let'-binds `default-directory' and calls `magit-status' with no argument, the
  ;; same way `C-x g' itself does, so it finds the ENCLOSING repository correctly even
  ;; when point is on a subdirectory, not the project root.
  (tm-need)
  (if (not (locate-library "magit"))
      (ert-skip "magit is not installed (./build.sh packages)")
    (require 'magit)
    (tm-with-project d
      (my/treemacs-reveal)
      (with-current-buffer (treemacs-get-local-buffer)
        (goto-char (point-min))
        (search-forward "src")
        (my/treemacs-to-magit))
      (let ((b (tm--buffer-with-mode-and-dir 'magit-status-mode d)))
        (should b)
        (kill-buffer b))
      (tm--kill-pending-git-status-processes))))

(ert-deftest treemacs/to-ranger-opens-ranger-on-the-directory-at-point ()
  ;; A fresh subprocess, not the shared test-file process: `ranger' keeps its own
  ;; global tracked-window/tab state (`ranger-w-alist'/`ranger-t-alist') across calls
  ;; within one Emacs process, by design, for its real, interactive, long-running use
  ;; --- confirmed the hard way, repeatedly, that resetting it by hand between calls in
  ;; the SAME process was not enough to stop it from reusing a stale session and
  ;; opening the wrong directory. A real, separate process sidesteps that --- and also
  ;; Treemacs's own async git-status subprocess, the same cleanup-race source noted on
  ;; the "to-dired" test above, which a whole separate process finishing and exiting
  ;; cleanly avoids entirely rather than needing to out-race.
  (tm-need)
  (if (not (locate-library "ranger"))
      (ert-skip "ranger is not installed (./build.sh packages)")
    (test-with-temp-dir d
      (make-directory (concat d "src") t)
      (dolist (f '("README.md" "src/Main.java")) (test-write-file (concat d f) "x\n"))
      (call-process "git" nil nil nil "init" "-q" d)
      (let* ((src (concat d "src"))
             (form `(progn
                      (require 'treemacs)
                      (require 'ranger)
                      (setq default-directory ,d
                            treemacs-persist-file ,(concat d "persist")
                            treemacs-last-error-persist-file ,(concat d "persist-error")
                            treemacs-python-executable nil
                            ranger-preview-file nil)
                      (switch-to-buffer (find-file-noselect ,(concat d "README.md")))
                      (my/treemacs-reveal)
                      (with-current-buffer (treemacs-get-local-buffer)
                        (goto-char (point-min))
                        (search-forward "src")
                        (my/treemacs-to-ranger))
                      (princ (cl-loop for b in (buffer-list)
                                      thereis (and (eq (buffer-local-value 'major-mode b) 'ranger-mode)
                                                   (equal (file-truename (file-name-as-directory (buffer-local-value 'default-directory b)))
                                                          (file-truename (file-name-as-directory ,src))))))))
             (out (with-output-to-string
                    (with-current-buffer standard-output
                      (call-process test-emacs nil t nil "--batch" "--init-directory" (getenv "CONFIG_DIR")
                                    "-l" (expand-file-name "early-init.el" (getenv "CONFIG_DIR"))
                                    "-l" (expand-file-name "init.el" (getenv "CONFIG_DIR"))
                                    "--eval" (format "%S" form))))))
        (should (string-suffix-p "t" out))))))

;;; treemacs.el ends here
