# Java and Rust (full support), and HTML/CSS/JS/TS/JSX/JSON (editing only, so far)

Status as of 2026-09-27, on Ubuntu 24.04 (WSL2), Emacs 32.0.50. Everything below marked
*measured* was run here.

## What is set up

| Piece | What it does | How it got here | Where |
|---|---|---|---|
| JDK 25 | compile and run Java | already installed (`apt`) | `/usr/bin/java` |
| Rust 1.98.1 (`rustc`, `cargo`, `rustup`) | compile and run Rust | already installed (`rustup`) | `~/.cargo/bin` |
| `rust-analyzer` 1.98.1 | Rust language server | `rustup component add rust-analyzer` | `~/.rustup` |
| `jdtls` 1.61.0 | Java language server (Eclipse JDT) | downloaded, SHA-256 checked against the published value | `~/.local/share/jdtls`, launcher `~/.local/bin/jdtls` |
| tree-sitter grammar `java` v0.23.5 | accurate highlighting, indentation, navigation | `./build.sh grammars` | `config/tree-sitter/` (gitignored) |
| tree-sitter grammar `rust` v0.23.2 | same, for Rust | same | same |
| `config/init.el` "Languages" section | pins grammar versions, remaps `.java` to `java-ts-mode`, keeps servers manual | this repo | tracked |

Nothing was installed with `sudo`. Nothing extra is bundled into Emacs itself.

## Does it make Emacs slow?

**No.** Language support costs nothing until you open a Java or Rust file, and the
language servers cost nothing until you start one.

| What | Result (measured) |
|---|---|
| Emacs startup with the grammars installed | **0.05 s**, 68 MB (identical without them). Neither tree-sitter nor Eglot is loaded at startup |
| Opening and fully highlighting a 6,306-line Java file, classic `java-mode` | 1.28 s |
| The same file, tree-sitter `java-ts-mode` | **0.106 s** (about 12 times faster) |
| A 5,401-line Rust file, `rust-ts-mode` | 0.192 s |
| `rust-analyzer` (started with `M-x eglot`): connect and first answer | **0.02 s**; about 340 MB while active (311 MB + a 26 MB helper) |
| `jdtls` (Java): connect | **2.7 s**; first symbols 3.7 s; **about 1.35 GB** (a JVM); 25 MB of cache in `~/.cache/jdtls` |
| Emacs itself while a server runs | 74 to 76 MB, unchanged |

How to read these:

- The highlighting times force the **whole** file to be highlighted. Emacs normally
  highlights only the part on screen, so real opening is faster than these numbers. The
  comparison between the two modes is what matters: tree-sitter is much faster on big
  Java files.
- The cost of a language server is **memory and start-up delay**, not editor speed. The
  server is a separate process; typing in Emacs is not slowed by it.
- Servers are **never started automatically** (`M-x eglot` starts one). That is
  deliberate: `jdtls` is a 1.35 GB JVM and most editing does not need it.
- These were small demo projects. A large Rust workspace (many dependencies) or a large
  Maven or Gradle project makes the servers use more memory and take longer to index. The
  machine here has 16 GB, about 8.7 GB free.

## Using it

1. Open a file. `.java` opens in `java-ts-mode` and `.rs` in `rust-ts-mode`.
2. For completion, diagnostics and jump-to-definition, run `M-x eglot`. It finds the
   project and starts the right server. Give `jdtls` a few seconds.
3. Use the normal keys: `M-.` (definition), `M-,` (back), `M-?` (references),
   `C-M-i` (complete), `C-x p f` (find file in project). See [KEYBOARD.md](KEYBOARD.md).
4. `M-x eglot-shutdown` stops the server and frees its memory. Eglot also stops it when
   you close the last buffer of the project (`eglot-autoshutdown`).

Handy Eglot commands (no default keys): `eglot-rename`, `eglot-code-actions`,
`eglot-format`, `eglot-find-implementation`, `eglot-find-type-definition`,
`eglot-reconnect`, `eglot-events-buffer` (protocol log, off by default for speed).

