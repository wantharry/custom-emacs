;;; docsbuffer.el --- every guide, in one buffer, always available  -*- lexical-binding: t; -*-

;; A buffer named *docs* holding the text of README.md and every guide in docs/, one after
;; another, so you can read any of them with no network and no re-finding the file: `C-x b
;; *docs*' or `C-c d'.  It is built once, briefly after startup, and does not pop up on its
;; own; `C-c d' is the only thing that displays it.  `C-c D' rebuilds it (after you have
;; changed a guide).  No package: `outline-mode' (built in) gives folding, and each guide's
;; name is also a real Emacs button you can click or press RET on.
;;
;; See docs/CUSTOMIZING.md.

;; WHAT: Emacs's built-in outlining library.  WHY: gives this buffer folding (one "* NAME"
;; heading per guide, collapsible) for free, the same mechanism `my/shortcuts'/`my/llm-
;; council' use.  HOW: provides `outline-mode' to derive from below.
(require 'outline)
;; WHAT: Emacs's built-in clickable-link library.  WHY: each guide's name in the table of
;; contents is a real button (`insert-text-button' below), so clicking or pressing RET on
;; it jumps straight to that guide.  HOW: provides `insert-text-button'.
(require 'button)

;; WHAT: the results buffer's fixed name.  WHY/HOW: same one-buffer-reused pattern as
;; every other reference buffer in this config.
(defvar my/docs-buffer-name "*docs*")

;; WHAT: where README.md and docs/*.md actually live.  WHY: nil (the default) means
;; "figure it out from `user-emacs-directory'", which works for a real running Emacs
;; (started with `--init-directory=config' at the repository root, so the project root is
;; exactly one directory up); tests instead bind this explicitly to point at the real
;; checked-out repository, since a test's own throwaway temporary config directory has no
;; docs/ folder of its own to read from.
(defvar my/docs-root nil
  "The project root holding README.md and docs/.  nil means the parent of
`user-emacs-directory', which is where it lives when Emacs runs with
--init-directory=config at the repository root.  Tests bind this to point
at the real repository, since a test's temporary config directory has no
docs/ of its own.")

;; WHAT/WHY/HOW: resolve the effective root right now --- `my/docs-root' if a test (or
;; anything else) has set it, otherwise derived fresh from `user-emacs-directory' each
;; time, so a change to that variable is always honored rather than cached stale.
(defun my/docs--root ()
  (or my/docs-root (expand-file-name "../" user-emacs-directory)))

;; WHAT: the full, ordered list of files this buffer concatenates.  WHY: README.md always
;; comes first (the project's own front page), then every other guide alphabetically ---
;; a predictable, stable order so the table of contents and the buffer's own section
;; order always match, and don't reshuffle between rebuilds just because of filesystem
;; enumeration order.  HOW: `file-expand-wildcards' finds every `docs/*.md' file; `cons'
;; puts README.md unconditionally first, ahead of the sorted rest.
(defun my/docs--files ()
  "README.md, then every docs/*.md, alphabetically; each an absolute path."
  (let ((root (my/docs--root)))
    (cons (expand-file-name "README.md" root)
          (sort (file-expand-wildcards (expand-file-name "docs/*.md" root)) #'string<))))

;; WHAT: where, in the buffer, each guide's own section actually starts.  WHY: this is
;; what lets clicking a table-of-contents entry jump straight to the right place instead
;; of requiring a manual scroll/search --- built once per rebuild in `my/docs-rebuild'
;; below, then read back by `my/docs--jump'.  HOW: buffer-local (each *docs* buffer
;; --- there is only ever one in practice --- has its own mapping).
(defvar-local my/docs--file-positions nil
  "Alist of (ABSOLUTE-FILE . BUFFER-POSITION), for jumping straight to a guide.")

;; WHAT/WHY/HOW: FILE's path shown relative to the project root, used everywhere a guide
;; name is displayed (the table of contents, each section's own heading) instead of a
;; long absolute path.
(defun my/docs--relative-name (file)
  (file-relative-name file (my/docs--root)))

;; WHAT: write the table-of-contents section at the top of the buffer.  WHY: gives an
;; at-a-glance index plus a short usage reminder, before the (much longer) actual guide
;; text begins.  HOW: one outline heading ("* Documentation index"), a short instructions
;; paragraph, then one clickable button per file in FILES; each button carries its own
;; absolute path in the `my-docs-file' property, read back by `my/docs--jump' below.
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

;; WHAT: the button `action' called on RET/click on a table-of-contents entry.  WHY/HOW:
;; looks up that file's recorded position in `my/docs--file-positions' (falling back to
;; the very top of the buffer if, somehow, it isn't there) and jumps there; `recenter 0'
;; puts the target heading at the very top of the window, but only when this buffer is
;; actually visible somewhere right now (`get-buffer-window') --- calling `recenter' with
;; no window showing the buffer would either error or act on the wrong window, and this
;; function can also be invoked programmatically (e.g. from a test), not just by a real
;; click.
(defun my/docs--jump (button)
  (goto-char (or (cdr (assoc (button-get button 'my-docs-file) my/docs--file-positions)) (point-min)))
  ;; only recenter if this buffer is actually shown somewhere (it may not be, if this is
  ;; invoked programmatically rather than by a real click or RET in a visible window)
  (when (get-buffer-window (current-buffer)) (recenter 0)))

;; WHAT: this buffer's own keymap.  WHY/HOW: inherits from `outline-mode-map' (folding
;; keys, including TAB, come for free), adding just `g' (rebuild --- a quick way to pick
;; up guide edits without remembering the separate `C-c D' binding) and `q' (close,
;; matching every other read-only reference buffer in this config).  This is one of the
;; two buffers (the other being `my/shortcuts-mode') whose `q' is bound explicitly here,
;; rather than inherited from `special-mode-map' the way `my/git-repos-mode' and `my/
;; start-mode' do --- both derive from `outline-mode', which has no `special-mode'
;; ancestry at all, so `q' has to be added by hand.
(defvar my/docs-mode-map
  (let ((m (make-sparse-keymap)))
    (set-keymap-parent m outline-mode-map)
    (define-key m "g" #'my/docs-rebuild)
    (define-key m "q" #'quit-window)
    m))

;; WHAT: the major mode for the *docs* buffer.  WHY: derives from `outline-mode' so every
;; "* NAME" section (the table of contents, plus one per guide) is foldable; `outline-
;; regexp' is set to match that exact heading style used throughout this buffer.
(define-derived-mode my/docs-mode outline-mode "Docs"
  "Every project guide, concatenated, foldable with `outline-mode'."
  (setq-local outline-regexp "\\* ")
  (setq-local buffer-read-only t))

;; WHAT: (re)build the whole *docs* buffer from scratch.  WHY: bound to both `C-c D' and
;; `g' (see the keymap above), and also called once, unconditionally, at startup (see
;; config/init.el) so the buffer is ready the moment `C-c d' is first pressed --- reading
;; and concatenating every guide is fast enough (about 2ms for this project's ~290KB of
;; docs, per the file's own measured note in init.el) that doing it eagerly at startup,
;; rather than lazily on first use, is simply not worth the added code complexity of
;; deferring it.  HOW: gathers the file list via `my/docs--files'; temporarily disables
;; read-only (`inhibit-read-only') to rebuild; only switches on the major mode once (not
;; redundantly on every rebuild); writes the table of contents first, then for each file
;; in order: records its starting buffer position into `positions' (collected in reverse
;; via `push', restored to file order with `nreverse' at the end --- the usual cheap-
;; accumulation pattern used throughout this project), inserts its own "* NAME" heading,
;; then either the file's real contents (`insert-file-contents', which inserts at point
;; without visiting/opening the file as a separate buffer) or a plain "(missing)"
;; placeholder if the file somehow isn't readable (so one bad/renamed guide doesn't break
;; the whole buffer); `goto-char (point-max)' after each insertion is needed because
;; `insert-file-contents' leaves point wherever it happens to land relative to the
;; inserted text, not necessarily at its end.  Does NOT display the buffer itself ---
;; that's `my/docs''s job, below --- so calling this to refresh doesn't yank focus away
;; from whatever the user is currently doing.
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

;; WHAT: `C-c d' --- show the documentation buffer.  WHY/HOW: since `my/docs-rebuild'
;; already runs once at startup (see config/init.el), the buffer normally already exists
;; by the time this is called and this just switches to it directly; the `or' fallback
;; (building it on the spot if it somehow doesn't exist yet) is defensive, covering an
;; unusual call order rather than the expected path.
;;;###autoload
(defun my/docs ()
  "Show the documentation buffer (building it first if it does not exist yet)."
  (interactive)
  (switch-to-buffer (or (get-buffer my/docs-buffer-name) (my/docs-rebuild))))

;; WHAT/WHY/HOW: register this file under the Emacs feature name `docsbuffer', matching
;; the `(require 'docsbuffer ...)' the relevant test file and config/init.el both use.
(provide 'docsbuffer)
;;; docsbuffer.el ends here
