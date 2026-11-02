#!/usr/bin/env bash
# Build the portable Windows bundle, from Linux/WSL, without Windows tooling except that WSL can
# run Windows programs (used to compile the packages with the Windows Emacs itself).
#
#   tools/dist-windows.sh          -> dist/custom-emacs-windows-x64.zip
#
# What goes in the zip: Emacs.exe (a launcher), the official GNU Emacs 31 for Windows (with all its
# libraries), your settings (config/), Evil and Magit compiled for that Emacs, tree-sitter grammars
# for Java and Rust, ripgrep, fd, delta, dua, a portable Git (MinGit), a real Windows-native Node.js
# runtime, and the JS/TS/HTML/CSS/Angular language servers plus the Angular/Nest CLIs built to run
# under it, and a real Windows-native Python embeddable runtime plus pylsp (dev-ui-ai branch only).
# See docs/DISTRIBUTION.md.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST="$ROOT/dist"; CACHE="$DIST/cache"
NAME=custom-emacs-windows-x64
STAGE="$DIST/stage/$NAME"
EMACS_ZIP=emacs-31.1_1.zip
EMACS_URL=https://ftp.gnu.org/gnu/emacs/windows/emacs-31
RG_VERSION="${RG_VERSION:-14.1.1}"
FD_VERSION="${FD_VERSION:-10.5.0}"
DELTA_VERSION="${DELTA_VERSION:-0.19.2}"
DUA_VERSION="${DUA_VERSION:-2.45.1}"   # my/disk-usage's own backend, config/disk-usage.el
JDTLS_VERSION="${JDTLS_VERSION:-1.61.0}"      # the Java language server; same version as in WSL here
JDK_VERSION="${JDK_VERSION:-21.0.12.1+1}"      # Eclipse Temurin, ported from this project's separate
                                                # `java' branch on request --- a real, genuine Windows-
                                                # native JDK, not just "install your own" the way this
                                                # branch had it before
MAVEN_VERSION="${MAVEN_VERSION:-3.9.9}"        # also ported from the `java' branch, for `C-c i j'
NODE_VERSION="${NODE_VERSION:-26.13.0}"        # same pinned version as tools/node/ (WSL-side); UNLIKE
                                                # jdtls above, this one genuinely gets bundled --- a real
                                                # portable Windows Node.js zip exists, so there is no
                                                # reason to make Windows users install their own, the
                                                # dev-ui-ai branch's JS/TS/HTML/CSS/Angular language
                                                # servers and the Angular/Nest CLIs below need it to run
MINGIT_URL="${MINGIT_URL:-https://github.com/git-for-windows/git/releases/download/v2.55.0.windows.5/MinGit-2.55.0.5-64-bit.zip}"
PYTHON_VERSION="${PYTHON_VERSION:-3.12.3}"     # same version as this machine's own system python3 (WSL
                                                # side), for consistency. The official "embeddable
                                                # package" --- a real, genuinely portable Windows Python
                                                # python.org itself publishes specifically for bundling
                                                # into other applications, not a repackaging done here.
ZIG=("${ZIG_PYTHON:-$DIST/.venv/bin/python}" -m ziglang)
[ -x "${ZIG[0]}" ] || { echo "no dist/.venv: run  python3 -m venv dist/.venv && dist/.venv/bin/pip install ziglang patchelf" >&2; exit 1; }
command -v 7z >/dev/null || { echo "7z is needed to make the zip (sudo apt-get install p7zip-full)" >&2; exit 1; }
command -v cmd.exe >/dev/null || { echo "this needs WSL (it runs the Windows Emacs to compile packages)" >&2; exit 1; }
[ -d "$ROOT/config/elpa" ] || { echo "no packages: run ./build.sh packages" >&2; exit 1; }
mkdir -p "$CACHE"

