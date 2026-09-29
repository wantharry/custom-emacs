#!/usr/bin/env bash
# Build the portable Linux bundle: this Emacs, its settings, its packages and every shared
# library it needs, in one folder that runs from wherever it is unpacked.
#
#   tools/dist-linux.sh            -> dist/custom-emacs-linux-x86_64.tar.gz and .zip
#
# Needs: a finished build (./build.sh, then ./build.sh packages and grammars), and
# patchelf, installed into dist/.venv by ./build.sh dist (or: python3 -m venv dist/.venv &&
# dist/.venv/bin/pip install patchelf).  See docs/DISTRIBUTION.md.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
NAME=custom-emacs-linux-x86_64
DIST="$ROOT/dist"
STAGE="$DIST/stage/$NAME"
PATCHELF="${PATCHELF:-$DIST/.venv/bin/patchelf}"
RG_VERSION="${RG_VERSION:-14.1.1}"

[ -x "$ROOT/install/bin/emacs" ] || { echo "no build: run ./build.sh first" >&2; exit 1; }
[ -x "$PATCHELF" ] || { echo "patchelf not found at $PATCHELF" >&2; exit 1; }
[ -d "$ROOT/config/elpa" ] || { echo "no packages: run ./build.sh packages" >&2; exit 1; }
command -v 7z >/dev/null || { echo "7z is needed to make the zip (sudo apt-get install p7zip-full)" >&2; exit 1; }

rm -rf "$STAGE"; mkdir -p "$STAGE"/{lib,tools,config,share}
echo "== Emacs itself"
cp -a "$ROOT/install" "$STAGE/app"

echo "== shared libraries"
# Everything except the C library family and the GPU drivers, which must come from the
# machine itself.
skip='^(ld-linux.*|linux-vdso.*|libc|libm|libdl|libpthread|librt|libutil|libresolv|libnss_.*|libcrypt|libanl|libGL|libGLX|libGLdispatch|libEGL|libOpenGL|libdrm.*|libgbm|libvulkan.*)\.so'
copy_libs() {   # copy the libraries the ELF files given need, into lib/
  local f l
  for f in "$@"; do
    ldd "$f" 2>/dev/null | awk '/=> \// {print $3}' | while read -r l; do
      b="$(basename "$l")"
      [[ "$b" =~ $skip ]] && continue
      [ -e "$STAGE/lib/$b" ] || cp -L "$l" "$STAGE/lib/$b"
    done
  done
}
BINS=("$STAGE/app/bin/emacs" "$STAGE/app/bin/emacsclient" "$STAGE/app/bin/etags" "$STAGE/app/bin/ebrowse")
copy_libs "${BINS[@]}"

