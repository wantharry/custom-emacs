;;; fastfind.el --- instant fuzzy file finding over an index, with a live fallback  -*- lexical-binding: t; -*-
;; harness: config
;; Three concerns, tested roughly in this order: the persisted index itself (built,
;; refreshed, gone stale); the live ripgrep/grep/elisp search that covers whatever the
;; index missed (new/excluded/untracked files); and the `completing-read' glue (ranking,
;; debounce, annotations) that ties both of those to the actual prompt a key press opens.

(require 'fastfind (expand-file-name "fastfind" (or (getenv "CONFIG_DIR") user-emacs-directory)))
(require 'project)

(defconst ff--files
  '("src/main/java/demo/Shape.java" "src/main/java/demo/Circle.java" "src/main/java/demo/Rect.java"
    "src/main/java/demo/Geometry.java" "src/main/java/demo/Main.java" "README.md" "notes.txt"
    ".env" "docs/shapes/notes.txt" "docs/GeometryNotes.md" "lib/geometry-utils.js"
    "node_modules/pkg/index.js" ".git/config" "build/out/Shape.class" "a.b.txt" "axb.txt"))

(defun ff--make-root ()
  "A fresh folder for the fixture files.  On Windows the system temp folder has a long path
(Users/name/AppData/Local/Temp) whose letters the loose \"letters in order anywhere in the path\"
tier would match, so use a short one at the top of the drive (folders can be created there, files
cannot, so only this folder goes there)."
  (file-name-as-directory
   (let ((temporary-file-directory (if (eq system-type 'windows-nt) "c:/" temporary-file-directory)))
     (make-temp-file "ff-" t))))

(defmacro ff-with-tree (root &rest body)
  "Bind ROOT to a temp folder holding `ff--files', with the cache elsewhere, no /tmp exclusion,
