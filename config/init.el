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

;; WHAT: wrap long lines at the last word boundary that fits, not at the exact character
;; the window edge happens to land on.  WHY: Emacs's own default (`word-wrap' nil) wraps
;; mid-word whenever a word straddles that boundary --- the continuation arrow shown in
;; the right fringe then sits in the middle of a split word, which is what was actually
;; being asked about ("why does it break the word... can we make sure only show when the
;; word fits"). `word-wrap' t moves the wrap point back to the nearest space/word-break
;; before the edge instead, so a whole word moves down to the next line together rather
;; than being cut in half; the fringe arrow still appears (it is what marks any wrapped,
;; not-a-real-newline continuation), but now only at an actual word boundary.
(setq-default word-wrap t)

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

;;; Calendar (M-x calendar / C-c y for a whole year) ---------------------------

;; A real mistake, made and reverted in the same session: `calendar-total-months' was
;; briefly set to 12 here, on the assumption that "shows more months" meant a sensible
;; multi-row year grid.  It does not --- `calendar.el' lays every month out in a single
;; row, so 12 months is one line 12 * calendar-month-width columns wide (300 on this
;; build, measured directly, not guessed).  On any normal window that just wraps and
;; scrambles --- confirmed for real, reported by the user right after the first version
;; of this comment claimed it was "verified" (it was, but only that the *text* held 12
;; month names, never what that actually renders as in a real window --- the same
;; mistake category as the word-wrap fix earlier this session, and the org/session.el
;; bug before that: tested in isolation, not through the real, visible result). Left at
;; the stock default (3) as a result --- `M-x calendar'`'s own `<'/`>' scroll that same
;; three-month window forward/backward through the year one month at a time.
;;
;; `C-c y' (`my/calendar-year') is the real fix instead: a genuine year-at-a-glance grid
;; (4 rows of 3 months), built by hand in config/calendar-year.el on top of `calendar-
;; generate-month' --- the same primitive `M-x calendar' itself uses for one row, just
;; called once per row here instead of once for all 12 in a row nothing can wrap sanely.
;; See that file's own header comment for the full story.
(autoload 'my/calendar-year (expand-file-name "calendar-year" user-emacs-directory)
  "Show all 12 months of a year in a grid, 3 months per row." t)
