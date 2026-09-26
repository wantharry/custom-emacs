# Testing

The rule of this project: **run the tests after every change.** A change is not done
until `./build.sh test` says `ALL TESTS PASSED`.

```sh
./build.sh test                  # everything that works offline (about 5 seconds)
./build.sh test --network        # plus the tests that need internet
./build.sh test --lsp            # plus tests that start real language servers
./build.sh test --full           # everything: network, language servers, tools/verify-prune.sh
./build.sh test dired            # only the ERT files whose name contains "dired"
EMACS=/path/to/emacs ./build.sh test     # test a different binary
```

`./build.sh test` is `tests/run-all.sh`. It prints one line per test file and a total,
and exits non-zero if anything fails.

To make git enforce it, enable the bundled hook once per clone:

```sh
git config core.hooksPath .githooks
```

Then every `git commit` runs the offline suite first and aborts if it fails
(`git commit --no-verify` skips it in an emergency).

## What is covered

Tests are grouped by **subsystem of Emacs**, then by project concern. Each file in
`tests/ert/` uses Emacs's own test framework (ERT); the Python files in `tests/` test
the tooling.

### Emacs itself

| File | Covers |
|---|---|
| `build-features.el` | What this build can do: native compilation (a function is really compiled and runs), byte compilation, tree-sitter, SQLite, GnuTLS, libxml, modules, threads, the portable dump, the GTK toolkit |
| `buffers-text.el` | Buffers: insertion, deletion, undo, narrowing, markers, text properties, overlays, buffer-local variables, buffer lifecycle, line arithmetic, `thing-at-point` |
| `editing-commands.el` | Kill and yank, case, transposition, whitespace, electric pairing, replacing a selection, comments, indentation, filling, sorting, rectangles, registers, keyboard macros |
| `search-regex.el` | Regexp search with groups, case folding, replacement, `rx`, `regexp-opt`, bounded search, `keep-lines`/`flush-lines`, string search and splitting |
| `files-dired.el` | Writing and reading, final newline on save, backups (and where they go), no lock files, auto-revert picking up external changes, Dired listings, copy/rename/delete, symlinks, name manipulation, recent files |
| `processes.el` | `call-process`, exit status, environment, stdin, asynchronous processes with filters and sentinels, sending input, killing, timers |
| `encoding-text.el` | UTF-8 and Latin-1, byte lengths, encoding detection, display widths, Unicode case conversion, base64, known hash vectors, character properties |
| `lisp-runtime.el` | Closures, dynamic binding, `pcase`, `seq`/`cl-lib`, hooks, advice, errors and `unwind-protect`, bignums, `format`, minor modes, macros, `setf`, hash tables, threads and mutexes |
| `language-modes.el` | Mode chosen by extension, file name and shebang; Python, Emacs Lisp, C, JavaScript, JSON, shell: indentation, highlighting, imenu, comments |
| `treesit.el` | The tree-sitter engine and clean failure with no grammar (grammar-dependent tests skip themselves until a grammar is installed) |
| `vc-diff.el` | Git repositories created on the fly: root, file state, working revision; diff hunks; merge-conflict resolution |
| `project-eglot.el` | `project`, `xref` (and finding real definitions), `eldoc`, Flymake, the Eglot client |
| `network-data.el` | URL parsing and encoding, JSON, XML, HTML, SQLite (queries and rollback), a real TCP client and server over loopback |
| `calendar-calc-help.el` | Calendar arithmetic, calc, time formatting and parsing, documentation and help, Info manuals, Customize |
| `tramp.el` | Remote file-name parsing and arithmetic (no connection is made) |
| `mail-shr.el` | Address and header parsing, message headers, encoded words, MIME types, HTML rendering with links |

### This project

