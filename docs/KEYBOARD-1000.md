# Emacs keybindings — tier 3 (1008 entries)

**Review draft** — a broader, less-curated companion to [KEYBOARD.md](KEYBOARD.md), not
yet machine-checked by `tests/ert/keybindings.el` the way that file is. Every key/command
pair below was still pulled directly from a real keymap dump against this project's own
built Emacs (`install/bin/emacs`, GNU Emacs 32.0.50) loaded with the real config
(`config/early-init.el` + `config/init.el`) — nothing here was invented from memory. Rows
with a filled-in "What it does" column come from the already-agreed seed draft (itself
sourced from `docs/KEYBOARD.md` / `config/shortcuts.el`); rows with a blank description
are raw, real bindings pulled straight from the keymap dump, added purely for coverage at
this tier.

This is the largest of the three tiers, and a strict superset of
[KEYBOARD-500.md](KEYBOARD-500.md) (which is itself a superset of
[KEYBOARD-200.md](KEYBOARD-200.md)): every command in the 500-tier also appears here,
unchanged, plus the next layer of coverage. 1008 landed just past the round 1000 target —
nothing was padded to reach it and nothing was trimmed to avoid overshooting it.

Total real, distinct entries in this file: **1008**.

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
| c | clone-indirect-buffer-other-window |  |
| d | dired-other-window |  |
| m | compose-mail-other-window |  |
| p | project-other-window-command |  |

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
| V | Buffer-menu-view |  |
| b | Buffer-menu-bury |  |
| e | Buffer-menu-this-window |  |
| k | Buffer-menu-delete |  |
| m | Buffer-menu-mark |  |
| o | Buffer-menu-other-window |  |
| s | Buffer-menu-save |  |
| t | Buffer-menu-visit-tags-table |  |
| u | Buffer-menu-unmark |  |
| v | Buffer-menu-select |  |

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
| U | dired-unmark-all-marks |  |
| W | browse-url-of-dired-file |  |
| Y | dired-do-relsymlink |  |
| Z | dired-do-compress |  |
| a | dired-find-alternate-file |  |
| c | dired-do-compress-to |  |
| i | dired-maybe-insert-subdir |  |
| j | dired-goto-file |  |
| k | dired-do-kill-lines |  |
| l | dired-do-redisplay |  |
| n | dired-next-line |  |
| o | dired-find-file-other-window |  |
| p | dired-previous-line |  |
| s | dired-sort-toggle-or-edit |  |
| t | dired-toggle-marks |  |
| v | dired-view-file |  |
| w | dired-copy-filename-as-kill |  |
| y | dired-show-file-type |  |
| ~ | dired-flag-backup-files |  |
| % & | dired-flag-garbage-files |  |
| % C | dired-do-copy-regexp |  |
| % H | dired-do-hardlink-regexp |  |
| % R | dired-do-rename-regexp |  |
| % S | dired-do-symlink-regexp |  |
| % Y | dired-do-relsymlink-regexp |  |
| % d | dired-flag-files-regexp |  |
| % g | dired-mark-files-containing-regexp |  |
| % l | dired-downcase |  |
| % m | dired-mark-files-regexp |  |
| % u | dired-upcase |  |

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
| Q | ibuffer-do-query-replace |  |
| R | ibuffer-do-rename-uniquely |  |
| T | ibuffer-do-toggle-read-only |  |
| U | ibuffer-unmark-all-marks |  |
| V | ibuffer-do-revert |  |
| W | ibuffer-do-view-and-eval |  |
| X | ibuffer-do-shell-command-pipe |  |
| ` | ibuffer-switch-format |  |
| b | ibuffer-bury-buffer |  |
| j | ibuffer-jump-to-buffer |  |
| k | ibuffer-do-kill-lines |  |
| l | ibuffer-redisplay |  |
| n | ibuffer-forward-line |  |
| p | ibuffer-backward-line |  |
| r | ibuffer-do-replace-regexp |  |

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
| n | next-error |  |
| p | previous-error |  |

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
| d | delete-rectangle |  |
| f | frameset-to-register |  |
| g | insert-register |  |
| j | jump-to-register |  |
| l | bookmark-bmenu-list |  |
| n | number-to-register |  |
| o | open-rectangle |  |
| r | copy-rectangle-to-register |  |

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
| C-M-% | isearch-query-replace-regexp |  |
| C-M-d | isearch-del-char |  |
| C-M-i | isearch-complete |  |
| C-M-w | isearch-yank-symbol-or-char |  |
| C-M-y | isearch-yank-char |  |
| C-M-z | isearch-yank-until-char |  |
| C-h ? | isearch-help-for-help |  |
| C-h b | isearch-describe-bindings |  |
| C-h k | isearch-describe-key |  |
| C-h m | isearch-describe-mode |  |
| C-h q | help-quit |  |
| C-x \ | isearch-transient-input-method |  |
| M-s ' | isearch-toggle-char-fold |  |
| M-s _ | isearch-toggle-symbol |  |
| M-s i | isearch-toggle-invisible |  |

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
| Y | magit-cherry |  |
| ^ | magit-section-up |  |
| a | magit-cherry-apply |  |
| b | magit-branch |  |
| c | magit-commit |  |
| d | magit-diff |  |
| e | magit-ediff-dwim |  |
| f | magit-fetch |  |
| g | magit-refresh |  |
| i | magit-gitignore |  |
| j | magit-status-quick |  |
| k | magit-delete-thing |  |
| l | magit-log |  |
| m | magit-merge |  |
| n | magit-section-forward |  |
| o | magit-submodule |  |
| p | magit-section-backward |  |
| q | magit-mode-bury-buffer |  |
| r | magit-rebase |  |
| s | magit-stage-files |  |
| t | magit-tag |  |
| u | magit-unstage-files |  |
| v | magit-revert-no-commit |  |
| w | magit-am |  |
| x | magit-reset-quickly |  |
| y | magit-show-refs |  |
| z | magit-stash |  |
| C-w | magit-copy-section-value |  |
| DEL | magit-diff-show-or-scroll-down |  |
| M-1 | magit-section-show-level-1-all |  |
| M-2 | magit-section-show-level-2-all |  |
| M-3 | magit-section-show-level-3-all |  |
| M-4 | magit-section-show-level-4-all |  |
| M-n | magit-section-forward-sibling |  |
| M-p | magit-section-backward-sibling |  |
| M-w | magit-copy-buffer-revision |  |
| RET | magit-visit-thing |  |
| SPC | magit-diff-show-or-scroll-up |  |
| TAB | magit-section-toggle |  |
| C-M-i | magit-dired-jump |  |

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
| C-k | treemacs-previous-project |  |
| M-! | treemacs-run-shell-command-in-project-root |  |
| M-H | treemacs-root-up |  |
| M-L | treemacs-root-down |  |
| M-N | treemacs-next-line-other-window |  |
| M-P | treemacs-previous-line-other-window |  |
| M-m | treemacs-bulk-file-actions |  |
| M-n | treemacs-next-neighbour |  |
| M-p | treemacs-previous-neighbour |  |
| TAB | treemacs-TAB-action |  |
| c d | treemacs-create-dir |  |
| c f | treemacs-create-file |  |
| o c | treemacs-visit-node-close-treemacs |  |
| o h | treemacs-visit-node-horizontal-split |  |
| o o | treemacs-visit-node-no-split |  |
| o r | treemacs-visit-node-in-most-recently-used-window |  |
| o v | treemacs-visit-node-vertical-split |  |
| o x | treemacs-visit-node-in-external-application |  |
| t a | treemacs-filewatch-mode |  |
| t c | treemacs-indicate-top-scroll-mode |  |
| t d | treemacs-git-commit-diff-mode |  |
| t f | treemacs-follow-mode |  |
| t g | treemacs-git-mode |  |
| t h | treemacs-toggle-show-dotfiles |  |
| t i | treemacs-hide-gitignored-files-mode |  |
| t n | treemacs-indent-guide-mode |  |
| t v | treemacs-fringe-indicator-mode |  |
| t w | treemacs-toggle-fixed-width |  |
| y a | treemacs-copy-absolute-path-at-point |  |
| y f | treemacs-copy-file |  |

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
| DEL | delete-region |  |
| SPC | embark-select |  |
| C-SPC | mark |  |
| ! | shell-command |  |
| $ | eshell |  |
| & | async-shell-command |  |
| + | make-directory |  |
| < | insert-file |  |
| = | ediff-files |  |
| D | delete-directory |  |
| F | find-file-literally |  |
| I | embark-insert-relative-path |  |
| R | byte-recompile-directory |  |
| W | embark-save-relative-path |  |
| \ | embark-recentf-remove |  |
| b | byte-compile-file |  |
| c | copy-file |  |
| d | delete-file |  |
| e | eww-open-file |  |
| j | embark-dired-jump |  |
| l | load-file |  |
| m | chmod |  |
| r | rename-file |  |
| s | make-symbolic-link |  |
| x | embark-open-externally |  |
| v d | vc-delete-file |  |
| v i | vc-ignore |  |
| v r | vc-rename-file |  |
| < | insert-buffer |  |
| = | ediff-buffers |  |
| K | embark-kill-buffer-and-window |  |
| r | embark-rename-buffer |  |
| z | embark-bury-buffer |  |
| | | embark-shell-command-on-buffer |  |
| $ | ispell-word |  |
| ' | expand-abbrev |  |
| H | embark-toggle-highlight |  |
| \ | embark-history-remove |  |
| a | apropos |  |
| a | xref-find-apropos |  |
| d | embark-find-definition |  |
| e | pp-eval-expression |  |
| h | describe-symbol |  |
| h | display-local-help |  |
| n | embark-next-symbol |  |

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
| b | describe-bindings |  |
| c | describe-key-briefly |  |
| d | apropos-documentation |  |
| e | view-echo-area-messages |  |
| g | describe-gnu-project |  |
| h | view-hello-file |  |
| i | info |  |
| n | view-emacs-news |  |
| o | helpful-symbol |  |
| p | finder-by-keyword |  |

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
| C-c C-l | outline-hide-leaves |  |
| C-c C-n | outline-next-visible-heading |  |
| C-c C-o | outline-hide-other |  |
| C-c C-p | outline-previous-visible-heading |  |
| C-c C-q | outline-hide-sublevels |  |
| C-c C-s | outline-show-subtree |  |
| C-c C-t | outline-hide-body |  |
| C-c C-u | outline-up-heading |  |
| C-c C-v | outline-move-subtree-down |  |
| C-c M-o | outline-find-headings |  |
| C-c RET | outline-insert-heading |  |
| C-c TAB | outline-show-children |  |
| <backtab> | outline-cycle-buffer |  |
| d | my/git-repos-dired |  |
| g | my/git-repos-refresh |  |
| t | my/git-repos-treemacs |  |
| F | newsticker-treeview-prev-feed |  |
| G | newsticker-get-all-news |  |
| N | newsticker-treeview-next-new-or-immortal-item |  |
| O | newsticker-treeview-mark-list-items-old |  |
| P | newsticker-treeview-prev-new-or-immortal-item |  |
| S | newsticker-treeview-save-item |  |
| a | newsticker-add-url |  |
| b | newsticker-treeview-browse-url-item |  |
| c | newsticker-treeview-customize-current-feed |  |

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
| } | evil-forward-paragraph |  |
| C-6 | evil-switch-to-windows-last-buffer |  |
| C-] | evil-jump-to-tag |  |
| C-^ | evil-buffer |  |
| C-b | evil-scroll-page-up |  |
| C-d | evil-scroll-down |  |
| C-e | evil-scroll-line-down |  |
| C-f | evil-scroll-page-down |  |
| C-o | evil-jump-backward |  |
| C-v | evil-visual-block |  |
| C-w | | evil-window-set-width |  |
| C-y | evil-scroll-line-up |  |
| C-z | evil-emacs-state |  |
| RET | evil-ret |  |
| TAB | evil-jump-forward |  |
| [ ' | evil-previous-mark-line |  |
| [ ( | evil-previous-open-paren |  |
| [ [ | evil-backward-section-begin |  |
| [ ] | evil-backward-section-end |  |
| [ ` | evil-previous-mark |  |
| [ s | evil-prev-flyspell-error |  |
| [ { | evil-previous-open-brace |  |
| ] ' | evil-next-mark-line |  |
| ] ) | evil-next-close-paren |  |
| ] [ | evil-forward-section-end |  |
| ] ] | evil-forward-section-begin |  |
| ] ` | evil-next-mark |  |
| ] s | evil-next-flyspell-error |  |
| ] } | evil-next-close-brace |  |
| g # | evil-search-unbounded-word-backward |  |
| g $ | evil-end-of-visual-line |  |
| g * | evil-search-unbounded-word-forward |  |
| g 0 | evil-beginning-of-visual-line |  |
| g E | evil-backward-WORD-end |  |
| g M | evil-percentage-of-line |  |
| g N | evil-previous-match |  |
| g ^ | evil-first-non-blank-of-visual-line |  |
| g _ | evil-last-non-blank |  |
| g d | evil-goto-definition |  |
| g e | evil-backward-word-end |  |
| g j | evil-next-visual-line |  |
| g k | evil-previous-visual-line |  |
| g m | evil-middle-of-visual-line |  |
| g n | evil-next-match |  |
| g o | evil-goto-char |  |
| g v | evil-visual-restore |  |
| z + | evil-scroll-bottom-line-to-top |  |
| z - | zb^ |  |
| z . | zz^ |  |
| z H | evil-scroll-left |  |
| z L | evil-scroll-right |  |
| z ^ | evil-scroll-top-line-to-bottom |  |
| z b | evil-scroll-line-to-bottom |  |
| z h | evil-scroll-column-left |  |
| z l | evil-scroll-column-right |  |

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
| C-c [ | org-agenda-file-to-front |  |
| C-c \ | org-match-sparse-tree |  |
| C-c ] | org-remove-file |  |
| C-c ^ | org-sort |  |
| C-c ` | org-table-edit-field |  |
| C-c { | org-table-toggle-formula-debugger |  |
| C-c } | org-table-toggle-coordinate-overlays |  |
| C-c ~ | org-table-create-with-table.el |  |
| M-RET | org-meta-return |  |
| S-RET | org-table-copy-down |  |
| S-TAB | org-shifttab |  |
| M-<up> | org-metaup |  |
| S-<up> | org-shiftup |  |
| C-c " a | orgtbl-ascii-plot |  |
| C-c " g | org-plot/gnuplot |  |
| C-c C-* | org-list-make-subtree |  |
| C-c C-, | org-insert-structure-template |  |
| C-c C-^ | org-up-element |  |
| C-c C-_ | org-down-element |  |
| C-c C-a | org-attach |  |
| C-c C-b | org-backward-heading-same-level |  |
| C-c C-c | org-ctrl-c-ctrl-c |  |
| C-c C-d | org-deadline |  |
| C-c C-e | org-export-dispatch |  |
| C-c C-f | org-forward-heading-same-level |  |

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
| C-d | calc-pop |  |
| C-j | calc-over |  |
| C-y | calc-yank |  |
| M-% | calc-percent |  |
| RET | calc-enter |  |
| TAB | calc-roll-down |  |
| Y ? | calc-shift-Y-prefix-help |  |
| C-M-d | calc-pop-above |  |
| C-M-i | calc-roll-up |  |
| M-RET | calc-last-args-stub |  |

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
| M-n | occur-next |  |
| M-p | occur-prev |  |
| RET | occur-mode-goto-occurrence |  |

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
| i c | image-crop |  |
| i h | image-flip-horizontally |  |
| i o | image-save |  |
| i r | image-rotate |  |
| i v | image-flip-vertically |  |
| i x | image-cut |  |
| s 0 | image-transform-reset-to-initial |  |
| s b | image-transform-fit-both |  |
| s f | image-mode-fit-frame |  |
| s h | image-transform-fit-to-height |  |

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
| c | Info-copy-current-node-name |  |
| d | Info-directory |  |
| f | Info-follow-reference |  |
| g | Info-goto-node |  |
| h | Info-help |  |
| i | Info-index |  |
| l | Info-history-back |  |
| m | Info-menu |  |
| n | Info-next |  |
| p | Info-prev |  |

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
| S | vc-dir-search |  |
| U | vc-dir-unmark-all-files |  |
| V | vc-dir-root-next-action |  |
| d | vc-dir-delete-file |  |
| e | vc-dir-find-file |  |
| i | vc-register |  |
| l | vc-print-log |  |
| m | vc-dir-mark |  |
| n | vc-dir-next-line |  |
| o | vc-dir-find-file-other-window |  |
| p | vc-dir-previous-line |  |
| u | vc-dir-unmark |  |
| v | vc-next-action |  |
| x | vc-dir-hide-up-to-date |  |
| * % | vc-dir-mark-by-regexp |  |