(global-set-key (kbd "C-c y") #'my/calendar-year)

;;; Org mode: disabled for now -------------------------------------------------
;; WHAT: `.org' files no longer auto-activate `org-mode' --- they open in plain
;; `fundamental-mode' instead (confirmed directly: no other rule in `auto-mode-alist'
;; claims `.org', so removing Org's own entry leaves the built-in default).  WHY: user
;; request --- Org binds a huge number of commands under
;; `C-c' (103, measured directly in a real org buffer, versus 19 on this config's own
;; `C-c' outside one), and it was showing up unwanted for someone who doesn't use Org.
;; This is a config-level toggle, easily reversed later (delete this form, or just
;; `M-x org-mode' by hand any time --- the command itself still works fine, this only
;; removes the automatic `.org' association).  Documentation for Org's own commands
;; (docs/KEYBOARD.md) and the earlier org/session.el collision fix are left in place on
;; purpose --- kept for whenever Org gets turned back on, per the user's own request.
;; HOW: Org registers its own `("\\.org\\'" . org-mode)' (and similar) entries in
;; `auto-mode-alist' unconditionally via its autoloads, before this file ever runs ---
;; so removing them has to happen here, after the fact, rather than by simply never
;; requiring Org in the first place.
(setq auto-mode-alist (rassq-delete-all 'org-mode auto-mode-alist))

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
;; WHAT: stop that periodic autosave (and `recentf' startup cleanup) from printing to
;; the echo area every 30s.  WHY: a real, reported problem --- `recentf-show-messages'
;; defaults to `t' in stock Emacs, so every single autosave shows "Wrote .../
;; recentf.eld", stock Emacs behavior this config never touched before now, not
;; something this idle timer itself introduced.  Confirmed directly in `recentf.el's own
;; source: the "Wrote FILE" message comes from a plain `write-region' call whose quiet-
;; flag is exactly `(unless (or (called-interactively-p 'interactive) recentf-show-
;; messages) 'quiet)' --- an autosave from a timer is never "interactive", so this alone
;; is enough to silence it; the actual saving (and the crash-safety it exists for) is
;; unaffected, only the message. `my/start-save' (startpage.el)'s own `recents.eld'
;; autosave already writes silently by construction (`with-temp-file' uses `write-
;; region's undocumented-but-real "VISIT is an integer" form, which stock Emacs's own
;; `write-region' never messages for regardless of this setting) --- confirmed in
;; `fileio.c' directly, not assumed, so nothing else needed changing for that file.
(setq recentf-show-messages nil)
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

;; WHAT: raise which-key's popup from its default 25% of the frame to 40%.  WHY: this is
;; a real regression fix, found by the GUI test suite, not a style tweak --- with the
;; `C-c n' (news), `C-c m' (dictation) and `C-c a c' (LLM council) bindings added this
;; session, `C-c''s own top-level binding list grew past what 25% of a normal frame can
;; show at once; confirmed for real, `my/toggle-evil' (bound to `C-c v') had scrolled out
;; of the visible, captured popup text.  HOW: 40% was measured, not guessed --- it's the
;; smallest height that comfortably shows every current `C-c' binding without cutting any
;; off; re-verified via the GUI test suite (36/36) after raising it.
(setq which-key-side-window-max-height 0.4)
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

;;; Completion ------------------------------------------------------------------

;; The minibuffer completion UI and matching style: `vertico' (a vertical candidate
;; list), `orderless' (type the words of what you want in any order, not just a
;; prefix --- "ff bin" matches "bin/find-file.el"), and `marginalia' (extra info
;; alongside each candidate: a command's own doc string in `M-x', a file's size and
;; permissions in `C-x C-f', a buffer's major mode in `C-x b'). All three replace
;; the built-in `fido-vertical-mode' this config used before --- falls back to that,
;; unchanged, if they are not installed, matching how this config treats every
;; other package as optional. Installed into config/elpa by `./build.sh packages';
;; loaded eagerly here (not autoloaded like most packages in this file), since
;; minibuffer completion is used from the very first keystroke of any command ---
;; there is no later "first use" to defer loading until, the way there is for
;; Magit or Treemacs.  Placed here, right after `load-path' gets the elpa
;; directories added above (not up with the rest of the UI settings near the top
;; of this file): `locate-library'/`require' need those directories on `load-path'
;; first --- confirmed for real, this section originally sat above the `load-path'
;; loop and silently always took the fallback branch, `vertico'/etc. never found.
;; See docs/SEARCHING.md.
;;
;; `flex' (built into Emacs, matches letters in order but not contiguously, e.g.
;; "gmtry" matches "Geometry") is kept in both lists alongside `orderless' --- a
;; real regression, not a guess: the previous setup (`fido-vertical-mode''s own
;; `(basic partial-completion flex)') included it, and `C-x p f' (`project-find-
;; file', Emacs's own built-in finder, distinct from this config's `C-c f f')
;; relies on exactly this fuzzy/skeleton matching; `tests/ert/java-navigation.el's
;; own `jnav/a-partial-name-finds-the-file-by-fuzzy-matching' failed for real
;; without it, since `orderless''s own default matching styles (literal and
;; regexp only) do not reproduce that kind of match on their own.
;;
;; `file' completion is otherwise kept off `orderless' specifically: out-of-order,
;; space-separated matching is far more useful for commands and buffer names than
;; for file paths, where it can match surprising things. This config's own fast
;; finder (`C-c f f', fastfind.el) is unaffected either way --- it sets its own,
;; completely separate completion style for its one minibuffer session, which
;; takes priority over whatever the global default is.
(if (and (locate-library "vertico") (locate-library "orderless") (locate-library "marginalia"))
    (progn
      (require 'vertico)
      (require 'orderless)
      (require 'marginalia)
      (vertico-mode 1)
      (marginalia-mode 1)
      (setq completion-styles '(orderless basic flex)
            completion-category-overrides '((file (styles basic partial-completion flex)))))
  (fido-vertical-mode 1))               ; fallback: minibuffer completion, vertical list, all built in
(setq completion-ignore-case t
      read-file-name-completion-ignore-case t)
(global-completion-preview-mode 1)      ; inline suggestions as you type

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
;;   C-c f a  anywhere on the disk, asynchronously (Consult/fd, never blocks)
;;   C-c f r  rebuild the whole-disk index now
;; Autoloaded by full path: putting `user-emacs-directory' itself on `load-path' makes
;; Emacs print a startup warning.
(defconst my/ff-library (expand-file-name "fastfind" user-emacs-directory))
(autoload 'my/ff-find-file my/ff-library "Find a file in the current project." t)
(autoload 'my/ff-find-file-global my/ff-library "Find a file anywhere on the disk." t)
(autoload 'my/ff-find-file-global-async my/ff-library
  "Find a file anywhere on the disk, asynchronously (Consult/fd)." t)
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

;;; Contextual actions, at point or on a candidate (embark) -----------------------

;; `C-.' shows a menu of actions for whatever is at point, or the current candidate
;; in an active minibuffer completion session (a file, a buffer, a package, a line
;; of a `grep'-like search, ...) --- open it, but also copy its name, delete it,
;; run a shell command on it, and more, all without leaving where you are first.
;; `C-;' skips the menu and runs the single most likely action directly. `C-h B'
;; shows every action available right now, as its own `which-key'-style menu.
;; `embark-consult' (config/elpa's own separate, tiny package) needs no wiring here
;; at all: Embark loads it automatically, on its own, once it notices Consult is
;; also loaded --- this is what makes `C-.' understand a `consult-ripgrep'/`consult-
;; buffer' candidate specifically (act on one search match without jumping to it
;; first), not just a generic minibuffer string. Installed into config/elpa by
;; `./build.sh packages'; nothing loads until first use. See docs/SEARCHING.md.
(when (locate-library "embark")
  (autoload 'embark-act "embark" "Choose an action for the thing at point, or the current minibuffer candidate." t)
  (autoload 'embark-dwim "embark" "Run the default action for the thing at point." t)
  (autoload 'embark-bindings "embark" "Show every action available right now." t))
(defun my/embark-missing ()
  (interactive)
  (message "Embark is not installed.  Run ./build.sh packages"))
(dolist (binding '(("C-." . embark-act) ("C-;" . embark-dwim) ("C-h B" . embark-bindings)))
  (global-set-key (kbd (car binding))
                  (if (locate-library "embark") (cdr binding) #'my/embark-missing)))

;;; Small navigation/search extras: avy, ace-window, wgrep, helpful, symbol-overlay ----

;; `avy' and `ace-window' were already on disk before this (pulled in as dependencies of
;; Treemacs), just never bound to a key --- `C-'' now jumps the cursor to any visible
;; spot by typing a few characters of it (stops as soon as what you typed is
;; unambiguous, or shows a letter to pick from when it isn't); `M-o' replaces the plain
;; `other-window' (cycle blindly through however many windows exist) with jumping
;; straight to one by a letter shown in it --- with only 2 windows open (the common
;; case), `ace-window' behaves exactly like `other-window' did, so nothing is lost. A
;; real, found-while-wiring-this-up conflict: `M-o' was already separately bound to
;; plain `other-window' in this file's own "Keys" section (a pre-existing, deliberate
;; shortcut from earlier work, unrelated to this change) --- since that section runs
;; *after* this one, it was silently winning and this binding never took effect on the
;; first attempt. Removed that older, now-redundant line rather than picking a
;; different key for this, since `ace-window' is a strict superset of what it did.
(when (locate-library "avy")
  (autoload 'avy-goto-char-timer "avy" "Jump to a visible spot by typing its first few characters." t))
(defun my/avy-missing ()
  (interactive)
  (message "avy is not installed.  Run ./build.sh packages"))
(global-set-key (kbd "C-'") (if (locate-library "avy") #'avy-goto-char-timer #'my/avy-missing))
(when (locate-library "ace-window")
  (autoload 'ace-window "ace-window" "Jump to a window by the letter shown in it." t))
(global-set-key (kbd "M-o") (if (locate-library "ace-window") #'ace-window #'other-window))

;; `wgrep' makes a `grep'-shaped results buffer (`M-x rgrep', or one `embark-export'
;; builds from a `consult-ripgrep'/`C-x p g' search) directly editable: fix something
;; across every matched file at once, `C-c C-p' to start editing, `C-c C-e' to save it
;; back to all of them, `C-c C-k' to discard.  WHY `with-eval-after-load' rather than a
;; plain `require': `wgrep' only ever needs to exist by the time a real `grep'-mode
;; buffer is first created, which needs `grep.el' itself loaded anyway --- piggybacking
;; on that means this never costs anything until a real search actually happens, the
;; same "nothing loads until used" rule every other feature here follows.  HOW: `wgrep'
;; wires itself into `grep-mode' entirely on its own, via `grep-setup-hook' (confirmed
;; directly in its own source, not assumed) --- once required, nothing more to bind by
;; hand.
(when (locate-library "wgrep")
  (with-eval-after-load 'grep (require 'wgrep)))
