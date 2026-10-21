#!/usr/bin/env bash
# Build the portable macOS bundle: Emacs.app (built via Homebrew's emacs-plus, so it has native
# compilation, tree-sitter and a real Cocoa GUI), fully relocated -- every Homebrew dylib it needs
# copied in and relinked with install_name_tool/dylibbundler, and its lisp/etc/libexec trees
# (which emacs-plus, unlike emacs-app, does not bundle -- it looks them up at a fixed Homebrew
# Cellar path) copied inside Contents/ too -- plus this config, its packages and tree-sitter
# grammars. The result needs NO Homebrew, and no compiling, on the machine that unzips it.
#
#   tools/dist-macos.sh            -> dist/custom-emacs-macos-arm64.zip
#
# Needs: emacs-plus@31 installed via Homebrew (brew tap d12frosted/emacs-plus && brew install
# emacs-plus@31), dylibbundler (brew install dylibbundler), a finished ./build.sh packages and
# ./build.sh grammars. Apple Silicon (arm64) only -- matches what GitHub's macos-latest runners
# and real MacBook Pros (M-series) actually are now; an Intel Mac would need its own build.
# See docs/DISTRIBUTION.md.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
NAME=custom-emacs-macos-arm64
DIST="$ROOT/dist"
STAGE="$DIST/stage/$NAME"

EMACS_PLUS_PREFIX="${EMACS_PLUS_PREFIX:-$(brew --prefix emacs-plus@31 2>/dev/null || true)}"
[ -n "$EMACS_PLUS_PREFIX" ] && [ -d "$EMACS_PLUS_PREFIX/Emacs.app" ] || {
  echo "emacs-plus@31 not found: brew tap d12frosted/emacs-plus && brew install emacs-plus@31" >&2; exit 1; }
command -v dylibbundler >/dev/null || { echo "dylibbundler not found: brew install dylibbundler" >&2; exit 1; }
[ -d "$ROOT/config/elpa" ] || { echo "no packages: run ./build.sh packages" >&2; exit 1; }
[ -d "$ROOT/config/tree-sitter" ] || { echo "no grammars: run ./build.sh grammars" >&2; exit 1; }

# emacs-plus's own Cellar keg, not the /opt/homebrew/opt/ symlink -- we need the real version
# directory name (e.g. "31.1") to find lisp/etc/libexec, which live one level further down,
# outside Emacs.app itself (this build uses --disable-ns-self-contained; confirmed directly
# with `emacs --batch --eval data-directory`, which prints a path under Cellar, not under
# Emacs.app/Contents/Resources -- unlike the official emacs-app cask).
CELLAR_KEG="$(cd "$EMACS_PLUS_PREFIX" && pwd -P)"
EMACS_VERSION="$("$EMACS_PLUS_PREFIX/bin/emacs" --version | head -1 | awk '{print $3}')"
ARCH_DIR="$(find "$CELLAR_KEG/libexec/emacs/$EMACS_VERSION" -maxdepth 1 -type d -name '*-apple-darwin*' | head -1)"
[ -n "$ARCH_DIR" ] || { echo "could not find libexec arch dir under $CELLAR_KEG/libexec/emacs/$EMACS_VERSION" >&2; exit 1; }

rm -rf "$STAGE"; mkdir -p "$STAGE"/{config,tools}
echo "== Emacs.app and Emacs Client.app (from $CELLAR_KEG)"
cp -R "$CELLAR_KEG/Emacs.app" "$STAGE/Emacs.app"
[ -d "$CELLAR_KEG/Emacs Client.app" ] && cp -R "$CELLAR_KEG/Emacs Client.app" "$STAGE/Emacs Client.app"

echo "== lisp/etc/libexec (not inside Emacs.app for this build; copied in so nothing is looked up"
echo "   on the machine that built this)"
mkdir -p "$STAGE/Emacs.app/Contents/Resources" "$STAGE/Emacs.app/Contents/libexec"
cp -R "$CELLAR_KEG/share/emacs/$EMACS_VERSION/lisp" "$STAGE/Emacs.app/Contents/Resources/lisp"
cp -R "$CELLAR_KEG/share/emacs/$EMACS_VERSION/etc" "$STAGE/Emacs.app/Contents/Resources/etc"
cp -R "$ARCH_DIR" "$STAGE/Emacs.app/Contents/libexec/arch"

echo "== relocating every Homebrew dylib Emacs itself needs (dylibbundler; recurses automatically)"
dylibbundler -od -b \
  -x "$STAGE/Emacs.app/Contents/MacOS/Emacs" \
  -d "$STAGE/Emacs.app/Contents/libs" \
  -p "@executable_path/../libs" >/dev/null
