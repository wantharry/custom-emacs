;;; consult.el --- Consult (consult-line/-ripgrep/-fd/-buffer) is wired in, lazy, and finds real matches  -*- lexical-binding: t; -*-
;; harness: config
;; Needs Consult installed (./build.sh packages); the tests that use it skip without it.
;; consult-ripgrep and consult-fd need `rg' and `fd' on PATH; those tests skip without them.

(require 'project)

(defconst cs--files
  '("src/main/java/demo/Shape.java" "src/main/java/demo/Circle.java" "src/main/java/demo/Rect.java"
    "src/main/java/demo/Geometry.java" "src/main/java/demo/Main.java" "README.md" "notes.txt")
  "A small fixture project, the same shape as the ones in fastfind.el and java-navigation.el.")

(defconst cs--shape-body
  "public interface Shape {\n  double area();\n  String name();\n}\n")
(defconst cs--circle-body
  "public class Circle implements Shape {\n  public double area() { return 1; }\n  public String name() { return \"circle\"; }\n}\n")

(defmacro cs-need ()
  ;; the internal `consult--*' functions these tests call directly are not autoloaded (only the
  ;; public commands are), so this loads the library instead of merely checking it exists
  `(if (locate-library "consult") (require 'consult) (ert-skip "consult is not installed (./build.sh packages)")))

(defmacro cs-with-project (root &rest body)
  "Bind ROOT to a fresh git project holding `cs--files', and run BODY there."
  (declare (indent 1))
  `(test-with-temp-dir ,root
     (dolist (f cs--files)
       (make-directory (file-name-directory (concat ,root f)) t)
       (test-write-file (concat ,root f)
                        (cond ((string-suffix-p "Shape.java" f) cs--shape-body)
                              ((string-suffix-p "Circle.java" f) cs--circle-body)
                              (t "x\n"))))
     (let ((default-directory ,root))
       (call-process "git" nil nil nil "init" "-q")
       (call-process "git" nil nil nil "add" "-A"))
     ,@body))

(defun cs--rg-hits (root query)
  "Run the same ripgrep command `consult-ripgrep' would build for QUERY under ROOT,
and return its output lines.  Bypasses the asynchronous minibuffer UI, the way
`consult--ripgrep-make-builder' is meant to be driven by consult itself."
  (let* ((built (funcall (consult--ripgrep-make-builder (list root)) query))
         (cmd (car built)))
    (with-temp-buffer
      (apply #'call-process (car cmd) nil t nil (cdr cmd))
      (split-string (buffer-string) "\n" t))))

(defun cs--fd-hits (root query)
  "The file paths `consult-fd' would list for QUERY under ROOT, with backslashes normalized
to / (on Windows `fd' prints native separators; the fast finder asks ripgrep for / with
`--path-separator', but `consult-fd' does not, so this is `fd''s own default output)."
  (let* ((built (funcall (consult--fd-make-builder (list root)) query))
         (cmd (car built)))
    (with-temp-buffer
      (apply #'call-process (car cmd) nil t nil (cdr cmd))
      (mapcar (lambda (l) (replace-regexp-in-string "\\\\" "/" l))
              (split-string (buffer-string) "\n" t)))))

;;; Wiring

(ert-deftest consult/keys-are-bound-to-autoloads ()
  (unless (locate-library "consult") (ert-skip "consult is not installed"))
  (should (eq (key-binding (kbd "C-c s l")) 'consult-line))
  (should (eq (key-binding (kbd "C-c s g")) 'consult-ripgrep))
  (should (eq (key-binding (kbd "C-c s f")) 'consult-fd))
  (should (eq (key-binding (kbd "C-c s b")) 'consult-buffer)))
  ;; whether `consult-line' is still an autoload stub here depends on whether an earlier test in
  ;; this file already loaded consult; `consult/is-not-loaded-until-used' checks laziness properly,
  ;; in a fresh subprocess.

(ert-deftest consult/is-not-loaded-until-used ()
  ;; In a fresh Emacs, because other tests here load it into this one.
  (let ((out (with-output-to-string
               (with-current-buffer standard-output
                 (call-process test-emacs nil t nil "--batch" "--init-directory" (getenv "CONFIG_DIR")
                               "-l" (expand-file-name "early-init.el" (getenv "CONFIG_DIR"))
                               "-l" (expand-file-name "init.el" (getenv "CONFIG_DIR"))
                               "--eval" "(princ (list (featurep 'consult) (autoloadp (symbol-function 'consult-line))))")))))
    (should (string-match-p "(nil t)" out))))

(ert-deftest consult/is-in-the-package-list ()
  (with-temp-buffer
    (insert-file-contents (expand-file-name "tools/install-packages.el" test-root))
    (should (re-search-forward "(defconst my/packages '([^)]*\\bconsult\\b" nil t))))

(ert-deftest consult/its-dependency-is-satisfied-by-this-emacs ()
  ;; consult requires `compat', which Emacs 32 ships as a built-in library (emacs-lisp/compat.el),
  ;; so no separate compat package is installed; confirm that assumption still holds.
  (cs-need)
  (should (locate-library "compat")))

(ert-deftest consult/is-in-the-startup-not-loaded-list ()
  (with-temp-buffer
    (insert-file-contents (expand-file-name "tests/ert/startup-perf.el" test-root))
    (should (re-search-forward "'(magit treemacs consult doom-themes" nil t))))

(ert-deftest consult/missing-command-explains-how-to-install ()
  (cl-letf (((symbol-function 'locate-library) (lambda (&rest _) nil)))
    (should (equal (let (msg)
                     (cl-letf (((symbol-function 'message) (lambda (fmt &rest a) (setq msg (apply #'format fmt a)))))
                       (my/consult-missing) msg))
                   "Consult is not installed.  Run ./build.sh packages"))))

;;; Real search results (bypassing the async minibuffer UI, which the GUI test drives instead)

(ert-deftest consult/ripgrep-builder-finds-every-real-match ()
  (cs-need)
  (skip-unless (executable-find "rg"))
  (cs-with-project root
    (let ((hits (cs--rg-hits root "area")))
      ;; `area' appears once in Shape.java ("double area();") and once in Circle.java
      ;; ("public double area()"): the fixture bodies above.
      (should (= 2 (length hits)))
      (should (cl-every (lambda (h) (string-match-p "\\bShape\\.java\\|Circle\\.java" h)) hits))
      (should (cl-every (lambda (h) (string-match-p "\\barea\\b" h)) hits)))))

(ert-deftest consult/ripgrep-uses-smart-case-like-project-find-regexp ()
  ;; ripgrep's default "smart case": an all-lowercase query ignores case; a query with any
  ;; uppercase letter becomes case-sensitive.  Same rule `C-x p g' uses (NAVIGATING-CODE.md).
  (cs-need)
  (skip-unless (executable-find "rg"))
  (cs-with-project root
    (test-write-file (concat root "notes.txt") "The AREA of a circle.\n")
    (should (= 3 (length (cs--rg-hits root "area"))))       ; lowercase: matches "area" and "AREA" alike
    (should (= 1 (length (cs--rg-hits root "AREA"))))       ; a capital: case-sensitive, only the exact "AREA"
    (should (= 0 (length (cs--rg-hits root "nonsense-xyz"))))))

(ert-deftest consult/ripgrep-finds-nothing-for-a-fuzzy-filename-style-query ()
  ;; "gmtry" is how the fast finder (C-c f f) matches a FILE NAME; consult-ripgrep matches file
  ;; CONTENT with a literal/regexp pattern, so it must find nothing for that non-literal fragment.
  (cs-need)
  (skip-unless (executable-find "rg"))
  (cs-with-project root
    (should (= 0 (length (cs--rg-hits root "gmtry"))))))

(ert-deftest consult/fd-builder-finds-the-file-by-name ()
  (cs-need)
  (skip-unless (executable-find "fd"))
  (cs-with-project root
    (let ((hits (cs--fd-hits root "Geometry")))
      (should (= 1 (length hits)))
      (should (string-suffix-p "src/main/java/demo/Geometry.java" (car hits))))))

(ert-deftest consult/fd-uses-smart-case-too ()
  ;; Same smart-case rule as ripgrep: "geometry" (all lowercase) ignores the file's real
  ;; capital G; "GEOMETRY" has a capital, so it becomes case-sensitive and does not match.
  (cs-need)
  (skip-unless (executable-find "fd"))
  (cs-with-project root
    (should (= 1 (length (cs--fd-hits root "geometry"))))
    (should (= 0 (length (cs--fd-hits root "GEOMETRY"))))))

(ert-deftest consult/fd-does-not-do-fuzzy-letter-matching ()
  ;; Unlike the fast finder, fd matches a literal fragment of the name, not letters in order.
  (cs-need)
  (skip-unless (executable-find "fd"))
  (cs-with-project root
    (should (= 0 (length (cs--fd-hits root "gmtry"))))))

(ert-deftest consult/line-candidates-include-the-real-lines-of-the-buffer ()
  (cs-need)
  (test-with-temp-dir d
    (let* ((f (test-write-file (concat d "a.txt") "first line\nsecond line\nthird line\n"))
           (b (find-file-noselect f)))
      (unwind-protect
          (with-current-buffer b
            (let ((cands (consult--line-candidates nil 1)))
              (should (cl-some (lambda (c) (string-match-p "\\`second line" c)) cands))
              (should (= 3 (length cands)))))
        (kill-buffer b)))))

;;; The read-only lock: files these commands open must stay locked

(ert-deftest consult/a-file-opened-through-fd-and-find-file-is-read-only ()
  ;; consult-fd hands the chosen path to `find-file' once you pick it (RET); simulate that step
  ;; directly, since driving the async minibuffer end to end is what the GUI test does.
  (cs-need)
  (skip-unless (executable-find "fd"))
  (cs-with-project root
    (let* ((hits (cs--fd-hits root "Geometry")) (b (find-file-noselect (car hits))))
      (unwind-protect (should (buffer-local-value 'buffer-read-only b))
        (kill-buffer b)))))

;;; consult.el ends here
