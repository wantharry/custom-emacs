;;; docsbuffer.el --- every guide lives in one always-there buffer  -*- lexical-binding: t; -*-
;; harness: config

(require 'docsbuffer (expand-file-name "docsbuffer" (or (getenv "CONFIG_DIR") user-emacs-directory)))

(defmacro db-with-fake-project (root &rest body)
  "Bind ROOT to a temp folder with a README.md and two docs/*.md files, and point
`my/docs-root' at it for the duration of BODY."
  (declare (indent 1))
  `(test-with-temp-dir ,root
     (make-directory (concat ,root "docs") t)
     (test-write-file (concat ,root "README.md") "# Top\n\nHello.\n")
     (test-write-file (concat ,root "docs/AAA.md") "# AAA\n\nFirst guide.\n")
     (test-write-file (concat ,root "docs/BBB.md") "# BBB\n\nSecond guide.\n")
     (let ((my/docs-root ,root))
       (unwind-protect (progn ,@body)
         (when (get-buffer my/docs-buffer-name) (kill-buffer my/docs-buffer-name))))))

;;; Building it

(ert-deftest docs/rebuild-includes-every-file-in-order ()
  (db-with-fake-project root
    (let ((buf (my/docs-rebuild)))
      (with-current-buffer buf
        (should (string-match-p "Hello\\." (buffer-string)))
        (should (string-match-p "First guide\\." (buffer-string)))
        (should (string-match-p "Second guide\\." (buffer-string)))
        ;; README, then AAA, then BBB (alphabetical after README)
        (should (< (string-match "Hello\\." (buffer-string)) (string-match "First guide" (buffer-string))))
        (should (< (string-match "First guide" (buffer-string)) (string-match "Second guide" (buffer-string))))))))

(ert-deftest docs/a-doc-file-removed-since-listing-is-simply-left-out ()
  ;; docs/*.md is expanded by `file-expand-wildcards', which only ever returns files that
  ;; exist, so a deleted docs/*.md file cannot appear as "missing": it is just absent,
  ;; with no error and no dangling reference to it.
  (db-with-fake-project root
    (delete-file (concat root "docs/BBB.md"))
    (let ((buf (my/docs-rebuild)))
      (with-current-buffer buf
        (should (string-match-p "First guide\." (buffer-string)))
        (should-not (string-match-p "BBB" (buffer-string)))))))

(ert-deftest docs/a-missing-readme-does-not-error-and-says-so ()
  ;; README.md, unlike docs/*.md, is always included whether or not it exists, so it is the
  ;; one file that can genuinely trigger the "(missing)" fallback.
  (db-with-fake-project root
    (delete-file (concat root "README.md"))
    (let ((buf (my/docs-rebuild)))
      (with-current-buffer buf
        (should (string-match-p "(missing)" (buffer-string)))
        (should (string-match-p "First guide\." (buffer-string)))
        (should (string-match-p "Second guide\." (buffer-string)))))))

(ert-deftest docs/rebuild-is-idempotent-and-does-not-duplicate-content ()
  (db-with-fake-project root
    (my/docs-rebuild)
    (my/docs-rebuild)
    (with-current-buffer my/docs-buffer-name
      (should (= 1 (cl-count-if (lambda (_) t) (list (string-match "First guide" (buffer-string))))))
      (should-not (string-match "First guide.*First guide" (buffer-string))))))

(ert-deftest docs/the-buffer-is-read-only ()
  (db-with-fake-project root
    (my/docs-rebuild)
    (with-current-buffer my/docs-buffer-name
      (should buffer-read-only)
      (should-error (let ((buffer-read-only t)) (insert "x")) :type 'buffer-read-only))))

(ert-deftest docs/the-buffer-is-not-marked-modified ()
  (db-with-fake-project root
    (my/docs-rebuild)
    (should-not (buffer-modified-p (get-buffer my/docs-buffer-name)))))

(ert-deftest docs/mode-is-derived-from-outline-mode-for-folding ()
  (db-with-fake-project root
    (my/docs-rebuild)
    (with-current-buffer my/docs-buffer-name
      (should (derived-mode-p 'outline-mode))
      (should (string= outline-regexp "\\* ")))))

;;; The table of contents and jumping

(ert-deftest docs/toc-lists-every-file-as-a-button ()
  (db-with-fake-project root
    (my/docs-rebuild)
    (with-current-buffer my/docs-buffer-name
      (goto-char (point-min))
      (should (next-button (point-min)))
      (should (string-match-p "README\\.md" (buffer-string)))
      (should (string-match-p "docs/AAA\\.md" (buffer-string)))
      (should (string-match-p "docs/BBB\\.md" (buffer-string))))))

(ert-deftest docs/clicking-a-toc-entry-jumps-to-that-guides-section ()
  (db-with-fake-project root
    (my/docs-rebuild)
    (save-window-excursion
      (switch-to-buffer my/docs-buffer-name)
      (goto-char (point-min))
      (search-forward "docs/BBB.md")
      (backward-char 2)
      (push-button)
      (should (looking-at-p "\\* docs/BBB\\.md"))
      (should (string-match-p "Second guide" (buffer-substring (point) (min (point-max) (+ (point) 200))))))))

(ert-deftest docs/file-positions-are-recorded-for-every-file ()
  (db-with-fake-project root
    (my/docs-rebuild)
    (with-current-buffer my/docs-buffer-name
      (should (= 3 (length my/docs--file-positions)))
      (should (assoc (expand-file-name "README.md" root) my/docs--file-positions))
      (should (assoc (expand-file-name "docs/AAA.md" root) my/docs--file-positions))
      (should (assoc (expand-file-name "docs/BBB.md" root) my/docs--file-positions)))))

;;; The real project's docs (no fake project: read what is actually here)

(ert-deftest docs/the-real-project-builds-with-every-real-guide ()
  (let* ((my/docs-root test-root)
         (buf (my/docs-rebuild)))
    (with-current-buffer buf
      ;; every real guide is really there, as its own section heading (not merely mentioned
      ;; in passing by some other guide's prose, which is why this checks the heading form
      ;; rather than just the bare filename: docs/TESTING.md itself contains the literal
      ;; text "(missing)" while describing this very feature)
      (dolist (f (directory-files (expand-file-name "docs" test-root) nil "\\.md\\'"))
        (should (string-match-p (format "^\\* docs/%s$" (regexp-quote f)) (buffer-string))))
      (should (string-match-p "^\\* README\\.md$" (buffer-string)))
      (should (assoc (expand-file-name "README.md" test-root) my/docs--file-positions)))))

;;; Wiring: keys, startup, no cost

(ert-deftest docs/keys-are-bound ()
  (should (eq (key-binding (kbd "C-c d")) 'my/docs))
  (should (eq (key-binding (kbd "C-c D")) 'my/docs-rebuild)))

(ert-deftest docs/the-buffer-already-exists-right-after-startup ()
  ;; Unlike the lazy features (Magit, Treemacs, Consult...), this one is built eagerly, in a
  ;; fresh subprocess, because the whole point is that it is there before you ask for it.
  (let ((out (with-output-to-string
               (with-current-buffer standard-output
                 (call-process test-emacs nil t nil "--batch" "--init-directory" (getenv "CONFIG_DIR")
                               "-l" (expand-file-name "early-init.el" (getenv "CONFIG_DIR"))
                               "-l" (expand-file-name "init.el" (getenv "CONFIG_DIR"))
                               "--eval" "(princ (list (and (get-buffer \"*docs*\") t) (buffer-local-value 'buffer-read-only (get-buffer \"*docs*\"))))")))))
    (should (string-match-p "(t t)" out))))

(ert-deftest docs/building-it-adds-no-measurable-startup-cost ()
  (let ((best most-positive-fixnum))
    (dotimes (_ 3)
      (let ((t0 (float-time)))
        (call-process test-emacs nil nil nil "--batch" "--init-directory" (getenv "CONFIG_DIR")
                      "-l" (expand-file-name "early-init.el" (getenv "CONFIG_DIR"))
                      "-l" (expand-file-name "init.el" (getenv "CONFIG_DIR"))
                      "--eval" "(kill-emacs)")
        (setq best (min best (- (float-time) t0)))))
    (should (< best 0.5))))

(ert-deftest docs/my-docs-command-shows-the-buffer ()
  (db-with-fake-project root
    (save-window-excursion
      (my/docs)
      (should (equal (buffer-name) my/docs-buffer-name)))))

;;; docsbuffer.el ends here