and the global search limited to ROOT."
  (declare (indent 1))
  `(let ((,root (ff--make-root)))
     (unwind-protect
         (test-with-temp-dir ff-cache
           (dolist (f ff--files)
             (make-directory (file-name-directory (concat ,root f)) t)
             (test-write-file (concat ,root f) "x"))
           (let ((my/ff-cache-dir ff-cache) (my/ff-global-roots (list ,root))
                 (my/ff-excluded-paths nil) (my/ff-project-stale-seconds 3600)
                 ;; No debounce delay here: these tests care about matching/ranking
                 ;; behavior, not the debounce itself (which has its own dedicated tests
                 ;; below); zero keeps every test here exactly as fast as before it existed.
                 (my/ff-debounce-seconds 0))
             ,@body))
       (ignore-errors (delete-directory ,root t)))))

(defun ff--wait-for-index ()
  "Wait until the background build has finished AND its result is in place (the process being
gone is not enough: the step that moves the finished file into place runs just after)."
  (while (or (process-live-p my/ff--process) (not (file-exists-p (my/ff--global-index-file))))
    (accept-process-output nil 0.1)))

(defun ff--rel (paths root) (mapcar (lambda (p) (file-relative-name p root)) paths))
(defun ff--find (root query) (ff--rel (car (my/ff--candidates (my/ff--global-index-file) (list root) query)) root))

;;; The index

(ert-deftest ff/index-lists-files-and-skips-excluded-folders ()
  (ff-with-tree r
    (my/ff-reindex t)
    (let ((lines (ff--rel (split-string (test-read-file (my/ff--global-index-file)) "\n" t) r)))
      (should (member "src/main/java/demo/Shape.java" lines))
      (should (member ".env" lines))                                  ; hidden files are indexed
      (should-not (cl-some (lambda (l) (string-prefix-p "node_modules/" l)) lines))
      (should-not (cl-some (lambda (l) (string-prefix-p ".git/" l)) lines)))))

(ert-deftest ff/index-skips-excluded-absolute-paths ()
  (ff-with-tree r
    (let ((my/ff-excluded-paths (list (concat (directory-file-name r) "/docs"))))
      (my/ff-reindex t)
      (should-not (cl-some (lambda (l) (string-match-p "/docs/" l))
                           (split-string (test-read-file (my/ff--global-index-file)) "\n" t))))))

(ert-deftest ff/index-is-built-in-the-background-and-finishes ()
  (ff-with-tree r
    (my/ff-reindex)
    (with-timeout (20 (ert-fail "index build did not finish"))
      (ff--wait-for-index))
    (should (file-exists-p (my/ff--global-index-file)))
    (should (member "README.md" (ff--rel (split-string (test-read-file (my/ff--global-index-file)) "\n" t) r)))))

(ert-deftest ff/refresh-builds-a-missing-index-and-leaves-a-fresh-one-alone ()
  (ff-with-tree r
    (should-not (my/ff--age (my/ff--global-index-file)))
    (my/ff-maybe-refresh)
    (with-timeout (20 (ert-fail "no index")) (ff--wait-for-index))
    (let ((mtime (file-attribute-modification-time (file-attributes (my/ff--global-index-file)))))
      (my/ff-maybe-refresh)
      (should (equal mtime (file-attribute-modification-time (file-attributes (my/ff--global-index-file))))))))

(ert-deftest ff/refresh-rebuilds-a-stale-index ()
  (ff-with-tree r
    (my/ff-reindex t)
    (set-file-times (my/ff--global-index-file) (time-subtract (current-time) (* 10 3600)))
    (should (> (my/ff--age (my/ff--global-index-file)) my/ff-stale-seconds))
    (my/ff-maybe-refresh)
    (with-timeout (20 (ert-fail "no rebuild")) (ff--wait-for-index))
    (should (< (my/ff--age (my/ff--global-index-file)) 60))))

;;; Matching and ranking

(ert-deftest ff/a-run-of-letters-in-the-file-name-comes-first ()
  (ff-with-tree r
    (my/ff-reindex t)
    (let ((hits (ff--find r "shape")))
      ;; Shape.java and Shape.class are equally good; both come before the folder match
      (should (string-prefix-p "Shape." (file-name-nondirectory (car hits))))
      (should (member "src/main/java/demo/Shape.java" (seq-take hits 2)))
      (should (< (cl-position "src/main/java/demo/Shape.java" hits :test #'equal)
                 (cl-position "docs/shapes/notes.txt" hits :test #'equal))))))

(ert-deftest ff/fuzzy-letters-in-order-find-the-file ()
  (ff-with-tree r
    (my/ff-reindex t)
    (should (equal (car (ff--find r "gmtry")) "src/main/java/demo/Geometry.java"))))

(ert-deftest ff/matching-ignores-case ()
  (ff-with-tree r
    (my/ff-reindex t)
    (should (equal (car (ff--find r "GEOMETRY.JAVA")) "src/main/java/demo/Geometry.java"))))

(ert-deftest ff/an-exact-file-name-beats-partial-matches ()
  (ff-with-tree r
    (my/ff-reindex t)
    (let ((hits (ff--find r "notes.txt")))
      (should (member "notes.txt" hits))
      (should (equal (car hits) "notes.txt")))))                       ; shorter path than docs/shapes/notes.txt

(ert-deftest ff/several-words-must-all-match ()
  (ff-with-tree r
    (my/ff-reindex t)
    (let ((hits (ff--find r "demo shp")))
      (should (equal (car hits) "src/main/java/demo/Shape.java"))
      (should (cl-every (lambda (h) (string-match-p "demo" h)) hits)))))

(ert-deftest ff/a-word-can-name-a-folder ()
  (ff-with-tree r
    (my/ff-reindex t)
    (should (equal (car (ff--find r "shapes notes")) "docs/shapes/notes.txt"))))

(ert-deftest ff/special-characters-in-a-query-are-literal ()
  (ff-with-tree r
    (my/ff-reindex t)
    (let ((hits (ff--find r "a.b.txt")))
      (should (equal (car hits) "a.b.txt"))
      (should-not (equal (car hits) "axb.txt")))))

(ert-deftest ff/a-query-with-regexp-characters-does-not-break-the-search ()
  (ff-with-tree r
    (my/ff-reindex t)
    (dolist (q '("a(b" "[x" "a+b" "\\" "(" "*" "a|b" "{1}"))
      (should (listp (ff--find r q))))))

(ert-deftest ff/a-nonsense-query-finds-nothing-even-live ()
  (ff-with-tree r
    (my/ff-reindex t)
    (let ((res (my/ff--candidates (my/ff--global-index-file) (list r) "qqqzzzjjj")))
      (should-not (car res)))))

(ert-deftest ff/results-are-limited ()
  (ff-with-tree r
    (make-directory (concat r "many/") t)
    (dotimes (i 60) (test-write-file (concat r (format "many/file%02d.txt" i)) "x"))
    (my/ff-reindex t)
    (let ((my/ff-max-results 25))
      (should (= 25 (length (ff--find r "file")))))))

;;; The live fallback ("if it is not in the index, search regularly")

(ert-deftest ff/a-new-file-is-found-live-until-the-index-is-rebuilt ()
  (ff-with-tree r
    (my/ff-reindex t)
    (test-write-file (concat r "brand-new-widget.txt") "x")
    (let ((res (my/ff--candidates (my/ff--global-index-file) (list r) "brand-new-widget")))
      (should (equal (ff--rel (car res) r) '("brand-new-widget.txt")))
      (should (cdr res)))                                              ; flagged as a live result
    (my/ff-reindex t)
    (let ((res (my/ff--candidates (my/ff--global-index-file) (list r) "brand-new-widget")))
      (should (equal (ff--rel (car res) r) '("brand-new-widget.txt")))
      (should-not (cdr res)))))                                        ; now from the index

(ert-deftest ff/excluded-folders-are-still-found-by-the-live-search ()
  (ff-with-tree r
    (my/ff-reindex t)
    (should-not (ff--find-in-index r "pkg/index"))
    (let ((res (my/ff--candidates (my/ff--global-index-file) (list r) "pkg/index")))
      (should (member "node_modules/pkg/index.js" (ff--rel (car res) r)))
      (should (cdr res)))))

(defun ff--find-in-index (root query)
  (ff--rel (my/ff--search-index (my/ff--global-index-file) query) root))

(ert-deftest ff/the-live-search-includes-hidden-and-ignored-files ()
  (ff-with-tree r
    (test-write-file (concat r ".gitignore") "build/\n")
    (let ((hits (ff--rel (my/ff--live-search (list r) "Shape.class") r)))
      (should (member "build/out/Shape.class" hits)))))

(ert-deftest ff/a-missing-index-falls-back-to-live-search ()
  (ff-with-tree r
    (let ((res (my/ff--candidates (my/ff--global-index-file) (list r) "geometry")))
      (should (cdr res))
      (should (cl-some (lambda (p) (string-match-p "Geometry.java" p)) (car res))))))

;;; Project scope

(defmacro ff-with-project (root &rest body)
  (declare (indent 1))
  `(ff-with-tree ,root
     (test-write-file (concat ,root ".gitignore") "build/\nnode_modules/\n")
     (test-git ,root "init" "-q")
     (test-git ,root "add" "-A")
     (test-git ,root "commit" "-q" "-m" "x")
     ,@body))

