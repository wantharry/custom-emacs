# lsp-java: a deeper Java IDE (research branch)

This is the `lsp-java` branch only --- a side-by-side alternative to the plain `eglot`+`jdtls` setup
[docs/EGLOT.md](EGLOT.md) already covers, not a replacement for it. Both exist on this branch; either can be
tried on the same files. `lsp-java` runs on top of `lsp-mode` (a separate, much larger LSP client than
Emacs's own built-in `eglot`) and brings real IDE features eglot+jdtls does not have on its own: refactoring,
code generation, a visual debugger, a test-runner tree, and a dependency viewer.

> **What is verified.** The server connection itself was tested for real, twice: once against the real jdtls
> already installed on the dev machine (Linux), and once against the actual delivered Windows bundle, both
> confirmed by the real `"LSP :: Connected to [jdtls:...]"` message, not assumed from the package's own docs.
> Two real upstream `dap-mode` bugs were found and fixed along the way (see below). The individual refactoring/
> codegen/test-runner commands listed below are lsp-java's own advertised features, not yet each verified one by
> one against a real server the way eglot's navigation commands were in EGLOT.md.

## 1. Start it

1. Open a `.java` file inside a real Maven (or Gradle) project --- one with a `pom.xml`/`build.gradle` at its
   root. `examples/mavenproject/` (bundled on this branch, 100 self-contained algorithm files, each already a
   complete one-file program) is a ready-made one to try it on, e.g.
   `examples/mavenproject/src/main/java/algorithms/sorting/BubbleSort.java`. A loose `.java` file with no
   project root will not connect --- lsp-java needs a real build file to anchor to, the same as eglot+jdtls.
2. Run **`C-c L`**.
3. Wait for the mode line to show `LSP[jdtls:<pid>]` --- that is the real connection, not just "command ran with
   no error." First connection takes a little while (the same jdtls JVM warm-up eglot's own section describes).

On the bundled Windows build, `C-c L` automatically reuses the exact same bundled `jdtls`/JDK the eglot section
already resolves (`my/bundled-jdtls-dir`/`my/bundled-jdk-java` in `init.el`) --- confirmed directly, including a
real end-to-end connection test against the actual delivered zip. One bundled server, not two separate
downloads. Off Windows (building from source), `lsp-java` falls back to its own default behavior: it offers to
download and manage its own copy of jdtls the first time, independent of whatever `jdtls` eglot might already
be using.

**A real, user-reported gotcha, not hypothetical**: `C-c L` only works on a `.java` buffer (`java-mode`/
`java-ts-mode`) --- pressing it while visiting `pom.xml` or any other non-Java file in the project does not
start a Java language server, since there is nothing Java-specific about that buffer's own major mode. Make
sure the buffer you are in is an actual `.java` file.

If it still shows *"Unable to find installed server supporting this file"* after a genuine `.java` buffer and a
real project root, the most likely cause (confirmed directly, this session) is a **stale Emacs session** ---
quit Emacs completely and relaunch `Emacs.exe` fresh, then try again. Loading this file once with an error
cached does not retry cleanly on its own.

## 2. What you get beyond eglot+jdtls

Confirmed from `lsp-java`'s own README, not assumed:

- **Refactoring**: `lsp-java-extract-method`, `lsp-java-extract-to-constant`, `lsp-java-create-field`/
  `-parameter`/`-local`, `lsp-java-add-unimplemented-methods`, `lsp-java-add-import`, `lsp-java-organize-imports`.
- **Code generation**: `lsp-java-generate-to-string`, `-generate-equals-and-hash-code`, `-generate-overrides`,
  `-generate-getters-and-setters`.
- **A real visual debugger** (`dap-mode`): breakpoints, step-through, variable inspection --- `M-x dap-debug`.
  Nothing like this exists in the plain eglot+jdtls setup at all.
- **A test-runner tree** (`lsp-jt`): `M-x lsp-jt-browser` opens a browsable tree of every test in the project;
  `x` runs the test(s) under point, `d` debugs them, `R` refreshes. `lsp-jt-report-open` opens the last report;
  `lsp-jt-lens-mode` adds inline run/debug buttons above each test method (needs `lsp-lens-mode`).
- **A dependency viewer**: `lsp-java-dependency-list`.
- **Spring Boot integration** (experimental, via STS4): live hovers from actually-running Spring apps, request-
  mapping/bean navigation, `.properties`/`.yml` validation and completion, `lsp-java-spring-initializr` to create
  a new Spring Boot project from inside Emacs. Not tried in this session.

## 3. Keys

Once `C-c L` has connected, `C-c l` (lowercase --- `lsp-keymap-prefix`, the same convention `lsp-mode` itself
documents and most of its users already know) is its own large command menu. Press it and pause for which-key
(built into Emacs) to show every available option; the table below is only the ones worth knowing by name.

| Key | Command | What it does |
|---|---|---|
| `C-c L` | `my/lsp-java` | **this branch:** start lsp-java for the current buffer |
| `C-c l w d` | `lsp-describe-session` | show workspace status, root folder, connected server |
| `C-c l = =` | `lsp-format-buffer` | format the whole buffer |
| `C-c l r o` | `lsp-organize-imports` | organize imports |
| `C-c l r r` | `lsp-rename` | rename the symbol at point, everywhere it is used |
| `C-c l g g` | `lsp-find-definition` | jump to the definition |
| `C-c l g r` | `lsp-find-references` | list every place the symbol is used |
| `C-c l g i` | `lsp-find-implementation` | list every implementation |
| `C-c l g e` | `lsp-treemacs-errors-list` | every diagnostic across the whole project, as a tree |
| `C-c l g h` | `lsp-treemacs-call-hierarchy` | who calls this function (or what it calls) |
| `C-c l g s` | `lsp-treemacs-symbols` | **this file's own addition:** a tree outline of every class/method/field in the current file --- `lsp-mode`'s own built-in map (`lsp-command-map`, confirmed by reading its source) already wires up `ge`/`gh` above the same way; `gs` was free in that same category |
| `C-c l h h` | `lsp-describe-thing-at-point` | documentation for the symbol at point |
| `C-c l a a` | `lsp-execute-code-action` | quick fixes / code actions at point |

Everything else (Java-specific refactoring/codegen, the test runner, the debugger, the dependency viewer) is
`M-x`-only for now --- see section 2 above for the exact command names.

## 4. Two real bugs found while setting this up

Both in `dap-mode` itself, not this config --- `dap-auto-configure-mode` calls `dap-ui-mode` and (via its own
`dap-features->modes` alist) `dap-tooltip-mode` directly, without `require`-ing the files those two actually
live in (`dap-ui.el`, `dap-mouse.el`). Calling it without those first fails outright with
`(void-function dap-ui-mode)`, then (once that one is fixed) `(void-function dap-tooltip-mode)` --- both hit
directly, one at a time, each only surfacing once the previous was fixed. `config/lsp-java.el` requires both
explicitly before calling `dap-auto-configure-mode`, working around the gap.

## 5. Size

The whole added package stack (`lsp-mode`, `lsp-ui`, `lsp-treemacs`, `dap-mode`, `lsp-java`, `flycheck`, plus
`posframe`, a real dependency) is about **6.8 MB** on disk --- `lsp-mode` itself is the largest single piece at
3.1 MB. Negligible next to the ~370 MB Windows bundle as a whole.
