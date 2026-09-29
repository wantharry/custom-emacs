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

## Where things stand as of the last entry

- All features above are committed and pushed to `origin/main`.
- A commenting pass (WHAT/WHY/HOW style) is in progress across the config files touched
  this session; see "Commenting pass" above for exactly what's done and what isn't yet.
- Per the standing workflow instruction, a full `./build.sh test --full` + Windows dist
  rebuild is due (more than 3-4 features have now accumulated since the last one) but may
  not have completed yet at the time this entry was written --- check `git log` and the
  Windows zip's own timestamp/commit to see whether it's since been done.
