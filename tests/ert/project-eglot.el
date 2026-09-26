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

;;; project-eglot.el ends here
