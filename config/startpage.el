;;; startpage.el --- start screen: recent files, folders and projects  -*- lexical-binding: t; -*-

;; The screen Emacs opens on when started without a file, and `C-c h' from anywhere.
;; It lists the last few files, folders and projects you worked in, each one a link
;; (RET, or a click), with a "+ N more" link that expands the list in place.
;; Files come from `recentf'.  Folders and projects are remembered here, in
;; `my/start-store-file', as you open files and Dired buffers.  No package is used.

;; WHAT: Emacs's built-in "remember recently opened files" library.  WHY: this is where
;; the Files section's data comes from --- deliberately NOT reimplemented here, since
;; Emacs already tracks it well; this file only adds the analogous tracking for folders
;; and projects, which `recentf' itself has no concept of.  HOW: gives us `recentf-list'.
(require 'recentf)
;; WHAT: Emacs's built-in clickable-link library.  WHY: every entry, the "+ N more"
;; toggle, and the section headings are all real buttons.  HOW: `insert-text-button',
;; `button-at', `button-get'.
(require 'button)
;; WHAT: a small built-in library for finding text with a given text property.  WHY:
;; used by `my/start--toggle' below to relocate the cursor onto the right toggle link
;; after expanding/collapsing a section, even though the buffer was just fully redrawn
;; and every position shifted.  HOW: gives us `text-property-search-forward'.
(require 'text-property-search)

;; WHAT: how many entries a collapsed section shows.  WHY: 5 keeps the start screen
;; short and scannable at a glance, matching the "last 5" language in the file header
;; comment; also directly reused elsewhere --- `1'-`5' are bound to open a numbered file
;; (see the keymap below) precisely because there are always at most this many visible.
(defvar my/start-count 5 "How many entries each section shows when collapsed.")
;; WHAT: how many entries a section shows once expanded (`[+ N more]' clicked).  WHY:
;; capped at 25 rather than "everything", since showing an unbounded history would make
;; the expanded view unwieldy and isn't really more useful past a couple dozen entries.
(defvar my/start-expanded-count 25 "How many entries each section shows when expanded.")
;; WHAT: how many folders/projects are kept in the on-disk history at all (not just how
;; many are shown).  WHY: a generous cushion above `my/start-expanded-count' --- keeping
;; more than will ever be displayed means older entries survive being pruned even if the
;; user doesn't revisit them again for a while, without the store file growing unbounded.
(defvar my/start-keep 60 "How many folders and projects are remembered.")
;; WHAT: regexps matched against a path to decide if it should ever be remembered/shown
;; at all.  WHY: keeps genuinely uninteresting or noisy paths --- temp directories, `.git'
;; internals, this project's own installed packages/native-compile cache/backups, system
;; paths --- out of the history entirely, rather than filtering them only at display time
;; (which would still waste one of the limited `my/start-keep' history slots on them).
(defvar my/start-ignore
  '("\\`/tmp/" "\\`/var/tmp/" "/\\.git/" "/COMMIT_EDITMSG\\'" "\\`/proc/" "\\`/sys/"
    "/elpa/" "/eln-cache/" "/backups/" "/auto-save-list/" "\\`/usr/share/emacs/")
  "Paths matching any of these regexps are never remembered or shown.")
;; WHAT: file names whose presence in a folder marks it as a "project root".  WHY: this
;; is how the Projects section is derived from the Folders one --- opening a file three
;; levels deep inside a git checkout should record the checkout's own root as a project,
;; not just the immediate containing folder.  HOW: covers this project's own ecosystem
;; (git/Mercurial) plus the common build-tool markers (Maven, Gradle, Cargo, npm/Node).
(defvar my/start-project-markers '(".git" ".hg" "pom.xml" "build.gradle" "Cargo.toml" "package.json")
  "A folder holding any of these counts as a project root.")
;; WHAT: where the folder/project history is saved on disk.  WHY: lets the start screen
;; show real history immediately on a fresh Emacs start, not just after this session has
;; opened something --- the same reasoning as `my/git-repos-store-file' in gitfolders.el.
(defvar my/start-store-file (locate-user-emacs-file "recents.eld")
  "Where the folder and project history is saved.")

;; WHAT: the in-memory folder history, newest first.  WHY/HOW: not buffer-local --- there
;; is exactly one such list for the whole Emacs session, same reasoning as `my/git-
;; repos--list' in gitfolders.el.
(defvar my/start--folders nil "Recent folders, newest first.")
;; WHAT/WHY/HOW: the in-memory project-root history, same shape and reasoning as the
;; folders list just above, just for project roots (as computed by `my/start--project-
;; root') instead of every folder visited.
(defvar my/start--projects nil "Recent project roots, newest first.")
;; WHAT: guards `my/start--load' so the store file is only actually read once per
;; session.  WHY/HOW: same "load once, reuse in memory after that" pattern as `my/git-
;; repos--loaded' in gitfolders.el.
(defvar my/start--loaded nil)
;; WHAT: whether the in-memory history has changed since it was last written to disk.
;; WHY: `my/start-save' (below) is called from more than one place (an idle timer, on
;; Emacs exit) --- this flag means a save that has nothing new to write is a cheap no-op
;; instead of an unconditional disk write every single time one of those triggers fires.
(defvar my/start--dirty nil)
;; WHAT: which of the three sections (`files'/`folders'/`projects') are currently shown
;; expanded rather than collapsed.  WHY: this is genuine UI state, distinct from the data
;; itself --- toggling one section's "+ N more" must not affect the other two, and must
;; survive a redraw (the whole buffer is rebuilt from scratch on every refresh, see `my/
;; start-refresh' below, so this can't just be inferred from what's currently on screen).
(defvar my/start--expanded nil "Sections currently expanded: a list of `files', `folders', `projects'.")

;;; Remembering ---------------------------------------------------------------

;; WHAT/WHY/HOW: true if PATH matches any regexp in `my/start-ignore' --- the one check
;; used both when deciding whether to remember a new path at all (`my/start-remember')
;; and, redundantly but cheaply, again when collecting entries to display (`my/start--
;; live'), in case the ignore list itself changed since something was recorded.
(defun my/start--ignored-p (path)
  (let ((case-fold-search nil))
    (seq-some (lambda (re) (string-match-p re path)) my/start-ignore)))

;; WHAT: read the saved folder/project history into memory, once.  WHY/HOW: same
;; "idempotent, `ignore-errors'-wrapped, tolerant of a corrupted file" pattern as `my/
;; git-repos--load' in gitfolders.el; `alist-get' pulls the `folders'/`projects' keys
;; back out of the saved alist shape (see `my/start-save' below for the matching write),
;; and `seq-filter #'stringp' discards anything that isn't actually a string, in case the
;; file's contents are unexpected in some way.
(defun my/start--load ()
  (unless my/start--loaded
    (setq my/start--loaded t)
    (when (file-readable-p my/start-store-file)
      (let ((data (ignore-errors
                    (with-temp-buffer (insert-file-contents my/start-store-file)
                                      (read (current-buffer))))))
        (setq my/start--folders (seq-filter #'stringp (alist-get 'folders data))
              my/start--projects (seq-filter #'stringp (alist-get 'projects data)))))))

;; WHAT: write the folder/project history back to disk.  WHY: called from an idle timer
;; and on Emacs exit (see the hooks below) rather than on every single `my/start-remember'
;; call, since that would mean a disk write on literally every file opened; the `--dirty'
;; check (see its own comment above) means even those periodic calls are a no-op unless
;; something genuinely changed since the last save.  HOW: `prin1' writes a plain alist,
;; exactly the shape `my/start--load' above expects to `read' back.
(defun my/start-save ()
  "Write the folder and project history to disk."
  (when (and my/start--loaded my/start--dirty)
    (setq my/start--dirty nil)
    (ignore-errors
      (with-temp-file my/start-store-file
        (prin1 `((folders . ,my/start--folders) (projects . ,my/start--projects))
               (current-buffer))))))

;; WHAT: move DIR to the front of the list held in the variable named by PLACE (a symbol,
;; e.g. `my/start--folders'), capped to `my/start-keep' entries.  WHY: this is the one
;; shared "record a most-recently-used entry" operation both folders and projects use.
;; HOW: `delete dir (copy-sequence ...)' removes any existing occurrence of DIR first (so
;; re-visiting an already-known folder moves it to the front rather than creating a
;; duplicate), `cons dir' puts it back at the very front, and `seq-take' enforces the cap;
;; `set place ...' (not `setq') is what lets this function work generically on whichever
;; variable PLACE names, since PLACE is only known at call time, not at compile time.
(defun my/start--push (place dir)
  "Move DIR to the front of the list stored in the symbol PLACE."
  (let ((l (cons dir (delete dir (copy-sequence (symbol-value place))))))
    (set place (seq-take l my/start-keep))
    (setq my/start--dirty t)))

;; WHAT: find DIR's project root, or nil if it isn't inside a recognized project at all.
;; WHY: this is how a folder visit turns into a project-history entry too.  HOW: checks
;; every marker in `my/start-project-markers' via `locate-dominating-file' (which walks
;; upward from DIR looking for that marker); among however many markers actually match at
;; different ancestor levels, the NEAREST one to DIR wins (the inline comment explains
;; why: `(> (length r) (length found))' --- a longer matched path is a closer ancestor,
;; since parent paths are shorter than their descendants), so a git repo nested inside a
;; folder that also happens to have, say, a stray `package.json' several levels up
;; correctly resolves to the git repo, not that unrelated outer folder.  The user's own
;; home directory is explicitly never treated as a project root, even if it happens to
;; contain one of the marker files, since that would make nearly everything "the home
;; directory project" and defeat the point.
(defun my/start--project-root (dir)
  (let (found)
    (dolist (m my/start-project-markers)
      (let ((r (locate-dominating-file dir m)))
        ;; the nearest marker wins, and the home folder is never a project
        (when (and r (or (null found) (> (length r) (length found))))
          (setq found r))))
    (and found (not (equal (expand-file-name found) (expand-file-name "~/")))
         (file-name-as-directory (expand-file-name found)))))

;; WHAT: record DIR as a recently visited folder, and (if applicable) its project root
;; as a recently visited project.  WHY: this is the single entry point both hooks below
;; (opening a file, entering Dired) funnel through.  HOW: only proceeds for a real,
;; local (not `file-remote-p' --- a TRAMP/remote path would be slow and often
;; inappropriate to record here), existing directory; normalizes DIR to an absolute,
;; slash-terminated form first (so the same folder is never recorded under two visually
;; different path spellings); checks the ignore list before recording either the folder
;; itself or (separately, since a folder could be ignore-listed while sitting inside an
;; otherwise-fine project, or vice versa) its derived project root.
(defun my/start-remember (dir)
  "Record DIR as a recent folder, and its project root as a recent project."
  (when (and (stringp dir) (not (file-remote-p dir)) (file-directory-p dir))
    (my/start--load)
    (let ((dir (file-name-as-directory (expand-file-name dir))))
      (unless (my/start--ignored-p dir)
        (my/start--push 'my/start--folders dir)
        (when-let* ((root (my/start--project-root dir)))
          (unless (my/start--ignored-p root)
            (my/start--push 'my/start--projects root)))))))

;; WHAT/WHY/HOW: record the containing folder of whatever file was just opened, as long
;; as this buffer actually corresponds to a real file (`buffer-file-name' is nil for,
;; e.g., a `*scratch*'-style buffer) --- hooked onto `find-file-hook' below.
(defun my/start--on-find-file ()
  (when buffer-file-name
    (my/start-remember (file-name-directory buffer-file-name))))

;; WHAT/WHY/HOW: record whatever folder a Dired buffer was just opened on --- hooked onto
;; `dired-mode-hook' below, the Dired-specific equivalent of `my/start--on-find-file'.
(defun my/start--on-dired ()
  (my/start-remember default-directory))

;; WHAT/WHY/HOW: wire the two recorder functions above into the moments they need to
;; fire (opening any file; entering any Dired buffer); make sure the history is actually
;; saved to disk before Emacs exits (`kill-emacs-hook'); and, since that alone would mean
;; a crash or forced-kill could lose everything recorded in a long session, also save
;; periodically whenever Emacs has been idle for 30 seconds (`run-with-idle-timer ... t
;; ...', the `t' meaning "repeat every time this idle threshold is reached again", not
;; just once) --- cheap thanks to the `--dirty' short-circuit in `my/start-save' itself.
(add-hook 'find-file-hook #'my/start--on-find-file)
(add-hook 'dired-mode-hook #'my/start--on-dired)
(add-hook 'kill-emacs-hook #'my/start-save)
(run-with-idle-timer 30 t #'my/start-save)

;;; Collecting ----------------------------------------------------------------

;; WHAT: the first N entries of PATHS that PRED accepts and that aren't ignored.  WHY:
;; this is the shared "give me N still-valid, still-relevant entries" filter used by
;; `my/start--entries' below for all three sections --- a saved path might no longer
;; exist (moved, deleted) or might now match the ignore list even though it didn't when
;; recorded, so this check happens fresh at DISPLAY time, not just once at record time.
;; HOW: walks PATHS in order, stopping as soon as N accepted entries have been collected
;; (so it never does more filesystem-existence checking than actually necessary, even if
;; the full history is much longer than N).
(defun my/start--live (paths n pred)
  "The first N of PATHS that PRED accepts and that are not ignored."
  (let (out (k 0))
    (while (and paths (< k n))
      (let ((p (pop paths)))
        (when (and (not (my/start--ignored-p p)) (funcall pred p))
          (push p out) (setq k (1+ k)))))
    (nreverse out)))

;; WHAT: every remembered path of KIND, newest first, with no existence filtering yet
;; (that's `my/start--live's job).  WHY: separates "what does the raw history say" from
;; "what's actually still valid to show", so the two concerns don't get tangled together.
;; HOW, per KIND: `files' reads straight from `recentf-list' itself (this section has no
;; separate storage of its own, `recentf' already IS the storage), filtering out any
;; entry that's actually a directory (a slash-terminated `recentf' entry, which can
;; happen) since this section is files only, folders belonging to the Folders section;
;; `folders'/`projects' return the in-memory lists tracked by this file, but --- and this
;; is the first-run fallback --- if either list is still empty (a brand new Emacs config,
;; before this file's own tracking has had a chance to record anything yet), they're
;; instead DERIVED from whatever `recentf-list' already has, via `my/start--derive'
;; below, so the start screen isn't empty and useless on the very first run.
(defun my/start--all (kind)
  "All remembered paths of KIND (`files', `folders' or `projects'), newest first."
  (my/start--load)
  (pcase kind
    ('files (seq-filter (lambda (f) (not (string-suffix-p "/" f)))
                        (mapcar #'expand-file-name (seq-filter #'stringp (bound-and-true-p recentf-list)))))
    ('folders (or my/start--folders (my/start--derive #'file-name-directory)))
    ('projects (or my/start--projects
                   (delete-dups (delq nil (mapcar #'my/start--project-root (my/start--derive #'identity))))))))

;; WHAT: derive a folder-like list from `recentf-list' by applying FN to each entry.
;; WHY: the first-run fallback described just above --- `my/start--all' calls this with
;; `#'file-name-directory' to get "the folder each recent file was in" (for the Folders
;; section's fallback), or `#'identity' to get "each recent file itself" (immediately fed
;; through `my/start--project-root' by the Projects section's own fallback, one caller up
;; in `my/start--all').  HOW: filters to real strings only, normalizes each to an
;; absolute, slash-terminated form, and removes duplicates.
(defun my/start--derive (fn)
  "Folders derived from `recentf-list', for a first run with no history yet."
  (delete-dups (delq nil (mapcar (lambda (f) (and (stringp f) (funcall fn f)
                                                  (file-name-as-directory
                                                   (expand-file-name (funcall fn f)))))
                                 (bound-and-true-p recentf-list)))))

;; WHAT/WHY/HOW: the actual function `my/start--insert-section' (below) calls to get what
;; to display --- combines `my/start--all' (the raw, unfiltered history for KIND) with
;; `my/start--live' (existence + ignore-list filtering, capped at N), using `file-exists-
;; p' for files but `file-directory-p' for folders/projects (a file could be replaced by
;; a directory of the same name, or vice versa, however unlikely --- using the right
;; predicate for each kind keeps that edge case handled correctly).
(defun my/start--entries (kind n)
  (my/start--live (my/start--all kind) n
                  (if (eq kind 'files) #'file-exists-p #'file-directory-p)))

;;; Drawing -------------------------------------------------------------------

;; WHAT/WHY/HOW: two small faces used throughout this buffer --- `my/start-heading' for
;; the three section titles (inherits the keyword-highlighting face, bolded), `my/start-
;; dir' for de-emphasized secondary text (a file's containing folder, the "nothing yet"
;; placeholder) via the standard `shadow' face.
(defface my/start-heading '((t :inherit font-lock-keyword-face :weight bold)) "Section headings.")
(defface my/start-dir '((t :inherit shadow)) "The folder part of an entry.")

;; WHAT: this buffer's own keymap.  WHY/HOW: inherits from `special-mode-map' (so `q'
;; closes it, along with every other standard read-only-buffer binding, for free ---
;; unlike `my/docs-mode'/`my/shortcuts-mode', which derive from `outline-mode' and have
;; no such inherited `q'); RET and TAB/backtab are rebound to the standard button-
;; navigation commands (`push-button'/`forward-button'/`backward-button') so this reads
;; naturally as a list of links; `n'/`p' are added as plain-letter aliases for TAB/
;; backtab, matching this config's general "n/p move" convention seen elsewhere (e.g.
;; newsticker); `g' refreshes; `f'/`m'/`d'/`t' open the entry at point with the fast
;; finder/Magit/Dired/Treemacs respectively; and the `dotimes' loop binds the digit keys
;; `1' through `5' (matching `my/start-count', the number of entries shown collapsed) to
;; jump straight to that numbered file.
(defvar my/start-mode-map
  (let ((m (make-sparse-keymap)))
    (set-keymap-parent m special-mode-map)
    (define-key m (kbd "RET") #'push-button)
    (define-key m (kbd "TAB") #'forward-button)
    (define-key m (kbd "<backtab>") #'backward-button)
    (define-key m "n" #'forward-button)
    (define-key m "p" #'backward-button)
    (define-key m "g" #'my/start-refresh)
    (define-key m "f" #'my/start-find-in-project)
    (define-key m "m" #'my/start-open-magit)
    (define-key m "d" #'my/start-open-dired)
    (define-key m "t" #'my/start-open-treemacs)
    (dotimes (i 5) (define-key m (number-to-string (1+ i)) #'my/start-open-nth-file))
    m))

;; WHAT: the major mode for the start screen.  WHY/HOW: derives from `special-mode';
;; `cursor-type nil' hides the cursor entirely (this is a link-driven, not a text-
;; editing, buffer --- there's nothing meaningful to place a text cursor "in"), line
;; numbers are turned off (irrelevant clutter for a short, fixed layout like this), and
;; `truncate-lines t' stops a long absolute path from wrapping awkwardly onto a second
;; visual line.
(define-derived-mode my/start-mode special-mode "Start"
  "The start screen: recent files, folders and projects."
  (setq-local cursor-type nil)
  (display-line-numbers-mode -1)
  (setq-local truncate-lines t))

;; WHAT: the button `action' for RET/click on an entry.  WHY/HOW: reads back the path and
;; kind stored on the button (set in `my/start--insert-section' below); a `files' entry
;; opens the file directly, anything else (`folders'/`projects') opens Dired on it ---
;; RET always means "the natural thing for what this line represents", never a generic
;; "open in Dired" for a file.
(defun my/start--open (button)
  (let ((path (button-get button 'my-path)) (kind (button-get button 'my-kind)))
    (pcase kind
      ('files (find-file path))
      (_ (dired path)))))

;;; Opening an entry with Magit, Dired or Treemacs directly (`m', `d', `t'): the same
;;; three actions as on the git-repos list (see gitfolders.el), reached the same way
;;; --- the cursor on an entry, then one key --- but working here on whichever folder
;;; is relevant: the entry itself for a folder or project, or its containing folder
;;; for a file, since RET on a file always opens the file itself, never Dired on it.

;; WHAT: the directory relevant to the entry at point --- itself for a folder/project
;; entry, its containing folder for a file entry.  WHY: shared by `m'/`d'/`t' below, the
;; same "resolve once, three commands use it" pattern as `my/git-repos--dir-at-point' in
;; gitfolders.el.  HOW: reads the button's stored path and kind; for `files' specifically,
;; strips the file name off to get its directory instead.
(defun my/start--dir-at-point ()
  (when-let* ((b (button-at (point))))
    (let ((path (button-get b 'my-path)) (kind (button-get b 'my-kind)))
      (if (eq kind 'files) (file-name-directory path) path))))

;; WHAT/WHY/HOW: reveal DIR in Treemacs --- byte-for-byte the same logic as `my/git-
;; repos--open-treemacs' in gitfolders.el (declines clearly if Treemacs isn't installed;
;; adds DIR as a Treemacs project first if it isn't already one; ensures the Treemacs
;; window is visible; selects it and jumps straight to DIR's node).  Kept as a separate,
;; near-identical copy here rather than shared code, matching how this project generally
;; keeps each feature file self-contained rather than introducing cross-file coupling for
;; a handful of duplicated lines.
(defun my/start--open-treemacs (dir)
  "Reveal DIR in Treemacs, adding it as a project first if it is not one already."
  (if (not (locate-library "treemacs"))
      (message "Treemacs is not installed.  Run ./build.sh packages")
    (require 'treemacs)
    (let ((path (treemacs-canonical-path dir)))
      (unless (treemacs--find-project-for-path path)
        (treemacs-do-add-project-to-workspace path (file-name-nondirectory (directory-file-name dir))))
      (unless (eq (treemacs-current-visibility) 'visible) (treemacs))
      (treemacs-select-window)
      (treemacs-goto-file-node path))))

;; WHAT: `m' --- open Magit status for the entry at point.  WHY/HOW: falls back to Dired
;; if Magit isn't installed (same "never a hard requirement" pattern used everywhere else
;; in this config that touches Magit); a friendly message, not an error, if point isn't
;; actually on an entry.
(defun my/start-open-magit ()
  "Open Magit status for the entry at point (its folder, for a file)."
  (interactive)
  (if-let* ((dir (my/start--dir-at-point)))
      (if (fboundp 'magit-status) (magit-status dir) (dired dir))
    (message "Put the cursor on an entry first")))

;; WHAT/WHY/HOW: `d' --- open Dired on the entry at point; same "friendly message if
;; point is in the wrong place" pattern as every other point-relative command here.
(defun my/start-open-dired ()
  "Open Dired on the entry at point (its folder, for a file)."
  (interactive)
  (if-let* ((dir (my/start--dir-at-point))) (dired dir)
    (message "Put the cursor on an entry first")))

;; WHAT/WHY/HOW: `t' --- reveal the entry at point in Treemacs; same pattern again.
(defun my/start-open-treemacs ()
  "Reveal the entry at point in Treemacs (its folder, for a file)."
  (interactive)
  (if-let* ((dir (my/start--dir-at-point))) (my/start--open-treemacs dir)
    (message "Put the cursor on an entry first")))

;; WHAT: the button `action' for a "[+ N more]"/"[- show fewer]" toggle.  WHY: this is
;; what implements expanding/collapsing one section in place.  HOW: flips whether KIND
;; (the section this particular toggle button belongs to, stored on the button itself) is
;; a member of `my/start--expanded' --- `delq' removes it (collapsing) if already there,
;; `cons' adds it (expanding) if not; `my/start-refresh' then fully redraws the buffer
;; reflecting the new state (see that function's own comment for why a full redraw,
;; rather than a targeted in-place edit, is the chosen approach here too).  Since a full
;; redraw invalidates every previous button position, the cursor is then explicitly
;; relocated: `text-property-search-forward' finds the FIRST position (from the top)
;; tagged with a `my-toggle' property equal to this same KIND --- i.e. this exact section's
;; own toggle link, wherever it landed in the freshly-redrawn buffer --- so the user's
;; cursor ends up right back on the button they just activated, not snapped to the top of
;; the whole buffer.
(defun my/start--toggle (button)
  (let ((kind (button-get button 'my-kind)))
    (setq my/start--expanded (if (memq kind my/start--expanded)
                                 (delq kind my/start--expanded)
                               (cons kind my/start--expanded)))
    (my/start-refresh)
    (goto-char (point-min))
    (when-let* ((m (text-property-search-forward 'my-toggle kind t)))
      (goto-char (prop-match-beginning m)))))

;; WHAT: draw one whole section (its heading, its entries or an empty-state message, and
;; its expand/collapse toggle if relevant).  WHY: this is the one function all three
;; sections (Files/Folders/Projects) share, called once per KIND from `my/start-refresh'
;; below.  HOW: `expanded' checks this section's own membership in `my/start--expanded';
;; `total' is the FULL count (for deciding whether a toggle is even needed, and for the
;; "[+ N more]" label's arithmetic), while `shown' is the actually-filtered, capped list
;; to display (`my/start--entries', capped to either the expanded or collapsed count
;; depending on `expanded').  If there's nothing to show at all, a plain de-emphasized
;; placeholder message explains why instead of just leaving a blank, confusing gap.
;; Otherwise, each entry gets: an optional leading digit (`1'-`5', ONLY for the Files
;; section's first five entries --- `(and (eq kind 'files) (<= i 5))' --- matching the
;; digit-key bindings in the keymap above, so what's printed always matches what pressing
;; that digit actually does); a clickable button showing the entry's own base name (the
;; file/folder name, not its full path --- `directory-file-name' strips a trailing slash
;; first so a folder's OWN name, not an empty string, is what's extracted); and, in a
;; de-emphasized face, its abbreviated containing folder path for context (`abbreviate-
;; file-name' shortens something like the user's home directory to "~").  Finally, if
;; there's more to show than the collapsed count OR this section is currently expanded
;; (so the "show fewer" link stays available once expanded, even if collapsing would
;; itself then drop back below the always-a-toggle threshold), a toggle link is added,
;; its label computed from whichever state it's currently in.
(defun my/start--insert-section (kind title)
  (let* ((expanded (memq kind my/start--expanded))
         (total (length (my/start--all kind)))
         (shown (my/start--entries kind (if expanded my/start-expanded-count my/start-count)))
         (i 0))
    (insert "  " (propertize title 'face 'my/start-heading) "\n")
    (if (null shown)
        (insert "    " (propertize "nothing yet: open a file or folder and it shows up here" 'face 'my/start-dir) "\n")
      (dolist (p shown)
        (setq i (1+ i))
        (let* ((name (if (eq kind 'files) (file-name-nondirectory p)
                       (file-name-nondirectory (directory-file-name p))))
               (dir (abbreviate-file-name (file-name-directory (directory-file-name p)))))
          (insert "   " (if (and (eq kind 'files) (<= i 5)) (propertize (number-to-string i) 'face 'my/start-dir) " ") " ")
          (insert-text-button (if (string-empty-p name) p name)
                              'action #'my/start--open 'follow-link t 'my-path p 'my-kind kind
                              'help-echo p)
          (insert "  " (propertize dir 'face 'my/start-dir) "\n"))))
    (when (or expanded (> total my/start-count))
      (insert "     ")
      (insert-text-button
       (if expanded "[- show fewer]"
         (format "[+ %d more]" (- (min total my/start-expanded-count) my/start-count)))
       'action #'my/start--toggle 'follow-link t 'my-kind kind 'my-toggle kind
       'help-echo "expand or collapse this list")
      (insert "\n"))
    (insert "\n")))

;; WHAT: redraw the whole start screen from scratch.  WHY: bound to `g'; also the last
;; step of `my/start-buffer' below (so opening the screen always shows current data);
;; same "always rebuild the visible text from the data model" strategy used throughout
;; this config.  HOW: `inhibit-read-only' permits the rewrite; the cursor's line number
;; is remembered and restored afterward (same technique, and same "land on the nearest
;; button rather than plain text" nudge, as `my/git-repos--redraw' in gitfolders.el);
;; draws the page title, then each of the three sections in a fixed order (Files,
;; Folders, Projects) via `my/start--insert-section'; then a fixed block of key-hint
;; lines at the bottom, built from a small literal table of (KEY LABEL KEY LABEL ...)
;; rows so the actual formatting/spacing logic (bold key names, spacing between pairs)
;; is written only once and applied uniformly to every hint line.
(defun my/start-refresh ()
  "Redraw the start screen."
  (interactive)
  (let ((inhibit-read-only t) (line (line-number-at-pos)))
    (erase-buffer)
    (insert "\n  " (propertize "Recent work" 'face '(:height 1.3 :weight bold)) "\n\n")
    (my/start--insert-section 'files "Files")
    (my/start--insert-section 'folders "Folders")
    (my/start--insert-section 'projects "Projects")
    (dolist (l '(("RET" "open" "TAB" "next link" "g" "refresh" "q" "close")
                 ("1-5" "open that file" "f" "find a file in this project")
                 ("m" "Magit" "d" "Dired" "t" "Treemacs (any entry)")
                 ("C-c h" "back to this screen" "C-c f f" "find any file")))
      (insert "  ")
      (while l (insert (propertize (pop l) 'face 'bold) " " (pop l) (if l "   " "")))
      (insert "\n"))
    (goto-char (point-min))
    (forward-line (max 0 (1- line)))
    (unless (button-at (point)) (ignore-errors (forward-button 1)))))

;; WHAT: open the file corresponding to whichever digit key (1-5) was just pressed.  WHY:
;; the actual command all five digit-key bindings in the keymap above point to (a single
;; shared command, not five near-identical ones) --- it figures out WHICH digit was
;; pressed from the key event itself rather than needing five separate closures.  HOW:
;; `(this-command-keys)' is the key sequence that invoked this command (a string here,
;; since it's a single plain character key); subtracting the character code of `?0'
;; converts that character ("1".."5") into the actual integer 1-5; that then indexes
;; (0-based, hence `1-' n) into the same `my/start-count'-sized Files list the section
;; itself displayed, so the number pressed always matches the number that was shown next
;; to that file.  A friendly message, not an error, if that numbered file doesn't
;; currently exist (e.g. fewer than 5 files are in the history yet).
(defun my/start-open-nth-file ()
  "Open the file whose number (1 to 5) was typed."
  (interactive)
  (let* ((n (- (aref (this-command-keys) 0) ?0))
         (f (nth (1- n) (my/start--entries 'files my/start-count))))
    (if f (find-file f) (message "No file number %d yet" n))))

;; WHAT: `f' --- on a project or folder entry, open the fast finder scoped to it.  WHY:
;; lets you jump from "here's a project I recently worked in" straight to "find a
;; specific file inside it" in two keystrokes, without first switching buffers/directories
;; by hand.  HOW: only makes sense on a `projects'/`folders' entry (not `files' --- a file
;; entry IS already a specific file, there's nothing to "find within" it); temporarily
;; let-binds `default-directory' to that entry's own path so `my/ff-find-file' (fastfind.el)
;; searches scoped to exactly that folder/project when invoked.
(defun my/start-find-in-project ()
  "On a project line, find a file in that project with the fast finder."
  (interactive)
  (let ((b (button-at (point))))
    (if (and b (memq (button-get b 'my-kind) '(projects folders)))
        (let ((default-directory (button-get b 'my-path))) (call-interactively #'my/ff-find-file))
      (message "Put the cursor on a project or folder line first"))))

;; WHAT: return the start screen buffer, freshly drawn.  WHY: the shared building block
;; both `my/start-initial-buffer' (startup) and `my/start' (`C-c h') below call --- always
;; ends with a `my/start-refresh', so no caller can accidentally show stale content.
;; HOW: reuses the single `*start*' buffer if it already exists (only switching on the
;; major mode the first time, as usual), otherwise creates it.
;;;###autoload
(defun my/start-buffer ()
  "Return the start screen buffer, freshly drawn."
  (let ((buf (get-buffer-create "*start*")))
    (with-current-buffer buf
      (unless (derived-mode-p 'my/start-mode) (my/start-mode))
      (my/start-refresh))
    buf))

;; WHAT: the function config/init.el points `initial-buffer-choice' at (see that file's
;; own comment on why a function, not a fixed buffer, is used there).  WHY: Emacs's own
;; startup sequence calls this AFTER it has already opened any files named on the command
;; line --- so this has to actively check whether that happened, rather than
;; unconditionally showing the start screen and potentially covering up files the user
;; explicitly asked to open.  HOW: the check is specifically "is the CURRENT buffer still
;; the untouched `*scratch*' buffer" --- if a real file was opened from the command line,
;; Emacs would have already switched the current buffer to that file by the time this
;; runs, so `*scratch*' being current specifically means nothing else was requested and
;; it's safe to show the start screen instead; otherwise, this returns the current buffer
;; UNCHANGED (not the start screen) so the file Emacs already opened is what's actually
;; shown, exactly as the docstring's second sentence explains.
;;;###autoload
(defun my/start-initial-buffer ()
  "The buffer to show when Emacs starts: the start screen, unless files were given.
Emacs evaluates this after opening the files named on the command line; if it returned
the start screen anyway, both would be shown in a split."
  (if (eq (current-buffer) (get-buffer "*scratch*"))
      (my/start-buffer)
    (current-buffer)))

;; WHAT: `C-c h' --- show the start screen from anywhere, at any time.  WHY/HOW: unlike
;; `my/start-initial-buffer' (only ever relevant once, at startup), this is the ordinary,
;; repeatable command a person actually presses; `delete-other-windows' ensures it takes
;; over the whole frame rather than appearing in a split alongside whatever else was on
;; screen, giving a clean, full "back to the start screen" experience every time.
;;;###autoload
(defun my/start ()
  "Show the start screen: recent files, folders and projects."
  (interactive)
  (switch-to-buffer (my/start-buffer))
  (delete-other-windows))

;; WHAT/WHY/HOW: register this file under the Emacs feature name `startpage', matching
;; the `require' both the relevant test file and config/init.el use.
(provide 'startpage)
;;; startpage.el ends here
