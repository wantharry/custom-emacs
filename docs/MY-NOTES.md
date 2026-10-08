# My notes

A personal, running log of real commands and gotchas, kept short for quick reference and
printing --- not the polished general guides ([KEYBOARD.md](KEYBOARD.md) etc.), just
commands and one-line notes, added to as they come up.

## Opening Emacs

| Command | What it opens |
|---|---|
| `install/bin/emacs --init-directory=$PWD/config` | this repo, Linux/WSL, the normal pruned install |
| `build/src/emacs --init-directory=$PWD/config` | this repo, straight from the build tree, unpruned |
| double-click `Emacs.exe` inside the unzipped folder | the portable Windows bundle |
| `./Emacs` inside the unzipped folder | the portable Linux bundle |

`--init-directory=` is what makes it *this* config; without it, Emacs falls back to its own stock default.

## Current location, always shown at the top

| Topic | Note |
|---|---|
| What | every buffer's own header line (top of the window, not the mode line at the bottom) shows the full path of the file being edited, or the directory for one that isn't (Dired, `*scratch*`, ...) --- `~`-abbreviated the same way the minibuffer already shortens the home directory |
| Why there, not the mode line | the mode line (bottom) already shows the bare buffer NAME; this adds the one thing it doesn't, without duplicating it |
| `ranger` | untouched --- it already sets its own, more detailed header (`user@host : /path`), confirmed directly in its source; `setq-default` only ever applies to a buffer that hasn't set its own |

## Custom menu

| Topic | Note |
|---|---|
| Where | a real "Custom" entry in the menu bar itself, one submenu per topic (Finding files, Searching, Git (Magit), Project tree, Recent work, LLM chat, Themes, Help, ...) --- every command this config adds, clickable, not just a keyboard reference |
| Opening it without a mouse | `F10` (`menu-bar-open`, the real dropdown) or `M-\`` (`tmm-menubar`, a text-mode version that works in a plain terminal/`-nw` session too --- type the highlighted letter to drill down, same letters shown in `c==>Custom` style) |
| How it's built | generated directly from `my/shortcuts-list` (`config/shortcuts.el`), the exact same data `C-c k` and its tests already keep accurate --- not a second, separately hand-written copy, specifically to avoid repeating the reference panel's own real `F`-is-undefined mistake from earlier this session |
| Keybindings shown in the menu | real, live, straight from the actual keymap (e.g. "Git status... `C-x g`") --- never typed in by hand, so they can't go stale either |

## Exiting Emacs

| Command | What it does |
|---|---|
| `C-x C-c` | quit Emacs entirely (asks to save any unsaved files first) |
| `q` (in Magit/Treemacs/Dired/ibuffer/start screen/docs/shortcuts buffers) | closes just that buffer/window, not Emacs |
| `C-x 5 0` | close just the current frame (OS window) |

## Opening/closing the browsing buffers

| Open | Close | What |
|---|---|---|
| `C-x d` / `C-x C-j` | `q` | Dired |
| `C-c t` / `C-c T` | `q` (hide) / `Q` (reset) | Treemacs |
| `C-c h` | `q` | Start screen --- recent files/folders/projects |
| `C-c f p` | `q` | Git repos list |
| `C-x g` (also `C-c g`) | `q` (`C-u q` kills it) | Magit status |
| `C-c a a` | `C-x k` | LLM chat (gptel) |
| `C-c a c` | `q` | LLM council |
| `C-c n` | `q` | News (newsticker) |
| `C-c d` (`C-c D` rebuilds) | `q` | Docs buffer |
| `C-c k` | `q` | Shortcuts buffer |
| `C-c w l` | `q` | Session list |
| `C-c w L` | `q` | Named sessions list |
| `C-c y` | `q` | Year calendar |
| `C-c m` | `C-c m` again | Dictation |
| `C-c M` | `C-c M` again | Live dictation |
| `C-c v` | `C-c v` again | Evil, vi keys |

## Ways to open a file, by scope (find files)

