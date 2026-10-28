;;; languages-web-lsp.el --- real LSP for JS/TS/HTML/CSS/Angular (dev-ui branch)  -*- lexical-binding: t; -*-
;; harness: config
;; `dev-ui'-only: tests/ert/languages-web.el already covers the tree-sitter EDITING
;; side (highlighting/indent/imenu) shared with every other branch; this file covers
;; the real language-server wiring that is only on this branch (see config/init.el's
;; own long comment on why: the servers are npm packages, installed locally into
;; tools/node-lsp/, not bundled).  Tests that need the real binaries skip themselves
;; if tools/node-lsp/ was never `npm install'ed; tests that start a real server run
;; only with RUN_LSP_TESTS=1 (tests/run-all.sh --lsp), same convention as
;; languages-java-rust.el.

(require 'eglot) (require 'jsonrpc)

(defun wl--bin (name)
  (expand-file-name name my/web-lsp-bin-dir))

(defmacro wl--skip-unless-installed ()
  '(skip-unless (file-directory-p my/web-lsp-bin-dir)))

;;; Wiring: the servers are findable and Eglot knows to start them

(ert-deftest wl/node-lsp-bin-dir-is-on-exec-path-when-present ()
  (wl--skip-unless-installed)
  (should (member my/web-lsp-bin-dir exec-path)))

;; A real, confirmed gap: `exec-path' alone is not enough for `compile'/`shell-
;; command'-style invocations (`my/npm-run-script'/`my/nest-generate' below), which
;; run through a real shell subprocess doing its OWN PATH lookup from the `PATH'
;; environment variable --- `nest generate' failed with a plain shell "command not
;; found" until `setenv' was added alongside `add-to-list' on `exec-path'.
(ert-deftest wl/node-lsp-bin-dir-is-also-on-the-path-env-var-when-present ()
  (wl--skip-unless-installed)
  (should (member my/web-lsp-bin-dir (split-string (getenv "PATH") path-separator))))

(ert-deftest wl/typescript-language-server-is-on-the-resulting-path ()
  (wl--skip-unless-installed)
  (should (file-executable-p (wl--bin "typescript-language-server"))))

(ert-deftest wl/html-and-css-servers-are-on-the-resulting-path ()
  (wl--skip-unless-installed)
  (should (file-executable-p (wl--bin "vscode-html-language-server")))
  (should (file-executable-p (wl--bin "vscode-css-language-server"))))

(ert-deftest wl/nest-cli-is-on-the-resulting-path ()
  (wl--skip-unless-installed)
  (should (file-executable-p (wl--bin "nest"))))

(ert-deftest wl/angular-language-server-is-on-the-resulting-path ()
  (wl--skip-unless-installed)
  (should (file-executable-p (wl--bin "ngserver"))))

(ert-deftest wl/angular-cli-is-on-the-resulting-path ()
  (wl--skip-unless-installed)
  (should (file-executable-p (wl--bin "ng"))))

;; A real, confirmed gap: this machine's own system Node (root-owned) was too old
;; for the latest `@angular/cli' (needs >=22.22.3, system has 22.22.0) ---
;; downloaded a real, checksum-verified, pinned Node locally into `tools/node/'
;; instead of needing root to upgrade the system one, put FIRST on both
;; `exec-path' and `PATH' so every tool's own `#!/usr/bin/env node' shebang
;; resolves to it, not the older system one.
(defmacro wl--skip-unless-node-installed ()
  '(skip-unless (file-directory-p my/node-bin-dir)))

(ert-deftest wl/local-node-is-on-exec-path-and-path-when-present ()
  (wl--skip-unless-node-installed)
  (should (member my/node-bin-dir exec-path))
  (should (member my/node-bin-dir (split-string (getenv "PATH") path-separator))))

(ert-deftest wl/local-node-binary-is-executable ()
  (wl--skip-unless-node-installed)
  (should (file-executable-p (expand-file-name "node" my/node-bin-dir))))

;; A real, confirmed first-run UX gap: the Angular CLI's first invocation on a
;; machine asks interactively whether to share usage analytics, which just hangs
;; a `compile' buffer forever waiting for a y/N keypress it never sends.
(ert-deftest wl/angular-cli-analytics-prompt-is-disabled ()
  (should (equal (getenv "NG_CLI_ANALYTICS") "false")))

(defun wl--entry-modes (entry)
  "The bare mode symbols an `eglot-server-programs' ENTRY's car covers.
Each one may itself be a plain symbol or a (MODE :language-id STRING) list
--- confirmed directly in Eglot's own source, not assumed."
  (let ((car (car entry)))
    (mapcar (lambda (m) (if (listp m) (car m) m))
            (if (listp car) car (list car)))))

(ert-deftest wl/eglot-already-knows-typescript-language-server-for-every-ts-variant ()
  ;; Confirmed directly in Eglot's own defaults (config/init.el's comment) --- this
  ;; is a fact about Eglot itself, not something this config added; failing here
  ;; would mean Eglot's own defaults changed upstream, not a bug in this config.
  (dolist (mode '(js-mode js-ts-mode tsx-ts-mode typescript-ts-mode typescript-mode))
    (should (cl-some (lambda (entry) (memq mode (wl--entry-modes entry))) eglot-server-programs))))

(ert-deftest wl/mhtml-ts-mode-has-its-own-eglot-entry ()
  ;; The one real gap Eglot's own defaults have (only plain html-mode, never this
  ;; config's mhtml-ts-mode remap) --- fixed in config/init.el, checked for real here.
  (should (eq (cdr (assoc 'mhtml-ts-mode eglot-server-programs)) #'my/web-lsp-html-or-angular)))

;;; Angular detection: ngserver replaces the plain servers inside an Angular workspace

(ert-deftest wl/angular-project-root-finds-angular-json ()
  (test-with-temp-dir d
    (test-write-file (concat d "angular.json") "{}")
    (make-directory (concat d "src"))
    (let ((default-directory (concat d "src/")))
      (should (equal (expand-file-name (my/angular-project-root)) (expand-file-name d))))))

(ert-deftest wl/angular-project-root-is-nil-outside-an-angular-workspace ()
  (test-with-temp-dir d
    (let ((default-directory d))
      (should-not (my/angular-project-root)))))

(ert-deftest wl/angular-server-command-probes-the-projects-own-node-modules ()
  (test-with-temp-dir d
    (let ((cmd (my/angular-language-server-command d)))
      (should (equal (car cmd) "ngserver"))
      (should (member (expand-file-name "node_modules" d) cmd))
      (should (member "--stdio" cmd)))))

(ert-deftest wl/ts-dispatch-uses-angular-server-inside-an-angular-workspace ()
  (test-with-temp-dir d
    (test-write-file (concat d "angular.json") "{}")
    (let ((default-directory d) (buffer-file-name (concat d "a.ts")))
      (should (equal (car (my/web-lsp-ts-or-angular)) "ngserver")))))

(ert-deftest wl/html-dispatch-uses-angular-server-inside-an-angular-workspace ()
  (test-with-temp-dir d
    (test-write-file (concat d "angular.json") "{}")
    (let ((default-directory d) (buffer-file-name (concat d "a.html")))
      (should (equal (car (my/web-lsp-html-or-angular)) "ngserver")))))

(ert-deftest wl/ts-dispatch-falls-back-to-the-plain-server-outside-angular ()
  (wl--skip-unless-installed)
  (test-with-temp-dir d
    (let ((default-directory d) (buffer-file-name (concat d "a.ts")))
      (should (equal (car (my/web-lsp-ts-or-angular)) (wl--bin "typescript-language-server"))))))

(ert-deftest wl/html-dispatch-falls-back-to-the-plain-server-outside-angular ()
  (wl--skip-unless-installed)
  (test-with-temp-dir d
    (let ((default-directory d) (buffer-file-name (concat d "a.html")))
      (should (equal (car (my/web-lsp-html-or-angular)) (wl--bin "vscode-html-language-server"))))))

;;; C-c i: run/install npm scripts

(ert-deftest wl/npm-keys-are-bound ()
  (should (eq (key-binding (kbd "C-c i r")) #'my/npm-run-script))
  (should (eq (key-binding (kbd "C-c i i")) #'my/npm-install)))

(ert-deftest wl/npm-root-finds-the-nearest-package-json ()
  (test-with-temp-dir d
    (test-write-file (concat d "package.json") "{}")
    (make-directory (concat d "src"))
    (let ((buffer-file-name (concat d "src/a.ts")) (default-directory (concat d "src/")))
      (should (equal (expand-file-name (my/npm-root)) (expand-file-name d))))))

(ert-deftest wl/npm-run-script-offers-the-real-scripts-and-runs-the-chosen-one ()
  (test-with-temp-dir d
    (test-write-file (concat d "package.json")
                      "{\"name\": \"t\", \"scripts\": {\"build\": \"echo building\", \"test\": \"echo testing\"}}")
    (let ((buffer-file-name (concat d "a.ts")) (default-directory d) offered)
      (cl-letf (((symbol-function 'completing-read)
                 (lambda (_prompt choices &rest _) (setq offered choices) "build")))
        (my/npm-run-script))
      (should (equal (sort (copy-sequence offered) #'string<) '("build" "test")))
      (with-timeout (10 (error "npm run did not finish in time"))
        (while (get-buffer-process "*compilation*") (sit-for 0.2)))
      (should (string-match-p "building" (with-current-buffer "*compilation*" (buffer-string))))
      (kill-buffer "*compilation*"))))

(ert-deftest wl/npm-run-script-errors-clearly-with-no-package-json ()
  (test-with-temp-dir d
    (let ((buffer-file-name (concat d "a.ts")) (default-directory d))
      (should-error (my/npm-run-script) :type 'user-error))))

;;; C-c i n: nest generate

(ert-deftest wl/nest-keys-are-bound ()
  (should (eq (key-binding (kbd "C-c i n")) #'my/nest-generate)))

(ert-deftest wl/nest-project-root-finds-nest-cli-json ()
  (test-with-temp-dir d
    (test-write-file (concat d "nest-cli.json") "{}")
    (make-directory (concat d "src"))
    (let ((buffer-file-name (concat d "src/a.ts")) (default-directory (concat d "src/")))
      (should (equal (expand-file-name (my/nest-project-root)) (expand-file-name d))))))

(ert-deftest wl/nest-generate-errors-clearly-with-no-nest-cli-json ()
  (test-with-temp-dir d
    (let ((buffer-file-name (concat d "a.ts")) (default-directory d))
      (should-error (my/nest-generate) :type 'user-error))))

(ert-deftest wl/nest-generate-creates-the-real-file-in-a-real-nest-project ()
  ;; A real, confirmed fact about Nest's own CLI, not assumed: `nest generate'
  ;; needs `nest-cli.json' (checked above) but NOT a full `npm install' of the
  ;; project's own dependencies to run --- it is pure code generation. Scaffolds a
  ;; minimal but genuinely real Nest project layout (the parts `nest generate'
  ;; itself actually reads) rather than a full `nest new', to keep this fast.
  (wl--skip-unless-installed)
  (test-with-temp-dir d
    (test-write-file (concat d "nest-cli.json") "{\"collection\": \"@nestjs/schematics\", \"sourceRoot\": \"src\"}")
    (test-write-file (concat d "tsconfig.json") "{}")
    (make-directory (concat d "src"))
    (test-write-file (concat d "src/app.module.ts")
                      "import { Module } from '@nestjs/common';\n\n@Module({})\nexport class AppModule {}\n")
    (let ((buffer-file-name (concat d "src/app.module.ts")) (default-directory d))
      (cl-letf (((symbol-function 'completing-read) (lambda (&rest _) "service"))
                ((symbol-function 'read-string) (lambda (&rest _) "cats")))
        (my/nest-generate))
      (with-timeout (15 (error "nest generate did not finish in time"))
        (while (get-buffer-process "*compilation*") (sit-for 0.2)))
      (should (file-exists-p (concat d "src/cats/cats.service.ts")))
      (should (string-match-p "CatsService" (test-read-file (concat d "src/cats/cats.service.ts"))))
      ;; the owning module really gets updated, not just the new file created
      (should (string-match-p "CatsService" (test-read-file (concat d "src/app.module.ts"))))
      (kill-buffer "*compilation*"))))

;;; C-c i a: ng generate

(ert-deftest wl/ng-keys-are-bound ()
  (should (eq (key-binding (kbd "C-c i a")) #'my/ng-generate)))

(ert-deftest wl/ng-generate-errors-clearly-with-no-angular-json ()
  (test-with-temp-dir d
    (let ((buffer-file-name (concat d "a.ts")) (default-directory d))
      (should-error (my/ng-generate) :type 'user-error))))

(ert-deftest wl/ng-generate-creates-the-real-file-in-a-real-angular-project ()
  ;; A real, confirmed fact about the Angular CLI, not assumed: `ng generate'
  ;; needs `angular.json' (checked above) but NOT a full `npm install' of the
  ;; project's own dependencies to run --- its own schematics ship as part of
  ;; `@angular/cli' itself. Scaffolds a minimal but genuinely real Angular project
  ;; layout (the parts `ng generate' itself actually reads) rather than a full
  ;; `ng new', to keep this fast.
  (wl--skip-unless-installed) (wl--skip-unless-node-installed)
  (test-with-temp-dir d
    (test-write-file (concat d "angular.json")
                      "{\"version\": 1, \"projects\": {\"t\": {\"root\": \"\", \"sourceRoot\": \"src\", \"projectType\": \"application\"}}}")
    (make-directory (concat d "src/app") t)
    (test-write-file (concat d "src/app/app.ts")
                      "import { Component } from '@angular/core';\n@Component({ selector: 'app-root', template: '' })\nexport class App {}\n")
    (let ((buffer-file-name (concat d "src/app/app.ts")) (default-directory d))
      (cl-letf (((symbol-function 'completing-read) (lambda (&rest _) "component"))
                ((symbol-function 'read-string) (lambda (&rest _) "cats")))
        (my/ng-generate))
      (with-timeout (15 (error "ng generate did not finish in time"))
        (while (get-buffer-process "*compilation*") (sit-for 0.2)))
      (should (file-exists-p (concat d "src/app/cats/cats.ts")))
      (should (string-match-p "class Cats" (test-read-file (concat d "src/app/cats/cats.ts"))))
      (kill-buffer "*compilation*"))))

;;; Real server sessions (opt-in: tests/run-all.sh --lsp)

(defun wl--skip-unless-lsp ()
  (unless (getenv "RUN_LSP_TESTS") (ert-skip "set RUN_LSP_TESTS=1 (run-all.sh --lsp) to start real servers")))

(defun wl--symbols (server)
  (let ((deadline (+ (float-time) 20)) syms)
    (while (and (not syms) (< (float-time) deadline))
      (setq syms (ignore-errors
                   (jsonrpc-request server :textDocument/documentSymbol
                                     (list :textDocument (eglot--TextDocumentIdentifier)) :timeout 10)))
      (unless syms (sleep-for 0.3)))
    syms))

(ert-deftest wl/typescript-language-server-answers-through-eglot ()
  (wl--skip-unless-lsp) (wl--skip-unless-installed)
  (skip-unless (treesit-language-available-p 'typescript))
  (test-with-temp-dir d
    (test-write-file (concat d "a.ts") "interface Point { x: number; }\nfunction dist(p: Point) { return p.x; }\n")
    (let ((buf (find-file-noselect (concat d "a.ts"))) (eglot-sync-connect t) (eglot-connect-timeout 30))
      (unwind-protect
          (with-current-buffer buf
            (call-interactively #'eglot)
            (let ((server (eglot-current-server)))
              (should server)
              (should (cl-some (lambda (s) (equal "dist" (plist-get s :name))) (wl--symbols server)))
              (eglot-shutdown server)))
        (kill-buffer buf)))))

(ert-deftest wl/html-language-server-answers-through-eglot ()
  (wl--skip-unless-lsp) (wl--skip-unless-installed)
  (skip-unless (treesit-language-available-p 'html))
  (test-with-temp-dir d
    (test-write-file (concat d "a.html") "<html>\n<body>\n<p id=\"x\">hi</p>\n</body>\n</html>\n")
    (let ((buf (find-file-noselect (concat d "a.html"))) (eglot-sync-connect t) (eglot-connect-timeout 30))
      (unwind-protect
          (with-current-buffer buf
            (call-interactively #'eglot)
            (let ((server (eglot-current-server)))
              (should server)
              (should (wl--symbols server))
              (eglot-shutdown server)))
        (kill-buffer buf)))))

;;; languages-web-lsp.el ends here
