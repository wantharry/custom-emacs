# Perspectives: named groups of buffers and windows

Working on two unrelated projects (or just two unrelated tasks) in the same Emacs session mixes both
projects' buffers into one list and `C-x b`/`C-b` becomes a scroll through everything open, not just
what you are actually working on right now. `perspective` groups buffers (and the window layout that
shows them) into named "perspectives", and switching perspectives swaps the whole visible set at once.

**Not the same package as the similarly-named `persp-mode`.** They are two different, unrelated
MELPA packages with a different API --- `doom-modeline`'s own `persp-name` mode-line segment (already in
this config) explicitly only supports `persp-mode`, confirmed directly in its own source comment
("Support `persp-mode`, while not support `perspective`"), so that segment is deliberately left off.
`perspective` shows its own current-perspective name in the mode-line automatically once enabled
(no extra setup needed) --- that is what you see instead.

## Off by default

Like Evil (`C-c v`), perspectives cost nothing until you actually want them: `perspective` is not
loaded, and `persp-mode` is not turned on, until you press the toggle key the first time.

| Key | Command | What it does |
|---|---|---|
| `C-c P` | `my/toggle-perspective` | turn perspectives on (installs `perspective` first if needed); press again to turn off |

## Once it is on: `C-x x`

`perspective`'s own full command prefix. This is also a **real, stock Emacs 28+ prefix**
(`rename-buffer`, `toggle-truncate-lines`, `insert-buffer`, ...) --- `perspective` layers its own
commands on top rather than replacing it: where it defines a command for a letter a stock one already
used, its own wins (e.g. `C-x x u` becomes `persp-unmerge`, not the stock `rename-uniquely`); every
other stock `C-x x` command untouched by `perspective` still works exactly as before.

| Key | Command | What it does |
|---|---|---|
| `C-x x s` | `persp-switch` | switch to a perspective by name, creating it if it does not exist yet |
| `C-x x n` | `persp-next` | next perspective |
| `C-x x p` | `persp-prev` | previous perspective |
| `C-x x r` | `persp-rename` | rename the current perspective |
| `C-x x c` | `persp-kill` | kill a perspective entirely |
| `C-x x k` | `persp-remove-buffer` | remove a buffer from the current perspective (the buffer itself is not killed) |
| `C-x x b` | `persp-switch-to-buffer` | switch to a buffer, limited to the current perspective |
| `C-x x a` | `persp-add-buffer` | add an existing buffer (from another perspective) to this one |
| `C-x x i` | `persp-import` | import another perspective's buffer list into this one |
| `C-x x m` / `C-x x u` | `persp-merge` / `persp-unmerge` | merge another perspective's buffers into this one, or undo that |
| `C-x x 1`–`C-x x 0` | `persp-switch-by-number` | jump straight to the 1st–10th perspective |
| `C-x x C-s` | `persp-state-save` | save every perspective (names, buffers, window layout) to a file |
| `C-x x C-l` | `persp-state-load` | load perspectives back from a file saved with the above |

`persp-state-save`/`persp-state-load` are manual here, not auto-restored on startup --- this config
already has its own crash-safe session restore (`C-c w`, see [SESSION.md](SESSION.md)), and the two are
not wired together; save/load perspectives explicitly if you want a layout to survive a restart.

Every perspective starts with its own `scratch` buffer, and buffers not explicitly added to a
perspective are still visible everywhere (only buffers you add stay scoped) --- `perspective`'s own
README has the full set of customization variables if you want stricter buffer isolation.
