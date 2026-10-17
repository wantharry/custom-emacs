;;; maven.el --- C-c j: Maven on a real multi-file project  -*- lexical-binding: t; -*-
;; harness: config
;; `C-c J' (my/run-java-file) only ever handles the one file in the current buffer, no
;; classpath; these cover the follow-up, `my/maven-run' and the `C-c j' keys, which find
;; the nearest pom.xml and run real Maven goals there.

(ert-deftest maven/keys-are-bound ()
  (should (eq (key-binding (kbd "C-c j c")) #'my/maven-compile))
  (should (eq (key-binding (kbd "C-c j t")) #'my/maven-test))
  (should (eq (key-binding (kbd "C-c j p")) #'my/maven-package))
  (should (eq (key-binding (kbd "C-c j i")) #'my/maven-install))
  (should (eq (key-binding (kbd "C-c j C")) #'my/maven-clean))
  (should (eq (key-binding (kbd "C-c j g")) #'my/maven-goals)))

(ert-deftest maven/bundled-maven-bin-is-nil-without-a-bundle ()
  ;; No `CUSTOM_EMACS_HOME' (the from-source Linux build this test actually runs under)
  ;; means there is no bundle to look in at all.
  (let ((process-environment (cons "CUSTOM_EMACS_HOME" process-environment)))
    (setenv "CUSTOM_EMACS_HOME" nil)
    (should (null (my/bundled-maven-bin)))))

(ert-deftest maven/bundled-maven-bin-is-nil-when-the-file-is-missing ()
  ;; A `CUSTOM_EMACS_HOME' that is set but does not actually contain tools/maven/bin/mvn.cmd
  ;; (true on every platform except a real Windows `java' branch bundle) must not claim one
  ;; exists --- `file-exists-p' is the real check, not just "the env var is set".
  (test-with-temp-dir home
    (let ((process-environment (cons "CUSTOM_EMACS_HOME" process-environment)))
      (setenv "CUSTOM_EMACS_HOME" (directory-file-name home))
      (should (null (my/bundled-maven-bin))))))

(ert-deftest maven/bundled-maven-bin-finds-a-real-mvn-cmd ()
  (test-with-temp-dir home
    (let* ((mvn (expand-file-name "tools/maven/bin/mvn.cmd" home))
           (process-environment (cons "CUSTOM_EMACS_HOME" process-environment)))
      (make-directory (file-name-directory mvn) t)
      (test-write-file mvn "@echo off\r\n")
      (setenv "CUSTOM_EMACS_HOME" (directory-file-name home))
      (should (equal (my/bundled-maven-bin) mvn)))))

(ert-deftest maven/command-falls-back-to-path-without-a-bundle ()
  (let ((process-environment (cons "CUSTOM_EMACS_HOME" process-environment)))
    (setenv "CUSTOM_EMACS_HOME" nil)
    (cl-letf (((symbol-function 'executable-find)
               (lambda (name) (and (equal name "mvn") "/usr/bin/mvn"))))
      (should (equal (my/maven-command) "/usr/bin/mvn")))))

(ert-deftest maven/command-prefers-the-bundle-over-path ()
  (test-with-temp-dir home
    (let* ((mvn (expand-file-name "tools/maven/bin/mvn.cmd" home))
           (process-environment (cons "CUSTOM_EMACS_HOME" process-environment)))
      (make-directory (file-name-directory mvn) t)
      (test-write-file mvn "@echo off\r\n")
      (setenv "CUSTOM_EMACS_HOME" (directory-file-name home))
      (cl-letf (((symbol-function 'executable-find) (lambda (_) "/usr/bin/mvn")))
        (should (equal (my/maven-command) mvn))))))

(ert-deftest maven/root-finds-the-nearest-pom-above-the-file ()
  (test-with-temp-dir proj
    (test-write-file (expand-file-name "pom.xml" proj) "<project/>")
    (make-directory (expand-file-name "src/main/java" proj) t)
    (let* ((file (expand-file-name "src/main/java/Foo.java" proj)))
      (test-write-file file "class Foo {}")
      (with-current-buffer (find-file-noselect file)
        (unwind-protect
            (should (equal (file-truename (my/maven-root)) (file-truename proj)))
          (kill-buffer))))))

(ert-deftest maven/run-errors-clearly-with-no-pom-xml-anywhere ()
  (test-with-temp-dir dir
    (let ((default-directory dir))
      (cl-letf (((symbol-function 'project-current) (lambda (&rest _) nil)))
        (should-error (my/maven-run "compile") :type 'user-error)))))

(ert-deftest maven/run-builds-the-right-command-and-runs-it-at-the-pom-root ()
  ;; Does not actually invoke a real `mvn' --- mocks `compile' itself (the same shape
  ;; `my/run-java-file' would need, if it had a test) to capture exactly what command
  ;; and directory `my/maven-run' decided on, which is the part this project owns.
  (test-with-temp-dir proj
    (test-write-file (expand-file-name "pom.xml" proj) "<project/>")
    (let (seen-command seen-dir seen-comint
          (process-environment (cons "CUSTOM_EMACS_HOME" process-environment)))
      (setenv "CUSTOM_EMACS_HOME" nil)
      (cl-letf (((symbol-function 'executable-find) (lambda (name) (and (equal name "mvn") "mvn")))
                ((symbol-function 'compile)
                 (lambda (command &optional comint)
                   (setq seen-command command seen-dir default-directory seen-comint comint))))
        (let ((default-directory proj))
          (my/maven-run "test -DskipTests"))
        (should (equal seen-command "mvn test -DskipTests"))
        (should (equal (file-truename seen-dir) (file-truename proj)))
        ;; Comint mode, not plain `compilation-mode' --- same reason as `my/run-java-file':
        ;; a goal or the program it runs may read stdin.
        (should seen-comint)))))

(ert-deftest maven/goals-prompts-and-runs-whatever-was-typed ()
  (test-with-temp-dir proj
    (test-write-file (expand-file-name "pom.xml" proj) "<project/>")
    (let (seen-command (default-directory proj)
          (process-environment (cons "CUSTOM_EMACS_HOME" process-environment)))
      (setenv "CUSTOM_EMACS_HOME" nil)
      (cl-letf (((symbol-function 'executable-find) (lambda (name) (and (equal name "mvn") "mvn")))
                ((symbol-function 'compile) (lambda (command &optional _) (setq seen-command command))))
        (my/maven-goals "clean install -DskipTests"))
      (should (equal seen-command "mvn clean install -DskipTests")))))
