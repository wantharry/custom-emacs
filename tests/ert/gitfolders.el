;;; gitfolders.el --- finding every git repository (C-c f p) works and never blocks Emacs  -*- lexical-binding: t; -*-
;; harness: config

(require 'gitfolders (expand-file-name "gitfolders" (or (getenv "CONFIG_DIR") user-emacs-directory)))

(defmacro gr-need-unix ()
  ;; This whole feature is Linux/WSL only (see config/gitfolders.el): the script is bash, and
  ;; assumes a Unix `/', `/mnt', `.git' layout, none of which apply on the Windows bundle.
  `(skip-unless (not (eq system-type 'windows-nt))))

(defmacro gr-isolated (&rest body)
  "Run BODY with the index (`my/git-repos--list', `my/git-repos--loaded') and its
store file all reset to fresh, throwaway state, so a test can never read, and can
never overwrite, the real computer-wide index."
  (declare (indent 0))
  `(test-with-temp-dir gr-store-dir
     (let ((my/git-repos--list nil) (my/git-repos--loaded nil)
           (my/git-repos-store-file (concat gr-store-dir "index.eld")))
       ,@body)))

(defmacro gr-with-stub-script (script-text &rest body)
  "Run BODY with `my/git-repos-script' pointing at a small executable script
containing SCRIPT-TEXT, instead of the real (slow, whole-disk) one, and with the
index isolated (see `gr-isolated')."
  (declare (indent 1))
  `(progn
     (gr-need-unix)
     (gr-isolated
       (test-with-temp-dir gr-dir
         (let ((my/git-repos-script (concat gr-dir "stub.sh")))
           (test-write-file my/git-repos-script (concat "#!/usr/bin/env bash\n" ,script-text))
           (set-file-modes my/git-repos-script #o755)
           (unwind-protect (progn ,@body)
             (when (get-buffer my/git-repos-buffer-name)
               (with-current-buffer my/git-repos-buffer-name
                 (when (process-live-p my/git-repos--process) (delete-process my/git-repos--process)))
               (kill-buffer my/git-repos-buffer-name))))))))

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

;;; The pure, parameterized functions: safe and meaningful to test on every platform, since
;;; none of them reads `system-type' (or anything else) from a live global itself.

(ert-deftest gitfolders/command-on-linux-is-the-script-plus-an-optional-windows-flag ()
  (should (equal (my/git-repos--command 'gnu/linux nil "tools/find-repos.sh" nil nil)
                 '("tools/find-repos.sh")))
  (should (equal (my/git-repos--command 'gnu/linux t "tools/find-repos.sh" nil nil)
                 '("tools/find-repos.sh" "--windows"))))

(ert-deftest gitfolders/command-on-windows-runs-fd-across-every-drive-with-exclusions ()
  (let ((cmd (my/git-repos--command 'windows-nt nil "any-script" "fd.exe" '("C:/" "D:/"))))
    (should (equal (car cmd) "fd.exe"))
    (should (member "C:/" cmd))
    (should (member "D:/" cmd))
    (should (member "^\\.git$" cmd))
    (dolist (n my/git-repos-windows-excluded-names)
      (should (member n cmd)))
    ;; the (Linux-only) prefix argument makes no difference on Windows: every local drive is
    ;; already included either way, there is no separate "other side" to add
    (should (equal cmd (my/git-repos--command 'windows-nt t "any-script" "fd.exe" '("C:/" "D:/"))))))

(ert-deftest gitfolders/command-on-windows-is-nil-without-fd-or-without-any-drive ()
  (should-not (my/git-repos--command 'windows-nt nil "s" nil '("C:/")))
  (should-not (my/git-repos--command 'windows-nt nil "s" "fd.exe" nil)))

(ert-deftest gitfolders/windows-drives-only-includes-letters-that-really-exist ()
  (cl-letf (((symbol-function 'file-directory-p) (lambda (d) (member d '("C:/" "E:/")))))
    (should (equal (my/git-repos--windows-drives) '("C:/" "E:/")))))

;;; The index: merging a fresh scan into what was already known.  Pure, and safe and
;;; meaningful everywhere: `my/git-repos--merge' never reads `system-type' itself.

(ert-deftest gitfolders/merge-on-windows-fresh-entirely-replaces-old ()
  (should (equal (my/git-repos--merge '("/mnt/c/old" "/home/x") '("/home/y") nil 'windows-nt)
                 '("/home/y"))))

(ert-deftest gitfolders/merge-on-a-full-scan-fresh-entirely-replaces-old-even-on-linux ()
  (should (equal (my/git-repos--merge '("/mnt/c/old" "/home/x") '("/home/y") t 'gnu/linux)
                 '("/home/y"))))

(ert-deftest gitfolders/merge-on-a-quick-linux-scan-keeps-old-windows-drive-entries ()
  (should (equal (my/git-repos--merge '("/mnt/c/old" "/home/x") '("/home/y") nil 'gnu/linux)
                 '("/home/y" "/mnt/c/old"))))

(ert-deftest gitfolders/merge-removes-duplicates-and-sorts ()
  (should (equal (my/git-repos--merge nil '("/b" "/a" "/b") nil 'gnu/linux) '("/a" "/b"))))

;;; The two ways this declines gracefully instead of erroring: no `fd' on Windows, or no
;;; script on Linux.  Both go through parameterized functions, so both are safe and
;;; meaningful to test on every platform: nothing here touches the real `system-type'.

(ert-deftest gitfolders/declines-clearly-when-fd-is-missing-on-windows ()
  (should (string-match-p "fd.exe was not found" (my/git-repos--unavailable-reason 'windows-nt "s" nil)))
  (should-not (my/git-repos--unavailable-reason 'windows-nt "s" "fd.exe")))

(ert-deftest gitfolders/declines-clearly-when-the-script-is-missing-on-linux ()
  ;; A nonexistent file is "not executable" under any OS's rules, so this half is safe
  ;; everywhere; whether the real script itself counts as "executable" is a genuine
  ;; Unix-only notion (`file-executable-p' on Windows goes by file extension, not a real
  ;; script), so that half has its own test below, guarded accordingly.
  (should (string-match-p "is missing" (my/git-repos--unavailable-reason 'gnu/linux "/does/not/exist.sh" nil))))

(ert-deftest gitfolders/the-real-script-counts-as-available-on-linux ()
  (gr-need-unix)
  (should-not (my/git-repos--unavailable-reason 'gnu/linux (gr--real-script) nil)))

(ert-deftest gitfolders/my-find-git-repos-shows-the-real-message-and-opens-no-buffer-when-unavailable ()
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

;;; The index file: saved and reloaded

(ert-deftest gitfolders/the-index-is-saved-to-and-reloaded-from-its-store-file ()
  (gr-isolated
    (setq my/git-repos--list '("/tmp/a" "/tmp/b"))
    (my/git-repos--save)
    ;; a fresh, unloaded state, as a new Emacs session would start with
    (setq my/git-repos--list nil my/git-repos--loaded nil)
    (my/git-repos--load)
    (should (equal my/git-repos--list '("/tmp/a" "/tmp/b")))))

(ert-deftest gitfolders/loading-is-a-no-op-once-already-loaded ()
  (gr-isolated
    (test-write-file my/git-repos-store-file "(\"/tmp/on-disk\")")
    (setq my/git-repos--list '("/tmp/in-memory")  my/git-repos--loaded t)
    (my/git-repos--load)
    (should (equal my/git-repos--list '("/tmp/in-memory")))))

;;; The buffer, built from a stub script (deterministic, instant)

(ert-deftest gitfolders/the-buffer-shows-the-cached-index-at-once-before-the-scan-finishes ()
  (gr-with-stub-script "sleep 5\n"
    (setq my/git-repos--list '("/tmp/already-known"))
    (my/find-git-repos)
    (with-current-buffer my/git-repos-buffer-name
      (should (string-match-p "/tmp/already-known" (buffer-string)))
      (should (process-live-p my/git-repos--process))
      (delete-process my/git-repos--process))))

(ert-deftest gitfolders/lists-every-repo-the-script-prints ()
  (gr-with-stub-script "echo '== Linux =='\necho '/tmp/one'\necho '/tmp/two'\n"
    (with-current-buffer (gr--run-and-wait)
      (should (string-match-p "/tmp/one" (buffer-string)))
      (should (string-match-p "/tmp/two" (buffer-string)))
      (should (= 2 (length my/git-repos--list))))))

(ert-deftest gitfolders/no-scanning-message-or-raw-section-marker-is-left-behind ()
  (gr-with-stub-script "echo '== Linux =='\necho '/tmp/one'\n"
    (with-current-buffer (gr--run-and-wait)
      (should-not (string-match-p "^Scanning" (buffer-string)))
      (should-not (string-match-p "== " (buffer-string))))))

(ert-deftest gitfolders/output-split-across-two-process-filter-chunks-is-still-collected-whole ()
  ;; A process filter can be called with a chunk that ends mid-line; simulate that directly,
  ;; since a real (fast, small) script rarely if ever triggers it.
  (gr-with-stub-script "sleep 5\n"
    (my/find-git-repos)
    (with-current-buffer my/git-repos-buffer-name
      (my/git-repos--handle-output "== Linux ==\n/tmp/part")
      (should (equal my/git-repos--pending "/tmp/part"))
      (should-not (member "/tmp/part" my/git-repos--found))   ; not collected yet: no newline seen
      (my/git-repos--handle-output "ial-repo\n/tmp/whole\n")
      (should (equal my/git-repos--pending ""))
      (should (member "/tmp/partial-repo" my/git-repos--found))
      (should (member "/tmp/whole" my/git-repos--found))
      (delete-process my/git-repos--process))))

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

(ert-deftest gitfolders/d-opens-dired-and-t-opens-treemacs ()
  (should (eq (lookup-key my/git-repos-mode-map "d") 'my/git-repos-dired))
  (should (eq (lookup-key my/git-repos-mode-map "t") 'my/git-repos-treemacs)))

(ert-deftest gitfolders/the-header-has-a-clickable-rescan-button ()
  (gr-with-stub-script "echo '== Linux =='\necho '/tmp/one'\n"
    (with-current-buffer (gr--run-and-wait)
      (goto-char (point-min))
      (should (search-forward "[rescan]" nil t)))))

(ert-deftest gitfolders/refresh-stops-an-in-flight-scan-first ()
  (gr-with-stub-script "sleep 10\n"
    (my/find-git-repos)
    (let ((first-proc (with-current-buffer my/git-repos-buffer-name my/git-repos--process)))
      (should (process-live-p first-proc))
      (my/git-repos-refresh)
      (should-not (process-live-p first-proc)))))

(ert-deftest gitfolders/an-old-processs-late-sentinel-does-not-clobber-a-newer-scans-results ()
  ;; Simulate the race directly: an old process's sentinel firing after
  ;; `my/git-repos--process' has already moved on to a newer scan must be a no-op.
  (gr-with-stub-script "echo '== Linux =='\necho '/tmp/one'\n"
    (with-current-buffer (gr--run-and-wait)
      (should (equal my/git-repos--list '("/tmp/one")))
      (let ((stale-process my/git-repos--process))
        (unwind-protect
            (progn
              ;; pretend a newer scan has since taken over; the sentinel only ever
              ;; compares this with `eq', never calls it, so a plain symbol is enough
              (setq my/git-repos--process 'a-newer-scan-is-in-progress)
              (funcall (process-sentinel stale-process) stale-process "finished\n")
              (should (equal my/git-repos--list '("/tmp/one"))))
          ;; restore a real (if exited) process object, so this test's own cleanup
          ;; (which calls `process-live-p' on it) has something safe to look at
          (setq my/git-repos--process stale-process))))))

;;; Opening a result: RET/click (Magit), d (Dired), t (Treemacs)

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

(ert-deftest gitfolders/d-opens-dired-on-the-repository-at-point ()
  (gr-with-stub-script "echo '== Linux =='\necho '/tmp/some-repo'\n"
    (let (opened)
      (cl-letf (((symbol-function 'dired) (lambda (dir) (setq opened dir))))
        (with-current-buffer (gr--run-and-wait)
          (goto-char (point-min))
          (search-forward "/tmp/some-repo")
          (backward-char 2)
          (my/git-repos-dired)))
      (should (equal opened "/tmp/some-repo")))))

(ert-deftest gitfolders/d-off-a-repository-line-says-so-instead-of-erroring ()
  (gr-with-stub-script "echo '== Linux =='\necho '/tmp/some-repo'\n"
    (let (msg)
      (cl-letf (((symbol-function 'message) (lambda (fmt &rest a) (setq msg (apply #'format fmt a)))))
        (with-current-buffer (gr--run-and-wait)
          (goto-char (point-min))
          (my/git-repos-dired)))
      (should (string-match-p "cursor on a repository line" msg)))))

(ert-deftest gitfolders/t-reveals-the-repository-at-point-in-treemacs ()
  (gr-with-stub-script "echo '== Linux =='\necho '/tmp/some-repo'\n"
    (let (added-path)
      (cl-letf (((symbol-function 'locate-library) (lambda (lib) (and (equal lib "treemacs") "fake.el")))
                ((symbol-function 'require) (lambda (&rest _) t))
                ((symbol-function 'treemacs-canonical-path) #'identity)
                ((symbol-function 'treemacs--find-project-for-path) (lambda (_) nil))
                ((symbol-function 'treemacs-do-add-project-to-workspace) (lambda (path _name) (setq added-path path)))
                ((symbol-function 'treemacs-current-visibility) (lambda () 'none))
                ((symbol-function 'treemacs) (lambda ()))
                ((symbol-function 'treemacs-select-window) (lambda ()))
                ((symbol-function 'treemacs-goto-file-node) (lambda (_path))))
        (with-current-buffer (gr--run-and-wait)
          (goto-char (point-min))
          (search-forward "/tmp/some-repo")
          (backward-char 2)
          (my/git-repos-treemacs)))
      (should (equal added-path "/tmp/some-repo")))))

;;; The prefix argument, and how it feeds the merge

(ert-deftest gitfolders/a-prefix-argument-adds-windows-to-the-scan-command-and-is-a-full-scan ()
  (gr-with-stub-script "echo '== Linux =='\n"
    (let (seen-command)
      (cl-letf* ((real-make-process (symbol-function 'make-process))
                 ((symbol-function 'make-process)
                  (lambda (&rest args) (setq seen-command (plist-get args :command)) (apply real-make-process args))))
        (with-current-buffer (gr--run-and-wait t)
          (should (member "--windows" seen-command))
          (should my/git-repos--full-scan))))))

(ert-deftest gitfolders/no-prefix-argument-means-linux-only-and-not-a-full-scan ()
  (gr-with-stub-script "echo '== Linux =='\n"
    (let (seen-command)
      (cl-letf* ((real-make-process (symbol-function 'make-process))
                 ((symbol-function 'make-process)
                  (lambda (&rest args) (setq seen-command (plist-get args :command)) (apply real-make-process args))))
        (with-current-buffer (gr--run-and-wait nil)
          (should-not (member "--windows" seen-command))
          (should-not my/git-repos--full-scan))))))

;;; The real script, against the real disk (fast: the Linux side only, no --windows)

(ert-deftest gitfolders/the-real-script-finds-this-projects-own-repository ()
  (gr-need-unix)
  (let ((out (shell-command-to-string (shell-quote-argument (gr--real-script)))))
    (should (string-match-p (regexp-quote (directory-file-name (expand-file-name test-root))) out))))

;;; gitfolders.el ends here
