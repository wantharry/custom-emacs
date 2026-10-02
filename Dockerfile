# Builds this exact Emacs (docs/BUILD.md's own recipe) inside a clean, disposable Ubuntu
# container -- a third independent check that the build recipe really is self-contained,
# alongside the local WSL build and the GitHub Actions workflow (.github/workflows/release.yml).
#
# Two ways to run the result:
#
#   Terminal (works anywhere Docker runs, no setup):
#     docker build -t custom-emacs .
#     docker run -it --rm -v "$PWD":/work custom-emacs
#
#   Real GUI window, forwarded to this host's display (verified on WSL2 + WSLg --- DISPLAY
#   and /tmp/.X11-unix are already real here, and a real window genuinely appeared on the
#   host, confirmed directly with `xwininfo', not assumed from the lack of an error;
#   GDK_BACKEND=x11 is required because this build uses --with-pgtk (see build.sh), which
#   otherwise prefers Wayland, and the container has no route to WSLg's Wayland socket,
#   only its X11/XWayland one). --no-splash replaces -nw here rather than being appended
#   to it --- CMD's default (["-nw"]) is fully REPLACED by whatever you pass after the
#   image name, not added to; passing the bare word `emacs' here (an earlier, untested
#   version of this comment did exactly that) would silently try to open a file literally
#   named "emacs" instead:
#     docker run -it --rm -v "$PWD":/work \
#       -e DISPLAY=$DISPLAY -e GDK_BACKEND=x11 -v /tmp/.X11-unix:/tmp/.X11-unix \
#       custom-emacs --no-splash
#
# `-v "$PWD":/work` mounts your current directory in as /work (the container's WORKDIR),
# so files you edit are the real files on your host, not lost when the container exits.
#
# One harmless, one-time thing you may see on a *fresh* container's first GUI run: a
# separate "Warning" window listing obsolete-macro notices from `theme-buffet.el' (a
# third-party package, nothing in this project's own code) --- native compilation for
# installed (non-built-in) packages happens lazily, on first load, not ahead of time
# during `docker build', so the very first interactive load of whichever package needs
# compiling triggers it live. Confirmed directly (not guessed) by reading
# `*Async-native-compile-log*' inside a running container. Since `--rm' discards the
# container's writable layer, including its native-comp cache, this can recur on each
# *fresh* container's first GUI run --- harmless and skippable (`q' closes it), but if it
# becomes annoying, drop `--rm' and reuse the same container instead of a fresh one each
# time.

FROM ubuntu:24.04

# Same package list as docs/BUILD.md section 1 (the GitHub Actions workflow installs the
# identical set) plus git/ca-certificates (to clone Emacs), python3/python3-venv
# (prune.py, and the venv ./build.sh dist uses for patchelf/ziglang if ever run here too),
# and autoconf --- a plain `ubuntu:24.04' image doesn't have it (unlike GitHub's own
# ubuntu-latest runner image, which ships it preinstalled among many other dev tools, so
# this requirement stayed invisible until building from a genuinely bare base image here);
# `emacs-src/autogen.sh' needs it to generate `configure' from a git checkout (a release
# tarball ships that pre-built, a git clone does not).
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential texinfo autoconf libgnutls28-dev libncurses-dev \
    libxml2-dev libjansson-dev libsqlite3-dev libtree-sitter-dev libgccjit-13-dev \
    libgtk-3-dev librsvg2-dev libjpeg-dev libtiff-dev libgif-dev libwebp-dev \
    liblcms2-dev libharfbuzz-dev libcairo2-dev libxpm-dev libotf-dev \
    git ca-certificates python3 python3-venv ripgrep fd-find \
    && rm -rf /var/lib/apt/lists/*
# `fd-find` installs as `fdfind` on Ubuntu; this config's `consult-fd' looks for `fd'.
RUN ln -s "$(command -v fdfind)" /usr/local/bin/fd

# A non-root user at UID/GID 1000 (the common host default, e.g. WSL2's own user) so a
# bind-mounted directory (-v "$PWD":/work) is writable without permission mismatches, and
# so the GUI, if used, is not run as root. Ubuntu's own official 24.04 image already ships
# a built-in `ubuntu' user at exactly 1000:1000 (confirmed directly: `useradd -u 1000`
# fails here with "UID 1000 is not unique") --- reused rather than fighting it with a
# second one.
USER ubuntu
WORKDIR /work

# Build inside the image at `docker build` time, not at container start --- the whole
# point is a reproducible build baked into the image, verified once here rather than
# re-run (and re-verified) every single `docker run'.
COPY --chown=ubuntu:ubuntu . /src
# git:// first, matching docs/BUILD.md and .github/workflows/release.yml; https:// as a
# fallback since some networks block the unencrypted git protocol (and, seen directly
# while building this image, Savannah's https endpoint alone can also just 500 transiently).
RUN cd /src \
    && (git clone --depth=1 git://git.savannah.gnu.org/emacs.git emacs-src || \
        git clone --depth=1 https://git.savannah.gnu.org/git/emacs.git emacs-src) \
    && ./build.sh all \
    && ./build.sh packages \
    && ./build.sh grammars

ENV PATH="/src/install/bin:${PATH}"
ENV CONFIG_DIR="/src/config"

# Terminal by default (works with no host setup at all); override the command with
# plain `emacs' (no `-nw') for the real GUI window, per the X11-forwarding example above.
ENTRYPOINT ["emacs", "--init-directory=/src/config"]
CMD ["-nw"]
