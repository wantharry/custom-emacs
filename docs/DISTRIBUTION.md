# Portable bundles: unzip and run

A bundle is one zip that holds Emacs, your settings, the packages and the helper programs. You unzip it
anywhere and open `Emacs.exe`. Nothing is installed and nothing is downloaded.

| Bundle | File | Status |
|---|---|---|
| **Windows 10/11, 64-bit** | `custom-emacs-windows-x64.zip` (about 247 MB zipped, 644 MB unpacked, with Java) | **Built and tested**, described below |
| Linux x86-64 | not packaged yet | Next. The Linux build here is Emacs 32, which needs its libraries carried along; see [Linux](#linux) |

The zip is in `dist/` after `./build.sh dist windows` and is **not** committed to git (it is about 247 MB and
rebuilt from what is in git).

## Windows

### Using it

1. Unzip `custom-emacs-windows-x64.zip` anywhere you can write (Desktop, `C:\Tools`, a USB stick).
2. Double-click **`Emacs.exe`**.

That is all. It opens on the start screen ([START-SCREEN.md](START-SCREEN.md)):

![the start screen on Windows](images/windows-1-start-screen.png)

Everything else behaves as in the Linux guides: Java highlighted by tree-sitter, the fast finder on
`C-c f f`, Magit on `C-x g`, Consult on `C-c s l/g/f/b`, and finding every git repository on the computer
with `C-c f p` — drawn instantly from a saved index (like the recent-files list), refreshed in the
background; on Windows this runs the bundled `fd.exe` directly across every local drive letter, no
shell script needed (found 36 real repositories on the machine this was tested on). Each result opens
with Magit, Dired or Treemacs (`RET`/click, `d`, `t`).

![Java on Windows](images/windows-2-java.png)

![the finder on Windows](images/windows-4-finder.png)

![Magit on Windows](images/windows-3-magit.png)

![consult-ripgrep on Windows, live preview](images/windows-5-consult.png)

*`C-c s g area`: the same live-preview results list as on Linux, using the bundled `rg`.*

![C-c f p on Windows: every git repository found, no shell script](images/windows-6-gitrepos.png)

*`C-c f p`: the bundled `fd.exe` found 36 real repositories across this machine's drives; clicking one opens Magit.*

*These are real screenshots of the unpacked bundle. The demo project and history are examples.*

### What is inside

```
custom-emacs-windows-x64/
├── Emacs.exe          the launcher you double-click (76 KB; source: tools/windows-launcher.c)
├── emacs/             GNU Emacs 31.1 for Windows, the official unmodified build, with all its libraries
├── config/            your settings: early-init.el, init.el, fastfind.el, startpage.el, docsbuffer.el, gitfolders.el
│   ├── elpa/          Evil, Magit, Treemacs and Consult (and their helpers), compiled by the Windows Emacs
│   └── tree-sitter/   grammars for Windows: Java, Rust, HTML, CSS, JavaScript/JSX, TypeScript/TSX, JSON
├── tools/
│   ├── git/           MinGit 2.55: Git for Magit, with its own small shell
│   ├── rg/            ripgrep: the fast finder, project text search, and Consult
│   ├── fd/            fd: file finding for Consult (`C-c s f`) and for finding git repositories (`C-c f p`)
│   └── jdtls/         the Java language server (needs your own JDK 17+ on PATH/JAVA_HOME; not bundled)
├── docs/              every guide, plain text, read from inside Emacs with `C-c d` (see below)
├── README.md          this project's own overview (also inside the `C-c d` buffer)
├── README.txt         this bundle's own quick-start
└── DISTRIBUTION.md    this guide
```

What `Emacs.exe` does when you start it: finds its own folder; puts the bundled Git, ripgrep and fd first on
`PATH`; sets `HOME` to your user profile if it is not set, so `~` means `C:\Users\you`; and starts
`emacs\bin\runemacs.exe` (Emacs without a console window) pointing at `config\`. Files or options you give
`Emacs.exe` are passed on to Emacs, so `Emacs.exe notes.txt` opens that file.

**Every guide is inside Emacs itself.** Press `C-c d` for a single buffer, `*docs*`, holding this project's
README and every `docs\*.md` guide, folded with `outline-mode` and with a clickable table of contents. It is
built the moment Emacs starts (about 2 ms; measured identical content on Windows and Linux, 257,570
characters), so it is there even with no network. See [CUSTOMIZING.md](CUSTOMIZING.md).

**Your changes are saved in the bundle's `config\` folder**: recent files, the folder and project history,
backups and anything `M-x customize` saves. Copying or moving the whole folder moves them with it. It also
means the folder must be writable, so do not put it under `C:\Program Files`.

### How it differs from the Linux build

| | Linux (this repository's build) | Windows bundle |
|---|---|---|
| Emacs | 32.0.50, built from source here | **31.1**, the official GNU build for Windows |
| Native compilation | yes (built-in code is native) | **no**: the official Windows build does not include it, so packages run byte-compiled |
| Speed | startup 0.05 s (measured, headless) | 0.23 s until the window is ready, measured in a real window |
| Line endings for new files | LF | LF: the config sets UTF-8 with LF on Windows (Windows Emacs would otherwise write CRLF). Files that already have CRLF keep them |
| Whole-disk file index | the whole `/`, minus system folders | the drive of your home folder (normally `C:\`), minus `Windows`, `Program Files`, `ProgramData` and a few noisy `AppData` folders |
| Java | install a JDK and `jdtls` yourself | `jdtls` **included**; install your own JDK (17+) so `java` is on PATH/JAVA_HOME ([EGLOT.md](EGLOT.md)) |
| Rust | install a toolchain and `rust-analyzer` | not included (it needs a Rust toolchain), same as Java's JDK |
| HTML/CSS/JS/TS/JSX/JSON editing (tree-sitter) | install grammars yourself | **included**: fast highlighting/indent/imenu, no language server yet (see [LANGUAGES.md](LANGUAGES.md)) |
| `fd` (for Consult's `C-c s f`) | download yourself (no `apt`/`sudo` route; see [SEARCH-OPTIONS.md](SEARCH-OPTIONS.md#9-setting-up-rg-and-fd-again)) | **included** |

The version difference is deliberate: nobody publishes a Windows build of the Emacs 32 development version,
and compiling one needs a Windows toolchain. Emacs 31.1 runs the same configuration; the test results below
show what was checked.

### What was verified

Everything here was run on the actual bundle, unzipped fresh with Windows' own extractor, on Windows 11 Home
(version 10.0.26200, the machine this was built on), driven from WSL. It was **not** tried on Windows 10 or on another PC.

| Check | Result |
|---|---|
| The zip's Emacs matches GNU's published SHA-256 | Yes (the build script refuses to continue otherwise) |
| Double-clicking `Emacs.exe` opens a real Windows window, on the start screen | Yes (window system `w32`, screenshots above) |
| Bundled Git and ripgrep are the ones found; `HOME` is set | Yes (Git 2.55.0 reported by Magit) |
| Java and Rust tree-sitter grammars load and parse | Yes (highlighted in the screenshot above) |
| Evil and Magit load | Yes |
| **A real commit through Magit**: stage, `c c`, the message buffer opens (1.6 s), it is editable, `C-c C-c` commits, `git log` shows it, and the source file is still read-only afterwards | Yes |
| Whole-drive index (859,000 files on this PC) | built in 1.6 s, queries 67 to 495 ms |
| **Finding every git repository** (`C-c f p`), indexed and drawn instantly, no shell script, the bundled `fd.exe` directly | Yes: **36 real repositories** found on this PC; clicking one opens a real Magit status on it |
| Offline test suite, the same tests as on Linux, run with the bundle's Emacs | **448 tests: 417 pass, 0 fail, 31 skipped** |
| Contents of the zip (files present, settings identical to the repository, no personal history, packages compiled for Emacs 31) | 12 automated tests in `tests/test_dist.py` |

`java-navigation`'s real-`jdtls` tests all pass on Windows (**27 of 27**, run with `LSP=1 tools/test-windows.sh`).
Consult's `rg`- and `fd`-backed tests also pass (**14 of 14**), and so does finding git repositories
(**10 of 10** that are meaningful there; the other 14 in that file are Linux/WSL-only, since the Linux side
still uses `tools/find-repos.sh`, a bash script). The 31 skips could not apply there: 14 are that Linux/WSL-only
half, 4 need a Rust toolchain, 3 are network tests you switch on yourself, 4 check the pruned Linux install,
4 check the Linux build (Emacs 32, native compilation), and 2 need symbolic links (Windows allows them only in
Developer Mode or as administrator; the tests skip themselves when the system refuses).

**Not run on Windows:** the real-window and real-terminal tests (they use a Linux windowing setup and
`tmux`). Instead the checks in the table above were scripted inside the real window, and the screenshots
are the evidence for what it looks like.

### Bugs this work found (and fixed)

Running the existing tests on Windows found real problems in code that had only run on Linux:

- The fast finder built its index with `sh -c ... && mv`, which does not exist on plain Windows. It now
  runs the search program directly and moves the finished file itself, with no shell, on both systems.
- ripgrep prints `C:\path\file` on Windows; the finder matches `/`. It now asks ripgrep for `/` separators.
- The default excluded folders were Linux folders. Windows gets its own list.
- The index build asked Emacs for a pseudo-terminal, and ripgrep then printed colored paths. It now uses a
  plain pipe (this affected Linux too, once the shell was removed).
- New files were saved with CRLF line endings. Now LF.
- `consult-fd`'s own file-name matching is untouched by the ripgrep fix above (it calls `fd` directly, not through
  our finder), so its test asserted a forward-slash path and failed against `fd`'s native `\` output on Windows;
  the test now compares paths with separators normalized, which is the correct fix (Emacs itself opens a
  backslash path on Windows without trouble).

### Limits and things to know

- **Unsigned.** The launcher is not code-signed. If you download the zip from the internet, Windows
  SmartScreen may show "Windows protected your PC" the first time; choose **More info**, then **Run anyway**.
  Some antivirus programs distrust small unsigned programs; `tools/windows-launcher.c` is 66 lines you can
  read and rebuild. (Not tested against SmartScreen: the copy used here did not come from the internet.)
- **`grep` from the bundled Git treats a backslash differently** from Linux `grep`. It is only a fallback
  when ripgrep is missing, and ripgrep is always in the bundle.
- **x64 only.** On Windows on ARM it should run through Windows' emulation; not tried.
- **Not portable across drives for the history.** The recent-files list stores full paths, so files that
  are on a drive letter that changes (a USB stick) will not open until the letter matches.
- The bundle contains programs with their own licenses: GNU Emacs (GPL v3+), MinGit (GPL v2, see
  `tools\git\LICENSE.txt`), ripgrep (MIT or Unlicense). The Emacs source is at
  https://git.savannah.gnu.org/emacs.git and GNU's Windows build recipe is on the same site.

### Building it yourself

From WSL (or any Linux with `7z` and the ability to run `cmd.exe`; the compile step runs the Windows Emacs):

```sh
./build.sh packages                 # once: Evil and Magit into config/elpa
./build.sh dist windows             # about 1 minute; downloads about 130 MB the first time
tools/test-windows.sh /mnt/c/path/to/unzipped/custom-emacs-windows-x64      # optional: run the offline tests with it
LSP=1 tools/test-windows.sh /mnt/c/path/to/unzipped/custom-emacs-windows-x64 java-navigation   # optional: with a real jdtls too
```

`./build.sh dist windows` does, in order: downloads the official Emacs 31.1 zip and checks it against GNU's
published checksum; downloads MinGit, ripgrep and fd (fd's checksum is fetched from GitHub's own release API); **cross-compiles** the Java and Rust grammars and
`Emacs.exe` for Windows with the `zig` compiler (installed into `dist/.venv`, not on your system);
copies in the four config files and `elpa/`; **recompiles the packages with the bundled Windows Emacs**
(compiled files must come from the Emacs that runs them); and zips. The downloads are cached in
`dist/cache/`.

To update the bundle after you change anything in `config/`: run it again, then run
`python3 -m unittest tests.test_dist`, which fails if the zip's settings differ from the repository.

## Linux

Not packaged yet. The plan: the build made here (Emacs 32, the exact one you run) plus every shared library
it needs (it links about 100, including GTK), the settings, packages, grammars and ripgrep, in one folder with
a launcher, in `.tar.gz` and `.zip`. A first attempt exists and is being finished and tested in a clean
Ubuntu container without GTK installed, since a bundle is only proven when it runs where nothing is
installed. Ask for it and it is the next job.
