;;; startpage.el --- start screen: recent files, folders and projects  -*- lexical-binding: t; -*-

;; The screen Emacs opens on when started without a file, and `C-c h' from anywhere.
;; It lists the last few files, folders and projects you worked in, each one a link
;; (RET, or a click), with a "+ N more" link that expands the list in place.
;; Files come from `recentf'.  Folders and projects are remembered here, in
;; `my/start-store-file', as you open files and Dired buffers.  No package is used.

(require 'recentf)
(require 'button)
(require 'text-property-search)

(defvar my/start-count 5 "How many entries each section shows when collapsed.")
(defvar my/start-expanded-count 25 "How many entries each section shows when expanded.")
(defvar my/start-keep 60 "How many folders and projects are remembered.")
(defvar my/start-ignore
  '("\\`/tmp/" "\\`/var/tmp/" "/\\.git/" "/COMMIT_EDITMSG\\'" "\\`/proc/" "\\`/sys/"
    "/elpa/" "/eln-cache/" "/backups/" "/auto-save-list/" "\\`/usr/share/emacs/")
  "Paths matching any of these regexps are never remembered or shown.")
(defvar my/start-project-markers '(".git" ".hg" "pom.xml" "build.gradle" "Cargo.toml" "package.json")
  "A folder holding any of these counts as a project root.")
(defvar my/start-store-file (locate-user-emacs-file "recents.eld")
  "Where the folder and project history is saved.")

(defvar my/start--folders nil "Recent folders, newest first.")
(defvar my/start--projects nil "Recent project roots, newest first.")
(defvar my/start--loaded nil)
(defvar my/start--dirty nil)
(defvar my/start--expanded nil "Sections currently expanded: a list of `files', `folders', `projects'.")

;;; Remembering ---------------------------------------------------------------

(defun my/start--ignored-p (path)
  (let ((case-fold-search nil))
    (seq-some (lambda (re) (string-match-p re path)) my/start-ignore)))

