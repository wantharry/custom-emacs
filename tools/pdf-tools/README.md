# Bundled `epdfinfo.exe` (pdf-tools' native helper, for Windows)

`pdf-tools` (the Emacs package, already in `config/elpa`) replaces the built-in
`doc-view-mode` with real searchable/selectable PDF text, but it needs a native helper
program, `epdfinfo`, built from C against `poppler-glib`. Building that from source needs
a C compiler and poppler's development headers --- neither exists on a fresh Windows
machine, and this build process cannot `apt-get install` anything there. See the comment
above the `(when (and (locate-library "pdf-tools") ...))` block in `config/init.el` for
why the Linux build still works that way (it has a real `apt-get` route, just needs the
user to run it once); Windows does not, so it gets this instead: a real, prebuilt
`epdfinfo.exe` plus every DLL it actually needs, so the Windows bundle works with zero
install, matching every other tool already bundled here (`tools/git`, `tools/fonts`, ...).

## Where `epdfinfo.exe` came from

MSYS2 publishes a prebuilt `epdfinfo.exe` as the UCRT64 package
`mingw-w64-ucrt-x86_64-emacs-pdf-tools-server` (<https://packages.msys2.org/packages/mingw-w64-ucrt-x86_64-emacs-pdf-tools-server>) ---
the same binary MSYS2 users get via `pacman -S`. Fetched directly from MSYS2's own mirror
(`mirror.msys2.org/mingw/ucrt64/...`), verified against the SHA256 checksum in MSYS2's own
`ucrt64.db` sync database (the same file `pacman` itself uses to verify packages), no
different from how `tools/git` (MinGit) or `tools/rg`/`tools/fd`/`tools/delta`/`tools/dua`
are fetched and verified elsewhere in this project.

## Where the other 53 files came from

`epdfinfo.exe` dynamically links against `poppler-glib`, which pulls in a real dependency
tree (cairo, glib, freetype, fontconfig, harfbuzz, openssl, nss, curl, ...). Windows loads
a program's DLLs from its own directory first, so the fix is to put every DLL it actually
needs right next to it --- but MSYS2's own *declared* package-level `Dependencies:` field
is not the right source for that list: it is the whole package's dependencies (including
command-line tools these libraries ship that `epdfinfo.exe` never calls), which pulled in
things like Python, Tcl/Tk and a full GnuTLS/SQLite stack that `epdfinfo.exe` does not
actually import. The real list was resolved the correct way instead: reading
`epdfinfo.exe`'s own PE import table (`objdump -p`) to find the DLLs it actually imports,
then recursively doing the same for each of *those* DLLs, stopping only at genuine Windows
system DLLs (`KERNEL32.dll`, the `api-ms-win-*` set, `dwrite.dll`, `usp10.dll`, ...) that
every Windows machine already has. That closure is the 53 DLLs here --- confirmed complete
by re-running the same import-table walk against the files actually collected and checking
every non-system import resolves locally (it does).

This is noticeably smaller than what the package-level dependency list would have pulled
in (the Python/Tcl/Tk/SQLite detour above), and --- unlike those --- is a real, checked
fact about what this specific binary needs, not an assumption.

## Real verification performed, not just file presence

Starting the real Windows Emacs (from this bundle's own `emacs/bin/emacs.exe`, run
directly from WSL the same way `tools/dist-windows.sh` already runs it to compile
packages) with `pdf-info-epdfinfo-program` pointed at this `epdfinfo.exe`:
`(pdf-info-check-epdfinfo)` returned without error, `(pdf-info-open ...)` on a real
hand-built single-page PDF returned successfully, and `(pdf-info-number-of-pages ...)`
correctly reported `1`. That confirms the whole DLL closure genuinely resolves and
`epdfinfo.exe` genuinely parses a real PDF through poppler --- not just that the files
exist on disk.

## Licenses

41 packages went into this (`epdfinfo.exe` itself plus 40 library dependencies). Each
one's own license file, as MSYS2 itself ships it (`ucrt64/share/licenses/<pkg>/` inside
their package), is copied into `licenses/<pkg>/` here --- except `libidn2` and `poppler`,
whose MSYS2 packages do not embed one; those two are fetched directly from each project's
own upstream repository instead (`licenses/libidn2/`, `licenses/poppler/`).

