# Encryption, a password manager, and clipboard history

Status as of 2026-10-17. All three built and tested for real on this machine ---
real encrypt/decrypt round-trips (both a plain password and a real GPG key), a
real password-store entry stored and retrieved, a real system clipboard change
captured by the history poller. 31 ERT tests across the three features, all
passing.

## What is set up

| Key | What it does |
|---|---|
| `C-c x e` / `C-c x d` | encrypt/decrypt a single file --- pick a GPG key, or leave it blank for a plain password |
| `C-c x E` / `C-c x D` | the same for a whole folder (tarred into one file first, then encrypted, so the structure/filenames are hidden too) |
| `C-c p f` | find a password-store entry and copy its password (clipboard clears again in 45s) |
| `C-c p i` | store/overwrite an entry --- its secret comes from a hidden prompt, never a visible command |
| `C-c p g` | generate a new random password for an entry, and copy it |
| `C-c p I` | set the password store up the first time (generates a real GPG key for it if you do not have one yet) |
| `C-c C-y` | browse a real, system-wide clipboard history (every copy from any app) and copy one back |
| `M-y` | browse Emacs's own kill-ring instead (`consult-yank-pop`, searchable) --- a separate, different history on purpose |

Nothing new to install for the encryption/password-manager pieces: `gpg` is
already on this machine, and `pass` (the standard Unix password manager) is
vendored directly in this repo (`tools/pass/pass` --- see its own
`tools/pass/README.md` for exactly where it came from) since there is no
`sudo` here to `apt-get` it. The clipboard history needs nothing extra either
--- it reads the real system clipboard through Emacs's own built-in
`gui-get-selection`, not an external clipboard-manager daemon.

## Why plain `gpg`/`call-process`, not Emacs's own `epa-encrypt-file`/`epa-decrypt-file`

A real hang, found directly while building `C-c x e`/`C-c x d`, not guessed:
EasyPG's own high-level functions go through `epg`'s asynchronous, status-fd
protocol with `gpg-agent`, which can block the ENTIRE Emacs process
indefinitely on a machine/session with no agent already running and no usable
Pinentry reachable --- confirmed directly (no `gpg`/`pinentry` process was even
left running to show what was stuck; Emacs's own event loop was just sitting
in `select()`, as if idle). Setting `epg-pinentry-mode` to `'loopback'` helps
but was not enough on its own either.

Plain `gpg --batch --passphrase-file ... ` via `call-process`, with the exact
same passphrase and cipher, always returns immediately --- `--batch` is
GnuPG's own guarantee that it will never try to prompt interactively at all.
`C-c x`/`C-c p` are both built on that primitive instead.

## Two real bugs found testing the password manager

1. `my/pass-store-dir` (this config's own variable, used to check `.gpg-id`/
   list entries) was never actually passed to the real `pass` script via its
   own `PASSWORD_STORE_DIR` environment variable --- the two silently pointed
   at two different directories. `pass` always used its own default
   (`~/.password-store`) no matter what `my/pass-store-dir` said. Fixed by
   deriving `PASSWORD_STORE_DIR` from `my/pass-store-dir` on every call.
2. `my/pass-insert`'s first version called `call-process-region` with the
   SAME buffer as both the stdin input and the stdout output --- undefined,
   unsafe behavior (a process reading its own not-yet-written output).
   Fixed with a separate output buffer.

## A real gotcha found testing the clipboard-history poller

The poller's own timer was started inside a single `(when (display-graphic-p)
...)` check, evaluated once at config-load time. For a `--fg-daemon`, no frame
exists yet at that exact moment, so `display-graphic-p` is nil then even
though a real GUI frame gets attached moments later via `emacsclient -c` ---
meaning the timer would never start for any daemon at all. Fixed by starting
the timer unconditionally (gated only on not being a real `--batch` process)
and checking `display-graphic-p` fresh on every tick instead.

## The clipboard history is deliberately TWO separate things, not one

By explicit request: `M-y` (Emacs's own kill-ring, via `consult-yank-pop`) and
`C-c C-y` (every real system-wide clipboard copy, from any app) are kept as
two distinct lists with two distinct commands, not merged into one. The
system-wide list is a plain Elisp variable (`my/clip-history`), polled every
2 seconds via `gui-get-selection` --- no external daemon.

One real security interaction between the two new features: a secret
`C-c p f`/`C-c p g` just copied is explicitly marked (`my/clip-history--skip`)
so the poller never logs it into the separate, persisted clipboard history,
regardless of that secret's own 45-second auto-clear timer on the kill-ring
itself --- confirmed directly, not assumed.

## Persistence

`my/clip-history` is added to `desktop-globals-to-save`, so it survives a
restart the same way `my/session-theme` already does (see
[SESSION.md](SESSION.md)). The kill-ring itself is **not** persisted ---
left as Emacs's own normal, in-session-only behavior.
