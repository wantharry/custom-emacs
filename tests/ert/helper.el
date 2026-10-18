;;; helper.el --- shared helpers for the ERT test files  -*- lexical-binding: t; -*-
;; Loaded by tests/run-all.sh before every test file.

(require 'ert)
(require 'cl-lib)
(require 'subr-x)

(defvar test-root (or (getenv "ROOT") default-directory)
  "Repository root.")
(defvar test-emacs (or (getenv "EMACS_BIN") (expand-file-name invocation-name invocation-directory))
  "The Emacs binary under test.")

;; WHAT/WHY: when `tests/run-all.sh' itself runs as the `.githooks/pre-commit' hook, git
;; has already set these in the environment for the REAL repo's commit in progress ---
;; inherited here, they point every later `git' call (`test-git' below, Magit's own
;; internal git calls, fastfind's own repo-finding, ...) at the real repo's `.git'
;; instead of a fresh test fixture's own, breaking its isolation. Confirmed directly:
;; `fastfind'/`magit'/`vc-diff'/`project-eglot'/`java-navigation'/`diff-hl' all failed
;; ONLY when run via the hook, never standalone. Unset here, once, for the whole test
;; process (not just inside `test-git''s own dynamic scope) since some fixtures (`mg-
;; with-repo' in `tests/ert/magit.el') call `git' directly, and the functionality under
;; test itself (Magit, VC, project.el) shells out to `git' well outside any such scope.
(dolist (v '("GIT_DIR" "GIT_WORK_TREE" "GIT_INDEX_FILE" "GIT_PREFIX" "GIT_COMMON_DIR"))
  (setenv v nil))

(defmacro test-with-temp-dir (var &rest body)
  "Bind VAR to a fresh temporary directory (with trailing slash) around BODY.

`file-truename' here is not cosmetic --- found the hard way, the first real run
of this suite on real Windows: `temporary-file-directory' there can itself be
the Windows 8.3 short form (e.g. `C:/Users/RUNNER~1/AppData/Local/Temp', set
that way in this account's own environment), while features under test
(Dired, VC, treemacs, ranger, ...) normalize paths they hand back through
`file-truename' internally and get the long form (`C:/Users/runneradmin/...')
back instead. Comparing those two forms directly then fails even though both
names refer to the exact same directory --- truenaming VAR itself here, once,
fixes every test that trusts it without each having to do this individually."
  (declare (indent 1))
  `(let ((,var (file-name-as-directory (file-truename (make-temp-file "emacs-test-" t)))))
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
       ;; `buffer-live-p' guards against BODY itself having already killed the
       ;; buffer (a real case: a test exercising a command that kills its own
       ;; buffer) --- calling `kill-buffer' again here would otherwise error,
       ;; masking whatever BODY's own `should' actually found.
       (when (buffer-live-p test--buf) (kill-buffer test--buf)))))

(defun test-startup-budget ()
  "Seconds a `sp--startup-seconds'-style startup-timing test is allowed, before
it counts as a real regression. 0.5s normally; a looser 2.0s under CI (`CI' is
the de facto standard env var essentially every CI provider, including GitHub
Actions, sets) --- found the hard way, running this suite for real on GitHub
Actions for the first time: shared/throttled CI runners are routinely slower
than a dedicated dev machine, enough to trip the strict local threshold on
totally unrelated features with no real regression, which would otherwise
make this whole class of guard just noise to ignore rather than a signal to
trust. Local development keeps the tight 0.5s budget, where it is still a
real, meaningful guard (confirmed directly: a plain, unloaded startup here
measures a comfortable ~0.3s). Windows CI gets a further-widened 3.0s: the
real Windows runner measured 2.1-2.3s on several of these tests even with the
2.0s CI budget already applied, consistently (process spawn and antivirus
filesystem scanning are both genuinely slower there, not a regression)."
  (cond ((and (getenv "CI") (eq system-type 'windows-nt)) 3.0)
        ((getenv "CI") 2.0)
        (t 0.5)))

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
  ;; WHAT: is this a pruned install?  WHY: `tetris' (a game, `play/'), not `org' --- `org'
  ;; used to be pruned and was a fine litmus test for that, but it no longer is (see
  ;; prune.list's own header and docs/PRUNING.md); checking it here would now silently
  ;; skip every pruning test, always, even on a genuinely pruned install, since `org'
  ;; would never be missing to detect.  Caught for real while making that change, not
  ;; anticipated in advance.
  (when (locate-library "tetris")
    (ert-skip "not a pruned install")))

(defun test-git (dir &rest args)
  "Run git ARGS in DIR with a fixed identity.  Return the exit status."
  (let ((default-directory dir)
        ;; A fixed author/committer identity so a commit never fails for lack of one
        ;; on a machine where git has never been configured; the global/system config
        ;; files are pointed at /dev/null so nothing in the real user's own gitconfig
        ;; (a commit template, `commit.gpgsign', color settings that could leak ANSI
        ;; codes into output a test then parses, ...) can change a test's behavior.
        (process-environment
         (append '("GIT_AUTHOR_NAME=t" "GIT_AUTHOR_EMAIL=t@t" "GIT_COMMITTER_NAME=t"
                   "GIT_COMMITTER_EMAIL=t@t" "GIT_CONFIG_GLOBAL=/dev/null"
                   "GIT_CONFIG_SYSTEM=/dev/null")
                 process-environment)))
    (apply #'call-process "git" nil nil nil args)))

;;; helper.el ends here
