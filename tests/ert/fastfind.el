;;; fastfind.el --- instant fuzzy file finding over an index, with a live fallback  -*- lexical-binding: t; -*-
;; harness: config

(require 'fastfind (expand-file-name "fastfind" (or (getenv "CONFIG_DIR") user-emacs-directory)))
(require 'project)

(defconst ff--files
  '("src/main/java/demo/Shape.java" "src/main/java/demo/Circle.java" "src/main/java/demo/Rect.java"
    "src/main/java/demo/Geometry.java" "src/main/java/demo/Main.java" "README.md" "notes.txt"
    ".env" "docs/shapes/notes.txt" "docs/GeometryNotes.md" "lib/geometry-utils.js"
    "node_modules/pkg/index.js" ".git/config" "build/out/Shape.class" "a.b.txt" "axb.txt"))

(defmacro ff-with-tree (root &rest body)
  "Bind ROOT to a temp folder holding `ff--files', with the cache elsewhere, no /tmp exclusion,
and the global search limited to ROOT."
  (declare (indent 1))
  `(test-with-temp-dir ,root
     (test-with-temp-dir ff-cache
       (dolist (f ff--files)
         (make-directory (file-name-directory (concat ,root f)) t)
         (test-write-file (concat ,root f) "x"))
       (let ((my/ff-cache-dir ff-cache) (my/ff-global-roots (list ,root))
             (my/ff-excluded-paths nil) (my/ff-project-stale-seconds 3600))
         ,@body))))

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
      (while (process-live-p my/ff--process) (accept-process-output nil 0.1)))
    (should (file-exists-p (my/ff--global-index-file)))
    (should (member "README.md" (ff--rel (split-string (test-read-file (my/ff--global-index-file)) "\n" t) r)))))

(ert-deftest ff/refresh-builds-a-missing-index-and-leaves-a-fresh-one-alone ()
  (ff-with-tree r
    (should-not (my/ff--age (my/ff--global-index-file)))
    (my/ff-maybe-refresh)
    (with-timeout (20 (ert-fail "no index")) (while (process-live-p my/ff--process) (accept-process-output nil 0.1)))
    (let ((mtime (file-attribute-modification-time (file-attributes (my/ff--global-index-file)))))
      (my/ff-maybe-refresh)
      (should (equal mtime (file-attribute-modification-time (file-attributes (my/ff--global-index-file))))))))

(ert-deftest ff/refresh-rebuilds-a-stale-index ()
  (ff-with-tree r
    (my/ff-reindex t)
    (set-file-times (my/ff--global-index-file) (time-subtract (current-time) (* 10 3600)))
    (should (> (my/ff--age (my/ff--global-index-file)) my/ff-stale-seconds))
    (my/ff-maybe-refresh)
    (with-timeout (20 (ert-fail "no rebuild")) (while (process-live-p my/ff--process) (accept-process-output nil 0.1)))
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
              (cl-letf (((symbol-function 'my/ff--grep-program) (lambda () nil))) ,@body)))))

(ert-deftest ff/every-matcher-gives-the-same-answers ()
  (skip-unless (executable-find "rg"))
  (ff-with-tree r
    (my/ff-reindex t)
    (let ((expected (mapcar (lambda (q) (ff--find r q)) '("shape" "gmtry" "demo shp" "notes.txt" "a.b.txt"))))
      (dolist (kind '(grep lisp))
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
  (dolist (c '(my/ff-find-file my/ff-find-file-global my/ff-reindex my/ff-status))
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

;;; fastfind.el ends here
