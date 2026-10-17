# `pass` (password-store), vendored here

The real, official `pass` script --- unmodified, Copyright 2012-2018 Jason A.
Donenfeld, GPL-2+ (see `licenses/pass-COPYRIGHT.txt`). Upstream:
<https://www.passwordstore.org/>.

## Where this came from

Not an arbitrary web download --- `apt-get download pass` against Ubuntu's own
archive (`pass_1.7.4-6_all.deb`, `noble/universe`), the same checksummed,
HTTPS-verified path a real `apt-get install pass` would use, just extracted
with `dpkg-deb -x` instead of actually installing it system-wide (no `sudo`
available in this build environment). The script itself is pure POSIX-ish
bash; nothing in it is Debian-specific.

## Why vendored instead of just requiring the user install it

Same reasoning as every other bundled tool in this config (fonts, pdf-tools,
the JDK, Maven): a real day-to-day gap, closed with zero install rather than
"go run `apt-get install pass` yourself first."

## What this config actually uses from `pass`

Only the `pass` script itself --- `init`, `ls`, `find`, `insert`, `generate`,
and plain `show` (never `show -c`/`generate -c`: those need `xclip`/`wl-copy`,
confirmed NOT installed on the dev machine this was built on; this config's
own `C-c p` commands copy via Emacs's own built-in clipboard integration
instead, which has no such external dependency). `pass`'s own dmenu/password-
importer extras (`usr/share/pass/*.rb`/`.py`, `examples/dmenu/`) are not
vendored --- genuinely unused here.

## Requirements

`pass` itself needs: `gpg` (already required by this config's own `C-c x`
encryption commands), and standard `bash`/`find`/`mktemp`/etc. `git` is
optional (for storing `~/.password-store` as a version-controlled repo) ---
not required for this config's own commands.