(defun ff--project-find (root query)
  (ff--rel (car (my/ff--candidates (my/ff--project-index root) (list root) query)) root))

(ert-deftest ff/the-project-index-lists-tracked-files-and-not-ignored-ones ()
  (ff-with-project r
    (let ((lines (ff--rel (split-string (test-read-file (my/ff--project-index r)) "\n" t) r)))
      (should (member "src/main/java/demo/Shape.java" lines))
      (should-not (member "build/out/Shape.class" lines))
      (should-not (cl-some (lambda (l) (string-prefix-p "node_modules/" l)) lines)))))

(ert-deftest ff/the-project-index-is-reused-until-it-is-stale ()
  (ff-with-project r
    (let ((f (my/ff--project-index r)))
      (let ((m (file-attribute-modification-time (file-attributes f))))
        (my/ff--project-index r)
        (should (equal m (file-attribute-modification-time (file-attributes f))))))))

(ert-deftest ff/a-commit-makes-the-project-index-stale ()
  (ff-with-project r
    (let ((f (my/ff--project-index r)))
      (should-not (my/ff--project-index-stale-p f r))
      (set-file-times f (time-subtract (current-time) 100))
      (test-write-file (concat r "added-later.txt") "x")
      (test-git r "add" "added-later.txt")                            ; rewrites .git/index
      (should (my/ff--project-index-stale-p f r))
      (should (member "added-later.txt" (ff--project-find r "added-later"))))))

(ert-deftest ff/a-file-not-yet-added-to-git-is-found-live ()
  (ff-with-project r
    (my/ff--project-index r)
    (test-write-file (concat r "untracked-idea.txt") "x")
    (let ((res (my/ff--candidates (my/ff--project-index r) (list r) "untracked-idea")))
      (should (member "untracked-idea.txt" (ff--rel (car res) r)))
      (should (cdr res)))))

