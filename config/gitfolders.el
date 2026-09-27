;;; gitfolders.el --- find every git repository on this computer  -*- lexical-binding: t; -*-

;; `C-c f p' lists every git repository on this computer:
;;   - Linux/WSL: runs `tools/find-repos.sh' (a couple of seconds); `C-u' also scans every
;;     Windows drive under /mnt (much slower: crossing into NTFS took about 48s for one drive).
;;   - Windows: runs the bundled `fd.exe' directly across every local drive letter (no shell
;;     script needed there); `C-u' has nothing extra to add, since there is no separate side
;;     to reach the way WSL reaches into Windows.
;; Either way this runs as a background process, so Emacs is never blocked while it searches.
;; Click a result, or press RET on it, to open Magit there (or Dired, if Magit is not
;; installed).  No package.
;;
;; See docs/SEARCH-OPTIONS.md.

(require 'button)

(defvar my/git-repos-buffer-name "*git repos*")
(defvar my/git-repos-script (expand-file-name "../tools/find-repos.sh" user-emacs-directory)
  "The Linux/WSL script this runs.  Only present in a git checkout of this project (a
normal `--init-directory=config' layout), not in the portable bundles; unused on Windows,
which instead runs `fd' directly (see `my/git-repos--windows-drives').")

;; Kept in step with WIN_SKIP_NAMES in tools/find-repos.sh: folder names that are never
;; real projects, so scanning them (`Windows', `Program Files') would only waste time.
(defvar my/git-repos-windows-excluded-names
  '("Windows" "Program Files" "Program Files (x86)" "ProgramData" "$RECYCLE.BIN" "System Volume Information"))

(defvar-local my/git-repos--windows nil
  "Non-nil if the search shown in this buffer included the Windows drives (Linux/WSL only;
meaningless on Windows itself, where every local drive is always included).")
(defvar-local my/git-repos--process nil)
(defvar-local my/git-repos--pending ""
  "Output the process filter has read but not yet processed, because it did not
end in a newline (a process filter can be called with a chunk that splits a
line in the middle).")
(defvar-local my/git-repos--count 0)

(defun my/git-repos--windows-drives ()
  "Every local drive letter that exists, as (\"C:/\" \"D:/\" ...).  Windows only."
  (seq-filter #'file-directory-p (mapcar (lambda (c) (format "%c:/" c)) (number-sequence ?A ?Z))))

(defun my/git-repos--command (platform windows script fd-exe drives)
  "The command line to run, given PLATFORM (`system-type'), whether WINDOWS (the Linux
prefix-argument) was requested, the Linux SCRIPT's path, and (Windows only) the FD-EXE
binary and the DRIVES to search.  A pure function of its arguments (none of them read
from a global here), so it can be tested without touching the real `system-type' or
running on a real Windows machine."
  (if (eq platform 'windows-nt)
      (when (and fd-exe drives)
        (append (list fd-exe "-H" "-t" "d" "-I" "-u" "^\\.git$") drives
                (mapcan (lambda (n) (list "--exclude" n)) my/git-repos-windows-excluded-names)))
    (append (list script) (and windows '("--windows")))))

(defun my/git-repos--open (button)
  (let ((dir (button-get button 'my-repo-dir)))
    (if (fboundp 'magit-status) (magit-status dir) (dired dir))))

(defvar my/git-repos-mode-map
  (let ((m (make-sparse-keymap)))
    (set-keymap-parent m special-mode-map)
    (define-key m "g" #'my/git-repos-refresh)
    m))

(define-derived-mode my/git-repos-mode special-mode "Git-Repos"
  "A list of every git repository found on this computer.  See `my/find-git-repos'.")

(defun my/git-repos--insert-header (windows)
  (insert (propertize "Git repositories on this computer\n\n" 'face '(:height 1.2 :weight bold)))
  (insert "  RET or click opens Magit status there (Dired if Magit is not installed).\n")
  (insert "  g refreshes")
  (insert
   (cond
    ((eq system-type 'windows-nt) " (every local drive is always included).\n")
    (windows " (Linux and every Windows drive under /mnt; this is the slow scan).\n")
    (t " (Linux only; C-u g also scans the Windows drives, which is much slower).\n")))
  (insert "\n"))

(defun my/git-repos--insert-line (line)
  "Insert one complete LINE of output: a \"== section ==\" marker (from the Linux script), or
a repo path (from either the script or, on Windows, `fd' directly, whose raw output still
ends in `.git' or `.git\\'; strip that here so both origins render the same way)."
  (cond
   ((string-prefix-p "== " line)
    (insert "\n" (propertize (string-trim (substring line 3) nil " =*") 'face 'bold) "\n"))
   ((string-empty-p line))
   (t (when (string-match "[/\\]\\.git[/\\]?\\'" line) (setq line (substring line 0 (match-beginning 0))))
      (setq my/git-repos--count (1+ my/git-repos--count))
      (insert "  ")
      (insert-text-button line 'action #'my/git-repos--open 'follow-link t 'my-repo-dir line)
      (insert "\n"))))

(defun my/git-repos--handle-output (buf chunk)
  "Process CHUNK of the script's output, a piece of a line at a time.  A process
filter can be called with output that splits a line in two, so only complete
lines (ending in a newline) are acted on; a trailing partial line is kept in
`my/git-repos--pending' for the next call, or for `my/git-repos--flush'."
  (with-current-buffer buf
    (let ((inhibit-read-only t) (text (concat my/git-repos--pending chunk)))
      (goto-char (point-max))
      (save-excursion
        (goto-char (point-min))
        (when (re-search-forward "^Scanning.*\n" nil t) (replace-match "")))
      (goto-char (point-max))
      (while (string-match "\n" text)
        (my/git-repos--insert-line (substring text 0 (match-beginning 0)))
        (setq text (substring text (match-end 0))))
      (setq my/git-repos--pending text))))

(defun my/git-repos--flush (buf)
  "Insert any final partial line left over when the process has finished."
  (with-current-buffer buf
    (unless (string-empty-p my/git-repos--pending)
      (let ((inhibit-read-only t)) (goto-char (point-max)) (my/git-repos--insert-line my/git-repos--pending))
      (setq my/git-repos--pending ""))))

(defun my/git-repos-refresh (&optional windows)
  "Rebuild the list.  On Linux/WSL, with a prefix argument, also scan every Windows drive
under /mnt.  On Windows the prefix argument does nothing: every local drive is always
included, since there is no separate side to reach the way WSL reaches into Windows."
  (interactive "P")
  (let ((buf (get-buffer-create my/git-repos-buffer-name))
        (command (my/git-repos--command system-type windows my/git-repos-script
                                        (executable-find "fd") (my/git-repos--windows-drives))))
    (with-current-buffer buf
      (when (process-live-p my/git-repos--process) (delete-process my/git-repos--process))
      (unless (derived-mode-p 'my/git-repos-mode) (my/git-repos-mode))
      (let ((inhibit-read-only t)) (erase-buffer))
      (setq my/git-repos--windows windows my/git-repos--pending "" my/git-repos--count 0)
      (let ((inhibit-read-only t))
        (my/git-repos--insert-header windows)
        (insert (cond ((eq system-type 'windows-nt) "Scanning every local drive...\n")
                      (windows "Scanning Linux, then every Windows drive (this can take about a minute)...\n")
                      (t "Scanning...\n"))))
      (goto-char (point-min))
      ;; :buffer is only so the filter/sentinel below can find their way back to it with
      ;; `process-buffer'; a custom :filter means Emacs never auto-inserts output there itself.
      (setq my/git-repos--process
            (make-process
             :name "git-repos" :buffer buf :noquery t :command command
             :filter (lambda (p out) (my/git-repos--handle-output (process-buffer p) out))
             :sentinel (lambda (p event)
                         (when (memq (process-status p) '(exit signal))
                           (my/git-repos--flush (process-buffer p))
                           (with-current-buffer (process-buffer p)
                             (message "Found %d git repositor%s%s" my/git-repos--count
                                      (if (= my/git-repos--count 1) "y" "ies")
                                      (if (string-prefix-p "finished" event) "" " (search stopped early)"))))))))
    buf))

(defun my/git-repos--unavailable-reason (platform script fd-exe)
  "Why `my/find-git-repos' cannot run right now, given PLATFORM (`system-type'), the
Linux SCRIPT's path and (Windows only) the FD-EXE binary found (or nil) --- explicit
parameters, like `my/git-repos--command', so this can be tested safely on any platform.
Returns nil if it can run."
  (if (eq platform 'windows-nt)
      (unless fd-exe
        "fd.exe was not found on PATH (only bundled in the portable Windows zip; see docs/DISTRIBUTION.md)")
    (unless (file-executable-p script)
      (format "%s is missing (only in a git checkout of this project, not the portable bundles)."
              script))))

;;;###autoload
(defun my/find-git-repos (&optional windows)
  "Show every git repository on this computer, in a new buffer.
On Linux/WSL, a prefix argument also searches every mounted Windows drive (much slower).
On Windows every local drive is always included; the prefix argument has no extra effect."
  (interactive "P")
  (if-let* ((reason (my/git-repos--unavailable-reason system-type my/git-repos-script (executable-find "fd"))))
      (message "%s" reason)
    (switch-to-buffer (my/git-repos-refresh windows))))

(provide 'gitfolders)
;;; gitfolders.el ends here
