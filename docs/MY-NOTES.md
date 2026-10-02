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

All 8 [Modus Themes](https://github.com/protesilaos/modus-themes) ship built into Emacs 28+ already --- no package, confirmed directly (`etc/themes/modus-*-theme.el`). The other 47 come from 15 separately installed packages (`atom-one-dark-theme`, `catppuccin-theme`, `solo-jazz-theme`, `nimbus-theme`, `rebecca-theme`, `subatomic-theme`, `night-owl-theme`, `seti-theme`, `shanty-themes`, `snazzy-theme`, `horizon-theme`, `xcode-theme`, `immaterial-theme`, `zenburn-theme`, `solarized-theme`, `dracula-theme`, `kaolin-themes`, `ember-theme` --- full URLs in the WHAT/WHY comment above `my/themes` in `config/init.el`). A real, easy-to-get-backwards gotcha found while wiring these up: `load-theme` never consults `load-path` at all --- it always does its own file search through `custom-theme-load-path`, whose `t` entry expands to Emacs's *built-in* `etc/themes` directory, not to `load-path`; a theme package can `require` fine while still being completely invisible to `load-theme`/`consult-theme` unless its directory is *also* pushed onto `custom-theme-load-path` (now done in the same loop that adds `config/elpa`'s subdirectories to `load-path`). `my/themes` in `config/init.el` is the character→theme mapping; add more there (any installed theme) to extend `C-c c` without a new keybinding. `ember-theme` needs `doom-themes` as a hard dependency --- installed, but deliberately never `require`d automatically (this project's own `startup/no-third-party-features-loaded' test forbids it), so `doom-themes`'s own 50+ variants are reachable only via `C-c C`'s fuzzy search, never a `my/themes` slot. `theme-buffet` is a real GNU ELPA package (not one of Protesilaos's own, despite appearing in his dotfiles) --- `my/themes-light`/`my/themes-dark` is where it's told which of `my/themes`'s entries count as which; keep both lists in step when adding a theme that should also take part in the automatic rotation.

## Magit

| Topic | Note |
|---|---|
| "pathspec '...' did not match" | git has no such branch/tag, not a Magit bug --- `b b` to pick an existing one, `b c` to create a new one |
| Transient switches | keys literally include a `-` (e.g. `-n`, `-A`) --- press `-` then the letter |

## Dist bundles / GitHub Actions

| Topic | Note |
|---|---|
| Fresh unzipped bundle | no `recentf`/`recents` history shipped --- always starts clean |
| `.github/workflows/release.yml` | Linux only (Windows dist needs WSL/`cmd.exe`) --- triggers on a pushed version tag (`v*`) |