fetch() {   # fetch URL FILE
  # `--connect-timeout'/`--max-time': curl has no timeout of its own by default, so a
  # stalled connection here would otherwise hang indefinitely instead of failing
  # clearly --- found the hard way, a real CI run stuck for hours on an unrelated
  # network call with the exact same shape (see .github/workflows/test.yml's own
  # comment on the PPA step). 600s is generous for the largest of these (the Emacs
  # zip, the JDK) while still failing in minutes, not hours, if something really is
  # stuck.
  [ -s "$CACHE/$2" ] || { echo "   downloading $2"; curl --connect-timeout 30 --max-time 600 -fSL -s -o "$CACHE/$2.part" "$1" && mv "$CACHE/$2.part" "$CACHE/$2"; }
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
FD_SHA="$(curl --connect-timeout 30 --max-time 60 -fsSL "https://api.github.com/repos/sharkdp/fd/releases/tags/v$FD_VERSION" | python3 -c "
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
DELTA_ASSET="delta-$DELTA_VERSION-x86_64-pc-windows-msvc.zip"
fetch "https://github.com/dandavison/delta/releases/download/$DELTA_VERSION/$DELTA_ASSET" delta-win.zip
DELTA_SHA="$(curl --connect-timeout 30 --max-time 60 -fsSL "https://api.github.com/repos/dandavison/delta/releases/tags/$DELTA_VERSION" | python3 -c "
import json, sys
name = sys.argv[1]
for a in json.load(sys.stdin)['assets']:
    if a['name'] == name:
        print(a['digest'].split(':')[1]); break
" "$DELTA_ASSET")"
if [ -n "$DELTA_SHA" ]; then
  [ "$(sha256sum "$CACHE/delta-win.zip" | cut -d' ' -f1)" = "$DELTA_SHA" ] || { echo "CHECKSUM MISMATCH for delta-win.zip" >&2; exit 1; }
  echo "   delta-win.zip matches the checksum published by GitHub"
else
  echo "   (could not fetch a published checksum for delta-win.zip; proceeding without one)"
fi
DUA_ASSET="dua-v$DUA_VERSION-x86_64-pc-windows-msvc.zip"
fetch "https://github.com/Byron/dua-cli/releases/download/v$DUA_VERSION/$DUA_ASSET" dua-win.zip
DUA_SHA="$(curl --connect-timeout 30 --max-time 60 -fsSL "https://api.github.com/repos/Byron/dua-cli/releases/tags/v$DUA_VERSION" | python3 -c "
import json, sys
name = sys.argv[1]
for a in json.load(sys.stdin)['assets']:
    if a['name'] == name:
        print(a['digest'].split(':')[1]); break
" "$DUA_ASSET")"
if [ -n "$DUA_SHA" ]; then
  [ "$(sha256sum "$CACHE/dua-win.zip" | cut -d' ' -f1)" = "$DUA_SHA" ] || { echo "CHECKSUM MISMATCH for dua-win.zip" >&2; exit 1; }
  echo "   dua-win.zip matches the checksum published by GitHub"
else
  echo "   (could not fetch a published checksum for dua-win.zip; proceeding without one)"
fi

echo "== Node.js (Windows-native, for the JS/TS/HTML/CSS/Angular language servers and Angular/Nest CLIs below)"
NODE_ZIP="node-v$NODE_VERSION-win-x64.zip"
fetch "https://nodejs.org/dist/v$NODE_VERSION/SHASUMS256.txt" "node-sums-$NODE_VERSION.txt"
fetch "https://nodejs.org/dist/v$NODE_VERSION/$NODE_ZIP" "$NODE_ZIP"
want="$(grep "  $NODE_ZIP\$" "$CACHE/node-sums-$NODE_VERSION.txt" | cut -d' ' -f1)"
got="$(sha256sum "$CACHE/$NODE_ZIP" | cut -d' ' -f1)"
[ -n "$want" ] && [ "$want" = "$got" ] || { echo "CHECKSUM MISMATCH for $NODE_ZIP" >&2; exit 1; }
echo "   $NODE_ZIP matches the checksum published by nodejs.org"

echo "== JS/TS/HTML/CSS/Angular language servers, built for Windows (own native bindings, not Linux's)"
# tools/node-lsp/node_modules (built earlier, for WSL, by ./build.sh packages) has LINUX-ONLY
# native bindings baked into it --- confirmed directly, `@oxc-parser/binding-linux-x64-gnu' (a
# transitive dependency's prebuilt parser) --- so copying it as-is into the Windows bundle would
# look fine and then fail at runtime on a real Windows machine. npm (>=9) can target a DIFFERENT
# platform's own optional native dependencies with `--os'/`--cpu', run right here on Linux, with
# no actual Windows machine needed --- confirmed directly: the result below has `@oxc-parser/
# binding-win32-x64-msvc' instead, and nothing Linux-specific left in it. Cached like the
# downloads above (same `tools/node-lsp/package-lock.json', so always the same real versions);
# `--ignore-scripts' because any native postinstall build step could only ever target THIS
# machine (Linux), never Windows, and none of these packages need one to merely be used, not built.
NODE_LSP_WIN="$CACHE/node-lsp-win32"
if [ ! -d "$NODE_LSP_WIN/node_modules" ]; then
  rm -rf "$NODE_LSP_WIN"; mkdir -p "$NODE_LSP_WIN"
  cp "$ROOT/tools/node-lsp/package.json" "$ROOT/tools/node-lsp/package-lock.json" "$NODE_LSP_WIN/"
  ( cd "$NODE_LSP_WIN" && "$ROOT/tools/node/bin/npm" install --os=win32 --cpu=x64 --ignore-scripts --no-audit --no-fund )
fi

echo "== Python (Windows-native embeddable runtime, for pylsp below)"
PYTHON_ZIP="python-$PYTHON_VERSION-embed-amd64.zip"
fetch "https://www.python.org/ftp/python/$PYTHON_VERSION/$PYTHON_ZIP" "$PYTHON_ZIP"
# python.org publishes MD5 for this file on its own release page, not SHA256 (confirmed directly,
# not assumed --- newer releases moved to sigstore/GPG signing instead of a SHA256 column, but this
# one still has the legacy MD5 shown) --- weaker than the SHA256 checks above, stated honestly
# rather than pretended otherwise; HTTPS transport already rules out in-flight tampering.
PYTHON_MD5="${PYTHON_MD5:-38cce2bf5b4de76db19a31f46a0720de}"
[ "$(md5sum "$CACHE/$PYTHON_ZIP" | cut -d' ' -f1)" = "$PYTHON_MD5" ] || { echo "CHECKSUM MISMATCH for $PYTHON_ZIP" >&2; exit 1; }
echo "   $PYTHON_ZIP matches the MD5 published by python.org"

echo "== pylsp (python-lsp-server), built for Windows (same cross-install idea as the Node packages above)"
# The embeddable package above has no pip, and (by design) no site-packages lookup until its own
# `._pth' file is edited --- fixed during assembly, below. Getting `pylsp' and its real dependencies
# (some genuinely compiled: `ujson', `black') onto Windows works the same way the Node packages
# above do: pip (>=20ish) can target ANOTHER platform/Python version/ABI's wheels with `--platform'/
# `--python-version'/`--implementation'/`--abi', combined with `--only-binary=:all:' (refuse to fall
# back to a source build, which could only ever target THIS machine) --- confirmed directly, every
# one of pylsp's dependencies, including the compiled ones, has a real `win_amd64'/`cp312' wheel on
# PyPI. `--target' (not a venv) because the result is copied straight into the embeddable package's
# own `Lib\site-packages' at assembly time, not installed in place here.
PYLSP_WIN="$CACHE/pylsp-win32"
if [ ! -d "$PYLSP_WIN/pylsp" ]; then
  rm -rf "$PYLSP_WIN"; mkdir -p "$PYLSP_WIN"
  "$ROOT/tools/python-lsp/.venv/bin/pip" install \
    --target "$PYLSP_WIN" --platform win_amd64 --python-version 312 --implementation cp --abi cp312 \
    --only-binary=:all: --no-deps --no-compile \
    python-lsp-server python-lsp-jsonrpc jedi parso ujson black click mypy_extensions pathspec \
    packaging platformdirs pluggy docstring-to-markdown typing_extensions importlib_metadata zipp pytokens \
    python-lsp-black
fi

echo "== Java: the language server, plus a real portable JDK and Maven to run it on"
JDTLS_BASE="https://download.eclipse.org/jdtls/milestones/$JDTLS_VERSION"
JDTLS_FILE="$(curl --connect-timeout 30 --max-time 60 -fsSL "$JDTLS_BASE/latest.txt" | tr -d '\r\n')"
fetch "$JDTLS_BASE/$JDTLS_FILE" "$JDTLS_FILE"
[ "$(sha256sum "$CACHE/$JDTLS_FILE" | cut -d' ' -f1)" = "$(curl --connect-timeout 30 --max-time 60 -fsSL "$JDTLS_BASE/$JDTLS_FILE.sha256" | cut -d' ' -f1 | tr -d '\r\n')" ] \
  || { echo "CHECKSUM MISMATCH for $JDTLS_FILE" >&2; exit 1; }
echo "   $JDTLS_FILE matches the checksum published by Eclipse"
# Eclipse Temurin (Adoptium): a real, official OpenJDK build distributed as a plain .zip
# (not an installer) specifically for this "unzip and go" use case. Asset/tag naming
# follows Adoptium's own convention: version "21.0.12.1+1" -> release tag
# "jdk-21.0.12.1%2B1" (URL-encoded '+') and asset "..._21.0.12.1_1.zip" ('+' -> '_').
JDK_TAG="jdk-${JDK_VERSION/+/%2B}"
JDK_ASSET="OpenJDK21U-jdk_x64_windows_hotspot_${JDK_VERSION/+/_}.zip"
JDK_URL="https://github.com/adoptium/temurin21-binaries/releases/download/$JDK_TAG/$JDK_ASSET"
fetch "$JDK_URL" "$JDK_ASSET"
[ "$(sha256sum "$CACHE/$JDK_ASSET" | cut -d' ' -f1)" = "$(curl -fsSL "$JDK_URL.sha256.txt" | cut -d' ' -f1 | tr -d '\r\n')" ] \
  || { echo "CHECKSUM MISMATCH for $JDK_ASSET" >&2; exit 1; }
echo "   $JDK_ASSET matches the checksum published by Adoptium"
# Apache Maven: a plain, official .zip (no installer), the same "unzip and go" shape as
# the JDK above --- Maven itself is pure Java, so it only needs the bundled JDK's `java'
# on PATH (already true, see the launcher) plus `JAVA_HOME' (set in the launcher too).
# `archive.apache.org', not `dlcdn.apache.org' --- confirmed directly, not assumed: `dlcdn'
# only mirrors CURRENT releases and 404s the moment a version rotates off it (hit this for
# real building this), while `archive.apache.org' permanently keeps every released version,
# which is the whole point of that server existing.
MAVEN_ASSET="apache-maven-$MAVEN_VERSION-bin.zip"
MAVEN_URL="https://archive.apache.org/dist/maven/maven-3/$MAVEN_VERSION/binaries/$MAVEN_ASSET"
fetch "$MAVEN_URL" "$MAVEN_ASSET"
[ "$(sha512sum "$CACHE/$MAVEN_ASSET" | cut -d' ' -f1)" = "$(curl -fsSL "$MAVEN_URL.sha512" | tr -d '\r\n')" ] \
  || { echo "CHECKSUM MISMATCH for $MAVEN_ASSET" >&2; exit 1; }
echo "   $MAVEN_ASSET matches the checksum published by Apache"

echo "== tree-sitter grammars for Windows (cross-compiled with zig, same versions as on Linux)"
mkdir -p "$CACHE/gram"
build_grammar() {   # build_grammar LANG TAG [SUBDIR] [REPO]
  # SUBDIR (default "src") and REPO (default tree-sitter-LANG) are only needed for a
  # grammar repo that holds more than one language, like tree-sitter-typescript's
  # typescript/src and tsx/src --- both from the same repo, so it is only cloned once.
  local l="$1" tag="$2" sub="${3:-src}" repo="${4:-tree-sitter-$1}"
  local d="$CACHE/gram/ts-$repo-$tag"
  [ -f "$CACHE/gram/libtree-sitter-$l.dll" ] && return
  [ -d "$d" ] || timeout 120 git clone -q --depth=1 --branch "$tag" "https://github.com/tree-sitter/$repo" "$d"
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
build_grammar python v0.23.6

echo "== launcher (Emacs.exe)"
"${ZIG[@]}" cc -target x86_64-windows-gnu -municode -O2 -s -Wl,--subsystem,windows \
  "$ROOT/tools/windows-launcher.c" -o "$CACHE/Emacs.exe"

echo "== assemble"
rm -rf "$STAGE"; mkdir -p "$STAGE"/{config,tools/rg,tools/fd,tools/delta}
unzip -q "$CACHE/$EMACS_ZIP" -d "$STAGE/emacs"
unzip -q "$CACHE/MinGit-64.zip" -d "$STAGE/tools/git"
unzip -q -j "$CACHE/rg-win.zip" "*/rg.exe" -d "$STAGE/tools/rg"
unzip -q -j "$CACHE/fd-win.zip" "*/fd.exe" -d "$STAGE/tools/fd"
unzip -q -j "$CACHE/delta-win.zip" "*/delta.exe" -d "$STAGE/tools/delta"
unzip -q -j "$CACHE/dua-win.zip" "*/dua.exe" -d "$STAGE/tools/dua"
# the language server: only the Windows part (it is started on the bundled JDK below, no
# Python needed --- see init.el's my/bundled-jdtls-command).
mkdir -p "$STAGE/tools/jdtls" && tar -xzf "$CACHE/$JDTLS_FILE" -C "$STAGE/tools/jdtls" plugins features config_win
# A real, portable JDK so jdtls (and `C-c J'/`C-c i j') has a `java' to run without
# installing anything. Skips `jmods\' and `include\' --- confirmed by `du -sh' on the
# real unpacked JDK that `jmods\' alone is 81 MB of the ~332 MB unpacked total (only for
# `jlink' custom runtime images, never needed just to RUN java/jdtls) and `include\' is
# JNI headers for compiling native code against the JDK, also unneeded here; `bin\',
# `conf\' and `lib\' are what running java actually touches, `legal\' is kept for the
# license texts. The zip's own top-level entry is the release folder itself
# ("jdk-21.0.12.1+1/"), so extract to a scratch folder and move its one subfolder into
# place, the same "strip the top-level dir" idea as the font/MinGit extraction above,
# giving a flat `tools\jdk\bin\java.exe' like `tools\jdtls'.
rm -rf "$CACHE/jdk-tmp"; mkdir -p "$CACHE/jdk-tmp"
unzip -q "$CACHE/$JDK_ASSET" -d "$CACHE/jdk-tmp" "*/bin/*" "*/conf/*" "*/legal/*" "*/lib/*"
mv "$CACHE"/jdk-tmp/*/ "$STAGE/tools/jdk"
rm -rf "$CACHE/jdk-tmp"
# Maven: same "strip the top-level release folder" unzip idiom as the JDK above (the
# zip's own top-level entry is "apache-maven-$MAVEN_VERSION/"), giving a flat
# `tools\maven\bin\mvn.cmd'.
rm -rf "$CACHE/maven-tmp"; mkdir -p "$CACHE/maven-tmp"
unzip -q "$CACHE/$MAVEN_ASSET" -d "$CACHE/maven-tmp"
mv "$CACHE"/maven-tmp/*/ "$STAGE/tools/maven"
rm -rf "$CACHE/maven-tmp"
mkdir -p "$STAGE/tools/node-lsp/bin-windows"
# The WHOLE official distribution, not just `node.exe' --- `npm'/`npx' (and the real `npm'
# package implementing them, under `node_modules/npm/') need to come along too: `ng new'/
# `create-vite'/`create-react-app' and any other on-demand scaffolding a user actually runs
# themselves goes through `npm'/`npx', not just the pre-installed CLIs below, which only cover
# generating files INSIDE an already-scaffolded project (`C-c i a'/`C-c i n'). This is already a
# genuine Windows-native build (unzipped as-is, not cross-installed like the packages below), so
# nothing to verify beyond the checksum already checked above.
unzip -q "$CACHE/$NODE_ZIP" -d "$STAGE/tools"
mv "$STAGE/tools/node-v$NODE_VERSION-win-x64" "$STAGE/tools/node-windows"
cp -a "$NODE_LSP_WIN/node_modules" "$STAGE/tools/node-lsp/node_modules"
# Every `.bin/' in the tree just copied --- the top-level one and each nested package's own --- is
# POSIX symlinks only: npm generates them for whatever OS IT is running on when it creates them,
# never the `--os' TARGET, so none of them work unzipped on Windows at all (confirmed directly).
# Small, hand-written `.cmd' wrappers below stand in instead, each just forwarding to the bundled
# `node.exe' with an explicit path to the real entry script --- the same "construct the real
# command line directly, do not trust a PATH-based shim" lesson `my/bundled-jdtls-command'
# (config/init.el) already needed for Java, just solved here with one small `.cmd' file per tool
# instead of bespoke Lisp. Forward slashes throughout (not `\'): `node.exe' and `cmd.exe' both
# accept them in a file path, and it sidesteps a bash/heredoc backslash-escaping mess for no
# real benefit.
find "$STAGE/tools/node-lsp/node_modules" -type d -name '.bin' -exec rm -rf {} +
write_cmd_shim() {   # write_cmd_shim NAME RELATIVE-ENTRY-SCRIPT-UNDER-node_modules
  printf '@echo off\r\n"%%~dp0../../node-windows/node.exe" "%%~dp0../node_modules/%s" %%*\r\n' "$2" \
    > "$STAGE/tools/node-lsp/bin-windows/$1.cmd"
}
write_cmd_shim typescript-language-server typescript-language-server/lib/cli.mjs
write_cmd_shim vscode-css-language-server vscode-langservers-extracted/bin/vscode-css-language-server
write_cmd_shim vscode-html-language-server vscode-langservers-extracted/bin/vscode-html-language-server
write_cmd_shim vscode-json-language-server vscode-langservers-extracted/bin/vscode-json-language-server
write_cmd_shim vscode-eslint-language-server vscode-langservers-extracted/bin/vscode-eslint-language-server
write_cmd_shim vscode-markdown-language-server vscode-langservers-extracted/bin/vscode-markdown-language-server
write_cmd_shim ngserver @angular/language-server/bin/ngserver
write_cmd_shim ng @angular/cli/bin/ng.js
write_cmd_shim nest @nestjs/cli/bin/nest.js
write_cmd_shim tsc typescript/bin/tsc   # my/run-ts-file's own type-check step (config/init.el)
mkdir -p "$STAGE/tools/python-windows"
unzip -q "$CACHE/$PYTHON_ZIP" -d "$STAGE/tools/python-windows"
# The embeddable package ships with site-packages lookup OFF by default (its own `._pth' comment:
# "Uncomment to run site.main() automatically") --- turned on here, plus `Lib\site-packages' added
# as a real search path, since that is where the cross-installed `pylsp' below actually goes.
PTH="$STAGE/tools/python-windows/python312._pth"
{ cat "$PTH"; echo 'Lib\site-packages'; } > "$PTH.new"
sed -i 's/^#import site/import site/' "$PTH.new"
mv "$PTH.new" "$PTH"
mkdir -p "$STAGE/tools/python-windows/Lib/site-packages"
cp -a "$PYLSP_WIN/." "$STAGE/tools/python-windows/Lib/site-packages/"
# No `.cmd' shim indirection needed here the way the Node-based servers above need one: `pylsp'
# is a real console-script entry point, but cross-installing with `--target' (not a real Windows
# pip run) never generates the little `.exe' launcher pip normally builds for one --- so a single
# one-line `.cmd' invoking `python.exe -m pylsp' stands in, the module form Eglot's own default
# `pylsp' lookup already resolves to on PATH via `exec-suffixes' (confirmed earlier this session:
# `.cmd' is in the Windows default list).
printf '@echo off\r\n"%%~dp0python.exe" -m pylsp %%*\r\n' > "$STAGE/tools/python-windows/pylsp.cmd"
cp "$CACHE/Emacs.exe" "$STAGE/Emacs.exe"
cp "$ROOT"/config/{early-init.el,init.el,fastfind.el,startpage.el,docsbuffer.el,gitfolders.el,llm.el,llm-council.el,shortcuts.el,dictate.el,emacs-session.el,calendar-year.el,mode-reference.el,disk-usage.el,ai-tools.el} "$STAGE/config/"
# text only (not docs/images/): the *docs* buffer (C-c d) reads these at the same relative
# layout as the git repository, so no code needs to know it is running from a bundle
cp "$ROOT/README.md" "$STAGE/README.md"
mkdir -p "$STAGE/docs" && cp "$ROOT"/docs/*.md "$STAGE/docs/"
# All 20 of the `C-c F' fonts (my/fonts, config/init.el), real files not just names --- a font
# is a plain OS resource, never auto-installed, so without this every one of them said "not
# installed" on a fresh machine (the whole point of `C-c F' being honest about what it finds).
# See tools/fonts/README.md for how each was sourced/verified (licenses, family-name gotchas).
cp -r "$ROOT/tools/fonts" "$STAGE/tools/fonts"
# `epdfinfo.exe' (pdf-tools' native helper) plus the 53 DLLs it actually needs --- same
# "real files, not a build step" pattern as the fonts just above. See tools/pdf-tools/
# README.md for exactly where each came from, the real DLL-closure verification, and the
# real functional test (opened a PDF through it, got the right page count back).
cp -r "$ROOT/tools/pdf-tools" "$STAGE/tools/pdf-tools"
mkdir -p "$STAGE/config/tree-sitter"; cp "$CACHE"/gram/*.dll "$STAGE/config/tree-sitter/"
cp -r "$ROOT/config/elpa" "$STAGE/config/elpa"
rm -rf "$STAGE/config/elpa/archives" "$STAGE/config/elpa/gnupg"
find "$STAGE/config/elpa" \( -name '*.elc' -o -name '*.eln' \) -delete   # built by another Emacs; redo below
# A real, found-the-hard-way bug this guards against: `vterm'/`pdf-tools' compile a
# native module/helper from C the first time they are actually USED (see init.el's own
# comments on each) --- if that ever happened on THIS machine first (e.g. while testing
# vterm directly, not through `./build.sh dist'), the result is a REAL, machine-specific
# `build/' directory (a genuine CMake build tree, `CMakeCache.txt' and all, not source)
# sitting in `config/elpa' alongside the package's own real source files, which the
# plain `cp -r' above would otherwise ship straight into the Windows bundle --- baking
# in THIS Linux machine's own absolute path, confirmed for real to make CMake refuse to
# continue on a real Windows machine ("different than the directory ... where
# CMakeCache.txt was created"). `CMakeCache.txt' is the one reliable signal to tell a
# REAL build tree apart from a package's own, legitimate `build/' directory of plain
# SOURCE files (`pdf-tools' ships exactly this: `build/server/epdfinfo.c', never a
# problem, confirmed directly it is not a CMake project at all) --- only directories
# that actually contain one are removed, nothing else.
find "$STAGE/config/elpa" -name 'CMakeCache.txt' -exec dirname {} \; | while read -r d; do rm -rf "$d"; done
find "$STAGE/config/elpa" -maxdepth 2 \( -name '*.so' -o -name '*.dll' -o -name '*.o' \) -delete

echo "== compile the packages with the Windows Emacs itself"
TMPWIN="$(cd /mnt/c && cmd.exe /c 'echo %TEMP%' 2>/dev/null | tr -d '\r')"
WT="$(wslpath "$TMPWIN")/custom-emacs-build"
rm -rf "$WT"; mkdir -p "$WT"
cp -r "$STAGE/emacs" "$WT/emacs"; cp -r "$STAGE/config/elpa" "$WT/elpa"
WELPA="$(wslpath -m "$WT/elpa")"
# the packages need each other on the load path while compiling (Magit needs llama, etc.)
# `(provide 'vterm-module)' --- a real, found-the-hard-way fix for a compile FAILURE
# (not a warning; the whole run previously still reported success at 1 file short):
# `evil-collection-vterm.el' does `(require 'vterm nil t)' at its own top level, which
# finds the real `vterm.el' on `load-path' and loads it for real (NOERROR only
# suppresses a file-not-found, not errors from code THAT file then runs) --- and
# `vterm.el' itself, unconditionally, checks whether `vterm-module' is already
# provided and if not either prompts via `y-or-n-p' (`vterm-always-compile-module'
# nil, the default) or actually tries to compile the native module right then
# (confirmed: setting that variable instead would NOT have been the right fix here,
# since the module genuinely cannot compile on Windows anyway --- see `tests/ert/
# vterm.el''s own comment on the general shape of this bug, a real case of it
# recurring somewhere new). Either way, `y-or-n-p' itself fails immediately in this
# real `--batch' process with no stdin ("Error reading from stdin"). Pretending the
# feature is already provided skips vterm.el's whole check with neither problem ---
# harmless for byte-compilation specifically, which only needs `vterm.el''s plain
# Lisp definitions and `declare-function' forms to satisfy the compiler, never an
# actually-working native module.
"$WT/emacs/bin/emacs.exe" --batch --eval "(progn (provide 'vterm-module) (setq byte-compile-warnings nil) (dolist (d (directory-files \"$WELPA\" t \"\\\\\`[^.]\")) (when (file-directory-p d) (add-to-list 'load-path d))) (byte-recompile-directory \"$WELPA\" 0 t))" 2>&1 | tail -1
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
  config\\  your settings and the packages Evil, Magit, Treemacs and Consult, and tree-sitter grammars for Java, Rust, HTML, CSS, JavaScript/JSX, TypeScript/TSX, JSON and Python
  tools\\   ripgrep and fd (fast search and file finding), delta (nicer Magit diffs), a portable
            Git (for Magit), a real Node.js runtime plus the JS/TS/HTML/CSS/Angular language
            servers and the Angular/Nest CLIs, a real Python runtime plus pylsp, and a real JDK
            plus Maven and the Java language server (all fully bundled, nothing to install)
  docs\\    every guide, also readable inside Emacs itself: press C-c d
Keep the folders together; you can move or copy the whole folder anywhere, even a USB stick.
Your history, backups and saved settings are written in config\\, so put it somewhere you can write.

Notes: this is Emacs 31.1, not the Emacs 32 development build the Linux version uses, and it has no
native compilation (the official Windows build ships without it), so it runs byte-compiled code.
Java: fully bundled (a real JDK and Maven, plus the language server) --- M-x eglot in a .java file
for definitions/references, C-c J to compile and run the current file, C-c i j for Maven goals
(compile/test/package/install/clean/arbitrary) on a real multi-file project with a pom.xml.
Rust's rust-analyzer is a separate program and is not included --- editing, hover and diagnostics
for Rust need your own rust-analyzer; Rust has no bundled compiler/runtime here.
JavaScript/JSX/TypeScript/TSX/HTML/CSS/Angular: fully bundled (a real Node.js runtime and the
language servers themselves), nothing to install --- M-x eglot in a .js/.ts/.tsx/.html/.css file.
Angular/Nest scaffolding (C-c i a / C-c i n) also work out of the box, same reason.
Python: fully bundled too (a real Python runtime and pylsp), nothing to install --- M-x eglot
in a .py file, or C-c i p to run the current file directly.
Consult (C-c s l/g/f/b) is included and works out of the box: it uses the bundled rg and fd.
Magit diffs are rendered with delta (bundled) via magit-delta-mode, on by default.
C-c W browses real disk usage (biggest first) using the bundled dua.
Press C-c d for every guide in one buffer (README.md and docs\\*.md), built the moment Emacs starts.
GNU Emacs is licensed under the GPL v3+ (https://www.gnu.org/software/emacs/), MinGit under GPL v2
(tools\\git\\LICENSE.txt), ripgrep under MIT/Unlicense, delta under MIT, and dua under MIT.
Full guide: DISTRIBUTION.md.
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
