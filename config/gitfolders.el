;;; gitfolders.el --- every git repository on this computer, kept in an index  -*- lexical-binding: t; -*-

;; `C-c f p' shows every git repository on this computer, drawn instantly from a small
;; index kept in `my/git-repos-store-file' --- the same idea as the recent files/folders
;; list on the start screen (see startpage.el), just for repositories instead of files.
;; Every time you open it, a background scan brings the index up to date (repositories
;; that moved or were deleted drop out, new ones appear) without making you wait for that
;; scan to finish first.  Press `g', or click [rescan], to run it again by hand.
;;
;; On Linux/WSL the quick scan (`tools/find-repos.sh') only covers the Linux side, since
;; crossing into a mounted Windows drive is much slower (about 48s for one drive); any
;; Windows-drive repositories an earlier full scan (`C-u') found stay in the index in the
;; meantime, unchanged.  On Windows there is no such split: the bundled `fd.exe' covers
;; every local drive directly in a few seconds, so every scan there is already a full one.
;;
;; RET or a click on a repository opens Magit status there (Dired if Magit is not
;; installed); `d' opens Dired on it, `t' reveals it in Treemacs.  No package.
;;
;; See docs/SEARCH-OPTIONS.md.

;; WHAT: Emacs's built-in clickable-link library.  WHY: every repository line in the
;; results buffer is a real button (`insert-text-button' below), not just styled text ---
;; that's what makes RET/mouse-click on a line actually do something.  HOW: gives us
;; `insert-text-button', `button-at' and `button-get' used throughout this file.
(require 'button)

;; WHAT: the results buffer's fixed name.  WHY: same one-buffer-reused pattern as every
;; other reference buffer in this config (`*shortcuts*', `*llm-council*', ...).
(defvar my/git-repos-buffer-name "*git repos*")
;; WHAT: where the Linux/WSL scanning script lives, resolved once at load time.  WHY:
;; this script only exists in a real git checkout of this project (a normal `--init-
;; directory=config' layout) --- the portable Windows bundle ships no shell scripts at
;; all, using `fd.exe' directly instead (see `my/git-repos--windows-drives' and `my/git-
;; repos--command').  HOW: `../tools/find-repos.sh' is relative to this file's own
;; directory (`user-emacs-directory', i.e. config/), so it resolves correctly regardless
;; of where the project itself is checked out.
(defvar my/git-repos-script (expand-file-name "../tools/find-repos.sh" user-emacs-directory)
  "The Linux/WSL scanner this runs.  Only present in a git checkout of this project (a
normal `--init-directory=config' layout), not in the portable bundles; unused on Windows,
which instead runs `fd' directly (see `my/git-repos--windows-drives').")
;; WHAT: where the saved index of found repositories lives on disk.  WHY: lets `C-c f p'
;; show a result instantly (from what was already found last time) instead of forcing a
;; wait for a fresh scan every single time it's opened --- exactly the same tradeoff
;; `my/start-store-file' makes in startpage.el for recent files/folders.  HOW: `locate-
;; user-emacs-file' puts it alongside this config's other generated state (recentf,
;; custom.el, ...), in the real per-user Emacs directory, not tracked by git.
(defvar my/git-repos-store-file (locate-user-emacs-file "git-repos.eld")
  "Where the index of found repositories is saved, so the list can be shown at once
without a fresh scan every time --- the same idea as `my/start-store-file' in startpage.el.")

;; Kept in step with WIN_SKIP_NAMES in tools/find-repos.sh: folder names that are never
;; real projects, so scanning them (`Windows', `Program Files') would only waste time.
;; WHAT: folder names the Windows-drive scan (`fd', via `my/git-repos--command') skips
;; outright.  WHY: these are real Windows system/vendor directories that are enormous,
;; slow to walk, and never contain a project's own `.git' folder --- excluding them by
;; name is a large, measured speedup over scanning them and finding nothing.  HOW: must
;; be kept in sync BY HAND with the identically-named list in tools/find-repos.sh (the
;; Linux-side script's own equivalent skip-list for when it crosses into `/mnt'); there
;; is deliberately no single shared source since one is Elisp and the other is shell.
(defvar my/git-repos-windows-excluded-names
  '("Windows" "Program Files" "Program Files (x86)" "ProgramData" "$RECYCLE.BIN" "System Volume Information"))

;; WHAT: the in-memory copy of the index --- every repository path last known about.
;; WHY/HOW: explicitly NOT buffer-local (unlike the process/scan-state variables below
;; it): there is exactly one such list for the whole computer, same reasoning as `my/
;; start--folders' in startpage.el --- multiple `*git repos*' buffers, if that ever
;; happened, should all agree on the same one true index rather than diverging.
(defvar my/git-repos--list nil
  "The index: every repository last known about, sorted.  Not buffer-local: there is
only ever one such list, computer-wide, same as `my/start--folders'.")
;; WHAT: guards `my/git-repos--load' (below) so the store file is only ever actually read
;; from disk once per Emacs session.  WHY: reading it again on every `C-c f p' would be
;; wasted I/O for data that, in this session, only this code itself ever changes.
(defvar my/git-repos--loaded nil)

;; WHAT: the currently-running background scan process, if any --- buffer-local, since a
;; scan is tied to one specific `*git repos*' buffer.  WHY: checked before starting a new
;; scan (to cancel a stale one first) and by the sentinel (to detect and ignore a late-
;; firing OLD scan's callback --- see the long comment inside `my/git-repos-refresh'
;; below for exactly why that check exists).
(defvar-local my/git-repos--process nil "The in-flight background scan, if any.")
;; WHAT: output bytes the process filter has read but couldn't yet turn into a complete
;; line.  WHY: a process filter can be called with a chunk of output that splits a line
;; right down the middle (partway through a path) --- this is where that leftover
;; fragment is held until the rest of the line arrives in a later chunk.
(defvar-local my/git-repos--pending ""
  "Output the process filter has read but not yet acted on, because it did not end in
a newline (a process filter can be called with a chunk that splits a line in the middle).")
;; WHAT: repository paths the currently in-flight scan has found so far.  WHY: accumulated
;; here (not written straight into `my/git-repos--list') so a scan-in-progress never
;; shows a half-finished result --- the real index is only updated, all at once, when the
;; scan's sentinel confirms it has actually finished (see `my/git-repos-refresh').
(defvar-local my/git-repos--found nil "Paths the in-flight scan has collected so far.")
;; WHAT: whether the current (or most recently finished) scan was a full one (both
;; Linux and every Windows drive) versus the quick Linux-only default.  WHY: this is
;; exactly what `my/git-repos--merge' (below) needs to decide whether Windows-drive
;; entries from an earlier scan should be kept as-is or replaced outright.
(defvar-local my/git-repos--full-scan nil "Whether the in-flight (or last finished) scan was a full one.")

;;; The index -------------------------------------------------------------------------

;; WHAT: read the saved index (once) into `my/git-repos--list'.  WHY: called at the start
;; of every `my/git-repos-refresh', so the very first `C-c f p' of a session shows
;; whatever was found last time, immediately, before this run's own background scan has
;; even started.  HOW: `unless my/git-repos--loaded' makes this genuinely idempotent ---
;; safe to call every time without re-reading the file after the first success; wrapped
;; in `ignore-errors' plus a `seq-filter #'stringp' pass, so a corrupted or unexpected-
;; shape store file degrades to "index is empty" instead of erroring `C-c f p' outright.
(defun my/git-repos--load ()
  "Read the saved index into `my/git-repos--list', once."
  (unless my/git-repos--loaded
    (setq my/git-repos--loaded t)
    (when (file-readable-p my/git-repos-store-file)
      (setq my/git-repos--list
            (seq-filter #'stringp
                        (ignore-errors
                          (with-temp-buffer
                            (insert-file-contents my/git-repos-store-file)
                            (read (current-buffer)))))))))

;; WHAT: write the current index back out to disk.  WHY: called right after a scan's
;; results are merged in, so the very next Emacs session's first `C-c f p' benefits too,
;; not just the rest of this one.  HOW: `prin1' writes it as plain readable Lisp (a list
;; of strings) --- exactly the shape `my/git-repos--load' above expects to `read' back;
;; `ignore-errors' means a write failure (e.g. a read-only filesystem) degrades to "the
;; in-memory index just won't persist" rather than erroring the whole refresh.
(defun my/git-repos--save ()
  "Write `my/git-repos--list' to disk."
  (ignore-errors
    (with-temp-file my/git-repos-store-file
      (prin1 my/git-repos--list (current-buffer)))))

;; WHAT: is PATH on a mounted Windows drive (from WSL's point of view)?  WHY: this is the
;; test `my/git-repos--merge' uses to decide which OLD entries survive a quick, Linux-
;; only scan.  HOW: WSL always mounts Windows drives under `/mnt/', so a simple prefix
;; check is sufficient and needs no filesystem access.
(defun my/git-repos--windows-mount-p (path)
  (string-prefix-p "/mnt/" path))

;; WHAT: combine OLD (the index before this scan) with FRESH (what this scan just found)
;; into the new index.  WHY: this is the one place the "quick scan only ever touches the
;; Linux side" policy from the file header comment is actually implemented --- without
;; it, a quick scan would look like it deleted every previously-found Windows repository,
;; when really it just never looked there this time.  HOW: on Windows, or whenever FULL-
;; SCAN is true, FRESH is simply the entire truth (`copy-sequence' to avoid aliasing the
;; caller's list); otherwise, FRESH (all-Linux results) is combined with whichever OLD
;; entries are on a Windows mount (`my/git-repos--windows-mount-p'), since those were not
;; re-examined this time and should neither vanish nor be treated as stale.  `delete-dups'
;; plus `sort' then produce one clean, alphabetical, duplicate-free final list either way.
;; Written as a pure function of its four explicit arguments (nothing read from a global
;; variable here) specifically so it can be exercised directly in tests without touching
;; the real platform or running a real scan --- same reasoning as `my/git-repos--command'
;; and `my/git-repos--unavailable-reason' below.
(defun my/git-repos--merge (old fresh full-scan platform)
  "Combine OLD (the index before this scan) with FRESH (what this scan just found).
On Windows, or when FULL-SCAN is non-nil, FRESH is the whole truth and replaces OLD
outright.  Otherwise (the quick default scan on Linux/WSL, which only covers Linux),
FRESH replaces only the Linux entries: any Windows-drive entries an earlier full scan
found are kept as they were, since this scan never looked at them.  A pure function of
its arguments, like `my/git-repos--command', so it can be tested without touching the
real platform or running a real scan."
  (sort (delete-dups
         (if (or full-scan (eq platform 'windows-nt))
             (copy-sequence fresh)
           (append fresh (seq-filter #'my/git-repos--windows-mount-p old))))
        #'string<))

;; WHAT: every drive letter that actually exists on this Windows machine, as ("C:/" ...).
;; WHY: `fd' needs an explicit list of roots to search --- there is no single "search
;; everything" flag that spans multiple drive letters.  HOW: probes `A:' through `Z:'
;; with `file-directory-p' (cheap: this just checks each one exists, does not scan into
;; it) and keeps only the ones that are real; Windows-only in practice (a no-op, empty
;; list on any other platform, since no such drive letters exist there).
(defun my/git-repos--windows-drives ()
  "Every local drive letter that exists, as (\"C:/\" \"D:/\" ...).  Windows only."
  (seq-filter #'file-directory-p (mapcar (lambda (c) (format "%c:/" c)) (number-sequence ?A ?Z))))

;; WHAT: build the exact command line for a scan, given every input it depends on as
;; explicit parameters.  WHY: on Windows, `fd' is run directly (no shell script exists
;; there, see `my/git-repos-script's own comment); on Linux/WSL, the shell script is run
;; instead, with an optional `--windows' flag for a full (`C-u') scan.  Like `my/git-
;; repos--merge' above, this takes PLATFORM/WINDOWS/SCRIPT/FD-EXE/DRIVES as plain
;; arguments rather than reading `system-type'/`executable-find'/etc. itself, precisely
;; so it is testable without touching the real system.  HOW: the `fd' invocation asks for
;; directories (`-t d') named exactly `.git' (`-I' includes hidden entries, `-u' disables
;; fd's own default ignore-file handling so a repo's own `.gitignore' can't hide its
;; parent from being found, `-H' includes hidden directories in the search itself), across
;; every DRIVES root, with one `--exclude NAME' per entry in `my/git-repos-windows-
;; excluded-names' (`mapcan' splices each `("--exclude" . NAME)' pair straight into the
;; flat argument list).  Returns nil on Windows if either FD-EXE or DRIVES is missing/
;; empty, since there is then nothing sensible to run.
(defun my/git-repos--command (platform windows script fd-exe drives)
  "The command line to run, given PLATFORM (`system-type'), whether WINDOWS (the Linux
prefix-argument) was requested, the Linux SCRIPT's path, and (Windows only) the FD-EXE
binary and the DRIVES to search.  A pure function of its arguments (none of them read
from a global here), so it can be tested without touching the real `system-type' or
running on a real Windows machine."
  (if (eq platform 'windows-nt)
      (when (and fd-exe drives)
        (append (list fd-exe "-H" "-t" "d" "-I" "-u" "^\\.git$") drives
                (mapcan (lambda (n) (list "--exclude" n)) my/git-repos-windows-excluded-names)))
    (append (list script) (and windows '("--windows")))))

;;; Opening a repository --------------------------------------------------------------

;; WHAT: open DIR the "normal" way --- Magit's status buffer if Magit is installed,
;; Dired otherwise.  WHY: this is what RET/click on a repository line does, and matches
;; how this config treats Magit as optional everywhere else (never a hard requirement).
(defun my/git-repos--open-magit (dir)
  (if (fboundp 'magit-status) (magit-status dir) (dired dir)))

;; WHAT: reveal DIR in Treemacs (`t' on a repository line).  WHY/HOW: declines clearly
;; (an echo-area message, not an error) if Treemacs isn't installed; otherwise adds DIR
;; as a Treemacs project if it isn't already one (`treemacs--find-project-for-path'
;; checks first, so re-pressing `t' on the same repo never adds it twice), makes sure the
;; Treemacs window is actually visible, then selects it and navigates straight to DIR's
;; own node --- so `t' both opens Treemacs and jumps to the right place in one step.
(defun my/git-repos--open-treemacs (dir)
  (if (not (locate-library "treemacs"))
      (message "Treemacs is not installed.  Run ./build.sh packages")
    (require 'treemacs)
    (let ((path (treemacs-canonical-path dir)))
      (unless (treemacs--find-project-for-path path)
        (treemacs-do-add-project-to-workspace path (file-name-nondirectory (directory-file-name dir))))
      (unless (eq (treemacs-current-visibility) 'visible) (treemacs))
      (treemacs-select-window)
      (treemacs-goto-file-node path))))

;; WHAT: the button `action' called on RET/click.  WHY/HOW: every repository button
;; stores its own directory in a `my-repo-dir' property (set in `my/git-repos--insert-
;; entries' below); this just reads that property back off the button that was activated
;; and hands it to `my/git-repos--open-magit'.
(defun my/git-repos--open (button)
  (my/git-repos--open-magit (button-get button 'my-repo-dir)))

;; WHAT: the repository directory the button under point represents, or nil if point
;; isn't on a repository line at all.  WHY: shared by both `d' (Dired) and `t' (Treemacs)
;; below, so "find the button at point and read its directory" isn't duplicated twice.
(defun my/git-repos--dir-at-point ()
  (when-let* ((b (button-at (point)))) (button-get b 'my-repo-dir)))

;; WHAT: `d' --- open the repository at point in Dired.  WHY/HOW: a friendly message
;; (not an error) if point isn't actually on a repository line.
(defun my/git-repos-dired ()
  "Open the repository at point in Dired."
  (interactive)
  (if-let* ((dir (my/git-repos--dir-at-point))) (dired dir)
    (message "Put the cursor on a repository line first")))

;; WHAT: `t' --- reveal the repository at point in Treemacs.  WHY/HOW: same "friendly
;; message, not an error, if point is in the wrong place" pattern as `my/git-repos-dired'
;; just above.
(defun my/git-repos-treemacs ()
  "Reveal the repository at point in Treemacs."
  (interactive)
  (if-let* ((dir (my/git-repos--dir-at-point))) (my/git-repos--open-treemacs dir)
    (message "Put the cursor on a repository line first")))

;;; The buffer --------------------------------------------------------------------------

;; WHAT: this buffer's own keymap.  WHY/HOW: inherits from `special-mode-map' (so `q'
;; closes it, and every other standard read-only-buffer binding works for free), adding
;; only the three commands genuinely specific to this buffer: `g' to rescan, `d'/`t' to
;; open the repository at point in Dired/Treemacs.  RET itself needs no explicit binding
;; here --- that comes from the button machinery (`insert-text-button''s own default RET/
;; mouse-1 action), not from this keymap.
(defvar my/git-repos-mode-map
  (let ((m (make-sparse-keymap)))
    (set-keymap-parent m special-mode-map)
    (define-key m "g" #'my/git-repos-refresh)
    (define-key m "d" #'my/git-repos-dired)
    (define-key m "t" #'my/git-repos-treemacs)
    m))

;; WHAT: the major mode for the results buffer.  WHY: derives from `special-mode' (the
;; standard base for a read-only, informational Emacs buffer) rather than `outline-mode'
;; --- unlike `my/shortcuts'/`my/llm-council', this list has no foldable sections, just a
;; flat list of repository lines, so plain `special-mode' read-only behavior is all it
;; needs.
(define-derived-mode my/git-repos-mode special-mode "Git-Repos"
  "A list of every git repository found on this computer.  See `my/find-git-repos'.")

;; WHAT: draw the buffer's title, key hints and (while a scan is running) a live
;; "updating..." indicator.  WHY/HOW: the Windows-only hint text ("C-u g also scans the
;; Windows drives (slow)") is conditionally omitted on Windows itself, since there a
;; prefix argument genuinely has no extra effect (every drive is already covered by a
;; plain scan there --- see the file header comment); the `[rescan]' button gives a
;; mouse-only way to trigger the same thing `g' does, for anyone not using the keyboard
;; shortcut; `process-live-p my/git-repos--process' is checked fresh every redraw so the
;; "updating..." text appears and disappears automatically as a scan starts and finishes.
(defun my/git-repos--insert-header ()
  (insert (propertize "Git repositories on this computer\n\n" 'face '(:height 1.2 :weight bold)))
  (insert "  RET/click open Magit   d Dired   t Treemacs   g rescan"
          (if (eq system-type 'windows-nt) "" "   C-u g also scans the Windows drives (slow)")
          "   q close\n  ")
  (insert-text-button "[rescan]" 'action (lambda (_) (my/git-repos-refresh)) 'follow-link t
                      'help-echo "Scan again now")
  (when (process-live-p my/git-repos--process)
    (insert "  " (propertize "updating..." 'face 'shadow)))
  (insert "\n\n"))

;; WHAT: insert one button per repository path in PATHS.  WHY/HOW: each button carries
;; its own directory in the `my-repo-dir' property (read back by `my/git-repos--open'/
;; `my/git-repos--dir-at-point' above), and `follow-link t' makes a single mouse click
;; (not just RET) activate it too, matching normal Emacs button conventions.
(defun my/git-repos--insert-entries (paths)
  (dolist (dir paths)
    (insert "  ")
    (insert-text-button dir 'action #'my/git-repos--open 'follow-link t 'my-repo-dir dir 'help-echo dir)
    (insert "\n")))

;; WHAT: the body of the buffer --- either a status message (first scan in progress, or
;; nothing found at all) or the real repository count plus the list itself.  WHY/HOW:
;; distinguishing "scanning for the first time" (no index yet, but a scan IS running)
;; from "no git repositories found" (no index, and nothing is running either) gives an
;; accurate message either way, rather than one generic "empty" state covering both.
(defun my/git-repos--insert-list ()
  (cond
   ((and (null my/git-repos--list) (process-live-p my/git-repos--process))
    (insert "  " (propertize "scanning for the first time (a few seconds)..." 'face 'shadow) "\n"))
   ((null my/git-repos--list)
    (insert "  " (propertize "no git repositories found" 'face 'shadow) "\n"))
   (t (insert (format "  %d repositor%s\n\n" (length my/git-repos--list)
                      (if (= (length my/git-repos--list) 1) "y" "ies")))
      (my/git-repos--insert-entries my/git-repos--list))))

;; WHAT: redraw the whole buffer from scratch, from `my/git-repos--list'.  WHY: same
;; "always rebuild the visible text from the data model, don't hand-patch it" strategy
;; used throughout this config (`my/llm-council--render' is the same idea).  HOW:
;; `inhibit-read-only' lets this function edit a buffer that's normally locked; the
;; cursor's line number is remembered before erasing and restored afterward (`forward-
;; line'), so pressing `g' to rescan doesn't visually yank the cursor back to the top;
;; if the restored line doesn't land exactly on a button (the list length changed), it
;; nudges forward to the next one instead of leaving point stranded on plain text.
(defun my/git-repos--redraw ()
  "Redraw the buffer from `my/git-repos--list', keeping the cursor on the same line."
  (let ((inhibit-read-only t) (line (line-number-at-pos)))
    (erase-buffer)
    (my/git-repos--insert-header)
    (my/git-repos--insert-list)
    (goto-char (point-min))
    (forward-line (max 0 (1- line)))
    (unless (button-at (point)) (ignore-errors (forward-button 1)))))

;;; Scanning ----------------------------------------------------------------------------

;; WHAT: interpret one raw line of scanner output as either a real repository path or
;; something to ignore.  WHY: the Linux script's own output mixes real paths with section
;; markers ("== ... ==") and a human-readable "Scanning..." progress line; `fd's raw
;; output (Windows) is always a real path, but --- either way --- still ends in `.git' or
;; `.git\' (the directory that was actually matched), which needs stripping to get the
;; repository's own root directory instead of its `.git' subfolder.  HOW: three early
;; "not a real path" cases first, then a regexp strips a trailing `/.git' or `\.git' (and
;; an optional trailing slash/backslash after it) if present, leaving LINE unchanged if
;; that pattern doesn't match for some reason (defensive, not expected in practice).
(defun my/git-repos--parse-line (line)
  "The repository path in LINE, or nil if LINE is a \"== section ==\" marker (from the
Linux script), its scanning-progress message, or blank.  The raw path (from either the
script or, on Windows, `fd' directly) still ends in `.git' or `.git\\'; strip that here."
  (cond
   ((string-prefix-p "== " line) nil)
   ((string-prefix-p "Scanning" line) nil)
   ((string-empty-p line) nil)
   (t (if (string-match "[/\\]\\.git[/\\]?\\'" line) (substring line 0 (match-beginning 0)) line))))

;; WHAT: fold newly-arrived process output CHUNK into `my/git-repos--found', a complete
;; line at a time.  WHY: this is the fix for the "a process filter chunk can split a line
;; in the middle" problem mentioned in `my/git-repos--pending's own comment --- without
;; it, a path could be silently truncated or corrupted right at a chunk boundary.  HOW:
;; prepends whatever was left over from last time (`my/git-repos--pending') onto this new
;; CHUNK first; then repeatedly finds the next newline, parses everything before it as one
;; line (pushing a real result onto `my/git-repos--found'), and advances past it, until no
;; more complete lines remain in TEXT; whatever's left over (a partial final line, if any)
;; becomes the new `my/git-repos--pending' for next time.
(defun my/git-repos--handle-output (chunk)
  "Collect complete lines of CHUNK into `my/git-repos--found'; a trailing partial line
is kept in `my/git-repos--pending' for the next call, or for `my/git-repos--flush'."
  (let ((text (concat my/git-repos--pending chunk)))
    (while (string-match "\n" text)
      (when-let* ((path (my/git-repos--parse-line (substring text 0 (match-beginning 0)))))
        (push path my/git-repos--found))
      (setq text (substring text (match-end 0))))
    (setq my/git-repos--pending text)))

;; WHAT: handle whatever's left in `my/git-repos--pending' once the process has actually
;; exited.  WHY: a process's very last line of output often has no trailing newline at
;; all (nothing ever arrives after it to trigger the newline-scan in `my/git-repos--
;; handle-output'), so without this, that one final repository could be silently dropped.
;; HOW: called from the sentinel, after the process is confirmed no longer running.
(defun my/git-repos--flush ()
  "Collect any final partial line left over when the process has finished."
  (unless (string-empty-p my/git-repos--pending)
    (when-let* ((path (my/git-repos--parse-line my/git-repos--pending)))
      (push path my/git-repos--found))
    (setq my/git-repos--pending "")))

;; WHAT: the real work of `C-c f p': rescan in the background and update the index when
;; done, while the buffer keeps showing the previous results the whole time.  WHY: this
;; is what makes `C-c f p' feel instant even though a real scan can take real seconds ---
;; the user never has to wait for one before seeing something.  HOW, in order: loads the
;; saved index first (a no-op after the first call, see `my/git-repos--load'); computes
;; the exact command for this platform/prefix-argument combination via the pure `my/git-
;; repos--command' helper; ensures the buffer is in the right mode; if a PREVIOUS scan is
;; still running in this buffer, kills it first (`delete-process') so two scans are never
;; racing each other; resets the per-scan scratch state (`my/git-repos--pending'/`--found')
;; and remembers whether this is a full scan (needed later by `my/git-repos--merge');
;; redraws immediately so the "updating..." indicator and previous results show up right
;; away; then starts the actual subprocess.  The `:filter' just forwards each chunk to
;; `my/git-repos--handle-output' in the right buffer.  The `:sentinel' is the trickiest
;; part: it only acts once the process has genuinely exited (`process-status' is `exit'
;; or `signal', not some other transient status change), AND --- this is the important,
;; real bug this `eq' check specifically guards against --- only if this callback's own
;; process `p' is STILL the buffer's current `my/git-repos--process'.  Without that
;; check, an old scan that got superseded by a newer one (via the `delete-process' above)
;; could have its sentinel fire late and overwrite the newer scan's in-progress or
;; already-finished results with its own stale ones.  Once past both checks: flush the
;; last partial line, merge the found paths into the real index (`my/git-repos--merge'),
;; save it to disk, redraw, and report the final count in the echo area --- noting
;; explicitly if the scan looks like it stopped early (anything other than a clean
;; "finished" event, e.g. it was killed) rather than silently implying a completed scan.
(defun my/git-repos-refresh (&optional windows)
  "Rescan now, in the background, and update the index when it finishes; the buffer
shows the index as it stands (last scan's results) the whole time.  On Linux/WSL a
prefix argument also scans every Windows drive under /mnt (much slower); on Windows
every local drive is already included, so the prefix argument has no extra effect."
  (interactive "P")
  (my/git-repos--load)
  (let ((buf (get-buffer-create my/git-repos-buffer-name))
        (command (my/git-repos--command system-type windows my/git-repos-script
                                        (executable-find "fd") (my/git-repos--windows-drives))))
    (with-current-buffer buf
      (unless (derived-mode-p 'my/git-repos-mode) (my/git-repos-mode))
      (when (process-live-p my/git-repos--process) (delete-process my/git-repos--process))
      (setq my/git-repos--pending "" my/git-repos--found nil
            my/git-repos--full-scan (or windows (eq system-type 'windows-nt)))
      (my/git-repos--redraw)
      (setq my/git-repos--process
            (make-process
             :name "git-repos" :buffer buf :noquery t :command command
             :filter (lambda (p out)
                       (with-current-buffer (process-buffer p) (my/git-repos--handle-output out)))
             :sentinel (lambda (p event)
                         ;; the `eq' check matters: if a later scan has already replaced
                         ;; `my/git-repos--process' (see the `delete-process' above), this is
                         ;; that OLD process's sentinel firing late, and must not clobber the
                         ;; newer scan's in-progress or already-finished results.
                         (when (and (memq (process-status p) '(exit signal))
                                    (eq p (buffer-local-value 'my/git-repos--process (process-buffer p))))
                           (with-current-buffer (process-buffer p)
                             (my/git-repos--flush)
                             (setq my/git-repos--list
                                   (my/git-repos--merge my/git-repos--list my/git-repos--found
                                                        my/git-repos--full-scan system-type))
                             (my/git-repos--save)
                             (my/git-repos--redraw)
                             (message "Found %d git repositor%s%s" (length my/git-repos--list)
                                      (if (= (length my/git-repos--list) 1) "y" "ies")
                                      (if (string-prefix-p "finished" event) "" " (scan stopped early)")))))))
      buf)))

;; WHAT: why `my/find-git-repos' can't run right now, or nil if it can.  WHY: same
;; up-front, clear-message-instead-of-a-raw-error philosophy as `my/dictate--ready-
;; reason' in dictate.el.  HOW, per platform: on Windows, the only requirement is `fd.exe'
;; on PATH (bundled only in the portable Windows zip, per the message --- see docs/
;; DISTRIBUTION.md); on Linux/WSL, the shell script itself must actually be present and
;; executable (it's missing entirely in the portable bundles, which ship no scripts).
;; Takes PLATFORM/SCRIPT/FD-EXE as explicit parameters, like `my/git-repos--command'
;; above, purely so this too can be tested without touching the real system.
(defun my/git-repos--unavailable-reason (platform script fd-exe)
  "Why `my/find-git-repos' cannot run right now, given PLATFORM (`system-type'), the
Linux SCRIPT's path and (Windows only) the FD-EXE binary found (or nil) --- explicit
parameters, like `my/git-repos--command', so this can be tested safely on any platform.
Returns nil if it can run."
  (if (eq platform 'windows-nt)
      (unless fd-exe
        "fd.exe was not found on PATH (only bundled in the portable Windows zip; see docs/DISTRIBUTION.md)")
    (unless (file-executable-p script)
      (format "%s is missing (only in a git checkout of this project, not the portable bundles)."
              script))))

;; WHAT: the interactive entry point, bound to `C-c f p' in config/init.el.  WHY: the one
;; command a person actually calls.  HOW: checks `my/git-repos--unavailable-reason' first
;; and just reports it (not an error) if this can't run on this machine right now;
;; otherwise starts (or continues) a refresh and switches to its buffer.
;;;###autoload
(defun my/find-git-repos (&optional windows)
  "Show every git repository on this computer, drawn at once from the index kept in
`my/git-repos-store-file', then brought up to date by a background scan --- the same
idea as the recent files/folders list on the start screen, just for repositories.
On Linux/WSL, a prefix argument also scans every mounted Windows drive (much slower).
On Windows every local drive is already included; the prefix argument has no extra effect."
  (interactive "P")
  (if-let* ((reason (my/git-repos--unavailable-reason system-type my/git-repos-script (executable-find "fd"))))
      (message "%s" reason)
    (switch-to-buffer (my/git-repos-refresh windows))))

;; WHAT/WHY/HOW: register this file under the Emacs feature name `gitfolders', matching
;; the `(require 'gitfolders ...)' tests/ert/gitfolders.el uses, same as every sibling
;; config file in this project.
(provide 'gitfolders)
;;; gitfolders.el ends here
