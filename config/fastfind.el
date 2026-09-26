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

(require 'project)
(require 'subr-x)
(require 'cl-lib)

(defgroup my-fastfind nil "Instant fuzzy file finding." :group 'convenience)

(defvar my/ff-cache-dir (locate-user-emacs-file "fastfind/")
  "Where the index files are kept.")
(defvar my/ff-global-roots '("/")
  "Folders indexed for the whole-disk search.  Other file systems are not entered, so the
Windows drive under /mnt is left out.")
(defvar my/ff-excluded-names '(".git" "node_modules" "__pycache__" ".cache" ".npm" ".rustup"
                               ".cargo/registry" ".gradle" ".m2/repository" "target/debug")
  "Folder names left out of the whole-disk index.  The live fallback does not use this.")
(defvar my/ff-excluded-paths '("/proc" "/sys" "/dev" "/run" "/mnt" "/tmp" "/snap")
  "Absolute folders left out of the whole-disk index.")
(defvar my/ff-max-results 200 "Most candidates shown.")
(defvar my/ff-stale-seconds (* 6 3600) "Age after which the whole-disk index is rebuilt.")
(defvar my/ff-project-stale-seconds 60 "Age after which a project index is rebuilt.")
(defvar my/ff-rg 'auto
  "The ripgrep program: `auto' finds it, nil forces the fallbacks (grep, then Lisp).")

;;; Tools

(defun my/ff--rg ()
  (if (eq my/ff-rg 'auto) (setq my/ff-rg (executable-find "rg")) my/ff-rg))

(defun my/ff--grep-program ()
  (and (not (my/ff--rg)) (executable-find "grep")))

(defun my/ff--ere-quote (string)
  "Escape STRING for ripgrep and grep -E."
  (replace-regexp-in-string "[][\\\\.^$*+?(){}|]" "\\\\\\&" string))

;;; Index files

(defun my/ff--global-index-file () (expand-file-name "global.idx" my/ff-cache-dir))

(defun my/ff--project-index-file (root)
  (expand-file-name (format "project-%s.idx" (md5 (expand-file-name root))) my/ff-cache-dir))

(defun my/ff--age (file)
  "Seconds since FILE was modified, or nil if it does not exist."
  (when (file-exists-p file)
    (float-time (time-subtract (current-time) (file-attribute-modification-time (file-attributes file))))))

;; ripgrep resolves an absolute exclusion pattern relative to the folder it runs in, so every
;; listing runs from / (from anywhere else the pattern silently excludes nothing).
(defun my/ff--list-command (roots &optional everything)
  "The command that prints every file under ROOTS, one per line.
Unless EVERYTHING, the excluded folders are skipped (the index); with it, nothing is
(the live fallback)."
  (if (my/ff--rg)
      (append (list (my/ff--rg) "--files" "--hidden" "--no-ignore" "--one-file-system" "--no-messages")
              (unless everything
                (append (mapcan (lambda (n) (list "--glob" (format "!**/%s/**" n))) my/ff-excluded-names)
                        (mapcan (lambda (p) (list "--glob" (format "!%s/**" p))) my/ff-excluded-paths)))
              roots)
    (append (list "find") roots '("-xdev")
            (unless everything
              (append '("(") (cl-loop for n in my/ff-excluded-names
                                      unless (string-match-p "/" n)
                                      append (list "-name" n "-o"))
                      (cl-loop for p in my/ff-excluded-paths append (list "-path" p "-o"))
                      '("-false" ")" "-prune" "-o")))
            '("-type" "f" "-print"))))

(defvar my/ff--process nil "The running whole-disk index build, if any.")

(defun my/ff-reindex (&optional sync)
  "Rebuild the whole-disk index in the background (or now, with SYNC).
Bound to C-c f r."
  (interactive)
  (make-directory my/ff-cache-dir t)
  (let* ((file (my/ff--global-index-file))
         (cmd (my/ff--list-command (mapcar #'expand-file-name my/ff-global-roots)))
         (script "\"$@\" > \"$0.tmp\" 2>/dev/null; mv \"$0.tmp\" \"$0\""))
    (cond
     (sync (let ((default-directory "/")) (apply #'call-process "sh" nil nil nil "-c" script file cmd)))
     ((process-live-p my/ff--process) (message "Index is already being built"))
     (t (setq my/ff--process
              (let ((default-directory "/"))
               (make-process :name "fastfind-index" :buffer nil :noquery t
                            :command (append (list "sh" "-c" script file) cmd)
                            :sentinel (lambda (_p event)
                                        (when (string-prefix-p "finished" event)
                                          (message "Fast file index ready (%s)"
                                                   (file-name-nondirectory (my/ff--global-index-file)))))))))))
  (when (called-interactively-p 'interactive) (message "Building the file index in the background ...")))

(defun my/ff-maybe-refresh ()
  "Build the whole-disk index if it is missing or old.  Runs in the background."
  (let ((age (my/ff--age (my/ff--global-index-file))))
    (when (or (null age) (> age my/ff-stale-seconds))
      (my/ff-reindex))))

(defun my/ff--project-index-stale-p (file root)
  "Non-nil if the index FILE for the project at ROOT is missing, old, or older than git's own index."
  (let ((age (my/ff--age file)))
    (or (null age)
        (> age my/ff-project-stale-seconds)
        ;; a commit, add or checkout rewrites .git/index: the file list has changed
        (let ((git-age (my/ff--age (expand-file-name ".git/index" root))))
          (and git-age (< git-age age))))))

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
              (let ((default-directory "/"))
                (apply #'call-process (car cmd) nil t nil (cdr cmd))))))))
    file))

;;; Matching

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

(defun my/ff--in-order-p (term path)
  "Non-nil if the letters of TERM appear in PATH in order (ignoring case)."
  (let ((case-fold-search t))
    (string-match-p (mapconcat (lambda (c) (regexp-quote (string c))) (string-to-list term) ".*") path)))

(defun my/ff--word-start-p (name i)
  "Non-nil if character I of NAME begins a word: the first letter, one after / _ - . or a capital after a lowercase."
  (or (= i 0)
      (memq (aref name (1- i)) '(?_ ?- ?. ?/))
      (and (>= (aref name i) ?A) (<= (aref name i) ?Z)
           (>= (aref name (1- i)) ?a) (<= (aref name (1- i)) ?z))))

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

(defun my/ff--path-score (terms path)
  "The sum of the scores of every word in TERMS for PATH, less a small penalty for length."
  (- (apply #'+ (mapcar (lambda (term) (my/ff--score term path)) terms))
     (* 1.0 (length (file-name-nondirectory path)))    ; a shorter file name is a closer match
     (* 0.05 (length path))))                           ; then a shorter path

(defun my/ff--sorted (terms paths limit)
  (mapcar #'cdr
          (seq-take (sort (mapcar (lambda (p) (cons (my/ff--path-score terms p) p)) (delete-dups paths))
                          (lambda (a b) (> (car a) (car b))))
                    limit)))

(defun my/ff--terms (query)
  "The space-separated words of QUERY, longest first."
  (sort (split-string query "[ \t]+" t) (lambda (a b) (> (length a) (length b)))))

(defun my/ff--filter-other-terms (terms paths)
  (let ((others (cdr terms)))
    (if others
        (seq-filter (lambda (p) (cl-every (lambda (o) (my/ff--in-order-p o p)) others)) paths)
      paths)))

(defvar my/ff-enough 20
  "Once the two good match tiers (letters together in the file name; letters in order in the
file name) give this many hits, the loose tier (letters in order anywhere in the path) is skipped.")

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

(defun my/ff--search-index (index-file query)
  "Best matches for QUERY among the lines of INDEX-FILE, best first."
  (my/ff--match-file index-file query (if (cdr (my/ff--terms query)) 4000 (* 2 my/ff-max-results))))

(defun my/ff--live-search (roots query)
  "The regular search: list every file under ROOTS now, hidden and ignored ones too, into a
temporary file and match QUERY there with the same matcher as the index (no file names are
pulled into Emacs, so a whole-disk search takes about a second)."
  (let ((tmp (make-temp-file "fastfind-live-")))
    (unwind-protect
        (let ((cmd (my/ff--list-command (mapcar #'expand-file-name roots) t)))
          (let ((default-directory "/"))
            (apply #'call-process (car cmd) nil (list :file tmp) nil (cdr cmd)))
          (my/ff--match-file tmp query (if (cdr (my/ff--terms query)) 4000 (* 2 my/ff-max-results))))
      (ignore-errors (delete-file tmp)))))

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

(defun my/ff--style-all (string table pred _point)
  (let ((all (all-completions string table pred)))
    (when all (nconc (copy-sequence all) 0))))

(defun my/ff--style-try (string table pred _point)
  (when (all-completions string table pred) (cons string (length string))))

(add-to-list 'completion-styles-alist
             '(my-fastfind my/ff--style-try my/ff--style-all
                           "Show exactly the candidates the fast finder produced, in its order."))

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
          (setq last-query string
                last-result (my/ff--candidates (funcall index-thunk) roots string)))
        (let ((shown (mapcar (lambda (p) (if (and strip (string-prefix-p strip p)) (substring p (length strip)) p))
                             (car last-result))))
          (cond ((eq action t) shown)
                ((eq action nil) (and shown (if (member string shown) t string)))
                (t (and (member string shown) t)))))))))

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

;;;###autoload
(defun my/ff-find-file-global ()
  "Find a file anywhere on the disk by typing part of its name."
  (interactive)
  (let ((roots my/ff-global-roots))
    (unless (my/ff--age (my/ff--global-index-file))
      (my/ff-reindex))
    (find-file (my/ff--read "Find file (whole disk): "
                            (my/ff--table #'my/ff--global-index-file roots nil)))))

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

(provide 'fastfind)
;;; fastfind.el ends here
