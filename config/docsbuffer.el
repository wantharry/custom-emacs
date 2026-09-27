;;; docsbuffer.el --- every guide, in one buffer, always available  -*- lexical-binding: t; -*-

;; A buffer named *docs* holding the text of README.md and every guide in docs/, one after
;; another, so you can read any of them with no network and no re-finding the file: `C-x b
;; *docs*' or `C-c d'.  It is built once, briefly after startup, and does not pop up on its
;; own; `C-c d' is the only thing that displays it.  `C-c D' rebuilds it (after you have
;; changed a guide).  No package: `outline-mode' (built in) gives folding, and each guide's
;; name is also a real Emacs button you can click or press RET on.
;;
;; See docs/CUSTOMIZING.md.

(require 'outline)
(require 'button)

(defvar my/docs-buffer-name "*docs*")

(defvar my/docs-root nil
  "The project root holding README.md and docs/.  nil means the parent of
`user-emacs-directory', which is where it lives when Emacs runs with
--init-directory=config at the repository root.  Tests bind this to point
at the real repository, since a test's temporary config directory has no
docs/ of its own.")

(defun my/docs--root ()
  (or my/docs-root (expand-file-name "../" user-emacs-directory)))

(defun my/docs--files ()
  "README.md, then every docs/*.md, alphabetically; each an absolute path."
  (let ((root (my/docs--root)))
    (cons (expand-file-name "README.md" root)
          (sort (file-expand-wildcards (expand-file-name "docs/*.md" root)) #'string<))))

(defvar-local my/docs--file-positions nil
  "Alist of (ABSOLUTE-FILE . BUFFER-POSITION), for jumping straight to a guide.")

(defun my/docs--relative-name (file)
  (file-relative-name file (my/docs--root)))

(defun my/docs--insert-toc (files)
  (insert "* Documentation index\n\n")
  (insert "  Every guide in this project, all in this one buffer.  Click a name, or place the\n")
  (insert "  cursor on it and press RET, to jump to it.  TAB folds a section; `C-c C-n'/`C-c C-p'\n")
  (insert "  move between guides.  `g' or `C-c D' rebuilds this buffer after a guide changes.\n\n")
  (dolist (f files)
    (insert "  ")
    (insert-text-button (my/docs--relative-name f)
                        'action #'my/docs--jump 'follow-link t 'my-docs-file f)
    (insert "\n"))
  (insert "\n"))

(defun my/docs--jump (button)
  (goto-char (or (cdr (assoc (button-get button 'my-docs-file) my/docs--file-positions)) (point-min)))
  ;; only recenter if this buffer is actually shown somewhere (it may not be, if this is
  ;; invoked programmatically rather than by a real click or RET in a visible window)
  (when (get-buffer-window (current-buffer)) (recenter 0)))

(defvar my/docs-mode-map
  (let ((m (make-sparse-keymap)))
    (set-keymap-parent m outline-mode-map)
    (define-key m "g" #'my/docs-rebuild)
    (define-key m "q" #'quit-window)
    m))

(define-derived-mode my/docs-mode outline-mode "Docs"
  "Every project guide, concatenated, foldable with `outline-mode'."
  (setq-local outline-regexp "\\* ")
  (setq-local buffer-read-only t))

;;;###autoload
(defun my/docs-rebuild ()
  "(Re)build *docs* from README.md and every docs/*.md.  Does not display it."
  (interactive)
  (let ((buf (get-buffer-create my/docs-buffer-name)) (files (my/docs--files)) positions)
    (with-current-buffer buf
      (let ((inhibit-read-only t))
        (unless (derived-mode-p 'my/docs-mode) (my/docs-mode))
        (erase-buffer)
        (my/docs--insert-toc files)
        (dolist (f files)
          (push (cons f (point)) positions)
          (insert (format "* %s\n\n" (my/docs--relative-name f)))
          (if (file-readable-p f)
              (insert-file-contents f)
            (insert "  (missing)\n"))
          (goto-char (point-max))
          (insert "\n"))
        (setq my/docs--file-positions (nreverse positions))
        (goto-char (point-min))
        (set-buffer-modified-p nil)))
    buf))

;;;###autoload
(defun my/docs ()
  "Show the documentation buffer (building it first if it does not exist yet)."
  (interactive)
  (switch-to-buffer (or (get-buffer my/docs-buffer-name) (my/docs-rebuild))))

(provide 'docsbuffer)
;;; docsbuffer.el ends here
