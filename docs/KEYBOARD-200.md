# Emacs keybindings — tier 1 (197 entries)

**Review draft** — a broader, less-curated companion to [KEYBOARD.md](KEYBOARD.md), not
yet machine-checked by `tests/ert/keybindings.el` the way that file is. Every key/command
pair below was still pulled directly from a real keymap dump against this project's own
built Emacs (`install/bin/emacs`, GNU Emacs 32.0.50) loaded with the real config
(`config/early-init.el` + `config/init.el`) — nothing here was invented from memory. Rows
with a filled-in "What it does" column come from the already-agreed seed draft (itself
sourced from `docs/KEYBOARD.md` / `config/shortcuts.el`); rows with a blank description
are raw, real bindings pulled straight from the keymap dump, added purely for coverage at
this tier.

This is the smallest of three tiers (200/500/1000); see [KEYBOARD-500.md](KEYBOARD-500.md)
and [KEYBOARD-1000.md](KEYBOARD-1000.md) for the larger, strictly-superset tiers.

Total real, distinct entries in this file: **197**.

## 1. Frames (OS-level windows)

| Key | Command | What it does |
|---|---|---|
| C-x 5 2 | make-frame-command | new frame |
| C-x 5 0 | delete-frame | close this frame |
| C-x 5 o | other-frame | jump to the next frame |
| C-x 5 1 | delete-other-frames | close every other frame |

## 2. Windows (panes inside a frame)