| File | Covers |
|---|---|
| `config.el` | Every setting in `init.el`/`early-init.el` takes effect; the files are well formed |
| `startup-perf.el` | Startup under half a second; `package.el`, Evil and third-party code **not** loaded at startup |
| `evil.el` | The `C-c v` toggle: on, off, repeatable, states, motions and operators, restores plain Emacs keys, Emacs keys still work, and a regression test for the Emacs 32 incompatibility |
| `evil-missing.el` | The toggle when Evil is not installed: declining, and accepting the install |
| `readonly.el` | Every kind of file (existing, new, symlinked) opens read-only; the disk is never touched; `allow-editing`/`stop-editing` work and only saving reaches the disk; nothing can unlock a buffer behind our back; `C-x C-q` twenty mistyped editing shortcuts change nothing (including under Evil); the `C-c e e` / `C-c e l` chords work in every mode (Dired, ibuffer, Java, Rust, Evil) and nothing shorter unlocks a file; Customize, recent files and file operations keep working |
| `keybindings.el` | **Every key in `docs/KEYBOARD.md`** (global, Dired, wdired, ibuffer, isearch, minibuffer, Lisp mode, Evil) is bound to the command the guide says |
| `languages-java-rust.el` | Java and Rust: tree-sitter modes, parsing, highlighting, indentation, imenu, server setup, no servers started on open, the toolchains compile and run; with `--lsp`, real `rust-analyzer` and `jdtls` sessions through Eglot |
| `pruning.el` | Removed packages are gone, coding essentials and deliberate exceptions are present, removed features fail cleanly, no native code left for them |
| `network-live.el` | Real HTTPS fetch, package refresh, package install (only with `--network`) |
| `tests/test_prune.py` | The pruning tool, using small fake trees: dependency rescue, lazy requires, exceptions, preloaded files, applying to an install, idempotence |
| `tests/test_repo.py` | Docs links and anchors, every guide listed in the README, script syntax, ignore rules, `prune.list` syntax, and the test suite's own conventions |

## How a test file is run

Each file starts with a header naming its **harness**:

| Header | Emacs is started as | Used for |
|---|---|---|
| `;; harness: bare` | `emacs -Q` (no config) | Emacs behavior that should not depend on our settings |
| `;; harness: config` | our `init.el` loaded from a temporary copy, with `config/elpa` linked in | Anything our configuration affects |
| `;; harness: noelpa` | same, but with no packages installed | The "Evil is missing" paths |

Files run in parallel, each in its own Emacs process, so tests cannot interfere with
one another. A temporary copy of the config is used so tests never write backups or
history into `config/`.

`tests/ert/helper.el` provides the shared tools:

| Helper | Use |
|---|---|
| `test-in-buffer MODE TEXT ...` | run code in a real buffer (shown in the selected window) |
| `test-with-temp-dir VAR ...` | a temporary directory that is deleted afterwards |
| `test-write-file`, `test-read-file` | file fixtures |
| `test-git DIR ARGS...` | run git with a fixed identity |
| `test-skip-unless-network`, `test-skip-unless-pruned` | skip a test when it does not apply |

## Adding a test

1. Pick the file for the subsystem (or create `tests/ert/NAME.el` with a
   `;; harness:` header and `lexical-binding: t`).
2. Name it `area/what-it-checks`. Names must be unique across files (a Python test
   enforces this, and the `area/` prefix).
3. Test **behavior**, not just that a function exists.
4. Run `./build.sh test NAME`, then the whole suite.

**When you find a bug, add the test that would have caught it first**, then fix it.
That has already happened three times here:

| Bug | Caught by |
|---|---|
| Pruning removed `mm-archive`, which broke package downloads | `network-live.el` and `tools/verify-prune.sh` |
| Evil 1.15 raises `void-variable evil-mode-buffers` on Emacs 32 | `evil/no-post-command-hook-errors-on-emacs-32` |
| `package.el` at startup costs ~0.7 s on WSL (Windows drives on `PATH`) | `startup-perf.el` tests |

## Things the tests found along the way

These are worth knowing; each is now covered by a test or a note.

- **Batch mode hides problems.** It does not run `post-command-hook`, so the Evil
  incompatibility only appears when a test runs those hooks explicitly. It also
  never switches globalized modes on for file buffers (true on Emacs 29 as well), so
  auto-revert is tested by behavior rather than by checking the mode variable.
- **Keyboard macros act on the window's buffer**, not the current buffer, so
  `test-in-buffer` displays its buffer in the selected window.
- **Some Emacs rules bite tests:** files under `/tmp` are never backed up;
  `vc-state` needs `default-directory` set to the file's directory; batch frames are
  narrow, so rendered text wraps.
- **Installed Lisp is byte-compiled**, so argument names are lost. Test help on
  functions defined inside the test.

## What the tests cannot tell you

- **Anything visual:** colors, fonts, icons, the mode line. There is no display in
  batch mode. Check these by eye.
- **Real language servers and tree-sitter grammars**, until they are installed.
  Grammar-dependent tests skip and will start running by themselves.
- **Windows and macOS.** Nothing here has been run there.
- **Interactive timing and feel.** `startup-perf.el` catches gross startup
  regressions only.

`--network` and `--full` add the real-download tests and the pruning verifier
(`tools/verify-prune.sh`, described in [PRUNING.md](PRUNING.md)).
