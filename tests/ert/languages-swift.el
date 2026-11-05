;;; languages-swift.el --- swift-mode, C-c i w, and sourcekit-lsp  -*- lexical-binding: t; -*-
;; harness: config
;; `swift-mode' tests skip themselves if the package is not installed
;; (./build.sh packages). The real sourcekit-lsp test runs only with RUN_LSP_TESTS=1
;; (tests/run-all.sh --lsp), the same gating as Python/the web languages.

(require 'eglot) (require 'jsonrpc)

(defmacro swift--skip-unless-mode-installed ()
  '(skip-unless (locate-library "swift-mode")))

(defun swift--skip-unless-lsp ()
  (unless (getenv "RUN_LSP_TESTS") (ert-skip "set RUN_LSP_TESTS=1 (run-all.sh --lsp) to start a real server")))

;;; .swift opens in swift-mode (once the package is installed; see the
;;; explicit-activation-gap comment in init.el --- never automatic from the
;;; package's own `-autoloads.el' in this config)

(ert-deftest swift/dot-swift-opens-in-swift-mode ()
  (swift--skip-unless-mode-installed)
  (with-temp-buffer
    (setq buffer-file-name "/tmp/x.swift")
    (set-auto-mode)
    (should (eq major-mode 'swift-mode))))

;;; C-c i w: run the current .swift file

(ert-deftest swift/run-swift-key-is-bound ()
  (should (eq (key-binding (kbd "C-c i w")) #'my/run-swift-file)))

(ert-deftest swift/run-swift-file-errors-clearly-on-a-non-swift-buffer ()
  (test-with-temp-dir d
    (let ((buffer-file-name (concat d "a.py")))
      (should-error (my/run-swift-file) :type 'user-error))))

(ert-deftest swift/run-swift-file-really-runs-a-real-swift-file ()
  ;; A real, confirmed round trip: `swift' actually runs the file directly as a
  ;; script (no separate `swiftc' compile step at all --- confirmed directly), and
  ;; the real stdout is read back, not mocked.
  (skip-unless (executable-find "swift"))
  (test-with-temp-dir d
    (test-write-file (concat d "ok.swift")
                      "func add(a: Int, b: Int) -> Int {\n    return a + b\n}\nprint(add(a: 2, b: 3))\n")
    (let ((buffer-file-name (concat d "ok.swift")) (default-directory d))
      (my/run-swift-file)
      (with-timeout (30 (error "swift did not finish in time"))
        (while (get-buffer-process "*compilation*") (sit-for 0.2)))
      (should (string-match-p "^5$" (with-current-buffer "*compilation*" (buffer-string))))
      (kill-buffer "*compilation*"))))

(ert-deftest swift/run-swift-file-reports-a-real-compile-error ()
  (skip-unless (executable-find "swift"))
  (test-with-temp-dir d
    (test-write-file (concat d "bad.swift") "let n: Int = \"oops\"\n")
    (let ((buffer-file-name (concat d "bad.swift")) (default-directory d))
      (my/run-swift-file)
      (with-timeout (30 (error "swift did not finish in time"))
        (while (get-buffer-process "*compilation*") (sit-for 0.2)))
      (let ((out (with-current-buffer "*compilation*" (buffer-string))))
        (should (string-match-p "error:" out))
        (should (string-match-p "bad\\.swift" out)))
      (kill-buffer "*compilation*"))))

;;; sourcekit-lsp: wiring and a real server session

(ert-deftest swift/eglot-entry-is-registered-for-sourcekit-lsp ()
  ;; Not a built-in Eglot default the way `pylsp' is for Python --- confirmed
  ;; directly, so this config registers it itself, the same as the web/UI
  ;; languages. Wrapped in `with-eval-after-load' above (this config never
  ;; eagerly `require's `eglot'), so `require' it here first to force that.
  (require 'eglot)
  (should (equal (assq 'swift-mode eglot-server-programs) '(swift-mode . ("sourcekit-lsp")))))

(ert-deftest swift/sourcekit-lsp-answers-through-eglot-with-a-real-go-to-definition ()
  ;; A real, confirmed round trip: a real `sourcekit-lsp' process, a real
  ;; `textDocument/definition' request, jumping from a call site to the actual
  ;; method definition --- not mocked.
  (swift--skip-unless-lsp)
  (skip-unless (and (executable-find "swift") (executable-find "sourcekit-lsp")))
  (test-with-temp-dir d
    (test-write-file (concat d "Package.swift")
                      "// swift-tools-version:5.9\nimport PackageDescription\nlet package = Package(name: \"T\", targets: [.executableTarget(name: \"T\", path: \".\")])\n")
    (test-write-file (concat d "main.swift")
                      "struct Shape {\n    func area() -> Double {\n        return 0.0\n    }\n}\n\nfunc total(shapes: [Shape]) -> Double {\n    var sum = 0.0\n    for s in shapes {\n        sum += s.area()\n    }\n    return sum\n}\n")
    (let ((buf (find-file-noselect (concat d "main.swift"))) (eglot-sync-connect t) (eglot-connect-timeout 60))
      (unwind-protect
          (with-current-buffer buf
            (call-interactively #'eglot)
            (let ((server (eglot-current-server)))
              (should server)
              (should (equal (file-name-nondirectory (car (process-command (jsonrpc--process server)))) "sourcekit-lsp"))
              (goto-char (point-min))
              (search-forward "s.area()")
              (goto-char (match-beginning 0)) (forward-char 2)
              (call-interactively #'xref-find-definitions)
              (should (equal (buffer-name) "main.swift"))
              (should (string-match-p "func area" (buffer-substring (line-beginning-position) (line-end-position))))
              (eglot-shutdown server)))
        (kill-buffer buf)))))

;;; languages-swift.el ends here
