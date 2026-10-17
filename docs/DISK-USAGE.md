# Disk usage: a WizTree-style browser, and recursive sizes in Dired

Two different answers to the same real question ("what is actually using disk space"), added together
at the user's request after asking about WizTree (a fast Windows disk-space analyzer):

- **`C-c W`** (outside Dired): `my/disk-usage`, a custom, drill-down browser --- largest file or
  subdirectory first, powered by [`dua`](https://github.com/Byron/dua-cli), a real, actively maintained
  Rust disk-usage scanner that is parallel by default.
- **`C-c W`** (inside Dired): toggles `dired-du-mode` (a real GNU ELPA package) --- recursive directory
  sizes shown right in the existing Dired listing, instead of a separate buffer.

Both share the same key deliberately: one is global, one is scoped to `dired-mode-map`, so Dired's own
binding simply takes over while you are in a Dired buffer, with no real conflict.

## `C-c W`: the custom browser (`my/disk-usage`)

> **A real, honest limit, said up front.** WizTree's own speed trick is reading the NTFS Master File
> Table directly instead of walking the filesystem --- that is Windows/NTFS-specific, and not something
> portable Elisp (or any portable tool) can do. `dua` is not that: it is a normal filesystem walk, just a
> genuinely fast, parallel one ("will max out your SSD", its own README's words) --- a real, different
> speed class from a serial `du`, confirmed directly: a full top-level breakdown of an entire real ~1.3 TB
> Windows `C:\` drive (no admin rights, so it skipped a few permission-protected system folders rather
> than stopping) finished in **118.6 seconds**.

Prompts for a directory (defaulting to the current one), then shows its immediate children, each with
its own real recursive size, biggest first:

<!-- keymap: my/disk-usage-mode-map -->
| Key | Command | What it does |
|---|---|---|
| `RET` | `my/disk-usage-visit` | drill into the directory at point (does nothing on a plain file) |
| `f` | `my/disk-usage-visit` | the same |
| `^` | `my/disk-usage-up` | go back up to the directory this one was drilled into from |
| `u` | `my/disk-usage-up` | the same |
| `d` | `my/disk-usage-dired-here` | open the entry at point (or this directory) in a real Dired buffer --- for anything this browser itself does not do (renaming, deleting, ...) |
| `g` | `my/disk-usage-refresh` | force a real re-scan of the current directory, bypassing the cache below |
| `a` | `my/disk-usage-toggle-async` | switch between async and sync scanning, see below |
| `q` | `quit-window` | close it |

### Async by default --- Emacs stays usable during a real scan

A real, user-raised concern: the first version of this used `call-process`, which
BLOCKS all of Emacs until `dua` exits --- against the real ~1.3 TB `C:\` test above
(118.6 seconds), that would have frozen Emacs solid for the whole two minutes. The
default now uses `make-process` instead, which never blocks Emacs --- you can keep
editing in another window while a big scan runs, and the buffer updates itself once
`dua` actually finishes. A real notice appears the moment a scan that cannot be
served from the cache (below) actually starts, both in the header line and via
`message` (so it is visible even if you have switched to a different window
meanwhile): "Scanning ... (async, Emacs stays responsive)".

The original, simpler synchronous mode (`call-process`, blocks while `dua` runs) is
kept too, not removed --- press `a` to switch either way, or set
`my/disk-usage-async` to `nil` yourself. There is no real reason to prefer sync for
a big directory, but it is a perfectly reasonable, simpler choice for a small, fast
one, and some people may just prefer a command that visibly runs to completion
before giving control back, rather than a background job.

### It only re-scans when it has to

Drilling in, going back up, or reopening a directory you already looked at does NOT
re-run `dua` every time --- a scan is cached and reused as long as that directory's
own modification time has not moved on since. Adding, removing or renaming an entry
DIRECTLY inside a directory always updates that directory's own mtime, so that case
is caught automatically.

The cache is saved to `disk-usage-cache.eld` (next to your other settings, gitignored
like `recentf.eld`) after every real scan, and survives restarting Emacs --- a
directory you looked at yesterday does not need a fresh scan today unless it
genuinely changed. Delete that file by hand if you ever want to start clean.

One real, honest limit: a change to a file two or more levels DEEPER does not update
a distant ancestor's own mtime, only its immediate parent's --- so a distant ancestor
can keep showing a slightly stale size until you explicitly press `g` on it. `g`
always forces a real re-scan, ignoring the cache entirely, so it is the reliable way
to be sure.

### Installing `dua`

Not an ELPA package, so `./build.sh packages` does not install it:

- **Windows (this project's own dist zip)**: already bundled, nothing to install.
- **Linux**: install it yourself --- a real system binary, the same treatment `fd`/`delta` already get in
  this config (see [DISTRIBUTION.md](DISTRIBUTION.md)). A prebuilt binary for your platform is on its own
  [GitHub releases page](https://github.com/Byron/dua-cli/releases); your distro's package manager may
  also have it, or `cargo install dua-cli` if you have a Rust toolchain.
- **Mac**: `brew install dua-cli`, or the same GitHub releases/`cargo` route as Linux.

Without it, `C-c W` (outside Dired) shows a plain message instead of erroring --- the same "not installed,
here is how" treatment every other optional tool in this config gets.

## `C-c W` inside Dired: `dired-du-mode`

A real GNU ELPA package, installed by `./build.sh packages` like everything else in `my/packages`
(`tools/install-packages.el`). Toggles recursive directory sizes on/off in the CURRENT Dired buffer only
--- off by default, since computing every directory's real recursive size takes real, noticeable time on
a big tree (confirmed directly by actually turning it on over this project's own `config/elpa`, thousands
of files). Its own README has the full set of customization variables (`dired-du-size-format`,
`dired-du-update-headers`, ...) if you want to tune it further; nothing here changes its own defaults.
