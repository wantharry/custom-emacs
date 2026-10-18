;;; project-eglot.el --- project, xref, eldoc, flymake, eglot  -*- lexical-binding: t; -*-
;; harness: bare

(require 'project) (require 'xref) (require 'eldoc) (require 'flymake) (require 'eglot)

(ert-deftest project/finds-git-root ()
  (test-with-temp-dir d
    (test-git d "init" "-q")
    (let ((pr (project-current nil d)))
      (should pr)
      (should (equal (file-truename (project-root pr)) (file-truename d))))))

(ert-deftest project/lists-tracked-files ()
  (test-with-temp-dir d
    (test-git d "init" "-q")
    (test-write-file (concat d "a.txt") "x")
    (test-git d "add" "a.txt")
    (should (member "a.txt" (mapcar #'file-name-nondirectory
                                    (project-files (project-current nil d)))))))

(ert-deftest project/plain-directory-is-not-a-project ()
  (test-with-temp-dir d
    (should-not (project-current nil d))))

(ert-deftest xref/elisp-backend-is-chosen-in-elisp-buffers ()
  (test-in-buffer #'emacs-lisp-mode "(car x)"
    (should (eq 'elisp (xref-find-backend)))))

(ert-deftest xref/finds-lisp-definitions ()
  (test-in-buffer #'emacs-lisp-mode "(string-join a b)"
    (should (xref-backend-definitions 'elisp "string-join"))))

(ert-deftest eldoc/mode-toggles ()
  (test-in-buffer #'emacs-lisp-mode ""
    (eldoc-mode 1) (should eldoc-mode)
    (eldoc-mode -1) (should-not eldoc-mode)))

(ert-deftest flymake/elisp-backend-registered ()
  (test-in-buffer #'emacs-lisp-mode ""
    (flymake-mode 1)
    (should flymake-mode)
    (should (memq 'elisp-flymake-byte-compile flymake-diagnostic-functions))
    (flymake-mode -1)))

(ert-deftest eglot/client-is-present-with-server-table ()
  (should (fboundp 'eglot))
  (should (fboundp 'eglot-ensure))
  (should eglot-server-programs))

(defun pe--eglot-server-for (mode)
  "Does any `eglot-server-programs' entry cover MODE (a key can be one mode
symbol or a list of several, matching how the real table is shaped)?"
  (seq-find (lambda (entry) (if (listp (car entry)) (memq mode (car entry)) (eq (car entry) mode)))
            eglot-server-programs))

(ert-deftest eglot/java-modes-have-a-configured-server ()
  (should (pe--eglot-server-for 'java-mode))
  (should (pe--eglot-server-for 'java-ts-mode)))

(ert-deftest eglot/rust-modes-have-a-configured-server ()
  (should (pe--eglot-server-for 'rust-mode))
  (should (pe--eglot-server-for 'rust-ts-mode)))

(ert-deftest eglot/python-modes-have-a-configured-server ()
  (should (pe--eglot-server-for 'python-mode)))

(ert-deftest eglot/fundamental-mode-has-no-configured-server ()
  (should-not (pe--eglot-server-for 'fundamental-mode)))

(ert-deftest project/remembers-and-forgets-a-project ()
  ;; `project-list-file' rebound to a throwaway path --- otherwise this writes
  ;; straight into the REAL `~/.emacs.d/projects.eld' (a real side-effect leak
  ;; outside this test's own sandbox, on any machine) --- found the hard way,
  ;; running this suite on a genuinely fresh machine for the first time: there
  ;; `~/.emacs.d/' does not exist yet at all, so the write fails outright
  ;; (file-missing) rather than just leaking into a real file that happens to
  ;; already be there.
  (test-with-temp-dir store
    (let ((project-list-file (concat store "projects.eld")))
      (test-with-temp-dir d
        (test-git d "init" "-q")
        (project-remember-project (project-current nil d))
        (should (member (file-truename d) (mapcar #'file-truename (project-known-project-roots))))
        (project-forget-project d)
        (should-not (member (file-truename d) (mapcar #'file-truename (project-known-project-roots))))))))

(ert-deftest project/files-respect-gitignore ()
  (test-with-temp-dir d
    (test-git d "init" "-q")
    (test-write-file (concat d ".gitignore") "ignored.txt\n")
    (test-write-file (concat d "kept.txt") "")
    (test-write-file (concat d "ignored.txt") "")
    (test-git d "add" ".gitignore" "kept.txt")
    (let ((files (mapcar #'file-name-nondirectory (project-files (project-current nil d)))))
      (should (member "kept.txt" files))
      (should-not (member "ignored.txt" files)))))

(ert-deftest xref/backend-identifier-at-point-returns-the-symbol ()
  (test-in-buffer #'emacs-lisp-mode "(string-join a b)"
    (goto-char 15) ; inside "a"
    (should (equal (xref-backend-identifier-at-point 'elisp) "a"))))

(ert-deftest xref/completion-table-includes-a-known-function ()
  (test-in-buffer #'emacs-lisp-mode ""
    (should (test-completion "car" (xref-backend-identifier-completion-table 'elisp)))))

(ert-deftest xref/finds-definitions-as-real-items-with-a-resolvable-location ()
  (test-in-buffer #'emacs-lisp-mode "(string-join a b)"
    (let* ((xrefs (xref-backend-definitions 'elisp "string-join"))
           (item (car xrefs)))
      (should (xref-item-p item))
      (should (marker-buffer (xref-location-marker (xref-item-location item)))))))

(ert-deftest flymake/checkdoc-backend-reports-real-notes-once-the-file-is-trusted ()
  ;; `elisp-flymake-checkdoc'/`elisp-flymake-byte-compile' refuse to run on a file
  ;; outside `trusted-content' (a real, newer Emacs security gate, found directly
  ;; while writing this test --- without it, `flymake-start' silently disables both
  ;; backends and no diagnostic is ever produced, which would make this test flaky
  ;; rather than meaningful).
  (test-with-temp-dir d
    (let* ((f (test-write-file (concat d "t.el") "(defun my-test-fn ()\n  1)\n"))
           (buf (find-file-noselect f))
           (trusted-content (list (abbreviate-file-name d))))
      (unwind-protect
          (with-current-buffer buf
            (emacs-lisp-mode)
            (flymake-mode 1)
            (flymake-start)
            (let ((n 0))
              (while (and (< n 50) (null (flymake-diagnostics))) (sit-for 0.2) (setq n (1+ n))))
            (should (flymake-diagnostics))
            (should (seq-some (lambda (diag) (eq (flymake-diagnostic-backend diag) 'elisp-flymake-checkdoc))
                              (flymake-diagnostics))))
        (kill-buffer buf)))))

(ert-deftest flymake/diagnostics-are-cleared-when-the-mode-is-disabled ()
  (test-with-temp-dir d
    (let* ((f (test-write-file (concat d "t.el") "(defun my-test-fn ()\n  1)\n"))
           (buf (find-file-noselect f))
           (trusted-content (list (abbreviate-file-name d))))
      (unwind-protect
          (with-current-buffer buf
            (emacs-lisp-mode)
            (flymake-mode 1)
            (flymake-start)
            (let ((n 0))
              (while (and (< n 50) (null (flymake-diagnostics))) (sit-for 0.2) (setq n (1+ n))))
            (should (flymake-diagnostics))
            (flymake-mode -1)
            (should-not (flymake-diagnostics)))
        (kill-buffer buf)))))

;;; project-eglot.el ends here