## 29. Package manager (package-menu-mode)

| Key | Command | What it does |
|---|---|---|
| ( | package-menu-toggle-hiding |  |
| ? | package-menu-describe-package |  |
| H | package-menu-hide-package |  |
| U | package-menu-mark-upgrades |  |
| b | package-report-bug |  |
| d | package-menu-mark-delete |  |
| h | package-menu-quick-help |  |
| i | package-menu-mark-install |  |
| u | package-menu-mark-unmark |  |
| w | package-browse-url |  |
| x | package-menu-execute |  |
| { | tabulated-list-narrow-current-column |  |
| } | tabulated-list-widen-current-column |  |
| ~ | package-menu-mark-obsolete-for-deletion |  |
| / / | package-menu-clear-filter |  |
| / N | package-menu-filter-by-name-or-description |  |
| / a | package-menu-filter-by-archive |  |
| / d | package-menu-filter-by-description |  |
| / k | package-menu-filter-by-keyword |  |
| / m | package-menu-filter-marked |  |
| / n | package-menu-filter-by-name |  |
| / s | package-menu-filter-by-status |  |
| / u | package-menu-filter-upgradable |  |
| / v | package-menu-filter-by-version |  |
| DEL | package-menu-backup-unmark |  |
| M-<left> | tabulated-list-previous-column |  |
| M-<right> | tabulated-list-next-column |  |

## 30. Archive / Tar mode

| Key | Command | What it does |
|---|---|---|
| C | archive-copy-file |  |
| E | archive-extract-other-window |  |
| G | archive-chgrp-entry |  |
| M | archive-chmod-entry |  |
| O | archive-chown-entry |  |
| a | archive-alternate-display |  |
| d | archive-flag-deleted |  |
| m | archive-mark |  |
| n | archive-next-line |  |
| p | archive-previous-line |  |
| r | archive-rename-entry |  |
| u | archive-unflag |  |
| v | archive-view |  |
| x | archive-expunge |  |
| DEL | archive-unflag-backwards |  |
| RET | archive-extract |  |
| M-DEL | archive-unmark-all-files |  |
| C | tar-copy |  |
| E | tar-extract-other-window |  |
| G | tar-chgrp-entry |  |
| I | tar-new-entry |  |
| M | tar-chmod-entry |  |
| O | tar-chown-entry |  |
| R | tar-rename-entry |  |
| d | tar-flag-deleted |  |
| n | tar-next-line |  |
| p | tar-previous-line |  |
| u | tar-unflag |  |
| v | tar-view |  |
| w | woman-tar-extract-file |  |
| x | tar-expunge |  |
| DEL | tar-unflag-backwards |  |
| RET | tar-extract |  |

## 31. Shell, Comint & Term buffers

| Key | Command | What it does |
|---|---|---|
| C-d | comint-delchar-or-maybe-eof |  |
| M-n | comint-next-input |  |
| M-p | comint-previous-input |  |
| M-r | comint-history-isearch-backward-regexp |  |
| RET | comint-send-input |  |
| C-M-l | comint-show-output |  |
| C-c . | comint-insert-previous-argument |  |
| C-c C-\ | comint-quit-subjob |  |
| C-c C-a | comint-bol-or-process-mark |  |
| C-c C-c | comint-interrupt-subjob |  |
| C-c C-d | comint-send-eof |  |
| C-c C-e | comint-show-maximum-output |  |
| C-c C-l | comint-dynamic-list-input-ring |  |
| C-c C-n | comint-next-prompt |  |
| C-c C-o | comint-delete-output |  |
| C-c C-p | comint-previous-prompt |  |
| C-c C-s | comint-write-output |  |
| C-c C-u | comint-kill-input |  |
| C-c C-w | backward-kill-word |  |
| C-c C-x | comint-get-next-from-history |  |
| C-c C-z | comint-stop-subjob |  |
| C-c M-o | comint-clear-buffer |  |
| C-c M-r | comint-previous-matching-input-from-input |  |
| C-c M-s | comint-next-matching-input-from-input |  |
| C-c RET | comint-copy-old-input |  |
| C-c SPC | comint-accumulate |  |
| <delete> | delete-forward-char |  |
| C-x <up> | comint-complete-input-ring |  |
| M-? | comint-dynamic-list-filename-completions |  |
| TAB | completion-at-point |  |
| M-RET | shell-resync-dirs |  |
| C-c C-b | shell-backward-command |  |
| C-c C-f | shell-forward-command |  |
| C-x n d | shell-narrow-to-prompt |  |
| C-d | term-delchar-or-maybe-eof |  |

## 32. Leftover corners (tabs, rectangle-mark, stray prefixes)

| Key | Command | What it does |
|---|---|---|
| 0 | tab-close |  |
| 1 | tab-close-other |  |
| 2 | tab-new |  |
| G | tab-group |  |
| M | tab-move-to |  |
| N | tab-new-to |  |
| O | tab-previous |  |
| b | switch-to-buffer-other-tab |  |
| d | dired-other-tab |  |
| f | find-file-other-tab |  |
| m | tab-move |  |
| n | tab-duplicate |  |
| o | tab-next |  |
| p | project-other-tab-command |  |
| r | tab-rename |  |
| t | other-tab-prefix |  |
| u | tab-undo |  |
| C-r | find-file-read-only-other-tab |  |
| RET | tab-switch |  |
| ^ f | tab-detach |  |
| C-t | string-rectangle |  |
| ' | abbrev-prefix-mark |  |
| ( | insert-parentheses |  |
| ) | move-past-close-and-reindent |  |
| / | dabbrev-expand |  |
