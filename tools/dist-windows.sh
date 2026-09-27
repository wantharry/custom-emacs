#!/usr/bin/env bash
# Build the portable Windows bundle, from Linux/WSL, without Windows tooling except that WSL can
# run Windows programs (used to compile the packages with the Windows Emacs itself).
#
#   tools/dist-windows.sh          -> dist/custom-emacs-windows-x64.zip
#
# What goes in the zip: Emacs.exe (a launcher), the official GNU Emacs 31 for Windows (with all its
# libraries), your settings (config/), Evil and Magit compiled for that Emacs, tree-sitter grammars
# for Java and Rust, ripgrep, and a portable Git (MinGit).  See docs/DISTRIBUTION.md.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST="$ROOT/dist"; CACHE="$DIST/cache"
NAME=custom-emacs-windows-x64
STAGE="$DIST/stage/$NAME"
EMACS_ZIP=emacs-31.1_1.zip
EMACS_URL=https://ftp.gnu.org/gnu/emacs/windows/emacs-31
RG_VERSION="${RG_VERSION:-14.1.1}"
FD_VERSION="${FD_VERSION:-10.5.0}"
JDTLS_VERSION="${JDTLS_VERSION:-1.61.0}"      # the Java language server; same version as in WSL here
                                                # (needs a JDK 21+ on PATH or JAVA_HOME; none is bundled)
MINGIT_URL="${MINGIT_URL:-https://github.com/git-for-windows/git/releases/download/v2.55.0.windows.5/MinGit-2.55.0.5-64-bit.zip}"
ZIG=("$DIST/.venv/bin/python" -m ziglang)
[ -x "$DIST/.venv/bin/python" ] || { echo "no dist/.venv: run  python3 -m venv dist/.venv && dist/.venv/bin/pip install ziglang patchelf" >&2; exit 1; }
command -v 7z >/dev/null || { echo "7z is needed to make the zip (sudo apt-get install p7zip-full)" >&2; exit 1; }
command -v cmd.exe >/dev/null || { echo "this needs WSL (it runs the Windows Emacs to compile packages)" >&2; exit 1; }
[ -d "$ROOT/config/elpa" ] || { echo "no packages: run ./build.sh packages" >&2; exit 1; }
mkdir -p "$CACHE"

fetch() {   # fetch URL FILE
  [ -s "$CACHE/$2" ] || { echo "   downloading $2"; curl -fSL -s -o "$CACHE/$2.part" "$1" && mv "$CACHE/$2.part" "$CACHE/$2"; }
}

echo "== downloads (cached in dist/cache)"
fetch "$EMACS_URL/emacs-31.1_1-sha256sums.txt" emacs-sums.txt
fetch "$EMACS_URL/$EMACS_ZIP" "$EMACS_ZIP"
want="$(grep " \*$EMACS_ZIP\$" "$CACHE/emacs-sums.txt" | cut -d' ' -f1)"
got="$(sha256sum "$CACHE/$EMACS_ZIP" | cut -d' ' -f1)"
[ -n "$want" ] && [ "$want" = "$got" ] || { echo "CHECKSUM MISMATCH for $EMACS_ZIP" >&2; exit 1; }
echo "   $EMACS_ZIP matches the checksum published by GNU"
fetch "$MINGIT_URL" MinGit-64.zip
fetch "https://github.com/BurntSushi/ripgrep/releases/download/$RG_VERSION/ripgrep-$RG_VERSION-x86_64-pc-windows-msvc.zip" rg-win.zip
FD_ASSET="fd-v$FD_VERSION-x86_64-pc-windows-msvc.zip"
fetch "https://github.com/sharkdp/fd/releases/download/v$FD_VERSION/$FD_ASSET" fd-win.zip
FD_SHA="$(curl -fsSL "https://api.github.com/repos/sharkdp/fd/releases/tags/v$FD_VERSION" | python3 -c "
import json, sys
name = sys.argv[1]
for a in json.load(sys.stdin)['assets']:
    if a['name'] == name:
        print(a['digest'].split(':')[1]); break
" "$FD_ASSET")"
if [ -n "$FD_SHA" ]; then
  [ "$(sha256sum "$CACHE/fd-win.zip" | cut -d' ' -f1)" = "$FD_SHA" ] || { echo "CHECKSUM MISMATCH for fd-win.zip" >&2; exit 1; }
  echo "   fd-win.zip matches the checksum published by GitHub"
else
  echo "   (could not fetch a published checksum for fd-win.zip; proceeding without one)"
fi

