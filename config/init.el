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

;; No theme yet: Emacs default colors. Add `load-theme' here later.

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

;;; Packages -----------------------------------------------------------------

;; Only what we choose to use, installed into config/elpa (gitignored) by
;; `./build.sh packages' or on first use.
;;
;; package.el is deliberately NOT loaded at startup.  It loads `browse-url',
;; which searches PATH for browsers; on WSL, where PATH includes Windows
;; drives, that alone costs ~0.7 s per launch.  Installed packages are put on
;; `load-path' directly instead, and package.el is loaded only to install.
(defvar my/elpa-dir (expand-file-name "elpa" user-emacs-directory)
  "Where packages installed by this configuration live.")

(dolist (dir (file-expand-wildcards (expand-file-name "*" my/elpa-dir)))
  (when (and (file-directory-p dir)
             (not (member (file-name-nondirectory dir) '("archives" "gnupg"))))
    (add-to-list 'load-path dir)))

(defun my/install-package (pkg)
  "Install PKG from ELPA into `my/elpa-dir'.  Loads package.el on demand."
  (require 'package)
  (setq package-user-dir my/elpa-dir
        package-archives '(("gnu"    . "https://elpa.gnu.org/packages/")
                           ("nongnu" . "https://elpa.nongnu.org/nongnu/")))
  (package-initialize)
  (package-refresh-contents)
  (package-install pkg))

;;; Evil (vi keybindings), off by default -------------------------------------

;; Compatibility shim.  Evil 1.15 reads `evil-mode-buffers', a variable the
;; globalized-minor-mode machinery defined in Emacs <= 31 but Emacs 32 no
;; longer does.  Without it, Evil signals (void-variable evil-mode-buffers)
;; from `post-command-hook' after commands.  Nil means "no buffer is being
;; initialized", which is the right answer outside Evil's own setup code.
;; Covered by tests/ert/evil.el; remove once Evil supports Emacs 32.
(defvar evil-mode-buffers nil
  "Compatibility shim for Evil on Emacs 32; see init.el.")

(defun my/toggle-evil ()
  "Toggle Evil (vi emulation) globally.
Evil is loaded on first use, so it costs nothing until then.  If it is not
installed, offer to install it from NonGNU ELPA."
  (interactive)
  (unless (require 'evil nil t)
    (if (y-or-n-p "Evil (vi keys) is not installed.  Install from NonGNU ELPA? ")
        (progn (my/install-package 'evil)
               (require 'evil))
      (user-error "Evil is not installed")))
  (evil-mode (if evil-mode -1 1))
  (message "Evil mode %s" (if evil-mode "enabled" "disabled")))

;;; Keys ---------------------------------------------------------------------

(global-set-key (kbd "C-c v") #'my/toggle-evil)
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
