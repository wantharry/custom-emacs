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
;; HOW: the content below is a plain, hand-written transcript of Casual's own real menu
;; layout (`casual-dired-tmenu'/`casual-org-tmenu'), captured directly from a real
;; running session, not invented --- kept in sync by hand if Casual's own menu changes,
;; the same tradeoff this project already accepts for `docs/KEYBOARD.md' and `C-c k'.
;; Shown via `display-buffer-in-side-window' in a dedicated, `no-other-window' window
;; (so `C-x o'/`other-window' skips straight over it, matching how `C-o''s own popup
;; and which-key's popup already behave) --- never selected, never the buffer you end
;; up typing into by accident.

;; One column, not Casual's own wide multi-column grouping --- this panel is meant to
;; be a narrow sidebar, not a wide popup, so the content is reflowed to fit that,
;; category headers kept (matching Casual's own real groupings) but each entry on its
;; own line.
(defconst my/mode-reference-dired-text
  "Dired

-- File --
o    Open other window
v    View (read-only)
C    Copy to...
R    Rename...
D    Delete...
l    Link...
c    Change...
y    Type
w    Copy name

-- Directory --
s    Sort by...
h    Hide details
O    Omit mode
$    Hide/unhide subdir
g    Revert

-- Bulk --
m    Mark
t    Toggle marks
r    Regexp...
/    Search & replace...
#    Utils...

-- Navigation --
^    .. parent dir
p/n  Up/down file
M-p  Up/down dir
M-n  (M-n = down)
[/]  Up/down subdir
j    Goto file...
M-j  Goto subdir...

-- Quick --
J    Jump to bookmark...
B    Add bookmark...
b    List buffers

-- Search --
C-s  Filename I-search...
M-s  ...regexp
M-f  Find in files...

-- New --
+    New directory
F    New file

-- Shell --
!    Shell command...
&    ...async
W    Browse
")

(defconst my/mode-reference-org-text
  "Org

-- Headline --
t    TODO state...
T    Cycle TODO
s    Sort...
c    Clone...

-- Add --
a    Headline
p    Property...
:    Tags...

-- Date --
C-s  Schedule...
C-d  Deadline...
.    Add timestamp...
i    Inactive timestamp

-- Priority --
S-up/S-down  Raise/lower

-- Link --
l    Insert link...
L    Last link
r    Insert citation...

-- Clock --
M-c  Clock in

-- Display --
M    Show markup
P    Prettify
V    Line wrap
N    Heading numbers

-- Mark --
m-s  Mark subtree
m-e  Mark element
v    Copy visible

-- Misc --
n    Add note...
w    Refile...
e    Export...
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
    (unless (get-buffer-window buf)
      ;; `slot . 1', not the default (0) --- a real conflict, found by testing: `C-o''s
      ;; own Casual menu (config/init.el) ALSO shows on the right now, in the default
      ;; slot 0. Two side windows sharing one slot fight over it (whichever shows
      ;; second silently fails to display at all, confirmed directly --- its transient
      ;; keymap still captured all input even though nothing was visible, the
      ;; confusing part that took the longest to track down). A distinct slot instead
      ;; makes them genuinely coexist, stacked on the same edge, no conflict: pressing
      ;; `C-o' while this panel is already showing adds Casual's menu above it, rather
      ;; than replacing or fighting with it.
      (let ((win (display-buffer-in-side-window
                  buf '((side . right) (slot . 1) (window-width . 0.28)))))
        (when win
          (set-window-parameter win 'no-other-window t)
          (set-window-start win (with-current-buffer buf (point-min))))))))

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
        (my/mode-reference--update))
    (remove-hook 'dired-mode-hook #'my/mode-reference--update)
    (remove-hook 'org-mode-hook #'my/mode-reference--update)
    (remove-hook 'window-selection-change-functions #'my/mode-reference--update)
    (remove-hook 'window-buffer-change-functions #'my/mode-reference--update)
    (my/mode-reference--hide)))

(provide 'mode-reference)
;;; mode-reference.el ends here
