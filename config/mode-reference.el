;;; mode-reference.el --- an always-visible command reference for Dired/Org  -*- lexical-binding: t; -*-

;; WHAT: a plain, read-only reference panel on the right, listing Dired's (or Org's)
;; most useful commands --- not interactive, just always there to glance at while you
;; work, automatically appearing the moment you switch into a real Dired/Org buffer and
;; disappearing the moment you switch away.
;;
;; WHY: user request, a deliberately different thing from `C-o''s own Casual menu
;; (config/init.el) --- that is a real `transient' popup: modal, takes over the
;; keyboard, closes the instant you pick one action. This is the opposite: a static
;; sidebar you can read while freely navigating/marking/editing, never grabs focus,
;; never closes on its own mid-task. The two intentionally coexist; this does not
;; replace `C-o'.
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

(defconst my/mode-reference-buffer-name "*Mode Reference*")

(defvar-local my/mode-reference--shown-mode nil
  "Which mode's text is currently in `my/mode-reference-buffer-name', so switching
between Dired and Org only rewrites the buffer when the content actually needs to
change, not on every single update.")

(defun my/mode-reference--relevant-mode ()
  "The major mode (a symbol) that currently warrants showing the panel, or nil."
  (cond ((derived-mode-p 'dired-mode) 'dired-mode)
        ((derived-mode-p 'org-mode) 'org-mode)))

(defun my/mode-reference--text-for (mode)
  (pcase mode
    ('dired-mode my/mode-reference-dired-text)
    ('org-mode my/mode-reference-org-text)))

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
    (let ((win (get-buffer-window buf)))
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
                   buf '((side . right) (slot . 1) (window-width . 0.28))))
        (when win (set-window-parameter win 'no-other-window t)))
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
  "Show an always-visible, read-only command reference on the right while in Dired or
Org, automatically hidden otherwise.  See config/mode-reference.el's own header
comment for how this differs from `C-o''s own Casual menu."
  :global t
  (if my/mode-reference-mode
      (progn
        ;; The window-change hooks (below) cover every later switch correctly, but a
        ;; real gap, found by testing rather than assumed: they do not fire for the
        ;; very FIRST buffer shown at startup (e.g. `emacs -nw somedir`, opening
        ;; straight into Dired) --- there is no prior state within the same session to
        ;; have "changed" from. `dired-mode-hook'/`org-mode-hook' close that gap: they
        ;; fire on every real mode activation, startup included, not only on later
        ;; buffer switches.
        (add-hook 'dired-mode-hook #'my/mode-reference--update)
        (add-hook 'org-mode-hook #'my/mode-reference--update)
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
    (remove-hook 'window-size-change-functions #'my/mode-reference--update)
    (remove-hook 'window-selection-change-functions #'my/mode-reference--update)
    (remove-hook 'window-buffer-change-functions #'my/mode-reference--update)
    (my/mode-reference--hide)))

(provide 'mode-reference)
;;; mode-reference.el ends here
