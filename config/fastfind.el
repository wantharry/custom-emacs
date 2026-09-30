;;; fastfind.el --- instant fuzzy file finding over an index, with a live fallback  -*- lexical-binding: t; -*-

;; Type a few letters of a file name and get the best matches at once, from an index of
;; the files in the current project or on the whole disk.  If the index has nothing (a file
;; is new, hidden or ignored), a regular live search runs instead.  Built in only: no
;; package.  The matcher is ripgrep when installed (7 to 97 ms over 975,000 paths),
;; otherwise grep, otherwise plain Emacs Lisp.
;;
;;   C-c f f   find a file in the current project (or anywhere if not in a project)
;;   C-c f g   find a file anywhere on the disk
;;   C-c f r   rebuild the index now
;;
;; See docs/NAVIGATING-CODE.md.

;; WHAT: Emacs's built-in project-awareness library.  WHY: `my/ff-find-file' uses it to
;; detect "am I inside a project right now, and if so where's its root" so `C-c f f' can
;; search just that project instead of the whole disk.  HOW: gives us `project-current'/
;; `project-root'/`project-files'.
(require 'project)
;; WHAT: string/list helper macros (`when-let*'-style, `string-trim', etc.).  WHY: used
;; throughout this file for small string-handling conveniences.
(require 'subr-x)
;; WHAT: Common Lisp compatibility macros.  WHY: `cl-incf' (increment a place), `cl-loop'
;; and `cl-every' are all used in the scoring/matching logic below.
(require 'cl-lib)

(defgroup my-fastfind nil "Instant fuzzy file finding." :group 'convenience)

;; WHAT: where index files (one per project, plus one whole-disk index) are cached on
;; disk.  WHY: rebuilding an index from scratch is what takes real time (a full-disk
;; listing); once built, matching against it is what's actually instant.  HOW: `locate-
;; user-emacs-file' keeps it alongside this config's other generated, untracked state.
(defvar my/ff-cache-dir (locate-user-emacs-file "fastfind/")
  "Where the index files are kept.")
;; WHAT: a compile-time-ish constant for "are we on Windows".  WHY: computed once at load
;; time (not re-checked with `eq system-type ...' everywhere) since several path/command
;; decisions below differ by platform.
(defconst my/ff--windows (eq system-type 'windows-nt))

;; WHAT: the single top-level folder every disk listing is run from.  WHY: on Windows,
;; drive letters mean there's no single "/" that covers everything the way there is on
;; Linux/macOS --- this defaults to the drive the user's home folder is on (the practical
;; common case: almost everything worth finding lives there).  HOW: `(substring (expand-
;; file-name "~") 0 2)' extracts just the "C:" part of the expanded home path.
(defvar my/ff--root-dir
  (if my/ff--windows (concat (substring (expand-file-name "~") 0 2) "/") "/")
  "The top folder listings run from: / on Linux and macOS, the drive of your home on Windows.")

;; WHAT: the folders actually indexed for the whole-disk search (`C-c f g').  WHY:
;; defaults to just `my/ff--root-dir' --- deliberately does NOT also index a WSL-mounted
;; Windows drive (`/mnt/...') by default, since crossing that boundary is much slower
;; (the same tradeoff `gitfolders.el' makes for its own quick scan, for the same reason).
(defvar my/ff-global-roots (list my/ff--root-dir)
  "Folders indexed for the whole-disk search.  Other file systems are not entered, so on
Linux under WSL the Windows drive under /mnt is left out.")
;; WHAT: folder NAMES (matched anywhere in the tree, via a glob) skipped when building
;; the index.  WHY: these are all real, huge, machine-generated directories (build
;; artifacts, package caches, VCS internals) that are never what someone is trying to
;; find by name, and indexing them would both slow the build down and pollute results
;; with noise.  HOW: the list is platform-independent Unix build/package-manager
;; directories first; a few Windows-specific ones (`AppData/Local/...', the Recycle Bin)
;; are appended only when `my/ff--windows' is true.  The live fallback (an uncached,
;; from-scratch search --- see `my/ff--live-search' below) deliberately ignores this list
;; entirely, since it exists specifically to still find things the index skips.
(defvar my/ff-excluded-names
  (append '(".git" "node_modules" "__pycache__" ".cache" ".npm" ".rustup"
            ".cargo/registry" ".gradle" ".m2/repository" "target/debug")
          (and my/ff--windows '("AppData/Local/Packages" "AppData/Local/Microsoft" "$RECYCLE.BIN")))
  "Folder names left out of the whole-disk index.  The live fallback does not use this.")
;; WHAT: absolute paths (not just names) skipped when building the whole-disk index.
;; WHY: some things need excluding by their exact location, not by name --- Linux
;; pseudo-filesystems like `/proc'/`/sys' (which aren't real files at all and can hang or
;; behave strangely if walked) and system-reserved Windows folders that would otherwise
;; slow the index hugely for zero benefit.
(defvar my/ff-excluded-paths
  (if my/ff--windows
      '("/Windows" "/Program Files" "/Program Files (x86)" "/ProgramData" "/System Volume Information" "/Recovery")
    '("/proc" "/sys" "/dev" "/run" "/mnt" "/tmp" "/snap"))
  "Absolute folders left out of the whole-disk index.")
;; WHAT: the hard cap on how many results are ever shown at once.  WHY: keeps the
;; minibuffer's completion list from becoming enormous and slow to render on a very
;; broad query (e.g. a single common letter matching thousands of files).
(defvar my/ff-max-results 200 "Most candidates shown.")
;; WHAT: how old the whole-disk index can get before it's considered stale and rebuilt.
;; WHY: 6 hours is a deliberate middle ground --- frequent enough that new files show up
;; reasonably promptly, infrequent enough that a full-disk rebuild (the expensive part)
;; doesn't happen constantly.
(defvar my/ff-stale-seconds (* 6 3600) "Age after which the whole-disk index is rebuilt.")
;; WHAT: same idea, but for a single project's own index.  WHY: much shorter (60s) than
;; the whole-disk one, since a project index is cheap to rebuild (git already knows its
;; file list, see `my/ff--project-index' below) and people edit/add files in whatever
;; project they're actively working in far more often than the rest of the disk changes.
(defvar my/ff-project-stale-seconds 60 "Age after which a project index is rebuilt.")
;; WHAT: which external matcher program to use.  WHY: `auto' (the default) means "detect
;; and remember it"; explicitly setting this to nil forces the fallback chain (grep, then
;; pure Emacs Lisp) even when ripgrep is actually installed --- useful for testing the
;; fallback paths deliberately, or on a machine where ripgrep misbehaves for some reason.
(defvar my/ff-rg 'auto
  "The ripgrep program: `auto' finds it, nil forces the fallbacks (grep, then Lisp).")
;; WHAT: how long to wait for a pause in typing before actually searching.  WHY: a real,
;; reported problem --- without this, a real search command runs synchronously on every
;; single keystroke, which can feel laggy typing into the whole-disk search specifically
;; (the file header comment's own measured cost, 7-97ms per keystroke over ~975,000
;; paths, is a real, perceptible delay at the high end, especially on Windows where
;; spawning that subprocess costs more to begin with). HOW: `my/ff--table' below waits
;; this long via `sit-for', not a timer --- `sit-for' returns immediately, without
;; waiting the full delay, the moment more input is already pending, which is exactly
;; what a fast typist mid-word is: every keystroke except the last one in a burst gets
;; interrupted almost instantly and just keeps showing the previous result, and the
;; *last* keystroke (the one after which nothing further is typed, by definition) is the
;; one whose `sit-for' actually completes and runs the real search. This is why a timer
;; (which would need its own machinery to force the minibuffer to redisplay once it
;; fires) is not needed here: Emacs's own completion machinery already re-invokes this
;; table after every keystroke as part of its normal redisplay cycle, so the one
;; genuinely-uninterrupted call already lands exactly where a timer would have fired one.
;; The real tradeoff: candidates lag behind by whatever was last actually searched during
;; a fast burst, not literally live on every letter --- `my/ff-find-file-global-async'
;; (`C-c f a') is the fully asynchronous alternative when that tradeoff isn't wanted.
(defvar my/ff-debounce-seconds 0.15
  "Seconds of no new typing before the fast finder actually searches again.")

;;; Tools

;; WHAT: resolve (once) and remember whether ripgrep is available.  WHY: `executable-
;; find' does real filesystem/PATH work --- caching the answer in `my/ff-rg' itself means
;; every later call in this file is a cheap variable read, not a repeated PATH search.
;; HOW: the `'auto' sentinel value means "not yet resolved"; once resolved, `my/ff-rg'
;; holds either the real path string or nil, and this function just returns that from
;; then on (skipping the `executable-find' call entirely).
(defun my/ff--rg ()
  (if (eq my/ff-rg 'auto) (setq my/ff-rg (executable-find "rg")) my/ff-rg))

;; WHAT: is `grep' available, and should it be used?  WHY: only relevant at all when
;; ripgrep is NOT being used --- this is the second tier of the three-way matcher
;; fallback chain (ripgrep, then grep, then pure Emacs Lisp).
(defun my/ff--grep-program ()
  (and (not (my/ff--rg)) (executable-find "grep")))

;; WHAT: escape STRING so it's safe to embed literally inside a ripgrep/`grep -E'
;; extended regex.  WHY: search terms typed by a user can contain regex metacharacters
;; (a literal "." or "(" in a file name, say) that must not be interpreted as regex
;; syntax when building the "letters in order" patterns in `my/ff--regexes' below.  HOW:
;; backslash-escapes every ERE special character; `\\\\\\&' in the replacement inserts a
;; literal backslash before whatever character `\&' (the whole match) was.
(defun my/ff--ere-quote (string)
  "Escape STRING for ripgrep and grep -E."
  (replace-regexp-in-string "[][\\\\.^$*+?(){}|]" "\\\\\\&" string))

;;; Index files

;; WHAT/WHY/HOW: the one whole-disk index file's path, inside `my/ff-cache-dir'.
(defun my/ff--global-index-file () (expand-file-name "global.idx" my/ff-cache-dir))

;; WHAT: the index file for one specific project, keyed by its root path.  WHY: each
;; project needs its own separate index file (a monorepo-wide search would defeat the
;; point of "search just this project"); HOW: `md5' of the expanded root path gives a
;; short, filesystem-safe, collision-resistant filename derived from an otherwise
;; arbitrary (and potentially very long, or character-unsafe) directory path.
(defun my/ff--project-index-file (root)
  (expand-file-name (format "project-%s.idx" (md5 (expand-file-name root))) my/ff-cache-dir))

;; WHAT: how many seconds old FILE is, or nil if it doesn't exist.  WHY: this is the one
;; staleness primitive both `my/ff-maybe-refresh' and `my/ff--project-index-stale-p'
;; below build their "is this index too old" decisions on top of.
(defun my/ff--age (file)
  "Seconds since FILE was modified, or nil if it does not exist."
  (when (file-exists-p file)
    (float-time (time-subtract (current-time) (file-attribute-modification-time (file-attributes file))))))

;; ripgrep resolves an absolute exclusion pattern relative to the folder it runs in, so every
;; listing runs from / (from anywhere else the pattern silently excludes nothing).
;; WHAT: build the exact command line that lists every file under ROOTS, one path per
;; line.  WHY: this one function is shared by both index-building (`my/ff-reindex'/`my/
;; ff--project-index', EVERYTHING nil so the exclude lists apply) and the live fallback
;; search (`my/ff--live-search', EVERYTHING t so nothing is excluded --- the whole point
;; of falling back is to find things the index deliberately skips).  HOW: with ripgrep,
;; `--files --hidden --no-ignore --one-file-system --no-messages' lists every real file
;; including dotfiles, ignoring any `.gitignore' (this is a file finder, not a project-
;; aware search) and never crossing into a different filesystem/mount; `--path-separator
;; /' is forced on Windows since ripgrep would otherwise print native backslashes, and
;; every other piece of this file assumes forward slashes throughout.  The exclusion
;; globs are two `mapcan' calls building `--glob "!**/NAME/**"'/`--glob "!PATH/**"' pairs
;; for each configured name/path --- note the comment just above this function: ripgrep
;; resolves an ABSOLUTE glob pattern relative to wherever it was actually launched from,
;; which is why every caller of this command explicitly runs it with `default-directory'
;; bound to `my/ff--root-dir' (see `my/ff-reindex' and `my/ff--live-search'), and why a
;; Windows absolute exclude path like "C:/Windows" has its drive letter stripped first
;; (`replace-regexp-in-string "\\`[a-zA-Z]:" ""') before being turned into a glob ---
;; ripgrep, run from the drive root, sees that same path as simply "/Windows".  Without
;; ripgrep, the fallback builds an equivalent plain `find' command instead: `-xdev' is
;; `find's own "don't cross filesystems" flag (matching `--one-file-system' above); the
;; exclusion logic is a `-prune'd `(  -name N -o ... -path P -o ... -false )' group ---
;; `-false' at the end makes the whole parenthesized OR-chain evaluate false whenever
;; none of the names/paths matched, so `-prune' only actually prunes on a real match; a
;; NAME containing a "/" is skipped from the `-name' checks (`find -name' only matches a
;; single path component, so a name like "target/debug" could never match that way ---
;; it's only meaningful in the ripgrep glob form above).
(defun my/ff--list-command (roots &optional everything)
  "The command that prints every file under ROOTS, one per line.
Unless EVERYTHING, the excluded folders are skipped (the index); with it, nothing is
(the live fallback)."
  (if (my/ff--rg)
      (append (list (my/ff--rg) "--files" "--hidden" "--no-ignore" "--one-file-system" "--no-messages")
              ;; Windows prints backslashes by default; every path here uses /
              (and my/ff--windows (list "--path-separator" "/"))
              (unless everything
                (append (mapcan (lambda (n) (list "--glob" (format "!**/%s/**" n))) my/ff-excluded-names)
                        ;; ripgrep runs from the drive's top folder, so "c:/x" is written "/x"
                        (mapcan (lambda (p) (list "--glob" (format "!%s/**" (replace-regexp-in-string "\\`[a-zA-Z]:" "" p))))
                                my/ff-excluded-paths)))
              roots)
    (append (list "find") roots '("-xdev")
            (unless everything
              (append '("(") (cl-loop for n in my/ff-excluded-names
                                      unless (string-match-p "/" n)
                                      append (list "-name" n "-o"))
                      (cl-loop for p in my/ff-excluded-paths append (list "-path" p "-o"))
                      '("-false" ")" "-prune" "-o")))
            '("-type" "f" "-print"))))

;; WHAT: the currently-running whole-disk index-build process, if any.  WHY: checked by
;; `my/ff-reindex' before starting a new background build, so `C-c f r' pressed twice in
;; a row doesn't start two competing builds.
(defvar my/ff--process nil "The running whole-disk index build, if any.")

;; WHAT: atomically replace the real index FILE with the just-finished listing TMP, but
;; only if TMP actually has real content.  WHY: `rename-file' (a single filesystem
;; rename, not a copy) means anything reading the index never sees a half-written file
;; --- it's either the complete old one or the complete new one, never something in
;; between; the size check guards against installing an empty/failed listing over a
;; perfectly good previous index (e.g. if the listing command itself errored out).
(defun my/ff--install-index (tmp file)
  "Move the finished listing TMP over the index FILE, if the listing produced anything."
  (when (and (file-exists-p tmp) (> (file-attribute-size (file-attributes tmp)) 0))
    (rename-file tmp file t)
    t))

;; WHAT: rebuild the whole-disk index, bound to `C-c f r'.  WHY: this is the expensive
;; operation everything else in this file is designed to avoid doing synchronously ---
;; hence "in the background" by default.  HOW: ensures the cache directory exists; builds
;; the listing command via `my/ff--list-command' (EVERYTHING left nil: the index DOES
;; apply the exclusion lists, unlike the live fallback); three distinct paths depending
;; on SYNC and whether a build is already running: (1) SYNC true runs it synchronously
;; with `call-process', writing straight to a `.tmp' file (used by the test suite, and
;; anywhere a blocking, deterministic rebuild is actually wanted); (2) a build is already
;; in flight (`process-live-p my/ff--process') just reports that and does nothing further
;; --- no second build is started; (3) the normal, asynchronous case starts a background
;; process whose `:filter' streams output straight to the `.tmp' file as it arrives
;; (`write-region ... 'silent' appends each chunk without any message-area noise, and
;; `coding-system-for-write' `no-conversion' plus `:coding 'no-conversion' on the process
;; itself avoid any newline/encoding translation that could corrupt paths with unusual
;; bytes), and whose `:sentinel', once the process has actually exited, cleans up its
;; stderr buffer and installs the finished index via `my/ff--install-index', reporting
;; success in the echo area.  `:connection-type 'pipe' matters specifically because a
;; process connected to a pseudo-terminal would make ripgrep (which auto-detects an
;; interactive terminal) add ANSI color codes to its output, corrupting the paths.
(defun my/ff-reindex (&optional sync)
  "Rebuild the whole-disk index in the background (or now, with SYNC).
Bound to C-c f r.  No shell is involved, so this works the same on Windows."
  (interactive)
  (make-directory my/ff-cache-dir t)
  (let* ((file (my/ff--global-index-file))
         (tmp (concat file ".tmp"))
         (cmd (my/ff--list-command (mapcar #'expand-file-name my/ff-global-roots))))
    (cond
     (sync (let ((default-directory my/ff--root-dir))
             (apply #'call-process (car cmd) nil (list :file tmp) nil (cdr cmd))
             (my/ff--install-index tmp file)))
     ((process-live-p my/ff--process) (message "Index is already being built"))
     (t (ignore-errors (delete-file tmp))
        (setq my/ff--process
              (let ((default-directory my/ff--root-dir)
                    (errbuf (generate-new-buffer " *fastfind-errors*")))
                (make-process :name "fastfind-index" :buffer nil :noquery t :command cmd
                              ;; a pipe, not a terminal: on a terminal ripgrep adds colors to the paths
                              :connection-type 'pipe :coding 'no-conversion :stderr errbuf
                              :filter (lambda (_p out)
                                        (let ((coding-system-for-write 'no-conversion))
                                          (write-region out nil tmp t 'silent)))
                              :sentinel (lambda (p _event)
                                          (when (memq (process-status p) '(exit signal))
                                            (kill-buffer errbuf)
                                            (when (my/ff--install-index tmp file)
                                              (message "Fast file index ready (%s)"
                                                       (file-name-nondirectory file)))))))))))
  (when (called-interactively-p 'interactive) (message "Building the file index in the background ...")))

;; WHAT: build the whole-disk index if it's missing or older than `my/ff-stale-seconds'.
;; WHY: called from `my/ff-find-file-global' so the index is kept fresh automatically,
;; without the user ever needing to remember to press `C-c f r' by hand.  HOW: always
;; runs asynchronously (no SYNC argument passed to `my/ff-reindex') so this never blocks
;; the very search that triggered it --- the current search just falls back to a live
;; search this one time if the index isn't ready yet (see `my/ff--candidates').
(defun my/ff-maybe-refresh ()
  "Build the whole-disk index if it is missing or old.  Runs in the background."
  (let ((age (my/ff--age (my/ff--global-index-file))))
    (when (or (null age) (> age my/ff-stale-seconds))
      (my/ff-reindex))))

;; WHAT: should this one project's index be rebuilt right now?  WHY: beyond simple age
;; (`my/ff-project-stale-seconds'), this also checks something age alone can't catch:
;; whether git's own index (`.git/index') was modified MORE RECENTLY than this file's
;; index --- meaning a commit, `git add', or checkout happened and the project's tracked
;; file list may have genuinely changed, even if the cached index isn't old by the clock
;; yet.  HOW: `git-age < age' means git's index is newer (smaller age = more recent), so
;; this project's cached file index should be considered stale even though it might
;; still be "young" in absolute terms.
(defun my/ff--project-index-stale-p (file root)
  "Non-nil if the index FILE for the project at ROOT is missing, old, or older than git's own index."
  (let ((age (my/ff--age file)))
    (or (null age)
        (> age my/ff-project-stale-seconds)
        ;; a commit, add or checkout rewrites .git/index: the file list has changed
        (let ((git-age (my/ff--age (expand-file-name ".git/index" root))))
          (and git-age (< git-age age))))))

;; WHAT: return the (rebuilt-if-needed) index file for project ROOT.  WHY: unlike the
;; whole-disk index, a project index is built SYNCHRONOUSLY, right here --- deliberate,
;; since a single project's file list is fast to gather (especially via git, see below)
;; and the user is actively waiting on this specific search right now.  HOW: if the
;; index is stale (`my/ff--project-index-stale-p'), it's rebuilt two different ways
;; depending on what's available: PREFERRED is asking `project.el' for the project's own
;; tracked file list (`project-files', which for a git project asks git directly ---
;; fast, and automatically respects `.gitignore'); this is wrapped in `condition-case'
;; because a project whose `.git' is present but broken/corrupted makes `project-files'
;; error, in which case this falls back to the same raw filesystem listing (`my/ff--
;; list-command') used everywhere else in this file.  Either way, the result is written
;; to FILE as one path per line.  New files not yet `git add'ed are consequently absent
;; from a git-derived index --- the docstring calls this out explicitly, since the live
;; fallback search (triggered automatically when the index has no matches) is what finds
;; them anyway.
(defun my/ff--project-index (root)
  "The index file for the project at ROOT, rebuilt first if stale.
Files that are new and not yet added to git are not in it; the live fallback finds them."
  (make-directory my/ff-cache-dir t)
  (let ((file (my/ff--project-index-file root)))
    (when (my/ff--project-index-stale-p file root)
      (let* ((default-directory root)
             (pr (project-current nil root))
             ;; project.el asks git; a folder with a broken .git makes that fail, so fall back
             (files (and pr (condition-case nil (project-files pr) (error nil)))))
        (if files
            (with-temp-file file
              (dolist (f files) (insert (expand-file-name f) "\n")))
          (let ((cmd (my/ff--list-command (list root))))
            (with-temp-file file
              (let ((default-directory my/ff--root-dir))
                (apply #'call-process (car cmd) nil t nil (cdr cmd))))))))
    file))

;;; Matching

;; WHAT: build three regexes for TERM, best (most specific) match tier first, with
;; special characters escaped by ESC (so this works whether the regex flavor is Emacs
;; Lisp's own, via `regexp-quote', or ripgrep/grep's ERE, via `my/ff--ere-quote').  WHY:
;; this is the heart of the "fuzzy" matching --- rather than one match/no-match test, it
;; tries progressively looser interpretations of what the user typed, so "abc" can match
;; "abc.txt" (tier 1: the letters together, as a run), "a-big-cat.txt" (tier 2: the
;; letters in order, anywhere in the file name), or "a/big/cat.txt" (tier 3: the letters
;; in order anywhere in the full path, even split across folder names).  HOW: `chars' is
;; TERM split into individual escaped characters; `not-slash' is "any run of characters
;; that isn't a path separator (or, for the Emacs-regexp case specifically, also not a
;; newline --- see the inline comment on why that distinction matters for a negated
;; class)", used to keep tiers 1 and 2 anchored within a single path component (the file
;; name) rather than spanning across folders.  Tier 1: TERM as one literal run, anchored
;; to the end of a path component (the `$' after `not-slash', meaning "the file name
;; itself", since these regexes are later matched line-by-line against one path per
;; line).  Tier 2: the same idea but with TERM's individual characters allowed to have
;; anything between them within the file name --- true "fuzzy" matching within just the
;; last path component.  Tier 3: no anchoring or `not-slash' restriction at all --- the
;; loosest tier, letters in order anywhere in the whole path, including across folder
;; boundaries.
(defun my/ff--regexes (term esc)
  "Three regexes for TERM, best first, with special characters escaped by ESC:
the letters as one run in the file name, the letters in order in the file name, and the
letters in order anywhere in the path."
  (let* ((chars (mapcar (lambda (c) (funcall esc (string c))) (string-to-list term)))
         ;; In an Emacs regexp a negated class also matches a newline, which would let a
         ;; match run across lines; ripgrep and grep work line by line and need no such care.
         (not-slash (if (eq esc #'regexp-quote) "[^/\n]*" "[^/]*")))
    (list (concat "/" not-slash (funcall esc term) not-slash "$")
          (concat "/" not-slash (mapconcat #'identity chars not-slash) not-slash "$")
          (mapconcat #'identity chars ".*"))))

;; WHAT: run REGEX (case-insensitive) against FILE (one path per line), returning at
;; most CAP matching lines, using whichever of ripgrep/grep is actually available.  WHY:
;; this is the "search a big flat list of paths" primitive both index search (`my/ff--
;; search-index') and live search (`my/ff--live-search') are built on.  HOW: `-N'
;; (ripgrep) / no equivalent needed for grep suppresses line numbers in the output, since
;; only the matched path text itself is wanted; `-m CAP' stops each tool early once CAP
;; matches are found, rather than scanning the whole file needlessly once there's already
;; enough to work with.
(defun my/ff--grep (regex file cap)
  "Lines of FILE matching REGEX (case-insensitive), at most CAP."
  (with-temp-buffer
    (cond
     ((my/ff--rg)
      (call-process (my/ff--rg) nil t nil "-i" "-N" "--no-filename" "--no-messages"
                    "-m" (number-to-string cap) "-e" regex file))
     ((my/ff--grep-program)
      (call-process "grep" nil t nil "-i" "-E" "-m" (number-to-string cap) "-e" regex file)))
    (split-string (buffer-string) "\n" t)))

;; WHAT: the pure-Emacs-Lisp equivalent of `my/ff--grep', used only when NEITHER ripgrep
;; NOR grep is available.  WHY: this is the third, slowest tier of the matcher fallback
;; chain, but it means this feature still works on a machine with no external search
;; tool installed at all --- degraded speed, not a hard failure.  HOW: REGEX here is
;; already an Emacs-Lisp-flavored regexp (built via `regexp-quote' rather than `my/ff--
;; ere-quote' when this path is taken --- see `my/ff--match-file' below for where that
;; choice is made); reads the whole file into a temp buffer and walks it with `re-search-
;; forward', collecting up to CAP matching lines, stopping the moment CAP is reached
;; rather than scanning the rest of a possibly-huge file.
(defun my/ff--lisp-grep (regex file cap)
  "The Emacs Lisp fallback for `my/ff--grep': REGEX is an Emacs regexp."
  (let ((case-fold-search t) hits)
    (with-temp-buffer
      (insert-file-contents file)
      (goto-char (point-min))
      (while (and (< (length hits) cap) (re-search-forward regex nil t))
        (let ((line (buffer-substring (line-beginning-position) (line-end-position))))
          (unless (string-empty-p line) (push line hits)))
        (forward-line 1)))
    (nreverse hits)))

;; WHAT: do the letters of TERM appear, in order, anywhere in PATH?  WHY: used both by
;; `my/ff--filter-other-terms' (below, for a multi-word query's non-primary terms) and by
;; the scoring function (`my/ff--score') to decide whether to award the "in order" bonus.
;; HOW: builds a plain "c1.*c2.*c3..." regexp on the fly from TERM's characters and tests
;; it against PATH with `string-match-p', case-insensitively.
(defun my/ff--in-order-p (term path)
  "Non-nil if the letters of TERM appear in PATH in order (ignoring case)."
  (let ((case-fold-search t))
    (string-match-p (mapconcat (lambda (c) (regexp-quote (string c))) (string-to-list term) ".*") path)))

;; WHAT: does character I of NAME begin a "word" (for scoring purposes)?  WHY: matching
;; at a word boundary (the start of a path component, right after a separator like `_'/
;; `-'/`.'/`/', or at a case transition like "myFile") is a much stronger fuzzy-match
;; signal than matching in the middle of an unrelated word --- this is what lets "mf"
;; score well against "myFile" the way real fuzzy finders (fzf, etc.) do.  HOW: true for
;; the very first character; true right after one of the listed separator characters;
;; true at an uppercase letter immediately following a lowercase one (a camelCase
;; boundary).
(defun my/ff--word-start-p (name i)
  "Non-nil if character I of NAME begins a word: the first letter, one after / _ - . or a capital after a lowercase."
  (or (= i 0)
      (memq (aref name (1- i)) '(?_ ?- ?. ?/))
      (and (>= (aref name i) ?A) (<= (aref name i) ?Z)
           (>= (aref name (1- i)) ?a) (<= (aref name (1- i)) ?z))))

;; WHAT: score PATH as a match for TERM (higher is better) --- roughly fzf-style ranking.
;; WHY: `my/ff--grep'/`my/ff--lisp-grep' above only decide "does this line match at
;; all"; this is what then decides which matches to show FIRST, so an exact or near-exact
;; match always outranks a loose one, even when both technically matched one of the three
;; regex tiers.  HOW, additively: an exact file-name match (ignoring case) scores highest
;; (400); the file name starting with TERM is next (250); TERM appearing anywhere in the
;; file name is next (160) --- these three are mutually exclusive (`cond'), only the best
;; one applies.  Then, independently: +60 if TERM's letters appear in order in the file
;; name at all (`my/ff--in-order-p'); +60 again, separately, if TERM matches somewhere in
;; the FULL PATH (a folder name on the way to the file, e.g. "org" in "lisp/org/ob.el")
;; but explicitly not already counted via the file name itself (`not (string-search lterm
;; lbase)', avoiding double-counting when it matched the file name too); then a per-
;; character loop awards +8 for every one of TERM's characters that lines up with a real
;; word-start position in the file name (via `my/ff--word-start-p') while walking both
;; strings in lockstep --- this is what makes an abbreviation-style match like "mf" for
;; "myFile" score meaningfully better than an equally "in order" but boundary-blind match
;; like "yf" would.
(defun my/ff--score (term path)
  "How good a match PATH is for TERM (higher is better), roughly like fzf: the file name
matching whole or at the start, letters in order, letters at the start of words, and a
short path."
  (let* ((base (file-name-nondirectory path))
         (lbase (downcase base)) (lterm (downcase term))
         (score 0.0))
    (cond ((string= lbase lterm) (cl-incf score 400))
          ((string-prefix-p lterm lbase) (cl-incf score 250))
          ((string-search lterm lbase) (cl-incf score 160)))
    (when (my/ff--in-order-p term base) (cl-incf score 60))
    ;; the word names a folder on the way to the file (for example "org" in lisp/org/ob.el)
    (when (and (not (string-search lterm lbase)) (string-search lterm (downcase path)))
      (cl-incf score 60))
    (let ((i 0) (n (length lterm)))
      (dotimes (j (length base))
        (when (and (< i n) (eq (aref lbase j) (aref lterm i)))
          (when (my/ff--word-start-p base j) (cl-incf score 8))
          (cl-incf i))))
    score))

;; WHAT: score PATH against a MULTI-word query (TERMS, from `my/ff--terms' below).  WHY:
;; a query like "foo bar" should reward a path that matches BOTH words, more than one
;; that only matches one of them well; a small length penalty is then applied so that,
;; among equally good matches, a shorter (more likely to be "the" file being looked for)
;; file name and path both nudge ahead of longer ones.  HOW: sums `my/ff--score' across
;; every term independently, then subtracts a per-character penalty (file name length
;; weighted more heavily than the rest of the path, since the file name is what most
;; directly reflects intent).
(defun my/ff--path-score (terms path)
  "The sum of the scores of every word in TERMS for PATH, less a small penalty for length."
  (- (apply #'+ (mapcar (lambda (term) (my/ff--score term path)) terms))
     (* 1.0 (length (file-name-nondirectory path)))    ; a shorter file name is a closer match
     (* 0.05 (length path))))                           ; then a shorter path

;; WHAT: sort PATHS by score (best first) for TERMS, keeping at most LIMIT.  WHY: this is
;; the final step turning a raw (and possibly duplicate-containing, since a path could be
;; matched by more than one regex tier) list of candidate lines into the actual ranked
;; result list shown to the user.  HOW: `delete-dups' first (a path found by two
;; different tiers should only appear once); pairs each remaining path with its score,
;; sorts descending by score, then `seq-take's just the top LIMIT before stripping the
;; scores back off (`mapcar #'cdr').
(defun my/ff--sorted (terms paths limit)
  (mapcar #'cdr
          (seq-take (sort (mapcar (lambda (p) (cons (my/ff--path-score terms p) p)) (delete-dups paths))
                          (lambda (a b) (> (car a) (car b))))
                    limit)))

;; WHAT: split QUERY into its space-separated words, longest first.  WHY: `my/ff--match-
;; file' below treats the FIRST (longest, per this ordering) term as the "primary" one
;; used to build the actual search regexes, on the theory that the longest word in a
;; query is the most discriminating one and most likely to narrow results down fastest;
;; the remaining terms are then used only as an additional filter (`my/ff--filter-other-
;; terms') over whatever that primary search already found.
(defun my/ff--terms (query)
  "The space-separated words of QUERY, longest first."
  (sort (split-string query "[ \t]+" t) (lambda (a b) (> (length a) (length b)))))

;; WHAT: narrow PATHS down to only those where every term AFTER the first also appears
;; (in order) somewhere in the path.  WHY: this is what makes a multi-word query like
;; "foo bar" actually require both words, rather than just searching for "foo" (the
;; primary/longest term) and ignoring "bar" entirely.  HOW: `(cdr terms)' is every term
;; except the first (already handled by the regex search that produced PATHS in the
;; first place); if there are no other terms, PATHS passes through unchanged.
(defun my/ff--filter-other-terms (terms paths)
  (let ((others (cdr terms)))
    (if others
        (seq-filter (lambda (p) (cl-every (lambda (o) (my/ff--in-order-p o p)) others)) paths)
      paths)))

;; WHAT: once the two "good" match tiers (letters together; letters in order in the file
;; name) together produce this many hits, the loosest tier (letters in order ANYWHERE in
;; the path) is skipped entirely.  WHY: a real speed/quality tradeoff --- the loose tier
;; is both the slowest to search (least selective regex) and the least useful once
;; there's already a healthy number of good candidates to choose from, so skipping it
;; once 20 good hits exist avoids wasted work for no real benefit to the results shown.
(defvar my/ff-enough 20
  "Once the two good match tiers (letters together in the file name; letters in order in the
file name) give this many hits, the loose tier (letters in order anywhere in the path) is skipped.")

;; WHAT: the best matches for QUERY among the lines of FILE (an index or a live listing),
;; best first, at most `my/ff-max-results'.  WHY: this is the shared engine both `my/ff--
;; search-index' and `my/ff--live-search' below are thin wrappers around.  HOW: `terms'
;; splits QUERY (`my/ff--terms'); `term' is the primary (longest) one, the only one the
;; actual regex search below is built from; `lisp' is true only when NEITHER ripgrep nor
;; grep is available, selecting the Emacs-Lisp-regexp-flavored escaping (`regexp-quote')
;; instead of the ERE-flavored one (`my/ff--ere-quote') for `my/ff--regexes'.  If there's
;; no term, or FILE doesn't exist, `hits' stays empty.  Otherwise, walks the three regex
;; tiers from `my/ff--regexes' in order (best/most specific first): always searches at
;; least the first tier; each subsequent tier only runs if `hits' hasn't already reached
;; `my/ff-enough' --- the actual early-exit `my/ff-enough' describes.  Each tier's
;; matches are appended onto `hits' (not deduplicated here --- that happens later, in
;; `my/ff--sorted').  Finally, `my/ff--filter-other-terms' applies any secondary query
;; words, and `my/ff--sorted' does the actual scoring/ranking/truncation.
(defun my/ff--match-file (file query cap)
  "Best matches for QUERY among the lines of FILE, best first (at most `my/ff-max-results')."
  (let* ((terms (my/ff--terms query))
         (term (car terms))
         (lisp (and (not (my/ff--rg)) (not (my/ff--grep-program))))
         (hits nil))
    (when (and term file (file-exists-p file))
      (let ((tiers (my/ff--regexes term (if lisp #'regexp-quote #'my/ff--ere-quote))) (n 0))
        (dolist (rx tiers)
          (setq n (1+ n))
          (when (or (= n 1) (< (length hits) my/ff-enough))
            (setq hits (append hits (if lisp (my/ff--lisp-grep rx file cap) (my/ff--grep rx file cap))))))))
    (my/ff--sorted terms (my/ff--filter-other-terms terms hits) my/ff-max-results)))

;; WHAT: search an already-built INDEX-FILE for QUERY.  WHY/HOW: the CAP passed down to
;; `my/ff--match-file' is deliberately much larger for a multi-word query (4000, versus
;; twice the normal display limit for a single word) --- a multi-word query is filtered
;; further afterward by `my/ff--filter-other-terms', which can only remove candidates, so
;; the underlying regex search needs to gather a wider net up front to leave enough
;; genuinely-matching candidates after that filter runs.
(defun my/ff--search-index (index-file query)
  "Best matches for QUERY among the lines of INDEX-FILE, best first."
  (my/ff--match-file index-file query (if (cdr (my/ff--terms query)) 4000 (* 2 my/ff-max-results))))

;; WHAT: the "index had nothing" fallback --- list every file under ROOTS fresh (right
;; now, hidden/ignored ones included) and match QUERY against that.  WHY: this is what
;; still finds a brand-new, untracked, or otherwise-excluded file that the cached index
;; doesn't know about yet, without needing to wait for a full reindex first.  HOW: lists
;; into a fresh temp file (`my/ff--list-command' called with EVERYTHING = t, so none of
;; the usual exclusion lists apply here --- the whole point is to find what the index
;; skips), then reuses the exact same `my/ff--match-file' matching/scoring engine as the
;; index path, so results from either path are ranked identically.  The temp file is
;; always cleaned up (`unwind-protect') even if matching itself errors.  The docstring's
;; "about a second" claim reflects that no file NAMES are pulled into Emacs itself during
;; the listing step --- only the external tool's raw stdout goes straight to a file,
;; which is what keeps a whole-disk live search from being painfully slow.
(defun my/ff--live-search (roots query)
  "The regular search: list every file under ROOTS now, hidden and ignored ones too, into a
temporary file and match QUERY there with the same matcher as the index (no file names are
pulled into Emacs, so a whole-disk search takes about a second)."
  (let ((tmp (make-temp-file "fastfind-live-")))
    (unwind-protect
        (let ((cmd (my/ff--list-command (mapcar #'expand-file-name roots) t)))
          (let ((default-directory my/ff--root-dir))
            (apply #'call-process (car cmd) nil (list :file tmp) nil (cdr cmd)))
          (my/ff--match-file tmp query (if (cdr (my/ff--terms query)) 4000 (* 2 my/ff-max-results))))
      (ignore-errors (delete-file tmp)))))

;; WHAT: get the actual candidate list for QUERY, trying the index first and only
;; falling back to a live search if the index truly has nothing.  WHY: this is the one
;; function that decides, for any given keystroke, index-vs-live --- everything upstream
;; (the completion table, below) just calls this and doesn't need to know which path was
;; taken.  HOW: returns `(PATHS . LIVE)', LIVE non-nil meaning "this came from the live
;; fallback, not the index" (used purely for the "(not in the index: live search)"
;; annotation shown in the minibuffer, see `my/ff--table' below).  If the index search
;; found anything at all, that's used outright.  Otherwise, as long as the query isn't
;; completely empty (`>= (length (string-trim query)) 1'), a live search runs instead;
;; an empty query intentionally returns `(nil . nil)' --- no candidates and no live
;; search --- rather than triggering an expensive whole-disk scan before the user has
;; typed anything at all.
(defun my/ff--candidates (index-file roots query)
  "(PATHS . LIVE) for QUERY: from INDEX-FILE, or (LIVE = t) from a live search of ROOTS
when the index has nothing."
  (let ((from-index (my/ff--search-index index-file query)))
    (if from-index
        (cons from-index nil)
      (if (>= (length (string-trim query)) 1)
          (cons (my/ff--live-search roots query) t)
        (cons nil nil)))))

;;; The minibuffer

;; WHAT/WHY/HOW: a custom `completion-styles-alist' entry that just shows exactly the
;; candidates the fast finder itself already computed and ranked, in that exact order ---
;; deliberately NOT re-filtering or re-sorting them the way a normal completion style
;; (substring, flex, ...) would, since this file's own scoring (`my/ff--score' etc.) is
;; already the real ranking logic; a generic completion style applied on top would
;; second-guess and likely scramble it.  `my/ff--style-try' just confirms the current
;; input is itself a valid candidate (for `try-completion'-style callers);
;; `my/ff--style-all' returns the pre-computed candidate list as-is for `all-
;; completions'-style callers (the `0' appended via `nconc' is the completion-style
;; convention for "these are already fully formed strings, don't try to find a common
;; prefix boundary within them").
(defun my/ff--style-all (string table pred _point)
  (let ((all (all-completions string table pred)))
    (when all (nconc (copy-sequence all) 0))))

(defun my/ff--style-try (string table pred _point)
  (when (all-completions string table pred) (cons string (length string))))

(add-to-list 'completion-styles-alist
             '(my-fastfind my/ff--style-try my/ff--style-all
                           "Show exactly the candidates the fast finder produced, in its order."))

;; WHAT: build a completion TABLE (a function, in Emacs's completion-table calling
;; convention) that recomputes candidates fresh for each distinct input string.  WHY:
;; this is the bridge between this file's own matching engine and Emacs's standard
;; `completing-read' machinery, so the fuzzy finder can be driven from an ordinary
;; minibuffer prompt.  HOW: INDEX-THUNK is a zero-argument function returning the index
;; file to search (deferred as a thunk rather than a plain value specifically so a
;; project's index can be looked up/rebuilt lazily, only once actually needed --- see
;; `my/ff-find-file' below, where it's `(lambda () (my/ff--project-index root))');
;; ROOTS is what a live-search fallback should list; STRIP, if given, is a folder prefix
;; stripped off each shown path (used so a project search shows paths relative to the
;; project root, rather than full absolute paths).  `last-query'/`last-result' cache the
;; most recent computation, since Emacs's completion machinery can call this table
;; function more than once per actual keystroke; recomputing only happens when STRING has
;; actually changed since last time.  The three actions this function must handle, per
;; Emacs's own completion-table protocol: `metadata' declares this as its own completion
;; category (`my-fastfind', matching the style registered just above) with sorting
;; disabled both ways (`identity' sort functions --- this file's own ranking is already
;; the intended order and must not be re-sorted), plus an `annotation-function' that adds
;; "(not in the index: live search)" next to results when `(cdr last-result)' says this
;; query's candidates came from the live fallback rather than the index; the `t'/`nil'/
;; `lambda' actions are the standard three completion-table queries (list all matches;
;; try to complete the given string; test if it's an exact match) --- `shown' applies the
;; STRIP prefix-removal uniformly before any of the three respond.
(defun my/ff--table (index-thunk roots strip)
  "A completion table over the files, computed afresh for each input.
INDEX-THUNK returns the index file; ROOTS are searched live when the index has nothing;
STRIP, if non-nil, is a folder removed from the front of each shown path."
  (let ((last-query nil) (last-result nil))
    (lambda (string pred action)
      (cond
       ((eq action 'metadata)
        `(metadata (category . my-fastfind) (display-sort-function . identity)
                   (cycle-sort-function . identity)
                   (annotation-function . ,(lambda (_c) (if (cdr last-result) "  (not in the index: live search)" "")))))
       ((memq action '(nil t lambda))
        (unless (equal string last-query)
          ;; An empty query never searches at all (see `my/ff--candidates'), so there is
          ;; nothing to debounce --- waiting here too would just be a pointless pause the
          ;; moment the minibuffer opens, before anything has been typed.
          (if (string-empty-p string)
              (setq last-query string last-result (cons nil nil))
            (when (sit-for my/ff-debounce-seconds)
              (setq last-query string
                    last-result (my/ff--candidates (funcall index-thunk) roots string)))))
        (let ((shown (mapcar (lambda (p) (if (and strip (string-prefix-p strip p)) (substring p (length strip)) p))
                             (car last-result))))
          (cond ((eq action t) shown)
                ((eq action nil) (and shown (if (member string shown) t string)))
                (t (and (member string shown) t)))))))))

;; WHAT: run `completing-read' with this file's own completion style forced on, for
;; TABLE.  WHY: without this, `fido-vertical-mode' (this config's own minibuffer
;; completion UI, set up in init.el) would override the completion style with its own
;; `flex' matching --- which, critically, asks the completion TABLE for candidates
;; matching an EMPTY string (to show something before any typing happens), and this
;; table intentionally returns nothing for an empty query (see `my/ff--candidates'
;; above) --- so without forcing the style back, the minibuffer would immediately show
;; "No matches" before the user even types anything.  HOW: `minibuffer-with-setup-hook'
;; with `:append' is the key detail --- it makes this hook run AFTER fido/icomplete's own
;; setup hook has already run (setup hooks otherwise run in registration order, and
;; fido's own hook runs first normally), so this one gets the final say and its `setq-
;; local completion-styles '(my-fastfind)' actually sticks instead of being immediately
;; overwritten again.
(defun my/ff--read (prompt table)
  ;; :append makes this run AFTER fido/icomplete's own minibuffer setup, which otherwise
  ;; replaces the completion style with `flex' and shows "No matches" (flex asks the table
  ;; for candidates matching an empty string, and this table has none for that).
  (minibuffer-with-setup-hook
      (:append (lambda ()
                 (setq-local completion-styles '(my-fastfind))
                 (setq-local completion-category-overrides nil)
                 (setq-local completion-ignore-case t)))
    (completing-read prompt table nil t)))

;; WHAT: `C-c f g' --- find a file anywhere on the disk.  WHY/HOW: ensures the whole-disk
;; index exists at all (`my/ff-reindex', synchronously, but only the very first time ---
;; `unless (my/ff--age ...)' means this only fires when there is no index file yet, not
;; on every single call); every later call instead relies on `my/ff-maybe-refresh''s own
;; background staleness check (wired in wherever this is actually invoked/idle-scheduled
;; elsewhere in this config) to keep the index up to date without blocking.  Reads via
;; `my/ff--read'/`my/ff--table' with no STRIP (whole-disk results are shown as full,
;; unstripped paths), then opens whatever was chosen.
;;;###autoload
(defun my/ff-find-file-global ()
  "Find a file anywhere on the disk by typing part of its name."
  (interactive)
  (let ((roots my/ff-global-roots))
    (unless (my/ff--age (my/ff--global-index-file))
      (my/ff-reindex))
    (find-file (my/ff--read "Find file (whole disk): "
                            (my/ff--table #'my/ff--global-index-file roots nil)))))

;; WHAT: `C-c f a' --- find a file anywhere on the disk without ever blocking Emacs while
;; typing, not even for the debounce's occasional pause.  WHY: a real, reported problem
;; --- even debounced, `my/ff-find-file-global' still runs a real, synchronous, blocking
;; search each time it actually fires; for someone who wants zero perceived blocking at
;; all, this instead reuses `consult-fd' (`C-c s f', already used here for project-scoped
;; file finding): a real, already-installed, battle-tested asynchronous pipeline
;; (throttled input, a streamed, non-blocking subprocess, live minibuffer refresh as
;; results arrive) instead of building a new one from scratch just for this. HOW:
;; `consult-fd' accepts its DIR argument as either one directory or, per its own
;; documented behavior, a LIST of search paths --- passing `my/ff-global-roots' directly
;; searches the exact same roots `C-c f g' does, just through Consult's own machinery.
;;
;; The real tradeoff, not hidden: `consult-fd' matches file names literally/by regex
;; (whatever `fd' itself supports --- see `consult-fd-args'), not the fuzzy "letters in
;; any order" scoring `my/ff-find-file-global' uses --- genuinely different matching
;; behavior, not a drop-in replacement, in exchange for genuinely never blocking.
;;;###autoload
(defun my/ff-find-file-global-async ()
  "Find a file anywhere on the disk asynchronously (via Consult and fd), so Emacs is
never blocked while you type --- see `my/ff-find-file-global' (`C-c f g') for the
debounced-but-still-synchronous alternative, and its own doc string for the real
difference in matching behavior between the two."
  (interactive)
  (unless (locate-library "consult")
    (user-error "my/ff-find-file-global-async needs Consult: run ./build.sh packages"))
  (require 'consult)
  (consult-fd my/ff-global-roots))

;; WHAT: `C-c f f' --- find a file in the current project, or fall back to the whole disk
;; if there isn't one.  WHY/HOW: `project-current' (no PROMPT argument, so it never asks
;; the user to pick/register a project --- just detects one silently or returns nil) is
;; the one branch point; with no project, this just delegates entirely to `my/ff-find-
;; file-global' above.  With a project, the root is expanded and normalized to always
;; end in a slash (`file-name-as-directory'), the prompt shows just the project's own
;; folder name (not its full path) for a cleaner minibuffer prompt, and the completion
;; table is built with STRIP set to ROOT itself --- meaning results are shown relative to
;; the project root, not as full absolute paths, before being re-expanded back to an
;; absolute path (`expand-file-name choice root') right before actually opening the file.
;;;###autoload
(defun my/ff-find-file ()
  "Find a file in the current project by typing part of its name.
Outside a project, search the whole disk."
  (interactive)
  (let ((pr (project-current)))
    (if (not pr)
        (my/ff-find-file-global)
      (let* ((root (file-name-as-directory (expand-file-name (project-root pr))))
             (choice (my/ff--read (format "Find file (%s): " (file-name-nondirectory (directory-file-name root)))
                                  (my/ff--table (lambda () (my/ff--project-index root)) (list root) root))))
        (find-file (expand-file-name choice root))))))

;; WHAT: an informational command reporting the current state of both index kinds and
;; which matcher is in use.  WHY: a quick way to check "is the index built, how big/old
;; is it, why does a search feel slow" without needing to dig into `my/ff-cache-dir' by
;; hand.  HOW: reports the whole-disk index's line count and age if it exists (or "not
;; built" if not), how many separate project index files exist in the cache directory,
;; and which of the three matcher tiers (ripgrep/grep/Emacs Lisp) is actually active.
(defun my/ff-status ()
  "Show the state of the file indexes."
  (interactive)
  (let ((g (my/ff--global-index-file)))
    (message "Global index: %s; %d project index(es); matcher: %s"
             (if (file-exists-p g)
                 (format "%s lines, %d s old" (with-temp-buffer (insert-file-contents g) (count-lines (point-min) (point-max)))
                         (my/ff--age g))
               "not built")
             (length (and (file-directory-p my/ff-cache-dir) (directory-files my/ff-cache-dir nil "\\`project-")))
             (cond ((my/ff--rg) "ripgrep") ((my/ff--grep-program) "grep") (t "Emacs Lisp")))))

;; WHAT/WHY/HOW: register this file under the Emacs feature name `fastfind', matching the
;; `(require 'fastfind ...)' the relevant test file uses, same as every sibling config
;; file in this project.
(provide 'fastfind)
;;; fastfind.el ends here
