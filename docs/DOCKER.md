# Docker

A `Dockerfile` at the repo root builds this exact Emacs inside a clean, disposable
`ubuntu:24.04` container and runs it either in a terminal or as a real GUI window
forwarded to your host display. It is a third, independent way to get this Emacs running
--- alongside the local WSL build ([docs/BUILD.md](BUILD.md)) and the GitHub Actions
Linux release (`.github/workflows/release.yml`) --- and it doubles as a genuine proof
that the from-source build recipe is actually self-contained: a bare container starts
with none of this machine's accumulated caches, downloaded dependencies, or already-built
state to quietly cover for a missing step.

## Build it

```sh
docker build -t custom-emacs .
```

This runs the same recipe `docs/BUILD.md` documents by hand (system packages, clone
Emacs, `./build.sh all`, `./build.sh packages`, `./build.sh grammars`), baked into the
image at build time rather than at every container start --- the whole point is a
reproducible build verified once here, not re-run (and re-verified) on every `docker
run`. Took about 8.5 minutes on this machine once the dependency list was right (see
"What building this caught", below); expect network speed and CPU to matter more than
anything else.

## Run it

**Terminal** --- works anywhere Docker runs, no host setup at all:

```sh
docker run -it --rm -v "$PWD":/work custom-emacs
```

**Real GUI window**, forwarded to this host's display (verified for real on WSL2 +
WSLg --- a genuine window appeared in the host's own X window tree, confirmed directly
with `xwininfo`, not assumed from the absence of an error):

```sh
docker run -it --rm -v "$PWD":/work \
  -e DISPLAY=$DISPLAY -e GDK_BACKEND=x11 -v /tmp/.X11-unix:/tmp/.X11-unix \
  custom-emacs --no-splash
```

`-v "$PWD":/work` mounts your current directory in as `/work` (the container's
`WORKDIR`), so files you edit are the real files on your host, not lost when the
container exits. `GDK_BACKEND=x11` matters specifically because this build uses
`--with-pgtk` (see `build.sh`), which otherwise prefers Wayland --- the container has no
route to WSLg's Wayland socket, only its X11/XWayland one.

`--no-splash` **replaces** the image's default command (`-nw`, terminal mode) rather than
adding to it --- whatever you pass after the image name replaces `CMD` entirely, it is
not appended to it. An earlier, untested version of this guide's own example passed the
bare word `emacs` here instead, which silently tried to open a file literally named
"emacs" rather than dropping `-nw` --- caught only by actually running it, not by reading
the Dockerfile.

## What building and running this actually caught

Three real, found-by-doing-it problems, none of them hypothetical:

1. **`ubuntu:24.04`'s official image already ships a built-in `ubuntu` user at UID/GID
   1000** (a change to the base image). The Dockerfile originally tried to create its own
   user at that UID for bind-mount permission compatibility --- failed immediately with
   "UID 1000 is not unique". Fixed by reusing the image's own `ubuntu` user instead of
   fighting it with a second one.
2. **Savannah's `https://` git endpoint can 500 transiently**, independent of anything in
   this project --- one build hit it directly. `docs/BUILD.md` and the GitHub Actions
   workflow already try `git://` first and fall back to `https://` for a different reason
   (some networks block the unencrypted protocol); the Dockerfile now does the same
   two-step fallback, which also happens to paper over this.
3. **A bare `ubuntu:24.04` image does not include `autoconf`**, unlike GitHub's own
   `ubuntu-latest` runner image (which ships it preinstalled among many other dev tools,
   so this requirement stayed invisible until building from a genuinely bare base image
   here). `emacs-src/autogen.sh` needs it to generate `configure` from a git checkout (a
   release tarball ships that pre-built; a git clone does not). Added to the Dockerfile's
   own package list, which is otherwise identical to `docs/BUILD.md` section 1.

One more thing found while actually launching the GUI, not a bug but worth knowing: a
**separate "Warning" window can appear on a fresh container's first GUI run**, listing
obsolete-macro notices from `theme-buffet.el` (a third-party package, nothing in this
project's own code --- confirmed directly by reading `*Async-native-compile-log*` inside
a running container). Installed (non-built-in) packages are native-compiled lazily, on
first load, not ahead of time during `docker build` --- so the very first interactive
load of whichever package needs compiling triggers it live. Since `--rm` discards the
container's writable layer (including its native-comp cache), this can recur on each
*fresh* container's first GUI run. Harmless (`q` closes it, nothing fails), skippable
(drop `--rm` and reuse the same container if it becomes annoying), and unrelated to any
of this project's own code.

## What is and is not covered

- Builds and runs the **Linux** bundle's equivalent only --- there is no Windows
  container here, for the same reason `.github/workflows/release.yml` does not build
  Windows either: the real Windows package-compile step needs an actual Windows
  `Emacs.exe` driven through `cmd.exe`, which only exists one layer down inside WSL2,
  not inside a plain Linux container.
- `.dockerignore` mirrors `.gitignore`: the build context never includes `emacs-src/`,
  `build/`, `install/`, `dist/`, `config/elpa/`, or `config/tree-sitter/` --- the
  Dockerfile clones and builds all of that itself, inside the image.