;; A real, found-while-testing-this interaction: every file this config opens locks
;; itself read-only by default (see "Every file opens read-only" below), and by default
;; `wgrep' silently REFUSES to save into a read-only buffer --- `wgrep-finish-edit' would
;; report "(0 changed)" with no further explanation, and the file on disk would just
;; never change, confirmed directly by editing a real match and finding the real file
;; untouched afterwards. `wgrep-change-readonly-file' is wgrep's own documented escape
;; hatch for exactly this (any read-only file, not just this config's own lock) --- set
;; here so it can, since running `wgrep-finish-edit' in the first place already IS the
;; one deliberate action this config's read-only lock exists to gate behind (the same
;; reasoning as the git-commit-message/Treemacs-persist exceptions in
;; `my/always-editable-file-regexp' above).
(setq wgrep-change-readonly-file t)

;; `helpful' replaces the plain `C-h f'/`v'/`k'/`o' pages with much richer ones: the
;; real source, every place that calls it, a live demo where one exists --- strictly
;; more information, same keys, so there is nothing new to learn to get it.
(when (locate-library "helpful")
  (autoload 'helpful-callable "helpful" "Describe a function, richly." t)
  (autoload 'helpful-variable "helpful" "Describe a variable, richly." t)
  (autoload 'helpful-key "helpful" "Describe a key's command, richly." t)
  (autoload 'helpful-symbol "helpful" "Describe whatever a symbol is, richly." t))
(dolist (binding '(("C-h f" . helpful-callable) ("C-h v" . helpful-variable)
                   ("C-h k" . helpful-key) ("C-h o" . helpful-symbol)))
  (when (locate-library "helpful") (global-set-key (kbd (car binding)) (cdr binding))))

;; `M-i' (`symbol-overlay-put') highlights every occurrence of whatever symbol the
;; cursor is on, right in the buffer, until pressed again --- `tab-to-tab-stop' (its
;; default binding, a legacy command from manual typewriter-style tab stops that is not
;; otherwise used here) is safely free for this, its own package's own suggested key.
(when (locate-library "symbol-overlay")
  (autoload 'symbol-overlay-put "symbol-overlay" "Highlight every occurrence of the symbol at point." t))
(global-set-key (kbd "M-i") (if (locate-library "symbol-overlay") #'symbol-overlay-put #'tab-to-tab-stop))

;;; Start screen ---------------------------------------------------------------

;; What Emacs shows when started without a file: the last 5 files, folders and projects,
;; each expandable with a "+ N more" link.  `C-c h' brings it back from anywhere.
;; See startpage.el and docs/START-SCREEN.md.
;; WHAT/WHY: unlike most other feature files in this config (dictate.el, llm.el, ...),
;; startpage.el is `require'd directly here, not autoloaded --- it has to be, since
;; Emacs needs `my/start-initial-buffer' to actually exist the moment startup decides
;; what buffer to show (see `initial-buffer-choice' just below), which happens far too
;; early for a lazy, first-keypress autoload to help.  HOW: `my/start-library' resolves
;; the file's path once, reused so the `require' below and any other reference to this
;; file's own location stay in sync automatically.
(defconst my/start-library (expand-file-name "startpage" user-emacs-directory))
(require 'startpage my/start-library)
;; WHAT/WHY/HOW: this is the actual hook Emacs's own startup sequence checks --- setting
;; `initial-buffer-choice' to a function (rather than a fixed buffer name or "*scratch*",
;; its usual default) means Emacs calls that function to decide what buffer to show,
;; letting `my/start-initial-buffer' itself decide (in startpage.el) whether to show the
;; start screen at all, versus deferring to a file given on the command line.
(setq initial-buffer-choice #'my/start-initial-buffer)

;;; Session: crash-safe auto-save, and restoring open buffers/windows next time -----

;; C-c w s saves the session by hand; C-c w r discards it (back to the plain start
;; screen). Every visited, edited buffer is also auto-saved to its real file as you
;; type, not just to a recovery shadow copy. No package: `desktop-save-mode' and
;; `auto-save-visited-mode', both built into Emacs. Loaded eagerly, right after the
;; start screen, for the same reason startpage.el is: restoring a saved session has to
;; happen during startup, too early for a lazy autoload to help. See
;; config/emacs-session.el (named that, not the shorter `session', to avoid a real
;; collision with a well-known third-party package Org has its own compatibility code
;; for --- see that file's own header comment) and docs/SESSION.md.
(require 'emacs-session (expand-file-name "emacs-session" user-emacs-directory))

;;; Shortcuts reference ----------------------------------------------------------

;; This configuration's own keybindings (not the built-in Emacs ones docs/KEYBOARD.md
;; teaches), grouped by topic, foldable: `C-c k' shows it anytime; it also appears
;; automatically, split next to the start screen, the first time Emacs opens with no
;; file given.  Loaded at startup (like startpage.el/docsbuffer.el) since that startup
;; split needs its content ready immediately.  See shortcuts.el and docs/KEYBOARD.md.
(require 'shortcuts (expand-file-name "shortcuts" user-emacs-directory))
(global-set-key (kbd "C-c k") #'my/shortcuts)

;;; News (newsticker) ----------------------------------------------------------------

;; `C-c n' shows real news headlines, grouped by feed, covering the popular categories:
;; Top Stories, World, USA, Business, Technology, Politics, Science, Health,
;; Entertainment and Sports --- each verified to be a real, currently-live RSS feed, not
;; assumed.  Built into Emacs (net/newsticker.el); fetched over Emacs's own networking
;; (`url-retrieve', `newsticker-retrieval-method' is `intern' by default) --- no external
;; `wget' needed, so this works the same on the Windows bundle.  Nothing loads, and no
;; network request happens, until `C-c n' is actually pressed.
;; WHAT: which feeds newsticker fetches.  WHY: one real, currently-live source per
;; popular category (each URL curl-verified live before being added, not just assumed)
;; rather than one single "top stories" feed, so `C-c n' groups headlines the same way a
;; real newspaper's own sections do --- see docs/SEARCH-OPTIONS.md's sibling docs for
;; this project's general "verify, don't assume" convention applied here too.  HOW:
;; `newsticker-url-list' is the built-in variable `newsticker-treeview' (bound below)
;; itself reads to know what to fetch --- this `setq' is the only configuration
;; newsticker needed, since everything else (grouping by feed, the treeview UI, `intern'
;; HTTP retrieval) is Emacs's own code, un-pruned from prune.list this session (it used
;; to be stripped out of this minimal build) rather than written here.
(setq newsticker-url-list
      '(("Top Stories"   "http://feeds.bbci.co.uk/news/rss.xml")
        ("World"         "http://feeds.bbci.co.uk/news/world/rss.xml")
        ("USA"           "https://rss.nytimes.com/services/xml/rss/nyt/US.xml")
        ("Business"      "http://feeds.bbci.co.uk/news/business/rss.xml")
        ("Technology"    "http://feeds.bbci.co.uk/news/technology/rss.xml")
        ("Politics"      "https://rss.nytimes.com/services/xml/rss/nyt/Politics.xml")
        ("Science"       "http://feeds.bbci.co.uk/news/science_and_environment/rss.xml")
        ("Health"        "http://feeds.bbci.co.uk/news/health/rss.xml")
        ("Entertainment" "http://feeds.bbci.co.uk/news/entertainment_and_arts/rss.xml")
        ("Sports"        "https://www.espn.com/espn/rss/news")))
;; WHAT/WHY/HOW: bind the key straight to the built-in command; no autoload wrapper is
;; needed here the way `my/dictate'/`my/llm-chat' below get one, because `newsticker-
;; treeview' is already a normal autoloaded `net/newst-treeview.el' entry point once
;; that file is on the load path (restored by un-pruning), so Emacs's own autoload
;; machinery handles "nothing loads until first use" automatically.
(global-set-key (kbd "C-c n") #'newsticker-treeview)

;;; Dictation (local Whisper) ----------------------------------------------------------

;; `C-c m' starts recording from the microphone; press it again to stop, transcribe, and
;; insert the result at point. Fully local (no cloud, no API key) via a self-built
;; whisper.cpp; nothing is bundled, so it declines clearly if that is not set up yet.
;; See config/dictate.el and docs/DICTATE.md.
;; WHAT: an `autoload' stub, not a `require'.  WHY: matches this file's own established
;; pattern (see `my/find-git-repos', `my/llm-chat' nearby) of never loading a whole
;; feature just to bind its key --- dictate.el itself, and the (potentially slow to
;; start) whisper-cli/model files it points at, are only ever touched the first time
;; `C-c m' is actually pressed.  HOW: `expand-file-name "dictate" user-emacs-directory'
;; resolves to config/dictate.el next to this file; the docstring here is shown by `C-h
;; f'/which-key before the real file has ever been loaded.
(autoload 'my/dictate (expand-file-name "dictate" user-emacs-directory)
  "Toggle dictation: start recording, or (pressed again) stop and insert the result." t)
(global-set-key (kbd "C-c m") #'my/dictate)
;; `C-c M' (capital) is LIVE dictation: text appears every few seconds while you are still
;; speaking, via a second whisper.cpp binary (`whisper-server') kept running, instead of
;; only once, all at once, when you stop.  Same autoload-stub reasoning as `C-c m' just
;; above --- nothing here loads until first pressed. See config/dictate.el and docs/DICTATE.md.
(autoload 'my/dictate-live (expand-file-name "dictate" user-emacs-directory)
  "Toggle live dictation: transcribed a few seconds at a time while you speak." t)
(global-set-key (kbd "C-c M") #'my/dictate-live)

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
;; WHAT: register a handful of Magit entry points as autoloads, only if Magit is actually
;; installed.  WHY: `locate-library' checks the package is present WITHOUT loading it, so
;; a machine that ran `./build.sh packages' without network access (Magit is one of the
;; optional installed packages, not bundled into this repo) still gets a working config
;; --- just with `C-x g' explaining why it can't run, via `my/magit-missing' below,
;; instead of `autoload' pointing at a file that doesn't exist and erroring obscurely.
;; HOW: each `autoload' names the real function, the literal package file it lives in
;; ("magit", one file among several this package ships), a docstring shown before the
;; real file has ever loaded, and `t' (interactive) so it can be bound to a key/called
;; with `M-x' immediately, before Magit itself has actually been loaded even once.
(when (locate-library "magit")
  (autoload 'magit-status "magit" "Show the status of the current Git repository." t)
  (autoload 'magit-dispatch "magit" "Show all Magit commands." t)
  (autoload 'magit-file-dispatch "magit" "Show Magit commands for this file." t)
  (autoload 'magit-log-buffer-file "magit" "Show the history of this file." t))
;; WHAT/WHY/HOW: the "Magit isn't installed" fallback command --- bound instead of the
;; real Magit commands whenever `locate-library "magit"' comes back nil, so pressing
;; `C-x g'/`C-c g' on a machine without Magit gives a clear, one-line explanation in the
;; echo area (with the exact command to fix it) rather than a "void function" error.
(defun my/magit-missing ()
  (interactive)
  (message "Magit is not installed.  Run ./build.sh packages"))
;; WHAT/WHY/HOW: `C-x g' (Magit's own conventional global keybinding, kept as-is rather
;; than moved under this config's own `C-c' prefix) opens the repository status buffer;
;; `C-c g' opens the file-specific command menu for whatever buffer you're currently in.
;; Both use the same "bind the real command if available, else the explainer" pattern as
;; `C-c a a'/`C-c a m'/`C-c a c' further down this file for gptel.
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
  (autoload 'gptel-menu "gptel-transient" "Menu: pick a model, backend or system prompt." t)
  ;; WHAT: make Ollama the default backend the moment `gptel' is touched at all, however
  ;; that happens --- not only via `my/llm-chat' (`C-c a a').  WHY: a real, reported
  ;; problem --- `gptel' ships with its own factory default backend, "ChatGPT" (a real
  ;; OpenAI endpoint), and this config deliberately never puts an API key anywhere;
  ;; reaching `gptel' through `C-c a m' first (which autoloads `gptel-transient' directly
  ;; --- see just above --- and never touches `config/llm.el' at all before that) hit
  ;; that untouched default and failed with a real "401 Unauthorized" the moment anything
  ;; was actually sent.  HOW: this has to live here, at the top level of `init.el' (always
  ;; loaded), not inside `config/llm.el' itself --- that file is *itself* lazily
  ;; autoloaded (only the first time `my/llm-chat'/`my/llm-council' runs), so a
  ;; `with-eval-after-load' hook registered inside it would never even be registered yet
  ;; if `gptel' were reached some other way first, exactly the bug this fixes. Costs
  ;; nothing at startup either way: `with-eval-after-load' only registers a callback,
  ;; and `(require 'llm ...)' inside it does not run until `gptel' itself actually loads.
  (with-eval-after-load 'gptel
    (require 'llm (expand-file-name "llm" user-emacs-directory))
    (my/llm-setup-ollama)))
(autoload 'my/llm-chat (expand-file-name "llm" user-emacs-directory)
  "Open a chat buffer with the local Ollama backend." t)
;; `C-c a c' asks three different local models the same question in parallel, then has a
;; fourth, bigger model compare and summarize their answers --- the summary shows up
;; expanded, each model's own answer folded shut below it. See config/llm-council.el.
;; WHAT/WHY/HOW: autoloaded the same way as `my/llm-chat' just above, and for the same
;; reason --- config/llm-council.el (and the `require's it does at the top of itself,
;; including this same `llm.el') only actually loads the first time `C-c a c' is used.
(autoload 'my/llm-council (expand-file-name "llm-council" user-emacs-directory)
  "Ask several local models at once, then have a bigger one summarize." t)
(defun my/llm-missing ()
  (interactive)
  (message "gptel is not installed.  Run ./build.sh packages"))
(global-set-key (kbd "C-c a a") (if (locate-library "gptel") #'my/llm-chat #'my/llm-missing))
(global-set-key (kbd "C-c a m") (if (locate-library "gptel") #'gptel-menu #'my/llm-missing))
;; WHAT/WHY: same "bind to the real command if gptel is installed, otherwise to a command
;; that just explains why not" pattern as the two lines above it --- `my/llm-council'
;; itself calls `(require 'gptel)' and would error confusingly if gptel were missing, so
;; this check happens here, once, before the key is even bound.
(global-set-key (kbd "C-c a c") (if (locate-library "gptel") #'my/llm-council #'my/llm-missing))

;;; Keys ---------------------------------------------------------------------

(global-set-key (kbd "C-c f f") #'my/ff-find-file)
(global-set-key (kbd "C-c f g") #'my/ff-find-file-global)
;; Same "bind to the real command if its dependency is installed, otherwise to a command
;; that just explains why not" pattern as `C-c a c' above --- `my/ff-find-file-global-
;; async' itself also declines clearly if called some other way (`M-x'), but binding it
;; to `my/consult-missing' here means the key itself never even reaches that far.
(global-set-key (kbd "C-c f a") (if (locate-library "consult") #'my/ff-find-file-global-async #'my/consult-missing))
(global-set-key (kbd "C-c f r") #'my/ff-reindex)
(global-set-key (kbd "C-c f p") #'my/find-git-repos)
(global-set-key (kbd "C-c v") #'my/toggle-evil)
(global-set-key (kbd "C-x C-b") #'ibuffer)
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
