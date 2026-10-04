;;; mode-reference.el --- an always-visible command reference for Dired/Org/ranger/Treemacs  -*- lexical-binding: t; -*-

;; WHAT: a plain, read-only reference panel on the right, listing the current mode's
;; most useful commands (Dired, Org, `ranger', or Treemacs) --- not interactive, just
;; always there to glance at while you work, automatically appearing the moment you
;; switch into a real buffer of one of those and disappearing the moment you switch
;; away. `ranger' and Treemacs were added after Dired/Org, user request, once this
;; session had also built real cross-navigation between all four (`r', `D', `z', `G',
;; `C-c T' --- see each one's own panel text, and init.el's own comments on those
;; commands, for the full account).
;;
;; WHY: user request, a deliberately different thing from `C-o''s own Casual menu
;; (config/init.el, Dired/Org only --- `ranger'/Treemacs have no Casual integration)
;; --- that is a real `transient' popup: modal, takes over the keyboard, closes the
;; instant you pick one action. This is the opposite: a static sidebar you can read
;; while freely navigating/marking/editing, never grabs focus, never closes on its
;; own mid-task. The two intentionally coexist in Dired/Org; this does not replace
;; `C-o' there.
;;
;; HOW: a real, found-by-the-user mistake in an earlier version of this content, not
;; something to repeat --- the first version was transcribed from Casual's own `C-o'
;; menu text (captured from a real running session), which LOOKED like a transcript of
;; real standalone keys but mostly was not: a transient menu's own suffix labels
;; (`F' for a new file, `l' for \"Link\", `C-s' for \"Schedule\", etc.) are only
;; meaningful INSIDE that menu, while it has focus --- most of them do nothing, or
;; something completely different, as a bare keypress in the real buffer (confirmed
;; directly: `F' said \"F is undefined\"; `l'/`c'/`h'/`O'/`#' turned out to be real
;; Dired keys bound to entirely different commands; most of the hand-written Org
;; entries were missing their real `C-c' prefix outright). Every single entry below
;; was re-verified directly against the real `dired-mode-map'/`org-mode-map'
;; (`lookup-key', not assumed, not re-copied from Casual's menu) before being written
;; here --- nothing in this file is Casual-menu-only shorthand any more.
;; Shown via `display-buffer-in-side-window' in a dedicated, `no-other-window' window
;; (so `C-x o'/`other-window' skips straight over it, matching how `C-o''s own popup
;; and which-key's popup already behave) --- never selected, never the buffer you end
;; up typing into by accident.

(defconst my/mode-reference-dired-text
  "Dired

-- File ops --
C      Copy to...
R      Rename to...
D      Delete marked
d      Flag for deletion
x      Delete flagged
S      Symlink to...
H      Hardlink to...
o      Open other window
v      View (read-only)
E      Open (external app)
a      Open, replace buffer

-- Directory --
+      Create directory
$      Hide/show subdir
i      Insert subdir here
g      Revert (refresh)
s      Change sort order

-- Marking --
m      Mark
u      Unmark
U      Unmark all
t      Toggle marks
*      Mark submenu (by type)
%      Regexp submenu

-- Navigation --
^      Up to parent dir
p/n    Previous/next line
j      Goto file by name...

-- Search --
A      Find regexp in marked
Q      Find & replace regexp

-- Other --
!      Shell command
&      ...async
W      Browse in web browser
T      Change timestamp
Z      Compress
k      Remove line (not file)
w      Copy filename
y      Show file type
q      Quit
")

(defconst my/mode-reference-org-text
  "Org

-- TODO / priority --
C-c C-t     Cycle TODO state
C-c ,       Set priority
C-c C-q     Set tags
S-up/down   Raise/lower priority

-- Dates --
C-c C-s     Schedule...
C-c C-d     Deadline...
C-c .       Insert timestamp
C-c C-y     Evaluate time range

-- Structure --
TAB         Cycle visibility
RET         Follow link/new item
C-c C-c     Context action
C-c C-w     Refile to heading...
C-c C-^     Up to parent heading
C-c C-f/b   Next/prev heading
C-c C-j     Jump to heading...
C-c $       Archive subtree

-- Links --
C-c C-l     Insert link
C-c C-o     Open at point

-- Clocking --
C-c C-x C-i Clock in
C-c C-x C-o Clock out

-- Search --
C-c /       Sparse tree (search)

-- Export --
C-c C-e     Export dispatcher
")

(defconst my/mode-reference-ranger-text
  "ranger

-- Navigation --
h/l    Up to parent / open, enter dir
j/k    Down/up a line
H/L    Back/forward in history
gg/G   Top/bottom of listing
RET    Open file, enter dir

-- Marking --
TAB    Mark the file
t      Toggle its mark
v      Toggle all marks

-- Copy / cut / paste --
y y    Copy (yank)
d d    Cut
p p    Paste
p o    Paste, overwriting

-- File ops --
R      Rename
D      Delete
+      Create directory
!      Shell command

-- View --
i      Toggle preview pane
z p    Toggle detail columns
z h    Toggle dotfiles
o      Change sort order

-- Search --
/      Search
n/N    Next/previous match

-- Other --
f      Travel (jump by typing)
S      Open a shell (eshell) here
r      This config: switch to plain Dired
?      ranger's own help
q      Quit ranger
")

(defconst my/mode-reference-treemacs-text
  "Treemacs

-- Navigate --
RET    Open file / expand or collapse
TAB    Expand or collapse
n/p    Next/previous line
u      Up to parent folder
H      Collapse the parent folder
M-n/p  Next/previous item, same level

-- Open --
o v    Open to the side
o h    Open below

-- Create / change --
c f    Create a file
c d    Create a folder
R      Rename
m      Move
d      Delete (asks first)

-- View --
g      Refresh
t h    Toggle dotfiles
w      Set the tree's width
>/<    Wider/narrower
y a    Copy absolute path
y r    Copy path from project root

-- Projects --
C-c C-p a   Add a project
C-c C-p d   Remove a project

-- This config --
D      Open plain Dired here
z      Open ranger here
G      Open Magit status for this repo

-- Other --
q      Close the tree (Q: and forget its state)
")

(defconst my/mode-reference-buffer-name "*Mode Reference*")

(defvar-local my/mode-reference--shown-mode nil
  "Which mode's text is currently in `my/mode-reference-buffer-name', so switching
between Dired and Org only rewrites the buffer when the content actually needs to
change, not on every single update.")

(defun my/mode-reference--relevant-mode ()
  "The major mode (a symbol) that currently warrants showing the panel, or nil.
`ranger-mode' is checked BEFORE `dired-mode': confirmed directly in its own source,
`ranger-mode' is `(define-derived-mode ranger-mode dired-mode ...)', so
`derived-mode-p 'dired-mode' is also true there --- checking it first would show the
Dired text instead of ranger's own."
  (cond ((derived-mode-p 'ranger-mode) 'ranger-mode)
        ((derived-mode-p 'dired-mode) 'dired-mode)
        ((derived-mode-p 'org-mode) 'org-mode)
        ((derived-mode-p 'treemacs-mode) 'treemacs-mode)))

(defun my/mode-reference--text-for (mode)
  (pcase mode
    ('dired-mode my/mode-reference-dired-text)
    ('org-mode my/mode-reference-org-text)
    ('ranger-mode my/mode-reference-ranger-text)
    ('treemacs-mode my/mode-reference-treemacs-text)))

;; WHAT/WHY: `ranger''s own preview pane (`ranger.el', confirmed directly in its
;; source) uses the SAME `(side . right) (slot . 1)' this panel already uses for
;; Dired/Org/Treemacs --- confirmed the hard way, the same silent-conflict failure
;; mode `C-o''s own Casual menu hit earlier (see `--show''s own comment below): two
;; side windows sharing one slot fight over it, whichever shows second not
;; displaying at all. `ranger' gets its own, genuinely different slot instead of
;; being excluded the way it briefly was.
(defun my/mode-reference--slot-for (mode)
  (if (eq mode 'ranger-mode) 2 1))
;; WHY a narrower width specifically for `ranger': its own three panes (parent 25%,
;; current 50%, preview 25%, see init.el's own comment on `ranger-width-parents'/
;; `-preview') already fill the frame on their own; the default 0.28 this panel uses
;; elsewhere would leave less than nothing for them. 0.16 was the narrowest that
;; still read comfortably in a real terminal session without ranger's own columns
;; getting uncomfortably thin, confirmed visually, not guessed.
(defun my/mode-reference--width-for (mode)
  (if (eq mode 'ranger-mode) 0.16 0.28))

(defvar my/mode-reference--updating nil
  "Guards against re-entering `my/mode-reference--update' while it is itself
showing/hiding the panel's own window --- that window change is exactly the kind of
event `window-selection-change-functions'/`window-buffer-change-functions' (what this
is hooked to) fire for, so without this guard the update would immediately re-trigger
itself.")

(defun my/mode-reference--show (mode)
  (let ((buf (get-buffer-create my/mode-reference-buffer-name)))
    (with-current-buffer buf
      (unless (eq (buffer-local-value 'my/mode-reference--shown-mode buf) mode)
        (let ((inhibit-read-only t))
          (erase-buffer)
          (insert (my/mode-reference--text-for mode))
          (goto-char (point-min)))
        (special-mode)
        (setq-local display-line-numbers nil) ; a static reference, not something to jump to a line in
        (setq-local my/mode-reference--shown-mode mode)))
    (let ((win (get-buffer-window buf))
          (slot (my/mode-reference--slot-for mode)))
      ;; A real, found-while-adding-ranger's-own-panel gap: `ranger''s own preview
      ;; pane needs a DIFFERENT slot than Dired/Org/Treemacs share (see `--slot-for''s
      ;; own comment) --- but a side window's slot is fixed at the moment it is
      ;; created, not something `display-buffer' can change on an already-open window.
      ;; Switching between, say, Dired and `ranger' therefore has to delete the old
      ;; window and recreate it in the new slot, not just reuse it in place the way
      ;; switching between Dired and Org (same slot, same width) already could.
      (when (and win (not (eql (window-parameter win 'my/mode-reference-slot) slot)))
        (delete-window win)
        (setq win nil))
      (unless win
        ;; `slot . 1', not the default (0) --- a real conflict, found by testing: `C-o''s
        ;; own Casual menu (config/init.el) ALSO shows on the right now, in the default
        ;; slot 0. Two side windows sharing one slot fight over it (whichever shows
        ;; second silently fails to display at all, confirmed directly --- its transient
        ;; keymap still captured all input even though nothing was visible, the
        ;; confusing part that took the longest to track down). A distinct slot instead
        ;; makes them genuinely coexist, stacked on the same edge, no conflict: pressing
        ;; `C-o' while this panel is already showing adds Casual's menu above it, rather
        ;; than replacing or fighting with it.
        (setq win (display-buffer-in-side-window
                   buf `((side . right) (slot . ,slot)
                         (window-width . ,(my/mode-reference--width-for mode)))))
        (when win
          (set-window-parameter win 'no-other-window t)
          (set-window-parameter win 'my/mode-reference-slot slot)))
      ;; Re-anchored every time `--show' runs, not only when the window is first
      ;; created --- a real, user-reported bug: `C-c U' (menu-bar/tool-bar toggled,
      ;; which changes the real frame's pixel geometry in a GUI) left the panel
      ;; scrolled a little way down from its own top, cutting the first few lines off.
      ;; Resizing a window can make Emacs's own redisplay auto-scroll it to keep
      ;; `window-point' visible, and nothing was ever re-asserting the top position
      ;; afterward --- `my/reset-to-defaults' (`C-c U', config/init.el) explicitly
      ;; calls `my/mode-reference--update' after it finishes for exactly this reason,
      ;; and `window-size-change-functions' (added in `my/mode-reference-mode', below)
      ;; covers any other frame/window resize that might do the same thing.
      (when win
        (set-window-point win (with-current-buffer buf (point-min)))
        (set-window-start win (with-current-buffer buf (point-min)))))))

(defun my/mode-reference--hide ()
  (when-let* ((win (get-buffer-window my/mode-reference-buffer-name t)))
    (delete-window win)))

;; WHAT: the single update routine every hook below actually calls --- decides whether the
;; panel should show (and for which mode) or hide entirely, based on what's visible right
;; now.  WHY: used directly as the hook function for `window-selection-change-functions'/
;; `window-buffer-change-functions'/`window-size-change-functions' and the mode hooks, each
;; of which calls its functions with different real arguments (a frame, a window, ...) this
;; never actually needs --- `&rest _' just discards whatever was passed.  Binding
;; `my/mode-reference--updating' to t with `let*' (rather than a plain `setq'/`unwind-
;; protect' pair) is what makes the reentrancy guard self-resetting: it is automatically
;; back to nil the moment this call returns, including through a non-local exit, with
;; nothing separate to remember to clean up.  HOW: `(window-buffer (selected-window))'
;; rather than plain `(current-buffer)' --- the buffer actually shown in the selected
;; window is the one whose mode should decide the panel's state, which is not guaranteed to
;; be the same buffer that happens to be current at the exact moment one of these hooks
;; fires; `ignore-errors' means an edge case here (no real buffer to check, a transient
;; state) just leaves the panel as it was, rather than erroring out of a hook Emacs itself
;; is relying on to keep firing.
(defun my/mode-reference--update (&rest _)
  (unless my/mode-reference--updating
    (let* ((my/mode-reference--updating t)
           (mode (ignore-errors
                   (with-current-buffer (window-buffer (selected-window))
                     (my/mode-reference--relevant-mode)))))
      (if mode
          (my/mode-reference--show mode)
        (my/mode-reference--hide)))))

;;;###autoload
(define-minor-mode my/mode-reference-mode
  "Show an always-visible, read-only command reference on the right while in Dired,
Org, `ranger', or Treemacs, automatically hidden otherwise.  See
config/mode-reference.el's own header comment for how this differs from `C-o''s own
Casual menu."
  :global t
  (if my/mode-reference-mode
      (progn
        ;; The window-change hooks (below) cover every later switch correctly, but a
        ;; real gap, found by testing rather than assumed: they do not fire for the
        ;; very FIRST buffer shown at startup (e.g. `emacs -nw somedir`, opening
        ;; straight into Dired) --- there is no prior state within the same session to
        ;; have "changed" from. `dired-mode-hook'/`org-mode-hook'/`treemacs-mode-hook'
        ;; close that gap: they fire on every real mode activation, startup included,
        ;; not only on later buffer switches. `ranger-mode' needs no entry of its own
        ;; here --- confirmed directly, `(define-derived-mode ranger-mode dired-mode
        ;; ...)' already runs `dired-mode-hook' too, as every derived mode does for
        ;; each of its ancestors.
        (add-hook 'dired-mode-hook #'my/mode-reference--update)
        (add-hook 'org-mode-hook #'my/mode-reference--update)
        (add-hook 'treemacs-mode-hook #'my/mode-reference--update)
        (add-hook 'window-selection-change-functions #'my/mode-reference--update)
        (add-hook 'window-buffer-change-functions #'my/mode-reference--update)
        ;; Catches a real, user-reported bug (see `my/mode-reference--show''s own
        ;; comment): a frame-geometry change (e.g. `menu-bar-mode'/`tool-bar-mode'
        ;; toggling in a real GUI frame) can resize the panel's window and leave it
        ;; scrolled away from its own top, with nothing else re-anchoring it.
        (add-hook 'window-size-change-functions #'my/mode-reference--update)
        (my/mode-reference--update))
    (remove-hook 'dired-mode-hook #'my/mode-reference--update)
    (remove-hook 'org-mode-hook #'my/mode-reference--update)
    (remove-hook 'treemacs-mode-hook #'my/mode-reference--update)
    (remove-hook 'window-size-change-functions #'my/mode-reference--update)
    (remove-hook 'window-selection-change-functions #'my/mode-reference--update)
    (remove-hook 'window-buffer-change-functions #'my/mode-reference--update)
    (my/mode-reference--hide)))

(provide 'mode-reference)
;;; mode-reference.el ends here
