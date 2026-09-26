;;; java-navigation.el --- find files, find symbols, definitions, implementations, references  -*- lexical-binding: t; -*-
;; harness: config
;; The project and search tests run offline.  The tests that talk to a real Java language
;; server (jdtls) run only with RUN_LSP_TESTS=1 (tests/run-all.sh --lsp).

(require 'project) (require 'xref) (require 'eglot) (require 'jsonrpc) (require 'imenu)

(defconst jn--files
  '(("src/main/java/demo/Shape.java"
     "package demo;\n\n/** Something that has an area. */\npublic interface Shape {\n    double area();\n\n    String name();\n}\n")
    ("src/main/java/demo/Circle.java"
     "package demo;\n\npublic class Circle implements Shape {\n    private final double radius;\n\n    public Circle(double radius) {\n        this.radius = radius;\n    }\n\n    @Override\n    public double area() {\n        return Math.PI * radius * radius;\n    }\n\n    @Override\n    public String name() {\n        return \"circle\";\n    }\n}\n")
    ("src/main/java/demo/Rect.java"
     "package demo;\n\npublic class Rect implements Shape {\n    private final double w;\n    private final double h;\n\n    public Rect(double w, double h) {\n        this.w = w;\n        this.h = h;\n    }\n\n    @Override\n    public double area() {\n        return w * h;\n    }\n\n    @Override\n    public String name() {\n        return \"rect\";\n    }\n}\n")
    ("src/main/java/demo/Geometry.java"
     "package demo;\n\nimport java.util.List;\n\npublic class Geometry {\n    /** Sum of the areas of all the shapes. */\n    public static double total(List<? extends Shape> shapes) {\n        double sum = 0;\n        for (Shape s : shapes) {\n            sum += s.area();\n        }\n        return sum;\n    }\n\n    public static String describe(Shape s) {\n        return s.name() + \" with area \" + s.area();\n    }\n}\n")
    ("src/main/java/demo/Main.java"
     "package demo;\n\nimport java.util.List;\n\npublic class Main {\n    public static void main(String[] args) {\n        List<Shape> shapes = List.of(new Circle(1.5), new Rect(2, 3));\n        System.out.println(\"total = \" + Geometry.total(shapes));\n        for (Shape s : shapes) {\n            System.out.println(Geometry.describe(s));\n        }\n    }\n}\n")
    ("README.md" "# demo\n")
    ("notes.txt" "scratch\n")))

(defmacro jn-with-project (dir &rest body)
  "Bind DIR to a temporary git project laid out like the demo Java project."
  (declare (indent 1))
  `(test-with-temp-dir ,dir
     (dolist (f jn--files)
       (make-directory (file-name-directory (concat ,dir (car f))) t)
       (test-write-file (concat ,dir (car f)) (cadr f)))
     (test-git ,dir "init" "-q")
     (test-git ,dir "add" "-A")
     (test-git ,dir "commit" "-q" "-m" "demo")
     ,@body))

(defun jn--rel (files dir) (sort (mapcar (lambda (f) (file-relative-name f dir)) files) #'string<))

;;; Find a file in the project (offline)

(ert-deftest jnav/project-root-is-the-git-folder ()
  (jn-with-project d
    (with-temp-buffer
      (let ((default-directory (concat d "src/main/java/demo/")))
        (should (equal (file-truename (project-root (project-current)))
                       (file-truename d)))))))

(ert-deftest jnav/project-find-file-lists-every-tracked-file ()
  (jn-with-project d
    (let ((files (jn--rel (project-files (project-current nil d)) d)))
      (should (member "src/main/java/demo/Circle.java" files))
      (should (member "README.md" files))
      (should-not (cl-some (lambda (f) (string-prefix-p ".git/" f)) files)))))

(ert-deftest jnav/new-untracked-files-are-listed-and-ignored-ones-are-not ()
  (jn-with-project d
    (test-write-file (concat d ".gitignore") "build/\n*.class\n")
    (make-directory (concat d "build") t)
    (test-write-file (concat d "build/out.txt") "x")
    (test-write-file (concat d "src/main/java/demo/New.java") "package demo; class New {}")
    (let ((files (jn--rel (project-files (project-current nil d)) d)))
      (should (member "src/main/java/demo/New.java" files))
      (should-not (member "build/out.txt" files)))))

(ert-deftest jnav/a-partial-name-finds-the-file-by-fuzzy-matching ()
  ;; What you type after C-x p f: the minibuffer matches loosely (completion style `flex').
  (jn-with-project d
    (let* ((names (jn--rel (project-files (project-current nil d)) d))
           (hits (completion-all-completions "gmtry" names nil 5)))
      (should (member "src/main/java/demo/Geometry.java"
                      (mapcar (lambda (s) (substring-no-properties s)) (butlast hits 0)))))))

