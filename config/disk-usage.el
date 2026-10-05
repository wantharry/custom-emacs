;;; disk-usage.el --- a WizTree-style disk usage browser, powered by `dua'  -*- lexical-binding: t; -*-

;; WHAT: a real, drill-down browser of what is actually using disk space --- largest
;; file/subdirectory first, press RET to descend into one, `^' to go back up, `d' to
;; open it in Dired, `g' to refresh --- the custom half of a real user request
;; ("Wiztree there is app in windows which is very fast how to make that in eMacs can
;; we use that or can we create").
;;
;; WHY: WizTree's own real trick --- reading the NTFS Master File Table directly
;; instead of walking the filesystem --- is genuinely not something portable Elisp (or
;; any portable tool) can do; that is Windows/NTFS-specific, and this config also runs
;; on Linux. `dired-du' (config/init.el's own comment on it, the plain-package half of
;; the same request) is the honest, portable equivalent for "recursive sizes inside
;; Dired," but its own default walk is a normal, single-threaded one, same speed class
;; as plain `du'. This file instead shells out to `dua' (https://github.com/Byron/dua-
;; cli), a real, actively maintained Rust disk-usage scanner that is parallel BY
;; DEFAULT ("will max out your SSD," confirmed directly in its own README) --- not
;; MFT-fast, but a genuinely different, much faster speed class than a serial walk,
;; and it ships real prebuilt binaries for both Windows and Linux (confirmed directly
;; against its GitHub releases), the same shape as the `rg'/`fd'/`delta' binaries this
;; project already bundles for Windows (`tools/dist-windows.sh').
;;
;; HOW: `dua aggregate -f bytes --no-total DIR' --- with exactly ONE input directory
;; and no `--depth', it lists that directory's own immediate children, each already
;; with its own correct RECURSIVE size (confirmed directly, by hand, before writing
;; this file) --- exactly the one building block a drill-down browser needs, with no
;; extra flag or parsing required beyond the plain "<size> b <name>" line format
;; `my/disk-usage--parse-line' expects. Entries from `dua' already come back sorted
;; ascending by size; `my/disk-usage--entries-from-pairs' just reverses that for a
;; WizTree-style "biggest first" view.
;;
;; ASYNC: `dua' runs via `make-process', never `call-process' --- a real, user-raised
;; concern, confirmed directly: the first version of this file used `call-process',
;; which BLOCKS Emacs entirely until the external program exits; against the real
;; ~1.3 TB Windows `C:\' scan tested earlier (118.6 real seconds), that would have
;; frozen Emacs solid for the whole two minutes. `my/disk-usage--refresh' shows a
;; real "Scanning ..." notice (both in the header line and via `message', so it is
;; visible whether or not this buffer is the selected window) the moment a scan that
;; cannot be served from cache actually starts, and updates the buffer from the
;; process's own sentinel once it exits --- guarded against a stale callback (the
;; directory this buffer is showing may have changed again, by drilling further or
;; pressing `g' a second time, before the first scan even finishes) by checking the
;; buffer is still live and still on the SAME directory before acting on the result.
;;
;; CACHING: a real re-scan (shelling out to `dua') only happens the first time a given
;; directory is shown, or when `g' explicitly asks for one, or when that directory's
;; OWN modification time has moved on from what was cached (a real, cheap, portable
;; signal: adding/removing/renaming an entry DIRECTLY inside a directory always
;; updates that directory's own mtime, confirmed standard filesystem behavior on both
;; Windows and Linux) --- user request, so drilling up and back down again, or
;; reopening the same directory later, does not pay for a fresh scan every single
;; time. A real, honest limit, not hidden: a change to a FILE nested two or more
;; levels deep does NOT update its grandparent's own mtime, only its immediate
;; parent's --- so a stale SIZE for a distant ancestor can still show until that
;; ancestor itself is explicitly refreshed with `g'.
;;
;; PERSISTENCE: the cache is saved to `my/disk-usage-cache-file' (a plain hash table,
;; printed with `prin1' and read back with `read' --- confirmed directly that a hash
;; table containing Lisp time values round-trips through this cleanly on this
;; project's own Emacs 30+) after every real scan, and loaded back the moment this
;; file is --- a second, later user request, after first shipping a session-only
;; version: "make sure it indexes and save ... so we don't have to do it every time,"
;; meaning across restarts too, not just within one. Gitignored like `recentf.eld'/
;; `places.eld' already are (the blanket `/config/*' rule already covers it; this is
;; state, not a real source file, so it gets no explicit `!' exception in
;; `.gitignore' the way `disk-usage.el' itself needed). No automatic eviction --- the
;; same simple, user-manageable treatment this project's other `.eld' state files
;; already get; delete the file by hand if it ever grows larger than wanted.

(require 'tabulated-list)
(require 'dired)

(defvar my/disk-usage-dua-command "dua"
  "The `dua' (disk usage analyzer) binary used by `my/disk-usage'.
See https://github.com/Byron/dua-cli --- on Windows, bundled with this project's own
dist zip (`tools/dist-windows.sh'); on Linux, expected to already be on PATH (not
bundled here, the same treatment `fd'/`delta' already get, see that script's own
comment on the difference between those and the bundled `rg').")

(defconst my/disk-usage-buffer-name "*Disk Usage*")

(defvar-local my/disk-usage--directory nil
  "The directory this `*Disk Usage*' buffer is currently showing.")

(defvar-local my/disk-usage--history nil
  "Directories visited before the current one, for `my/disk-usage-up' --- always the
real ancestor chain, since this buffer only ever moves by drilling into a child or
popping back off this same list, never by jumping sideways.")

(defun my/disk-usage--parse-line (line)
  "Return (SIZE . NAME) from one real line of `dua aggregate -f bytes --no-total'
output (\"      4096 b somefile\"), or nil for a line that is not one of those (a
stray stderr warning about a file `dua' could not read, for instance --- left in the
same buffer `call-process' writes to, since separating streams buys nothing here:
a non-matching line is simply not a real entry, not something to error out over)."
  (when (string-match "\\`[ \t]*\\([0-9]+\\) b \\(.+\\)\\'" line)
    (cons (string-to-number (match-string 1 line)) (match-string 2 line))))

(defconst my/disk-usage-cache-file (expand-file-name "disk-usage-cache.eld" user-emacs-directory)
  "Where `my/disk-usage--cache' is persisted across restarts; see this file's own
header comment, \"PERSISTENCE\".")

(defun my/disk-usage--load-cache ()
  "The real, saved cache from a previous session, or a fresh empty one --- never
signals: a missing, truncated or otherwise unreadable cache file just means
starting fresh, not something to error out over (the file is pure derived state,
nothing is ever lost that a real re-scan could not simply rebuild)."
  (or (and (file-exists-p my/disk-usage-cache-file)
           (ignore-errors
             (with-temp-buffer
               (insert-file-contents my/disk-usage-cache-file)
               (car (read-from-string (buffer-string))))))
      (make-hash-table :test #'equal)))

(defvar my/disk-usage--cache (my/disk-usage--load-cache)
  "DIR (as `expand-file-name') -> (MTIME . PAIRS), for `my/disk-usage--scan'.
Persisted to `my/disk-usage-cache-file'; see this file's own header comment,
\"CACHING\"/\"PERSISTENCE\".")

(defun my/disk-usage--save-cache ()
  "Write `my/disk-usage--cache' to `my/disk-usage-cache-file' --- never signals,
the same reasoning as `my/disk-usage--load-cache': a failed save (a read-only
filesystem, no disk space, ...) should not break the browse that triggered it,
only mean the next real session starts from an empty cache again."
  (ignore-errors
    (let ((print-length nil) (print-level nil))
      (with-temp-file my/disk-usage-cache-file
        (prin1 my/disk-usage--cache (current-buffer))))))

(defun my/disk-usage--dir-mtime (dir)
  (file-attribute-modification-time (file-attributes dir)))

(defun my/disk-usage--cached-pairs (dir force)
  "The cached (SIZE . NAME) pairs for DIR if they are still valid and FORCE is
nil, or the symbol `none' if a real scan is needed --- distinct from nil, which
is also what a genuinely empty directory's own real scan returns."
  (let* ((mtime (my/disk-usage--dir-mtime dir))
         (cached (gethash dir my/disk-usage--cache)))
    (if (and (not force) cached (time-equal-p (car cached) mtime))
        (cdr cached)
      'none)))

(defvar my/disk-usage-async t
  "Whether `my/disk-usage' scans with `dua' asynchronously (the default) or
synchronously.  Asynchronous (`make-process') never blocks Emacs, however long a
real scan takes --- see this file's own header comment, \"ASYNC\"; this is what
most people want, and what a big directory/whole drive genuinely needs. Synchronous
(`call-process') is simpler and perfectly fine for a small, fast directory, and is
kept as a real, available option rather than removed --- toggle it with
`my/disk-usage-toggle-async' (`a' in `my/disk-usage-mode').")

(defun my/disk-usage--parse-dua-output (output)
  (nreverse (delq nil (mapcar #'my/disk-usage--parse-line (split-string output "\n" t)))))

(defun my/disk-usage--finish-scan (dir mtime callback pairs)
  "Common to both the sync and async paths: cache a real scan's PAIRS and hand
them to CALLBACK."
  (puthash dir (cons mtime pairs) my/disk-usage--cache)
  (my/disk-usage--save-cache)
  (funcall callback pairs))

(defun my/disk-usage--scan-sync (dir mtime callback)
  "The ORIGINAL, simpler path: run `dua' with `call-process', which blocks all of
Emacs until it exits.  Fine for a small, fast directory; see `my/disk-usage-async'."
  (let (status output)
    (with-temp-buffer
      (setq status (call-process my/disk-usage-dua-command nil t nil
                                  "aggregate" "-f" "bytes" "--no-total" dir)
            output (buffer-string)))
    (if (zerop status)
        (my/disk-usage--finish-scan dir mtime callback (my/disk-usage--parse-dua-output output))
      (funcall callback (cons :error output)))))

(defun my/disk-usage--scan-async-1 (dir mtime callback)
  "The async path: run `dua' with `make-process', never blocking Emacs; see
`my/disk-usage-async' and this file's own header comment, \"ASYNC\". Returns the
live process."
  (let ((outbuf (generate-new-buffer " *dua-output*")))
    (make-process
     :name "dua" :buffer outbuf :noquery t :connection-type 'pipe
     :command (list my/disk-usage-dua-command "aggregate" "-f" "bytes" "--no-total" dir)
     :sentinel
     (lambda (proc _event)
       (unless (process-live-p proc)
         (unwind-protect
             (if (zerop (process-exit-status proc))
                 (my/disk-usage--finish-scan
                  dir mtime callback
                  (my/disk-usage--parse-dua-output (with-current-buffer outbuf (buffer-string))))
               (funcall callback (cons :error (with-current-buffer outbuf (buffer-string)))))
           (kill-buffer outbuf)))))))

(defun my/disk-usage--scan-async (dir force callback)
  "Arrange for CALLBACK to be called with DIR's real (SIZE . NAME) pairs, biggest
first --- synchronously, right here, if a valid cache entry covers it (FORCE nil);
otherwise by actually running `dua', either async or sync depending on
`my/disk-usage-async'. Returns the live `dua' process when an ASYNC scan was
started (for `my/disk-usage--pending-process' to track), or nil otherwise (a
cache hit, or a sync scan --- both of which already called CALLBACK by the time
this returns)."
  (setq dir (expand-file-name dir))
  (let ((pairs (my/disk-usage--cached-pairs dir force)))
    (if (not (eq pairs 'none))
        (progn (funcall callback pairs) nil)
      (let ((mtime (my/disk-usage--dir-mtime dir)))
        (if my/disk-usage-async
            (my/disk-usage--scan-async-1 dir mtime callback)
          (my/disk-usage--scan-sync dir mtime callback)
          nil)))))

(defun my/disk-usage-toggle-async ()
  "Toggle whether `my/disk-usage' scans asynchronously (never blocks Emacs) or
synchronously (simpler, blocks while `dua' runs) --- see `my/disk-usage-async'."
  (interactive)
  (setq my/disk-usage-async (not my/disk-usage-async))
  (message "Disk usage: now scanning %s" (if my/disk-usage-async "asynchronously (does not block Emacs)" "synchronously (blocks Emacs while dua runs)")))

(defun my/disk-usage--size-cell (size)
  "A human-readable string for SIZE, with the real byte count attached as a text
property --- `my/disk-usage--sort-by-size' reads this back directly rather than
re-parsing its own already-formatted display string (\"59.6M\"), which `string<'
would sort wrong against something like \"4.0K\"."
  (propertize (file-size-human-readable size) 'my/disk-usage-size size))

(defun my/disk-usage--sort-by-size (a b)
  (< (get-text-property 0 'my/disk-usage-size (aref (cadr a) 0))
     (get-text-property 0 'my/disk-usage-size (aref (cadr b) 0))))

(defun my/disk-usage--entries-from-pairs (pairs dir)
  (mapcar
   (lambda (pair)
     (let* ((size (car pair)) (name (cdr pair))
            (path (expand-file-name name dir))
            (dirp (file-directory-p path)))
       (list path
             (vector (my/disk-usage--size-cell size)
                     (if dirp (propertize (concat name "/") 'face 'dired-directory) name)))))
   pairs))

(defvar-local my/disk-usage--pending-process nil
  "The `dua' process a not-yet-finished `my/disk-usage--refresh' is waiting on,
or nil --- a second scan started before the first finishes (`g' pressed twice, or
drilling again quickly) kills this one first, so its now-irrelevant result can
never land in the buffer after the newer one already has.")

(defun my/disk-usage--refresh (&optional force)
  "Show `my/disk-usage--directory', from the cache if valid or by starting a
real `dua' scan otherwise, async or sync depending on `my/disk-usage-async'."
  (when (process-live-p my/disk-usage--pending-process)
    (delete-process my/disk-usage--pending-process))
  (let* ((dir my/disk-usage--directory) (buf (current-buffer))
         (label (abbreviate-file-name dir))
         ;; Only announce a scan when one will actually happen --- a cache hit
         ;; calls CALLBACK synchronously, below, with nothing real to wait on.
         (will-scan (eq (my/disk-usage--cached-pairs dir force) 'none)))
    (when will-scan
      (setq-local header-line-format
                  (format "Scanning %s ... (%s)" label
                          (if my/disk-usage-async "async, Emacs stays responsive" "sync, Emacs will freeze until done")))
      (message "Disk usage: scanning %s ..." label)
      ;; Flushes the notice above to the screen right now --- for a SYNC scan this
      ;; is the only chance: `call-process' blocks before Emacs would otherwise
      ;; get to redisplay on its own, so without this the notice would not
      ;; actually become visible until after the freeze it is warning about.
      ;; Harmless, and a no-op in practice, for the async path.
      (force-mode-line-update)
      (redisplay t))
    (setq my/disk-usage--pending-process
          (my/disk-usage--scan-async
           dir force
           (lambda (pairs)
             ;; Guard against a stale callback: this buffer may have moved on to a
             ;; different directory (or been killed) before this scan finished.
             (when (and (buffer-live-p buf)
                        (with-current-buffer buf (equal my/disk-usage--directory dir)))
               (with-current-buffer buf
                 (setq my/disk-usage--pending-process nil)
                 (if (and (consp pairs) (eq (car pairs) :error))
                     (progn
                       (setq-local header-line-format (format "%s --- dua FAILED, g to retry" label))
                       (message "Disk usage: dua failed for %s: %s" label (cdr pairs)))
                   (setq tabulated-list-entries (my/disk-usage--entries-from-pairs pairs dir))
                   (tabulated-list-print t)
                   (goto-char (point-min))
                   (rename-buffer (format "*Disk Usage: %s*" label) t)
                   (setq-local header-line-format
                               (format "%s  ---  RET/f: open  ^/u: up  d: Dired here  g: refresh  a: %s  q: quit"
                                       label (if my/disk-usage-async "async" "sync")))
                   (message "Disk usage: %s done" label)))))))
  nil))

(defvar my/disk-usage-mode-map
  (let ((map (make-sparse-keymap)))
    (set-keymap-parent map tabulated-list-mode-map)
    (define-key map (kbd "RET") #'my/disk-usage-visit)
    (define-key map "f" #'my/disk-usage-visit)
    (define-key map "^" #'my/disk-usage-up)
    (define-key map "u" #'my/disk-usage-up)
    (define-key map "d" #'my/disk-usage-dired-here)
    (define-key map "g" #'my/disk-usage-refresh)
    (define-key map "a" #'my/disk-usage-toggle-async)
    (define-key map "q" #'quit-window)
    map)
  "Keymap for `my/disk-usage-mode'.")

(define-derived-mode my/disk-usage-mode tabulated-list-mode "Disk Usage"
  "A WizTree-style, drill-down browser of real disk usage, powered by `dua'.
See config/disk-usage.el's own header comment for the full WHAT/WHY/HOW."
  (setq tabulated-list-format
        [("Size" 10 my/disk-usage--sort-by-size) ("Name" 0 t)])
  (setq tabulated-list-padding 1)
  (tabulated-list-init-header))

(defun my/disk-usage-visit ()
  "Drill into the directory at point.  Does nothing on a plain file --- there is
nowhere further to go, same as `dired-find-file' on a file vs. a directory."
  (interactive)
  (let ((path (tabulated-list-get-id)))
    (when (and path (file-directory-p path))
      (push my/disk-usage--directory my/disk-usage--history)
      (setq my/disk-usage--directory path)
      (my/disk-usage--refresh))))

(defun my/disk-usage-up ()
  "Go back to the directory this one was drilled into FROM --- the real parent in
the chain of drills, not necessarily `file-name-directory' (though in practice,
since this buffer only ever moves by drilling in or popping back off the same
history, they are always the same real directory)."
  (interactive)
  (when my/disk-usage--history
    (setq my/disk-usage--directory (pop my/disk-usage--history))
    (my/disk-usage--refresh)))

(defun my/disk-usage-dired-here ()
  "Open the entry at point (or this buffer's own directory, with no entry at
point) in a real Dired buffer --- for anything this browser itself does not do
(renaming, deleting, ...), hand off to Dired rather than reinventing it."
  (interactive)
  (dired (or (tabulated-list-get-id) my/disk-usage--directory)))

(defun my/disk-usage-refresh ()
  "Force a real re-scan of the current directory, bypassing the cache."
  (interactive)
  (my/disk-usage--refresh t))

;;;###autoload
(defun my/disk-usage (&optional dir)
  "Browse DIR's disk usage, largest file/subdirectory first, powered by `dua'.
Prompts for DIR (defaulting to the current directory) when called interactively."
  (interactive (list (read-directory-name "Disk usage for: " default-directory)))
  (unless (executable-find my/disk-usage-dua-command)
    (user-error "`dua' is not installed/not on PATH --- see docs/DISK-USAGE.md"))
  (let ((buf (get-buffer-create my/disk-usage-buffer-name)))
    (with-current-buffer buf
      (my/disk-usage-mode)
      (setq my/disk-usage--directory (expand-file-name dir))
      (setq my/disk-usage--history nil)
      (my/disk-usage--refresh))
    (switch-to-buffer buf)))

(provide 'disk-usage)
;;; disk-usage.el ends here
