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

echo "== tree-sitter grammars for Windows (cross-compiled with zig, same versions as on Linux)"
mkdir -p "$CACHE/gram"
build_grammar() {   # build_grammar LANG TAG
  local l="$1" tag="$2" d="$CACHE/gram/ts-$1"
  [ -f "$CACHE/gram/libtree-sitter-$l.dll" ] && return
  [ -d "$d" ] || git clone -q --depth=1 --branch "$tag" "https://github.com/tree-sitter/tree-sitter-$l" "$d"
  local srcs=("$d/src/parser.c"); [ -f "$d/src/scanner.c" ] && srcs+=("$d/src/scanner.c")
  "${ZIG[@]}" cc -target x86_64-windows-gnu -shared -O2 -I "$d/src" "${srcs[@]}" -o "$CACHE/gram/libtree-sitter-$l.dll"
}
# keep these in step with `treesit-language-source-alist' in config/init.el
build_grammar java v0.23.5
build_grammar rust v0.23.2

echo "== launcher (Emacs.exe)"
"${ZIG[@]}" cc -target x86_64-windows-gnu -municode -O2 -s -Wl,--subsystem,windows \
  "$ROOT/tools/windows-launcher.c" -o "$CACHE/Emacs.exe"

echo "== assemble"
rm -rf "$STAGE"; mkdir -p "$STAGE"/{config,tools/rg}
unzip -q "$CACHE/$EMACS_ZIP" -d "$STAGE/emacs"
unzip -q "$CACHE/MinGit-64.zip" -d "$STAGE/tools/git"
unzip -q -j "$CACHE/rg-win.zip" "*/rg.exe" -d "$STAGE/tools/rg"
cp "$CACHE/Emacs.exe" "$STAGE/Emacs.exe"
cp "$ROOT"/config/{early-init.el,init.el,fastfind.el,startpage.el} "$STAGE/config/"
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
  config\\  your settings and the packages Evil and Magit, and tree-sitter grammars for Java and Rust
  tools\\   ripgrep (fast search) and a portable Git (for Magit)
Keep the folders together; you can move or copy the whole folder anywhere, even a USB stick.
Your history, backups and saved settings are written in config\\, so put it somewhere you can write.

Notes: this is Emacs 31.1, not the Emacs 32 development build the Linux version uses, and it has no
native compilation (the official Windows build ships without it), so it runs byte-compiled code.
Language servers (Java's jdtls, Rust's rust-analyzer) are separate programs and are not included.
GNU Emacs is licensed under the GPL v3+ (https://www.gnu.org/software/emacs/), MinGit under GPL v2
(tools\\git\\LICENSE.txt) and ripgrep under MIT/Unlicense. Full guide: DISTRIBUTION.md.
EOF
cp "$ROOT/docs/DISTRIBUTION.md" "$STAGE/DISTRIBUTION.md" 2>/dev/null || true

echo "== zip"
rm -f "$DIST/$NAME.zip"
( cd "$DIST/stage" && 7z a -tzip -mx=6 -bso0 -bsp0 "$DIST/$NAME.zip" "$NAME" )
ls -lh "$DIST/$NAME.zip"; du -sh "$STAGE"