(ert-deftest jnav/text-search-in-the-project-finds-uses-across-files ()
  (jn-with-project d
    (let* ((pr (project-current nil d))
           (matches (xref-matches-in-files "area" (project-files pr))))
      (should (>= (length matches) 5))
      (should (member "Circle.java"
                      (mapcar (lambda (m) (file-name-nondirectory (xref-location-group (xref-item-location m)))) matches))))))

(defun jn--flatten-imenu (alist)
  (cl-loop for e in alist
           if (imenu--subalist-p e) append (jn--flatten-imenu (cdr e))
           else collect (car e)))

(defun jn--click-at (pos)
  "A synthetic right-click at POS in the selected window."
  (list 'mouse-3 (list (selected-window) pos '(0 . 0) 0)))

(ert-deftest jnav/the-outline-of-a-file-lists-its-methods ()
  (skip-unless (treesit-language-available-p 'java))
  (jn-with-project d
    (let ((b (find-file-noselect (concat d "src/main/java/demo/Geometry.java"))))
      (unwind-protect
          (with-current-buffer b
            (let ((names (jn--flatten-imenu (imenu--make-index-alist t))))
              (should (cl-some (lambda (n) (string-match-p "total" n)) names))
              (should (cl-some (lambda (n) (string-match-p "describe" n)) names))))
        (kill-buffer b)))))

;;; Text search across the project

(ert-deftest jnav/project-text-search-uses-ripgrep-when-it-is-installed ()
  (require 'xref)
  (should (eq xref-search-program (if (executable-find "rg") 'ripgrep 'grep))))

(ert-deftest jnav/ripgrep-and-grep-find-the-same-matches ()
  (skip-unless (executable-find "rg"))
  (jn-with-project d
    (let* ((default-directory d)
           (files (project-files (project-current nil d)))
           (count (lambda (prog) (let ((xref-search-program prog))
                                   (sort (mapcar (lambda (m) (format "%s:%d" (file-name-nondirectory (xref-location-group (xref-item-location m)))
                                                                     (xref-location-line (xref-item-location m))))
                                                 (xref-matches-in-files "area" files))
                                         #'string<)))))
      (should (funcall count 'ripgrep))
      (should (equal (funcall count 'ripgrep) (funcall count 'grep))))))

;;; Clicking

(ert-deftest jnav/ctrl-click-jumps-to-the-definition ()
  ;; Emacs 31 and newer: C-<mouse-1> runs xref-find-definitions-at-mouse in any buffer.
  (skip-unless (fboundp 'global-xref-mouse-mode))
  (should global-xref-mouse-mode)
  (test-in-buffer #'emacs-lisp-mode "(car x)"
    (should (eq (key-binding (kbd "C-<mouse-1>")) 'xref-find-definitions-at-mouse))
    (should (eq (key-binding (kbd "C-<down-mouse-1>")) 'ignore))))

(ert-deftest jnav/ctrl-click-works-in-java-buffers ()
  (skip-unless (fboundp 'global-xref-mouse-mode))
  (skip-unless (treesit-language-available-p 'java))
  (test-in-buffer #'java-ts-mode "class A {}"
    (should (eq (key-binding (kbd "C-<mouse-1>")) 'xref-find-definitions-at-mouse))))

(ert-deftest jnav/results-lines-follow-on-left-click-and-middle-click ()
  ;; In the *xref* list: mouse-1 or RET follows the reference; mouse-2 shows it in another window.
  (jn-with-project d
    (let ((matches (xref-matches-in-files "area" (project-files (project-current nil d)))))
      (xref--show-xrefs (lambda () matches) nil)
      (with-current-buffer "*xref*"
        (goto-char (point-min))
        (let ((m (text-property-search-forward 'mouse-face 'highlight t)))
          (should m)                                            ; some part of the line highlights on hover
          (goto-char (prop-match-beginning m))
          (should (string-match-p "mouse-1: follow reference" (get-text-property (point) 'help-echo)))
          (should (string-match-p "mouse-2: display in another window" (get-text-property (point) 'help-echo))))
        ;; the click bindings sit in a keymap attached to the result text itself
        (let ((km (get-text-property (point) 'keymap)))
          (should (keymapp km))
          (should (eq (lookup-key km [follow-link]) 'mouse-face))   ; a short left click follows
          (should (eq (lookup-key km [mouse-2]) 'xref-goto-xref)))
        (should (eq (lookup-key xref--xref-buffer-mode-map (kbd "RET")) 'xref-goto-xref))
        (should (eq (lookup-key xref--xref-buffer-mode-map "n") 'xref-next-line))
        (should (eq (lookup-key xref--xref-buffer-mode-map "p") 'xref-prev-line)))
      (kill-buffer "*xref*"))))

;;; The right-click menu (built by Emacs and by our config)

(ert-deftest jnav/right-click-menu-is-enabled-in-code-buffers ()
  (should context-menu-mode)
  (with-temp-buffer
    (emacs-lisp-mode)
    (should (memq 'prog-context-menu context-menu-functions)))     ; Find Definition / Find References
  (should (memq 'my/context-menu-eglot (default-value 'context-menu-functions))))

(ert-deftest jnav/right-click-menu-offers-definition-and-references-for-a-symbol ()
  (test-in-buffer #'emacs-lisp-mode "(defun area () 1) (area)"
    (let ((menu (make-sparse-keymap)))
      (prog-context-menu menu (jn--click-at 20))
      (should (lookup-key menu [xref-find-def]))
      (should (lookup-key menu [xref-find-ref])))))

(ert-deftest jnav/eglot-menu-items-only-appear-when-a-server-manages-the-buffer ()
  (test-in-buffer #'emacs-lisp-mode "(defun area () 1) (area)"
    (let ((click (jn--click-at 20)) (menu (make-sparse-keymap)))
      (my/context-menu-eglot menu click)
      (should-not (lookup-key menu [my-find-impl]))                   ; no server: nothing added
      (cl-letf (((symbol-function 'eglot-managed-p) (lambda () t)))
        (setq menu (make-sparse-keymap))
        (my/context-menu-eglot menu click)
        (should (lookup-key menu [my-find-impl]))
        (should (lookup-key menu [my-find-type]))))))

(ert-deftest jnav/the-menu-commands-call-the-right-eglot-commands ()
  (let (called)
    (cl-letf (((symbol-function 'eglot-find-implementation) (lambda () (interactive) (push "implementation" called)))
              ((symbol-function 'eglot-find-type-definition) (lambda () (interactive) (push "type" called))))
      (test-in-buffer #'emacs-lisp-mode "(defun area () 1) (area)"
        (let ((event (jn--click-at 20)))
          (my/eglot-find-implementation-at-mouse event)
          (my/eglot-find-type-definition-at-mouse event))))
    (should (equal (sort called #'string<) '("implementation" "type")))))

(ert-deftest jnav/the-source-path-default-is-set-for-servers-without-a-build-file ()
  (should (equal (plist-get (plist-get (default-value 'eglot-workspace-configuration) :java) :project)
                 '(:sourcePaths ["src/main/java" "src"]))))

;;; With a real Java language server (opt-in: tests/run-all.sh --lsp)

(defun jn--skip-unless-lsp ()
  (unless (getenv "RUN_LSP_TESTS") (ert-skip "set RUN_LSP_TESTS=1 (run-all.sh --lsp) to start jdtls"))
  (unless (executable-find "jdtls") (ert-skip "jdtls is not installed"))
  (unless (treesit-language-available-p 'java) (ert-skip "Java grammar not installed")))

(defvar jn--proj nil "Root of the project currently under test.")

(defun jn--goto (file text &optional after)
  (find-file (concat jn--proj file))
  (goto-char (point-min)) (search-forward text) (goto-char (match-beginning 0))
  (when after (search-forward after) (backward-char 1)))

(defun jn--wait (fn)
  "Call FN until it returns non-nil, up to 90 seconds."
  (let ((end (+ (float-time) 90)) r)
    (while (and (not r) (< (float-time) end))
      (setq r (ignore-errors (funcall fn)))
      (unless r (sleep-for 1)))
    r))

(defun jn--where (xrefs)
  (sort (mapcar (lambda (x) (let ((l (xref-item-location x)))
                              (format "%s:%d" (file-name-nondirectory (xref-location-group l)) (xref-location-line l))))
                xrefs)
        #'string<))

(defun jn--ask (method &optional extra)
  (jn--wait (lambda ()
              (let ((r (jsonrpc-request (eglot-current-server) method
                                        (append (eglot--TextDocumentPositionParams) extra) :timeout 30)))
                (and r (> (length r) 0)
                     (sort (mapcar (lambda (l) (format "%s:%d" (file-name-nondirectory (plist-get l :uri))
                                                       (1+ (plist-get (plist-get (plist-get l :range) :start) :line))))
                                   (append r nil))
                           #'string<))))))

(defvar jn--shared nil
  "One project and one running jdtls, shared by all the lsp-java tests (starting the server
for every test would take about a minute in total).  Cleaned up when Emacs exits.")

(defun jn--ensure-shared-server ()
  "Return the shared project directory, creating the project and starting jdtls the first time."
  (unless (and jn--shared (eglot-current-server))
    (let ((dir (file-name-as-directory (make-temp-file "emacs-test-jdtls-" t))))
      (dolist (f jn--files)
        (make-directory (file-name-directory (concat dir (car f))) t)
        (test-write-file (concat dir (car f)) (cadr f)))
      (test-git dir "init" "-q") (test-git dir "add" "-A") (test-git dir "commit" "-q" "-m" "demo")
      (setq jn--shared dir)
      (add-hook 'kill-emacs-hook
                (lambda ()
                  (ignore-errors (eglot-shutdown-all))
                  (ignore-errors (delete-directory dir t))))
      (let ((eglot-sync-connect t) (eglot-connect-timeout 240))
        (find-file (concat dir "src/main/java/demo/Main.java"))
        (call-interactively #'eglot))))
  jn--shared)

(defmacro jn-with-server (dir &rest body)
  "Bind DIR to the shared demo project (with jdtls running) around BODY."
  (declare (indent 1))
  `(let* ((,dir (jn--ensure-shared-server)) (jn--proj ,dir))
     (find-file (concat ,dir "src/main/java/demo/Main.java"))   ; a buffer the server manages
     ,@body))

(ert-deftest lsp-java/the-server-accepts-the-source-layout-without-errors ()
  (jn--skip-unless-lsp)
  (jn-with-server d
    (sleep-for 10)
    (should-not (cl-some (lambda (dg) (string-match-p "does not match the expected package" (flymake-diagnostic-text dg)))
                         (flymake-diagnostics)))))

(ert-deftest lsp-java/click-a-static-method-and-find-its-definition ()
  (jn--skip-unless-lsp)
  (jn-with-server d
    (jn--goto "src/main/java/demo/Main.java" "total(shapes)")
    (let ((id (xref-backend-identifier-at-point 'eglot)))
      (should (equal (jn--wait (lambda () (jn--where (xref-backend-definitions 'eglot id)))) '("Geometry.java:7"))))))

(ert-deftest lsp-java/a-call-through-an-interface-finds-the-interface-method ()
  (jn--skip-unless-lsp)
  (jn-with-server d
    (jn--goto "src/main/java/demo/Geometry.java" "s.area()" "area")
    (let ((id (xref-backend-identifier-at-point 'eglot)))
      (should (equal (jn--wait (lambda () (jn--where (xref-backend-definitions 'eglot id)))) '("Shape.java:5"))))))

(ert-deftest lsp-java/implementations-of-an-interface-method ()
  (jn--skip-unless-lsp)
  (jn-with-server d
    (jn--goto "src/main/java/demo/Shape.java" "double area" "area")
    (should (equal (jn--ask :textDocument/implementation) '("Circle.java:11" "Rect.java:13")))))

(ert-deftest lsp-java/implementations-of-an-interface ()
  (jn--skip-unless-lsp)
  (jn-with-server d
    (jn--goto "src/main/java/demo/Shape.java" "interface Shape" "Shape")
    (should (equal (jn--ask :textDocument/implementation) '("Circle.java:3" "Rect.java:3")))))

(ert-deftest lsp-java/references-to-a-method-in-every-file ()
  (jn--skip-unless-lsp)
  (jn-with-server d
    (jn--goto "src/main/java/demo/Shape.java" "double area" "area")
    (should (equal (jn--ask :textDocument/references '(:context (:includeDeclaration t)))
                   '("Circle.java:11" "Geometry.java:10" "Geometry.java:16" "Rect.java:13" "Shape.java:5")))))

(ert-deftest lsp-java/references-to-a-class-or-interface ()
  (jn--skip-unless-lsp)
  (jn-with-server d
    (jn--goto "src/main/java/demo/Shape.java" "interface Shape" "Shape")
    (let ((refs (jn--ask :textDocument/references '(:context (:includeDeclaration t)))))
      (should (member "Main.java:7" refs))
      (should (member "Geometry.java:7" refs))
      (should (member "Circle.java:3" refs))
      (should (member "Rect.java:3" refs))
      (should (>= (length refs) 8)))))

(ert-deftest lsp-java/references-include-the-call-in-another-file ()
  (jn--skip-unless-lsp)
  (jn-with-server d
    (jn--goto "src/main/java/demo/Geometry.java" "static double total" "total")
    (should (equal (jn--ask :textDocument/references '(:context (:includeDeclaration t)))
                   '("Geometry.java:7" "Main.java:8")))))

(ert-deftest lsp-java/type-definition ()
  (jn--skip-unless-lsp)
  (jn-with-server d
    (jn--goto "src/main/java/demo/Geometry.java" "Shape s" "Shape")
    (should (equal (jn--ask :textDocument/typeDefinition) '("Shape.java:4")))))

(ert-deftest lsp-java/the-real-commands-jump-to-the-definition ()
  ;; M-. through the real Emacs command, not just the protocol.
  (jn--skip-unless-lsp)
  (jn-with-server d
    (jn--goto "src/main/java/demo/Main.java" "total(shapes)")
    (jn--wait (lambda () (xref-backend-definitions 'eglot (xref-backend-identifier-at-point 'eglot))))
    (let ((xref-show-definitions-function #'xref-show-definitions-buffer-at-bottom))
      (xref-find-definitions (xref-backend-identifier-at-point 'eglot)))
    (should (equal (file-name-nondirectory (buffer-file-name)) "Geometry.java"))
    (should (= 7 (line-number-at-pos)))))

(ert-deftest lsp-java/find-a-class-by-name-anywhere-in-the-project ()
  (jn--skip-unless-lsp)
  (jn-with-server d
    (let ((found (jn--wait (lambda () (mapcar (lambda (x) (xref-item-summary x)) (xref-backend-apropos 'eglot "Circle"))))))
      (should (cl-some (lambda (s) (string-match-p "Circle" s)) found)))))

;;; java-navigation.el ends here
