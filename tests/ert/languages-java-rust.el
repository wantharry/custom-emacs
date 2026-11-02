;;; languages-java-rust.el --- Java and Rust support  -*- lexical-binding: t; -*-
;; harness: config
;; Grammar-dependent tests skip themselves if the grammar is not installed
;; (./build.sh grammars).  Tests that start a real language server run only with
;; RUN_LSP_TESTS=1 (tests/run-all.sh --lsp).

(require 'treesit) (require 'eglot) (require 'jsonrpc) (require 'imenu)

(defmacro jr-with-grammar (lang &rest body)
  (declare (indent 1))
  `(progn (skip-unless (treesit-language-available-p ,lang)) ,@body))

(defun jr--flatten-imenu (alist)
  "All entry names in an imenu index, however deeply nested."
  (cl-loop for e in alist
           if (imenu--subalist-p e) append (jr--flatten-imenu (cdr e))
           else collect (car e)))

(defun jr--open-mode (name text)
  (test-with-temp-dir d
    (let ((buf (find-file-noselect (test-write-file (concat d name) text))))
      (unwind-protect (buffer-local-value 'major-mode buf) (kill-buffer buf)))))

(defconst jr--java "class Shapes {\n  interface Shape { double area(); }\n  static double total(double a, double b) {\n    return a + b;\n  }\n  public static void main(String[] args) {\n    int n = 3;\n  }\n}\n")
(defconst jr--rust "struct Point { x: i32 }\n\nfn first() -> i32 { 1 }\n\nfn second(p: &Point) -> i32 {\n    p.x\n}\n")

;;; Grammars and modes

(ert-deftest langs/grammars-installed-and-loadable ()
  ;; A hard requirement, not a skip: other tests skip without a grammar, so this
  ;; is what stops a missing grammar from hiding behind green results.
  (dolist (l '(java rust))
    (unless (treesit-language-available-p l)
      (ert-fail (format "tree-sitter grammar for %s is not installed; run ./build.sh grammars" l)))
    (should (<= (treesit-language-abi-version l) (treesit-library-abi-version)))))

(ert-deftest langs/grammar-sources-are-pinned ()
  (dolist (l '(java rust))
    (let ((src (assq l treesit-language-source-alist)))
      (should src)
      (should (string-match-p "\\`v[0-9]+\\.[0-9]+\\.[0-9]+\\'" (nth 2 src))))))

(ert-deftest langs/java-files-open-in-the-tree-sitter-mode ()
  (jr-with-grammar 'java
    (should (eq 'java-ts-mode (jr--open-mode "A.java" jr--java)))))

(ert-deftest langs/rust-files-open-in-the-tree-sitter-mode ()
  (jr-with-grammar 'rust
    (should (eq 'rust-ts-mode (jr--open-mode "a.rs" jr--rust)))))

(ert-deftest langs/classic-java-mode-remains-when-no-grammar ()
  ;; init.el only remaps java-mode when the grammar exists.
  (should (eq (and (assq 'java-mode major-mode-remap-alist) t)
              (and (treesit-language-available-p 'java) t))))

;;; Parsing, highlighting, editing

(ert-deftest langs/java-parses-to-a-program-tree ()
  (jr-with-grammar 'java
    (test-in-buffer #'java-ts-mode jr--java
      (should (equal "program" (treesit-node-type (treesit-buffer-root-node 'java))))
      (should (treesit-search-subtree (treesit-buffer-root-node 'java) "class_declaration")))))

(ert-deftest langs/rust-parses-to-a-source-file-tree ()
  (jr-with-grammar 'rust
    (test-in-buffer #'rust-ts-mode jr--rust
      (should (equal "source_file" (treesit-node-type (treesit-buffer-root-node 'rust))))
      (should (treesit-search-subtree (treesit-buffer-root-node 'rust) "function_item")))))

(ert-deftest langs/java-highlighting ()
  (jr-with-grammar 'java
    (test-in-buffer #'java-ts-mode jr--java
      (font-lock-ensure)
      (should (memq 'font-lock-keyword-face (ensure-list (get-text-property 1 'face))))
      (search-forward "double")
      (should (memq 'font-lock-type-face (ensure-list (get-text-property (- (point) 3) 'face)))))))

(ert-deftest langs/rust-highlighting ()
  (jr-with-grammar 'rust
    (test-in-buffer #'rust-ts-mode jr--rust
      (font-lock-ensure)
      (should (memq 'font-lock-keyword-face (ensure-list (get-text-property 1 'face))))
      (search-forward "fn first")
      (should (memq 'font-lock-function-name-face (ensure-list (get-text-property (- (point) 2) 'face)))))))

(ert-deftest langs/java-indentation ()
  (jr-with-grammar 'java
    (test-in-buffer #'java-ts-mode "class A {\nvoid f() {\nint x;\n}\n}\n"
      (indent-region (point-min) (point-max))
      (should (equal (buffer-string) "class A {\n    void f() {\n        int x;\n    }\n}\n")))))

(ert-deftest langs/rust-indentation ()
  (jr-with-grammar 'rust
    (test-in-buffer #'rust-ts-mode "fn main() {\nlet x = 1;\nif x > 0 {\nprintln!(\"a\");\n}\n}\n"
      (indent-region (point-min) (point-max))
      (should (equal (buffer-string) "fn main() {\n    let x = 1;\n    if x > 0 {\n        println!(\"a\");\n    }\n}\n")))))

(ert-deftest langs/java-comments ()
  (jr-with-grammar 'java
    (test-in-buffer #'java-ts-mode "int x;\n"
      (comment-region (point-min) (point-max))
      (should (string-prefix-p "//" (buffer-string))))))

(ert-deftest langs/rust-comments ()
  (jr-with-grammar 'rust
    (test-in-buffer #'rust-ts-mode "let x = 1;\n"
      (comment-region (point-min) (point-max))
      (should (string-prefix-p "//" (buffer-string))))))

(ert-deftest langs/java-imenu-lists-classes-and-methods ()
  (jr-with-grammar 'java
    (test-in-buffer #'java-ts-mode jr--java
      (let ((names (jr--flatten-imenu (imenu--make-index-alist t))))
        (should (cl-some (lambda (n) (string-match-p "Shapes" n)) names))
        (should (cl-some (lambda (n) (string-match-p "total" n)) names))
        (should (cl-some (lambda (n) (string-match-p "main" n)) names))))))

(ert-deftest langs/rust-imenu-lists-functions-and-types ()
  (jr-with-grammar 'rust
    (test-in-buffer #'rust-ts-mode jr--rust
      (let ((names (jr--flatten-imenu (imenu--make-index-alist t))))
        (should (cl-some (lambda (n) (string-match-p "first" n)) names))
        (should (cl-some (lambda (n) (string-match-p "second" n)) names))
        (should (cl-some (lambda (n) (string-match-p "Point" n)) names))))))

(ert-deftest langs/rust-knows-the-function-around-point ()
  (jr-with-grammar 'rust
    (test-in-buffer #'rust-ts-mode jr--rust
      (search-forward "p.x")
      (should (equal "second" (treesit-defun-name (treesit-defun-at-point))))
      (beginning-of-defun)
      (should (looking-at "fn second")))))

(ert-deftest langs/java-knows-the-method-around-point ()
  (jr-with-grammar 'java
    (test-in-buffer #'java-ts-mode jr--java
      (search-forward "int n")
      (should (equal "main" (treesit-defun-name (treesit-defun-at-point)))))))

;;; Language servers: configured, not auto-started

(ert-deftest langs/rust-server-is-rust-analyzer ()
  ;; This isn't our own entry (unlike the bundled Java one below) --- it's whatever
  ;; Eglot's own built-in default for Rust happens to be, so the key is read defensively
  ;; rather than assuming today's exact shape: an `eglot-server-programs' key can be a
  ;; bare mode symbol, a list of mode symbols, or a list mixing those with (MODE . ID)
  ;; conses, depending on the entry; normalizing all three before the `memq' is what
  ;; keeps this from breaking the moment a future Eglot release reshapes its own default.
  (let ((entry (cl-find-if (lambda (e) (let ((k (car e))) (memq 'rust-ts-mode (mapcar (lambda (x) (if (consp x) (car x) x)) (if (listp k) k (list k))))))
                           eglot-server-programs)))
    (should entry)
    (should (equal (cdr entry) '("rust-analyzer")))))

(ert-deftest langs/java-server-is-jdtls ()
  (skip-unless (executable-find "jdtls"))
  (test-with-temp-dir d
    (let ((buf (find-file-noselect (test-write-file (concat d "A.java") jr--java))))
      (unwind-protect
          (with-current-buffer buf
            (should (string-match-p "jdtls" (car (nth 3 (eglot--guess-contact))))))
        (kill-buffer buf)))))

(ert-deftest langs/opening-files-does-not-start-servers ()
  (jr-with-grammar 'rust
    (test-in-buffer #'rust-ts-mode jr--rust
      (should-not (and (fboundp 'eglot-current-server) (eglot-current-server)))
      (should-not (cl-some (lambda (p) (string-match-p "EGLOT" (process-name p))) (process-list))))))

(ert-deftest langs/eglot-protocol-logging-is-off ()
  (should (equal eglot-events-buffer-config '(:size 0))))

;;; The toolchains themselves

(ert-deftest langs/java-toolchain-works ()
  (skip-unless (executable-find "javac"))
  (test-with-temp-dir d
    (test-write-file (concat d "T.java") "public class T { public static void main(String[] a) { System.out.print(6*7); } }")
    (should (= 0 (call-process "javac" nil nil nil "-d" d (concat d "T.java"))))
    (should (equal "42" (car (process-lines "java" "-cp" d "T"))))))

(ert-deftest langs/rust-toolchain-works ()
  (skip-unless (executable-find "rustc"))
  (test-with-temp-dir d
    (test-write-file (concat d "t.rs") "fn main() { print!(\"{}\", 6*7); }")
    (should (= 0 (call-process "rustc" nil nil nil "-o" (concat d "t") (concat d "t.rs"))))
    (should (equal "42" (car (process-lines (concat d "t")))))))

(ert-deftest langs/rust-analyzer-component-is-installed ()
  ;; rustup ships a stub `rust-analyzer' that fails until the component is added.
  (skip-unless (executable-find "rust-analyzer"))
  (should (string-match-p "\\`rust-analyzer " (car (process-lines "rust-analyzer" "--version")))))

(ert-deftest langs/jdtls-launcher-runs ()
  (skip-unless (executable-find "jdtls"))
  (should (= 0 (call-process "jdtls" nil nil nil "--help"))))

;;; Real language-server sessions (opt-in: tests/run-all.sh --lsp)

(defun jr--skip-unless-lsp ()
  (unless (getenv "RUN_LSP_TESTS") (ert-skip "set RUN_LSP_TESTS=1 (run-all.sh --lsp) to start real servers")))

(defun jr--symbols (server)
  "Document symbols for the current buffer, retried until the server has them."
  (let ((deadline (+ (float-time) 120)) syms)
    (while (and (not syms) (< (float-time) deadline))
      (setq syms (ignore-errors
                   (jsonrpc-request server :textDocument/documentSymbol
                                    (list :textDocument (eglot--TextDocumentIdentifier)) :timeout 30)))
      (unless syms (sleep-for 0.5)))
    syms))

(ert-deftest lsp/rust-analyzer-answers-through-eglot ()
  (jr--skip-unless-lsp)
  (skip-unless (executable-find "rust-analyzer"))
  (jr-with-grammar 'rust
    (test-with-temp-dir d
      (make-directory (concat d "src"))
      (test-write-file (concat d "Cargo.toml") "[package]\nname = \"t\"\nversion = \"0.1.0\"\nedition = \"2021\"\n")
      (test-write-file (concat d "src/main.rs") jr--rust)
      (let ((buf (find-file-noselect (concat d "src/main.rs"))) (eglot-sync-connect t) (eglot-connect-timeout 120))
        (unwind-protect
            (with-current-buffer buf
              (call-interactively #'eglot)
              (let ((server (eglot-current-server)))
                (should server)
                (should (cl-some (lambda (s) (equal "first" (plist-get s :name))) (jr--symbols server)))
                (eglot-shutdown server)))
          (kill-buffer buf))))))

(ert-deftest lsp/jdtls-answers-through-eglot ()
  (jr--skip-unless-lsp)
  (skip-unless (executable-find "jdtls"))
  (jr-with-grammar 'java
    (test-with-temp-dir d
      (test-write-file (concat d "Shapes.java") jr--java)
      (let ((buf (find-file-noselect (concat d "Shapes.java"))) (eglot-sync-connect t) (eglot-connect-timeout 180))
        (unwind-protect
            (with-current-buffer buf
              (call-interactively #'eglot)
              (let ((server (eglot-current-server)))
                (should server)
                (should (jr--symbols server))
                (eglot-shutdown server)))
          (kill-buffer buf))))))

;;; The Windows bundle starts its own Java language server

(ert-deftest langs/bundled-jdtls-command-is-built-from-the-bundle-folder ()
  ;; No JDK is bundled (see init.el): this uses whatever `java' it finds on PATH, here a
  ;; fake one, standing in for a real JDK the user installed themselves.
  (test-with-temp-dir home
    (make-directory (concat home "tools/jdtls/plugins") t)
    (make-directory (concat home "tools/jdtls/config_win") t)
    (make-directory (concat home "bin") t)
    (test-write-file (concat home "tools/jdtls/plugins/org.eclipse.equinox.launcher_1.7.0.jar") "")
    (test-write-file (concat home "bin/java") "")
    (set-file-modes (concat home "bin/java") #o755)
    (let ((process-environment (cons (concat "CUSTOM_EMACS_HOME=" (directory-file-name home)) process-environment))
          (exec-path (list (concat home "bin"))))
      (let ((cmd (my/bundled-jdtls-command)))
        (should (string-suffix-p "bin/java" (car cmd)))
        (should (member "-Declipse.application=org.eclipse.jdt.ls.core.id1" cmd))
        (should (cl-some (lambda (a) (string-match-p "org.eclipse.equinox.launcher_1.7.0.jar\\'" a)) cmd))
        (should (string-suffix-p "config_win" (cadr (member "-configuration" cmd))))
        ;; the workspace is under the settings folder, one per project
        (should (string-match-p "jdtls-workspaces/[0-9a-f]\\{32\\}\\'" (cadr (member "-data" cmd))))))))

(ert-deftest langs/bundled-jdtls-command-errors-clearly-with-no-java-found ()
  (test-with-temp-dir home
    (make-directory (concat home "tools/jdtls/plugins") t)
    (test-write-file (concat home "tools/jdtls/plugins/org.eclipse.equinox.launcher_1.jar") "")
    (let ((process-environment (cons (concat "CUSTOM_EMACS_HOME=" (directory-file-name home)) process-environment))
          (exec-path nil))          ; no Java anywhere on the path
      (should-error (my/bundled-jdtls-command) :type 'user-error))))

(ert-deftest langs/bundled-jdtls-workspace-differs-per-project ()
  (test-with-temp-dir home
    (make-directory (concat home "tools/jdtls/plugins") t)
    (test-write-file (concat home "tools/jdtls/plugins/org.eclipse.equinox.launcher_1.jar") "")
    (let ((process-environment (cons (concat "CUSTOM_EMACS_HOME=" (directory-file-name home)) process-environment))
          (exec-path (list (concat home "bin"))))
      (make-directory (concat home "bin") t) (test-write-file (concat home "bin/java") "")
      (set-file-modes (concat home "bin/java") #o755)
      (let ((a (let ((default-directory (concat home "a/"))) (make-directory default-directory t) (cadr (member "-data" (my/bundled-jdtls-command)))))
            (b (let ((default-directory (concat home "b/"))) (make-directory default-directory t) (cadr (member "-data" (my/bundled-jdtls-command))))))
        (should-not (equal a b))))))

(ert-deftest langs/the-bundled-server-is-registered-only-on-windows-with-a-bundle ()
  ;; Anywhere else (Linux, or Windows without the launcher) Eglot's own entry for Java is left alone.
  (require 'eglot)
  (if (and (eq system-type 'windows-nt) (my/bundled-jdtls-dir) (file-directory-p (my/bundled-jdtls-dir)))
      (should (rassq 'my/bundled-jdtls-command eglot-server-programs))
    (should-not (rassq 'my/bundled-jdtls-command eglot-server-programs))))

;;; C-c J: compile and run the current .java file --- ported from this project's
;;; separate `java' branch on request (its own `C-c J'/`my/run-java-file')

(ert-deftest langs/run-java-key-is-bound ()
  (should (eq (key-binding (kbd "C-c J")) #'my/run-java-file)))

(ert-deftest langs/run-java-file-errors-clearly-on-a-non-java-buffer ()
  (test-with-temp-dir d
    (let ((buffer-file-name (concat d "a.py")))
      (should-error (my/run-java-file) :type 'user-error))))

(ert-deftest langs/run-java-file-really-compiles-and-runs-a-real-java-file ()
  ;; A real, confirmed round trip: `javac'/`java' actually run (on WSL, the real system
  ;; JDK, since no bundled one exists here --- confirmed `my/bundled-jdk-java' falls back
  ;; correctly), and the real stdout is read back, not mocked.
  (skip-unless (or (my/bundled-jdk-bin "javac.exe") (executable-find "javac")))
  (test-with-temp-dir d
    (test-write-file (concat d "Hello.java")
                      "public class Hello {\n    public static void main(String[] args) {\n        System.out.println(\"Hello from Java!\");\n    }\n}\n")
    (let ((buffer-file-name (concat d "Hello.java")) (default-directory d))
      (my/run-java-file)
      (with-timeout (20 (error "javac/java did not finish in time"))
        (while (get-buffer-process "*compilation*") (sit-for 0.2)))
      (should (string-match-p "Hello from Java!" (with-current-buffer "*compilation*" (buffer-string))))
      (kill-buffer "*compilation*"))))

(ert-deftest langs/run-java-file-really-compiles-and-runs-a-real-file-with-a-package ()
  ;; A real, user-hit bug, not assumed: a bare `javac file.java && java Class', run
  ;; from the file's own directory, only works for the default package --- any real
  ;; `package com.foo.bar;' file (confirmed live on the user's own machine, running
  ;; `C-c J' against a real `coding-languages/java' file) fails with a real
  ;; `NoClassDefFoundError: Class (wrong name: com/foo/bar/Class)'. This test puts the
  ;; file on disk at the real matching package directory structure (`com/example/pkg/
  ;; Hello.java', not just a bare file in an empty temp dir) and confirms the actual
  ;; fully-qualified run succeeds.
  (skip-unless (or (my/bundled-jdk-bin "javac.exe") (executable-find "javac")))
  (test-with-temp-dir d
    (let ((pkg-dir (concat d "com/example/pkg/")))
      (make-directory pkg-dir t)
      (test-write-file (concat pkg-dir "Hello.java")
                        "package com.example.pkg;\n\npublic class Hello {\n    public static void main(String[] args) {\n        System.out.println(\"Hello from a real package!\");\n    }\n}\n")
      (let ((buffer-file-name (concat pkg-dir "Hello.java")) (default-directory pkg-dir))
        (my/run-java-file)
        (with-timeout (20 (error "javac/java did not finish in time"))
          (while (get-buffer-process "*compilation*") (sit-for 0.2)))
        (should (string-match-p "Hello from a real package!" (with-current-buffer "*compilation*" (buffer-string))))
        (kill-buffer "*compilation*")))))

(ert-deftest langs/java-file-package-detects-a-real-package-declaration ()
  (test-with-temp-dir d
    (test-write-file (concat d "Plain.java") "public class Plain {}\n")
    (should-not (my/java-file-package (concat d "Plain.java")))
    (test-write-file (concat d "Pkg.java") "package com.example.pkg;\n\npublic class Pkg {}\n")
    (should (equal (my/java-file-package (concat d "Pkg.java")) "com.example.pkg"))))

;;; C-c i j: Maven goals --- also ported from the `java' branch, under the `C-c i'
;;; prefix rather than its own original bare `C-c j' at the user's own request:
;;; `C-c j' is already `projectile-keymap-prefix' on THIS branch (the `java' branch
;;; never installed projectile), confirmed free live via `key-binding' before using it.

(ert-deftest langs/maven-keys-are-bound ()
  (should (eq (key-binding (kbd "C-c i j c")) #'my/maven-compile))
  (should (eq (key-binding (kbd "C-c i j t")) #'my/maven-test))
  (should (eq (key-binding (kbd "C-c i j p")) #'my/maven-package))
  (should (eq (key-binding (kbd "C-c i j i")) #'my/maven-install))
  (should (eq (key-binding (kbd "C-c i j C")) #'my/maven-clean))
  (should (eq (key-binding (kbd "C-c i j g")) #'my/maven-goals))
  ;; `C-c j' itself must still be projectile's own prefix, unclobbered
  (should (eq (key-binding (kbd "C-c j")) 'projectile-command-map)))

(ert-deftest langs/maven-root-finds-the-nearest-real-pom-xml ()
  (test-with-temp-dir d
    (test-write-file (concat d "pom.xml") "<project></project>")
    (make-directory (concat d "src/main/java/com/example") t)
    (let ((buffer-file-name (concat d "src/main/java/com/example/App.java"))
          (default-directory (concat d "src/main/java/com/example/")))
      (should (equal (expand-file-name (my/maven-root)) (expand-file-name d))))))

(ert-deftest langs/maven-run-errors-clearly-with-no-pom-xml ()
  (test-with-temp-dir d
    (let ((buffer-file-name (concat d "a.java")) (default-directory d))
      (should-error (my/maven-run "compile") :type 'user-error))))

(ert-deftest langs/maven-command-prefers-a-bundled-mvn-over-path ()
  ;; Same "bundled path first, PATH second" pattern already confirmed for
  ;; `my/bundled-jdtls-command' above --- only exercised when `CUSTOM_EMACS_HOME'
  ;; points at a real bundle, which WSL/Linux never sets, so this is a real,
  ;; confirmed round trip on Windows and a correctly-skipped no-op everywhere else.
  (if (and (eq system-type 'windows-nt) (getenv "CUSTOM_EMACS_HOME"))
      (let ((mvn (expand-file-name "tools/maven/bin/mvn.cmd" (getenv "CUSTOM_EMACS_HOME"))))
        (skip-unless (file-exists-p mvn))
        (should (equal (my/maven-command) mvn)))
    (should (equal (my/maven-command) (or (executable-find "mvn") "mvn")))))

;;; languages-java-rust.el ends here
