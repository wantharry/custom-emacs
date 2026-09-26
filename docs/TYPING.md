# Typing Emacs keys fast

How to press Control and Meta comfortably and quickly, how to type fewer of them, and a
four-week plan to make them automatic. Read [KEYBOARD.md](KEYBOARD.md) for *what* the keys
do; this guide is about *how to press them* and *how to learn them*.

> **What is verified.** Every key in the tables here is checked against this Emacs build by
> `tests/ert/keybindings.el`. The keyboard and ergonomics advice is general guidance, not
> measured on your hands. The Windows, macOS and Linux keyboard-setup steps were **not run on
> this machine** (they change your operating system, not Emacs); menu names may differ a
> little on your version. This is not medical advice: if typing hurts, stop and see a professional.

## 1. Ten-second summary

1. **Make Caps Lock a Control key** (section 2). The biggest single improvement.
2. **Press Alt with your thumb** and use `Esc` as a hold-free Meta (sections 3.1 and 3.3).
3. **Hold Control once through a whole chord** like `C-x C-s` (section 3.2).
4. **Type fewer chords:** turn on Evil (`C-c v`) or `M-x repeat-mode` (section 4).
5. **Let Emacs teach you:** run things with `M-x` and read the hint it prints (section 4.4).
6. **Learn a few keys a day on real work,** not a big cheat sheet at once (section 5).

## 2. Set up the keyboard first (five minutes)

### 2.1 Make Caps Lock a Control key

Control is the key you press most, and by default it sits in the corner where the pinky
stretches to reach it. Caps Lock sits on the home row and is almost never needed. Making it
a second Control key is the change nearly every Emacs user makes.

**Your setup is Emacs in a WSLg window on Windows: make the change in Windows**, because WSLg
takes its keyboard input from Windows. Changing it inside Linux will not affect the window.

| System | How |
|---|---|
| **Windows** (your case) | Install **Microsoft PowerToys** → **Keyboard Manager** → **Remap a key** → add: physical key **Caps Lock**, mapped to **Ctrl (Left)**. Or with AutoHotkey v2, a one-line script: `CapsLock::LCtrl` |
| macOS | System Settings → Keyboard → Keyboard Shortcuts → **Modifier Keys** → set Caps Lock to Control |
| Linux desktop | GNOME Tweaks → Keyboard & Typing → Additional Layout Options → *Caps Lock behavior*; or in X11 `setxkbmap -option ctrl:nocaps` (does **not** apply inside WSLg) |

**Check it worked:** in an Emacs window press Caps Lock and `f`. The cursor should move one
character right (`C-f`). If it types `F` or nothing happens, the remap is not active.

Keep the real Ctrl keys too. Section 3.1 explains why using both is better than one.

### 2.2 Make sure Alt is Meta

Meta is the `M-` in `M-x`. On Windows and Linux it is the **Alt** key.

**Check it:** press `Alt` and `x` together. The prompt `M-x` should open at the bottom. If it
does not, use the `Esc` method in section 3.3, which needs no modifier at all.

| Where | If Alt does not act as Meta |
|---|---|
| Emacs window (WSLg) | Usually works. Windows itself may take `Alt+Space` (window menu), `Alt+Tab` and `Alt+F4` |
| Windows Terminal, most Linux terminals | Alt normally works; otherwise use `Esc` |
| macOS Terminal.app | Preferences → Profiles → Keyboard → **Use Option as Meta key** |
| macOS iTerm2 | Profiles → Keys → *Left Option key*: **Esc+** |
| macOS GUI Emacs | Not tried here. The setting is `ns-alternate-modifier` set to `'meta` |

### 2.3 Know what your system takes for itself

Some keys never reach Emacs because the operating system uses them first:

| Key | Problem | What to do |
|---|---|---|
| `C-SPC` (start selecting) | Windows often uses Ctrl+Space to switch input methods, so it can silently do nothing | Use **`C-@`**, which runs the same command (`set-mark-command`) |
| `C-M-` chords (Ctrl+Alt) | On many Windows keyboard layouts, Ctrl+Alt is treated as AltGr and types a symbol instead | Use `Esc` then the control key: `C-M-f` is `Esc C-f` |
| `Alt+F4`, `Alt+Tab`, the Windows key | Belong to Windows | Avoid, or use the `Esc` route |
| `C-z` | Suspends the window (see section 6) | Do not press it by accident |

## 3. How to press them

### 3.1 Which finger presses what

Emacs keys are mostly a letter with a modifier. The comfortable pattern:

- **Press the modifier with the hand opposite to the letter.** The letter comes from one
  hand and the modifier from the other, so nothing stretches and nothing collides.
