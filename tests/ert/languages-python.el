;;; languages-python.el --- Python tree-sitter mode and C-c i p  -*- lexical-binding: t; -*-
;; harness: config
;; Grammar-dependent tests skip themselves if the grammar is not installed
;; (./build.sh grammars).

(require 'treesit)

(defmacro py-with-grammar (&rest body)
  (declare (indent 0))
  `(progn (skip-unless (treesit-language-available-p 'python)) ,@body))

;;; .py opens in python-ts-mode, not the legacy python-mode

(ert-deftest py/dot-py-opens-in-python-ts-mode ()
  ;; A real, found-by-testing gap, not assumed: `python.el' registering
  ;; `(python-mode . python-ts-mode)' in `treesit-major-mode-remap-alist' does NOT
  ;; by itself make `.py' open in `python-ts-mode' --- that variable is only a
  ;; catalog, copied into `major-mode-remap-alist' (what `set-auto-mode' actually
  ;; consults) by `treesit-enabled-modes', which defaults to nil. This config adds
  ;; the real entry itself, the same way it already does for Java/JS/CSS/HTML.
  (py-with-grammar
    (with-temp-buffer
      (setq buffer-file-name "/tmp/x.py")
      (set-auto-mode)
      (should (eq major-mode 'python-ts-mode)))))

;;; C-c i p: run the current .py file

(ert-deftest py/run-python-key-is-bound ()
  (should (eq (key-binding (kbd "C-c i p")) #'my/run-python-file)))

(ert-deftest py/run-python-file-errors-clearly-on-a-non-py-buffer ()
  (test-with-temp-dir d
    (let ((buffer-file-name (concat d "a.rb")))
      (should-error (my/run-python-file) :type 'user-error))))

(ert-deftest py/run-python-file-really-runs-a-real-py-file ()
  ;; A real, confirmed round trip: python3 actually runs and its real stdout is
  ;; read back, not mocked.
  (skip-unless (or (executable-find "python3") (executable-find "python")))
  (test-with-temp-dir d
    (test-write-file (concat d "ok.py") "def add(a, b):\n    return a + b\n\nprint(add(2, 3))\n")
    (let ((buffer-file-name (concat d "ok.py")) (default-directory d))
      (my/run-python-file)
      (with-timeout (20 (error "python3 did not finish in time"))
        (while (get-buffer-process "*compilation*") (sit-for 0.2)))
      (should (string-match-p "^5$" (with-current-buffer "*compilation*" (buffer-string))))
      (kill-buffer "*compilation*"))))

(ert-deftest py/run-python-file-reports-a-real-traceback ()
  (skip-unless (or (executable-find "python3") (executable-find "python")))
  (test-with-temp-dir d
    (test-write-file (concat d "bad.py") "def boom():\n    return 1 / 0\n\nboom()\n")
    (let ((buffer-file-name (concat d "bad.py")) (default-directory d))
      (my/run-python-file)
      (with-timeout (20 (error "python3 did not finish in time"))
        (while (get-buffer-process "*compilation*") (sit-for 0.2)))
      (let ((out (with-current-buffer "*compilation*" (buffer-string))))
        (should (string-match-p "ZeroDivisionError" out))
        (should (string-match-p "bad\\.py" out)))
      (kill-buffer "*compilation*"))))

;;; languages-python.el ends here