echo "== GTK's run-time plug-ins (image loaders)"
PIXDIR=/usr/lib/x86_64-linux-gnu/gdk-pixbuf-2.0/2.10.0/loaders
mkdir -p "$STAGE/lib/gdk-pixbuf/loaders"
cp -L "$PIXDIR"/*.so "$STAGE/lib/gdk-pixbuf/loaders/"
copy_libs "$STAGE"/lib/gdk-pixbuf/loaders/*.so
# a second pass: the libraries we just copied need theirs
for _ in 1 2 3; do copy_libs "$STAGE"/lib/*.so*; done

echo "== make it relocatable (RUNPATH, no LD_LIBRARY_PATH leaking into child programs)"
for f in "$STAGE"/lib/*.so*; do [ -L "$f" ] || "$PATCHELF" --set-rpath '$ORIGIN' "$f" 2>/dev/null || true; done
for f in "$STAGE"/lib/gdk-pixbuf/loaders/*.so; do "$PATCHELF" --set-rpath '$ORIGIN/../..' "$f" 2>/dev/null || true; done
for f in "${BINS[@]}"; do "$PATCHELF" --set-rpath '$ORIGIN/../../lib' "$f"; done

echo "== settings, packages, grammars (no personal history)"
cp "$ROOT"/config/{early-init.el,init.el,fastfind.el,startpage.el,docsbuffer.el,gitfolders.el,llm.el,llm-council.el,shortcuts.el,dictate.el,session.el} "$STAGE/config/"
cp -a "$ROOT/config/elpa" "$STAGE/config/elpa"
rm -rf "$STAGE/config/elpa/archives" "$STAGE/config/elpa/gnupg"      # download state, not needed
[ -d "$ROOT/config/tree-sitter" ] && cp -a "$ROOT/config/tree-sitter" "$STAGE/config/tree-sitter"
# text only (not docs/images/): the *docs* buffer (C-c d) reads these at the same relative
# layout as the git repository, so no code needs to know it is running from a bundle
# (my/docs--root resolves to the parent of config/, i.e. $STAGE itself here)
cp "$ROOT/README.md" "$STAGE/README.md"
mkdir -p "$STAGE/docs" && cp "$ROOT"/docs/*.md "$STAGE/docs/"

echo "== GTK settings schemas and a font, so it does not depend on the desktop"
mkdir -p "$STAGE/share/glib-2.0/schemas" "$STAGE/share/fonts"
cp /usr/share/glib-2.0/schemas/gschemas.compiled "$STAGE/share/glib-2.0/schemas/"
cp /usr/share/fonts/truetype/dejavu/DejaVuSansMono*.ttf /usr/share/fonts/truetype/dejavu/DejaVuSans.ttf "$STAGE/share/fonts/" 2>/dev/null || true
cp /usr/share/fonts/truetype/dejavu/LICENSE "$STAGE/share/fonts/DEJAVU-LICENSE" 2>/dev/null || true

echo "== finding every git repository (C-c f p): a small, dependency-light script (falls"
echo "   back from fd to plain find on its own), so it travels with the bundle like everything else"
cp "$ROOT/tools/find-repos.sh" "$STAGE/tools/find-repos.sh"
chmod +x "$STAGE/tools/find-repos.sh"

echo "== ripgrep (fast file and text search)"
if [ ! -x "$DIST/cache/rg-linux" ]; then
  mkdir -p "$DIST/cache"
  curl -fsSL "https://github.com/BurntSushi/ripgrep/releases/download/$RG_VERSION/ripgrep-$RG_VERSION-x86_64-unknown-linux-musl.tar.gz" \
    | tar -xz -C "$DIST/cache" --strip-components=1 "ripgrep-$RG_VERSION-x86_64-unknown-linux-musl/rg"
  mv "$DIST/cache/rg" "$DIST/cache/rg-linux"
fi
cp "$DIST/cache/rg-linux" "$STAGE/tools/rg"

echo "== launcher"
cat > "$STAGE/Emacs" <<'LAUNCHER'
#!/bin/sh
# Opens this Emacs with its bundled settings and packages.  Double-click it (if your file
# manager offers "Run"), or run ./Emacs [files].  Everything it needs is in this folder.
HERE="$(dirname "$(readlink -f "$0")")"
export CUSTOM_EMACS_PORTABLE=1
export PATH="$HERE/tools:$PATH"
export XDG_DATA_DIRS="$HERE/share:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
export GSETTINGS_SCHEMA_DIR="$HERE/share/glib-2.0/schemas"
# GTK needs a list of its image plug-ins with absolute paths; write it for where we are.
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/custom-emacs"
mkdir -p "$CACHE" 2>/dev/null
if [ -w "$CACHE" ]; then
  sed "s#@APP@#$HERE#g" "$HERE/lib/gdk-pixbuf/loaders.cache.in" > "$CACHE/loaders.cache"
  export GDK_PIXBUF_MODULE_FILE="$CACHE/loaders.cache"
fi
exec "$HERE/app/bin/emacs" --init-directory="$HERE/config" "$@"
LAUNCHER
chmod +x "$STAGE/Emacs"
# the image plug-in list, with the location left to be filled in at launch
QL=/usr/lib/x86_64-linux-gnu/gdk-pixbuf-2.0/gdk-pixbuf-query-loaders
GDK_PIXBUF_MODULEDIR="$STAGE/lib/gdk-pixbuf/loaders" "$QL" 2>/dev/null | sed "s#$STAGE#@APP@#g" > "$STAGE/lib/gdk-pixbuf/loaders.cache.in"

# a desktop entry generator, so it can be added to the application menu
cat > "$STAGE/install-desktop-entry.sh" <<'DESK'
#!/bin/sh
# Adds "Custom Emacs" to your application menu (per user; undo by deleting the .desktop file).
HERE="$(dirname "$(readlink -f "$0")")"
D="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
mkdir -p "$D"
cat > "$D/custom-emacs.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Custom Emacs
Comment=Emacs with its settings and packages
Exec="$HERE/Emacs" %F
Terminal=false
Categories=Development;TextEditor;
StartupWMClass=Emacs
EOF
echo "Added $D/custom-emacs.desktop"
DESK
chmod +x "$STAGE/install-desktop-entry.sh"

cat > "$STAGE/README.txt" <<EOF
Custom Emacs, portable, for Linux x86-64.

  Run:        ./Emacs            (or ./Emacs somefile)
  Menu entry: ./install-desktop-entry.sh   (optional)

Everything is inside this folder:
  app/    Emacs 32 (the exact build this repository produces) with its shared libraries
  config/ your settings, and the packages Evil, Magit, Treemacs and Consult, and tree-sitter
          grammars for Java, Rust, HTML, CSS, JavaScript/JSX, TypeScript/TSX and JSON
  tools/  ripgrep (fast search); git for Magit is NOT bundled, use your system's own
  docs/   every guide, also readable inside Emacs itself: press C-c d
Keep the folders together; you can move or copy the whole folder anywhere, even a USB stick.
Your history, backups and saved settings are written in config/, so put it somewhere you can write.

Needs: 64-bit Linux with glibc 2.39 or newer (Ubuntu 24.04+, Debian 13+, Fedora 40+), a
graphical session (X11 or Wayland), and git already installed (for Magit). For a terminal,
run ./Emacs -nw.
Java: no language server is bundled here (unlike the Windows version) --- install jdtls
yourself, or use the Linux build this bundle came from directly. Rust's rust-analyzer is
also not included, same as Java's JDK. This is planned; see docs/DISTRIBUTION.md.
Consult (C-c s l/g/f/b) is included and works out of the box: it uses the bundled rg
(and your system's fd, if installed, for C-c s f/C-c f p).
Press C-c d for every guide in one buffer (README.md and docs/*.md), built the moment Emacs starts.
Emacs is licensed under the GNU GPL v3+; its source is at https://git.savannah.gnu.org/emacs.git
(commit $(git -C "$ROOT/emacs-src" rev-parse --short=12 HEAD 2>/dev/null || echo unknown)).
Full guide: DISTRIBUTION.md in this folder, or https://github.com/wantharry/custom-emacs.
EOF
cp "$ROOT/docs/DISTRIBUTION.md" "$STAGE/DISTRIBUTION.md" 2>/dev/null || true

echo "== archives"
rm -f "$DIST/$NAME".tar.gz "$DIST/$NAME".zip
# .tar.gz: wraps everything in one top-level folder ("$NAME") -- the normal, expected
# convention for a .tar.gz, and safe: `tar -xzf` never creates its own destination folder,
# so there is no risk of ending up with two nested copies of it.
( cd "$DIST/stage" && tar -czf "$DIST/$NAME.tar.gz" "$NAME" )
# .zip: no wrapping folder -- a file manager's "Extract Here"/"Extract All" on Linux (like
# Windows Explorer) proposes a destination folder named after the zip itself; if the zip's
# own contents were ALSO wrapped in a same-named folder, that would double-nest on
# extraction (the exact bug already fixed in tools/dist-windows.sh; avoided the same way
# here, by archiving the staged folder's CONTENTS, not the folder itself).
( cd "$STAGE" && 7z a -tzip -mx=6 -bso0 -bsp0 "$DIST/$NAME.zip" * )
ls -lh "$DIST/$NAME".tar.gz "$DIST/$NAME".zip
du -sh "$STAGE"
