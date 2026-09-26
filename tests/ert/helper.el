;;; helper.el --- shared helpers for the ERT test files  -*- lexical-binding: t; -*-
;; Loaded by tests/run-all.sh before every test file.

(require 'ert)
(require 'cl-lib)
(require 'subr-x)

(defvar test-root (or (getenv "ROOT") default-directory)
  "Repository root.")
(defvar test-emacs (or (getenv "EMACS_BIN") (expand-file-name invocation-name invocation-directory))
  "The Emacs binary under test.")

(defmacro test-with-temp-dir (var &rest body)
  "Bind VAR to a fresh temporary directory (with trailing slash) around BODY."
  (declare (indent 1))
  `(let ((,var (file-name-as-directory (make-temp-file "emacs-test-" t))))
     (unwind-protect (progn ,@body)
       (ignore-errors (delete-directory ,var t)))))

(defmacro test-in-buffer (mode text &rest body)
  "Run BODY in a fresh ordinary buffer in MODE (a function) containing TEXT.
Point starts at the beginning.  The buffer name has no leading space, so undo
and mode hooks behave as in real editing.  It is shown in the selected window,
because keyboard macros and the command loop act on the window's buffer."
  (declare (indent 2))
  `(let* ((test--win (selected-window))
          (test--old (window-buffer test--win))
          (test--buf (generate-new-buffer "test-buf")))
     (unwind-protect
         (progn
           (set-window-buffer test--win test--buf)
           (with-current-buffer test--buf
             (funcall ,mode)
             (insert ,text)
             (goto-char (point-min))
             ,@body))
       (set-window-buffer test--win test--old)
       (when (buffer-live-p test--buf) (kill-buffer test--buf)))))

(defun test-write-file (path content)
  "Write CONTENT to PATH and return PATH."
  (with-temp-file path (insert content))
  path)

(defun test-read-file (path)
  "Return the contents of PATH."
  (with-temp-buffer (insert-file-contents path) (buffer-string)))

(defun test-skip-unless-network ()
  (unless (getenv "RUN_NETWORK_TESTS")
    (ert-skip "network test: set RUN_NETWORK_TESTS=1 to run")))

(defun test-skip-unless-pruned ()
  (when (locate-library "org")
    (ert-skip "not a pruned install")))

(defun test-git (dir &rest args)
  "Run git ARGS in DIR with a fixed identity.  Return the exit status."
  (let ((default-directory dir)
        (process-environment
         (append '("GIT_AUTHOR_NAME=t" "GIT_AUTHOR_EMAIL=t@t" "GIT_COMMITTER_NAME=t"
                   "GIT_COMMITTER_EMAIL=t@t" "GIT_CONFIG_GLOBAL=/dev/null"
                   "GIT_CONFIG_SYSTEM=/dev/null")
                 process-environment)))
    (apply #'call-process "git" nil nil nil args)))

;;; helper.el ends here