(defun my/start--load ()
  (unless my/start--loaded
    (setq my/start--loaded t)
    (when (file-readable-p my/start-store-file)
      (let ((data (ignore-errors
                    (with-temp-buffer (insert-file-contents my/start-store-file)
                                      (read (current-buffer))))))
        (setq my/start--folders (seq-filter #'stringp (alist-get 'folders data))
              my/start--projects (seq-filter #'stringp (alist-get 'projects data)))))))

(defun my/start-save ()
  "Write the folder and project history to disk."
  (when (and my/start--loaded my/start--dirty)
    (setq my/start--dirty nil)
    (ignore-errors
      (with-temp-file my/start-store-file
        (prin1 `((folders . ,my/start--folders) (projects . ,my/start--projects))
               (current-buffer))))))

(defun my/start--push (place dir)
  "Move DIR to the front of the list stored in the symbol PLACE."
  (let ((l (cons dir (delete dir (copy-sequence (symbol-value place))))))
    (set place (seq-take l my/start-keep))
    (setq my/start--dirty t)))

(defun my/start--project-root (dir)
  (let (found)
    (dolist (m my/start-project-markers)
      (let ((r (locate-dominating-file dir m)))
        ;; the nearest marker wins, and the home folder is never a project
        (when (and r (or (null found) (> (length r) (length found))))
          (setq found r))))
    (and found (not (equal (expand-file-name found) (expand-file-name "~/")))
         (file-name-as-directory (expand-file-name found)))))

(defun my/start-remember (dir)
  "Record DIR as a recent folder, and its project root as a recent project."
  (when (and (stringp dir) (not (file-remote-p dir)) (file-directory-p dir))
    (my/start--load)
    (let ((dir (file-name-as-directory (expand-file-name dir))))
      (unless (my/start--ignored-p dir)
        (my/start--push 'my/start--folders dir)
        (when-let ((root (my/start--project-root dir)))
          (unless (my/start--ignored-p root)
            (my/start--push 'my/start--projects root)))))))

(defun my/start--on-find-file ()
  (when buffer-file-name
    (my/start-remember (file-name-directory buffer-file-name))))

(defun my/start--on-dired ()
  (my/start-remember default-directory))

(add-hook 'find-file-hook #'my/start--on-find-file)
(add-hook 'dired-mode-hook #'my/start--on-dired)
(add-hook 'kill-emacs-hook #'my/start-save)
(run-with-idle-timer 30 t #'my/start-save)

;;; Collecting ----------------------------------------------------------------

(defun my/start--live (paths n pred)
  "The first N of PATHS that PRED accepts and that are not ignored."
  (let (out (k 0))
    (while (and paths (< k n))
      (let ((p (pop paths)))
        (when (and (not (my/start--ignored-p p)) (funcall pred p))
          (push p out) (setq k (1+ k)))))
    (nreverse out)))

(defun my/start--all (kind)
  "All remembered paths of KIND (`files', `folders' or `projects'), newest first."
  (my/start--load)
  (pcase kind
    ('files (seq-filter (lambda (f) (not (string-suffix-p "/" f)))
                        (mapcar #'expand-file-name (seq-filter #'stringp (bound-and-true-p recentf-list)))))
    ('folders (or my/start--folders (my/start--derive #'file-name-directory)))
    ('projects (or my/start--projects
                   (delete-dups (delq nil (mapcar #'my/start--project-root (my/start--derive #'identity))))))))

(defun my/start--derive (fn)
  "Folders derived from `recentf-list', for a first run with no history yet."
  (delete-dups (delq nil (mapcar (lambda (f) (and (stringp f) (funcall fn f)
                                                  (file-name-as-directory
                                                   (expand-file-name (funcall fn f)))))
                                 (bound-and-true-p recentf-list)))))

(defun my/start--entries (kind n)
  (my/start--live (my/start--all kind) n
                  (if (eq kind 'files) #'file-exists-p #'file-directory-p)))

;;; Drawing -------------------------------------------------------------------

(defface my/start-heading '((t :inherit font-lock-keyword-face :weight bold)) "Section headings.")
(defface my/start-dir '((t :inherit shadow)) "The folder part of an entry.")

(defvar my/start-mode-map
  (let ((m (make-sparse-keymap)))
    (set-keymap-parent m special-mode-map)
    (define-key m (kbd "RET") #'push-button)
    (define-key m (kbd "TAB") #'forward-button)
    (define-key m (kbd "<backtab>") #'backward-button)
    (define-key m "n" #'forward-button)
    (define-key m "p" #'backward-button)
    (define-key m "g" #'my/start-refresh)
    (define-key m "f" #'my/start-find-in-project)
    (dotimes (i 5) (define-key m (number-to-string (1+ i)) #'my/start-open-nth-file))
    m))

(define-derived-mode my/start-mode special-mode "Start"
  "The start screen: recent files, folders and projects."
  (setq-local cursor-type nil)
  (display-line-numbers-mode -1)
  (setq-local truncate-lines t))

(defun my/start--open (button)
  (let ((path (button-get button 'my-path)) (kind (button-get button 'my-kind)))
    (pcase kind
      ('files (find-file path))
      (_ (dired path)))))

(defun my/start--toggle (button)
  (let ((kind (button-get button 'my-kind)))
    (setq my/start--expanded (if (memq kind my/start--expanded)
                                 (delq kind my/start--expanded)
                               (cons kind my/start--expanded)))
    (my/start-refresh)
    (goto-char (point-min))
    (when-let ((m (text-property-search-forward 'my-toggle kind t)))
      (goto-char (prop-match-beginning m)))))

(defun my/start--insert-section (kind title)
  (let* ((expanded (memq kind my/start--expanded))
         (total (length (my/start--all kind)))
         (shown (my/start--entries kind (if expanded my/start-expanded-count my/start-count)))
         (i 0))
    (insert "  " (propertize title 'face 'my/start-heading) "\n")
    (if (null shown)
        (insert "    " (propertize "nothing yet: open a file or folder and it shows up here" 'face 'my/start-dir) "\n")
      (dolist (p shown)
        (setq i (1+ i))
        (let* ((name (if (eq kind 'files) (file-name-nondirectory p)
                       (file-name-nondirectory (directory-file-name p))))
               (dir (abbreviate-file-name (file-name-directory (directory-file-name p)))))
          (insert "   " (if (and (eq kind 'files) (<= i 5)) (propertize (number-to-string i) 'face 'my/start-dir) " ") " ")
          (insert-text-button (if (string-empty-p name) p name)
                              'action #'my/start--open 'follow-link t 'my-path p 'my-kind kind
                              'help-echo p)
          (insert "  " (propertize dir 'face 'my/start-dir) "\n"))))
    (when (or expanded (> total my/start-count))
      (insert "     ")
      (insert-text-button
       (if expanded "[- show fewer]"
         (format "[+ %d more]" (- (min total my/start-expanded-count) my/start-count)))
       'action #'my/start--toggle 'follow-link t 'my-kind kind 'my-toggle kind
       'help-echo "expand or collapse this list")
      (insert "\n"))
    (insert "\n")))

(defun my/start-refresh ()
  "Redraw the start screen."
  (interactive)
  (let ((inhibit-read-only t) (line (line-number-at-pos)))
    (erase-buffer)
    (insert "\n  " (propertize "Recent work" 'face '(:height 1.3 :weight bold)) "\n\n")
    (my/start--insert-section 'files "Files")
    (my/start--insert-section 'folders "Folders")
    (my/start--insert-section 'projects "Projects")
    (dolist (l '(("RET" "open" "TAB" "next link" "g" "refresh" "q" "close")
                 ("1-5" "open that file" "f" "find a file in this project")
                 ("C-c h" "back to this screen" "C-c f f" "find any file")))
      (insert "  ")
      (while l (insert (propertize (pop l) 'face 'bold) " " (pop l) (if l "   " "")))
      (insert "\n"))
    (goto-char (point-min))
    (forward-line (max 0 (1- line)))
    (unless (button-at (point)) (ignore-errors (forward-button 1)))))

(defun my/start-open-nth-file ()
  "Open the file whose number (1 to 5) was typed."
  (interactive)
  (let* ((n (- (aref (this-command-keys) 0) ?0))
         (f (nth (1- n) (my/start--entries 'files my/start-count))))
    (if f (find-file f) (message "No file number %d yet" n))))

(defun my/start-find-in-project ()
  "On a project line, find a file in that project with the fast finder."
  (interactive)
  (let ((b (button-at (point))))
    (if (and b (memq (button-get b 'my-kind) '(projects folders)))
        (let ((default-directory (button-get b 'my-path))) (call-interactively #'my/ff-find-file))
      (message "Put the cursor on a project or folder line first"))))

;;;###autoload
(defun my/start-buffer ()
  "Return the start screen buffer, freshly drawn."
  (let ((buf (get-buffer-create "*start*")))
    (with-current-buffer buf
      (unless (derived-mode-p 'my/start-mode) (my/start-mode))
      (my/start-refresh))
    buf))

;;;###autoload
(defun my/start-initial-buffer ()
  "The buffer to show when Emacs starts: the start screen, unless files were given.
Emacs evaluates this after opening the files named on the command line; if it returned
the start screen anyway, both would be shown in a split."
  (if (eq (current-buffer) (get-buffer "*scratch*"))
      (my/start-buffer)
    (current-buffer)))

;;;###autoload
(defun my/start ()
  "Show the start screen: recent files, folders and projects."
  (interactive)
  (switch-to-buffer (my/start-buffer))
  (delete-other-windows))

(provide 'startpage)
;;; startpage.el ends here