- **Thumb for Alt.** Your thumbs rest on the space bar, right next to Alt. `M-x` is left
  thumb on Alt and right hand on `x`.
- **Use both Control keys.** With Caps Lock remapped to Control (left side), use it for
  letters typed by the **right** hand (`C-n`, `C-p`, `C-k`, `C-y`, `C-l`, `C-j`), and use the
  real **right** Control key for letters typed by the **left** hand (`C-x`, `C-s`, `C-f`,
  `C-b`, `C-a`, `C-e`, `C-w`, `C-g`).
- **Keep wrists straight and shoulders loose.** Reaching with the pinky bent up is what tires
  the hand. If a chord feels awkward, change which hand presses it, or find another way
  (sections 3.3 and 4).

This is a guideline: comfort differs between people and keyboards.

### 3.2 Hold the modifier through the whole chord, or let go?

For a two-key chord that uses Control twice, such as `C-x C-s`, you **do not** press Control
twice. Hold Control, tap `x`, tap `s`, release. This is the trick that makes Emacs feel fast.

But when the second key has no Control (`C-x s` vs `C-x C-s` are different commands!), you
must **let go of Control before the second key**. Mixing these up is the most common
beginner mistake.

**Hold Control through both keys:**

| Key | Command | Feel |
|---|---|---|
| `C-x C-f` | `find-file` | hold Ctrl, tap `x`, tap `f` |
| `C-x C-s` | `save-buffer` | hold Ctrl, tap `x`, tap `s` |
| `C-x C-c` | `save-buffers-kill-terminal` | hold Ctrl, tap `x`, tap `c` |
| `C-x C-b` | `ibuffer` | hold Ctrl, tap `x`, tap `b` |
| `C-x C-w` | `write-file` | hold Ctrl, tap `x`, tap `w` |
| `C-x C-x` | `exchange-point-and-mark` | hold Ctrl, tap `x` twice |
| `C-x C-e` | `eval-last-sexp` | hold Ctrl, tap `x`, tap `e` |
| `C-x C-t` | `transpose-lines` | hold Ctrl, tap `x`, tap `t` |

**Let go of Control before the second key:**

| Key | Command | Feel |
|---|---|---|
| `C-x b` | `switch-to-buffer` | Ctrl+`x`, release, then `b` |
| `C-x k` | `kill-buffer` | Ctrl+`x`, release, then `k` |
| `C-x o` | `other-window` | Ctrl+`x`, release, then `o` |
| `C-x 0` | `delete-window` | Ctrl+`x`, release, then `0` |
| `C-x 1` | `delete-other-windows` | Ctrl+`x`, release, then `1` |
| `C-x 2` | `split-window-below` | Ctrl+`x`, release, then `2` |
| `C-x 3` | `split-window-right` | Ctrl+`x`, release, then `3` |
| `C-x u` | `undo` | Ctrl+`x`, release, then `u` |
| `C-x h` | `mark-whole-buffer` | Ctrl+`x`, release, then `h` |
| `C-x d` | `dired` | Ctrl+`x`, release, then `d` |
| `C-c e e` | `allow-editing` | Ctrl+`c`, release, then `e`, `e` (three deliberate keys) |
| `C-c e l` | `stop-editing` | Ctrl+`c`, release, then `e`, `l` |

**The same idea for Meta:** `M-g M-g` (`goto-line`) holds Alt through both keys, while
`M-g g` releases it before the second:

| Key | Command | Feel |
|---|---|---|
| `M-g M-g` | `goto-line` | hold Alt, tap `g` twice |
| `M-g g` | `goto-line` | Alt+`g`, release, then `g` |
| `M-g n` | `next-error` | Alt+`g`, release, then `n` |

Emacs treats `M-g M-g` and `M-g g` as the same command, so whichever is easier for you works.
That is common: many two-key chords accept both.

### 3.3 Meta without holding anything: the Esc method

Pressing `Esc` then a key does the same as holding Alt and pressing that key. You tap
`Esc`, let go, then tap the key. No two-key stretch at all.

| You want | Alt way | Esc way | Command |
|---|---|---|---|
| Run a command by name | `M-x` | `Esc` then `x` | `execute-extended-command` |
| Forward one word | `M-f` | `Esc` then `f` | `forward-word` |
| Back one word | `M-b` | `Esc` then `b` | `backward-word` |
| Cut the next word | `M-d` | `Esc` then `d` | `kill-word` |
| Copy | `M-w` | `Esc` then `w` | `kill-ring-save` |
| Ctrl+Alt chords | `C-M-f` | `Esc` then `C-f` | `forward-sexp` |

Three more facts (all checked here):

