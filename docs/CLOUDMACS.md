# Cloudmacs: this Emacs, in a browser tab (local machine only)

`tools/cloudmacs.sh` runs this project's own built `install/bin/emacs`, with this project's
own config, reachable at `http://127.0.0.1:PORT` in any browser --- the same idea as
[karlicoss/cloudmacs](https://github.com/karlicoss/cloudmacs) (a Docker image that does the
same trick), explained below.

```
tools/cloudmacs.sh          # http://127.0.0.1:8080
tools/cloudmacs.sh 9000     # a different port
```

The first run downloads [Gotty](https://github.com/sorenisanerd/gotty) (verified against its
published checksum, cached in `dist/cache/`, same pattern as `rg`/`fd`/`delta`/`dua` in the
Windows dist build) and starts a real Emacs **daemon** using this project's own config
(`install/bin/emacs --init-directory=config --daemon`) if one is not already running. Gotty
then serves `emacsclient --tty -c` as a live web terminal. Open the URL, and you are looking
at this actual Emacs --- same fonts (as far as a terminal can show them), same keybindings,
same buffers, same `C-c k`/Custom menu.

**Closing the tab does not close Emacs.** Gotty is just a window onto a real `emacsclient`
session attached to a real daemon; reopen the URL (or run `tools/cloudmacs.sh` again) and
the same buffers are still there. `Ctrl-C` on the *script itself* only stops Gotty (the web
server) --- the Emacs daemon underneath keeps running; kill it separately
(`emacsclient -e '(kill-emacs)'`) if you want it gone too.

## Why not the real `karlicoss/cloudmacs` Docker image

Its [Dockerfile](https://github.com/karlicoss/cloudmacs/blob/master/Dockerfile) is built on
`silex/emacs:master-alpine` --- a *different* Emacs entirely, linked against musl libc.
This project's own native-compiled `.eln` files are glibc-linked (built on Ubuntu) and simply
will not load under musl --- the exact "machine-specific native-build artifact" problem
`tests/test_dist.py` already guards the Windows/Linux dist zips against, just encountered
again in a new place. Running the real image would give you a different, generic Emacs with
none of this config, not this one. Running Gotty directly against this host's own
already-built Emacs avoids that mismatch entirely and needs no Docker at all --- the whole
trick (Gotty plus `emacsclient --tty`) is only a few lines either way; see the script's own
comments.

## Security: local machine only, on purpose

`tools/cloudmacs.sh` binds Gotty to `127.0.0.1`, not `0.0.0.0`, and sets up **no
authentication at all**. That is a deliberate choice for "my own machine, my own
convenience," not an oversight --- `emacsclient --tty` is a real shell-equivalent (`M-!`,
`shell`, `eshell`, ...), so anyone who can reach the port can run arbitrary commands as you.
If you ever want this reachable from elsewhere (another device on your LAN, or the real
internet), do not just change the bind address: add real authentication (Gotty supports
`--credential user:pass`) and put it behind HTTPS (a reverse proxy, same as the real
Cloudmacs project's own README recommends) first.

## A real caveat: it shares this config's own session state

The daemon it starts uses this project's real `config/` directory, the same one your normal
interactive Emacs uses --- including `config/session/.emacs.desktop` (see
[SESSION.md](SESSION.md)). That is expected (it is genuinely the same config, on purpose),
but it means a Cloudmacs session and a separately-opened `install/bin/emacs` both reading
that same directory are sharing real state, not two independent sandboxes.
