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
;; "JetBrainsMono Nerd Font Mono" comes first because that is this font's real installed name
;; here (`fc-list`); the plain "JetBrains Mono" name never matches on this machine, so it
;; silently fell through to DejaVu Sans Mono. Kept as a fallback for a machine that has the
;; non-Nerd-Font release installed instead.
(when (display-graphic-p)
  (let ((font (seq-find (lambda (f) (find-font (font-spec :name f)))
                        '("JetBrainsMono Nerd Font Mono" "JetBrains Mono" "Fira Code" "Cascadia Code"
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

;; Windows would otherwise save new files with CRLF line endings; use UTF-8 with LF, as on Linux
;; and macOS, so a file is the same wherever you write it.  Files that already use CRLF keep it.
(when (eq system-type 'windows-nt)
  (prefer-coding-system 'utf-8-unix)
  ;; ... and do not print "(Unix)" in the mode line for it, which Linux does not
  (setq eol-mnemonic-unix ":"))

(electric-pair-mode 1)
(show-paren-mode 1)
(delete-selection-mode 1)
(global-auto-revert-mode 1)
(save-place-mode 1)
(recentf-mode 1)
;; `recentf' only saves its list via `kill-emacs-hook' by default, so an unclean exit
;; (a crash, a forced kill, a real hang needing Task Manager) loses the whole session's
;; history --- confirmed for real on the Windows bundle: after a forced kill, the very
;; next launch showed none of that session's files.  A periodic autosave closes most of
;; that window, the same way `my/start-save' (startpage.el) already protects the recent
;; folders/projects list.
(run-with-idle-timer 30 t #'recentf-save-list)
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
;; The exceptions: the message files Git asks you to write (a commit message, a merge message,
;; a tag, the rebase list), which Magit opens for you: locking them would make committing
;; impossible, and they only exist because you asked to commit.  And the file Treemacs uses to
;; remember its projects, which the program itself writes.
(defvar my/always-editable-file-regexp
  (concat "/\\.git/\\(?:.*/\\)?\\(?:COMMIT_EDITMSG\\|MERGE_MSG\\|TAG_EDITMSG\\|NOTES_EDITMSG\\|PULLREQ_EDITMSG\\|EDIT_DESCRIPTION\\|git-rebase-todo\\)\\'"
          ;; Treemacs keeps its list of projects in a small file it opens and writes itself
          "\\|/\\.cache/treemacs-persist\\(?:-at-last-error\\)?\\'")
  "Files whose buffers are left editable by the read-only lock.")

(defun my/make-file-buffer-read-only ()
  "Make the file-visiting buffer that was just opened read-only."
  (unless (and buffer-file-name (string-match-p my/always-editable-file-regexp buffer-file-name))
    (read-only-mode 1)))
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
        (rust "https://github.com/tree-sitter/tree-sitter-rust" "v0.23.2")
        (html "https://github.com/tree-sitter/tree-sitter-html" "v0.23.2")
        (css "https://github.com/tree-sitter/tree-sitter-css" "v0.23.2")
        (javascript "https://github.com/tree-sitter/tree-sitter-javascript" "v0.23.1")
        (jsdoc "https://github.com/tree-sitter/tree-sitter-jsdoc" "v0.23.2")
        (typescript "https://github.com/tree-sitter/tree-sitter-typescript" "v0.23.2" "typescript/src")
        (tsx "https://github.com/tree-sitter/tree-sitter-typescript" "v0.23.2" "tsx/src")
        (json "https://github.com/tree-sitter/tree-sitter-json" "v0.23.0")))

;; Rust: Emacs 32 already opens .rs files in `rust-ts-mode' when its grammar exists.
;; Java: .java opens in the older `java-mode' unless remapped, so remap it, but only
;; when the grammar is installed (otherwise keep the working classic mode).
(when (treesit-language-available-p 'java)
  (add-to-list 'major-mode-remap-alist '(java-mode . java-ts-mode)))

;; Web/UI languages: same idea as Java.  .ts/.tsx already open in `typescript-ts-mode'/
;; `tsx-ts-mode' automatically (core Emacs has no legacy TypeScript mode to fall back to,
;; so those two fall back to plain `fundamental-mode', not highlighted, until their
;; grammar is installed); .js/.css/.html need the same explicit remap Java does, since
;; each has a working legacy mode that would otherwise stay in charge forever.  .js/.jsx
;; are remapped from `javascript-mode' (what `auto-mode-alist' actually opens them in,
;; an alias of `js-mode'), not `js-mode' itself, or the remap silently never applies.
(when (treesit-language-available-p 'javascript)
  (add-to-list 'major-mode-remap-alist '(javascript-mode . js-ts-mode)))
(when (treesit-language-available-p 'css)
  (add-to-list 'major-mode-remap-alist '(css-mode . css-ts-mode)))
(when (treesit-language-available-p 'html)
  (add-to-list 'major-mode-remap-alist '(mhtml-mode . mhtml-ts-mode)))
(when (treesit-language-available-p 'json)
  (add-to-list 'major-mode-remap-alist '(js-json-mode . json-ts-mode)))

;; Windows bundle: it carries the Java language server itself (tools\jdtls), but no JDK ---
;; Java needs one installed, the same way Rust needs rust-analyzer installed (neither is
;; bundled).  Eglot's own entry looks for a program called `jdtls' (a Python script), so
;; tell it to start the bundled jdtls with whatever `java' it finds on PATH or JAVA_HOME
;; instead.  Only used when the launcher (Emacs.exe) says where the bundle is; anywhere
;; else Eglot's normal entry applies.
(defun my/bundled-jdtls-dir ()
  (let ((home (getenv "CUSTOM_EMACS_HOME")))
    (and home (expand-file-name "tools/jdtls/" home))))

(defun my/bundled-jdtls-command (&rest _)
  "The command line that runs the bundled jdtls on your own Java (none is bundled)."
  (let* ((dir (my/bundled-jdtls-dir))
         (java (or (executable-find "java")
                   (user-error "No Java found.  Install a JDK (17+) so `java' is on PATH or JAVA_HOME, then try M-x eglot again")))
         (jar (car (file-expand-wildcards (expand-file-name "plugins/org.eclipse.equinox.launcher_*.jar" dir))))
         (root (file-name-as-directory
                (expand-file-name (or (and (fboundp 'project-current) (when-let* ((pr (project-current)))
                                                                     (project-root pr)))
                                      default-directory))))
         ;; one workspace folder per project, kept with the settings (it must be writable)
         (data (expand-file-name (concat "jdtls-workspaces/" (md5 root)) user-emacs-directory)))
    (list java
          "-Declipse.application=org.eclipse.jdt.ls.core.id1"
          "-Dosgi.bundles.defaultStartLevel=4"
          "-Declipse.product=org.eclipse.jdt.ls.core.product"
          "-Xmx1G" "--add-modules=ALL-SYSTEM"
          "--add-opens" "java.base/java.util=ALL-UNNAMED"
          "--add-opens" "java.base/java.lang=ALL-UNNAMED"
          "-jar" jar
          "-configuration" (expand-file-name "config_win" dir)
          "-data" data)))

(when (and (eq system-type 'windows-nt) (my/bundled-jdtls-dir) (file-directory-p (my/bundled-jdtls-dir)))
  (with-eval-after-load 'eglot
    (add-to-list 'eglot-server-programs '((java-mode java-ts-mode) . my/bundled-jdtls-command))))

;; Language servers (rust-analyzer, jdtls) are started by hand with M-x eglot and
;; never automatically: a JVM-based server takes seconds and a large amount of
;; memory, and most editing does not need it.  Skip logging every protocol message.
(setq eglot-events-buffer-config '(:size 0))

;;; Clicking through code -------------------------------------------------------

;; Right-click a symbol in code for "Find Definition" and "Find References" (Emacs
;; adds these to the context menu only when `context-menu-mode' is on).
(context-menu-mode 1)

;; Ctrl+Click on a symbol jumps to its definition, as in VS Code, IntelliJ and Eclipse
;; (Emacs 31 and newer).
(when (fboundp 'global-xref-mouse-mode)
  (global-xref-mouse-mode 1))

;; When a language server (Eglot) manages the buffer, also offer implementations and
;; the type definition there.  Emacs has no default mouse route to them.
(defun my/eglot-find-implementation-at-mouse (event)
  "Show the implementations of the symbol clicked with EVENT."
  (interactive "e")
  (mouse-set-point event)
  (call-interactively #'eglot-find-implementation))

(defun my/eglot-find-type-definition-at-mouse (event)
  "Go to the type definition of the symbol clicked with EVENT."
  (interactive "e")
  (mouse-set-point event)
  (call-interactively #'eglot-find-type-definition))

(defun my/context-menu-eglot (menu click)
  "Add Eglot-only navigation items to the right-click MENU for CLICK."
  (when (and (featurep 'eglot) (eglot-managed-p)
             (save-excursion
               (mouse-set-point click)
               (thing-at-point 'symbol)))
    (define-key-after menu [my-find-impl]
      '(menu-item "Find Implementations" my/eglot-find-implementation-at-mouse
                  :help "Show the classes that implement this interface or method")
      'xref-find-def)
    (define-key-after menu [my-find-type]
      '(menu-item "Find Type Definition" my/eglot-find-type-definition-at-mouse
                  :help "Go to the type of this symbol")
      'my-find-impl))
  menu)
(add-hook 'context-menu-functions #'my/context-menu-eglot 20)

;; Text search across a project (C-x p g) is 4 to 10 times faster with ripgrep than with
;; grep (measured on the 5,629 files of the Emacs source: 56-63 ms against 226-670 ms,
;; same matches).  Applied when xref loads, so it costs nothing at startup; falls back to
;; grep on a machine without rg.
(with-eval-after-load 'xref
  (setq xref-search-program (if (executable-find "rg") 'ripgrep 'grep)))

;; jdtls, for a folder with no build file (no pom.xml or build.gradle), guesses the
;; source root wrongly (it warns "declared package does not match expected package")
;; and then finds no references to classes.  Tell it where the sources are.  Projects
;; with a build file ignore this.  Covers src/main/java/... and src/...
(setq-default eglot-workspace-configuration
              '(:java (:project (:sourcePaths ["src/main/java" "src"]))))

;; After a chord such as C-x o, keep pressing the last letter to repeat it (o, O for
;; other-window, u for undo, n/p for next/previous-error).  M-x repeat-mode to toggle.
(repeat-mode 1)

;;; Fast file finding ------------------------------------------------------------

;; Type a few letters of a file name and get the best matches at once, from an index of
;; the project or of the whole disk (matched with ripgrep), with a live search when the
;; index has nothing.  See fastfind.el and docs/NAVIGATING-CODE.md.
;;   C-c f f  project file (anywhere, outside a project)   C-c f g  anywhere on the disk
;;   C-c f r  rebuild the whole-disk index now
;; Autoloaded by full path: putting `user-emacs-directory' itself on `load-path' makes
;; Emacs print a startup warning.
(defconst my/ff-library (expand-file-name "fastfind" user-emacs-directory))
(autoload 'my/ff-find-file my/ff-library "Find a file in the current project." t)
(autoload 'my/ff-find-file-global my/ff-library "Find a file anywhere on the disk." t)
(autoload 'my/ff-reindex my/ff-library "Rebuild the whole-disk file index." t)
(autoload 'my/ff-status my/ff-library "Show the state of the file indexes." t)

;; The whole-disk index is built in the background, once, after Emacs has been idle for
;; 90 seconds, and again when it is over 6 hours old.  Nothing runs at startup.  Set this
;; to nil to build it only when you press C-c f r.
(defvar my/ff-auto-refresh t)
(when my/ff-auto-refresh
  (run-with-idle-timer 90 nil (lambda () (require 'fastfind my/ff-library) (my/ff-maybe-refresh))))

;;; Treemacs: a file tree in a sidebar ------------------------------------------------

;; `C-c t' shows the file tree of the project you are in (and hides it if it is showing);
;; `C-c T' also moves to the current file in it.  Treemacs's own `treemacs' command asks for a
;; folder the first time; these find the project by themselves.  Installed into config/elpa by
;; `./build.sh packages'; nothing loads until first use, so it costs nothing at startup.
;; See docs/TREEMACS.md.
(defun my/treemacs ()
  "Show the file tree of the current project, or hide it if it is already showing."
  (interactive)
  (require 'treemacs)
  (cond
   ((eq (treemacs-current-visibility) 'visible) (treemacs))         ; hide
   ((treemacs-workspace->is-empty?)
    ;; the first time: use this buffer's project, or else its folder, so there is no prompt
    (let ((root (or (treemacs--find-current-user-project) default-directory)))
      (treemacs-do-add-project-to-workspace (treemacs-canonical-path root)
                                            (file-name-nondirectory (directory-file-name root)))
      (treemacs-select-window)))
   (t (treemacs))))

(defun my/treemacs-reveal ()
  "Show the file tree and move into it, on the file of this buffer."
  (interactive)
  (require 'treemacs)
  ;; first time: add this buffer's project (without leaving this window, since
  ;; `treemacs-find-file' reads the file from the current buffer)
  (when (treemacs-workspace->is-empty?) (save-selected-window (my/treemacs)))
  (treemacs-find-file)          ; marks this file in the tree, showing the tree if it was hidden
  (treemacs-select-window))

(with-eval-after-load 'treemacs
  ;; Many Treemacs commands (delete, create, rename, the follow modes...) are only autoload stubs in its
  ;; autoloads file, which this config does not load at startup.  Load it now that Treemacs is in use.
  (when-let* ((f (locate-library "treemacs-autoloads"))) (load f nil t))
  (treemacs-follow-mode 1)            ; keep the current file highlighted in the tree
  (treemacs-project-follow-mode 1))   ; show the project of the buffer you move to

(defun my/treemacs-missing ()
  (interactive)
  (message "Treemacs is not installed.  Run ./build.sh packages"))
(global-set-key (kbd "C-c t") (if (locate-library "treemacs") #'my/treemacs #'my/treemacs-missing))
(global-set-key (kbd "C-c T") (if (locate-library "treemacs") #'my/treemacs-reveal #'my/treemacs-missing))

;;; Consult: search built on the completion list -----------------------------------

;; A handful of `consult' commands, each a fast, previewed search over one kind of thing:
;; `C-c s l' this buffer, `C-c s g' text across the project (ripgrep), `C-c s f' files by
;; name across the project (fd), `C-c s b' buffers, recent files and bookmarks in one list.
;; Moving to a candidate shows it at once in the window (the preview); `RET' or click stays
;; there, `C-g' returns to where you were.  Installed into config/elpa by `./build.sh
;; packages'; nothing loads until first use.  Needs `rg' and `fd' for the fastest results;
;; without them `consult-ripgrep'/`consult-fd' fall back to slower built-in tools.
;; See docs/SEARCHING.md and docs/SEARCH-OPTIONS.md.
(when (locate-library "consult")
  (autoload 'consult-line "consult" "Search this buffer, with a live preview." t)
  (autoload 'consult-ripgrep "consult" "Search project text with ripgrep, with a live preview." t)
  (autoload 'consult-fd "consult" "Find a project file by name with fd, with a live preview." t)
  (autoload 'consult-buffer "consult" "Switch to a buffer, recent file or bookmark." t))
(defun my/consult-missing ()
  (interactive)
  (message "Consult is not installed.  Run ./build.sh packages"))
(dolist (binding '(("C-c s l" . consult-line) ("C-c s g" . consult-ripgrep)
                   ("C-c s f" . consult-fd) ("C-c s b" . consult-buffer)))
  (global-set-key (kbd (car binding))
                  (if (locate-library "consult") (cdr binding) #'my/consult-missing)))

;;; Start screen ---------------------------------------------------------------

;; What Emacs shows when started without a file: the last 5 files, folders and projects,
;; each expandable with a "+ N more" link.  `C-c h' brings it back from anywhere.
;; See startpage.el and docs/START-SCREEN.md.
(defconst my/start-library (expand-file-name "startpage" user-emacs-directory))
(require 'startpage my/start-library)
(setq initial-buffer-choice #'my/start-initial-buffer)

;;; Documentation buffer ----------------------------------------------------------

;; Every guide (README.md and docs/*.md) concatenated into one buffer, *docs*, built once
;; at startup so it is always there to read, with no network and no re-finding a file.
;; It does not pop up on its own: `C-c d' shows it, `C-c D' rebuilds it.  Reading and
;; building it takes about 2 ms for 290 KB of text, so this runs at startup, not lazily.
;; See config/docsbuffer.el and docs/CUSTOMIZING.md.
(require 'docsbuffer (expand-file-name "docsbuffer" user-emacs-directory))
(my/docs-rebuild)
(global-set-key (kbd "C-c d") #'my/docs)
(global-set-key (kbd "C-c D") #'my/docs-rebuild)

;;; Magit ------------------------------------------------------------------------

;; Git in a keyboard-driven interface: `C-x g' opens the status of the current repository
;; (see docs/MAGIT.md).  Installed into config/elpa by `./build.sh packages'; nothing
;; loads until the first use, so it costs nothing at startup.  Without it installed,
;; `C-x g' says so instead of failing.
(when (locate-library "magit")
  (autoload 'magit-status "magit" "Show the status of the current Git repository." t)
  (autoload 'magit-dispatch "magit" "Show all Magit commands." t)
  (autoload 'magit-file-dispatch "magit" "Show Magit commands for this file." t)
  (autoload 'magit-log-buffer-file "magit" "Show the history of this file." t))
(defun my/magit-missing ()
  (interactive)
  (message "Magit is not installed.  Run ./build.sh packages"))
(global-set-key (kbd "C-x g") (if (locate-library "magit") #'magit-status #'my/magit-missing))
(global-set-key (kbd "C-c g") (if (locate-library "magit") #'magit-file-dispatch #'my/magit-missing))

;;; Finding git repositories --------------------------------------------------------

;; `C-c f p' lists every git repository on the Linux side; `C-u C-c f p' also scans every
;; mounted Windows drive (much slower).  Runs tools/find-repos.sh in the background, so
;; Emacs is never blocked while it searches.  Nothing loads until first use.
;; See config/gitfolders.el.
(autoload 'my/find-git-repos (expand-file-name "gitfolders" user-emacs-directory)
  "Show every git repository on this computer." t)

;;; Chat with an LLM (gptel) ----------------------------------------------------------

;; `C-c a a' opens a chat buffer: a local Ollama model, set up automatically (reading
;; whatever `ollama list' reports right now); `C-c a m' opens gptel's own menu to switch
;; model, backend or system prompt.  Installed into config/elpa by `./build.sh packages';
;; nothing loads until first use.  See config/llm.el and docs/LLM.md.
(when (locate-library "gptel")
  (autoload 'gptel-menu "gptel-transient" "Menu: pick a model, backend or system prompt." t))
(autoload 'my/llm-chat (expand-file-name "llm" user-emacs-directory)
  "Open a chat buffer with the local Ollama backend." t)
(defun my/llm-missing ()
  (interactive)
  (message "gptel is not installed.  Run ./build.sh packages"))
(global-set-key (kbd "C-c a a") (if (locate-library "gptel") #'my/llm-chat #'my/llm-missing))
(global-set-key (kbd "C-c a m") (if (locate-library "gptel") #'gptel-menu #'my/llm-missing))

;;; Keys ---------------------------------------------------------------------

(global-set-key (kbd "C-c f f") #'my/ff-find-file)
(global-set-key (kbd "C-c f g") #'my/ff-find-file-global)
(global-set-key (kbd "C-c f r") #'my/ff-reindex)
(global-set-key (kbd "C-c f p") #'my/find-git-repos)
(global-set-key (kbd "C-c v") #'my/toggle-evil)
(global-set-key (kbd "C-x C-b") #'ibuffer)
(global-set-key (kbd "M-o") #'other-window)
(global-set-key (kbd "C-c r") #'recentf-open)
(global-set-key (kbd "C-c h") #'my/start)

;; Report how fast we started, once, so speed is measurable.
(add-hook 'emacs-startup-hook
          (lambda ()
            (message "Emacs %s ready in %.2fs (%d GCs), native-comp: %s"
                     emacs-version
                     (float-time (time-subtract after-init-time before-init-time))
                     gcs-done
                     (native-comp-available-p))))

;;; init.el ends here