| Scope | Command | Method | Source |
|---|---|---|---|
| Folder | `C-x C-f` | built-in completion, current directory | Built-in |
| Folder | `C-x d`/`C-x C-j` then `RET` | Dired browse | Built-in |
| Folder | `C-c t` then `RET` | Treemacs browse | Package (Treemacs) |
| Folder | `C-c f d` | fuzzy, live only, current dir subtree | **Custom** |
| Project | `C-c f f` | fuzzy, cached index + live fallback | **Custom** |
| Project | `C-x p f` | built-in completion, not fuzzy; follows current buffer's project, same as `C-c f f` | Built-in |
| Project | `C-x p d` | Dired on project root | Built-in |
| Project | `C-c s f` (`consult-fd`) | literal/regexp, `fd`, no live preview | Package (Consult) |
| Disk | `C-c f g` | fuzzy, cached whole-disk index + live fallback | **Custom** |
| Disk | `C-c f a` | same, async (Consult/fd), never blocks | **Custom** (wraps `consult-fd`) |
| History | `C-c h` then `RET`/number | recent list, no query typed | **Custom** |

`gmtry` finds `Geometry.java` via the fuzzy commands (`f f`/`f g`/`f d`), not via `C-x p f`/`C-c s f`.

## Searching text, by scope (Consult + built-ins compared)

| Scope | Command | Match type | Live preview | Source |
|---|---|---|---|---|
| This buffer | `C-s`/`C-r` | simple (`M-r`→regexp) | yes | Built-in |
| This buffer | `C-M-s`/`C-M-r` | regexp | yes | Built-in |
| This buffer | `C-c s l` (`consult-line`) | completion-style | yes | Package (Consult) |
| This buffer | `M-s o` (`occur`) | regexp | no | Built-in |
| This buffer | `M-%`/`C-M-%` | simple/regexp | no (steps, asks y/n) | Built-in |
| Directory (ask) | `C-u C-c s g` | ripgrep literal/regexp | yes | Package (Consult) |
| Directory (ask) | `C-u C-x p g` | regexp | no | Built-in |
| Project | `C-c s g` (`consult-ripgrep`) | ripgrep literal/regexp | yes | Package (Consult) |
| Project | `C-x p g` | regexp | no | Built-in |
| Multiple buffers | `M-x consult-line-multi` | completion-style | yes | Package (Consult) |
| Multiple buffers | `M-x multi-occur` | regexp | no | Built-in |

- No dedicated key for directory-scoped text search --- `C-u` in front of the project-search commands prompts for a directory instead.

## LLM

| Command | Note |
|---|---|
| `C-c a a` | Ollama auto-setup via its `/api/tags` HTTP endpoint directly, no `ollama` CLI needed |
| `C-c a m` | switch model/backend/prompt; ChatGPT/Claude/Gemini pre-registered but inactive until a key is in `~/.authinfo.gpg` |
| `C-c a c` | 3 small local models in parallel + 1 separate bigger summarizer, never the largest model pulled |

## Dictation

| Command | Note |
|---|---|
| `C-c m` / `C-c M` | fully local (whisper.cpp), no cloud, no API key |
| Linux stop | `SIGTERM` + wait --- `delete-process` alone corrupts the WAV header |
| Windows stop | sends `"q"` on stdin --- no `SIGTERM` equivalent on Windows |

## Session

| Topic | Note |
|---|---|
| `emacs-session.el` name | avoids a real collision with a third-party `session` package Org expects |
| `auto-save-visited-mode` | saves an unlocked (`C-c e e`), edited buffer back to disk a few seconds after you stop typing |
| What actually gets saved | window placement, buffers, files and frame chrome (menu bar/tool bar/decorations) all persist on their own, via `desktop-save-mode`'s own "frameset" mechanism --- confirmed directly by inspecting a real saved file, not assumed from the name "session" |
| The color theme | did NOT persist on its own (`theme-buffet` always re-picked a fresh random one at every startup regardless) --- fixed with `my/session-theme`, saved/restored via `desktop-globals-to-save` + `desktop-save-hook`/`desktop-after-read-hook`, timed to run after `theme-buffet`'s own startup pick so it correctly wins |
| `C-c w r` (`my/session-reset`) | only deletes the *saved* file --- it does **not** touch your currently running Emacs's frame/theme at all. If menu-bar/theme/etc. are wrong in the live session when you run this, they'll just get auto-saved wrong again on the very next exit. Fix the live state first (or use `C-c U`, which does both at once), then reset/save |

