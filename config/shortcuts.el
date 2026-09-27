;;; shortcuts.el --- this config's own keybindings, grouped by topic  -*- lexical-binding: t; -*-

;; A buffer named *shortcuts* listing every key this configuration itself adds (not the
;; hundreds of built-in Emacs bindings docs/KEYBOARD.md teaches --- see that for those),
;; grouped by topic and foldable with `outline-mode', so you can collapse everything and
;; open just the one topic you want.  Shown automatically, split next to the start
;; screen, the first time Emacs opens with no file given; `C-c k' brings it back anytime.
;;
;; `my/shortcuts-list' is the one place this data lives; docs/KEYBOARD.md's own "this
;; config:" rows are the authoritative description text, and
;; tests/ert/shortcuts.el checks every key here still really runs the command it claims.
;;
;; See docs/KEYBOARD.md.

(require 'outline)

(defvar my/shortcuts-buffer-name "*shortcuts*")

(defconst my/shortcuts-list
  '(("Finding files"
     ("C-c f f" my/ff-find-file "instant fuzzy file finder (project, or whole disk outside one)")
     ("C-c f g" my/ff-find-file-global "the same over the whole disk")
     ("C-c f r" my/ff-reindex "rebuild the whole-disk file index"))
    ("Searching"
     ("C-c s l" consult-line "search this buffer, with a live preview")
     ("C-c s g" consult-ripgrep "search project text (ripgrep), with a live preview")
     ("C-c s f" consult-fd "find a project file by name (fd), with a live preview")
     ("C-c s b" consult-buffer "switch to a buffer, recent file or bookmark"))
    ("Git"
     ("C-x g" magit-status "Git status, stage and commit with single keys")
     ("C-c g" magit-file-dispatch "Git commands for this file")
     ("C-c f p" my/find-git-repos "list every git repository on this computer (indexed, instant)"))
    ("Project tree"
     ("C-c t" my/treemacs "show or hide the project file tree")
     ("C-c T" my/treemacs-reveal "show the tree and move to the current file in it"))
    ("Recent work"
     ("C-c h" my/start "the start screen: recent files, folders and projects")
     ("C-c r" recentf-open "open a recent file"))
    ("Editing lock"
     ("C-c e e" allow-editing "make this buffer editable")
     ("C-c e l" stop-editing "lock this buffer read-only again"))
    ("Documentation"
     ("C-c d" my/docs "show every guide in one buffer, built at startup")
     ("C-c D" my/docs-rebuild "rebuild it after a guide changes")
     ("C-c k" my/shortcuts "this buffer"))
    ("LLM chat"
     ("C-c a a" my/llm-chat "open a chat buffer with a local Ollama model")
     ("C-c a m" gptel-menu "pick a model, backend or system prompt"))
    ("Windows"
     ("M-o" other-window "switch to the other window")))
  "This configuration's own keybindings, grouped by topic, as (TOPIC (KEY COMMAND
DESCRIPTION) ...).  COMMAND is only used to check the key still really runs it (see
tests/ert/shortcuts.el); the buffer itself shows only KEY and DESCRIPTION.  Kept in
step with docs/KEYBOARD.md's own \"this config:\" rows by hand; add a new command to
both places.")

(defvar my/shortcuts-mode-map
  (let ((m (make-sparse-keymap)))
    (set-keymap-parent m outline-mode-map)
    (define-key m "q" #'quit-window)
    m))

(define-derived-mode my/shortcuts-mode outline-mode "Shortcuts"
  "This configuration's own keybindings, grouped by topic.  See `my/shortcuts'."
  (setq-local outline-regexp "\\* ")
  (setq-local buffer-read-only t))

(defun my/shortcuts--insert ()
  (insert (propertize "This config's keybindings\n\n" 'face '(:height 1.2 :weight bold)))
  (insert "  TAB folds a topic; RET/click on a topic also works.  See docs/KEYBOARD.md\n")
  (insert "  for what every built-in Emacs key does too.\n\n")
  (dolist (topic my/shortcuts-list)
    (insert (format "* %s\n" (car topic)))
    (dolist (row (cdr topic))
      (insert (format "  %-10s %s\n" (nth 0 row) (nth 2 row))))
    (insert "\n")))

;;;###autoload
(defun my/shortcuts-buffer ()
  "Return the *shortcuts* buffer, freshly drawn."
  (let ((buf (get-buffer-create my/shortcuts-buffer-name)))
    (with-current-buffer buf
      (let ((inhibit-read-only t))
        (unless (derived-mode-p 'my/shortcuts-mode) (my/shortcuts-mode))
        (erase-buffer)
        (my/shortcuts--insert)
        (goto-char (point-min))
        (set-buffer-modified-p nil)))
    buf))

;;;###autoload
(defun my/shortcuts ()
  "Show this configuration's own keybindings, grouped by topic."
  (interactive)
  (switch-to-buffer (my/shortcuts-buffer)))

(defun my/shortcuts--maybe-show-at-startup ()
  "Split the frame and show *shortcuts* next to the start screen, but only when the
start screen is what actually opened (not when files were given on the command line),
and only into a single, unsplit window (never fight a layout already in progress)."
  (when (and (eq (window-buffer) (get-buffer "*start*")) (one-window-p t))  ; startpage.el's own buffer name
    (let ((main (selected-window)))
      (select-window (split-window main nil 'right))
      (switch-to-buffer (my/shortcuts-buffer))
      (select-window main))))
(add-hook 'emacs-startup-hook #'my/shortcuts--maybe-show-at-startup 60)

(provide 'shortcuts)
;;; shortcuts.el ends here
