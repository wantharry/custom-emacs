;;; gitfolders.el --- find every git repository on this computer  -*- lexical-binding: t; -*-

;; `C-c f p' lists every git repository on the Linux side (a couple of seconds); `C-u C-c f p'
;; also scans every mounted Windows drive (much slower: crossing into NTFS took about 48s for
;; one drive here).  Runs `tools/find-repos.sh' as a background process, so Emacs is never
;; blocked while it searches.  Click a result, or press RET on it, to open Magit there (or
;; Dired, if Magit is not installed).  No package.
;;
;; See docs/SEARCH-OPTIONS.md.

(require 'button)

(defvar my/git-repos-buffer-name "*git repos*")
(defvar my/git-repos-script (expand-file-name "../tools/find-repos.sh" user-emacs-directory)
  "The script this runs.  Only present in a git checkout of this project (a normal
`--init-directory=config' layout), not in the portable bundles, and it needs a
Unix-like shell and `/mnt'-style mounts, so this feature is Linux/WSL only for now.")

(defvar-local my/git-repos--windows nil
  "Non-nil if the search shown in this buffer included the Windows drives.")
(defvar-local my/git-repos--process nil)
(defvar-local my/git-repos--pending ""
  "Output the process filter has read but not yet processed, because it did not
end in a newline (a process filter can be called with a chunk that splits a
line in the middle).")
(defvar-local my/git-repos--count 0)

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
  (insert (if windows " (Linux and every Windows drive under /mnt; this is the slow scan).\n"
            " (Linux only; C-u g also scans the Windows drives, which is much slower).\n"))
  (insert "\n"))

(defun my/git-repos--insert-line (line)
  "Insert one complete LINE of the script's output: a section marker or a repo path."
  (cond
   ((string-prefix-p "== " line)
    (insert "\n" (propertize (string-trim (substring line 3) nil " =*") 'face 'bold) "\n"))
   ((string-empty-p line))
   (t (setq my/git-repos--count (1+ my/git-repos--count))
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
  "Rebuild the list.  With a prefix argument, also scan every Windows drive under /mnt."
  (interactive "P")
  (let ((buf (get-buffer-create my/git-repos-buffer-name)))
    (with-current-buffer buf
      (when (process-live-p my/git-repos--process) (delete-process my/git-repos--process))
      (unless (derived-mode-p 'my/git-repos-mode) (my/git-repos-mode))
      (let ((inhibit-read-only t)) (erase-buffer))
      (setq my/git-repos--windows windows my/git-repos--pending "" my/git-repos--count 0)
      (let ((inhibit-read-only t))
        (my/git-repos--insert-header windows)
        (insert (if windows "Scanning Linux, then every Windows drive (this can take about a minute)...\n"
                  "Scanning...\n")))
      (goto-char (point-min))
      ;; :buffer is only so the filter/sentinel below can find their way back to it with
      ;; `process-buffer'; a custom :filter means Emacs never auto-inserts output there itself.
      (setq my/git-repos--process
            (make-process
             :name "git-repos" :buffer buf :noquery t
             :command (append (list my/git-repos-script) (and windows '("--windows")))
             :filter (lambda (p out) (my/git-repos--handle-output (process-buffer p) out))
             :sentinel (lambda (p event)
                         (when (memq (process-status p) '(exit signal))
                           (my/git-repos--flush (process-buffer p))
                           (with-current-buffer (process-buffer p)
                             (message "Found %d git repositor%s%s" my/git-repos--count
                                      (if (= my/git-repos--count 1) "y" "ies")
                                      (if (string-prefix-p "finished" event) "" " (search stopped early)"))))))))
    buf))

;;;###autoload
(defun my/find-git-repos (&optional windows)
  "Show every git repository on this computer, in a new buffer.
With a prefix argument, also search every mounted Windows drive (much slower)."
  (interactive "P")
  (cond
   ((eq system-type 'windows-nt)
    (message "Finding git repositories is Linux/WSL only for now, not the Windows bundle."))
   ((not (file-executable-p my/git-repos-script))
    (message "%s is missing (only in a git checkout of this project, not the portable bundles)."
             my/git-repos-script))
   (t (switch-to-buffer (my/git-repos-refresh windows)))))

(provide 'gitfolders)
;;; gitfolders.el ends here
