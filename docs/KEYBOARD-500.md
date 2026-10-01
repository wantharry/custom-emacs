# Emacs keybindings — tier 2 (526 entries)

**Review draft** — a broader, less-curated companion to [KEYBOARD.md](KEYBOARD.md), not
yet machine-checked by `tests/ert/keybindings.el` the way that file is. Every key/command
pair below was still pulled directly from a real keymap dump against this project's own
built Emacs (`install/bin/emacs`, GNU Emacs 32.0.50) loaded with the real config
(`config/early-init.el` + `config/init.el`) — nothing here was invented from memory. Rows
with a filled-in "What it does" column come from the already-agreed seed draft (itself
sourced from `docs/KEYBOARD.md` / `config/shortcuts.el`); rows with a blank description
are raw, real bindings pulled straight from the keymap dump, added purely for coverage at
this tier.

This tier is a strict superset of the smaller tier: every command in
[KEYBOARD-200.md](KEYBOARD-200.md) also appears here, unchanged, plus the next layer of
coverage. See [KEYBOARD-1000.md](KEYBOARD-1000.md) for the largest tier.

Total real, distinct entries in this file: **526**.

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
| 1 | same-window-prefix |  |
| 4 | other-window-prefix |  |
| a | add-change-log-entry-other-window |  |
| b | switch-to-buffer-other-window |  |

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
| % | Buffer-menu-toggle-read-only |  |
| 1 | Buffer-menu-1-window |  |
| 2 | Buffer-menu-2-window |  |
| I | Buffer-menu-toggle-internal |  |
| O | Buffer-menu-view-other-window |  |
| S | tabulated-list-sort |  |
| T | Buffer-menu-toggle-files-only |  |
| U | Buffer-menu-unmark-all |  |

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
| # | dired-flag-auto-save-files |  |
| $ | dired-hide-subdir |  |
| & | dired-do-async-shell-command |  |
| ( | dired-hide-details-mode |  |
| . | dired-clean-directory |  |
| < | dired-prev-dirline |  |
| = | dired-diff |  |
| > | dired-next-dirline |  |
| ? | dired-summary |  |
| @ | tramp-dired-find-file-with-sudo |  |
| A | dired-do-find-regexp |  |
| B | dired-do-byte-compile |  |
| D | dired-do-delete |  |
| E | dired-do-open |  |
| G | dired-do-chgrp |  |
| H | dired-do-hardlink |  |
| I | dired-do-info |  |
| L | dired-do-load |  |
| M | dired-do-chmod |  |
| N | dired-do-man |  |
| O | dired-do-chown |  |
| P | dired-do-print |  |
| Q | dired-do-find-regexp-and-replace |  |
| S | dired-do-symlink |  |
| T | dired-do-touch |  |

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
| ! | ibuffer-do-shell-command-file |  |
| + | ibuffer-add-to-tmp-show |  |
| , | ibuffer-toggle-sorting-mode |  |
| - | ibuffer-add-to-tmp-hide |  |
| . | ibuffer-mark-old-buffers |  |
| / | | ibuffer-or-filter |  |
| = | ibuffer-diff-with-file |  |
| A | ibuffer-do-view |  |
| B | ibuffer-copy-buffername-as-kill |  |
| D | ibuffer-do-delete |  |
| E | ibuffer-do-eval |  |
| H | ibuffer-do-view-other-frame |  |
| I | ibuffer-do-query-replace-regexp |  |
| L | ibuffer-do-toggle-lock |  |
| M | ibuffer-do-toggle-modified |  |
| N | ibuffer-do-shell-command-pipe-replace |  |
| O | ibuffer-do-occur |  |
| P | ibuffer-do-print |  |

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
| . | xref-find-by-kind |  |
| c | goto-char |  |
| i | imenu |  |

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
| + | increment-register |  |
| B | buffer-to-register |  |
| F | file-to-register |  |
| M | bookmark-set-no-overwrite |  |
| N | rectangle-number-lines |  |
| c | clear-rectangle |  |

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
| C-\ | isearch-toggle-input-method |  |
| C-^ | isearch-toggle-specified-input-method |  |
| C-g | isearch-abort |  |
| C-q | isearch-quote-char |  |
| C-r | isearch-repeat-backward |  |
| C-s | isearch-repeat-forward |  |
| C-w | isearch-yank-word-or-char |  |
| C-y | isearch-yank-kill |  |
| M-% | isearch-query-replace |  |
| M-c | isearch-toggle-case-fold |  |
| M-e | isearch-edit-string |  |
| M-n | isearch-ring-advance |  |
| M-p | isearch-ring-retreat |  |
| M-r | isearch-toggle-regexp |  |
| M-y | isearch-yank-pop-only |  |

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
| ! | magit-run |  |
| $ | magit-process-buffer |  |
| % | magit-worktree |  |
| + | magit-diff-more-context |  |
| - | magit-diff-less-context |  |
| 0 | magit-diff-default-context |  |
| 1 | magit-section-show-level-1 |  |
| 2 | magit-section-show-level-2 |  |
| 3 | magit-section-show-level-3 |  |
| 4 | magit-section-show-level-4 |  |
| : | magit-git-command |  |
| > | magit-sparse-checkout |  |
| ? | magit-dispatch |  |
| A | magit-cherry-pick |  |
| B | magit-bisect |  |
| C | magit-clone |  |
| D | magit-diff-refresh |  |
| E | magit-ediff |  |
| F | magit-pull |  |
| G | magit-refresh-all |  |
| H | magit-describe-section |  |
| I | magit-init |  |
| J | magit-display-repository-buffer |  |
| K | magit-file-untrack |  |
| L | magit-log-refresh |  |
| M | magit-remote |  |
| O | magit-subtree |  |
| P | magit-push |  |
| R | magit-file-rename |  |
| S | magit-stage-modified |  |
| T | magit-notes |  |
| U | magit-unstage-all |  |
| V | magit-revert |  |
| W | magit-patch |  |
| X | magit-reset |  |

## 17. Project tree — Treemacs

| Key | Command | What it does |
|---|---|---|
| C-c t | my/treemacs | this config: show/hide project file tree |
| C-c T | my/treemacs-reveal | this config: show tree + jump to current file |
| ! | treemacs-run-shell-command-for-current-node |  |
| < | treemacs-decrease-width |  |
| = | treemacs-fit-window-width |  |
| > | treemacs-increase-width |  |
| ? | treemacs-common-helpful-hydra |  |
| C | treemacs-cleanup-litter |  |
| H | treemacs-collapse-parent-node |  |
| P | treemacs-peek-mode |  |
| Q | treemacs-kill-buffer |  |
| R | treemacs-rename-file |  |
| W | treemacs-extra-wide-toggle |  |
| b | treemacs-add-bookmark |  |
| d | treemacs-delete-file |  |
| g | treemacs-refresh |  |
| h | treemacs-COLLAPSE-action |  |
| l | treemacs-RET-action |  |
| m | treemacs-move-file |  |
| n | treemacs-next-line |  |
| p | treemacs-previous-line |  |
| q | treemacs-quit |  |
| s | treemacs-resort |  |
| u | treemacs-goto-parent-node |  |
| w | treemacs-set-width |  |
| C-? | treemacs-advanced-helpful-hydra |  |
| C-j | treemacs-next-project |  |

## 18. Completion / actions — Embark

| Key | Command | What it does |
|---|---|---|
| C-. | embark-act | menu of actions on thing at point |
| C-; | embark-dwim | run default action, no menu |
| C-h B | embark-bindings | list every action available now |
| A | embark-act-all |  |
| B | embark-become |  |
| E | embark-export |  |
| L | embark-live |  |
| S | embark-collect |  |
| i | embark-insert |  |
| q | embark-toggle-quit |  |
| w | embark-copy-as-kill |  |
| C F | consult-locate |  |
| C G | consult-git-grep |  |
| C I | consult-imenu-multi |  |
| C L | consult-line-multi |  |
| C f | consult-find |  |
| C g | consult-grep |  |
| C i | consult-imenu |  |
| C o | consult-outline |  |
| C-r | embark-isearch-backward |  |
| C-s | embark-isearch-forward |  |

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
| ? | help-for-help |  |
| C | describe-coding-system |  |
| F | Info-goto-emacs-command-node |  |
| I | describe-input-method |  |
| K | Info-goto-emacs-key-command-node |  |
| L | describe-language-environment |  |
| P | describe-package |  |
| R | info-display-manual |  |
| S | info-lookup-symbol |  |
| a | apropos-command |  |

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
| 5 | my/start-open-nth-file |  |
| d | my/start-open-dired |  |
| f | my/start-find-in-project |  |
| g | my/start-refresh |  |
| m | my/start-open-magit |  |
| n | forward-button |  |
| p | backward-button |  |
| t | my/start-open-treemacs |  |
| RET | push-button |  |
| C-c @ | outline-mark-subtree |  |
| C-c / h | outline-hide-by-heading-regexp |  |
| C-c / s | outline-show-by-heading-regexp |  |
| C-c C-< | outline-promote |  |
| C-c C-> | outline-demote |  |
| C-c C-^ | outline-move-subtree-up |  |
| C-c C-a | outline-show-all |  |
| C-c C-b | outline-backward-same-level |  |
| C-c C-c | outline-hide-entry |  |
| C-c C-d | outline-hide-subtree |  |
| C-c C-e | outline-show-entry-and-parents |  |
| C-c C-f | outline-forward-same-level |  |
| C-c C-k | outline-show-branches |  |

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
| ! | evil-shell-command |  |
| # | evil-search-word-backward |  |
| % | evil-jump-item |  |
| ' | evil-goto-mark-line |  |
| ( | evil-backward-sentence-begin |  |
| ) | evil-forward-sentence-begin |  |
| * | evil-search-word-forward |  |
| + | evil-next-line-first-non-blank |  |
| , | evil-repeat-find-char-reverse |  |
| - | evil-previous-line-first-non-blank |  |
| ; | evil-repeat-find-char |  |
| ? | evil-search-backward |  |
| B | evil-backward-WORD-begin |  |
| E | evil-forward-WORD-end |  |
| F | evil-find-char-backward |  |
| H | evil-window-top |  |
| K | evil-lookup |  |
| L | evil-window-bottom |  |
| M | evil-window-middle |  |
| N | evil-search-previous |  |
| T | evil-find-char-to-backward |  |
| V | evil-visual-line |  |
| W | evil-forward-WORD-begin |  |
| Y | evil-yank-line |  |
| \ | evil-execute-in-emacs-state |  |
| ^ | evil-first-non-blank |  |
| _ | evil-next-line-1-first-non-blank |  |
| ` | evil-goto-mark |  |
| e | evil-forward-word-end |  |
| f | evil-find-char |  |
| n | evil-search-next |  |
| t | evil-find-char-to |  |
| v | evil-visual-char |  |
| { | evil-backward-paragraph |  |
| | | evil-goto-column |  |

## 23. Org (installed, not auto-enabled for .org files in this config)

| Key | Command | What it does |
|---|---|---|
| | | org-force-self-insert |  |
| C-# | org-table-rotate-recalc-marks |  |
| C-' | org-cycle-agenda-files |  |
| C-c | | org-table-create-or-convert-from-region |  |
| C-j | org-return-and-maybe-indent |  |
| M-h | org-mark-element |  |
| M-{ | org-backward-element |  |
| M-} | org-forward-element |  |
| RET | org-return |  |
| TAB | org-cycle |  |
| C-M-t | org-transpose-element |  |
| C-c ! | org-timestamp-inactive |  |
| C-c # | org-update-statistics-cookies |  |
| C-c $ | org-archive-subtree |  |
| C-c % | org-mark-ring-push |  |
| C-c & | org-mark-ring-goto |  |
| C-c ' | org-edit-special |  |
| C-c * | org-ctrl-c-star |  |
| C-c + | org-table-sum |  |
| C-c , | org-priority |  |
| C-c - | org-ctrl-c-minus |  |
| C-c . | org-timestamp |  |
| C-c / | org-sparse-tree |  |
| C-c : | org-toggle-fixed-width |  |
| C-c ; | org-toggle-comment |  |
| C-c < | org-date-from-calendar |  |
| C-c = | org-table-eval-formula |  |
| C-c > | org-goto-calendar |  |
| C-c ? | org-table-field-info |  |
| C-c @ | org-mark-subtree |  |

## 24. Calc

| Key | Command | What it does |
|---|---|---|
| ! | calc-missing-key |  |
| " | calc-auto-algebraic-entry |  |
| # | calcDigit-start |  |
| % | calc-mod |  |
| & | calc-inv |  |
| ' | calc-algebraic-entry |  |
| * | calc-times |  |
| + | calc-plus |  |
| - | calc-minus |  |
| / | calc-divide |  |
| ? | calc-help |  |
| ^ | calc-power |  |
| i | calc-info |  |
| n | calc-change-sign |  |
| q | calc-quit |  |

## 25. Compilation / grep / occur result buffers

| Key | Command | What it does |
|---|---|---|
| g | recompile |  |
| n | next-error-no-select |  |
| p | previous-error-no-select |  |
| C-o | compilation-display-error |  |
| M-p | compilation-previous-error |  |
| M-{ | compilation-previous-file |  |
| M-} | compilation-next-file |  |
| RET | compile-goto-error |  |
| TAB | compilation-next-error |  |
| C-c C-f | next-error-follow-minor-mode |  |
| C-c C-k | kill-compilation |  |
| e | grep-change-to-grep-edit-mode |  |
| l | recenter-current-error |  |
| c | clone-buffer |  |
| e | occur-edit-mode |  |
| o | occur-mode-goto-occurrence-other-window |  |
| r | occur-rename-buffer |  |
| C-o | occur-mode-display-occurrence |  |

## 26. Image / Doc-View / View-mode (read-only viewers)

| Key | Command | What it does |
|---|---|---|
| F | image-goto-frame |  |
| W | image-mode-wallpaper-set |  |
| b | image-previous-frame |  |
| f | image-next-frame |  |
| m | image-mode-mark-file |  |
| n | image-next-file |  |
| p | image-previous-file |  |
| u | image-mode-unmark-file |  |
| w | image-mode-copy-file-name-as-kill |  |
| DEL | image-scroll-down |  |
| RET | image-toggle-animation |  |
| SPC | image-scroll-up |  |
| a + | image-increase-speed |  |
| a - | image-decrease-speed |  |
| a 0 | image-reset-speed |  |
| a r | image-reverse-speed |  |
| i + | image-increase-size |  |
| i - | image-decrease-size |  |

## 27. Info & help-mode (reading documentation)

| Key | Command | What it does |
|---|---|---|
| , | Info-index-next |  |
| < | Info-top-node |  |
| > | Info-final-node |  |
| ? | Info-summary |  |
| G | Info-goto-node-web |  |
| I | Info-virtual-index |  |
| L | Info-history |  |
| S | Info-search-case-sensitively |  |
| T | Info-toc |  |
| [ | Info-backward-node |  |
| ] | Info-forward-node |  |
| ^ | Info-up |  |

## 28. Version control, extended (vc-dir, full C-x v)

| Key | Command | What it does |
|---|---|---|
| + | vc-pull |  |
| = | vc-diff |  |
| ? | vc-dir-toggle-hints |  |
| @ | vc-revert |  |
| D | vc-root-diff |  |
| G | vc-dir-ignore |  |
| I | vc-root-log-incoming |  |
| L | vc-print-root-log |  |
| M | vc-dir-mark-all-files |  |
| O | vc-root-log-outgoing |  |
| P | vc-push |  |
| Q | vc-dir-query-replace-regexp |  |
