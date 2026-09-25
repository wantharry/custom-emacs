;;; init.el --- personal config for the research Emacs  -*- lexical-binding: t; -*-

;;; Startup / performance ----------------------------------------------------

;; Restore a sane GC threshold after startup (early-init.el raised it).
(add-hook 'emacs-startup-hook
          (lambda ()
            (setq gc-cons-threshold (* 64 1024 1024)   ; 64 MB
                  gc-cons-percentage 0.2)))

;; Reading from subprocesses (LSP servers etc.) is faster with a bigger buffer.
(setq read-process-output-max (* 1024 1024))

;; Keep machine-generated settings out of this file.
(setq custom-file (expand-file-name "custom.el" user-emacs-directory))
(when (file-exists-p custom-file) (load custom-file nil t))

;;; UI -----------------------------------------------------------------------

(menu-bar-mode 1)
(column-number-mode 1)
(global-display-line-numbers-mode 1)
(global-hl-line-mode 1)
(setq-default indicate-empty-lines t
              fill-column 80)

;; Built-in theme (Modus ships with Emacs).
(load-theme 'modus-vivendi t)

;; Use the first available font from the list; fall back to the default.
(when (display-graphic-p)
  (let ((font (seq-find (lambda (f) (find-font (font-spec :name f)))
                        '("JetBrains Mono" "Fira Code" "Cascadia Code"
                          "DejaVu Sans Mono" "Menlo" "Consolas"))))
    (when font
      (set-face-attribute 'default nil :font font :height 120))))

;;; Editing ------------------------------------------------------------------

(setq-default indent-tabs-mode nil
              tab-width 4)
(setq require-final-newline t
      sentence-end-double-space nil
      ring-bell-function #'ignore
      use-short-answers t)

(electric-pair-mode 1)
(show-paren-mode 1)
(delete-selection-mode 1)
(global-auto-revert-mode 1)
(save-place-mode 1)
(recentf-mode 1)
(savehist-mode 1)

;; Backups and auto-saves go to one place instead of littering projects.
(let ((dir (expand-file-name "backups/" user-emacs-directory)))
  (make-directory dir t)
  (setq backup-directory-alist `(("." . ,dir))
        auto-save-file-name-transforms `((".*" ,dir t))
        backup-by-copying t
        create-lockfiles nil))

;;; Completion (all built in) -------------------------------------------------

(fido-vertical-mode 1)                  ; minibuffer completion, vertical list
(setq completion-styles '(basic partial-completion flex)
      completion-ignore-case t
      read-file-name-completion-ignore-case t)
(global-completion-preview-mode 1)      ; inline suggestions as you type
(which-key-mode 1)                      ; shows available keys after a prefix

;;; Coding: tree-sitter + LSP (Eglot) -----------------------------------------

;; Highlight as much as tree-sitter offers. Grammars are installed on demand:
;;   M-x treesit-install-language-grammar   (needs a C compiler; we have one)
(setq treesit-font-lock-level 4)

;; Eglot is the built-in LSP client. Start it per buffer with M-x eglot,
;; or enable for a language, e.g.:
;;   (add-hook 'python-ts-mode-hook #'eglot-ensure)
(setq eglot-autoshutdown t)

;;; Keys ---------------------------------------------------------------------

(global-set-key (kbd "C-x C-b") #'ibuffer)
(global-set-key (kbd "M-o") #'other-window)
(global-set-key (kbd "C-c r") #'recentf-open)

;; Report how fast we started, once, so speed is measurable.
(add-hook 'emacs-startup-hook
          (lambda ()
            (message "Emacs %s ready in %.2fs (%d GCs), native-comp: %s"
                     emacs-version
                     (float-time (time-subtract after-init-time before-init-time))
                     gcs-done
                     (native-comp-available-p))))

;;; init.el ends here
