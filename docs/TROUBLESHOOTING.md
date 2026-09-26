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

## The Emacs window looks frozen (WSL and WSLg)

**Quick check:** `./build.sh doctor` measures everything below on your machine (PATH, where the
files live, fonts, window start time, the font actually used, running and stuck Emacs
processes, tools, the commit hook) and tells you what to fix.

A window that stops responding under WSLg has several possible causes. This was checked on
2026-09-25; the earlier hang itself could not be reproduced, so this is what was measured
and what is known to cause it.

**Checked here and ruled out as a cause of a slow or stuck start:**

| Checked | Result |
|---|---|
| Time to open a graphical frame: the new build | 0.15 s |
| Time to open a graphical frame: Ubuntu's Emacs 29.3 (GTK/X11 build) | 0.18 to 0.26 s |
| The D-Bus session socket (`DBUS_SESSION_BUS_ADDRESS` points at `/run/user/1000/bus`, which does not exist) | Harmless here: identical timing with it unset, with `GSETTINGS_BACKEND=memory` and with `NO_AT_BRIDGE=1`. Worth knowing about, because a missing bus is a classic GTK stall on WSL |
| Fonts | 250 fonts, all on the Linux disk (none from `/mnt/c`), cache valid, `fc-list` takes 0.00 s |
| Leftover Emacs windows | Both running windows were sleeping (`S`, ~0% CPU), waiting for input, not hung |

**Things that make Emacs look frozen, most likely first:**

1. **Background native compilation.** The first use of a package compiles it in several
   `emacs --batch` processes at once (17 were seen for Magit) and can use every core for a
   minute. The window is fine but sluggish. `ps -C emacs` shows the workers.
2. **Slow Windows-drive access.** 2,000 small files took 17.9 s on `/mnt/c` and 0.08 s on the
   WSL disk. Opening a file or directory on `/mnt/c`, or a stale `recentf` entry pointing
   there, can stall the window. Keep files on the Linux side.
3. **A slow `PATH`.** The WSL `PATH` here has 39 Windows folders; each lookup of a missing
   program costs ~0.09 s, and loading `package.el` made startup take ~0.9 s (fixed in this
   config, see [Speed](#speed)).
4. **A script or test that opens a graphical Emacs and hits an error.** A graphical session
   shows errors nowhere, so the window just stays open and unresponsive. This happened
   several times to scripts written for this project; all of them now wrap their work and
   always exit. `tests/run-all.sh --gui` opens such a window for about 10 seconds.
5. **A prompt you cannot see, or a stale server file.** For the separate *gitmacs* project
   the README documents the first-launch daemon hang and the fix (kill the leftover
   process and delete `%APPDATA%\.emacs.d\server\gitmacs`).
6. **WSLg itself stuck.** If every Linux window is frozen, restart WSL from Windows:
   `wsl --shutdown`.

**Finding out what is wrong, from another terminal:**

```sh
ps -o pid,stat,pcpu,etime,args -C emacs
```

| State | Meaning |
|---|---|
| `R`, high CPU | busy computing (compiling, a runaway loop, a big file) |
| `D` | stuck waiting for the disk, usually a `/mnt/c` path |
| `S`, ~0% CPU | waiting for input: a hidden prompt, or the display server is not answering |

To see **where** a busy Emacs is stuck, send it `SIGUSR2`; it stops and shows a backtrace
(verified: `kill -USR2 <pid>` interrupts a busy loop and prints the call stack):

```sh
kill -USR2 <pid>
```

To stop it cleanly from any WSL terminal: `kill <pid>`, or `pkill -x emacs` for all of them.
From Windows PowerShell: `wsl -e pkill -x emacs`.

**Running `emacs -nw` inside a terminal** avoids WSLg entirely and works even when the
graphical window does not.

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

## Java and Rust

### `rust-analyzer` says `Unknown binary 'rust-analyzer' in official toolchain`

- **Cause:** the file in `~/.cargo/bin` is only a `rustup` stub until the component is
  installed.
- **Fix:** `rustup component add rust-analyzer`.

### A tree-sitter grammar will not load, or `treesit-language-abi-version` is above 14

- **Cause:** the grammar was built for a newer parser format than the tree-sitter
  library (0.20.x here) supports.
- **Fix:** use the pinned versions in `config/init.el` and rebuild with
  `./build.sh grammars`. See [LANGUAGES.md](LANGUAGES.md#why-the-grammars-are-pinned).

### `jdtls` uses over a gigabyte of memory

- **Expected:** it is a JVM (about 1.35 GB in the measured demo). It only runs after
  `M-x eglot`. Stop it with `M-x eglot-shutdown`.

### Many Java/Rust tests are skipped

- **Cause:** grammars are not installed. One test fails on purpose to tell you; run
  `./build.sh grammars`.

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
