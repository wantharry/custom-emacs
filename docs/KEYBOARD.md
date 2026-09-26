# Learning Emacs: keys and what they fire

A working guide to the keyboard, for learning Emacs by using it. Every key in the
tables below is **checked against this Emacs build** by `tests/ert/keybindings.el`
(it reads this file), so the tables cannot silently be wrong.

> New to pressing Control and Meta, or want to get faster? Read [TYPING.md](TYPING.md): keyboard
> setup, which finger presses what, holding Control through a chord, the `Esc` method, and a
> four-week practice plan.

## How to read the notation

| Written | Means |
|---|---|
| `C-x` | hold **Ctrl**, press `x` |
| `M-x` | hold **Alt** (Meta), press `x`. If Alt is taken by your system, press `ESC` then `x` |
| `C-M-f` | Ctrl and Alt together, then `f` |
| `S-` / `s-` | Shift / Super (Windows key) |
| `RET` `SPC` `TAB` `DEL` `ESC` | Enter, Space, Tab, **Backspace**, Escape |
| `C-x C-f` | a **sequence**: press `C-x`, release, then `C-f` |
| `<f3>` | the F3 key; `<left>` an arrow key |

Words you will see: **point** is your cursor, **mark** is the other end of the selected
**region**, a **buffer** is the text you are editing, a **window** is a pane showing a
buffer, and a **frame** is what other programs call a window. **Kill** means cut,
**yank** means paste, and the **kill ring** is the clipboard history.

## The five keys to survive

| Key | Command | What it does |
|---|---|---|
| `C-g` | `keyboard-quit` | **Cancel whatever is happening.** Press it any time you are stuck |
| `C-x C-c` | `save-buffers-kill-terminal` | Quit Emacs (asks about unsaved files) |
| `C-x C-f` | `find-file` | Open a file (or create one) |
| `C-x C-s` | `save-buffer` | Save |
| `C-/` | `undo` | Undo (repeat to keep undoing) |

## Every file opens read-only

This configuration opens **every file read-only**, so a slip while learning shortcuts
can never type into a file. You will see `Buffer is read-only` in the bottom line if
you try, and the file on disk is untouched.

| To do this | Type |
|---|---|
| **Allow editing** the current buffer | `C-c e e` (or `M-x allow-editing`) |
| Save your changes | `C-x C-s` |
| **Lock it again** | `C-c e l` (or `M-x stop-editing`) |

The shortcuts are deliberate **three-key chords**, so a slipped key cannot unlock a file:
`C-c e e` to **e**dit and `C-c e l` to **l**ock (`C-c` is the prefix Emacs reserves for
your own keys, and `which-key` lists the choices after `C-c e`). The standard single
shortcut, `C-x C-q`, only prints a reminder here.
Notes:

- It applies to every file you open, including new ones. To **create** a file, open it
  (`C-x C-f name`), then `C-c e e`.
- Movement, searching, selecting and copying (`C-SPC`, `M-w`) all still work; only
  changes are blocked.
- `stop-editing` warns if the buffer has unsaved changes.
- Buffers that are not files (`*scratch*`, the minibuffer) are still editable.
- In **Dired**, `C-x C-q` still starts wdired (renaming files by editing their names);
  nothing changes on disk until you confirm with `C-c C-c`.
- Things that must edit a file for you, such as `M-x eglot-rename` or `eglot-format`, will
  report `Buffer is read-only` until you `M-x allow-editing`.

`M-x` (`execute-extended-command`) runs **any** command by name. If you forget a key,
`M-x` plus the command name always works.

## What "fires" when you press a key

Pressing a key looks it up in the active keymaps, in order: minor modes (for example
Evil), then the current major mode (for example Dired), then the global map. The
first match runs.