Three small demo projects live in `~/emacs-demo/` to try all this on: `hello-java/Hello.java`,
`hello-rust/`, and `java-project/`, a multi-file Java project used for navigation (see
[NAVIGATING-CODE.md](NAVIGATING-CODE.md)).

## Setting it up again from scratch

```sh
# Java: a JDK 21 or newer (jdtls needs it)
sudo apt-get install -y openjdk-21-jdk        # or any newer JDK

# Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
rustup component add rust-analyzer            # the file in ~/.cargo/bin is only a stub until this

# jdtls (no sudo)
B=https://download.eclipse.org/jdtls/milestones/1.61.0
f=$(curl -sL $B/latest.txt)
curl -sLO $B/$f && curl -sLO $B/$f.sha256 && sha256sum -c <(echo "$(cut -d' ' -f1 $f.sha256)  $f")
mkdir -p ~/.local/share/jdtls/1.61.0 && tar -xzf $f -C ~/.local/share/jdtls/1.61.0
ln -sf ~/.local/share/jdtls/1.61.0/bin/jdtls ~/.local/bin/jdtls   # ~/.local/bin must be on PATH

# tree-sitter grammars (needs git and a C compiler)
./build.sh grammars
```

## Why the grammars are pinned

A tree-sitter grammar is compiled against a parser format version (the "ABI"). The
tree-sitter library on this machine (0.20.x) loads ABI 14 and older. The newest
tagged releases of the Rust grammar are newer than that, so `init.el` pins
**Java v0.23.5** and **Rust v0.23.2**, and `./build.sh grammars` reports each grammar's
ABI next to the library's limit (both 14 here). If you upgrade the tree-sitter
library, you can move the pins forward. `M-x treesit-install-language-grammar` uses the
same pinned list.

## Adding another language

1. Add its grammar to `treesit-language-source-alist` in `config/init.el`
   (a pinned tag) and run `./build.sh grammars`.
2. If Emacs does not switch to the `-ts-mode` by itself, add a `major-mode-remap-alist`
   entry guarded by `treesit-language-available-p`, as for Java.
3. Install its language server; Eglot already knows many by name
   (`M-x describe-variable eglot-server-programs`).
4. Add tests to `tests/ert/languages-*.el` and run `./build.sh test`.

## Tests

`tests/ert/languages-java-rust.el` covers the modes chosen, parsing, highlighting,
indentation, comments, imenu, function-at-point, the server configuration, that opening
files starts no servers, and that the Java and Rust toolchains really compile and run.
Two more tests start the real servers and check they answer through Eglot; they run only
with `./build.sh test --lsp` (about 5 seconds for these two; the Java navigation tests in
`java-navigation.el` add about 80 seconds, because each newly opened file takes the server a few
seconds to analyze). A separate test **fails** (it does not skip)
if a grammar is missing, so a broken install cannot hide behind skipped tests.

## HTML, CSS, JavaScript/JSX, TypeScript/TSX and JSON

These get accurate, fast tree-sitter highlighting, indentation and imenu the same way Java and
Rust do. On most branches that is all they get --- **no language server** (no autocomplete, no
go-to-definition): the servers that would provide that (`typescript-language-server`,
`vscode-html/css-language-server`) are npm packages needing a Node.js runtime, which this
project does not bundle; see `git log` for the tradeoffs considered.

**The `dev-ui` branch is the exception**: real LSP support for all of these, plus Angular, is
wired in --- see "Real LSP for the web/UI languages (`dev-ui` branch)" below. Everywhere else,
this is a real, complete phase on its own:

