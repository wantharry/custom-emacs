;;; lsp-java.el --- lsp-mode + lsp-java: a deeper Java IDE, as an alternative to eglot+jdtls  -*- lexical-binding: t; -*-

;; `C-c L' starts it for the current buffer (refactoring, code generation, a visual
;; debugger, a test runner --- all beyond what the plain eglot+jdtls setup in init.el
;; offers). Research branch (`lsp-java'): this is deliberately a SEPARATE path from
;; init.el's own `my/bundled-jdtls-command' (eglot) --- nothing here replaces or
;; disables that; both exist side by side so either can be tried on the same files.
;; Like eglot, this is manual-start only (`C-c L', not a `java-mode-hook'), the same
;; "don't slow down opening a file just to maybe use an LSP later" philosophy the
;; eglot section already follows.
;;
;; WHAT lsp-java adds that eglot+jdtls does not, confirmed from its own README, not
;; assumed: refactorings (extract method/constant/field/parameter/local, organize
;; imports), code generation (toString, equals/hashCode, overrides, getters/setters),
;; a real visual debugger (`dap-mode'), a test-runner tree UI (`lsp-jt-browser'),
;; a dependency viewer, and (experimental) Spring Boot integration.
;;
;; Once `C-c L' has started it for a buffer, `C-c l' (lowercase, `lsp-keymap-prefix'
;; below) is lsp-mode's own full command menu --- rename, format, code actions,
;; workspace folders, and everything else lsp-mode itself binds; press it and wait a
;; moment for which-key (built into Emacs now) to show every option, rather than
;; this file hand-binding each one individually.
;;
;; Packages needed (`./build.sh packages'): lsp-mode, lsp-ui, lsp-treemacs, dap-mode,
;; lsp-java, flycheck, yasnippet (already pulled in elsewhere in this config).

;; WHAT: tells lsp-mode which prefix key to bind its own large command map under, once
;; `lsp-mode' (the minor mode) actually turns on in a buffer. WHY this exact key: `C-c
;; l' (lowercase) is lsp-mode's own documented, widely-used community convention ---
;; keeping it, rather than picking a different one, means anyone already familiar with
;; lsp-mode elsewhere needs nothing new to learn here. MUST be set before `lsp-mode' is
;; `require'd (it reads this variable once, at load time, to build its keymap), which
;; is why it is the very first real line in this file.
(setq lsp-keymap-prefix "C-c l")

;; WHAT: point `lsp-java' at the SAME bundled jdtls (and bundled JDK) the eglot section
;; in init.el already resolves, instead of letting `lsp-java' manage its own separate
;; download/copy of the identical server. WHY: confirmed directly (this session's own
;; research) that `lsp-java-server-install-dir' just needs to contain the standard
;; `plugins/org.eclipse.equinox.launcher_*.jar' + `config_<os>' layout any real
;; eclipse.jdt.ls distribution already has --- the exact layout `my/bundled-jdtls-dir'
;; (init.el) already points at --- so reusing it is a straight substitution, not a
;; guess; one bundled copy on Windows, not two. HOW: `my/bundled-jdtls-dir'/`my/
;; bundled-jdk-java' are both already defined in init.el (loaded before this file,
;; since `autoload' below only triggers once `C-c L' is actually pressed) --- this
;; function is only ever called from `my/lsp-java', at which point both exist.
;; Anywhere those return nil (not the bundled Windows build), `lsp-java' falls back to
;; its own default behavior: auto-download its own copy on first use.
(defun my/lsp-java--point-at-bundled-server ()
  "If this is the bundled Windows build, point lsp-java at the SAME jdtls/JDK the
eglot+jdtls section in init.el already uses, instead of a separate download."
  (when-let* ((dir (my/bundled-jdtls-dir))
              ((file-directory-p dir)))
    (setq lsp-java-server-install-dir (file-name-as-directory dir)))
  (when-let* ((java (my/bundled-jdk-java)))
    (setq lsp-java-java-path java)
    ;; WHAT: `lsp-java-java-path' only controls which JVM runs jdtls ITSELF; it
    ;; says nothing about which JDK jdtls should resolve `java.lang.*'/the rest
    ;; of `java.base' against for the PROJECT being analyzed --- a real, found-
    ;; by-reproducing-it gap, confirmed directly: without this, every single
    ;; class in a real project got a real compiler error, `Implicit super
    ;; constructor Object() is undefined', on every file --- jdtls could not
    ;; resolve `java.lang.Object' itself, with no project runtime configured at
    ;; all (`lsp-java-configuration-runtimes' defaults to nil). WHY `JavaSE-21'
    ;; specifically: the bundled JDK's own real major version (Adoptium Temurin
    ;; 21, `tools/dist-windows.sh''s own `JDK_VERSION'), not the project's lower
    ;; `maven.compiler.source' (17, in `examples/mavenproject/pom.xml') --- a
    ;; newer JDK compiling down to an older release level is standard and
    ;; already how `javac --release' itself works; jdtls does the equivalent.
    (setq lsp-java-configuration-runtimes
          (vector (list :name "JavaSE-21"
                        :path (directory-file-name (file-name-directory (directory-file-name (file-name-directory java))))
                        :default t)))))

;; WHAT: force `lsp-completion-mode' back on if it gets left off even after the
;; server genuinely supports completion. WHY needed at all, not a guess: confirmed
;; directly, this session, by instrumenting a real connection start to finish ---
;; real jdtls sends its own "Starting"/"Started"/"ServiceReady" status messages
;; MORE THAN ONCE during one real connection (a second "Starting 100%" interleaved
;; AFTER an earlier "Started"/"Ready", before the final "ServiceReady"), and
;; `textDocument/completion' is DYNAMICALLY registered (confirmed: absent from the
;; static `initialize' response, present only later via `client/registerCapability')
;; part way through that same sequence. `lsp-configure-hook' --- what `lsp-mode'
;; itself uses to turn `lsp-completion-mode' on --- fires repeatedly across that
;; whole sequence (18 times, confirmed, all within the same second, for one buffer),
;; and the two together race: completion was confirmed, directly, to still be OFF
;; 20+ seconds after a real successful connection, in the one java-mode buffer
;; actually open, despite `(lsp-feature? "textDocument/completion")' already
;; returning true partway through that same firing sequence --- lsp-mode's own
;; enable-on-hook logic landing on an "off" moment of jdtls's flip-flopping status,
;; not jdtls ever failing to offer completion at all. HOW: poll instead of trusting
;; a single hook firing to land at the right moment --- every 2s for up to a
;; minute, in THIS buffer specifically (closed over, checked live via
;; `buffer-live-p' so a since-closed buffer safely stops this), turn completion
;; back on the moment the feature is available but the mode is not already on.
(defun my/lsp-java--ensure-completion (buf deadline)
  (when (buffer-live-p buf)
    (with-current-buffer buf
      (when (and (bound-and-true-p lsp-mode)
                 (not (bound-and-true-p lsp-completion-mode))
                 (ignore-errors (lsp-feature? "textDocument/completion")))
        (lsp-completion-mode 1)))
    (unless (or (with-current-buffer buf (bound-and-true-p lsp-completion-mode))
                (> (float-time) deadline))
      (run-with-timer 2 nil #'my/lsp-java--ensure-completion buf deadline))))

;; WHAT: sanitize whatever `lsp-java--get-filename' (lsp-java's own upstream
;; function, computing the local cache filename for a `jdt://' class-file URI)
;; returns, before it is ever used as a real path. WHY: a real, reproduced user
;; bug, clicking into `System.out.println' (go-to-definition on a JDK MODULE
;; class) --- jdtls's own `jdt://' URIs are a pseudo-scheme, not real RFC3986,
;; and for a module class the query portion embeds the class path a SECOND
;; time with characters jdtls never escapes (confirmed directly, reconstructing
;; the real shape and tracing `lsp-java--get-filename''s own fallback regex
;; branch by hand: a literal `<' survives into the generated name). That branch
;; only strips `/' and `\\' from what it captures, nothing else --- so a `<'
;; reaches `with-temp-file' unchanged, and Windows/NTFS refuses outright to
;; create a file with `<' in its name (`"Invalid argument"', the exact real
;; error hit) --- breaking go-to-definition into ANY JDK module class on
;; Windows. HOW: replace every character Windows disallows in a filename (`< >
;; : " | ? *'; `/' and `\\' are already handled upstream) with `_' --- lossy,
;; but safe: this is only ever a local cache filename, never round-tripped back
;; into a real `jdt://' request (the real URI is saved separately, in the
;; `.metadata' sidecar file `lsp-java--resolve-uri' already writes).
;;
;; A SECOND, separate real bug in the same fallback branch, confirmed directly
;; from a real user screenshot after the above fix: the branch's own format,
;; `"%s(%s)"', NEVER ends in `.java' (it ends in the closing `)'), unlike the
;; branch-1 \"clean\" case which always does --- so `auto-mode-alist' (which
;; `find-file' uses to pick a major mode, matched by filename SUFFIX) never
;; matches `java-mode'/`java-ts-mode' for one of these buffers, and Emacs falls
;; back to plain `fundamental-mode': no syntax highlighting at all, confirmed
;; directly, a real screenshot of `System.java(_java.lang(System.class)' shown
;; completely uncolored next to a real, highlighted `.java' buffer for
;; comparison. HOW: force the sanitized name to end in `.java' whenever it
;; does not already --- cosmetically odd for one of these (`Foo(Bar).java'),
;; but this is purely a local cache filename no one reads by hand; being
;; highlighted correctly matters far more than how the name itself looks.
(defun my/lsp-java--sanitize-filename (filename)
  (let ((safe (replace-regexp-in-string "[<>:\"|?*]" "_" filename)))
    (if (string-suffix-p ".java" safe) safe (concat safe ".java"))))
(with-eval-after-load 'lsp-java
  (advice-add 'lsp-java--get-filename :filter-return #'my/lsp-java--sanitize-filename))

;;;###autoload
(defun my/lsp-java ()
  "Start the lsp-java Java IDE (refactoring, code generation, debugger, test runner)
for the current buffer --- the `lsp-java' branch's alternative to `M-x eglot' for
Java. Installs nothing by itself; run `./build.sh packages' first if any of lsp-mode/
lsp-ui/lsp-treemacs/dap-mode/lsp-java/flycheck is missing."
  (interactive)
  (unless (locate-library "lsp-java")
    (user-error "lsp-java is not installed.  Run ./build.sh packages"))
  (require 'yasnippet)
  (require 'flycheck)
  (require 'lsp-mode)
  ;; `lsp-mode.el' itself `require's only `lsp-protocol' (confirmed by reading its
  ;; own top of file) --- every other generic UI feature it auto-configures on
  ;; connect (modeline status, header-line breadcrumb, diagnostics, semantic
  ;; tokens) lives in its OWN separate file, each normally loaded on demand by a
  ;; real `package.el' autoload --- which this config does not use (packages are
  ;; put on `load-path' directly, `my/elpa-dir' in init.el, never through `package-
  ;; initialize'/`package-activate-all', the only thing that would also load each
  ;; package's own generated `-autoloads.el' and wire those up). Left unrequired,
  ;; `lsp-auto-configure' silently fails for each one with `(void-function ...)',
  ;; logged once per `lsp-configure-hook' firing rather than raised as a real
  ;; error --- confirmed directly, one at a time, each only surfacing once the
  ;; previous was fixed (`lsp-modeline-workspace-status-mode', then `lsp-
  ;; headerline-breadcrumb-mode'); required explicitly here instead of waiting for
  ;; the next one to surface the same way.
  (require 'lsp-modeline)
  (require 'lsp-headerline)
  (require 'lsp-diagnostics)
  (require 'lsp-semantic-tokens)
  (require 'lsp-icons)
  (require 'lsp-java)
  (my/lsp-java--point-at-bundled-server)
  ;; `lsp-auto-guess-root': without this, lsp-mode interactively asks "which project
  ;; root?" the first time any file in a not-yet-seen project is opened --- fine at
  ;; the keyboard, but there is no reason to ask when a `pom.xml'/`build.gradle' (the
  ;; markers `lsp-java' itself already knows to look for) makes the real root
  ;; unambiguous.
  (setq lsp-auto-guess-root t)
  (yas-minor-mode 1)
  (flycheck-mode 1)
  (lsp)
  (my/lsp-java--ensure-completion (current-buffer) (+ (float-time) 60))
  (when (locate-library "lsp-ui") (require 'lsp-ui) (lsp-ui-mode 1))
  (when (locate-library "dap-mode")
    (require 'dap-mode)
    ;; `dap-auto-configure-mode' calls `dap-ui-mode' and (via `dap-features->modes')
    ;; `dap-tooltip-mode' directly, but does not `require' the files those two
    ;; actually live in itself --- confirmed for real, not assumed: calling it
    ;; without these two first fails with `(void-function dap-ui-mode)' then
    ;; `(void-function dap-tooltip-mode)', both real errors this session hit
    ;; directly, one at a time, each only surfacing once the previous was fixed.
    (require 'dap-ui)
    (require 'dap-mouse)
    (require 'dap-java)
    (dap-auto-configure-mode 1))
  ;; WHAT: `C-c l g s' --- a symbols outline (tree of every class/method/field in the
  ;; current file). WHY added by hand: `lsp-mode''s own `lsp-command-map' (confirmed by
  ;; reading its source, not assumed) already wires up `lsp-treemacs-errors-list' (`C-c
  ;; l g e') and `lsp-treemacs-call-hierarchy' (`C-c l g h') under the same "g" (goto)
  ;; prefix automatically once `lsp-treemacs' is loaded --- but leaves `lsp-treemacs-
  ;; symbols' (along with references/implementations/type-hierarchy as trees, and the
  ;; Java dependency viewer) unbound, available only via `M-x'. `gs' was free in that
  ;; same "g" category, so extending the map lsp-mode itself already built is more
  ;; consistent than inventing a parallel one. The other unbound lsp-treemacs views
  ;; (`lsp-treemacs-references'/`-implementations'/`-type-hierarchy'/`-java-deps-list')
  ;; are left as `M-x'-only --- each already has a non-tree equivalent lsp-mode binds
  ;; itself (`gr'/`gi' call plain `xref'), so a tree view of the same thing is a nice-
  ;; to-have, not something used often enough to need its own key.
  (when (locate-library "lsp-treemacs")
    (require 'lsp-treemacs)
    (define-key lsp-command-map "gs" #'lsp-treemacs-symbols)))