| See what a key does | Key | Command |
|---|---|---|
| Recent keys **and the commands they fired** (last 300) | `C-h l` | `view-lossage` |
| What does this key do? (full help, and which map it came from) | `C-h k` | `describe-key` |
| Same, one line in the echo area | `C-h c` | `describe-key-briefly` |
| Which keys run this command? | `C-h w` | `where-is` |
| Everything bound in this buffer | `C-h b` | `describe-bindings` |
| Explain the current modes and their keys | `C-h m` | `describe-mode` |
| Recent messages Emacs printed | `C-h e` | `view-echo-area-messages` |

Two habits that teach the most: press `C-h l` after a confusing moment to see exactly
which keys you pressed, and type a **prefix then `C-h`** (for example `C-x C-h`) to
list every key that starts with that prefix. This configuration also enables
`which-key`: pause after a prefix such as `C-x` and a list of what can follow appears.

## Moving around

### By character, word, line

| Key | Command | Moves |
|---|---|---|
| `C-f` | `forward-char` | forward one character |
| `C-b` | `backward-char` | back one character |
| `C-n` | `next-line` | down one line |
| `C-p` | `previous-line` | up one line |
| `M-f` | `forward-word` | forward one word |
| `M-b` | `backward-word` | back one word |
| `C-a` | `move-beginning-of-line` | start of the line |
| `C-e` | `move-end-of-line` | end of the line |
| `M-m` | `back-to-indentation` | first non-blank character of the line |

### By sentence, paragraph, function

| Key | Command | Moves |
|---|---|---|
| `M-a` | `backward-sentence` | start of the sentence |
| `M-e` | `forward-sentence` | end of the sentence |
| `M-{` | `backward-paragraph` | start of the paragraph |
| `M-}` | `forward-paragraph` | end of the paragraph |
| `C-M-a` | `beginning-of-defun` | start of the function |
| `C-M-e` | `end-of-defun` | end of the function |
| `C-M-f` | `forward-sexp` | over the next balanced expression |
| `C-M-b` | `backward-sexp` | back over a balanced expression |
| `C-M-u` | `backward-up-list` | out to the enclosing parenthesis |
| `C-M-d` | `down-list` | into the next parenthesis |

### By screen and buffer, and jumping

| Key | Command | Moves |
|---|---|---|
| `C-v` | `scroll-up-command` | down one screen |
| `M-v` | `scroll-down-command` | up one screen |
| `C-l` | `recenter-top-bottom` | cycle the cursor line: middle, top, bottom |
| `M-<` | `beginning-of-buffer` | start of the buffer |
| `M->` | `end-of-buffer` | end of the buffer |
| `M-g g` | `goto-line` | a line number |
| `M-g c` | `goto-char` | a character position |
| `M-g TAB` | `move-to-column` | a column |
| `M-g n` | `next-error` | next compiler or grep match |
| `M-g p` | `previous-error` | previous match |
| `C-x C-x` | `exchange-point-and-mark` | swap cursor and the other end of the selection |

Most movement commands take a **count**: `C-u 5 C-n` (or `M-5 C-n`) moves down five
lines. `C-u` is `universal-argument`; `M-0` to `M-9` are `digit-argument`.

## Selecting, cutting, pasting, undoing

| Key | Command | What it does |
|---|---|---|
| `C-SPC` | `set-mark-command` | start selecting (move to extend it) |
| `C-x h` | `mark-whole-buffer` | select everything |
| `M-h` | `mark-paragraph` | select the paragraph |
| `M-@` | `mark-word` | select the next word |
| `C-w` | `kill-region` | **cut** the selection |
| `M-w` | `kill-ring-save` | **copy** the selection |
| `C-y` | `yank` | **paste** |
| `M-y` | `yank-pop` | right after a paste: replace it with older clipboard entries |
| `C-k` | `kill-line` | cut from the cursor to the end of the line |
| `M-d` | `kill-word` | cut the next word |
| `M-DEL` | `backward-kill-word` | cut the previous word |
| `C-M-k` | `kill-sexp` | cut a balanced expression |
| `M-z` | `zap-to-char` | cut up to a character you type |
| `C-d` | `delete-char` | delete the character under the cursor |
| `DEL` | `delete-backward-char` | delete the character before the cursor |
| `C-/` | `undo` | undo |
| `C-_` | `undo` | undo (works in terminals too) |
| `C-x u` | `undo` | undo |
| `C-?` | `undo-redo` | redo an undo |

