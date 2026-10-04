;;; shortcuts.el --- this config's own keybindings, grouped by topic  -*- lexical-binding: t; -*-

;; A buffer named *shortcuts* listing every key this configuration itself adds (not the
;; hundreds of built-in Emacs bindings docs/KEYBOARD.md teaches --- see that for those),
;; grouped by topic and foldable with `outline-mode', so you can collapse everything and
;; open just the one topic you want.  Shown automatically, split next to the start
;; screen, the first time Emacs opens with no file given; `C-c k' brings it back anytime.
;;
;; `my/shortcuts-list' is the one place this data lives; docs/KEYBOARD.md's own "this
;; config:" rows are the authoritative description text, and
;; tests/ert/shortcuts.el checks every key here still really runs the command it claims.
;;
;; A second section, `my/shortcuts-packages', covers packages/features with their own
;; "world" once open (Magit, Treemacs, Consult, gptel, newsticker, and this project's
;; own git-repos/start-screen/docs buffers): how to open each one, how to close it, and
;; a few important commands once inside --- including the less obvious real facts (e.g.
;; Magit's "commit"/"push"/"pull" are two-key transient chains, not one keystroke;
;; gptel-mode itself binds nothing but C-c RET). tests/ert/shortcuts.el checks these
;; against the real keymaps too (via `transient-get-suffix' for Magit's transients).
;;
;; See docs/KEYBOARD.md.

(require 'outline)
(require 'cl-lib)

(defvar my/shortcuts-buffer-name "*shortcuts*")

;; WHAT: one entry per package/feature that has its own "world" once opened, as (NAME
;; OPEN CLOSE COMMANDS).  WHY: added this session so a person can learn how to open,
;; close, and use the handful of important commands inside each package this config
;; wires in, without needing to already know Magit/Treemacs/gptel/newsticker by heart or
;; go hunting through each package's own docs.  HOW: rendered by `my/shortcuts--insert-
;; packages' below into the *shortcuts* buffer as a second, flat list of outline
;; headings, appended after the existing topic list; COMMANDS is nil for the two entries
;; (Dictation, Evil) where the same single key both opens and closes, so there is nothing
;; further to list.  Every fact here (every OPEN/CLOSE key, every COMMANDS key) is
;; checked against the real keymaps in tests/ert/shortcuts.el --- including, for Magit's
;; two-key transient chains like "c c", via `transient-get-suffix' --- so this list is
;; prose kept honest by tests, not just asserted.
(defconst my/shortcuts-packages
  '(("Magit" "C-x g (also C-c g for file-specific commands)"
     "q (magit-mode-bury-buffer; C-u q kills the buffer instead of just hiding it)"
     (("TAB" . "expand/collapse the section at point")
      ("RET" . "visit the thing at point")
      ("s" . "stage (the change at point; a file-picker prompt if point is elsewhere)")
      ("u" . "unstage (the change at point; a file-picker prompt if point is elsewhere)")
      ("c c" . "commit")
      ("P p" . "push to your pushremote")
      ("F p" . "pull from your pushremote")
      ("l l" . "log")))
    ("Treemacs" "C-c t (toggle); C-c T (reveal the current file in it)"
     "q hides it (treemacs-quit); Q fully resets it (treemacs-kill-buffer)"
     (("RET" . "open the file, or expand/collapse the folder")
      ("c f" . "create a file")
      ("c d" . "create a directory")
      ("d" . "delete the file/folder at point")
      ("R" . "rename")
      ("g or r" . "refresh")))
    ("Search (Consult)" "C-c s l / g / f / b (buffer text / project text / project files / buffers)"
     "C-g aborts; RET opens the selected one"
     (("(move the cursor)" . "a live preview follows automatically")))
    ("LLM chat (gptel)" "C-c a a"
     "no dedicated key: kill-buffer / C-x k (gptel-mode itself only binds C-c RET)"
     (("C-c RET" . "send the buffer up to point")
      ("C-c a m" . "menu: pick a model, backend or system prompt")))
    ;; WHAT: the newest package entry, for `my/llm-council' (config/llm-council.el).
    ;; WHY/HOW: unlike the other entries, both keys used here (TAB to fold/unfold, q to
    ;; close) are plain `outline-mode'/this-buffer-mode behavior rather than a real
    ;; command bound specifically by llm-council.el --- worth spelling out anyway, since
    ;; those are still the two things a person needs to know once that buffer is open.
    ("LLM council (this config)" "C-c a c"
     "q"
     (("TAB" . "expand/collapse one model's own answer")
      ("(nothing else)" . "the summary is expanded; each model's raw answer starts folded shut")))
    ("News (newsticker)" "C-c n"
     "q"
     (("n / p" . "next / previous item")
      ("RET on an item" . "show it")
      ("o" . "mark that item read")
      ("g / G" . "update this feed / every feed")))
    ;; WHAT/WHY: user request, after asking what exists in this family --- both share
    ;; the Magit-style transient-popup idea, applied to containers/a Kubernetes cluster
    ;; instead of git. `docker''s own menu (opened by the single `docker' command, the
    ;; `transient-define-prefix' in `docker-core.el') covers containers/images/volumes/
    ;; networks/contexts all from one place, the same way `magit-status' is the one
    ;; door into Magit; `kubernetes' needs a running cluster/`kubectl' to show anything
    ;; real, same as Magit needs a real git repo.
    ("Docker (this config)" "C-c K d"
     "q (transient's own stock close key, like any other transient menu)"
     (("c" . "containers submenu (list, start/stop/rm, logs, exec, shell)")
      ("i" . "images submenu (list, pull, build, rm)")
      ("v" . "volumes submenu")
      ("n" . "networks submenu")))
    ("Kubernetes (this config)" "C-c K k"
     "q"
     (("RET" . "navigate into the resource at point")
      ("l" . "logs for the resource at point")
      ("d" . "describe the resource at point")
      ("g" . "refresh")))
    ("Git repos (this config)" "C-c f p"
     "q"
     (("RET / click" . "open Magit status there")
      ("d" . "open in Dired")
      ("t" . "reveal in Treemacs")
      ("g / [rescan]" . "rescan now")))
    ("Start screen (this config)" "C-c h"
     "q"
     (("RET" . "open the file, folder or project")
      ("m / d / t" . "open it with Magit / Dired / Treemacs")
      ("1-5" . "open that recent file by number")
      ("f" . "find a file in that project/folder")))
    ("Docs buffer (this config)" "C-c d (C-c D rebuilds it)"
     "q"
     (("TAB" . "fold/unfold a heading")
      ("C-c C-n / C-c C-p" . "next / previous guide")))
    ("Shortcuts buffer (this config)" "C-c k"
     "q"
     (("TAB" . "fold/unfold a topic")))
    ("Session list (this config)" "C-c w l"
     "q"
     (("RET / click" . "switch to that buffer")
      ("g" . "refresh")))
    ("Named sessions list (this config)" "C-c w L"
     "q"
     (("RET / click" . "open that named session (replaces what's open)")
      ("d" . "delete it")
      ("g" . "refresh")))
    ("Dictation (this config)" "C-c m starts recording"
     "C-c m again stops it, transcribes, and inserts the result"
     nil)
    ("Live dictation (this config)" "C-c M starts recording"
     "C-c M again stops it --- text appears every few seconds while you speak, not only at the end"
     nil)
    ("Year calendar (this config)" "C-c y"
     "q"
     (("<" . "previous year")
      (">" . "next year")))
    ("Evil, vi keys" "C-c v turns it on"
     "C-c v again turns it off"
     nil))
  "Packages/features with their own \"world\" once open: how to open, how to close,
