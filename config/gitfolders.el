;;; gitfolders.el --- every git repository on this computer, kept in an index  -*- lexical-binding: t; -*-

;; `C-c f p' shows every git repository on this computer, drawn instantly from a small
;; index kept in `my/git-repos-store-file' --- the same idea as the recent files/folders
;; list on the start screen (see startpage.el), just for repositories instead of files.
;; Every time you open it, a background scan brings the index up to date (repositories
;; that moved or were deleted drop out, new ones appear) without making you wait for that
;; scan to finish first.  Press `g', or click [rescan], to run it again by hand.
;;
;; On Linux/WSL the quick scan (`tools/find-repos.sh') only covers the Linux side, since
;; crossing into a mounted Windows drive is much slower (about 48s for one drive); any
;; Windows-drive repositories an earlier full scan (`C-u') found stay in the index in the
;; meantime, unchanged.  On Windows there is no such split: the bundled `fd.exe' covers
;; every local drive directly in a few seconds, so every scan there is already a full one.
;;
;; RET or a click on a repository opens Magit status there (Dired if Magit is not
;; installed); `d' opens Dired on it, `t' reveals it in Treemacs.  No package.
;;
;; See docs/SEARCH-OPTIONS.md.

(require 'button)

(defvar my/git-repos-buffer-name "*git repos*")
(defvar my/git-repos-script (expand-file-name "../tools/find-repos.sh" user-emacs-directory)
  "The Linux/WSL scanner this runs.  Only present in a git checkout of this project (a
normal `--init-directory=config' layout), not in the portable bundles; unused on Windows,
which instead runs `fd' directly (see `my/git-repos--windows-drives').")
(defvar my/git-repos-store-file (locate-user-emacs-file "git-repos.eld")
  "Where the index of found repositories is saved, so the list can be shown at once
without a fresh scan every time --- the same idea as `my/start-store-file' in startpage.el.")

;; Kept in step with WIN_SKIP_NAMES in tools/find-repos.sh: folder names that are never
;; real projects, so scanning them (`Windows', `Program Files') would only waste time.
(defvar my/git-repos-windows-excluded-names
  '("Windows" "Program Files" "Program Files (x86)" "ProgramData" "$RECYCLE.BIN" "System Volume Information"))

(defvar my/git-repos--list nil
  "The index: every repository last known about, sorted.  Not buffer-local: there is
only ever one such list, computer-wide, same as `my/start--folders'.")
(defvar my/git-repos--loaded nil)

(defvar-local my/git-repos--process nil "The in-flight background scan, if any.")
(defvar-local my/git-repos--pending ""
  "Output the process filter has read but not yet acted on, because it did not end in
a newline (a process filter can be called with a chunk that splits a line in the middle).")
(defvar-local my/git-repos--found nil "Paths the in-flight scan has collected so far.")
(defvar-local my/git-repos--full-scan nil "Whether the in-flight (or last finished) scan was a full one.")

;;; The index -------------------------------------------------------------------------

(defun my/git-repos--load ()
  "Read the saved index into `my/git-repos--list', once."
  (unless my/git-repos--loaded
    (setq my/git-repos--loaded t)
    (when (file-readable-p my/git-repos-store-file)
      (setq my/git-repos--list
            (seq-filter #'stringp
                        (ignore-errors
                          (with-temp-buffer
                            (insert-file-contents my/git-repos-store-file)
                            (read (current-buffer)))))))))

(defun my/git-repos--save ()
  "Write `my/git-repos--list' to disk."
  (ignore-errors
    (with-temp-file my/git-repos-store-file
      (prin1 my/git-repos--list (current-buffer)))))

(defun my/git-repos--windows-mount-p (path)
  (string-prefix-p "/mnt/" path))

(defun my/git-repos--merge (old fresh full-scan platform)
  "Combine OLD (the index before this scan) with FRESH (what this scan just found).
On Windows, or when FULL-SCAN is non-nil, FRESH is the whole truth and replaces OLD
outright.  Otherwise (the quick default scan on Linux/WSL, which only covers Linux),
FRESH replaces only the Linux entries: any Windows-drive entries an earlier full scan
found are kept as they were, since this scan never looked at them.  A pure function of
its arguments, like `my/git-repos--command', so it can be tested without touching the
real platform or running a real scan."
  (sort (delete-dups
         (if (or full-scan (eq platform 'windows-nt))
             (copy-sequence fresh)
           (append fresh (seq-filter #'my/git-repos--windows-mount-p old))))
        #'string<))

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

;;; Opening a repository --------------------------------------------------------------

(defun my/git-repos--open-magit (dir)
  (if (fboundp 'magit-status) (magit-status dir) (dired dir)))

(defun my/git-repos--open-treemacs (dir)
  (if (not (locate-library "treemacs"))
      (message "Treemacs is not installed.  Run ./build.sh packages")
    (require 'treemacs)
    (let ((path (treemacs-canonical-path dir)))
      (unless (treemacs--find-project-for-path path)
        (treemacs-do-add-project-to-workspace path (file-name-nondirectory (directory-file-name dir))))
      (unless (eq (treemacs-current-visibility) 'visible) (treemacs))
      (treemacs-select-window)
      (treemacs-goto-file-node path))))

(defun my/git-repos--open (button)
  (my/git-repos--open-magit (button-get button 'my-repo-dir)))

(defun my/git-repos--dir-at-point ()
  (when-let* ((b (button-at (point)))) (button-get b 'my-repo-dir)))

(defun my/git-repos-dired ()
  "Open the repository at point in Dired."
  (interactive)
  (if-let* ((dir (my/git-repos--dir-at-point))) (dired dir)
    (message "Put the cursor on a repository line first")))

(defun my/git-repos-treemacs ()
  "Reveal the repository at point in Treemacs."
  (interactive)
  (if-let* ((dir (my/git-repos--dir-at-point))) (my/git-repos--open-treemacs dir)
    (message "Put the cursor on a repository line first")))

;;; The buffer --------------------------------------------------------------------------

(defvar my/git-repos-mode-map
  (let ((m (make-sparse-keymap)))
    (set-keymap-parent m special-mode-map)
    (define-key m "g" #'my/git-repos-refresh)
    (define-key m "d" #'my/git-repos-dired)
    (define-key m "t" #'my/git-repos-treemacs)
    m))

(define-derived-mode my/git-repos-mode special-mode "Git-Repos"
  "A list of every git repository found on this computer.  See `my/find-git-repos'.")

(defun my/git-repos--insert-header ()
  (insert (propertize "Git repositories on this computer\n\n" 'face '(:height 1.2 :weight bold)))
  (insert "  RET/click open Magit   d Dired   t Treemacs   g rescan"
          (if (eq system-type 'windows-nt) "" "   C-u g also scans the Windows drives (slow)")
          "   q close\n  ")
  (insert-text-button "[rescan]" 'action (lambda (_) (my/git-repos-refresh)) 'follow-link t
                      'help-echo "Scan again now")
  (when (process-live-p my/git-repos--process)
    (insert "  " (propertize "updating..." 'face 'shadow)))
  (insert "\n\n"))

(defun my/git-repos--insert-entries (paths)
  (dolist (dir paths)
    (insert "  ")
    (insert-text-button dir 'action #'my/git-repos--open 'follow-link t 'my-repo-dir dir 'help-echo dir)
    (insert "\n")))

(defun my/git-repos--insert-list ()
  (cond
   ((and (null my/git-repos--list) (process-live-p my/git-repos--process))
    (insert "  " (propertize "scanning for the first time (a few seconds)..." 'face 'shadow) "\n"))
   ((null my/git-repos--list)
    (insert "  " (propertize "no git repositories found" 'face 'shadow) "\n"))
   (t (insert (format "  %d repositor%s\n\n" (length my/git-repos--list)
                      (if (= (length my/git-repos--list) 1) "y" "ies")))
      (my/git-repos--insert-entries my/git-repos--list))))

(defun my/git-repos--redraw ()
  "Redraw the buffer from `my/git-repos--list', keeping the cursor on the same line."
  (let ((inhibit-read-only t) (line (line-number-at-pos)))
    (erase-buffer)
    (my/git-repos--insert-header)
    (my/git-repos--insert-list)
    (goto-char (point-min))
    (forward-line (max 0 (1- line)))
    (unless (button-at (point)) (ignore-errors (forward-button 1)))))

;;; Scanning ----------------------------------------------------------------------------

(defun my/git-repos--parse-line (line)
  "The repository path in LINE, or nil if LINE is a \"== section ==\" marker (from the
Linux script), its scanning-progress message, or blank.  The raw path (from either the
script or, on Windows, `fd' directly) still ends in `.git' or `.git\\'; strip that here."
  (cond
   ((string-prefix-p "== " line) nil)
   ((string-prefix-p "Scanning" line) nil)
   ((string-empty-p line) nil)
   (t (if (string-match "[/\\]\\.git[/\\]?\\'" line) (substring line 0 (match-beginning 0)) line))))

(defun my/git-repos--handle-output (chunk)
  "Collect complete lines of CHUNK into `my/git-repos--found'; a trailing partial line
is kept in `my/git-repos--pending' for the next call, or for `my/git-repos--flush'."
  (let ((text (concat my/git-repos--pending chunk)))
    (while (string-match "\n" text)
      (when-let* ((path (my/git-repos--parse-line (substring text 0 (match-beginning 0)))))
        (push path my/git-repos--found))
      (setq text (substring text (match-end 0))))
    (setq my/git-repos--pending text)))

(defun my/git-repos--flush ()
  "Collect any final partial line left over when the process has finished."
  (unless (string-empty-p my/git-repos--pending)
    (when-let* ((path (my/git-repos--parse-line my/git-repos--pending)))
      (push path my/git-repos--found))
    (setq my/git-repos--pending "")))

(defun my/git-repos-refresh (&optional windows)
  "Rescan now, in the background, and update the index when it finishes; the buffer
shows the index as it stands (last scan's results) the whole time.  On Linux/WSL a
prefix argument also scans every Windows drive under /mnt (much slower); on Windows
every local drive is already included, so the prefix argument has no extra effect."
  (interactive "P")
  (my/git-repos--load)
  (let ((buf (get-buffer-create my/git-repos-buffer-name))
        (command (my/git-repos--command system-type windows my/git-repos-script
                                        (executable-find "fd") (my/git-repos--windows-drives))))
    (with-current-buffer buf
      (unless (derived-mode-p 'my/git-repos-mode) (my/git-repos-mode))
      (when (process-live-p my/git-repos--process) (delete-process my/git-repos--process))
      (setq my/git-repos--pending "" my/git-repos--found nil
            my/git-repos--full-scan (or windows (eq system-type 'windows-nt)))
      (my/git-repos--redraw)
      (setq my/git-repos--process
            (make-process
             :name "git-repos" :buffer buf :noquery t :command command
             :filter (lambda (p out)
                       (with-current-buffer (process-buffer p) (my/git-repos--handle-output out)))
             :sentinel (lambda (p event)
                         ;; the `eq' check matters: if a later scan has already replaced
                         ;; `my/git-repos--process' (see the `delete-process' above), this is
                         ;; that OLD process's sentinel firing late, and must not clobber the
                         ;; newer scan's in-progress or already-finished results.
                         (when (and (memq (process-status p) '(exit signal))
                                    (eq p (buffer-local-value 'my/git-repos--process (process-buffer p))))
                           (with-current-buffer (process-buffer p)
                             (my/git-repos--flush)
                             (setq my/git-repos--list
                                   (my/git-repos--merge my/git-repos--list my/git-repos--found
                                                        my/git-repos--full-scan system-type))
                             (my/git-repos--save)
                             (my/git-repos--redraw)
                             (message "Found %d git repositor%s%s" (length my/git-repos--list)
                                      (if (= (length my/git-repos--list) 1) "y" "ies")
                                      (if (string-prefix-p "finished" event) "" " (scan stopped early)")))))))
      buf)))

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
  "Show every git repository on this computer, drawn at once from the index kept in
`my/git-repos-store-file', then brought up to date by a background scan --- the same
idea as the recent files/folders list on the start screen, just for repositories.
On Linux/WSL, a prefix argument also scans every mounted Windows drive (much slower).
On Windows every local drive is already included; the prefix argument has no extra effect."
  (interactive "P")
  (if-let* ((reason (my/git-repos--unavailable-reason system-type my/git-repos-script (executable-find "fd"))))
      (message "%s" reason)
    (switch-to-buffer (my/git-repos-refresh windows))))

(provide 'gitfolders)
;;; gitfolders.el ends here
