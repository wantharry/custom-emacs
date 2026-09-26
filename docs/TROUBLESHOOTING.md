# Troubleshooting

Problems actually hit while building this project, with what caused them and
what fixed them. Newest-relevant first.

## Getting the source

### `git clone` fails: `RPC failed; HTTP 500 ... fatal: expected 'packfile'`

- **Cause:** Savannah's HTTPS git server returned a 500 while building the pack.
  It failed the same way for a full clone and for `--depth=1`. It is a server-side
  problem, not your machine or network.
- **Fix:** use the `git://` protocol, same repository:
  `git clone --depth=1 git://git.savannah.gnu.org/emacs.git emacs-src`
- Alternative (untried): the official read-only mirror
  `github.com/emacs-mirror/emacs`.

## System packages

### `apt-get update && apt-get install ...` installs nothing

- **Cause:** a dead third-party repository (in this case a `lazygit` PPA that
  returns 404 for Ubuntu 24.04) makes `apt-get update` exit non-zero, so the `&&`
  chain never reaches the install.
- **Fix:** run `sudo apt-get install -y ...` alone (Ubuntu's own package lists
  were fine), or remove the broken repo: `sudo add-apt-repository -r
  ppa:lazygit-team/release`.

## Configure

### `You do not seem to have makeinfo >= 4.13`

- **Cause:** a git checkout has no pre-built manuals. `--without-makeinfo` is
  **not** a valid option.
- **Fix:** `sudo apt-get install texinfo`.

### Terminfo / curses library errors

- **Cause:** no `libncurses-dev`.
- **Fix:** install it (it is in the package list in [BUILD.md](BUILD.md)).

## Running and testing

### A headless test "shows my config did nothing"

- **Cause:** `emacs --batch` does **not** load an init file (`init-file-user` is
  `nil`). Every value looks like the default.
- **Fix:** load it explicitly: `emacs --batch -l config/init.el --eval '...'`.

### `Gdk-WARNING ... cursor image size (64x64) not an integer multiple of scale (3)`

- Harmless. GTK on a scaled WSLg display. It also confirms Emacs connected to
  Wayland.

### Many background `emacs --batch ... emacs-async-comp-*.el` processes after launch

- Expected on the first run of a new package: Emacs is native-compiling it once
  in the background. Results are cached in `eln-cache/`.

### Launching a window from a script

- Run it in the background so the script does not block:
  `install/bin/emacs --init-directory=$PWD/config &`
- Do not use `pkill -f 'build/src/emacs'` from a shell whose own command line
  contains that text: it matches and kills itself.

### Running Emacs against a copy of another config

- Use `-Q --init-directory=<scratch> -l <that>/init.el` so its state files,
  `eln-cache` and package files do not land in `~/.emacs.d`.

## Speed

### Startup takes about a second instead of 0.05 s

- **Cause on WSL:** the Windows `PATH` is inherited (here 53 entries, 39 of them
  Windows drives under `/mnt`). Each lookup of a program that is not installed costs
  ~0.09 s, and loading `browse-url` (which `package.el` loads) does several, so
  `(require 'package)` alone took ~0.7 s. With the Windows entries removed from `PATH`
  it took 0.005 s.
- **Fix in this config:** `package.el` is not loaded at startup. The test
  `startup/package-el-not-loaded` guards it. To fix it for every program, set
  `appendWindowsPath=false` under `[interop]` in `/etc/wsl.conf` (a system change, not
  made here).
- **Keep files on the Linux side.** Small-file operations were ~220 times slower on a
  Windows drive (`/mnt/c`, 17.9 s) than on the WSL disk (0.08 s) in a 2,000-file test.

## Evil

### `Error in post-command-hook (evil-normal-post-command): (void-variable evil-mode-buffers)`

- **Cause:** Evil 1.15 expects a variable Emacs 32 dropped. See
  [CUSTOMIZING.md](CUSTOMIZING.md).
- **Fix:** the compatibility shim in `init.el`. If you see it, the shim was removed.

## Fonts and icons

### The font is not the one I expected

- **Cause:** the font list matches names **exactly**. `JetBrainsMono Nerd Font`
  does not match `JetBrains Mono`.
- **Fix:** see [CUSTOMIZING.md](CUSTOMIZING.md#fonts). Check names with
  `fc-list : family | sort -u`.

### Mode line icons are empty boxes

- **Cause:** `nerd-icons` wants a font called `Symbols Nerd Font`, which is not
  installed. Not a theme or build problem.

## Pruning

### After pruning, `M-x org-mode` says `Cannot open load file`

- **Cause:** stale autoload entries. Expected; see the limitations in
  [PRUNING.md](PRUNING.md#known-limitations).

### Package refresh/install fails: `Cannot open load file ... mm-archive`

- **Cause:** `url` loads `gnus/mm-archive` lazily on any download, and it was
  pruned. Package `require` checks did not catch it because the load happens at
  run time.
- **Fix:** it is now a `!gnus/mm-archive.el` exception in `prune.list`. Rebuild
  the install (`./build.sh install && ./build.sh prune`) and run
  `./tools/verify-prune.sh`. See
  [PRUNING.md](PRUNING.md#what-went-wrong-the-first-time).

### The tool keeps far too much / prunes almost nothing

- **Cause seen during development:** counting the generated autoload registries
  (`ldefs-boot.el`, `*-loaddefs.el`) and `obsolete/` as dependency sources makes
  every removed file look "needed". The tool now ignores both.

## Working practices that avoided problems

- Do not run two shell commands that both `cd` at the same time; one can
  change the other's working directory. Use absolute paths.
- The `! command` shorthand is a Claude Code prompt feature. In a normal
  terminal, type the command without the `!`.
- Never edit `emacs-src/` for configuration; it must stay a clean upstream
  checkout so `git pull` keeps working.