echo "== Java: the Java language server, but no JDK (Java needs one installed, same as Rust needs rust-analyzer)"
JDTLS_BASE="https://download.eclipse.org/jdtls/milestones/$JDTLS_VERSION"
JDTLS_FILE="$(curl -fsSL "$JDTLS_BASE/latest.txt" | tr -d '\r\n')"
fetch "$JDTLS_BASE/$JDTLS_FILE" "$JDTLS_FILE"
[ "$(sha256sum "$CACHE/$JDTLS_FILE" | cut -d' ' -f1)" = "$(curl -fsSL "$JDTLS_BASE/$JDTLS_FILE.sha256" | cut -d' ' -f1 | tr -d '\r\n')" ] \
  || { echo "CHECKSUM MISMATCH for $JDTLS_FILE" >&2; exit 1; }
echo "   $JDTLS_FILE matches the checksum published by Eclipse"

echo "== tree-sitter grammars for Windows (cross-compiled with zig, same versions as on Linux)"
mkdir -p "$CACHE/gram"
build_grammar() {   # build_grammar LANG TAG [SUBDIR] [REPO]
  # SUBDIR (default "src") and REPO (default tree-sitter-LANG) are only needed for a
  # grammar repo that holds more than one language, like tree-sitter-typescript's
  # typescript/src and tsx/src --- both from the same repo, so it is only cloned once.
  local l="$1" tag="$2" sub="${3:-src}" repo="${4:-tree-sitter-$1}"
  local d="$CACHE/gram/ts-$repo-$tag"
  [ -f "$CACHE/gram/libtree-sitter-$l.dll" ] && return
  [ -d "$d" ] || git clone -q --depth=1 --branch "$tag" "https://github.com/tree-sitter/$repo" "$d"
  local srcdir="$d/$sub"
  local srcs=("$srcdir/parser.c"); [ -f "$srcdir/scanner.c" ] && srcs+=("$srcdir/scanner.c")
  "${ZIG[@]}" cc -target x86_64-windows-gnu -shared -O2 -I "$srcdir" "${srcs[@]}" -o "$CACHE/gram/libtree-sitter-$l.dll"
}
# keep these in step with `treesit-language-source-alist' in config/init.el
build_grammar java v0.23.5
build_grammar rust v0.23.2
build_grammar html v0.23.2
build_grammar css v0.23.2
build_grammar javascript v0.23.1
build_grammar jsdoc v0.23.2
build_grammar typescript v0.23.2 typescript/src tree-sitter-typescript
build_grammar tsx v0.23.2 tsx/src tree-sitter-typescript
build_grammar json v0.23.0

echo "== launcher (Emacs.exe)"
"${ZIG[@]}" cc -target x86_64-windows-gnu -municode -O2 -s -Wl,--subsystem,windows \
  "$ROOT/tools/windows-launcher.c" -o "$CACHE/Emacs.exe"

