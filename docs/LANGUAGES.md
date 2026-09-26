# Java and Rust

Status as of 2026-09-25, on Ubuntu 24.04 (WSL2), Emacs 32.0.50. Everything below marked
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

## Known limits

- Highlighting and indentation were checked by tests, **not by eye**; look at a real file.
- No debugger (DAP) and no Maven or Gradle installed; `jdtls` handles Maven and Gradle
  projects it finds, but that path is untested here.
- Java projects **without a build file** need the source root declared. The config sets a default
  for `src/main/java` and `src`; other layouts need a `.dir-locals.el` (see
  [NAVIGATING-CODE.md](NAVIGATING-CODE.md)). Projects with a `pom.xml` or `build.gradle` should not
  need it, but that path was not tested here.
- Grammars and servers are per platform. Nothing here has been tried on Windows or macOS.
