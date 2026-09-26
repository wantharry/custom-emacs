;;; init.el --- personal config for the research Emacs  -*- lexical-binding: t; -*-

;; This configuration uses features from Emacs 30 (completion preview, built-in
;; which-key, Eglot's log setting).  Fail with a clear message instead of an obscure
;; "void function" halfway through.  Built and tested on 32.0.50.
(when (< emacs-major-version 30)
  (error "This configuration needs Emacs 30 or newer; this is Emacs %s" emacs-version))

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

;;; Every file opens read-only -------------------------------------------------

;; Nothing on disk changes by accident, for example when a slip while learning
;; shortcuts turns into typed text.  Each file you visit is read-only until you
;; deliberately type  M-x allow-editing  or press  C-c e e  (C-c e l  or
;; M-x stop-editing  locks it again).
;; This also covers files that do not exist yet: allow editing to create them.
;;
;; The hook runs last (depth 90) so nothing else, such as version control, can make
;; the buffer writable again.  Emacs's own writers still work: `customize' saves
;; with `inhibit-read-only', and package/recentf/savehist write through temporary
;; buffers rather than visited files.
(defun my/make-file-buffer-read-only ()
  "Make the file-visiting buffer that was just opened read-only."
  (read-only-mode 1))
(add-hook 'find-file-hook #'my/make-file-buffer-read-only 90)

(defun allow-editing ()
  "Make the current buffer editable.
Files open read-only.  This is the one deliberate way to change that;
`stop-editing' locks the buffer again."
  (interactive)
  (if (not buffer-read-only)
      (message "Already editable: %s" (buffer-name))
    (read-only-mode -1)
    (message "Editing ON for %s.  Save with C-x C-s; lock again with M-x stop-editing."
             (buffer-name))))

(defun stop-editing ()
  "Make the current buffer read-only again."
  (interactive)
  (read-only-mode 1)
  (message "Editing OFF for %s%s" (buffer-name)
           (if (and buffer-file-name (buffer-modified-p))
               " (it has UNSAVED changes; unlock and save with C-x C-s to keep them)"
             "")))

(defun my/read-only-hint ()
  "Tell how to edit.  Replaces the standard C-x C-q toggle on purpose.
A single shortcut must not be able to switch editing on, so that a mistyped
key sequence can never make a file editable."
  (interactive)
  (message "Files open read-only.  To edit, type:  C-c e e   (or M-x allow-editing)"))
(global-set-key (kbd "C-x C-q") #'my/read-only-hint)

;; Deliberate three-key chords under C-c (the prefix Emacs reserves for users), so a
;; single slipped key can never unlock a file:  C-c e e = edit,  C-c e l = lock.
(global-set-key (kbd "C-c e e") #'allow-editing)
(global-set-key (kbd "C-c e l") #'stop-editing)

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

;;; Languages: tree-sitter grammars and language servers ----------------------

;; Grammar versions are pinned to ones built with parser ABI 14 or lower, which is
;; the most the tree-sitter library on this machine (0.20.x) can load.  Install
;; them with `./build.sh grammars' or `M-x treesit-install-language-grammar'.
(setq treesit-language-source-alist
      '((java "https://github.com/tree-sitter/tree-sitter-java" "v0.23.5")
        (rust "https://github.com/tree-sitter/tree-sitter-rust" "v0.23.2")))

;; Rust: Emacs 32 already opens .rs files in `rust-ts-mode' when its grammar exists.
;; Java: .java opens in the older `java-mode' unless remapped, so remap it, but only
;; when the grammar is installed (otherwise keep the working classic mode).
(when (treesit-language-available-p 'java)
  (add-to-list 'major-mode-remap-alist '(java-mode . java-ts-mode)))

;; Language servers (rust-analyzer, jdtls) are started by hand with M-x eglot and
;; never automatically: a JVM-based server takes seconds and a large amount of
;; memory, and most editing does not need it.  Skip logging every protocol message.
(setq eglot-events-buffer-config '(:size 0))

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