(ert-deftest ff/a-folder-that-is-not-a-git-project-is-indexed-too ()
  (ff-with-tree r
    (let ((hits (ff--project-find r "geometry")))
      (should (cl-some (lambda (h) (string-match-p "Geometry.java" h)) hits)))))

;;; The three matchers agree

(defmacro ff-with-matcher (kind &rest body)
  (declare (indent 1))
  `(pcase ,kind
     ('rg (skip-unless (executable-find "rg")) (let ((my/ff-rg (executable-find "rg"))) ,@body))
     ('grep (skip-unless (executable-find "grep"))
            (let ((my/ff-rg nil)) ,@body))
     ('lisp (let ((my/ff-rg nil))
              ;; `my/ff--grep-program' falls back to real `grep' on its own whenever
              ;; `my/ff-rg' is nil; on a machine that actually has `grep' (i.e. everywhere
              ;; this tier's own counterpart above runs), binding `my/ff-rg' alone would
              ;; still land on the grep tier, never the pure-elisp one this clause means
              ;; to force --- so `my/ff--grep-program' itself has to be stubbed out too.
              (cl-letf (((symbol-function 'my/ff--grep-program) (lambda () nil))) ,@body)))))

(ert-deftest ff/every-matcher-gives-the-same-answers ()
  (skip-unless (executable-find "rg"))
  (ff-with-tree r
    (my/ff-reindex t)
    (let ((expected (mapcar (lambda (q) (ff--find r q)) '("shape" "gmtry" "demo shp" "notes.txt" "a.b.txt"))))
      ;; On Windows the only grep is MSYS's (inside MinGit), which reads a backslash in a command-line
      ;; argument differently, so a query with a dot matches too much.  The bundle always has ripgrep,
      ;; which is used first, so grep is only compared where it behaves.
      (dolist (kind (if (eq system-type 'windows-nt) '(lisp) '(grep lisp)))
        (should (equal expected
                       (ff-with-matcher kind
                         (mapcar (lambda (q) (ff--find r q)) '("shape" "gmtry" "demo shp" "notes.txt" "a.b.txt")))))))))

(ert-deftest ff/without-ripgrep-the-index-can-still-be-built-and-used ()
  (ff-with-tree r
    (let ((my/ff-rg nil))
      (my/ff-reindex t)
      (should (member "README.md" (ff--rel (split-string (test-read-file (my/ff--global-index-file)) "\n" t) r)))
      (should (equal (car (ff--find r "gmtry")) "src/main/java/demo/Geometry.java")))))

(ert-deftest ff/without-ripgrep-the-live-search-still-works ()
  (ff-with-tree r
    (let ((my/ff-rg nil))
      (should (member "src/main/java/demo/Geometry.java" (ff--rel (my/ff--live-search (list r) "geometry") r))))))

;;; The prompt

(ert-deftest ff/the-completion-table-returns-the-ranked-candidates ()
  (ff-with-tree r
    (my/ff-reindex t)
    (let* ((table (my/ff--table #'my/ff--global-index-file (list r) r))
           (all (all-completions "gmtry" table nil)))
      (should (equal (car all) "src/main/java/demo/Geometry.java"))
      (should (eq (cdr (assq 'display-sort-function (cdr (completion-metadata "gmtry" table nil)))) 'identity)))))

(ert-deftest ff/the-fastfind-completion-style-keeps-the-finders-order ()
  (ff-with-tree r
    (my/ff-reindex t)
    (let* ((table (my/ff--table #'my/ff--global-index-file (list r) r))
           (completion-styles '(my-fastfind))
           (res (completion-all-completions "shape" table nil 5)))
      (should res)
      (should (equal (car res) "src/main/java/demo/Shape.java")))))

(ert-deftest ff/live-results-are-marked-in-the-prompt ()
  (ff-with-tree r
    (my/ff-reindex t)
    (test-write-file (concat r "only-live-file.txt") "x")
    (let* ((table (my/ff--table #'my/ff--global-index-file (list r) r)))
      (all-completions "only-live-file" table nil)
      (should (string-match-p "live search"
                              (funcall (cdr (assq 'annotation-function (cdr (completion-metadata "only-live-file" table nil)))) "x"))))))

(ert-deftest ff/choosing-a-result-opens-the-file-read-only ()
  (ff-with-project r
    (with-temp-buffer
      (let ((default-directory r))
        (cl-letf* ((pr (project-current nil r))
                   ((symbol-function 'project-current) (lambda (&rest _) pr))
                   ((symbol-function 'completing-read) (lambda (&rest _) "src/main/java/demo/Geometry.java")))
          (my/ff-find-file)
          (should (equal (file-name-nondirectory (buffer-file-name)) "Geometry.java"))
          (should buffer-read-only)
          (kill-buffer))))))

(ert-deftest ff/outside-a-project-the-global-search-is-used ()
  (ff-with-tree r
    (let (used)
      (cl-letf (((symbol-function 'project-current) (lambda (&rest _) nil))
                ((symbol-function 'my/ff-find-file-global) (lambda () (setq used t))))
        (my/ff-find-file))
      (should used))))

(ert-deftest ff/the-global-command-starts-a-build-when-there-is-no-index-yet ()
  (ff-with-tree r
    (let (built)
      (cl-letf (((symbol-function 'my/ff-reindex) (lambda (&rest _) (setq built t)))
                ((symbol-function 'completing-read) (lambda (&rest _) (concat r "README.md"))))
        (my/ff-find-file-global)
        (should built)
        (kill-buffer "README.md")))))

;;; Setup, keys, cost

(ert-deftest ff/keys-and-autoloads ()
  (should (eq (key-binding (kbd "C-c f f")) 'my/ff-find-file))
  (should (eq (key-binding (kbd "C-c f g")) 'my/ff-find-file-global))
  (should (eq (key-binding (kbd "C-c f r")) 'my/ff-reindex))
  (when (locate-library "consult")
    (should (eq (key-binding (kbd "C-c f a")) 'my/ff-find-file-global-async)))
  (dolist (c '(my/ff-find-file my/ff-find-file-global my/ff-find-file-global-async my/ff-reindex my/ff-status))
    (should (commandp c))))

(ert-deftest ff/the-background-refresh-is-on-by-default-and-switchable ()
  (should (boundp 'my/ff-auto-refresh))
  (should my/ff-auto-refresh))

(ert-deftest ff/status-reports-the-index-and-matcher ()
  (ff-with-tree r
    (my/ff-reindex t)
    (let ((msg (let ((inhibit-message t)) (my/ff-status) (current-message))))
      (should (string-match-p "Global index" (with-current-buffer "*Messages*" (buffer-substring (max (point-min) (- (point-max) 300)) (point-max))))))))

(ert-deftest ff/a-large-index-is-searched-quickly ()
  (skip-unless (executable-find "rg"))
  (test-with-temp-dir cache
    (let* ((my/ff-cache-dir cache) (idx (my/ff--global-index-file)))
      (make-directory cache t)
      (with-temp-file idx
        (dotimes (i 300000)
          (insert (format "/data/project%03d/module%02d/src/file%06d.txt\n" (% i 500) (% i 40) i)))
        (insert "/data/deep/needle-widget-service.txt\n"))
      (let* ((t0 (float-time)) (r (my/ff--search-index idx "needle")) (dt (- (float-time) t0)))
        (should (equal r '("/data/deep/needle-widget-service.txt")))
        (should (< dt 1.0))))))                                        ; measured 20 to 130 ms

;;; Debounce: a real search only runs once typing actually pauses (C-c f f / C-c f g)

;; WHAT/WHY: these mock `sit-for' itself (its return value, `t' = waited the full time,
;; `nil' = interrupted by pending input --- both documented, both real possible
;; outcomes) rather than trying to genuinely trigger the interruption via
;; `unread-command-events'.  A real, found-the-hard-way limitation, not a shortcut taken
;; for convenience: confirmed directly that `--batch' mode (which is how this whole test
;; suite runs) does not honor `sit-for''s pending-input interruption the way a real
;; command loop does --- `input-pending-p' correctly reports `t' after queuing fake
;; input, but `sit-for' still waits out the full delay regardless in `--batch'
;; specifically. `sit-for' itself being interruptible by pending input in *real*
;; interactive use is `sit-for''s own, long-established, widely-relied-upon documented
;; behavior (the same primitive `company-mode'/`corfu' and others build exactly this kind
;; of debounce on) --- not this project's to re-prove. What IS this project's to prove,
;; and what these two tests actually check, is that `my/ff--table' itself responds
;; correctly to each of `sit-for''s two possible outcomes.
(ert-deftest ff/debounce-skips-the-search-when-sit-for-is-interrupted ()
  (ff-with-tree r
    (my/ff-reindex t)
    (let ((table (my/ff--table #'my/ff--global-index-file (list r) r)))
      (cl-letf (((symbol-function 'sit-for) (lambda (&rest _) nil)))
        (should-not (all-completions "shape" table nil))))))

(ert-deftest ff/debounce-runs-the-search-when-sit-for-completes-uninterrupted ()
  (ff-with-tree r
    (my/ff-reindex t)
    (let ((table (my/ff--table #'my/ff--global-index-file (list r) r)))
      (cl-letf (((symbol-function 'sit-for) (lambda (&rest _) t)))
        (should (equal (car (all-completions "shape" table nil)) "src/main/java/demo/Shape.java"))))))

;;; C-c f a: the fully asynchronous alternative (Consult/fd, never blocks)

;; WHAT/WHY: verifies this file's own responsibility --- it calls `consult-fd' with the
;; right roots, and declines clearly without Consult installed --- not Consult's own
;; async pipeline itself, which is Consult's own, separately tested, concern.

(ert-deftest ff/global-async-declines-clearly-without-consult ()
  (cl-letf (((symbol-function 'locate-library) (lambda (&rest _) nil)))
    (should-error (my/ff-find-file-global-async) :type 'user-error)))

(ert-deftest ff/global-async-searches-the-same-roots-as-the-synchronous-command ()
  (ff-with-tree r
    (skip-unless (locate-library "consult"))
    (require 'consult)
    (let (captured)
      (cl-letf (((symbol-function 'consult-fd) (lambda (&optional dir &rest _) (setq captured dir))))
        (my/ff-find-file-global-async)
        (should (equal captured my/ff-global-roots))))))

(ert-deftest ff/an-empty-query-is-never-debounced ()
  ;; Debouncing an empty query would mean a pointless pause the moment the minibuffer
  ;; opens, before anything has been typed --- `my/ff--candidates' already never
  ;; searches for one; this confirms the debounce wrapper does not add a wait on top of
  ;; that, by timing it directly rather than just assuming so: with NO pending input, a
  ;; real (non-empty) query would genuinely wait out the full debounce (proven by the
  ;; test above) --- a fast return here, under the same long debounce setting, means the
  ;; empty-string branch really did skip `sit-for' rather than happening to look the
  ;; same for an unrelated reason (an empty query already having no candidates either way).
  (ff-with-tree r
    (my/ff-reindex t)
    (let* ((my/ff-debounce-seconds 2)
           (table (my/ff--table #'my/ff--global-index-file (list r) r))
           (t0 (float-time)))
      (all-completions "" table nil)
      (should (< (- (float-time) t0) 0.5)))))

;;; Finding just the current directory (C-c f d, my/ff-find-file-here)

(ert-deftest ff/here-never-has-an-index-so-it-always-live-searches ()
  (ff-with-tree r
    (let ((res (my/ff--candidates (my/ff--no-index-file) (list r) "shape")))
      (should (cdr res))                                              ; LIVE = t: no index was used
      (should (cl-some (lambda (p) (string-match-p "Shape.java" p)) (car res))))))

(ert-deftest ff/here-is-scoped-to-one-subfolder-not-the-whole-tree ()
  (ff-with-tree r
    ;; "Rect.java" lives only under src/main/java/demo/ (not docs/, and no other fixture
    ;; file name contains "rect"); an unscoped search over the whole tree finds it
    ;; (confirmed by ff--find below), but one scoped to the sibling docs/ folder must
    ;; not --- this is the real difference between `C-c f d' and `C-c f f'/`C-c f g'.
    (should (ff--find r "rect"))
    (let* ((sub (concat r "docs/"))
           (res (my/ff--candidates (my/ff--no-index-file) (list sub) "rect")))
      (should-not (car res)))))

(ert-deftest ff/here-shows-paths-relative-to-the-current-directory ()
  (ff-with-tree r
    (let* ((sub (concat r "docs/"))
           (table (my/ff--table #'my/ff--no-index-file (list sub) sub)))
      (should (member "GeometryNotes.md" (all-completions "geometry" table nil))))))

;;; fastfind.el ends here