and a few important commands once inside.  Each entry is (NAME OPEN CLOSE COMMANDS),
COMMANDS a list of (KEY . DESCRIPTION).  The underlying facts are verified for real in
tests/ert/shortcuts.el (against the real keymaps, and via `transient-get-suffix' for
Magit's transient-based commands like \"c c\"); the text here is prose, kept in step
by hand.")

(defconst my/shortcuts-list
  '(("Finding files"
     ("C-c f f" my/ff-find-file "instant fuzzy file finder (project, or whole disk outside one)")
     ("C-c f d" my/ff-find-file-here "the same, scoped to just the current directory (recursively)")
     ("C-c f g" my/ff-find-file-global "the same over the whole disk")
     ("C-c f a" my/ff-find-file-global-async "the same, but never blocks Emacs (Consult/fd)")
     ("C-c f r" my/ff-reindex "rebuild the whole-disk file index"))
    ;; WHAT/WHY: a real gap, found by the user --- plain Dired itself (stock Emacs, not
    ;; something this config wrote) was never in this list at all, only reachable
    ;; indirectly through other topics' own sub-options (the start screen's `d', git
    ;; repos' `d'). Added directly, matching existing precedent for a useful stock
    ;; command sitting alongside custom ones in the same list (`consult-theme' under
    ;; "Themes" below is the same situation) --- `dired-jump' specifically, not just
    ;; `dired', since it opens the CURRENT file's own directory with the cursor already
    ;; on that file, the more immediately useful of the two for "I'm here, show me the
    ;; folder" rather than "prompt me for some directory."
    ("Dired"
     ("C-x C-j" dired-jump "open Dired on the current file's directory, cursor on that file")
     ("C-x d" dired "open Dired, prompting for a directory"))
    ;; WHAT/WHY: user request --- a ranger-style file manager (Miller columns: parent
    ;; directory, current listing, a live preview pane), explicitly kept separate from
    ;; plain Dired above rather than replacing it (`ranger-override-dired' stays nil;
    ;; see init.el's own comment for the real reason `dirvish', tried first, could not
    ;; offer that separation at all).
    ("File manager (ranger)"
     ("C-c R" ranger "a ranger-style file manager: parent directory, listing, live preview"))
    ("Searching"
     ("C-c s l" consult-line "search this buffer, with a live preview")
     ("C-c s g" consult-ripgrep "search project text (ripgrep), with a live preview")
     ("C-c s f" consult-fd "find a project file by name (fd); no live preview, unlike the others here --- Consult's own design: a filename search has no match location to jump to")
     ("C-c s b" consult-buffer "switch to a buffer, recent file or bookmark")
     ("C-'" avy-goto-char-timer "jump the cursor anywhere visible by typing a few characters")
     ("M-i" symbol-overlay-put "highlight every occurrence of the symbol at the cursor"))
    ("Completion (embark: actions on the thing at point/candidate)"
     ("C-." embark-act "menu of actions for the thing at point, or the current candidate")
     ("C-;" embark-dwim "run the default action directly, no menu")
     ("C-h B" embark-bindings "list every action available right now"))
    ;; WHAT/WHY: a real gap, found the same way Evil/Dired were earlier this session ---
    ;; `yas-insert-snippet'/`er/expand-region'/`er/contract-region'/`vterm' were all
    ;; bound to real keys in init.el back when the 6-package batch shipped, but never
    ;; added to THIS list, so none of them ever showed up in the Custom menu or `C-c k'
    ;; despite being fully wired up and working.
    ("Snippets"
     ("C-c Y" yas-insert-snippet "insert one of your own Yasnippet snippets by name (none bundled; M-x yas-new-snippet to write one)"))
    ("Selection"
     ("C-=" er/expand-region "grow the selection by semantic units (word, then symbol, string, statement, ...)")
     ("C-M--" er/contract-region "shrink it back one step"))
    ("Terminal"
     ("C-c V" vterm "a real terminal emulator (full curses apps: htop, vim, ssh) in a new buffer"))
    ;; WHAT/WHY: a real gap, found right after the Custom menu's own creation --- this
    ;; topic's own menu label was just "Git", and it listed only `magit-status'/`magit-
    ;; file-dispatch', not Magit itself by name, nor its own top-level command hub
    ;; (`magit-dispatch', autoloaded in init.el but never actually bound to a key until
    ;; now --- see the `C-c G' comment there). Renamed and the gap filled, same as the
    ;; Evil/Dired fixes earlier this session.
    ("Git (Magit)"
     ("C-x g" magit-status "Git status, stage and commit with single keys")
     ("C-c g" magit-file-dispatch "Git commands for this file")
     ("C-c G" magit-dispatch "Magit's own full command menu: status, log, branch, stash, everything")
     ("C-c f p" my/find-git-repos "list every git repository on this computer (indexed, instant)"))
    ("Project tree"
     ("C-c t" my/treemacs "show or hide the project file tree")
     ("C-c T" my/treemacs-reveal "show the tree and move to the current file in it"))
    ("Recent work"
     ("C-c h" my/start "the start screen: recent files, folders and projects")
     ("C-c r" recentf-open "open a recent file"))
    ("Calendar"
     ("C-c y" my/calendar-year "a real year-at-a-glance calendar, 12 months in a grid"))
    ("Editing lock"
     ("C-c e e" allow-editing "make this buffer editable")
     ("C-c e l" stop-editing "lock this buffer read-only again"))
    ("Evil, vi keys"
     ;; WHAT/WHY: a real gap, found by the user, not caught before --- `my/toggle-evil'
     ;; already existed and was already documented in `my/shortcuts-packages' (the
     ;; "world" section, `C-c k''s own second half), but was never also in THIS list,
     ;; the one the new "Custom" menu-bar menu (above) is generated from --- so it
     ;; never showed up there, or (less obviously) in `C-c k''s own flat topic list
     ;; either, only in its packages section further down. A single toggle command on
     ;; one key is exactly the shape this list already expects, unlike most of
     ;; `my/shortcuts-packages''s other entries (Magit, Treemacs, ...), whose
     ;; OPEN/CLOSE/COMMANDS fields are prose, not callable commands --- this one entry
     ;; genuinely belongs in both places, and now is.
     ("C-c v" my/toggle-evil "turn vi-style (Evil) keybindings on; C-c v again turns them off"))
    ;; WHAT/WHY: user request --- a key to turn the always-visible reference panel
    ;; (config/mode-reference.el) off, for once they're comfortable with Dired/
    ;; ranger/Treemacs and no longer need it on screen; on by default until then.
    ;; Same shape as the Evil toggle just above: one key, same command both ways.
    ("Reference panel (this config)"
     ("C-c H" my/mode-reference-mode "toggle the always-visible command-reference panel on the right (shown by default; Dired/Org/ranger/Treemacs)"))
    ("Session (crash-safe auto-save and restore)"
     ("C-c w s" my/session-save "save the session (open buffers, window layout) now")
     ("C-c w r" my/session-reset "discard it: back to the plain start screen next time")
     ("C-c w l" my/session-list "list every buffer currently part of the session")
     ("C-c w S" my/session-save-as "save the current buffers/windows as a new named session")
     ("C-c w O" my/session-open "replace what's open with a named session")
     ("C-c w D" my/session-delete "delete a named session for good")
     ("C-c w L" my/session-named-list "list every named session saved"))
    ("Documentation"
     ("C-c d" my/docs "show every guide in one buffer, built at startup")
     ("C-c D" my/docs-rebuild "rebuild it after a guide changes")
     ("C-c k" my/shortcuts "this buffer"))
    ("LLM chat"
     ("C-c a a" my/llm-chat "open a chat buffer with a local Ollama model")
     ("C-c a m" gptel-menu "pick a model, backend or system prompt")
     ;; WHAT/WHY: added this session alongside config/llm-council.el, so `C-c a c' shows
     ;; up in the flat key list (checked by tests/ert/shortcuts.el's "every listed key
     ;; really runs the command it claims" test) as well as in the packages section above.
     ("C-c a c" my/llm-council "ask 3 local models at once, summarized by a bigger one"))
    ("Windows"
     ("M-o" ace-window "jump to a window by the letter shown in it"))
    ("Themes"
     ("C-c c" my/load-theme-by-number "pick a color theme by character (press C-c c, then 1-9/a-z/A-T; 0 is the default, no theme)")
     ("C-c ." my/cycle-theme "switch to the next theme, whatever slot it's in")
     ("C-c ," my/cycle-theme-previous "switch to the previous theme, whatever slot it's in")
     ("C-c C" consult-theme "fuzzy-search any installed theme by name, with live preview"))
    ("Frame"
     ("C-c u" my/toggle-frame-chrome "hide/show the menu bar, tool bar and window decorations together")
     ("C-c U" my/reset-to-defaults "put frame and theme back to this config's own defaults, and save it"))
    ("Help"
     ("C-h f" helpful-callable "describe a command or function, richly")
     ("C-h v" helpful-variable "describe a setting, richly")
     ("C-h k" helpful-key "describe a key's command, richly")
     ("C-h o" helpful-symbol "describe anything, richly")))
  "This configuration's own keybindings, grouped by topic, as (TOPIC (KEY COMMAND
DESCRIPTION) ...).  COMMAND is only used to check the key still really runs it (see
tests/ert/shortcuts.el); the buffer itself shows only KEY and DESCRIPTION.  Kept in
step with docs/KEYBOARD.md's own \"this config:\" rows by hand; add a new command to
both places.")

;; WHAT: a real \"Custom\" menu in the menu bar, one submenu per topic above, listing
;; every command this config itself adds --- Dired/file-finding, LLM chat, git
;; repositories, Treemacs, recent files, themes, and everything else in `my/shortcuts-
;; list' --- clickable, not just a keyboard reference.
;; WHY: user request, after the mode-reference panel's own real bug this same session
;; (hand-transcribing a menu's labels, which drifted from the real commands and broke)
;; --- deliberately NOT repeating that mistake: this menu is generated directly from
;; `my/shortcuts-list', the exact same data `C-c k'/`tests/ert/shortcuts.el' already
;; keep accurate, not a second, separately hand-maintained copy that could go stale
;; the same way.  `my/shortcuts-packages' (Magit/Treemacs/etc.'s own \"how to open/
;; close/use it\" prose) is deliberately NOT also folded in here --- its OPEN/CLOSE/
;; COMMANDS fields are description strings, not real command symbols a menu item could
;; call, and the commands that open those packages in the first place (`magit-status',
;; `my/treemacs', ...) are already real entries in `my/shortcuts-list' under \"Git\"/
;; \"Project tree\", so nothing from that \"world\" is actually missing here.
;; HOW: `easy-menu-define' builds one real keymap from the vector spec below; each
;; item's REAL keybinding (`C-c f f', `C-x g', ...) is shown automatically next to its
;; label by Emacs's own menu code, straight from the live keymap --- never typed in by
;; hand here, so it can never go stale the way a hand-copied key string could.
(defun my/custom-menu--spec ()
  "Build the `easy-menu' vector spec for the \"Custom\" menu, directly from
`my/shortcuts-list'."
  (append
   '("Custom")
   (mapcar
    (lambda (topic)
      (cons (car topic)
            (mapcar (lambda (row)
                      (cl-destructuring-bind (_key command desc) row
                        (vector desc command t)))
                    (cdr topic))))
    my/shortcuts-list)))

(easy-menu-define my/custom-menu global-map "This config's own commands, by topic."
  (my/custom-menu--spec))

;; WHAT: this buffer's own keymap and major mode.  WHY/HOW: derives from `outline-mode'
;; (TAB fold/unfold, heading navigation) rather than `special-mode' --- same choice, and
;; same reason, as `my/llm-council-mode'/`my/docs-mode'; `outline-mode' has no `special-
;; mode' ancestry at all, so unlike `my/start-mode'/`my/git-repos-mode' (which get `q' for
;; free by inheriting `special-mode-map'), it has to be bound by hand here --- see
;; docsbuffer.el's own comment on its matching `my/docs-mode-map' for the fuller version of
;; this same point, about these being the two buffers in this config needing that.
;; `outline-regexp' is set to match this buffer's own "* NAME" heading style, the same one
;; every other outline-derived buffer here uses.
(defvar my/shortcuts-mode-map
  (let ((m (make-sparse-keymap)))
    (set-keymap-parent m outline-mode-map)
    (define-key m "q" #'quit-window)
    m))

(define-derived-mode my/shortcuts-mode outline-mode "Shortcuts"
  "This configuration's own keybindings, grouped by topic.  See `my/shortcuts'."
  (setq-local outline-regexp "\\* ")
  (setq-local buffer-read-only t))

;; WHAT: write the whole *shortcuts* buffer's text: title, a short usage reminder, the flat
;; per-topic key list built straight from `my/shortcuts-list', then (see the comment a few
;; lines down) the separate packages section built from `my/shortcuts-packages'.  WHY: kept
;; as one function, called once per redraw from `my/shortcuts-buffer' below, rather than two
;; functions called separately by that caller --- the usual "always rebuild the whole buffer
;; from the data model in one place" pattern this config uses throughout.
(defun my/shortcuts--insert ()
  (insert (propertize "This config's keybindings\n\n" 'face '(:height 1.2 :weight bold)))
  (insert "  TAB folds a topic; RET/click on a topic also works.  See docs/KEYBOARD.md\n")
  (insert "  for what every built-in Emacs key does too.\n\n")
  (dolist (topic my/shortcuts-list)
    (insert (format "* %s\n" (car topic)))
    (dolist (row (cdr topic))
      (insert (format "  %-10s %s\n" (nth 0 row) (nth 2 row))))
    (insert "\n"))
  ;; WHAT/WHY: the second section's own header, then its actual content --- added this
  ;; session; everything above this point in the function is the original, pre-existing
  ;; flat topic list untouched.
  (insert (propertize "Packages: how to open, how to close, and what to do once inside\n\n"
                      'face '(:weight bold)))
  (my/shortcuts--insert-packages))

;; WHAT: render `my/shortcuts-packages' (above) into the current buffer.  WHY: kept as
;; its own function (called from `my/shortcuts--insert') so the two sections --- the
;; original flat key list, and this newer packages section --- stay clearly separate
;; both in the buffer's own layout and in this file's code.  HOW: one outline heading
;; ("* NAME") per package, then its Open/Close lines always shown, then --- only when
;; COMMANDS is non-nil (it's nil for Dictation/Evil, see the defconst's own comment) ---
;; an indented "Once inside:" block listing each key/description pair, padded to a fixed
;; column with `%-22s' so the descriptions line up regardless of key length.
(defun my/shortcuts--insert-packages ()
  (dolist (pkg my/shortcuts-packages)
    ;; WHAT/HOW: `cl-destructuring-bind' unpacks each 4-element list entry directly into
    ;; four named locals in one step, instead of four separate `nth' calls.
    (cl-destructuring-bind (name open close commands) pkg
      (insert (format "* %s\n" name))
      (insert (format "  Open:  %s\n" open))
      (insert (format "  Close: %s\n" close))
      (when commands
        (insert "  Once inside:\n")
        (dolist (c commands)
          (insert (format "    %-22s %s\n" (car c) (cdr c)))))
      (insert "\n"))))

;;;###autoload
(defun my/shortcuts-buffer ()
  "Return the *shortcuts* buffer, freshly drawn."
  (let ((buf (get-buffer-create my/shortcuts-buffer-name)))
    (with-current-buffer buf
      (let ((inhibit-read-only t))
        (unless (derived-mode-p 'my/shortcuts-mode) (my/shortcuts-mode))
        (erase-buffer)
        (my/shortcuts--insert)
        (goto-char (point-min))
        (set-buffer-modified-p nil)))
    buf))

;;;###autoload
(defun my/shortcuts ()
  "Show this configuration's own keybindings, grouped by topic."
  (interactive)
  (switch-to-buffer (my/shortcuts-buffer)))

(defun my/shortcuts--maybe-show-at-startup ()
  "Split the frame and show *shortcuts* next to the start screen, but only when the
start screen is what actually opened (not when files were given on the command line),
and only into a single, unsplit window (never fight a layout already in progress)."
  (when (and (eq (window-buffer) (get-buffer "*start*")) (one-window-p t))  ; startpage.el's own buffer name
    (let ((main (selected-window)))
      (select-window (split-window main nil 'right))
      (switch-to-buffer (my/shortcuts-buffer))
      (select-window main))))
(add-hook 'emacs-startup-hook #'my/shortcuts--maybe-show-at-startup 60)

(provide 'shortcuts)
;;; shortcuts.el ends here