## Which-key

| Topic | Note |
|---|---|
| `*` in Dired | a real prefix key (the mark submenu) --- good way to see the popup: open Dired, press `*`, wait a second |
| Popup side | stock bottom, everywhere, no exceptions --- tried moving it to the right (globally, then scoped to just Dired/Org) across two earlier attempts this session, reverted both times; the right side in Dired/Org is now used by `C-o`'s Casual menu and the always-visible reference panel instead (below) |

## Dired and Org: Casual (`C-o`) and the always-visible reference panel

Two deliberately different things --- worth keeping straight:

| Topic | Note |
|---|---|
| `C-o` (Casual) | a real, Magit-style **transient** popup --- modal, takes over the keyboard, closes the instant you pick one action. `casual-dired-tmenu` in Dired (grouped File/Directory/Bulk/Navigation/Quick/Search/New), `casual-org-tmenu` in Org (grouped Headline/Date/Priority/Link/Timestamp/Mark/etc., context-aware --- shows the actual heading text at point). Dired/Org only --- `ranger`/Treemacs have no Casual integration |
| The reference panel | the opposite --- a plain, read-only, **non-modal** sidebar (`my/mode-reference-mode`, `config/mode-reference.el`), always visible the moment you're in a real Dired, Org, `ranger', or Treemacs buffer, never grabs focus, never closes on its own mid-task. A real bug, found by actually using it (`F` for "new file" said "F is undefined"): the first version of this content was transcribed from Casual's own `C-o` menu *labels*, which mostly only mean anything while that menu has focus, not as real standalone keys --- turned up to be systematic, not a one-off, across both original panels. Rebuilt with every single entry re-verified directly against the real `dired-mode-map`/`org-mode-map` instead, with `tests/ert/mode-reference.el` now parsing and checking every key automatically so this can't silently come back |
| Extended to `ranger`/Treemacs | user request, after the panel had already proven itself for Dired/Org --- `ranger''s own entries went through the same discipline (every key individually `lookup-key'-checked, not guessed), and Treemacs's text reuses the already-verified table from `docs/TREEMACS.md' directly (including this config's own `D'/`z'/`G' cross-navigation commands). `ranger-mode' is checked BEFORE `dired-mode' in `my/mode-reference--relevant-mode' --- confirmed directly, `ranger-mode' IS `dired-mode' underneath, so checking order matters or it would show Dired's text in a `ranger' session |
| `ranger`'s own window-slot conflict, found again | `ranger''s own preview pane (confirmed directly in its source) uses the exact same `(side . right) (slot . 1)' the panel already used --- the identical failure mode Casual's menu hit against the panel earlier (see below), just a second real instance of it. Fixed with `my/mode-reference--slot-for': `ranger' gets slot 2, a genuinely different one, so all 4 panes (parent, listing, preview, reference) now coexist; switching INTO or OUT OF `ranger' deletes and recreates the panel's window in the right slot, since a side window's slot can't be changed after it's created |
| `ranger`'s own panel is narrower | its own three panes already fill the frame (see "A ranger-style file manager" above) --- the panel uses 0.16 width there instead of the usual 0.28, confirmed visually to still read comfortably in a real terminal session |
| Package (Casual) | `casual` (github.com/kickingvegas/casual), verified directly against MELPA, not assumed --- a big umbrella package (109 files), covers other built-in modes too (re-builder, timezone, etc.), only the Dired and Org parts are wired up here |
| The Dired `C-o` collision | was already `dired-display-file` (show in another window, don't switch) --- kept Casual on `C-o` anyway, matching its own documented cross-mode convention; `o`/`v` already cover similar ground, `M-x dired-display-file` still works directly. Org had no existing `C-o` binding of its own, confirmed directly, so no collision there |
| First use is slower | loading (and likely natively compiling, like any installed package's first real use) `casual-dired`/`casual-org` the first time `C-o` is pressed in a session takes a few real seconds, confirmed directly (not instant) --- every use after that in the same session is fast |
| The real window-slot conflict | both the panel and Casual's menu wanted the exact same right-side window --- found by testing: the second one to try displaying silently failed to show at all, while its modal keymap still captured every keystroke (very confusing until tracked down). Fixed by giving them distinct `slot` values on the same `(side . right)` edge (panel: slot 1, Casual: slot 0) --- they now genuinely coexist, stacked, Casual's menu appearing above the panel when `C-o` is pressed while it's already showing |
| Auto show/hide | `dired-mode-hook`/`org-mode-hook` (covers the very first buffer at startup) plus `window-selection-change-functions`/`window-buffer-change-functions` (covers every later switch) --- a real gap found by testing: the window-change hooks alone never fire for the first buffer shown at startup, since there is no prior session state to have "changed" from |
| Scrolled away from its own top | a real, user-reported bug: `C-c U` (menu-bar/tool-bar toggled, a real frame-geometry change in a GUI) could leave the panel scrolled a little way down, cutting the first few lines off --- `window-start` was only ever set once, when the window was first created, never re-asserted after a resize. Fixed with `window-size-change-functions` (catches any resize generally) and `my/reset-to-defaults` explicitly re-anchoring it too (catches this specific trigger directly) |

## Org mode

| Topic | Note |
|---|---|
| `.org` auto-activation | back on (was disabled for one session, then re-enabled on request) --- `.org` files open in real `org-mode` again |
| Its ~103 `C-c` bindings | confirmed mode-local, not global: a plain buffer sees 25 `C-c` bindings (this config's own), a real org buffer sees 109 --- they never show up in any other file type |

## Year calendar

| Command | Note |
|---|---|
| `C-c y` | real 12-month grid (4 rows x 3) --- stock `M-x calendar` only ever lays out one wide row |
| `*Year Calendar*` buffer | separate from the real `*Calendar*`, doesn't touch `calendar-total-months` |

## News

| Topic | Note |
|---|---|
| `C-c n` | built into Emacs (`net/newsticker.el`), no package |
| Fetching | `url-retrieve`, no external `wget`/`curl` --- works on the Windows bundle too |
| Feeds | 10 curl-verified live feeds, one per category |
| Loading | nothing fetches until `C-c n` is actually pressed |

## Themes

| Command | Note |
|---|---|
| `C-c c` *char* | pick a color theme by character --- `1`-`9`, then `a`-`z`, then `A`-`T` (55 themes total), `0` for the default (Emacs's own plain look) --- never stacks (previous theme disabled first) |
| `C-c .` / `C-c ,` | switch to the next/previous theme in the list, whatever character it's bound to --- for when the specific slot doesn't matter, wraps around at either end |
| `C-c C` | `consult-theme` --- fuzzy-search any installed theme *by name* with a live preview, including every `doom-themes` variant (see below), instead of memorizing a character |
| `M`-`T` | Modus Themes, light then dark: operandi / tinted / deuteranopia / tritanopia / vivendi / tinted / deuteranopia / tritanopia |
| (automatic) | `theme-buffet` still only rotates the 8 Modus Themes light/dark by time of day, re-checked hourly --- `C-c c`/`C-c .`/`C-c C` always override it; none of the other 47 themes were added to its rotation |

The full `C-c c` character -> theme mapping, grouped by package (also in `my/themes` in
`config/init.el`, the single source of truth --- this table is just a friendlier view
of the same thing):

| Key | Theme | | Key | Theme |
|---|---|---|---|---|
| `1` | atom-one-dark | | `2` | catppuccin (mocha) |
| `3` | solo-jazz | | `4` | nimbus |
| `5` | rebecca | | `6` | subatomic |
| `7` | night-owl | | `8` | seti |
| `b` | snazzy | | `c` | horizon |
| `h` | zenburn | | `u` | dracula |

**shanty-themes:** `9` dark, `a` light
**xcode-theme:** `d` dark, `e` light
**immaterial-theme:** `f` dark, `g` light
**ember-theme** (manual-only, needs `doom-themes`): `K` light, `L` soft

**solarized-theme** (12): `i` dark, `j` light, `k` dark-high-contrast, `l`
light-high-contrast, `m` gruvbox-dark, `n` gruvbox-light, `o` selenized-black, `p`
selenized-dark, `q` selenized-light, `r` selenized-white, `s` wombat-dark, `t` zenburn

**kaolin-themes** (15): `v` dark, `w` light, `x` aurora, `y` blossom, `z` breeze, `A`
bubblegum, `B` eclipse, `C` galaxy, `D` mono-dark, `E` mono-light, `F` ocean, `G` shiva,
`H` temple, `I` valley-dark, `J` valley-light

**Modus Themes** (8, built-in): `M` operandi, `N` operandi-tinted, `O`
operandi-deuteranopia, `P` operandi-tritanopia, `Q` vivendi, `R` vivendi-tinted, `S`
vivendi-deuteranopia, `T` vivendi-tritanopia

Plus `0` for the default (no theme). `doom-themes`'s own 50+ variants aren't on this
list at all --- reach those through `C-c C`'s fuzzy search by name instead.

All 8 [Modus Themes](https://github.com/protesilaos/modus-themes) ship built into Emacs 28+ already --- no package, confirmed directly (`etc/themes/modus-*-theme.el`). The other 47 come from 15 separately installed packages (`atom-one-dark-theme`, `catppuccin-theme`, `solo-jazz-theme`, `nimbus-theme`, `rebecca-theme`, `subatomic-theme`, `night-owl-theme`, `seti-theme`, `shanty-themes`, `snazzy-theme`, `horizon-theme`, `xcode-theme`, `immaterial-theme`, `zenburn-theme`, `solarized-theme`, `dracula-theme`, `kaolin-themes`, `ember-theme` --- full URLs in the WHAT/WHY comment above `my/themes` in `config/init.el`). A real, easy-to-get-backwards gotcha found while wiring these up: `load-theme` never consults `load-path` at all --- it always does its own file search through `custom-theme-load-path`, whose `t` entry expands to Emacs's *built-in* `etc/themes` directory, not to `load-path`; a theme package can `require` fine while still being completely invisible to `load-theme`/`consult-theme` unless its directory is *also* pushed onto `custom-theme-load-path` (now done in the same loop that adds `config/elpa`'s subdirectories to `load-path`). `my/themes` in `config/init.el` is the character→theme mapping; add more there (any installed theme) to extend `C-c c` without a new keybinding. `ember-theme` needs `doom-themes` as a hard dependency --- installed, but deliberately never `require`d automatically (this project's own `startup/no-third-party-features-loaded' test forbids it), so `doom-themes`'s own 50+ variants are reachable only via `C-c C`'s fuzzy search, never a `my/themes` slot. `theme-buffet` is a real GNU ELPA package (not one of Protesilaos's own, despite appearing in his dotfiles) --- `my/themes-light`/`my/themes-dark` is where it's told which of `my/themes`'s entries count as which; keep both lists in step when adding a theme that should also take part in the automatic rotation.

**The fixed cursor color, across 4 of the 55 themes** (real screenshots of this build,
same file and same line in every shot, so the only thing that changes is the theme):
`enable-theme-functions` keeps the cursor a fixed `DarkOrange` no matter which theme is
active, since several themes don't give it enough contrast against their own `hl-line`
color on their own.

*`solo-jazz` (light) --- the theme the regression test itself uses, since this was visibly wrong here before the fix:*

![solo-jazz with the fixed cursor](images/theme-1-solo-jazz.png)

*`dracula` (dark):*

![dracula with the fixed cursor](images/theme-2-dracula.png)

*`modus-operandi` (the built-in, accessible light theme):*

![modus-operandi with the fixed cursor](images/theme-3-modus-operandi.png)

*`catppuccin` (mocha):*

![catppuccin with the fixed cursor](images/theme-4-catppuccin.png)

## Magit

| Topic | Note |
|---|---|
| "pathspec '...' did not match" | git has no such branch/tag, not a Magit bug --- `b b` to pick an existing one, `b c` to create a new one |
| Transient switches | keys literally include a `-` (e.g. `-n`, `-A`) --- press `-` then the letter |
| `magit-dispatch` (`C-c G`) | Magit's own full command menu (status, log, branch, stash, everything) --- was autoloaded in init.el from early on but never actually bound to a key until a real gap report ("also include magit in the menu") caught it |

## Six more packages (Corfu, Yasnippet, expand-region, diff-hl, vterm, pdf-tools)

| Topic | Note |
|---|---|
| Corfu (`C-c k`'s own popup, no key to press) | in-buffer completion as you type, driven by whatever `completion-at-point-functions` the buffer already has --- Eglot wires its own in per-buffer automatically, nothing extra to do |
| `corfu-terminal`/`popon` | tried, then deliberately left back OUT --- this project's Emacs (32.0.50) already has native tty-child-frame support, confirmed by actually watching a real popup render in a real `-nw` session; `corfu.el` itself warns `corfu-terminal` is unneeded on Emacs 31+ |
| `C-c Y` (`yas-insert-snippet`) | Yasnippet; no snippet collection is bundled on purpose, so this starts empty --- `M-x yas-new-snippet` to write one |
| TAB and Yasnippet | only ever intercepts TAB when the text right before the cursor is a real snippet trigger (a `:filter`'d conditional keybinding, Emacs's own standard idiom) --- any other TAB press behaves exactly as before |
| `C-=` / `C-M--` | expand-region: grow/shrink the selection by semantic units (word, then the content inside the nearest pair, then the pair with its parens, then outward again) |
| diff-hl | live git change markers --- a fringe `\|` in a GUI frame, a margin `+`/`-`/`~` in a `-nw` terminal session (`diff-hl-margin-mode`, needed since the fringe doesn't exist there at all); also marks changed files in Dired itself |
| `C-c V` (`vterm`) | a real terminal emulator (full curses apps: htop, vim, ssh) --- its native module downloads and builds its own copy of `libvterm` automatically the first time it's used. True on Linux (this machine already had `cmake`/`gcc`); on a fresh Windows machine those genuinely need installing first --- see the Windows row below |
| `vterm` on Windows | needs `cmake` and a real C compiler present on THAT machine before `C-c V`'s first-use compile can work --- confirmed for real: `cmake` was already there on one test machine, `gcc`/`g++` were not, installed via `winget install --id BrechtSanders.WinLibs.POSIX.UCRT` (a maintained MinGW-w64 build; confirmed working from a fresh shell afterward --- a shell already open when the install runs will not see the updated PATH, needs a new one). A real, found-while-testing-this gotcha if you try to verify the compile indirectly (e.g. driving a Windows Emacs process from WSL): the compiled module can end up named/built wrong (an actual Linux ELF file, not a Windows DLL) if the process spawning `cmake`/`gcc` has a stale or cross-contaminated `PATH` --- a real, normal, directly-launched Windows Emacs session (double-click, or a real Windows terminal) does not have this problem; only indirect/bridged invocations do |
| pdf-tools | wired in, but genuinely blocked on one real system package this build process cannot install for itself: `sudo apt-get install libpoppler-glib-dev`, then restart Emacs --- until then, `.pdf` files keep working exactly as before (no regression either way, see init.el's own comment) |

## A ranger-style file manager (`C-c R`), genuinely separate from Dired

| Topic | Note |
|---|---|
| `C-c R` (`ranger`) | opens a real Miller-columns file manager (parent dir, listing, live preview) --- explicitly kept separate from plain Dired, per a real user request, not a default |
| Why `ranger`, not `dirvish` | `dirvish` (tried first) only works at all with its own GLOBAL `dirvish-override-dired-mode` turned on, which would make plain `dired`/`C-x d` ALSO become Dirvish sessions --- confirmed directly by calling its standalone `dirvish` command without that mode on and getting a perfectly plain Dired buffer back, nothing Dirvish-specific at all; `ranger-mode` is a real, self-contained derived mode instead, no global switch needed |
| Two real "mingling" bugs found and fixed before this shipped | (1) the always-visible reference panel (built earlier this session) would claim the exact side-window slot ranger's own preview pane needs, breaking its layout --- fixed with a dedicated slot/width for `ranger-mode` (see "Dired and Org: Casual" above, now showing ranger's own content there too, not excluded any more); (2) `ranger.el` itself installs `C-p` → `deer-from-dired` into the SHARED `dired-mode-map` (its own default `ranger-key`) the first time ANY Dired buffer opens after it's loaded, silently breaking plain `previous-line` in Dired everywhere --- fixed by pre-setting `ranger-key` to nil in init.el before the library ever loads |
| Opening a file leaves ranger's own keys behind | real user confusion, worth knowing: pressing `l`/`RET`/right-arrow on a FILE (not a directory) calls `find-file` on it, which replaces that window's buffer with the file's own major mode --- `ranger-mode-map`'s own keys (`h`/`j`/`k`/`l`, arrows, etc.) stop working at that point, since you're no longer in a `ranger` buffer at all. `C-c R` is bound GLOBALLY, not just inside `ranger` --- pressing it again from the opened file re-opens `ranger` right where you were (it defaults to the current buffer's own directory), the simplest way back |
| Pane widths | the default 3-pane split (`ranger-width-parents` 0.12, `ranger-width-preview` 0.65) left the middle pane --- the one you're actually reading --- squeezed into just 23% of the frame, well left of center. A first rebalance (0.15/0.50, parent 15%/middle 35%/preview 50%) widened it but, confirmed with a real screenshot, still centered it at only ~32% --- giving the preview pane the single biggest share always pushes everything else left of true center, however the middle pane's own width is tuned. Settled on 0.25/0.25 (parent 25%/middle 50%/preview 25%), the one ratio that puts the middle pane's own midpoint EXACTLY at the frame's center (`0.25 + 0.50/2 = 0.5`), confirmed visually --- the real tradeoff, the user's own explicit choice: a visibly smaller preview pane than ranger's own default convention favors, offered directly rather than assumed |
| Does this depend on screen size/resolution? | No --- confirmed directly in `ranger.el''s own source (`(floor (* (frame-pixel-width) ranger-width-preview))`): these are FRACTIONS of the current frame's own pixel width, computed fresh every time the layout is built, not fixed pixel counts, so the same 25/50/25 ratio holds identically on any monitor, window size, or resolution |

## Dired / ranger / Treemacs / Magit: cross-navigation

Jump between all three file browsers (and Magit) without losing the directory you're
currently in, user-requested one route at a time until the whole matrix was covered.
Every key here is LOCAL to that one mode's own keymap (`r` means something different
in Dired than in `ranger`, etc.), never a shared global one --- exactly to avoid
repeating the real `C-p' mingling bug above.

| From | Key | Goes to |
|---|---|---|
| Dired | `r` | `ranger`, same directory |
| `ranger` | `r` | plain Dired, same directory (and cleans up `ranger`'s own extra parent/preview panes, which its own `ranger-to-dired` deliberately leaves open) |
| Dired or `ranger` | `C-c T` | Treemacs, on that directory --- a real gap fixed along the way: `treemacs-find-file` (what `C-c T` wraps) only ever looks at `buffer-file-name`, always nil in a directory listing, so this used to fall into Treemacs's own "File to find:" prompt instead |
| Treemacs | `D` | plain Dired, on the directory at point |
| Treemacs | `z` | `ranger`, on the directory at point |
| Treemacs | `G` | Magit status for the repository the directory at point belongs to --- a real gotcha: `magit-status` called WITH a directory argument requires that EXACT directory to be a repo's own toplevel, or it offers to init a nested repo there instead, so this `let`-binds `default-directory` and calls it with no argument instead, the same way `C-x g` itself does |
| Dired or `ranger` | `C-x g` | Magit status for the enclosing repository --- already worked, no new binding needed, confirmed directly (`key-binding` from inside each) |

## Dist bundles / GitHub Actions

| Topic | Note |
|---|---|
| Fresh unzipped bundle | no `recentf`/`recents` history shipped --- always starts clean |
| `.github/workflows/release.yml` | Linux only (Windows dist needs WSL/`cmd.exe`) --- triggers on a pushed version tag (`v*`) |

## Reference panel toggle, Docker/Kubernetes, and a batch of smaller tools

| Topic | Note |
|---|---|
| `C-c H` | turns the always-visible reference panel (Dired/Org/ranger/Treemacs) off, or back on --- shown by default |
| `C-c K d` | Docker: one transient menu for containers/images/volumes/networks (needs a real `docker` on PATH) |
| `C-c K k` | Kubernetes: `kubernetes-overview`, a buffer listing a cluster's resources (needs `kubectl` configured) |
| `C->` / `C-<` / `C-c C-<` | multiple-cursors: mark next/previous/all occurrences like this, then just type |
| `C-c C-h` (inside an Org buffer with `verb-mode` on) | `verb`, a real HTTP client --- "postman in eMacs." `C-c C-h C-s` sends the request at point |
| `C-h D` | `devdocs-lookup` --- offline language/library docs, each set downloaded on first use |
| `C-c v` (Evil toggle) | now also offers to install/initialize `evil-collection` the first time Evil turns on --- real vi keys in Dired/Magit/Treemacs/etc., not just plain Emacs's own bindings under Evil's normal state |
| `vterm` on Windows | genuinely does NOT work, full stop --- not a missing-tool problem, confirmed by reading `vterm-module.c` itself: it unconditionally uses real POSIX `termios`/pty calls with zero Windows code path anywhere. `libtool`/`cc`/libvterm's own Unix-only `bin/` tools were all real, fixable gaps found first (MSYS2 for `libtool`, copy `gcc.exe` to `cc.exe`, and vterm's `CMakeLists.txt` now asks for just the `libvterm.la` target) --- but the module itself still can't build. `C-c V` stays Linux-only |
| `C-c W` | a WizTree-style disk usage browser (`my/disk-usage`, powered by `dua` --- real, parallel, fast, but NOT WizTree's own MFT-reading trick; ~2 minutes for a full ~1.3 TB Windows `C:\`, confirmed for real) --- `RET`/`f` drills in, `^`/`u` goes back up, `d` opens Dired there |
| `C-c W` inside Dired | a different thing, same key: toggles `dired-du-mode` --- recursive sizes right in the listing. Off by default, noticeably slower on a big tree |
| This config's own package-activation gap | bit twice now (`docker`/`kubernetes`, then `dired-du`): `package.el` is only ever used to DOWNLOAD packages here, never to activate them --- every single optional command needs its own explicit `(autoload ...)` in `init.el`, or it is just plain not `fboundp` at all, confirmed the hard way both times by `tests/ert/keybindings.el`'s own `keys/every-documented-command-exists` |
| `C-c F`/`C-c }`/`C-c {` | pick/cycle a font by character, 20 real ones (`my/fonts`) --- same shape as `C-c c` for themes, but a font is a plain OS resource this project never installs, so picking one not actually on the machine says so plainly instead of silently doing nothing |
| `:font` vs `:family` on `set-face-attribute` | a real, found-the-hard-way difference: `:font` takes a full font STRING and silently does NOTHING at all if it cannot resolve a real matching font right then (no error, face stays whatever it was); `:family` sets the plain family-name attribute unconditionally. Use `:family` for anything that needs to reliably apply/be testable; `:font` is fine only when already gated behind a real `find-font' check first (see the font-switcher above) |
| Dual line-number columns (`my/absolute-line-numbers-margin-mode`, GUI only) | `display-line-numbers-type` is `relative` (one line, real request after it showed up in tsoding/rexim's own config); the CURRENT line still shows its real absolute number for free (`display-line-numbers-current-absolute`, a real built-in, on by default) --- but showing absolute for EVERY line at once needed a second, hand-built column: a left window MARGIN with overlays, since `display-line-numbers-mode` only ever draws one number per line natively, no Lisp hook for a second. GUI-only (`diff-hl-margin-mode` only ever uses a margin as a *terminal* fallback, confirmed in its own code, so no real conflict to worry about there) |
| A real hang, found testing the margin feature above | `window-end`/`forward-line` can desync at a buffer's own edges (no trailing newline, an empty buffer) and loop forever in a function that runs on every keystroke --- confirmed directly: an actual Emacs process stuck past the 15s timeout in the real GUI screenshot pipeline. Fixed with a hard iteration cap (no real window is ever hundreds of lines tall) and by computing `window-end` ONCE before the loop, not on every iteration (repeatedly forcing it can itself trigger redisplay) |
| `%p` in the mode line (buffer position as a percentage, or Top/Bot/All) | a real, built-in Emacs feature, just off by default --- `(size-indication-mode 1)` is the one line that turns it on; `mode-line-percent-position` already holds the right format spec either way |