| Key | Command | What it does |
|---|---|---|
| C-x o | other-window | move to next window |
| M-o | ace-window | this config: jump to a window by its letter |
| C-x 2 | split-window-below | split top/bottom |
| C-x 3 | split-window-right | split left/right |
| C-x 0 | delete-window | close this window |
| C-x 1 | delete-other-windows | keep only this one |
| C-x + | balance-windows | make all equal size |
| C-x ^ | enlarge-window | taller |
| C-x } | enlarge-window-horizontally | wider |
| C-x { | shrink-window-horizontally | narrower |
| C-x 4 f | find-file-other-window | open a file in another window |
| C-x 4 0 | kill-buffer-and-window | close buffer + its window |

## 3. Buffers (open / close / switch)

| Key | Command | What it does |
|---|---|---|
| C-x C-f | find-file | open a file |
| C-x C-s | save-buffer | save |
| C-x k | kill-buffer | close a buffer |
| C-x b | switch-to-buffer | switch by name |
| C-x C-b | ibuffer | list all buffers |
| C-c s b | consult-buffer | this config: switch buffer/recent file/bookmark, live preview |
| C-c r | recentf-open | this config: open a recent file |
| C-c h | my/start | this config: start screen: recent files/folders/projects |
| C-x <left> | previous-buffer | previous buffer |
| C-x <right> | next-buffer | next buffer |

## 4. Dired: the directory editor

| Key | Command | What it does |
|---|---|---|
| C-x d | dired | open Dired on a directory |
| C-x C-j | dired-jump | jump to the current file's directory in Dired |
| RET | dired-find-file | open the file, or enter the directory |
| ^ | dired-up-directory | go up to the parent directory |
| g | revert-buffer | refresh the listing |
| q | quit-window | close Dired |
| m | dired-mark | mark the file |
| u | dired-unmark | unmark it |
| d | dired-flag-file-deletion | flag for deletion |
| x | dired-do-flagged-delete | actually delete everything flagged |
| C | dired-do-copy | copy (asks for destination) |
| R | dired-do-rename | rename or move |
| + | dired-create-directory | make a directory |
| ! | dired-do-shell-command | run a shell command on the files |
| C-x C-q | dired-toggle-read-only | wdired: edit file names as text |

## 5. ibuffer: the buffer list

| Key | Command | What it does |
|---|---|---|
| C-x C-b |  | this config: opens ibuffer, not the plain buffer list (see Buffers, above) |
| RET | ibuffer-visit-buffer | open the buffer |
| o | ibuffer-visit-buffer-other-window | open it in another window |
| m | ibuffer-mark-forward | mark |
| u | ibuffer-unmark-forward | unmark |
| d | ibuffer-mark-for-delete | flag for closing |
| x | ibuffer-do-kill-on-deletion-marks | close every flagged buffer |
| S | ibuffer-do-save | save the marked buffers |
| g | ibuffer-update | refresh |
| q |  | leave (quit-window, see Help/general above) |

## 6. Moving — top / bottom of buffer

| Key | Command | What it does |
|---|---|---|
| M-< | beginning-of-buffer |  |
| M-> | end-of-buffer |  |
| M-g g | goto-line |  |
| C-l | recenter-top-bottom | cycle line to middle/top/bottom |

## 7. Moving — by page

| Key | Command | What it does |
|---|---|---|
| C-v | scroll-up-command | down one screen |
| M-v | scroll-down-command | up one screen |

## 8. Moving — by paragraph

| Key | Command | What it does |
|---|---|---|
| M-{ | backward-paragraph |  |
| M-} | forward-paragraph |  |
| M-h | mark-paragraph | select it |

## 9. Moving — by line

| Key | Command | What it does |
|---|---|---|
| C-n | next-line |  |
| C-p | previous-line |  |
| C-a | move-beginning-of-line |  |
| C-e | move-end-of-line |  |
| M-m | back-to-indentation | first non-blank char |

## 10. Moving — by parentheses / expression (sexp)

| Key | Command | What it does |
|---|---|---|
| C-M-f | forward-sexp | over a balanced expr |
| C-M-b | backward-sexp |  |
| C-M-u | backward-up-list | out to enclosing paren |
| C-M-d | down-list | into the next paren |
| C-M-a | beginning-of-defun |  |
| C-M-e | end-of-defun |  |
| C-M-k | kill-sexp | cut a balanced expr |
| C-M-t | transpose-sexps | swap two expressions |

## 11. Moving — by character / word

| Key | Command | What it does |
|---|---|---|
| C-f | forward-char |  |
| C-b | backward-char |  |
| M-f | forward-word |  |
| M-b | backward-word |  |

## 12. Jumping

| Key | Command | What it does |
|---|---|---|
| C-' | avy-goto-char-timer | this config: jump anywhere by typing a few chars |
| M-. | xref-find-definitions | jump to a definition |
| M-, | xref-go-back |  |
| M-? | xref-find-references | find uses |
| M-i | symbol-overlay-put | this config: highlight every occurrence of symbol at point |

## 13. Selecting / cutting / pasting / undo

| Key | Command | What it does |
|---|---|---|
| C-SPC | set-mark-command | start selecting |
| C-w | kill-region | cut |
| M-w | kill-ring-save | copy |
| C-y | yank | paste |
| M-y | yank-pop | cycle older clipboard entries |
| C-k | kill-line | cut to end of line |
| C-/ | undo |  |
| C-x r m | bookmark-set | bookmark this place |
| C-x r b | bookmark-jump | jump to a bookmark |
| C-x r k | kill-rectangle | cut a rectangular block |
| C-x r y | yank-rectangle | paste the block |
| <f3> | kmacro-start-macro-or-insert-counter | start recording a macro |
| <f4> | kmacro-end-or-call-macro | stop recording; press again to replay |
| C-x x | exchange-point-and-mark | swap cursor/mark |

## 14. Search — in buffer

| Key | Command | What it does |
|---|---|---|
| C-s | isearch-forward |  |
| C-r | isearch-backward |  |
| C-c s l | consult-line | this config: search this buffer, live preview |
| M-% | query-replace |  |
| C-M-% | query-replace-regexp |  |
| RET | isearch-exit | isearch: stop here, keep cursor at match |
| DEL | isearch-delete-char | isearch: delete last search char |

## 15. Search — project / disk

| Key | Command | What it does |
|---|---|---|
| C-c f f | my/ff-find-file | this config: fuzzy finder, project or whole disk |
| C-c s g | consult-ripgrep | this config: search project text, live preview |
| C-c s f | consult-fd | this config: find project file by name, live preview |
| C-c f a | my/ff-find-file-global-async | this config: same, never blocks Emacs |
| C-c f r | my/ff-reindex | this config: rebuild whole-disk index |
| C-x p f | project-find-file | open a file in current project |
| C-x p g | project-find-regexp | search whole project |

## 16. Git — Magit

| Key | Command | What it does |
|---|---|---|
| C-x g | magit-status | git status, stage/commit |
| C-c g | magit-file-dispatch | this config: git commands for this file |
| C-c f p | my/find-git-repos | this config: list every repo on disk, instant |
| s | magit-stage | magit: stage the change at point |
| u | magit-unstage | magit: unstage the change at point |

## 17. Project tree — Treemacs

| Key | Command | What it does |
|---|---|---|
| C-c t | my/treemacs | this config: show/hide project file tree |
| C-c T | my/treemacs-reveal | this config: show tree + jump to current file |

## 18. Completion / actions — Embark

| Key | Command | What it does |
|---|---|---|
| C-. | embark-act | menu of actions on thing at point |
| C-; | embark-dwim | run default action, no menu |
| C-h B | embark-bindings | list every action available now |

## 19. Help

| Key | Command | What it does |
|---|---|---|
| C-h k | helpful-key | this config: what does this key do, richly |
| C-h f | helpful-callable | this config: describe a command/function |
| C-h v | helpful-variable | this config: describe a setting |
| M-x | execute-extended-command | run any command by name |
| C-h m | describe-mode | modes active + their keys |
| C-h l | view-lossage | last keys pressed + what fired |
| C-g | keyboard-quit | cancel anything |

## 20. This config's own features

| Key | Command | What it does |
|---|---|---|
| C-c e e | allow-editing | unlock a buffer for editing |
| C-c e l | stop-editing | relock a buffer read-only |
| C-c w s | my/session-save |  |
| C-c w l | my/session-list |  |
| C-c d | my/docs | every guide, one buffer |
| C-c D | my/docs-rebuild |  |
| C-c k | my/shortcuts | this keybinding list itself |
| C-c y | my/calendar-year | 12-month grid calendar |
| C-c a a | my/llm-chat |  |
| C-c a m | gptel-menu |  |
| C-c a c | my/llm-council |  |
| C-c m | my/dictate |  |
| C-c M | my/dictate-live |  |
| C-c n | newsticker-treeview |  |

## 21. Packages — what's installed and why it's fast/efficient

- vertico: minimal minibuffer completion UI — no heavy dependency chain, defers matching to orderless
- orderless: completion style: space-separated tokens match in any order; pairs with vertico
- marginalia: adds annotations to minibuffer candidates; tiny, purely cosmetic/informational
- consult: a big set of small, fast search/switch commands reusing Emacs's own completion, not a new UI
- embark: contextual actions on the thing at point or the current candidate; lightweight
- embark-consult: tiny glue package: Embark previews for Consult candidates
- magit: full git porcelain UI; larger than most here, but replaces shelling out to git entirely
- magit-section: the collapsible-section UI library Magit is built on (dependency, no keys of its own)
- with-editor: lets external processes (git commit) use Emacs itself as $EDITOR (dependency for Magit)
- treemacs: file-tree sidebar; only draws when shown, doesn't scan the whole disk eagerly
- evil: vi keybindings emulation; opt-in via C-c v, off by default so it costs nothing until toggled
- avy: jump-to-visible-char navigation; single tiny package, one entry point
- ace-window: window selection by letter; tiny, no configuration needed
- wgrep: makes grep/ripgrep result buffers directly editable and saveable
- helpful: richer describe-function/variable/key buffers; replaces the built-in help, no extra keys
- symbol-overlay: highlight every occurrence of the symbol at point; one command, one toggle
- gptel: LLM chat client; minimal, no heavy dependency chain, binds almost nothing itself
- hydra: sticky/transient keymap helper (dependency some packages use for multi-step menus)
- llama: tiny anaphoric lambda macro (dependency, keeps other packages' code shorter)
- lv: small overlay-based popup library used by hydra (dependency, no keys)
- pfuture: async process wrapper (dependency, e.g. Treemacs's git status)
- posframe: child-frame popups (dependency for some packages' floating UI)
- cond-let: small cond+let utility macro (dependency, no keys)
- cfrs: child-frame read-string dialogs (dependency, e.g. Treemacs rename prompts)
- dash: general-purpose list utility library (dependency used across several packages)
- f: file-path utility library (dependency)
- s: string utility library (dependency)
- ht: hash-table utility library (dependency)
- elisp-refs: finds callers/references of an Elisp function or variable; a dev tool, no bound keys
- — Recommended, NOT currently installed —
- corfu + cape: in-buffer completion, the vertico/orderless sibling for at-point completion; much lighter than company (not yet installed)
- diff-hl: fringe markers for uncommitted git changes; tiny, complements Magit rather than overlapping it (not yet installed)
- undo-fu: linear undo/redo; pairs naturally with evil's u/C-r and is a very small package (not yet installed)
- rainbow-delimiters: purely cosmetic paren-nesting colors; negligible cost (not yet installed)
- expand-region: expands selection by syntactic units (M-= repeatedly); one function, tiny (not yet installed)

## 22. Evil: vi keys (optional)

| Key | Command | What it does |
|---|---|---|
| C-c v | my/toggle-evil | turn vi keys on/off |
| h | evil-backward-char |  |
| j | evil-next-line |  |
| k | evil-previous-line |  |
| l | evil-forward-char |  |
| w | evil-forward-word-begin |  |
| b | evil-backward-word-begin |  |
| 0 | evil-beginning-of-line |  |
| $ | evil-end-of-line |  |
| g g | evil-goto-first-line |  |
| G | evil-goto-line |  |
| i | evil-insert |  |
| a | evil-append |  |
| o | evil-open-below |  |
| x | evil-delete-char |  |
| d | evil-delete |  |
| y | evil-yank |  |
| p | evil-paste-after |  |
| u | evil-undo |  |
| / | evil-search-forward |  |
| : | evil-ex |  |