| Piece | Grammar | Mode (needs the grammar) | Remap needed? |
|---|---|---|---|
| HTML | `html` v0.23.2 | `mhtml-ts-mode` | yes (`mhtml-mode` has a working legacy mode) |
| CSS | `css` v0.23.2 | `css-ts-mode` | yes (`css-mode` has a working legacy mode) |
| JavaScript/JSX | `javascript` v0.23.1 (+ `jsdoc` v0.23.2, for comments) | `js-ts-mode` | yes, from `javascript-mode` (the real mode `.js`/`.jsx` open in, not `js-mode` itself) |
| TypeScript | `typescript` v0.23.2 | `typescript-ts-mode` | **no** --- core Emacs has no legacy TypeScript mode, so `.ts` maps straight to this |
| TSX | `tsx` v0.23.2 | `tsx-ts-mode` | **no**, same as TypeScript |
| JSON | `json` v0.23.0 | `json-ts-mode` | yes (`js-json-mode` has a working legacy mode) |

Without its grammar installed, `.ts`/`.tsx` fall back to plain `fundamental-mode` (no
highlighting at all) --- a strictly worse fallback than Java/Rust/JS/CSS/HTML/JSON get, since
core Emacs ships no legacy TypeScript mode to fall back to.

All seven grammars install at parser ABI 14, matching the same library ceiling as Java and
Rust; see `tests/ert/languages-web.el` for real parse/highlight/indent/comment/imenu checks
(26 tests, a hard failure rather than a skip if a grammar is missing) and
`tests/gui/gui-tests.el`'s `gui/web-languages-source-is-drawn-in-color` for a real colored
window. Verified for real on the Windows bundle too (correct mode and real tree-sitter parsers
for `.js`/`.ts`/`.css`/`.html`), which carries the same grammars, cross-compiled with zig.

## Real LSP for the web/UI languages (`dev-ui` branch)

This branch exists for frontend/web work (JavaScript, TypeScript, React, Next.js, Angular ---
React and Next.js are not separate language servers, just TS/JS/JSX/TSX under a framework, so
nothing extra is needed for either). Confirmed directly in Eglot's own `eglot-server-programs'
(not assumed): it already knows `typescript-language-server' by name for every JS/TS/JSX/TSX
mode, and `vscode-css-language-server' for CSS --- the only real gap was `mhtml-ts-mode' (this
config's own HTML remap), missing from Eglot's `html-mode'-only entry, added in `config/
init.el'.

None of these servers are bundled with Emacs or Node itself --- an npm ecosystem needing a real
Node.js runtime, the same reason this project does not bundle Java's JDK either. Installed
locally into `tools/node-lsp/' (its own `package.json', committed; `node_modules/' is not,
`npm install` there to get them) instead of system-wide, the same "self-contained, not system-
wide" shape as `config/elpa'/`dist/.venv' elsewhere in this project; `tools/node-lsp/node_modules/
.bin' is added to `exec-path' so Eglot's own existing lookup-by-name finds them.

