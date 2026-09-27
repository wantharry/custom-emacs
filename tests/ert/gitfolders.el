;;; gitfolders.el --- finding every git repository (C-c f p) works and never blocks Emacs  -*- lexical-binding: t; -*-
;; harness: config

(require 'gitfolders (expand-file-name "gitfolders" (or (getenv "CONFIG_DIR") user-emacs-directory)))

(defmacro gr-need-unix ()
  ;; This whole feature is Linux/WSL only (see config/gitfolders.el): the script is bash, and
  ;; assumes a Unix `/', `/mnt', `.git' layout, none of which apply on the Windows bundle.
  `(skip-unless (not (eq system-type 'windows-nt))))

(defmacro gr-with-stub-script (script-text &rest body)
  "Run BODY with `my/git-repos-script' pointing at a small executable script
containing SCRIPT-TEXT, instead of the real (slow, whole-disk) one."
  (declare (indent 1))
  `(progn
     (gr-need-unix)
     (test-with-temp-dir gr-dir
     (let ((my/git-repos-script (concat gr-dir "stub.sh")))
       (test-write-file my/git-repos-script (concat "#!/usr/bin/env bash\n" ,script-text))
       (set-file-modes my/git-repos-script #o755)
       (unwind-protect (progn ,@body)
         (when (get-buffer my/git-repos-buffer-name)
           (with-current-buffer my/git-repos-buffer-name
             (when (process-live-p my/git-repos--process) (delete-process my/git-repos--process)))
           (kill-buffer my/git-repos-buffer-name)))))))

(defun gr--run-and-wait (&optional windows)
  "Call `my/find-git-repos', wait for the (stub) process to finish, return its buffer."
  (my/find-git-repos windows)
  (with-current-buffer my/git-repos-buffer-name
    (let ((n 0))
      (while (and (< n 100) (process-live-p my/git-repos--process))
        (accept-process-output my/git-repos--process 0.1)
        (setq n (1+ n))))
    (current-buffer)))

;;; Wiring

(ert-deftest gitfolders/key-is-bound ()
  (should (eq (key-binding (kbd "C-c f p")) 'my/find-git-repos)))

(ert-deftest gitfolders/is-not-loaded-until-used ()
  (let ((out (with-output-to-string
               (with-current-buffer standard-output
                 (call-process test-emacs nil t nil "--batch" "--init-directory" (getenv "CONFIG_DIR")
                               "-l" (expand-file-name "early-init.el" (getenv "CONFIG_DIR"))
                               "-l" (expand-file-name "init.el" (getenv "CONFIG_DIR"))
                               "--eval" "(princ (list (featurep 'gitfolders) (autoloadp (symbol-function 'my/find-git-repos))))")))))
    (should (string-match-p "(nil t)" out))))

(ert-deftest gitfolders/does-not-slow-startup ()
  (let ((best most-positive-fixnum))
    (dotimes (_ 3)
      (let ((t0 (float-time)))
        (call-process test-emacs nil nil nil "--batch" "--init-directory" (getenv "CONFIG_DIR")
                      "-l" (expand-file-name "early-init.el" (getenv "CONFIG_DIR"))
                      "-l" (expand-file-name "init.el" (getenv "CONFIG_DIR"))
                      "--eval" "(kill-emacs)")
        (setq best (min best (- (float-time) t0)))))
    (should (< best 0.5))))

;;; The two ways this declines gracefully instead of erroring: on Windows, or with no script

(ert-deftest gitfolders/declines-clearly-on-windows-instead-of-trying-to-run-bash ()
  ;; Only meaningful on a real Windows Emacs: binding `system-type' to fake it on Linux makes
  ;; Emacs's own file-name code reach for real w32-only primitives that do not exist here,
  ;; which is a worse test than simply running for real where it matters.
  (skip-unless (eq system-type 'windows-nt))
  (let (msg)
    (cl-letf (((symbol-function 'message) (lambda (fmt &rest a) (setq msg (apply #'format fmt a)))))
      (my/find-git-repos))
    (should (string-match-p "Windows bundle" msg))
    (should-not (get-buffer my/git-repos-buffer-name))))

(ert-deftest gitfolders/declines-clearly-when-the-script-is-missing ()
  ;; On Windows the platform check above always fires first, regardless of the script path.
  (gr-need-unix)
  (let ((my/git-repos-script "/does/not/exist.sh") msg)
    (cl-letf (((symbol-function 'message) (lambda (fmt &rest a) (setq msg (apply #'format fmt a)))))
      (my/find-git-repos))
    (should (string-match-p "is missing" msg))
    (should-not (get-buffer my/git-repos-buffer-name))))

(defun gr--real-script ()
  "The real tools/find-repos.sh in this repository, regardless of where
`my/git-repos-script' resolves in the current test harness (its own
temp copy of just the config/*.el files has no tools/ directory at all,
exactly like the Windows bundle, which is the case it is meant to handle)."
  (expand-file-name "tools/find-repos.sh" test-root))

(ert-deftest gitfolders/the-real-script-is-executable-and-valid-bash ()
  (gr-need-unix)
  (should (file-executable-p (gr--real-script)))
  (should (equal (call-process "bash" nil nil nil "-n" (gr--real-script)) 0)))

;;; The buffer, built from a stub script (deterministic, instant)

(ert-deftest gitfolders/lists-every-repo-the-script-prints ()
  (gr-with-stub-script "echo '== Linux =='\necho '/tmp/one'\necho '/tmp/two'\n"
    (with-current-buffer (gr--run-and-wait)
      (should (string-match-p "^Linux$" (buffer-string)))
      (should (string-match-p "/tmp/one" (buffer-string)))
      (should (string-match-p "/tmp/two" (buffer-string)))
      (should (= 2 my/git-repos--count)))))

(ert-deftest gitfolders/no-scanning-message-or-raw-section-marker-is-left-behind ()
  (gr-with-stub-script "echo '== Linux =='\necho '/tmp/one'\n"
    (with-current-buffer (gr--run-and-wait)
      (should-not (string-match-p "Scanning" (buffer-string)))
      (should-not (string-match-p "== " (buffer-string))))))

(ert-deftest gitfolders/a-line-split-across-two-process-filter-chunks-still-works ()
  ;; A process filter can be called with a chunk that ends mid-line; simulate that directly,
  ;; since a real (fast, small) script rarely if ever triggers it.
  (gr-need-unix)
  (test-with-temp-dir gr-dir
    (let ((my/git-repos-script (concat gr-dir "stub.sh")))
      (test-write-file my/git-repos-script "#!/usr/bin/env bash\nsleep 5\n")
      (set-file-modes my/git-repos-script #o755)
      (unwind-protect
          (with-current-buffer (my/git-repos-refresh nil)
            (my/git-repos--handle-output (current-buffer) "== Linux ==\n/tmp/part")
            (should (equal my/git-repos--pending "/tmp/part"))
            (should-not (string-match-p "/tmp/part" (buffer-string)))   ; not inserted yet: no newline seen
            (my/git-repos--handle-output (current-buffer) "ial-repo\n/tmp/whole\n")
            (should (equal my/git-repos--pending ""))
            (should (string-match-p "/tmp/partial-repo" (buffer-string)))
            (should (string-match-p "/tmp/whole" (buffer-string)))
            (should (= 2 my/git-repos--count)))
        (when (get-buffer my/git-repos-buffer-name)
          (with-current-buffer my/git-repos-buffer-name
            (when (process-live-p my/git-repos--process) (delete-process my/git-repos--process)))
          (kill-buffer my/git-repos-buffer-name))))))

(ert-deftest gitfolders/a-final-line-with-no-trailing-newline-is-not-dropped ()
  ;; `my/git-repos--flush' (called from the sentinel) must catch this, or the very last
  ;; result would silently vanish whenever the script's own last `echo' produced one.
  (gr-with-stub-script "echo '== Linux =='\nprintf '/tmp/no-newline-at-end'\n"
    (with-current-buffer (gr--run-and-wait)
      (should (string-match-p "/tmp/no-newline-at-end" (buffer-string))))))

(ert-deftest gitfolders/the-buffer-is-read-only ()
  (gr-with-stub-script "echo '== Linux =='\necho '/tmp/one'\n"
    (with-current-buffer (gr--run-and-wait)
      (should buffer-read-only)
      (should-error (let ((buffer-read-only t)) (insert "x")) :type 'buffer-read-only))))

(ert-deftest gitfolders/g-refreshes ()
  (should (eq (lookup-key my/git-repos-mode-map "g") 'my/git-repos-refresh)))

(ert-deftest gitfolders/refresh-stops-an-in-flight-scan-first ()
  (gr-with-stub-script "sleep 10\n"
    (my/find-git-repos)
    (let ((first-proc (with-current-buffer my/git-repos-buffer-name my/git-repos--process)))
      (should (process-live-p first-proc))
      (my/git-repos-refresh)
      (should-not (process-live-p first-proc)))))

;;; Clicking a result

(ert-deftest gitfolders/clicking-a-result-opens-magit-status-there ()
  (gr-with-stub-script "echo '== Linux =='\necho '/tmp/some-repo'\n"
    (let (opened (real-fboundp (symbol-function 'fboundp)))
      (cl-letf (((symbol-function 'magit-status) (lambda (dir) (setq opened dir)))
                ((symbol-function 'fboundp) (lambda (f) (if (eq f 'magit-status) t (funcall real-fboundp f)))))
        (with-current-buffer (gr--run-and-wait)
          (goto-char (point-min))
          (search-forward "/tmp/some-repo")
          (backward-char 2)
          (push-button)))
      (should (equal opened "/tmp/some-repo")))))

(ert-deftest gitfolders/without-magit-it-opens-dired-instead ()
  (gr-with-stub-script "echo '== Linux =='\necho '/tmp/some-repo'\n"
    (let (opened (real-fboundp (symbol-function 'fboundp)))
      (cl-letf (((symbol-function 'fboundp) (lambda (f) (if (eq f 'magit-status) nil (funcall real-fboundp f))))
                ((symbol-function 'dired) (lambda (dir) (setq opened dir))))
        (with-current-buffer (gr--run-and-wait)
          (goto-char (point-min))
          (search-forward "/tmp/some-repo")
          (backward-char 2)
          (push-button)))
      (should (equal opened "/tmp/some-repo")))))

;;; The prefix argument

(ert-deftest gitfolders/a-prefix-argument-adds-windows-to-the-scan-command ()
  (gr-with-stub-script "echo '== Linux =='\n"
    (let (seen-command)
      (cl-letf* ((real-make-process (symbol-function 'make-process))
                 ((symbol-function 'make-process)
                  (lambda (&rest args) (setq seen-command (plist-get args :command)) (apply real-make-process args))))
        (with-current-buffer (gr--run-and-wait t)
          (should (member "--windows" seen-command))
          (should my/git-repos--windows))))))

(ert-deftest gitfolders/no-prefix-argument-means-linux-only ()
  (gr-with-stub-script "echo '== Linux =='\n"
    (let (seen-command)
      (cl-letf* ((real-make-process (symbol-function 'make-process))
                 ((symbol-function 'make-process)
                  (lambda (&rest args) (setq seen-command (plist-get args :command)) (apply real-make-process args))))
        (with-current-buffer (gr--run-and-wait nil)
          (should-not (member "--windows" seen-command))
          (should-not my/git-repos--windows))))))

;;; The real script, against the real disk (fast: the Linux side only, no --windows)

(ert-deftest gitfolders/the-real-script-finds-this-projects-own-repository ()
  (gr-need-unix)
  (let ((out (shell-command-to-string (shell-quote-argument (gr--real-script)))))
    (should (string-match-p (regexp-quote (directory-file-name (expand-file-name test-root))) out))))

;;; gitfolders.el ends here