echo "== assemble"
rm -rf "$STAGE"; mkdir -p "$STAGE"/{config,tools/rg,tools/fd}
unzip -q "$CACHE/$EMACS_ZIP" -d "$STAGE/emacs"
unzip -q "$CACHE/MinGit-64.zip" -d "$STAGE/tools/git"
unzip -q -j "$CACHE/rg-win.zip" "*/rg.exe" -d "$STAGE/tools/rg"
unzip -q -j "$CACHE/fd-win.zip" "*/fd.exe" -d "$STAGE/tools/fd"
# the language server: only the Windows part (it is started with whatever `java' the user has on
# PATH or JAVA_HOME, no Python needed).  No JDK is bundled: see init.el's my/bundled-jdtls-command.
mkdir -p "$STAGE/tools/jdtls" && tar -xzf "$CACHE/$JDTLS_FILE" -C "$STAGE/tools/jdtls" plugins features config_win
cp "$CACHE/Emacs.exe" "$STAGE/Emacs.exe"
cp "$ROOT"/config/{early-init.el,init.el,fastfind.el,startpage.el,docsbuffer.el,gitfolders.el,llm.el,shortcuts.el} "$STAGE/config/"
# text only (not docs/images/): the *docs* buffer (C-c d) reads these at the same relative
# layout as the git repository, so no code needs to know it is running from a bundle
cp "$ROOT/README.md" "$STAGE/README.md"
mkdir -p "$STAGE/docs" && cp "$ROOT"/docs/*.md "$STAGE/docs/"
mkdir -p "$STAGE/config/tree-sitter"; cp "$CACHE"/gram/*.dll "$STAGE/config/tree-sitter/"
cp -r "$ROOT/config/elpa" "$STAGE/config/elpa"
rm -rf "$STAGE/config/elpa/archives" "$STAGE/config/elpa/gnupg"
find "$STAGE/config/elpa" \( -name '*.elc' -o -name '*.eln' \) -delete   # built by another Emacs; redo below

echo "== compile the packages with the Windows Emacs itself"
TMPWIN="$(cd /mnt/c && cmd.exe /c 'echo %TEMP%' 2>/dev/null | tr -d '\r')"
WT="$(wslpath "$TMPWIN")/custom-emacs-build"
rm -rf "$WT"; mkdir -p "$WT"
cp -r "$STAGE/emacs" "$WT/emacs"; cp -r "$STAGE/config/elpa" "$WT/elpa"
WELPA="$(wslpath -m "$WT/elpa")"
# the packages need each other on the load path while compiling (Magit needs llama, etc.)
"$WT/emacs/bin/emacs.exe" --batch --eval "(progn (setq byte-compile-warnings nil) (dolist (d (directory-files \"$WELPA\" t \"\\\\\`[^.]\")) (when (file-directory-p d) (add-to-list 'load-path d))) (byte-recompile-directory \"$WELPA\" 0 t))" 2>&1 | tail -1
n=$(find "$WT/elpa" -name '*.elc' | wc -l)
[ "$n" -gt 40 ] || { echo "only $n files compiled; expected more" >&2; exit 1; }
rm -rf "$STAGE/config/elpa"; cp -a "$WT/elpa" "$STAGE/config/elpa"; rm -rf "$WT"
# a compiled file must be newer than its source, or Emacs prints "newer than byte-compiled file"
find "$STAGE/config/elpa" -name '*.elc' -exec touch {} +

cat > "$STAGE/README.txt" <<EOF
Custom Emacs, portable, for Windows 10/11 (64-bit).

  Run:  double-click  Emacs.exe

Nothing to install, nothing to download. Everything is in this folder:
  emacs\\   GNU Emacs 31.1 for Windows (official build, unmodified) with its libraries
  config\\  your settings and the packages Evil, Magit, Treemacs and Consult, and tree-sitter grammars for Java, Rust, HTML, CSS, JavaScript/JSX, TypeScript/TSX and JSON
  tools\\   ripgrep and fd (fast search and file finding), a portable Git (for Magit), and the Java
            language server (needs your own JDK 17+ on PATH or JAVA_HOME; not bundled)
  docs\\    every guide, also readable inside Emacs itself: press C-c d
Keep the folders together; you can move or copy the whole folder anywhere, even a USB stick.
Your history, backups and saved settings are written in config\\, so put it somewhere you can write.

Notes: this is Emacs 31.1, not the Emacs 32 development build the Linux version uses, and it has no
native compilation (the official Windows build ships without it), so it runs byte-compiled code.
Java: the language server (jdtls) is included, but not a JDK --- install one yourself (17+), so
"java" is on PATH or JAVA_HOME, then M-x eglot in a Java project (definitions, references, etc.).
Rust's rust-analyzer is a separate program and is not included, the same as Java's JDK.
Consult (C-c s l/g/f/b) is included and works out of the box: it uses the bundled rg and fd.
Press C-c d for every guide in one buffer (README.md and docs\\*.md), built the moment Emacs starts.
GNU Emacs is licensed under the GPL v3+ (https://www.gnu.org/software/emacs/), MinGit under GPL v2
(tools\\git\\LICENSE.txt) and ripgrep under MIT/Unlicense. Full guide: DISTRIBUTION.md.
EOF
cp "$ROOT/docs/DISTRIBUTION.md" "$STAGE/DISTRIBUTION.md" 2>/dev/null || true

echo "== zip"
rm -f "$DIST/$NAME.zip"
# The zip's own top-level entries are the files themselves (Emacs.exe, emacs/, config/, ...), not
# one more "$NAME/" wrapping them.  Zipping "$NAME" as a single entry (the previous approach) meant
# that Windows' "Extract All" wizard, which proposes a destination folder named after the zip
# minus ".zip" (i.e. also "$NAME"), extracted that one folder INTO a second folder of the same
# name: "$NAME\$NAME\Emacs.exe" instead of "$NAME\Emacs.exe". Zipping the contents directly avoids
# the doubling regardless of what the person names the folder they extract into.
( cd "$STAGE" && 7z a -tzip -mx=6 -bso0 -bsp0 "$DIST/$NAME.zip" * )
ls -lh "$DIST/$NAME.zip"; du -sh "$STAGE"