if [ -d "$STAGE/Emacs Client.app" ]; then
  dylibbundler -od -b \
    -x "$STAGE/Emacs Client.app/Contents/MacOS/Emacs Client" \
    -d "$STAGE/Emacs Client.app/Contents/libs" \
    -p "@executable_path/../libs" >/dev/null 2>&1 || true
fi
remaining="$(otool -L "$STAGE/Emacs.app/Contents/MacOS/Emacs" | grep -c '/opt/homebrew' || true)"
[ "$remaining" = 0 ] || { echo "still $remaining Homebrew paths left in the Emacs binary" >&2; exit 1; }

echo "== settings, packages, grammars (no personal history)"
cp "$ROOT"/config/{early-init.el,init.el,fastfind.el,startpage.el,docsbuffer.el,gitfolders.el,llm.el,llm-council.el,shortcuts.el,dictate.el,emacs-session.el,calendar-year.el,mode-reference.el,disk-usage.el} "$STAGE/config/"
cp -a "$ROOT/config/elpa" "$STAGE/config/elpa"
rm -rf "$STAGE/config/elpa/archives" "$STAGE/config/elpa/gnupg"
# same real bug as the Linux/Windows dist scripts guard against: a native module/helper
# (vterm, pdf-tools) compiled by hand on THIS machine first leaves a real CMake build tree
# with THIS machine's own absolute path baked in; only a directory that really is one
# (CMakeCache.txt present) is removed.
find "$STAGE/config/elpa" -name 'CMakeCache.txt' -exec dirname {} \; | while read -r d; do rm -rf "$d"; done
cp -a "$ROOT/config/tree-sitter" "$STAGE/config/tree-sitter"
cp "$ROOT/README.md" "$STAGE/README.md"
mkdir -p "$STAGE/docs" && cp "$ROOT"/docs/*.md "$STAGE/docs/"

echo "== all 20 C-c F fonts, real files (same reasoning as the Linux/Windows bundles; see"
echo "   tools/fonts/README.md, including the macOS install step: double-click, Install Font)"
cp -r "$ROOT/tools/fonts" "$STAGE/tools/fonts"

echo "== finding every git repository (C-c f p): a small, dependency-light script (falls"
echo "   back from fd to plain find on its own), so it travels with the bundle like everything else"
cp "$ROOT/tools/find-repos.sh" "$STAGE/tools/find-repos.sh"
chmod +x "$STAGE/tools/find-repos.sh"

echo "== helper tools (rg, fd, dua, delta), relocated the same way as Emacs itself"
for t in rg fd dua delta; do
  src="$(command -v "$t" 2>/dev/null || true)"
  [ -n "$src" ] || continue
  mkdir -p "$STAGE/tools/$t"
  cp -L "$src" "$STAGE/tools/$t/$t"
  if otool -L "$STAGE/tools/$t/$t" | grep -q '/opt/homebrew'; then
    dylibbundler -od -b -x "$STAGE/tools/$t/$t" -d "$STAGE/tools/$t/libs" -p "@executable_path/libs" >/dev/null 2>&1 || true
  fi
done

echo "== launcher"
cat > "$STAGE/Open Custom Emacs.command" <<'LAUNCHER'
#!/bin/sh
# Opens this Emacs with its bundled settings, packages and grammars. Double-click this file
# (or run ./"Open Custom Emacs.command" [files] from a terminal). Everything it needs is in
# this folder; it does not touch, or need, Homebrew or any system Emacs.
HERE="$(cd "$(dirname "$0")" && pwd)"
APP="$HERE/Emacs.app/Contents"
export EMACSLOADPATH="$APP/Resources/lisp/"
export EMACSDATA="$APP/Resources/etc"
export EMACSDOC="$APP/Resources/etc"
export EMACSPATH="$APP/libexec/arch"
export PATH="$HERE/tools/rg:$HERE/tools/fd:$HERE/tools/dua:$HERE/tools/delta:$PATH"
# Emacs's own portable-dump lookup is relative to the executable's real on-disk path using a
# directory name baked in at compile time (the exact target triple, e.g.
# "aarch64-apple-darwin24.6.0") -- this bundle renames that directory to the plain "arch" above
# for clarity, which breaks that implicit lookup silently: Emacs still starts, but falls all the
# way back to interpreting raw Lisp sources via loadup.el (the same bootstrap process used to
# BUILD Emacs in the first place) instead of using the fast, already-dumped image, confirmed
# directly ("Loading loadup.el (source)...", then a real crash partway through: "Symbol's
# function definition is void: file-name-sans-extension"). --dump-file names the exact .pdmp
# file explicitly, bypassing that broken path inference entirely.
DUMP="$(find "$APP/libexec/arch" -maxdepth 1 -name '*.pdmp' | head -1)"
exec "$APP/MacOS/Emacs" --dump-file="$DUMP" --init-directory="$HERE/config" "$@"
LAUNCHER
chmod +x "$STAGE/Open Custom Emacs.command"

cat > "$STAGE/README.txt" <<EOF
Custom Emacs, portable, for macOS (Apple Silicon / arm64).

  Run:  double-click  "Open Custom Emacs.command"
        (opens a Terminal window briefly, then the real Emacs GUI window; this is a plain
        shell script, not a signed, notarized .app, so this is simpler and more honest than
        pretending Emacs.app alone is double-click-ready -- see "What is inside" below)

Nothing to install, nothing to compile, no Homebrew needed. Everything is in this folder:
  Emacs.app/        GNU Emacs $EMACS_VERSION (emacs-plus build: native compilation, tree-sitter,
                     a real Cocoa GUI), fully self-contained -- every library it needs, and its
                     lisp/etc/libexec trees, are copied inside Contents/, not looked up on the
                     machine that built this bundle
  config/            your settings, the packages (Evil, Magit, Treemacs, Consult, vterm, themes,
                     ...), and tree-sitter grammars for Java, Rust, HTML, CSS, JavaScript/JSX,
                     TypeScript/TSX and JSON
  tools/             rg, fd, dua, delta -- fast search, disk usage, nicer Magit diffs; git for
                     Magit is NOT bundled, macOS ships its own (Xcode Command Line Tools)
  docs/              every guide, also readable inside Emacs itself: press C-c d

Your changes are saved in config/, so put this folder somewhere you can write (not a read-only
volume). Keep every folder together; you can move or copy the whole thing anywhere.

Gatekeeper note: Emacs.app here is only ad-hoc signed (not notarized by Apple), same as any
Homebrew-built app. Because it is launched via the .command script rather than double-clicked
directly, macOS generally does not show the usual "unidentified developer" dialog the first
time; if it ever does, right-click > Open once.

If something inside this folder (e.g. the fast finder, C-c f p) gets silently killed the first
time you use it, that is Gatekeeper too: Finder's Archive Utility stamps every file in a
downloaded zip as quarantined when you extract it, and a plain "right-click > Open" only
clears that for the one app you clicked, not everything else in the folder. Clear it from
a terminal, for the WHOLE folder (cd here first, or replace the dot with its full path):
  xattr -cr .
(every file this bundle ships is already writable so that command cannot silently skip any
of them with a permission error, the way it would on an unmodified, read-only Homebrew copy).

This bundle does NOT include a Java language server (jdtls) or a Rust toolchain/rust-analyzer --
install those yourself if you want Java/Rust code intelligence (M-x eglot); see LANGUAGES.md.
Press C-c d for every guide in one buffer (README.md and docs/*.md), built the moment Emacs starts.
Emacs is licensed under the GNU GPL v3+; emacs-plus: https://github.com/d12frosted/homebrew-emacs-plus
Full guide: DISTRIBUTION.md in this folder, or https://github.com/wantharry/custom-emacs.
EOF
cp "$ROOT/docs/DISTRIBUTION.md" "$STAGE/DISTRIBUTION.md" 2>/dev/null || true

echo "== make everything owner-writable (a real bug this avoids: Homebrew ships some binaries"
echo "   read-only, e.g. fd/dua, 555 not 755; so do the vendored .git packs inside the VC-"
echo "   installed theme packages -- Archive Utility stamps com.apple.quarantine on every file"
echo "   when a downloaded, quarantined zip is extracted, and removing that xattr needs write"
echo "   permission on the file; without this, \`xattr -cr\` on the unzipped bundle silently"
echo "   fails on exactly these files with Permission denied, and macOS then SIGKILLs the"
echo "   still-quarantined fd the first time C-c f p tries to run it -- confirmed directly,"
echo "   not hypothetical)"
chmod -R u+w "$STAGE"

echo "== zip (ditto, not plain zip -- preserves the .app bundles' code signatures and resource forks)"
rm -f "$DIST/$NAME.zip"
mkdir -p "$DIST"
# --keepParent wraps one top-level folder named "$NAME" (the directory given, by name) --
# the normal, expected convention for an archive like this, and safe: Archive Utility's
# "Extract" never double-nests a zip whose entries are already wrapped in one folder.
( cd "$DIST/stage" && ditto -c -k --sequesterRsrc --keepParent "$NAME" "$DIST/$NAME.zip" )
ls -lh "$DIST/$NAME.zip"
du -sh "$STAGE"
