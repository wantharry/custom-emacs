# Conversation log

A running record of what was discussed, built, tried and reverted while working on this
config with an AI assistant (Claude Code), in enough detail that a **new conversation,
possibly with a different LLM entirely**, can pick up where the last one left off without
re-deriving decisions from git history alone. Git history (`git log`) has the *what* and
*when*; this file has the *why*, plus the things that were tried and abandoned, which git
history alone doesn't show. Update it as new work happens, in the same style: short,
factual, dated by feature rather than by clock time.

**Read this first if you are an AI assistant new to this conversation.** See also
[README.md](../README.md) for what the project actually is, and every other guide in
`docs/` for how each feature works.

## Standing instructions from the user (apply until told otherwise)

- **Workflow pacing**: after finishing one feature, run only that feature's own test file
  (`./build.sh test <name>`) and commit --- do **not** run the full regression suite or
  rebuild the Windows dist zip after every single feature. Batch that: after **3-4**
  features have accumulated, run `./build.sh test --full`, and if clean, rebuild the
  Windows zip (`./build.sh dist windows`), verify it (`python3 -m unittest
  tests.test_dist`), and copy it to `/mnt/c/Users/openclaw/Downloads/`. If a commit's own
  pre-commit hook fails ONLY on the known, expected "Windows bundle is stale" diff (not a
  real regression, since the dist zip hasn't been rebuilt yet), use `git commit --no-
  verify`, but only after confirming the rest of the hook's own test output shows zero
  real failures.
- When asked to comment code, use a **WHAT / WHY / HOW** style: what this line/block does,
  why it exists (the real reasoning, a bug it fixes, a tradeoff it makes), and how it
  achieves that --- not just restating the code in English. Applied file-by-file on request;
  see "Commenting pass" below for which files have it so far.
- Caps Lock → Ctrl remapping must be **Emacs-level**, not OS-level. A PowerToys Keyboard
  Manager approach was tried and **fully reverted** (see below) after this correction. Not
  currently planned --- the user said "I'll plan later"; do not act on this again until
  they bring it up.

## Features built this session, in order

Each of these is also documented properly in its own `docs/*.md` guide; this section is
the short, narrative "why" version plus anything that didn't make it into the feature's
own doc (dead ends, things reverted).

### Caps Lock → Ctrl (tried, then fully reverted)

Asked how to make Caps Lock act as Ctrl. Installed PowerToys and configured its Keyboard
Manager to do the remap. **The user then explicitly said this was wrong**: "I don't want
it changed since it's OS level, I want something at Emacs level." The entire PowerToys
change was reverted: the Keyboard Manager module disabled, its `default.json` config
deleted, PowerToys restarted to apply the reversion (confirmed `PowerToys.
KeyboardManagerEngine` no longer running). Three real Emacs-level options were later
outlined (AutoHotkey app-scoped to Emacs only, `god-mode`/leaning on Evil to reduce Ctrl
reliance, or WSL-side `setxkbmap`) but the user deferred: "I'll plan later." **Nothing is
implemented for this**; don't assume any of the three options without asking again.

Also hit and fixed a real bug while doing this: `Get-Content $path | ConvertFrom-Json |
... | Set-Content -Path $path` (same file as source and destination in one PowerShell
pipeline) truncated the file to 0 bytes mid-pipeline. Fixed (before the whole change was
reverted anyway) by reading fully into a variable first, writing to a `.tmp` file, then
`Move-Item -Force`. Worth remembering if a similar same-file-pipeline pattern comes up
again in a PowerShell script.

### uEmacs/PK research (informational only, no repo changes)

Researched and compared `torvalds/uemacs` (MicroEMACS fork) against this real GNU Emacs
build: 169 commands, 14,645 lines of C, 176KB binary, no Elisp. Took real terminal-
emulator screenshots (via `pyte`, since a real GPU terminal emulator failed under WSLg's
Mesa/EGL zink driver) and measured real startup time with a synthetic-keystroke `pty.fork`
harness. **Genuinely surprising finding**: uEmacs was measured *slower* (35.1ms) than this
project's own custom-built GNU Emacs (11.0ms) for a real terminal round trip --- worth
citing if anyone claims "a minimal C editor is obviously faster than Emacs" again. Also
hit and worked around a real uEmacs crash (`*** buffer overflow detected ***`) caused by
modern Ubuntu's default `_FORTIFY_SOURCE`/stack-protector hardening catching a genuine
latent bug in that (old, unmaintained) codebase --- not something fixed in uEmacs itself,
just diagnosed for the comparison.

### Real-time news via built-in newsticker (`C-c n`)

Un-pruned `net/newsticker.el` and `net/newst-*.el` from `prune.list` (they'd been stripped
from this minimal build) and wired up three real, curl-verified-live RSS feeds: BBC World,
NYT US, ESPN top news. Confirmed `newsticker-retrieval-method` defaults to `'intern'`
(uses Emacs's own `url-retrieve`, not an external `wget`), so this works identically on
the Windows bundle with no extra dependency. See [DICTATE.md](DICTATE.md) is unrelated;
newsticker itself has no dedicated doc file yet beyond [KEYBOARD.md](KEYBOARD.md)'s `C-c
n` row and [shortcuts.el](../config/shortcuts.el)'s own packages section.

### Local speech-to-text dictation (`C-c m`)

Built whisper.cpp locally (CPU-only on Linux/WSL; cross-compiled for Windows from WSL via
`zig cc`/`zig c++` targeting `x86_64-windows-gnu`, matching this project's existing
tree-sitter/Emacs.exe cross-compile pattern --- no Windows compiler needed). Model:
`ggml-small.en.bin`, measured 100% correct on a synthesized test sentence, ~3.6-3.8s to
transcribe an 8-second clip. **Real bug found and fixed**: `delete-process` alone on the
recording process does not let it finalize its WAV header (confirmed: `wave.Error: fmt
chunk and/or data chunk missing`); fixed with an explicit `SIGTERM` (Linux) / writing "q"
to stdin (Windows, the only way `ffmpeg` cleanly finalizes there) followed by actually
waiting for the process to exit before `delete-process`. **Another real bug found while
cross-compiling for Windows**: `-DGGML_NATIVE=OFF` alone (for portability) disabled all
CPU SIMD, a measured ~7.5x slowdown (28.5s vs 3.7s) --- fixed by explicitly enabling AVX/
AVX2/FMA/F16C/SSE4.2 instead. Deliberately **not bundled** (binary + model would add
~469MB; matches this project's existing JDK/Node.js precedent of "heavy runtime, user
sets it up, documented, not shipped"). Investigated real GPU/CUDA acceleration in this
WSL2 environment: `nvidia-smi` works but no `nvcc` and no NVIDIA Vulkan ICD were found;
gave the user real `sudo apt-get` commands for NVIDIA's official CUDA toolkit, which they
ran themselves. **The Linux-side rebuild against that new CUDA toolkit (for real GPU
acceleration) was never actually done** --- offered multiple times, always deferred in
favor of continuing with other features. Revisit if dictation speed ever becomes a
priority again. Full writeup: [DICTATE.md](DICTATE.md).

### which-key popup height fix

Real regression, caught by the GUI test suite, not invented: as `C-c n`/`C-c m`/`C-c a c`
were added this session, `C-c`'s own top-level binding list grew past what the default 25%
popup height could show --- confirmed `my/toggle-evil` had scrolled out of the visible,
captured buffer text. Fixed with `(setq which-key-side-window-max-height 0.4)`; verified
36/36 GUI tests pass afterward.

### Extended shortcuts reference (`C-c k`)

Added a second section to the `*shortcuts*` buffer (`my/shortcuts-packages` in
[shortcuts.el](../config/shortcuts.el)): for each package/feature with its own "world"
once open (Magit, Treemacs, Consult, gptel, newsticker, LLM council, and this config's own
git-repos/start-screen/docs buffers), how to open it, how to close it, and a few important
commands once inside. Delegated real-keybinding research to a subagent that read actual
package source rather than guessing; it corrected several assumptions, most notably: Magit
"commit"/"push"/"pull"/"log" are real two-key **transient chains** (`c c`, `P p`, `F p`,
`l l`), not single keystrokes; `gptel-mode-map` binds exactly one key (`C-c RET`); `q` in
`docsbuffer.el`/`shortcuts.el` is bound explicitly (their mode parent is `outline-mode`,
not `special-mode`), unlike `gitfolders.el`/`startpage.el` which genuinely inherit it.
Verified the Magit transient facts programmatically via `transient-get-suffix` (hit and
fixed a real quirk: before a transient's first interactive use it returns a plain `cons`,
not yet an EIEIO object --- use `plist-get`, not `oref`/`slot-value`).

### LLM council (`C-c a c`)

New feature (`config/llm-council.el`): asks one question of three different local Ollama
models in parallel (chosen for being from different trainers/families --- `qwen3:8b`,
`llama3.1:8b`, `gemma2:9b` here --- not near-duplicates), then has a fourth, bigger model
(`gpt-oss:20b` here) compare and summarize their answers. Everything lands in one
`outline-mode` buffer: the summary expanded at the top, each model's raw answer folded
shut below it. Model choice always comes from a live `my/llm-ollama-models' query
(never hardcoded), degrading gracefully on a machine with different models pulled. Every
request uses `:stream nil` so each callback fires exactly once. If a council model fails
it's excluded from the summarizer's prompt (not sent as a blank answer); if every model
fails, no wasted 4th request is sent. 21 tests, 20 passing + 1 real-Ollama round trip
that's opt-in only (`--lsp`). Full writeup: [LLM.md](LLM.md).

### Commenting pass (WHAT / WHY / HOW)

At the user's request, added thorough line-level comments (what a line does, why it
exists --- the real reasoning/bug/tradeoff --- and how it works) to the actual production
Elisp, not just docstrings. Done so far, in this order: `config/llm-council.el`,
`config/dictate.el`, `config/shortcuts.el` (the parts added this session), the relevant
blocks of `config/init.el` (news, dictation, which-key, LLM council, Magit, start screen),
`config/gitfolders.el` (`C-c f p`, "find every git repository"), `config/fastfind.el`
(`C-c f f`/`C-c f g`, the fuzzy file finder), `config/docsbuffer.el` (`C-c d`, the docs
buffer), `config/startpage.el` (the start screen / recent files-folders-projects page).
**A real bug was introduced and caught by tests while doing this**: rewriting `my/ff--in-
order-p` in fastfind.el accidentally dropped the `".*"` separator argument from a
`mapconcat` call, breaking multi-character fuzzy matching --- caught immediately by
`./build.sh test fastfind` (1 real failure) and fixed. Lesson: **always re-run that
file's own test suite after a comment-adding rewrite**, even though comments alone
shouldn't change behavior --- a full-file rewrite is still a rewrite. Not yet commented in
this style (as of this entry): everything else in the repo, including `config/llm.el`,
Magit/Treemacs/Consult/Evil wiring in `init.el` beyond what's listed above, and the test
files themselves. Continue the same file-by-file pattern if asked to keep going.

### A conversation log, so a new session doesn't lose context

At the user's request, added this very file plus `CLAUDE.md` (a repo-root pointer Claude
Code reads automatically at the start of any session here, directing it to this file
first). The intent, in the user's own words: "any new LLM model should start off with
this conv." Update this file after finishing new work, in the same style.

### Finished and documented the Linux portable bundle (`./build.sh dist linux`)

Noticed (while answering "is Linux/Windows building documented?") that `tools/dist-
linux.sh` already existed --- a real, substantial script --- but was **untracked**
(never committed) and out of date: only 4 of this project's 10 `config/*.el` files were
copied, and it called `zip`, which isn't installed here (this environment has `7z`
instead, same as the Windows script already uses). Finished it for real:

- Copied all 10 config files (matching `tools/dist-windows.sh`'s list exactly).
- Switched to `7z` for the `.zip`.
- **Bundled `README.md` + `docs/*.md`**: without this, `C-c d` (the docs buffer) showed
  every guide as `(missing)` inside the bundle --- confirmed for real by actually running
  a freshly-unpacked copy, not just built.
- **Bundled `tools/find-repos.sh`**: without this, `C-c f p` (finding every git
  repository) couldn't run at all inside the bundle (the script it points at didn't
  exist there). The script already falls back from `fd` to plain `find` on its own, so
  no further changes were needed.
- **Fixed a real double-nesting risk in the `.zip` specifically**: it was archiving the
  staged folder by name from its parent, which --- exactly like the already-fixed
  Windows zip bug --- would double-nest if a file manager's "Extract Here" also proposes
  a same-named destination folder. Fixed by archiving the folder's *contents* with no
  wrapping name (the `.tar.gz` keeps its wrapping folder, which is safe/conventional for
  that format since `tar -xzf` never creates its own destination folder).

Verified for real, end to end, not just built: `ldd` shows no missing shared libraries;
a freshly-unpacked copy loads headlessly with every package (Evil, Magit, Treemacs,
Consult, gptel) resolving on `load-path`; a real GUI frame opens under Wayland/WSLg and
closes cleanly, including the relocated GDK pixbuf loader cache (the trickiest part of a
Linux bundle --- GTK needs absolute paths to its image plug-ins, only known once
unpacked); the docs buffer and `C-c f p` both genuinely work; and the **full offline
test suite, run against the bundle's own `app/bin/emacs`** (not the dev build) via
`EMACS=.../app/bin/emacs tests/run-all.sh`, passes: **548 tests, 0 failures, 19
skipped**. Added `LinuxBundle`/`LinuxTarball` to `tests/test_dist.py` (8 tests) so this
stays checked automatically, mirroring `WindowsBundle`.

Honest, real gap documented rather than hidden: **no Java language server (`jdtls`) is
bundled for Linux yet**, unlike Windows. Also explicitly **not yet tried on a genuinely
bare machine** (only tested in this dev environment, which already has the build
dependencies installed) --- that's the natural next check if this gets picked up again.

## Real findings worth remembering (cross-cutting)

- This environment (WSL2 Ubuntu 24.04 + WSLg) has a real GPU (`nvidia-smi` works, CUDA
  13.1 runtime) but **no working GPU-accelerated real terminal emulator** --- alacritty
  fails with Mesa/EGL zink errors. `pyte` (pure-Python terminal emulation) + PIL is the
  working alternative for capturing terminal screenshots here.
- This project's established pattern for a new per-platform binary that needs cross-
  compiling for Windows from WSL is `zig cc`/`zig c++ -target x86_64-windows-gnu` (via
  `python -m ziglang`) --- no Windows compiler needed. Already used for tree-sitter
  grammars, `Emacs.exe` itself, and now whisper.cpp's `whisper-cli.exe`.
- This project's established pattern for a heavy, optional runtime dependency (JDK,
  Node.js, and now whisper.cpp + its model) is: **never bundle it**, document how to set
  it up, and have the feature decline clearly (not crash) when it's missing.
- Every new `config/*.el` file needs adding to a long, consistent list of places:
  `build.sh`, `tests/run-all.sh` (two spots), `tools/doctor.sh`, `tools/dist-windows.sh`,
  `tools/test-windows.sh`, `tests/test_dist.py` (`CONFIG_FILES`), `tests/test_repo.py`,
  `tests/test_tui.py`, `.gitignore`. Easy to miss one; `grep -rn "llm.el" <those files>`
  (or whichever existing file is most similar) is the fastest way to find every spot that
  needs the new filename added alongside it.

### Crash-safe auto-save and session restore (`C-c w`)

User asked: buffers should auto-save, a crash should be recoverable, and Emacs's whole
state (open buffers, window layout) should come back next time --- with a way to reset to
default --- "is there a package like that?" Answer: no package needed, `desktop-save-mode'
(session/window restore) and `auto-save-visited-mode' (real-file auto-save) are both
built into Emacs. New file `config/session.el`, `C-c w s`/`C-c w r`/`C-c w l` (save now /
reset / list what's tracked). Full details in [SESSION.md](SESSION.md); the short version:

- Verified with a real `kill -9` crash (window split, 2 files, one edited after
  unlocking): edited content survived (`auto-save-visited-mode`), and a fresh Emacs
  restored both files, the split, AND correctly re-locked the file that had been left
  unlocked --- restoring a buffer goes through the same `find-file` machinery as opening
  it by hand, so the read-only lock always reapplies.
- **Two real bugs found only by that actual crash test, not by reading the source**:
  (1) `desktop-save`'s second argument is `RELEASE` (let go of the lock), not "force
  save" --- passing it non-nil, an easy mistake made once here, silently defeats the
  periodic autosave forever, since it never gets to claim ownership; (2) the stock 30s
  `desktop-auto-save-timeout` default is too long --- a session crashed well within that
  window had no saved desktop at all; shortened to 10s here.
- **A whole detour chasing a phantom "hang"**: real GUI test runs kept timing out with
  zero output, looking exactly like a genuine deadlock (checked with `/proc/PID/status`,
  `wchan`, fd lists --- no gdb/strace available in this environment). It was never a hang
  at all: twice, a test *script* tried to `insert` into a buffer the read-only lock had
  correctly just re-locked, erroring out mid-timer-callback before ever reaching the
  `kill-emacs` that would have ended it --- the process just sat there alive,
  indistinguishable from stuck without a way to see the actual (silent, off-screen)
  error. Lesson worth repeating: when something built on real, working infrastructure
  looks impossibly stuck, suspect the test's own script before the infrastructure ---
  especially inside a callback whose errors go nowhere visible.
- `desktop-read` is unconditionally a no-op under `noninteractive` (Emacs's own
  documented behavior) --- the real, headless round-trip test in `tests/ert/session.el`
  has to briefly let-bind `noninteractive' to nil to exercise it at all in `--batch`.
- `C-c w l` (list what's tracked) was a follow-up ask ("can it list states like
  buffers?") --- uses `desktop-save-buffer-p`, desktop.el's own real filter, so the list
  never drifts from what would actually be saved.

### Named sessions (`C-c w S`/`O`/`D`/`L`): a second follow-up ask

User then asked: different window positions/states are saved, but how many can be
saved, is that even possible? Answer: yes, unlimited (only disk space) --- desktop.el
already saves/reads per-directory, so a "named session" is just its own directory.
`C-c w S` saves the current buffers/windows under a name, alongside as many others as
you like; `C-c w O` loads one back (replacing what's open, but the LIVE, always-auto-
saved session stays anchored where it was --- opening a snapshot loads it into your live
workspace, it doesn't switch which directory autosave protects); `C-c w D` deletes one;
`C-c w L` lists them all.

**Two more real bugs, same lesson as the RELEASE-argument one, found only by testing
the actual round trip**: (1) `desktop-save` unconditionally does `(setq desktop-dirname
DIRNAME)` as its very first line (plus mutates `desktop-io-file-version`/`desktop-file-
checksum`/`desktop-saved-frameset`) --- a naive "just call it on a different directory"
implementation would have silently repointed the live session's crash protection at the
named snapshot. (2) `desktop-read` claims the lock of whatever it reads and never
releases it, so opening the SAME named session a second time later silently did nothing
("Not reloading the desktop") until fixed to release that lock afterward. A third,
smaller one: re-saving under the same name hit a real "Overwrite this desktop file?"
prompt (or, with no terminal attached, an outright error) because `desktop-file-
modtime` was left at the live session's unrelated value; fixed by setting it to the
named file's own real current modtime first. All three confirmed fixed with a real,
scripted save→open→re-open→re-save cycle before writing the formal tests (11 more, 25
total in `tests/ert/session.el`). Full writeup in [SESSION.md](SESSION.md).

### News: more popular categories (`C-c n`)

User asked to update the news feeds for "more important news," then "get all the
popular ones." Expanded from 3 feeds (World/USA/Sports) to 10: Top Stories, World, USA,
Business, Technology, Politics, Science, Health, Entertainment, Sports --- mostly BBC
(consistent, well-known URL pattern) plus NYT for USA/Politics and ESPN for Sports, same
sourcing convention as before. Every URL curl-verified live (real item counts, 20-52
each) before being added, same as the original three. Added a real, opt-in
(`RUN_NETWORK_TESTS=1`) test, `config/news-every-feed-is-really-live`, that fetches
every configured feed for real via this project's own `url-retrieve-synchronously` path
(not `curl`) and confirms each one --- this didn't exist before; the original three feeds
were only ever checked for URL *syntax*, never actually fetched by the test suite.
Hit a real tool-infrastructure outage mid-task (the server-side safety classifier
stopped returning verdicts for both Bash and WebFetch for a stretch) --- picked back up
once it recovered; the curl verification and test run happened in a later turn than the
config edit itself.

### Minibuffer enhancement: vertico, orderless, marginalia, embark

User asked to install "vertico, marginalia, consult, embark, orderless" (Consult was
already installed) to "enhance the minibuffer." Installed the other four plus
`embark-consult` (a tiny, standard companion package not explicitly asked for, added
since it's essentially required for embark actions to understand Consult's own
candidate lists correctly --- mentioned to the user, not silently assumed). Replaced the
built-in `fido-vertical-mode` with `vertico-mode` + `orderless` (as a completion style)
+ `marginalia-mode`, falling back to `fido-vertical-mode` unchanged if not installed
(same optional-package pattern as everything else here); `C-.`/`C-;`/`C-h B` for Embark.

**A real, self-caused bug found only by testing, not by reading the source**: the new
Completion section was originally placed near the TOP of `init.el` (where the old
`fido-vertical-mode` line had lived), but `config/elpa/*` only gets added to
`load-path` later in the file --- so `(locate-library "vertico")` always returned nil,
silently falling back to `fido-vertical-mode` every time, no error, nothing visibly
wrong. Confirmed for real (`vertico-mode` was void as a variable) and fixed by moving
the whole section to right after the `load-path` bootstrap loop.

**A real, genuine regression, caught by this project's own existing test suite**:
`orderless`'s own default matching styles (literal and regexp only) do not include
anything like `flex`'s "letters in order, not contiguous" fuzzy matching --- and the
previous `completion-styles` (`fido-vertical-mode`'s own) had included `flex`, which
`C-x p f` (`project-find-file`, a real Emacs built-in, not this project's own fast
finder) relies on. `tests/ert/java-navigation.el`'s own pre-existing
`jnav/a-partial-name-finds-the-file-by-fuzzy-matching` failed for real until `flex` was
added back alongside `orderless` (and, separately, to the `file` category override
too, verified both matter with a direct `completion-all-completions` check). This
project's own fast finder (`C-c f f`, fastfind.el) was never at risk either way --- it
already sets its own, fully separate completion style per minibuffer session; confirmed
unaffected, 37/37 still pass.

New `tests/ert/completion.el` (9 tests) hit one more small, real, self-caused bug: a
test asserting Embark is lazy failed because an EARLIER test in the same file
deliberately `require`s Embark for real, and ERT tests in one file share the same
Emacs process --- fixed the same way `llm-council/is-not-loaded-until-used` already
does it, by checking in a fresh subprocess instead of the shared one. 602 tests, 582
pass, 0 fail, 20 skipped across the full offline suite after all of this.

### Live dictation (`C-c M`): transcribed as you speak, not only once you stop

User: "i see its transcribing, but once i stop and transcribe its doing it, i want live
transcribe as i am speaking it should be transcribing." `C-c m` is push-to-talk; this is
a genuinely new, second command (`C-c M`, capital), not a change to `C-c m`.

**Why repeated `whisper-cli` calls can't be live**: *measured* --- a 1.9s clip and a
3.6s clip both took ~3.1-3.2s to transcribe, proving the cost is fixed per-invocation
overhead, not audio length. whisper.cpp ships a second binary for exactly this,
`whisper-server` (loads the model once, answers HTTP requests against it), which
`C-c M` starts on first use and deliberately leaves running afterward.

**Real, measured speed/accuracy tradeoff**: `small.en` stayed ~2.6-2.8s/chunk even
warm and even quantized (q5_0, no real speed win on this hardware); only `base.en` +
greedy decode (`-bo 1 -bs 1`) got genuinely faster than the audio itself, ~0.6-0.7s/chunk.
Real cost: `base.en` misheard "emacs" as "e-max" once, where `small.en` got the same
sentence 100% correct. Accepted on purpose for live responsiveness; `C-c m` is
unaffected. See [DICTATE.md](DICTATE.md) for the full numbers.

**Four real bugs, all found by an actual real end-to-end test** (PulseAudio's own
`RDPSink`/`RDPSink.monitor` loopback in this environment plays a synthesized clip while
`parecord` genuinely records it back, so live dictation runs against real captured
audio, not a canned response):

1. Chunks landed in reverse order --- a plain `(point-marker)` (insertion-type `nil`)
   does not advance past text inserted at its own position. Fixed with
   `(set-marker-insertion-type my/dictate-live--target-marker t)`.
2. A file-missing race at stop time --- a manual stop landing right as a rotation tick
   fired could signal a just-spawned recording process before it ever created its WAV
   file. Fixed by treating a missing chunk file as silence instead of an error.
3. **The subtlest one**: the original readiness check polled the server with a real
   HTTP GET via `url-retrieve-synchronously`. *Measured, repeatedly*: any prior `url.el`
   GET to the server --- even one that completed and was cleaned up correctly --- left
   `url.el` in a state that silently broke the very next `url-retrieve-synchronously`
   POST (the real transcription request): empty body back, no error anywhere. Confirmed
   the server was never at fault with raw `curl` (identical GET-then-POST always worked
   there, each request its own process). Disabling `url-http-attempt-keepalives` on
   both requests did **not** fix it. Replacing the readiness check with a bare
   `open-network-stream` TCP probe --- never touching `url.el` at all --- did.
4. Even with that fixed, the very first real request right after a (re)start still came
   back empty, consistently: the listening socket accepts connections a real, short
   time before `whisper-server`'s request handling is actually ready to serve one. A
   plain 0.5s settle after the port starts answering fixed it reliably across many
   repeated runs.

Bugs 3 and 4 were caught by, and are now regression-tested by, a real, opt-in ERT test
(`dictate/live-transcribe-a-real-known-recording`) that POSTs a known pre-recorded WAV
to a real, freshly-started `whisper-server` and checks the actual transcribed text ---
not a mock. It took a genuinely long, methodical isolation process (comparing a single
fresh start against a kill-then-restart cycle, disabling keep-alives, bypassing `url.el`
entirely for the readiness check, then bisecting a settle delay from 0s up) to pin bug 4
down after bug 3's fix alone did not make the failure go away. 32 tests in
`tests/ert/dictate.el` (14 new), 0 fail; 615 tests, 595 pass, 0 fail, 20 skipped across
the full offline suite. **Windows: not yet built or tested** for the `whisper-server`
side --- only Linux/WSL is verified end to end so far.

#### Follow-up: whisper-server.exe cross-compiled for Windows, two more real bugs found by the user

User tried `C-c M` on the real Windows bundle. `whisper-server.exe` didn't exist yet
(only `whisper-cli.exe`, for `C-c m`, had been cross-compiled) --- built it the same way
(zig cross-compile, static, from the same `/tmp/whisper.cpp` checkout already
configured for Windows), copied it plus `ggml-base.en.bin` to
`~/.local/share/whisper-cpp/` on the user's machine directly (WSL's `/mnt/c/` maps to
the same Windows user account this session already had access to).

**A real bug, found immediately on first use**: `Error running timer
'my/dictate-live--rotate': (buffer-read-only #<buffer *Messages*>) [5 times]`. Cause:
the user pressed `C-c M` while sitting in `*Messages*` (read-only by default in Emacs,
likely left there after reading an earlier error) --- every rotation tick then tried to
`insert` into it and failed. Fixed defensively in `my/dictate-live--rotate` (treats a
read-only target buffer the same as a buffer that's gone, falling back to a `message`).
**A self-caused bug found while writing that fix**: the edit left one extra closing
paren, breaking `unwind-protect`'s own structure --- caught immediately by
byte-compiling before committing (`Invalid read syntax: ")"`), not by a test; fixed and
re-verified compiles clean, 32/32 tests still pass.

**A real, substantial finding about accuracy**: once working, the user reported
hallucinated phrases appearing that they never said ("Okay guys, let's...", "I'm sorry.",
"Holy shit."). Investigated for real, not guessed: isolated the exact failure to a
chunk's fixed-interval cut landing mid-word/mid-phrase --- Whisper doesn't transcribe
only what it heard in that case, it *confidently completes* the cut-off phrase with a
plausible but wrong ending. Confirmed this happens identically with both `base.en` and
`small.en` on the same isolated fragment (ruling out model size as the cause), and that
real VAD (downloaded `silero-v6.2.0`, tested directly) does **not** fix it either ---
VAD correctly handles pure silence/noise (already fine without it) but still hands a
genuinely cut-off fragment of real speech to the decoder, which still completes it. The
standard anti-hallucination knobs (`no_speech_thold`, `entropy_thold`, `logprob_thold`)
don't help either, since this is *high*-confidence nonsense, not low-confidence. The one
thing that measurably helps: `my/dictate-live-chunk-seconds` moved from 3s to 5s (user's
explicit choice, offered alongside a bigger VAD-based dynamic-chunking redesign and
"leave it as-is" as the alternatives) --- cuts less often, so the failure happens less
often, though any fixed interval can still land mid-phrase. See
[DICTATE.md](DICTATE.md)'s own "Hallucination" section for the full writeup.
`C-c m` (record, then transcribe once) is unaffected --- it never hits this failure
mode, since it only ever transcribes a complete utterance.

### LLM council: picking by size instead of by name/family (`C-c a c`)

User: "it needs to check the available models, if they are less than 3 it can ask the
same question to each, i dont want to use the large one 20b it slows down the pc, pick
anything for 3 models with 2gb or 3gb and for summary make it 7b if available, if only
one model available it will be doing all the tasks." A real rework of the picking
logic, not a config tweak: `my/llm-council-models`/`my/llm-council-summarizer-models`
(name wish-lists, family-diversity-driven) are gone, replaced by `my/llm-council--
available-models` (a new, separate live `/api/tags` query that keeps each model's disk
size and parameter count --- `my/llm-ollama-models' itself deliberately still discards
both, since its only other caller just needs names) and `my/llm-council--order-by`
(orders available models by closeness to a target: `my/llm-council-target-size-gb'
(2.5GB) for the council, `my/llm-council-target-summarizer-params-b' (7B) for the
summarizer --- two different units on purpose, since a 7B model on disk is usually
~4GB, not 2-3GB). `my/llm-council-summarizer-exclude` (`gpt-oss:20b`/`-32k`) rules the
large model out **outright**, not just deprioritizes it, matching the user's explicit
"don't use it" rather than "prefer something else."

The "only one model available" case is a real, deliberate exception to "the summarizer
must be distinct from the council": `my/llm-council--choose` only excludes COUNCIL from
the summarizer pick when more than one model total is available --- with exactly one,
that model fills both roles (its own single answer, and its own summarizer) instead of
the summarizer coming back empty just because the sole model "conflicts with itself."

All 5 real call-sites in `tests/ert/llm-council.el` that exercised the old name-based
picking were rewritten around a new shared 5-model test fixture
(`llm-council-test--models`: three sized right at the 2.5GB target, one sized right at
the 7B target but far from 2.5GB on disk, one deliberately huge and excluded) rather
than patched individually, plus 4 new direct tests for the new behavior (closest-to-
target picking, never-picks-excluded, degrades-with-fewer-than-3, single-model-does-
both-roles). `llm-council--with-ollama-backend` itself now mocks the new `my/llm-
council--available-models` (not the now-unused-here `my/llm-ollama-models`) --- this
was caught for real, not anticipated: the first test run after the rewrite showed the
mocked tests suddenly asserting against *actual* locally-pulled model names
(`phi3:mini`, `llama3.2:3b-16k`, ...) instead of the intended fake ones, because the
picking code now prefers the live query first and the test macro was still only mocking
the old, no-longer-called function. 25 tests in `tests/ert/llm-council.el` (6 new/
rewritten), 0 fail, 1 skipped (the real round trip, `--lsp`-gated); 619 tests, 599 pass,
0 fail, 20 skipped across the full offline suite.

### Follow-up: live dictation's read-only-buffer decline was never actually up front

A self-caused bug, found only because the user hit it for real, twice: the WHY comment
on `my/dictate-live--rotate`'s read-only fallback (added in the earlier follow-up entry
above) claimed "`my/dictate-live-start' already declines up front for the common case
(starting while read-only)" --- that claim was **false**; the up-front check was never
actually written, only the defensive fallback inside the timer. The real effect: live
dictation would start normally in a read-only buffer (e.g. `*Messages*`, which is where
the user landed again, likely left there after an earlier error message) and every
single chunk, forever, would fall back to a bare `message` instead of ever inserting
anything --- it *looked* like it was transcribing correctly (each message shows the
heard text), with no indication anything was wrong until the user asked why no buffer
was showing the text. Fixed for real this time: `my/dictate-live-start` now checks
`buffer-read-only` up front (alongside the existing `-ready-reason`/re-entrancy checks,
rewritten from nested `if`s to a `cond` to fit the third branch cleanly) and declines
with one clear message instead of ever starting. New regression test
`dictate/live-declines-up-front-in-a-read-only-buffer`; 33 tests in
`tests/ert/dictate.el` (1 new), 0 fail, confirmed stable across 3 repeated runs; 620
tests, 600 pass, 0 fail, 20 skipped across the full offline suite.

### Org mode restored: a real reversal of an earlier pruning decision

User: "is org mode available if not can you add it i think its important right for
emacs to have org mode may be some packages depend on it." Checked before assuming:
Org was already **fully present on Windows** (258 org-related files in the zip, since
Windows uses the official prebuilt GNU Emacs unmodified) --- the gap was Linux-only,
where `org/` was one of the directories `prune.list` explicitly removed (alongside
games, mail/news readers, chat, legacy IDE tooling) to keep the from-source Linux build
small. Removed `org/` from `prune.list`, rebuilt and re-pruned `./install` from
scratch (a fresh `make install` first --- pruning only deletes from `install/`, so a
previously-pruned tree can't just be re-pruned with a shorter list and get files back),
confirmed real: `(require 'org)`, `org-mode`, heading navigation, everything works.

The user's "maybe some packages depend on it" turned out to be concretely true in two
places, both confirmed directly, not assumed: (1) `prune.py`'s own dependency scan
already force-kept `org-macs`/`org-element-ast` even before this change, because the
newer built-in calendar parser hard-requires them; (2) `gptel-org.el` (Org-formatted
chat rendering, one file inside the already-installed `gptel` package) used to fail to
byte-compile since only that same small slice of Org was present --- confirmed it now
compiles and presumably works cleanly with the rest of Org back.

A real, separate bug this surfaced: `test-skip-unless-pruned` (the shared test helper
every pruning-related ERT test uses to detect "is this actually a pruned build?")
checked `(locate-library "org")` as its litmus test --- with `org` no longer ever
pruned, that check would have silently skipped every single pruning test, forever, on
a genuinely pruned build, since `org` would never be absent to detect. Fixed to check
`tetris` instead (still genuinely pruned). `tests/ert/pruning.el` itself also rewritten
throughout: `org`/`org-agenda` moved from "removed" to their own "present" test; the
stale-autoload and no-native-code-left regression tests switched from `org-mode`/
`org-agenda` examples to `tetris`/`erc` (still-pruned, so still real examples of the
same underlying behavior). `docs/PRUNING.md`, `docs/SEARCH-OPTIONS.md`,
`docs/TROUBLESHOOTING.md`, `docs/LLM.md` all updated with real, freshly re-measured
numbers (not copied from before): 264 of 1,678 files now pruned (was 410), 6.6 MB of
source (was 14.3 MB), install size 281 MB (was 258 MB pruned / 308 MB unpruned), 1,371
native `.eln` files (was 1,228 pruned / 1,627 unpruned); the `require`-all sweep
(`tools/requireall.el`, re-run directly rather than assumed) now fails exactly 35 of
513 bundled packages on the pruned build (was 36), the one fewer being `org` itself,
otherwise the identical set. `docs/PRUNING.md` also had one unrelated, already-stale
line fixed while in there: it still mentioned `newsticker`/`net/newst-*` as pruned,
which has not been true since the news-feed work earlier this session --- caught by
inspection while re-checking `prune.list`'s real current contents for this change, not
something this change itself caused.

8 tests in `tests/ert/pruning.el` (rewritten, not just patched), 0 fail, 0 skipped
(confirming the pruned-build detection itself works again); 621 tests, 601 pass, 0
fail, 20 skipped across the full offline suite. Dist bundles not yet rebuilt for this
(neither Linux nor Windows) --- both need a fresh `./build.sh dist <platform>` to
actually pick up the un-pruned `org/`, since Linux's dist step reads from `./install`
(now correctly repopulated) and Windows was never affected by pruning to begin with,
so its zip only needs rebuilding for the *other* uncommitted-as-of-last-Windows-build
changes (the read-only-buffer fix), not for this.

### gptel defaults to Ollama regardless of entry point; word-wrap at word boundaries

User hit a real "(HTTP/1.1 401 Unauthorized) invalid_request_error" from ChatGPT while
trying to use `gptel` --- `gptel` ships with ChatGPT (a real OpenAI endpoint) as its own
factory-default backend, and this config deliberately never puts an API key anywhere;
the local Ollama backend only ever got set up by `my/llm-chat' (`C-c a a'). Asked to
make Ollama the default outright.

**A real bug in the first attempt, caught by testing before committing to it**: put a
`with-eval-after-load 'gptel' hook inside `config/llm.el' calling `my/llm-setup-ollama'.
Verified with a real, fresh subprocess (the same pattern `llm/is-not-loaded-until-used'
already uses) doing a bare `(require 'gptel)' --- `gptel-backend' came back `nil', not
Ollama. Cause: `config/llm.el' is *itself* lazily autoloaded (only loaded the first time
`my/llm-chat'/`my/llm-council' runs), so a hook registered inside it never gets
registered at all if `gptel' is reached some other way first --- exactly the user's
real path: `C-c a m' autoloads `gptel-transient' directly (see `config/init.el'),
never touching `config/llm.el'. Fixed by moving the hook to `config/init.el' itself
(always loaded, still costs nothing until `gptel' actually loads, same as every other
`with-eval-after-load' in this codebase). Re-verified with the same real-subprocess
method through both real entry points (`gptel-transient' and a bare `require'); both
now correctly end with `gptel-ollama-p' true. Two new regression tests in
`tests/ert/llm.el' drive this through real, fresh subprocesses specifically because a
mocked test cannot reproduce "the hook lives in the wrong file."

Same turn, a second, unrelated question: "why does it break the word... can we make
sure only show when the word fit at the end" --- Emacs's own default (`word-wrap' nil)
wraps a long line at the exact character the window edge lands on, splitting a word in
half if it straddles that boundary, with the continuation arrow (marking any wrapped,
not-a-real-newline continuation) then sitting mid-word. `(setq-default word-wrap t)`
added to `config/init.el`'s UI section moves the wrap point back to the nearest word
boundary instead, so a whole word moves to the next line together; the arrow itself
doesn't go away (it marks every wrap, word-boundary or not), only where it lands
changes. Real, meaningful ERT coverage stops at "the variable is set correctly" ---
tried to verify the actual visual wrap point too (`vertical-motion` against a real
line), but `--batch` mode has no real window geometry to wrap against, confirmed
directly (`vertical-motion` did not move to a second line at all); the deeper visual
behavior is standard, well-documented Emacs behavior once the variable is right, not
something this project invented, so untested beyond that is an accepted, explained gap
rather than a silent one.

40 tests in `tests/ert/llm.el` (2 new), 0 fail, stable across 3 repeated runs; 21 tests
in `tests/ert/config.el` (1 new), 0 fail; 624 tests, 604 pass, 0 fail, 20 skipped
across the full offline suite.

### Follow-up: cloud backends (ChatGPT, Claude, Gemini) registered, none active

Same conversation, user: "there should be option for chatgpt and other models right for
api key... in case i want to use other cloud models." `config/llm.el` already had two
commented-out, ready-to-uncomment examples (Anthropic, OpenAI) at its bottom --- moved
them from "manually uncomment to use" to "always registered, so they show up in
`gptel-menu` without editing config," plus added Gemini as a third. Confirmed directly,
not assumed, that this is safe: `gptel-make-openai` (and the same shape for `-anthropic`/
`-gemini`) ends with `(setf (alist-get name gptel--known-backends ...) backend)`, never
touching the active `gptel-backend` itself --- so registering all three changes nothing
about Ollama staying the default from the fix just above; you would only end up talking
to one if you deliberately picked it from `C-c a m`.

**A real bug, caught immediately by the same real-subprocess testing method, not
assumed clean**: the first version hit `void-function (gptel-make-openai)`.
`gptel-make-openai`/`-anthropic`/`-gemini` each live in their own file
(`gptel-openai.el`/etc.), none loaded just because `gptel` itself is --- the exact same
reason `my/llm-setup-ollama` already `require`s `gptel-ollama` explicitly before calling
`gptel-make-ollama`; missed adding the equivalent `require`s for these three at first.
Fixed, re-verified through the same real, fresh-subprocess method as the Ollama-default
fix (through `gptel-transient`, i.e. `C-c a m` --- the exact path that broke the first
attempt at that fix too): `gptel--known-backends` correctly ends up
`(ChatGPT Claude Gemini Ollama)`, active backend still `Ollama`. One more real bug in
the new test itself, caught by running it rather than assumed correct: `princ` does not
quote strings the way `%S`/`prin1` would, so the first version of the regex (expecting
quoted names) never matched real output.

41 tests in `tests/ert/llm.el` (1 more new, 3 total this session), 0 fail, stable
across 3 repeated runs; 625 tests, 605 pass, 0 fail, 20 skipped across the full
offline suite.

### Windows zip rebuilt (Windows only, Linux deferred on request)

User asked for a zip; mid-build, clarified "lets do only windows, until i tell linux"
--- Windows rebuilt and verified (`test_dist.py`, 10/10), copied to Downloads (+7,312
bytes over the last Windows build). Linux's own dist is now two features further
behind than Windows's (still never rebuilt this session at all, missing the Org
restore on top of everything Windows already has) --- deliberately left alone per the
user's own instruction; do not rebuild it until asked.

### Two real, reported minibuffer noise problems, both traced to their real cause

User: "it keeps saving a message appears in the mini buffer of saving the file to
config recentf.eld ..also i see recents.eld..what you are saving, it better it doesnt
show the message in the minibuffer." Investigated both files raised, not just the one
named in the complaint:

- `config/recentf.eld` is `recentf`'s own save file (`C-c r`'s recent-files list); the
  30s idle autosave timer that writes it (added earlier this session, for crash-safety)
  was printing "Wrote .../recentf.eld" every single time. Traced to the real cause in
  `recentf.el`'s own source, not assumed: `recentf-save-list`'s `write-region` call is
  quiet only `(unless (or (called-interactively-p 'interactive) recentf-show-messages)
  'quiet)` --- `recentf-show-messages` defaults to `t` in stock Emacs, so it always
  showed the message regardless of the timer being non-interactive. Fixed with a single
  `(setq recentf-show-messages nil)`; confirmed directly (not assumed) with a real,
  mocked-`message` call to `recentf-save-list` showing zero messages afterward.
- `config/recents.eld` (a **different**, this-project-specific file --- `startpage.el`'s
  own recent folders/projects list, unrelated to built-in `recentf` despite the similar
  name, saved by its own separate 30s idle timer, `my/start-save`) turned out to
  **already** save silently, confirmed directly in `fileio.c`'s own `write-region`
  documentation rather than assumed clean just because the user didn't specifically
  complain about it: `with-temp-file` (what `my/start-save` uses) passes `write-region`
  a numeric `VISIT` (`0`), and the docs are explicit that a VISIT that is "neither t nor
  nil nor a string" suppresses the message --- nothing needed changing there.

New regression test `config/recentf-autosave-does-not-message` (mocks `message`, asserts
zero calls across a real `recentf-save-list` invocation, not just that the variable is
set). 22 tests in `tests/ert/config.el` (1 new), 0 fail, stable across 3 repeated runs;
626 tests, 606 pass, 0 fail, 20 skipped across the full offline suite.

### Whole-disk search stops blocking: debounce for C-c f f/g, a fully async C-c f a

User asked why typing into the whole-disk finder (`C-c f g`/`C-c f f` outside a
project) felt laggy per letter --- confirmed for real, not assumed, that this is a
genuine, already-documented cost (the file header's own measured "7 to 97ms per
keystroke over ~975,000 paths", and the user's own real index came back at 988,397
files) --- a fresh, real search runs synchronously on every keystroke, not just once.
Then asked specifically for it to be asynchronous instead. Offered two different
scopes (debounce only vs. a full async rewrite); user: "can we write both for
different commands."

**Debounce for the existing `C-c f f`/`C-c f g`**: `my/ff--table`'s completion-table
closure now waits `my/ff-debounce-seconds` (150ms) via `sit-for` before actually
searching, once per distinct query string. `sit-for` --- not a timer --- is the whole
trick: it returns immediately, without waiting, the moment more input is already
pending, which is exactly what every keystroke except the last one in a fast burst is;
Emacs's own completion machinery already re-invokes the table after every keystroke as
part of its normal redisplay cycle, so the one call that is NOT interrupted (the one
after which nothing further is typed) is naturally the one that runs the real search
--- no new minibuffer-refresh machinery needed, unlike a timer-based approach would need.

**A real, found-the-hard-way testing limitation, not a shortcut**: the first version of
this feature's tests tried to simulate "more input is already pending" via
`unread-command-events`, the same technique `tests/gui/gui-tests.el` already uses for
real keystroke-driven tests. Confirmed directly, not assumed: `--batch` mode (how this
whole suite runs) does **not** honor `sit-for`'s pending-input interruption the way a
real command loop does --- `input-pending-p` correctly reports `t` after queuing fake
input, but `sit-for` still waited out the full delay regardless, every time, in
`--batch` specifically. Rescoped the tests to what is actually this project's
responsibility to prove: that `my/ff--table` responds correctly to each of `sit-for`'s
two documented possible return values (mocking `sit-for` itself, not trying to
re-trigger its own interruption mechanics) --- `sit-for` being interruptible by pending
input in real interactive use is `sit-for`'s own long-established, widely-relied-upon
behavior (the same primitive `company-mode`/`corfu` build their own debouncing on), not
something this suite needs to re-prove.

**A fully asynchronous alternative, `C-c f a`**: rather than hand-rolling an async
subprocess pipeline (filters, sentinels, a minibuffer-refresh trigger) from scratch,
`my/ff-find-file-global-async` reuses `consult-fd` (already installed, already used by
`C-c s f` for project-scoped search) --- confirmed directly in Consult's own
documentation, not assumed, that its `dir` argument accepts a **list** of search paths,
so `my/ff-global-roots` (the exact same roots `C-c f g` searches) can be passed
straight through with no new plumbing. Verified fully end to end, not just unit-tested:
built the exact `fd` command line Consult's own internals produce for a real query
against a real directory, ran it for real, got real correct file results back. The
real, disclosed tradeoff: `fd`'s own literal/regex name matching, not the fuzzy
"letters in any order" scoring `C-c f g`/`C-c f f` use --- a genuinely different tool,
not a drop-in replacement, in exchange for genuinely never blocking, not even for a
debounce pause.

42 tests in `tests/ert/fastfind.el` (5 new, 1 extended), 0 fail, stable across 3
repeated runs; 631 tests, 611 pass, 0 fail, 20 skipped across the full offline suite.

### A real bug found by asking "what else can we do now": Org mode crashed session.el

User asked what else was worth doing, given everything learned this session. While
checking whether Org's own conventional keybindings (`C-c a`/`C-c c`/`C-c l`) would
conflict with anything, found something worse first: `M-x org-mode`, run through the
real, fully-loaded config (not `(require 'org)` in isolation, which is all the earlier
Org-restoration work had actually tested), crashed with "Symbol's value as variable is
void: session-globals-exclude" --- reproduced first, then traced to the real cause, not
guessed: `config/session.el` (this project's own crash-safe-session feature, unrelated
to Org, written back when Org was still pruned) `(provide 'session)`d --- the exact
same feature name as a real, well-known third-party ELPA package Org's own
`org-compat.el` has a compatibility hook for (`(eval-after-load 'session ...)`,
expecting that package's own `session-globals-exclude` variable). A bare `(require
'org)` outside this config never hit it, since nothing had registered the `session`
feature name yet in that isolated context --- confirmed directly why the earlier
restoration work's own verification missed this: it never tested Org together with the
rest of the actual, already-loaded config, only in isolation.

Fixed by renaming the file and the feature to `emacs-session`, matching this project's
own "feature name = filename" convention throughout (not a special-cased workaround),
rather than touching Org's own hook, which is entirely legitimate for anyone who
actually has the real `session` package installed. This touched far more than the one
file: the 26 tests in `tests/ert/session.el` (renamed `tests/ert/emacs-session.el`,
every `session/...` test name updated to `emacs-session/...` to match), `config/init.el`'s
own `require`, and six more places across the build/test tooling that referenced the
old filename by name (`build.sh`, `tools/dist-windows.sh`, `tools/dist-linux.sh`,
`tools/test-windows.sh`, `tools/doctor.sh`, `tests/run-all.sh`, `tests/test_dist.py`,
`tests/test_repo.py`, `tests/test_tui.py`, `.gitignore`) --- found via a real, repo-wide
grep, not assumed to be "just the one file," and re-checked afterward with a second
grep pass that turned up more (`.gitignore`, `tools/test-windows.sh`,
`tests/test_tui.py`) the first pass's narrower pattern had missed.

New regression test `emacs-session/does-not-collide-with-orgs-own-session-package-hook`
runs `M-x org-mode` through the real, fully-loaded config specifically so this exact
failure mode --- verified in isolation, broken in the real integrated system --- cannot
silently come back. 26 tests in `tests/ert/emacs-session.el` (1 new), 0 fail, stable
across 3 repeated runs; 632 tests, 612 pass, 0 fail, 20 skipped across the full offline
suite. The Linux and Windows dist zips now also show the (expected, already-anticipated)
"file renamed" version of the usual stale-bundle signal for this one file specifically,
on top of everything already accumulated --- resolves the same way, on the next rebuild
of each.

### M-x calendar shows 12 months instead of 3

User: "i dont seem to get 12 months in emacs calendar, only see three months how to
change it." Not a bug --- `calendar`'s own docstring says "Display a **three**-month
Gregorian calendar" outright --- but a real, genuine, documented variable controls it:
`calendar-total-months` (a plain `defvar`, not a `defcustom`, so it never shows up in
`M-x customize` --- found by reading `calendar.el`'s own source, not guessed). Verified
directly before adding it, not assumed from the docstring alone: opened a real calendar
buffer and counted real month headers in it, 3 by default, 12 with the variable set,
both confirmed for real. Set in `config/init.el` before `calendar.el` itself has even
loaded (safe and idiomatic: `defvar` only sets a value if unbound, so this wins once
calendar.el's own later `defvar` runs).

New test `config/calendar-shows-12-months` opens a real calendar buffer through a real,
fresh subprocess and counts real month headers, rather than only checking the variable
holds 12 --- deliberately, since `calendar-total-months` is made buffer-local by
`calendar-mode` itself, so a correctly-set variable could still, in principle, fail to
affect a newly opened buffer if scoped wrong; this rules that out for real. 23 tests in
`tests/ert/config.el` (1 new), 0 fail, stable across 3 repeated runs; 633 tests, 613
pass, 0 fail, 20 skipped across the full offline suite.

### Follow-up, same day: the 12-month calendar was reverted --- it looked jumbled for real

Shipped in the Windows zip, then user: "did you test it, its all jumbled when i do the
calendar." A real testing gap, not a random report: the earlier test confirmed the
buffer's *text* held 12 month names, but never checked what that actually renders as.
Measured directly once asked: `calendar.el` lays every month out in a single row, not a
multi-row grid --- 12 months is one real line 300 columns wide (`calendar-month-width`
is 25 here), which wraps and scrambles on any normal window. Reverted to the stock
default (3, a real 76-column line, measured) --- Emacs's calendar genuinely has no
built-in year-grid view to switch to instead; `M-x calendar`'s own `<`/`>` scroll the
same three-month window forward/backward through the year one month at a time. This is
the same mistake *category* as the word-wrap fix and the Org/`session.el` bug earlier
this session: verified in isolation (the text), not through the real, visible result
(what it looks like) --- three real findings this session now share that exact shape.

`config/calendar-shows-12-months` (the test written for the reverted change) rewritten
to `config/calendar-stays-at-the-default-3-months`, now checking the real rendered line
width too (76 columns), not just the month count --- specifically so a future change
back toward "show more months" has to notice the width problem before shipping, not
after. 23 tests in `tests/ert/config.el` (0 net new, 1 rewritten), 0 fail, stable
across 3 repeated runs; 633 tests, 613 pass, 0 fail, 20 skipped across the full offline
suite.

### A real year-at-a-glance calendar, built by hand: `C-c y` (`my/calendar-year`)

User, after the 12-month revert: "so we cant fix?" Checked properly before answering
either way: a real web search turned up no existing package that lays out a whole
year as a grid (`calfw` exists, but is a month/week/day event-calendar, not a year
grid) --- confirmed, not assumed, before concluding this needed building by hand.
Asked the user to choose between building it properly or leaving the default 3-month
view; they chose to build it.

New file `config/calendar-year.el` (matching this project's own "substantial feature
gets its own file" convention, not crammed into `init.el`): `M-x calendar` (`calendar-
generate`) lays every month out in one row by calling `calendar-generate-month' once
per month at increasing column indents --- the exact same primitive, just called once
per *row* of 3 months instead of once for 12 in a row nothing can wrap sanely, each
row built in its own scratch buffer and the results assembled into a plain, separate,
read-only `*Year Calendar*` buffer (`special-mode`, `q` to close) that never touches
the real `*Calendar*` buffer, `calendar-total-months`, or the diary. Bound to `C-c y`
(`C-u C-c y` prompts for a year).

Verified for real, learning directly from the exact mistake earlier this session:
every claim about the real buffer (12 months present, a real month-row's actual
rendered width, read-only, `q` bound, default year, reusing the same buffer on a
second call) checked through a real, fresh subprocess with the full config loaded, not
assumed from the underlying primitive working in isolation. Real measured numbers: 33
total lines, a real month-row 71 columns wide (narrower than the already-proven-safe
76-column default 3-month view, nowhere near the reverted attempt's 300).

Needed touching far more than the one new file, a lesson from the `emacs-session.el`
rename earlier this session applied immediately rather than re-discovered the hard
way: a new hand-written config file has to be added to every hardcoded file list this
project's build/test tooling keeps (`build.sh`, `tools/dist-windows.sh`, `tools/dist-
linux.sh`, `tools/test-windows.sh`, `tools/doctor.sh`, `tests/run-all.sh`,
`tests/test_dist.py`, `tests/test_repo.py`, `tests/test_tui.py`, `.gitignore`) --- found
this out for real again anyway, the first test run crashing with a real "Cannot open
load file" until every one of those was updated.

Two real, self-caused test bugs, both found and fixed by actually running the tests,
not assumed correct on writing: one test wrongly expected January 1st, 2027 to sit
alone on its own calendar row (it is a Friday, so it shares that row with the 2nd); a
second wrongly anchored a regex to both ends of a string that had real startup log
lines ahead of the value being checked, the same anchoring mistake made and fixed
earlier this session for the gptel-defaults-to-Ollama tests.

10 tests in `tests/ert/calendar-year.el` (new file), 0 fail, stable across 3 repeated
runs; 643 tests, 623 pass, 0 fail, 20 skipped across the full offline suite.

## Where things stand as of the last entry

- Live dictation (`C-c M`) is committed but the dist bundles are **not yet rebuilt** ---
  per the standing workflow-pacing instruction above, a single feature gets its own
  tests run and committed, not an automatic dist rebuild; both bundles are one feature
  past their last rebuild as of this entry. `whisper-server.exe` is now built and
  confirmed working on the user's real Windows machine (see the follow-up section
  above), placed directly at `~/.local/share/whisper-cpp/` the same way `whisper-cli.exe`
  already was --- **not** added to the dist zip itself, matching this project's existing
  "heavy runtime dependency, never bundled" convention for whisper.cpp. The Windows zip
  in Downloads right now predates this follow-up entirely (rebuilt once already this
  session, before `C-c M` was even tried) and does not need rebuilding just for this ---
  nothing about `whisper-server.exe` lives inside the zip.
- All other features above are committed and pushed to `origin/main`, including the
  Windows dist rebuild (verified clean, `test_dist.py` all green) and the new, finished
  Linux bundle (also verified, see its own section above) from before live dictation.
- A commenting pass (WHAT/WHY/HOW style) is in progress across the config files touched
  this session; see "Commenting pass" above for exactly what's done and what isn't yet
  (`config/llm.el` and the Magit/Treemacs/Consult/Evil wiring beyond what's listed there
  are the known remaining gaps).
- One loose end from earlier in this session: a full `./build.sh test --full` run
  showed 1 ERT failure (565/566) that was never pinned down --- two attempts to re-run
  and identify it got killed by the harness for low system memory (not a real test
  failure; see the harness's own note about this). It may be the pre-existing,
  documented timing-sensitive real-`jdtls` flake under full parallel load (see BUILD.md),
  but this was **never confirmed**. If asked to investigate, run `./build.sh test --full`
  again (memory permitting) and look for which specific test failed.
- The Linux bundle is explicitly **not yet tried on a genuinely bare machine** and has
  **no bundled Java language server** --- both documented as real, current limits in
  [DISTRIBUTION.md](DISTRIBUTION.md), not hidden.
