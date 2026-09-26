# Customizing

Nearly all customization is Elisp in `config/`, which needs **no
recompiling**. See [ARCHITECTURE.md](ARCHITECTURE.md#where-a-change-belongs) for
when a change belongs in C instead.

## How the config is loaded

Run Emacs with `--init-directory=config` and it loads, in order:

1. `config/early-init.el`: before the window and the package system exist.
   Used only for startup speed and frame setup.
2. `config/init.el`: everything else.
3. `config/custom.el`: written by `M-x customize`, loaded from `init.el` if it
   exists. Gitignored.

`~/.emacs-research` is a symlink to `config/`, so either path works.

Only `init.el` and `early-init.el` are tracked in git. Everything else Emacs
writes into `config/` (backups, `recentf.eld`, `history`, `eln-cache/`) is
ignored on purpose; see `.gitignore`.

> **Batch mode does not load your init file.** `emacs --batch` skips it
> (`init-file-user` is `nil`), so a headless test that "shows nothing changed"
> proves nothing. Load it explicitly: `emacs --batch -l config/init.el ...`.

## What is in `early-init.el`

- Disables garbage collection while starting (restored in `init.el`).
- Hides the tool bar and vertical scroll bars before the first frame is drawn
  (avoids a visible flash) and suppresses the startup screen.
- Silences native-compilation warnings and lets Lisp compile in the background.

## What is in `init.el`, section by section

| Section | Does |
|---|---|
| Startup / performance | Sets GC threshold to 64 MB after startup, a 1 MB process-output buffer (faster language servers), and moves `M-x customize` output to `custom.el` |
| UI | Menu bar, column numbers, line numbers everywhere, current-line highlight. **No theme.** Picks a font (below) |
| Editing | 4-space indentation with spaces, matching parens, delete-selection, auto-revert, save-place, recent files, minibuffer history. Backups and auto-saves go to `config/backups/` and no lock files are created |
| Completion | Built-in only: vertical `fido` minibuffer, flexible matching, inline completion preview, `which-key` |
| Coding | `treesit-font-lock-level 4`; Eglot (built-in LSP client) is available but not auto-started |
| Packages | Puts installed packages (only Evil) from `config/elpa/` on `load-path` **without** loading `package.el`, which costs ~0.7 s per launch on WSL. `my/install-package` loads it only to install |
| Read-only files | Every file opens read-only. `C-c e e` (`M-x allow-editing`) and `C-c e l` (`M-x stop-editing`) are the only ways to change that; the single-key `C-x C-q` just prints a reminder. The hook runs last so nothing (such as version control) can unlock a buffer. See [KEYBOARD.md](KEYBOARD.md) |
| Evil | `C-c v` toggles vi-style editing; Evil loads on first use. Includes a one-line compatibility shim (below) |
| Languages | Pins the Java and Rust tree-sitter grammar versions, remaps `.java` to `java-ts-mode` when its grammar exists, and keeps language servers manual. See [LANGUAGES.md](LANGUAGES.md) |
| Keys | `C-c v` → toggle Evil, `C-x C-b` → `ibuffer`, `M-o` → other window, `C-c r` → recent files. All keys are listed in [KEYBOARD.md](KEYBOARD.md) |
| Startup report | Prints Emacs version, load time and GC count to the echo area once |

The only third-party package is **Evil**, and it is optional: it is installed by
`./build.sh packages` (or offered on first use of `C-c v`) into `config/elpa/`, which
is gitignored. Nothing else is installed.

**Evil on Emacs 32.** Evil 1.15 reads a variable, `evil-mode-buffers`, that Emacs 32
no longer defines. Without a shim every command raised `(void-variable
evil-mode-buffers)` from `post-command-hook`. `init.el` defines the variable as `nil`.
The regression test `evil/no-post-command-hook-errors-on-emacs-32` guards it; delete the
shim once Evil supports Emacs 32.

## Adding a theme

There is deliberately none right now. Emacs ships several (Modus, Deeper Blue,
Wheatgrass, and others). To use a built-in one, add to `init.el`:

```elisp
(load-theme 'modus-vivendi t)
```

List what is available with `M-x customize-themes`. A third-party theme (for
example `doom-themes`) needs installing from a package archive first; that is
outside the "no extra packages" baseline, so decide it explicitly.

## Fonts

`init.el` picks the first font from a list that fontconfig can find:
`JetBrains Mono`, `Fira Code`, `Cascadia Code`, `DejaVu Sans Mono`, `Menlo`,
`Consolas`, at height 120 (12 pt).

**Known problem: names must match exactly.** On the WSL machine used here the
installed font is named `JetBrainsMono Nerd Font`, which does **not** match
`"JetBrains Mono"`, so the list falls through to DejaVu Sans Mono. Check the real
names with:

```sh
fc-list : family | sort -u | grep -i jetbrains
```

and put that exact name first in the list. Not installed on this machine:
`Cascadia Code`, `Cascadia Mono`, `Fira Code`, `Consolas`, `Symbols Nerd Font`.

Icon fonts: packages such as `nerd-icons` look for a font named
`Symbols Nerd Font`, which is not installed here; icons would show as empty
boxes until it is (or another Nerd Font is mapped in).

Inside Emacs, `M-x describe-font` shows which font is actually in use.

## Editing and applying changes live

- `C-x C-e` after a form evaluates just that form.
- `M-x eval-buffer` re-applies the whole `init.el` without restarting.
- Adding something to a hook or mode may need the mode toggled off and on.

## Changing built-in behavior

Find the source: `C-h f <function>` then follow the link, or open
`emacs-src/lisp/...`. Evaluate your edit in place; it takes effect immediately
in the running session. For it to persist across restarts, put the override in
`config/init.el` instead of editing `emacs-src/` (which must stay clean for
`git pull`). Use `advice-add` or redefine after `(with-eval-after-load 'x ...)`.

## Profiling

Do not guess at bottlenecks. To find out what is slow:

1. `M-x profiler-start`, choose `cpu+mem`.
2. Do the slow thing.
3. `M-x profiler-report`, expand the tree; `profiler-stop` when done.

If the time is in Lisp, the fix belongs in config. If it is inside C primitives
(redisplay, process output, encoding), a source change may be justified.

Startup time: `emacs --init-directory=config -f kill-emacs` timed externally, or
read the message the config prints at startup.

## Keeping the look consistent across platforms

Themes and mode lines are Lisp; fonts come from the operating system. So the
same `init.el` gives the same colors everywhere, but fonts depend on what is
installed on each machine. That is why the font list has fallbacks. See
[CROSS-PLATFORM.md](CROSS-PLATFORM.md).
