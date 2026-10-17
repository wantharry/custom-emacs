# Quick reference: two printable pages

A condensed, frequency-ordered cheat sheet --- the most-used commands on one page, finger
placement on the other. [KEYBOARD.md](KEYBOARD.md) is the full, exhaustive reference and
[TYPING.md](TYPING.md) is the fuller how-to-press-them guide with a four-week learning plan;
this page is deliberately the opposite of both: short enough to print and keep next to the
keyboard. Every key below is checked against this project's own built Emacs by
`tests/ert/keybindings.el`, the same as [KEYBOARD.md](KEYBOARD.md).

## Page 1 --- most-used commands, by frequency

### Cursor movement (used constantly)

<!-- keymap: global -->
| Key | Command | What it does |
|---|---|---|
| `C-f` | `forward-char` | move one character forward |
| `C-b` | `backward-char` | move one character back |
| `C-n` | `next-line` | move down one line |
| `C-p` | `previous-line` | move up one line |
| `C-a` | `move-beginning-of-line` | jump to the start of the line |
| `C-e` | `move-end-of-line` | jump to the end of the line |
| `M-f` | `forward-word` | move one word forward |
| `M-b` | `backward-word` | move one word back |
| `C-s` | `isearch-forward` | search forward (also used as a jump tool) |
| `C-r` | `isearch-backward` | search backward |
| `M-<` | `beginning-of-buffer` | jump to the top of the buffer |
| `M->` | `end-of-buffer` | jump to the bottom of the buffer |
| `C-v` | `scroll-up-command` | page down |
| `M-v` | `scroll-down-command` | page up |

### Editing (very frequent)

<!-- keymap: global -->
| Key | Command | What it does |
|---|---|---|
| `C-d` | `delete-char` | delete one character forward |
| `DEL` | `delete-backward-char` | delete one character back |
| `C-k` | `kill-line` | cut from the cursor to the end of the line |
| `M-d` | `kill-word` | cut the word forward |
| `C-w` | `kill-region` | cut the selected region |
| `C-y` | `yank` | paste the last kill |
| `M-y` | `consult-yank-pop` | paste an earlier kill, searchable (this config) |
| `C-/` | `undo` | undo the last change |
| `C-x u` | `undo` | the same |
| `C-SPC` | `set-mark-command` | start a selection region |

### Files and buffers (frequent)

<!-- keymap: global -->
| Key | Command | What it does |
|---|---|---|
| `C-x C-f` | `find-file` | open a file |
| `C-x C-s` | `save-buffer` | save the buffer |
| `C-x b` | `switch-to-buffer` | switch to another open buffer |
| `C-x k` | `kill-buffer` | close a buffer |
| `C-x C-b` | `ibuffer` | show every open buffer --- **this config:** stock Emacs binds this to the plainer `list-buffers`; this project rebinds it to `ibuffer`, a real buffer (mark, sort, bulk-close), see [KEYBOARD.md](KEYBOARD.md#the-buffer-list-ibuffer) |

### Windows and frames (frequent)

<!-- keymap: global -->
| Key | Command | What it does |
|---|---|---|
| `C-x 2` | `split-window-below` | split the window top/bottom |
| `C-x 3` | `split-window-right` | split the window left/right |
| `C-x o` | `other-window` | move to the other window |
| `C-x 1` | `delete-other-windows` | keep only the current window |
| `C-x 0` | `delete-window` | close the current window |

### Commands and repetition (moderate, high-value)

<!-- keymap: global -->
| Key | Command | What it does |
|---|---|---|
| `M-x` | `execute-extended-command` | run any command by name |
| `C-x z` | `repeat` | repeat the last command (keep tapping `z` to repeat again) |
| `C-u` | `universal-argument` | `C-u N` repeats the next command N times |
| `C-x (` | `kmacro-start-macro` | start recording a keyboard macro |
| `C-x )` | `kmacro-end-macro` | stop recording |
| `C-x e` | `kmacro-end-and-call-macro` | replay the last macro (`e` again to repeat it) |
| `C-g` | `keyboard-quit` | cancel --- the universal escape hatch |
| `C-h` | `help-command` | open the help system |

## Page 2 --- finger placement

### Home row (resting position)

| Hand | Pinky | Ring | Middle | Index |
|---|---|---|---|---|
| Left | A | S | D | F |
| Right | ; | L | K | J |

Both thumbs rest on the spacebar. `F` and `J` have raised bumps so you can find home position
without looking.

### Column responsibility (each finger covers the keys above/below its home key)

| Finger | Keys |
|---|---|
| Left pinky | Q, A, Z (+ 1, Tab, Shift, Caps Lock) |
| Left ring | W, S, X |
| Left middle | E, D, C |
| Left index | R, F, V and T, G, B |
| Right index | Y, H, N and U, J, M |
| Right middle | I, K, , |
| Right ring | O, L, . |
| Right pinky | P, ; , / (+ 0, Enter, Shift) |

### Modifier keys for Emacs chords

- **Remap Caps Lock to Control.** The single biggest speed trick for Emacs --- Caps Lock
  sits right next to the left pinky's home position (`A`), turning `Ctrl` into a small
  pinky-dip instead of a stretch to the corner of the keyboard. Full setup steps (Windows,
  macOS, Linux) are in [TYPING.md](TYPING.md#21-make-caps-lock-a-control-key).
- **Cross-hand chording.** Press `Ctrl` with one pinky while the other hand types the letter
  (e.g. `C-n`: left pinky on `Ctrl`, right index on `N`) --- faster than reaching with the
  same hand. See [TYPING.md section 3.1](TYPING.md#31-which-finger-presses-what) for the
  fuller version, including which hand's `Ctrl` to use for which letters.
- **Alt (Meta) via thumb.** Keep both hands on the letter keys; use the thumb for Alt, right
  next to the spacebar.
- **Hold, don't release, through a sequence.** For `C-x C-f`, hold `Ctrl` down and tap `x`
  then `f`, rather than releasing between them --- but only when the SECOND key also has
  `Ctrl` (`C-x b` is different: release `Ctrl` after `x`). [TYPING.md section
  3.2](TYPING.md#32-hold-the-modifier-through-the-whole-chord-or-let-go) has the full table
  of which is which, since mixing these up is the most common beginner mistake.
- **Build reflexes on the most common chords first:** `C-f`/`b`/`n`/`p`/`a`/`e`/`k`/`y`/`s`/`g`/`x`
  before adding more. `C-g` (`keyboard-quit`) becomes especially automatic as the universal
  "escape hatch."

### Practice habit

After each reach, return the finger to its home row key. This return-to-home habit, built
through repetition, is what produces real typing and chording speed over time.