**Angular** is the one genuinely separate case: `@angular/language-server' (`ngserver') replaces
both the TS and HTML servers entirely inside an Angular workspace (confirmed in its own
documentation), understanding Angular template syntax and component decorators neither plain
server knows about. `config/init.el''s `my/angular-project-root' detects this via `angular.json'
(the one reliable marker `ng new' always creates) and dispatches to `ngserver', pointed at the
PROJECT's own `node_modules' (it needs the project's own `@angular/language-service'/
`typescript' versions, not this branch's `tools/node-lsp/') --- not verified end to end against
a real Angular workspace (none was available to test against directly); a known, documented
inefficiency even when it is right: because Eglot keys a server by its own static list of
managed major modes, and the TS-family/HTML-family modes are necessarily two separate
`eglot-server-programs' entries (Eglot's own defaults already split them the same way), an
Angular project opened with both a `.ts' and a `.html' file runs two separate `ngserver'
processes instead of one shared one.

`C-c i': runs one of the current project's `package.json' `"scripts"' (`C-c i r', prompts for
which one) or `npm install' (`C-c i i') --- the npm equivalent of Maven's `C-c j' on the
`lsp-java' branch, shaped differently on purpose: Maven's goals are standardized across every
Java project, so separate keys per goal make sense; npm scripts are whatever each project's
own `package.json' happens to define, so picking from the real list beats guessing which
goal-shaped keys to hardcode.

## Express and NestJS

Both are just TypeScript/JavaScript under a framework, like React/Next.js above --- the
`typescript-language-server' wiring already covers them, including real decorator/type
support (`@Controller()'/`@Injectable()'/etc., confirmed directly against real `@nestjs/
common' types, not assumed: zero diagnostics on a real decorated controller file). Express
needs nothing beyond that; NestJS additionally gets its own CLI (`@nestjs/cli' plus its real
dependency `@nestjs/schematics', installed into this branch's own `tools/node-lsp/' the same
way the language servers are --- not a separate directory, despite the name, since the
`exec-path'/`PATH' wiring already covers it either way):

`C-c i n': `nest generate', prompting for a schematic (controller/service/module/guard/...,
Nest's own documented set) and a name --- confirmed for real against an actual scaffolded
Nest project: it creates the right file AND updates the owning module's `imports'/
`providers'/`controllers' array automatically, the same as running it from a real terminal.

`C-c i a': `ng generate' (Angular's own CLI, `@angular/cli', the same install location as
above), the same shape as `C-c i n' --- a schematic (component/directive/pipe/service/...,
Angular's own documented set that takes a plain name; `config'/`environments'/`service-
worker'/`app-shell'/`application'/`ai-config' are left out on purpose, since each of those
is workspace-level or takes different arguments) and a name. Confirmed for real against an
actual scaffolded Angular project: creates the right files, the same as a real terminal.

A real, confirmed gap fixed along the way: `exec-path' alone is not enough for `compile'/
`shell-command'-style invocations (every command above) --- they run through a real shell
subprocess, which does its own PATH lookup from the `PATH' environment variable, never
consulting Emacs's `exec-path'. `nest generate' failed with a plain shell "command not
found" until `setenv' was added alongside `add-to-list' on `exec-path'.

Two more real gaps, found getting `ng generate' working specifically: the latest
`@angular/cli' needs Node >=22.22.3, and this machine's own system Node (root-owned) was
22.22.0 --- rather than needing root to upgrade the real system Node (which other things on
this machine may depend on staying as it is), a real, checksum-verified Node release was
downloaded directly from nodejs.org into this branch's own `tools/node/', put FIRST on both
`exec-path' and `PATH' so every tool's own `#!/usr/bin/env node' shebang resolves to it.
Separately, the Angular CLI's very first invocation on a machine asks interactively whether
to share usage analytics, which just hangs a `compile' buffer forever waiting for a y/N
keypress it never sends --- `(setenv "NG_CLI_ANALYTICS" "false")' is the CLI's own
documented way to skip that prompt outright.

See `tests/ert/languages-web-lsp.el' for the real checks (wiring, Angular detection and
dispatch, the npm/nest/ng commands --- including real `nest generate'/`ng generate' runs
against real scaffolded projects --- and two tests --- `./build.sh test --lsp' only --- that start the
real servers and confirm they answer through Eglot).

## Known limits

- Highlighting and indentation were checked by tests, **not by eye**; look at a real file.
- No debugger (DAP) and no Maven or Gradle installed; `jdtls` handles Maven and Gradle
  projects it finds, but that path is untested here.
- Java projects **without a build file** need the source root declared. The config sets a default
  for `src/main/java` and `src`; other layouts need a `.dir-locals.el` (see
  [NAVIGATING-CODE.md](NAVIGATING-CODE.md)). Projects with a `pom.xml` or `build.gradle` should not
  need it, but that path was not tested here.
- Grammars and servers are per platform. This page's own measurements are Linux/WSL only; the
  Windows bundle carries the same grammars (cross-compiled) and `jdtls`, verified separately
  (see [DISTRIBUTION.md](DISTRIBUTION.md)). Nothing here has been tried on macOS.