Several of these are copyleft (GPL/LGPL): notably `poppler` itself
(GPL-2.0-or-later), `emacs-pdf-tools-server` (GPL-3.0), `jbigkit` (GPL-2.0), and
`libgcc`/`libstdc++`/`gettext-runtime` (GPL-3.0-or-later, with GCC's linking exception for
the first two). None of these binaries are modified from what MSYS2 publishes --- they are
straight, unmodified copies of MSYS2's own public UCRT64 packages. Corresponding source
for every one of them is already public: MSYS2's own build recipes at
<https://github.com/msys2/MINGW-packages>, and each project's own upstream source at the
URL in its license file / the `%URL%` field of MSYS2's package database.

| package | version | license (SPDX) |
|---|---|---|
| emacs-pdf-tools-server | 1.3.0-2 | GPL-3.0 |
| brotli | 1.2.0-1 | MIT |
| bzip2 | 1.0.8-4 | custom (bzip2 license) |
| cairo | 1.18.6-2 | LGPL-2.1-or-later OR MPL-1.1 |
| curl | 8.23.0-1 | MIT |
| expat | 2.9.0-1 | MIT |
| fontconfig | 2.18.3-1 | custom (fontconfig license) |
| freetype | 2.15.0-1 | GPL-2.0-or-later OR FTL |
| gettext-runtime | 1.0-1 | GPL-3.0-or-later AND LGPL-2.1-or-later |
| glib2 | 2.90.1-1 | LGPL-2.1-or-later |
| graphite2 | 1.3.15-1 | LGPL-2.1-or-later |
| harfbuzz | 14.6.0-1 | MIT |
| jbigkit | 2.1-6 | GPL-2.0 |
| lcms2 | 2.19.1-1 | MIT AND GPL-3.0-or-later |
| lerc | 4.1.1-1 | Apache-2.0 |
| libdeflate | 1.26-1 | MIT |
| libffi | 3.8.0-1 | MIT |
| libgcc | 16.2.0-6 | GPL-3.0-or-later WITH GCC-exception-3.1 AND GFDL-1.3-or-later |
| libiconv | 1.19-1 | LGPL-2.1-or-later |
| libidn2 | 2.3.8-4 | GPL-2.0-or-later (dual LGPLv3/GPLv2, see `licenses/libidn2/`) |
| libjpeg-turbo | 3.2.0-1 | custom (BSD-like) |
| libpng | 1.6.59-1 | custom (libpng license) |
| libpsl | 0.21.5-3 | MIT |
| libssh2 | 1.11.1-2 | BSD-3-Clause |
| libstdc++ | 16.2.0-6 | GPL-3.0-or-later WITH GCC-exception-3.1 AND GFDL-1.3-or-later |
| libtiff | 4.7.2-2 | MIT |
| libunistring | 1.4.2-1 | LGPL-3.0-or-later OR GPL-3.0-or-later |
| libwebp | 1.6.0-1 | BSD-3-Clause |
| libwinpthread | 14.0.0.r426.g4564ee4b5-2 | MIT AND BSD-3-Clause |
| nghttp2 | 1.70.0-1 | MIT |
| nghttp3 | 1.18.0-1 | MIT |
| ngtcp2 | 1.25.0-1 | MIT |
| nspr | 4.40-1 | MPL-2.0 |
| nss | 3.131-1 | MPL-2.0 |
| openjpeg2 | 2.5.4-2 | BSD-2-Clause |
| openssl | 3.6.5-1 | Apache-2.0 |
| pcre2 | 10.49-1 | BSD-3-Clause |
| pixman | 0.46.4-3 | MIT |
| poppler | 26.08.0-1 | GPL-2.0-or-later (see `licenses/poppler/`) |
| xz | 5.8.4-1 | 0BSD AND LGPL-2.1-or-later AND GPL-2.0-or-later |
| zlib | 1.3.2-2 | Zlib |
| zstd | 1.5.7-2 | BSD-3-Clause OR GPL-2.0-or-later |

## Size

~39 MB total (54 files: `epdfinfo.exe` + 53 DLLs).