- **`C-[` is the same as `Esc`.** It can be easier to reach than the Esc key.
- **`Esc Esc Esc`** cancels almost everything (`keyboard-escape-quit`). `C-g` is the usual way
  to cancel, and it is the one to learn first.
- **Watch the speed.** In a terminal, `Esc` followed *quickly* by another key is read as Meta
  plus that key. It is usually what you want, but if you only wanted to cancel something and
  then type a command, pause a moment or use `C-g` instead. (This caught a test here, so it is
  real.)

### 3.4 Practice the motion, not the letters

- **Learn a chord as one gesture,** like a piano chord, not as "control, x, control, s".
  Say `C-x C-s` and your hands should already be moving.
- **Go slow first,** then only speed up when it is smooth. Fast and wrong builds the wrong
  habit.
- **Stop looking at the keyboard.** Look at the screen. The bottom line shows the keys you
  have typed so far (`C-x-`), which tells you when you are mid-chord.
- **Short sessions beat long ones.** Ten focused minutes a day beats an hour on Saturday.

## 4. Type fewer chords

### 4.1 Evil: single-letter commands

`C-c v` turns on vi-style editing. In its **normal** state almost everything is a single
letter with no modifier (`h j k l` to move, `dd` to delete a line, `yy` to copy, `p` to
paste). If Control chords are uncomfortable, this removes most of them. The keys are in
[KEYBOARD.md](KEYBOARD.md#evil-vi-keys-optional).

### 4.2 `repeat-mode`: repeat with one key

`M-x repeat-mode` makes some commands repeatable by a single key straight after the chord,
for as long as you keep pressing it:

<!-- keymap: none -->
| After | Then press | Runs |
|---|---|---|
| `C-x o` | `o` | `other-window` (again) |
| `C-x o` | `O` | `other-window-backward` |
| `C-x u` | `u` | `undo` (again) |
| `M-g n` | `n` | `next-error` (again) |
| `M-g n` | `p` | `previous-error` |
<!-- keymap: global -->

It is **not** turned on in this config. To keep it, add `(repeat-mode 1)` to
`config/init.el`. Try it for a week and decide.

### 4.3 Counts and the repeat key

- **`C-u` then a number, then a command** repeats it: `C-u 5 C-n` moves down five lines. `M-5`
  does the same in fewer keys.
- **`C-x z`** (`repeat`) repeats the previous command, and pressing `z` again keeps repeating.

### 4.4 Let Emacs remind you

| Help | How |
|---|---|
| The key hint | Run a command with `M-x` and the bottom line says *"You can run the command X with KEY"*. Use `M-x` freely and read the hint |
| Discover what follows | Type a prefix such as `C-x` or `C-c` and pause: `which-key` lists the options |
| What did I press? | `C-h l` (`view-lossage`) shows your last keys and what they ran |
| What does this key do? | `C-h k` then the key; `C-h c` for a one-line answer |
| Which key runs this command? | `C-h w` then the command name |

### 4.5 Names instead of keys

You never need a key. `M-x` completes as you type and matches loosely, so the first letters of
each word usually find a command. A key is only for commands you use all the time.

## 5. A four-week plan

**Ten minutes a day** on real work or the practice file. Add only the keys of the current week,
and keep the earlier ones going. If a key does not stick after a few days, keep using `M-x`
for it and come back later. A practice file with exercises is in
[`practice.txt`](practice.txt); copy it first so you can edit freely:

```sh
cp docs/practice.txt /tmp/practice.txt
```

Open it with `C-x C-f /tmp/practice.txt`, then unlock it with `C-c e e` (this config opens every
file read-only, and unlocking it is the first thing to practice).

### Week 1: survive and move

| Key | Command | Drill |
|---|---|---|
| `C-g` | `keyboard-quit` | Start `C-x`, then cancel. Do it ten times |
| `C-x C-f` | `find-file` | Open the practice file |
| `C-c e e` | `allow-editing` | Unlock it |
| `C-x C-s` | `save-buffer` | Save with the hold-Ctrl trick |
| `C-x C-c` | `save-buffers-kill-terminal` | Quit, and reopen |
| `C-/` | `undo` | Type a word, undo it |
| `C-f` | `forward-char` | Move right with no arrow keys |
| `C-b` | `backward-char` | Move left |
| `C-n` | `next-line` | Move down |
| `C-p` | `previous-line` | Move up |
| `C-a` | `move-beginning-of-line` | Jump to the start of the line |
| `C-e` | `move-end-of-line` | Jump to the end |
| `M-x` | `execute-extended-command` | Run `goto-line` by name |

Goal: do open, unlock, edit, save, quit **without the mouse or arrow keys**.

### Week 2: words, cut and paste

| Key | Command | Drill |
|---|---|---|
| `M-f` | `forward-word` | Cross a sentence one word at a time |
| `M-b` | `backward-word` | Cross it back |
| `M-d` | `kill-word` | Cut the next word |
| `C-k` | `kill-line` | Cut to the end of the line |
| `C-SPC` | `set-mark-command` | Start selecting (use `C-@` if this does nothing) |
| `C-w` | `kill-region` | Cut the selection |
| `M-w` | `kill-ring-save` | Copy it |
| `C-y` | `yank` | Paste |
| `M-y` | `yank-pop` | Right after pasting, swap in an older cut |
| `C-d` | `delete-char` | Delete the letter under the cursor |

Goal: move a line to another place with only the keyboard.

### Week 3: search, windows, buffers

| Key | Command | Drill |
|---|---|---|
| `C-s` | `isearch-forward` | Search, press `C-s` again for the next match |
| `C-r` | `isearch-backward` | Search backwards |
| `M-%` | `query-replace` | Replace with `y`, `n`, `!`, `q` |
| `C-x b` | `switch-to-buffer` | Jump to another open file |
| `C-x k` | `kill-buffer` | Close a file |
| `C-x 3` | `split-window-right` | Two panes side by side |
| `C-x 2` | `split-window-below` | Two panes top and bottom |
| `C-x o` | `other-window` | Move between panes (try `M-o` too) |
| `C-x 1` | `delete-other-windows` | Back to one pane |
| `C-x 0` | `delete-window` | Close this pane |

Goal: edit two files at once, side by side, without touching the mouse.

### Week 4: speed and power

| Key | Command | Drill |
|---|---|---|
| `M-<` | `beginning-of-buffer` | Jump to the top |
| `M->` | `end-of-buffer` | Jump to the bottom |
| `M-g g` | `goto-line` | Go to line 40 |
| `C-l` | `recenter-top-bottom` | Press repeatedly and watch the view |
| `C-x d` | `dired` | Browse a folder ([KEYBOARD.md](KEYBOARD.md#dired-the-directory-editor)) |
| `M-.` | `xref-find-definitions` | In code, jump to a definition |
| `M-,` | `xref-go-back` | Come back |
| `C-x p f` | `project-find-file` | Open a file in the project |
| `M-;` | `comment-dwim` | Comment a line |
| `<f3>` | `kmacro-start-macro-or-insert-counter` | Record a macro (`<f4>` ends it and replays) |

Goal: edit code the way you would with the mouse, at the same speed or faster.

### You have got it when

- You reach for the mouse less than once an hour.
- You do not look at the keyboard for `C-x C-s`, `C-x C-f` and `C-g`.
- You start a chord and your hands already know the second key.
- `C-h l` shows few mistakes in a session.

## 6. When you press the wrong thing

Slips are normal. Almost everything is reversible:

| You pressed | What happened | How to recover |
|---|---|---|
| Something unexpected | Emacs is waiting for more keys | `C-g` cancels; `Esc Esc Esc` cancels harder |
| `C-x C-c` | Quit. It asks first if there are unsaved changes | Answer `n` (or `no`) at the prompt |
| `C-z` | In a window, this **suspends (minimizes)** it; in a terminal it sends Emacs to the background | Click it in the taskbar; in a terminal type `fg` |
| `C-x C-q` | Nothing; it only prints a reminder in this config | Use `C-c e e` to edit |
| `C-w` or `C-k` by mistake | You cut text (in a locked file it is refused) | `C-y` pastes it back, or `C-/` undoes |
| `C-x 1` | The other panes closed (the buffers are still open) | `C-x 3` or `C-x 2`, then `C-x b` |
| `C-x k` | A buffer closed | `C-x C-f` reopens the file |
| `M-x` and a wrong command | A command started | `C-g` |
| A prompt at the bottom you did not want | Emacs is in the minibuffer | `C-g`; or `C-]` (`abort-recursive-edit`) to leave |
| Typing into a file | Nothing changed; the file is read-only | That is the lock working. `C-c e e` only if you meant to edit |

## 7. A note on comfort

- If a chord hurts, change how you press it before you change how often you press it: remap
  Caps Lock, use the other hand, use the `Esc` method, or use Evil.
- Take breaks. Ten-minute sessions and stretching help more than pushing through.
- If you get pain or numbness, stop and see a professional. That is beyond what a keyboard
  guide can help with.

## 8. Related guides

- [KEYBOARD.md](KEYBOARD.md): every key, including Dired and Evil.
- [TESTING.md](TESTING.md): how this and the other tables are checked by the tests.
- [`practice.txt`](practice.txt): exercises to type along with.