Killing with `C-k` twice in a row accumulates into one clipboard entry.

## Editing text

| Key | Command | What it does |
|---|---|---|
| `RET` | `newline` | new line |
| `C-j` | `electric-newline-and-maybe-indent` | new line and indent |
| `C-o` | `open-line` | insert a line break, keep the cursor in place |
| `C-x C-o` | `delete-blank-lines` | collapse blank lines |
| `M-\` | `delete-horizontal-space` | remove spaces around the cursor |
| `M-SPC` | `cycle-spacing` | collapse spaces to one, then none, then restore |
| `M-^` | `delete-indentation` | join this line to the previous one |
| `TAB` | `indent-for-tab-command` | indent the line (or complete) |
| `C-M-\` | `indent-region` | indent the selection |
| `C-t` | `transpose-chars` | swap two characters |
| `M-t` | `transpose-words` | swap two words |
| `C-x C-t` | `transpose-lines` | swap two lines |
| `C-M-t` | `transpose-sexps` | swap two expressions |
| `M-u` | `upcase-word` | UPPERCASE the word |
| `M-l` | `downcase-word` | lowercase the word |
| `M-c` | `capitalize-word` | Capitalize the word |
| `M-q` | `fill-paragraph` | re-wrap the paragraph to the fill column (80) |
| `M-;` | `comment-dwim` | comment or uncomment the line or selection |
| `C-x C-;` | `comment-line` | comment or uncomment the current line |
| `C-q` | `quoted-insert` | insert the next key literally |
| `C-x 8 RET` | `insert-char` | insert a Unicode character by name |

## Rectangles, registers, bookmarks, macros

| Key | Command | What it does |
|---|---|---|
| `C-x r k` | `kill-rectangle` | cut a rectangular block (mark and cursor are opposite corners) |
| `C-x r d` | `delete-rectangle` | delete the block |
| `C-x r y` | `yank-rectangle` | paste the block |
| `C-x r t` | `string-rectangle` | replace the block with typed text on every line |
| `C-x r o` | `open-rectangle` | insert blank space in the block |
| `C-x r s` | `copy-to-register` | copy the selection into a named register |
| `C-x r i` | `insert-register` | paste a register |
| `C-x r SPC` | `point-to-register` | remember this position |
| `C-x r j` | `jump-to-register` | jump back to it |
| `C-x r m` | `bookmark-set` | bookmark this place (saved across sessions) |
| `C-x r b` | `bookmark-jump` | jump to a bookmark |
| `C-x r l` | `bookmark-bmenu-list` | list bookmarks |
| `<f3>` | `kmacro-start-macro-or-insert-counter` | start recording a keyboard macro |
| `<f4>` | `kmacro-end-or-call-macro` | stop recording; press again to replay it |
| `C-x (` | `kmacro-start-macro` | start recording |
| `C-x )` | `kmacro-end-macro` | stop recording |
| `C-x e` | `kmacro-end-and-call-macro` | replay the last macro |
| `C-x z` | `repeat` | repeat the previous command (then `z` again to keep repeating) |

## Searching and replacing

| Key | Command | What it does |
|---|---|---|
| `C-s` | `isearch-forward` | incremental search forward |
| `C-r` | `isearch-backward` | incremental search backward |
| `C-M-s` | `isearch-forward-regexp` | regular-expression search forward |
| `C-M-r` | `isearch-backward-regexp` | regular-expression search backward |
| `M-s .` | `isearch-forward-symbol-at-point` | search for the symbol at the cursor |
| `M-s w` | `isearch-forward-word` | search for whole words |
| `M-s _` | `isearch-forward-symbol` | search for whole symbols |
| `M-s o` | `occur` | list every matching line in a new buffer (`RET` jumps to it) |
| `M-s h r` | `highlight-regexp` | highlight matches |
| `M-%` | `query-replace` | replace, asking each time |
| `C-M-%` | `query-replace-regexp` | regexp replace, asking each time |

While replacing: `y` replace this one, `n` skip, `!` replace all the rest, `q` quit.

### Keys inside an incremental search

<!-- keymap: isearch-mode-map -->
| Key | Command | What it does |
|---|---|---|
| `C-s` | `isearch-repeat-forward` | next match |
| `C-r` | `isearch-repeat-backward` | previous match |
| `RET` | `isearch-exit` | stop here, keep the cursor at the match |
| `C-g` | `isearch-abort` | cancel and return to where you started |
| `DEL` | `isearch-delete-char` | delete the last search character |
| `C-w` | `isearch-yank-word-or-char` | add the next word at the cursor to the search |
| `C-y` | `isearch-yank-kill` | add the clipboard text to the search |
| `M-e` | `isearch-edit-string` | edit the search string |
| `M-c` | `isearch-toggle-case-fold` | toggle case sensitivity |
| `M-r` | `isearch-toggle-regexp` | toggle regexp mode |
| `M-p` | `isearch-ring-retreat` | earlier search from history |
| `M-n` | `isearch-ring-advance` | later search from history |
| `M-s o` | `isearch-occur` | list all matches |
| `M-%` | `isearch-query-replace` | replace starting from this search |

## Files, buffers, windows, tabs

<!-- keymap: global -->
| Key | Command | What it does |
|---|---|---|
| `C-x C-f` | `find-file` | open a file |
| `C-x C-s` | `save-buffer` | save |
| `C-x C-w` | `write-file` | save as |
| `C-x s` | `save-some-buffers` | offer to save every modified buffer |
| `C-x C-v` | `find-alternate-file` | replace this buffer with another file |
| `C-x C-r` | `find-file-read-only` | open read-only |
| `C-x i` | `insert-file` | insert a file's contents here |
| `C-x C-q` | `my/read-only-hint` | **this config:** only reminds you to type `M-x allow-editing` (see below) |
| `C-x b` | `switch-to-buffer` | switch buffer by name |
| `C-x k` | `kill-buffer` | close a buffer |
| `C-x C-b` | `ibuffer` | list buffers (this config uses ibuffer) |
| `C-x <left>` | `previous-buffer` | previous buffer |
| `C-x <right>` | `next-buffer` | next buffer |
| `C-c r` | `recentf-open` | **this config:** open a recent file |
| `C-c h` | `my/start` | **this config:** the start screen: last 5 files, folders and projects, each expandable ([START-SCREEN.md](START-SCREEN.md)) |
| `C-c e e` | `allow-editing` | **this config:** make this buffer editable |
| `C-c e l` | `stop-editing` | **this config:** lock this buffer read-only again |
| `C-x 0` | `delete-window` | close this window |
| `C-x 1` | `delete-other-windows` | keep only this window |
| `C-x 2` | `split-window-below` | split top and bottom |
| `C-x 3` | `split-window-right` | split left and right |
| `C-x o` | `other-window` | move to the next window |
| `M-o` | `other-window` | **this config:** same, one keystroke |
| `C-x ^` | `enlarge-window` | taller |
| `C-x }` | `enlarge-window-horizontally` | wider |
| `C-x {` | `shrink-window-horizontally` | narrower |
| `C-x +` | `balance-windows` | make all windows equal |
| `C-x 4 f` | `find-file-other-window` | open a file in another window |
| `C-x 4 b` | `switch-to-buffer-other-window` | show a buffer in another window |
| `C-x 4 0` | `kill-buffer-and-window` | close the buffer and its window |
| `C-x 5 2` | `make-frame-command` | new frame (OS window) |
| `C-x 5 0` | `delete-frame` | close this frame |
| `C-x t 2` | `tab-new` | new tab |
| `C-x t o` | `tab-next` | next tab |
| `C-x t 0` | `tab-close` | close this tab |
| `C-x t b` | `switch-to-buffer-other-tab` | show a buffer in another tab |

## Running commands and evaluating code

| Key | Command | What it does |
|---|---|---|
| `M-x` | `execute-extended-command` | run any command by name |
| `M-:` | `eval-expression` | evaluate one Lisp expression |
| `C-x C-e` | `eval-last-sexp` | evaluate the expression before the cursor |
| `M-!` | `shell-command` | run a shell command |
| `M-&` | `async-shell-command` | run one in the background |
| `C-x ESC ESC` | `repeat-complex-command` | edit and re-run the last command with arguments |
| `C-u` | `universal-argument` | give the next command a count or variant |

## Help (the most valuable section)

| Key | Command | What it does |
|---|---|---|
| `C-h t` | `help-with-tutorial` | **the built-in interactive tutorial. Do it first** |
| `C-h ?` | `help-for-help` | list of every help key |
| `C-h k` | `describe-key` | what does this key do? |
| `C-h c` | `describe-key-briefly` | one-line version |
| `C-h f` | `describe-function` | describe a command or function |
| `C-h v` | `describe-variable` | describe a setting |
| `C-h o` | `describe-symbol` | describe anything |
| `C-h x` | `describe-command` | describe a command |
| `C-h m` | `describe-mode` | current modes and their keys |
| `C-h b` | `describe-bindings` | every key currently bound |
| `C-h w` | `where-is` | which keys run a command |
| `C-h a` | `apropos-command` | find commands by keyword |
| `C-h d` | `apropos-documentation` | find by what the docs say |
| `C-h l` | `view-lossage` | the last keys you pressed and what they ran |
| `C-h e` | `view-echo-area-messages` | recent messages |
| `C-h i` | `info` | the Info manual reader |
| `C-h r` | `info-emacs-manual` | the Emacs manual |

Inside Info: `SPC` next page, `DEL` previous, `n`/`p` next/previous node, `u` up, `l` back,
`q` quit, `s` search, `m` follow a menu item.

## Programming

For finding files, searching a project and clicking through Java code, see [NAVIGATING-CODE.md](NAVIGATING-CODE.md).

| Key | Command | What it does |
|---|---|---|
| `M-.` | `xref-find-definitions` | jump to a definition |
| `M-,` | `xref-go-back` | jump back |
| `M-?` | `xref-find-references` | find uses |
| `C-M-.` | `xref-find-apropos` | search for symbols by pattern |
| `M-/` | `dabbrev-expand` | complete the word from text already in your buffers |
| `C-M-i` | `complete-symbol` | complete the symbol at the cursor |
| `C-x p f` | `project-find-file` | open a file in the current project |
| `C-c f f` | `my/ff-find-file` | **this config:** instant fuzzy file finder (project, or whole disk outside one) |
| `C-c f g` | `my/ff-find-file-global` | **this config:** the same over the whole disk |
| `C-c f r` | `my/ff-reindex` | **this config:** rebuild the whole-disk file index |
| `C-x p g` | `project-find-regexp` | search the whole project |
| `C-x p p` | `project-switch-project` | switch project |
| `C-x p b` | `project-switch-to-buffer` | a buffer of this project |
| `C-x p d` | `project-find-dir` | open a project directory in Dired |
| `C-x p c` | `project-compile` | compile the project |
| `C-x p !` | `project-shell-command` | run a shell command in the project root |
| `C-x p v` | `project-vc-dir` | version-control status of the project |
| `C-x v d` | `vc-dir` | version-control status of a directory |
| `C-x v =` | `vc-diff` | diff this file against the last commit |
| `C-x v v` | `vc-next-action` | the next sensible step (add, commit, ...) |
| `C-x v l` | `vc-print-log` | history of this file |
| `C-x v g` | `vc-annotate` | who wrote each line |
| `C-x v D` | `vc-root-diff` | diff the whole repository |
| `C-x v P` | `vc-push` | push |
| `C-x v +` | `vc-update` | pull |

In Emacs Lisp buffers, `C-M-x` (`eval-defun`) evaluates the whole function under the
cursor, so you can change how Emacs behaves and see it at once:

<!-- keymap: emacs-lisp-mode-map -->
| Key | Command | What it does |
|---|---|---|
| `C-M-x` | `eval-defun` | evaluate the function around the cursor |

`M-x eglot` starts the language-server client for the current buffer (needs a language
server installed). It has no key by default.

## Dired: the directory editor

Open it with `C-x d` (`dired`) and give a directory, or `C-x C-j` (`dired-jump`) to
land on the current file in its directory. In Dired the buffer *is* the file listing.
You **mark** files, then run an operation on the marked ones (or on the file under the
cursor if none are marked).

### Get around and open

<!-- keymap: dired-mode-map -->
| Key | Command | What it does |
|---|---|---|
| `n` | `dired-next-line` | next line |
| `p` | `dired-previous-line` | previous line |
| `<` | `dired-prev-dirline` | previous directory in the list |
| `>` | `dired-next-dirline` | next directory in the list |
| `^` | `dired-up-directory` | go up to the parent directory |
| `RET` | `dired-find-file` | open the file or enter the directory |
| `f` | `dired-find-file` | same as `RET` |
| `e` | `dired-find-file` | same as `RET` |
| `a` | `dired-find-alternate-file` | open, replacing this Dired buffer |
| `o` | `dired-find-file-other-window` | open in another window |
| `C-o` | `dired-display-file` | show in another window without moving there |
| `v` | `dired-view-file` | view read-only (`q` to leave) |
| `j` | `dired-goto-file` | jump to a file by name |
| `g` | `revert-buffer` | refresh the listing |
| `q` | `quit-window` | close Dired |
| `?` | `dired-summary` | one-line reminder of the main keys |
| `(` | `dired-hide-details-mode` | hide or show permissions, owners, dates |
| `s` | `dired-sort-toggle-or-edit` | toggle sorting by name or date |
| `i` | `dired-maybe-insert-subdir` | list a subdirectory inside this buffer |
| `$` | `dired-hide-subdir` | hide or show a subdirectory |
| `w` | `dired-copy-filename-as-kill` | copy the file name (`0 w` full path) |
| `=` | `dired-diff` | diff this file against another |

### Mark and unmark

| Key | Command | What it does |
|---|---|---|
| `m` | `dired-mark` | mark the file (`*`) |
| `u` | `dired-unmark` | unmark it |
| `DEL` | `dired-unmark-backward` | unmark the previous one |
| `U` | `dired-unmark-all-marks` | remove all marks |
| `t` | `dired-toggle-marks` | invert the marks |
| `d` | `dired-flag-file-deletion` | flag for deletion (`D`) |
| `x` | `dired-do-flagged-delete` | actually delete everything flagged |
| `* /` | `dired-mark-directories` | mark all directories |
| `* *` | `dired-mark-executables` | mark executable files |
| `* @` | `dired-mark-symlinks` | mark symbolic links |
| `* s` | `dired-mark-subdir-files` | mark every file in this subdirectory |
| `* c` | `dired-change-marks` | change one kind of mark into another |
| `% m` | `dired-mark-files-regexp` | mark files whose names match a regexp |
| `% g` | `dired-mark-files-containing-regexp` | mark files whose **contents** match |
| `% d` | `dired-flag-files-regexp` | flag matching names for deletion |
| `M-}` | `dired-next-marked-file` | jump to the next marked file |
| `M-{` | `dired-prev-marked-file` | jump to the previous marked file |

### Act on files (marked ones, or the one under the cursor)

| Key | Command | What it does |
|---|---|---|
| `C` | `dired-do-copy` | copy (asks for the destination) |
| `R` | `dired-do-rename` | rename or move |
| `D` | `dired-do-delete` | delete now (asks first) |
| `+` | `dired-create-directory` | make a directory |
| `S` | `dired-do-symlink` | make symbolic links |
| `H` | `dired-do-hardlink` | make hard links |
| `Y` | `dired-do-relsymlink` | make relative symbolic links |
| `M` | `dired-do-chmod` | change permissions |
| `O` | `dired-do-chown` | change owner |
| `G` | `dired-do-chgrp` | change group |
| `T` | `dired-do-touch` | update the timestamp |
| `Z` | `dired-do-compress` | compress or uncompress |
| `!` | `dired-do-shell-command` | run a shell command on the files (`*` stands for the file names) |
| `&` | `dired-do-async-shell-command` | the same in the background |
| `A` | `dired-do-find-regexp` | search inside the marked files |
| `Q` | `dired-do-find-regexp-and-replace` | search and replace inside them |
| `B` | `dired-do-byte-compile` | byte-compile Lisp files |
| `L` | `dired-do-load` | load Lisp files |
| `k` | `dired-do-kill-lines` | hide lines from the listing (does not delete files) |
| `% R` | `dired-do-rename-regexp` | rename files by regexp (`\1` for groups) |
| `% C` | `dired-do-copy-regexp` | copy files with regexp renaming |
| `% u` | `dired-upcase` | upper-case the file names |
| `% l` | `dired-downcase` | lower-case the file names |

### Edit file names like text

`C-x C-q` (`dired-toggle-read-only`) turns the listing into an ordinary editable
buffer (**wdired**). Rename files by editing their names with normal editing keys
(including search and replace and rectangles), then:

<!-- keymap: wdired-mode-map -->
| Key | Command | What it does |
|---|---|---|
| `C-c C-c` | `wdired-finish-edit` | apply all the renames |
| `C-c ESC` | `wdired-abort-changes` | discard them |

### Typical Dired recipes

- **Delete files:** move to each, press `d`, then `x` and confirm. Or mark with `m`
  and press `D`.
- **Copy several files:** `m` each one, `C`, type the destination directory.
- **Rename many files:** `C-x C-q`, edit the names, `C-c C-c`. Or `% R` with a regexp.
- **Everything of one type:** `% m` and a regexp such as `\.pdf$`, then act on them.
- **Find a file by name across folders:** `M-x find-name-dired`.
- **Run a command on files:** mark them, `!`, for example `chmod +x *`.

## The buffer list (ibuffer)

`C-x C-b` opens it in this config.

<!-- keymap: ibuffer-mode-map -->
| Key | Command | What it does |
|---|---|---|
| `RET` | `ibuffer-visit-buffer` | open the buffer |
| `o` | `ibuffer-visit-buffer-other-window` | open it in another window |
| `m` | `ibuffer-mark-forward` | mark |
| `u` | `ibuffer-unmark-forward` | unmark |
| `d` | `ibuffer-mark-for-delete` | flag for closing |
| `x` | `ibuffer-do-kill-on-deletion-marks` | close every flagged buffer |
| `D` | `ibuffer-do-delete` | close the marked buffers |
| `S` | `ibuffer-do-save` | save the marked buffers |
| `g` | `ibuffer-update` | refresh |
| `,` | `ibuffer-toggle-sorting-mode` | cycle the sort order |
| `q` | `quit-window` | leave |

## Minibuffer and completion

The minibuffer is the bar at the bottom where commands ask for input.

<!-- keymap: minibuffer-local-map -->
| Key | Command | What it does |
|---|---|---|
| `RET` | `exit-minibuffer` | accept |
| `M-p` | `previous-history-element` | earlier input from history |
| `M-n` | `next-history-element` | later input |
| `M-r` | `previous-matching-history-element` | search the history |
| `C-g` | `minibuffer-keyboard-quit` | cancel |

This configuration turns on a vertical completion list (`fido-vertical-mode`):
candidates appear under the prompt, you keep typing to narrow them, `TAB` completes,
and `C-n` / `C-p` (or the arrows) choose. Matching is flexible and ignores case, so
`fbuf` can find `find-buffer-file`. An inline suggestion also appears as you type in
programming buffers (`completion-preview-mode`); `TAB` accepts it.

## Evil: vi keys (optional)

Press `C-c v` (`my/toggle-evil`) to turn vi-style editing on or off. The first time it
loads Evil (and offers to install it if missing). While on, you are in one of these
**states**, shown in the mode line:

| State | Meaning |
|---|---|
| Normal | keys are commands (the default; `ESC` returns here) |
| Insert | keys type text (`i`, `a`, `o`, ...) |
| Visual | select text (`v`, `V`) |

Your Emacs keys such as `C-x C-f`, `M-x` and `C-c v` still work in Normal state, so you
can always turn Evil off again with `C-c v`.

<!-- keymap: evil-normal -->
| Key | Command | What it does |
|---|---|---|
| `h` | `evil-backward-char` | left |
| `j` | `evil-next-line` | down |
| `k` | `evil-previous-line` | up |
| `l` | `evil-forward-char` | right |
| `w` | `evil-forward-word-begin` | next word |
| `b` | `evil-backward-word-begin` | previous word |
| `e` | `evil-forward-word-end` | end of word |
| `0` | `evil-beginning-of-line` | start of line |
| `$` | `evil-end-of-line` | end of line |
| `g g` | `evil-goto-first-line` | top of the file |
| `G` | `evil-goto-line` | bottom of the file (or `12G` for line 12) |
| `i` | `evil-insert` | insert before the cursor |
| `a` | `evil-append` | insert after the cursor |
| `o` | `evil-open-below` | new line below, insert |
| `O` | `evil-open-above` | new line above, insert |
| `x` | `evil-delete-char` | delete the character |
| `d` | `evil-delete` | delete (then a motion: `dw` a word, `dd` a line) |
| `c` | `evil-change` | delete and insert (`cw`, `cc`) |
| `y` | `evil-yank` | copy (then a motion: `yw`, `yy`) |
| `p` | `evil-paste-after` | paste after |
| `P` | `evil-paste-before` | paste before |
| `u` | `evil-undo` | undo |
| `C-r` | `evil-redo` | redo |
| `.` | `evil-repeat` | repeat the last change |
| `v` | `evil-visual-char` | select characters |
| `V` | `evil-visual-line` | select lines |
| `/` | `evil-search-forward` | search forward |
| `n` | `evil-search-next` | next match |
| `N` | `evil-search-previous` | previous match |
| `:` | `evil-ex` | the `:` command line (`:w`, `:q`, `:%s/a/b/g`) |

## Java, Rust and other languages (Eglot)

Open a file, then `M-x eglot` starts the language server (`rust-analyzer` for Rust,
`jdtls` for Java). After that the keys in **Programming** above (`M-.`, `M-,`, `M-?`,
`C-M-i`) work through the server. Eglot's own commands have no default keys, so run them
with `M-x`:

| Run | What it does |
|---|---|
| `M-x eglot` | start the server for this project |
| `M-x eglot-shutdown` | stop it and free its memory |
| `M-x eglot-rename` | rename a symbol everywhere |
| `M-x eglot-code-actions` | quick fixes and refactorings at the cursor |
| `M-x eglot-format` | format the buffer with the server |
| `M-x eglot-find-implementation` | jump to an implementation |
| `M-x flymake-show-buffer-diagnostics` | list the errors and warnings |

See [LANGUAGES.md](LANGUAGES.md) for costs and setup.

## A learning path

1. **Day 1:** `C-h t` (the tutorial, about 30 minutes). Get comfortable with
   `C-g`, `C-x C-f`, `C-x C-s`, `C-x C-c`, `C-/`, and the cursor keys `C-f C-b C-n C-p`.
2. **Week 1:** learn the word and line movements (`M-f M-b C-a C-e`), cut and paste
   (`C-k C-w M-w C-y`), and search (`C-s C-r`). Turn on the habit of `C-h k`.
3. **Week 2:** windows and buffers (`C-x 2 C-x 3 C-x o C-x 1 C-x b`), Dired (`C-x d`,
   then `m d x C R`), and `M-x`.
4. **Week 3 onward:** macros (`<f3> ... <f4>`), rectangles, registers, project keys
   (`C-x p f`), `M-.` to jump to definitions, and version control (`C-x v`).

Press `C-h l` whenever something surprising happens. It shows what you pressed and
what fired, which is the fastest way to learn.
