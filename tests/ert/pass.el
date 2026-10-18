;;; pass.el --- C-c p f/i/g/I, real password-store round-trips  -*- lexical-binding: t; -*-
;; harness: config

;; WHAT/WHY: same isolation discipline as tests/ert/encryption.el --- every test
;; runs with its own fresh GNUPGHOME *and* its own fresh `my/pass-store-dir',
;; never the real user's own `~/.gnupg'/`~/.password-store'.

(defun pt--real-pass-program ()
  "The real tools/pass/pass in this repository, regardless of where
`my/pass-program' resolves in the current test harness (its own temp copy
of just the config/*.el files has no tools/ directory at all, exactly like
the Windows bundle, which `my/pass-program' is meant to handle --- see
`gr--real-script' in tests/ert/gitfolders.el for the same, already-
established gotcha)."
  (expand-file-name "tools/pass/pass" test-root))

(defmacro pt-with-store (var &rest body)
  "Run BODY with a fresh, isolated GNUPGHOME and `my/pass-store-dir' in VAR
(a directory --- the store itself, not yet initialized), and `my/pass-
program' pointed at the real script regardless of harness path quirks."
  (declare (indent 1))
  `(test-with-temp-dir pt--home
     (set-file-modes pt--home #o700)
     (test-with-temp-dir ,var
       (let ((process-environment (cons (concat "GNUPGHOME=" (directory-file-name pt--home))
                                         process-environment))
             (my/pass-store-dir ,var))
         (cl-letf (((symbol-function 'my/pass-program) (lambda () (pt--real-pass-program))))
           ,@body)))))

(defun pt-need-pass ()
  "Skip unless the real script is really runnable --- on Windows that means
present on disk AND a real shell to run it through (`my/pass--shell-program'),
never `file-executable-p' directly: that is exactly the check `my/pass-
program' itself does NOT rely on there, per its own docstring, since Windows
never reports a plain shebang script as executable regardless of its real
permissions. Using the feature's own real-availability logic here, rather
than a raw POSIX check, is what lets these round-trip tests actually
exercise the Windows invocation path on Windows instead of skipping it
outright."
  (unless (or (file-executable-p (pt--real-pass-program))
              (and (file-exists-p (pt--real-pass-program)) (my/pass--shell-program)))
    (ert-skip "tools/pass/pass is missing or not executable")))

(ert-deftest pass/the-real-script-is-executable-and-valid-bash ()
  ;; `file-executable-p' is skipped on Windows --- not a weaker check, a correct one:
  ;; Windows has no POSIX execute bit, and `file-executable-p' there only ever returns
  ;; non-nil for a file ending in .exe/.bat/.cmd/.com (Emacs's own documented behavior),
  ;; never for a plain shebang script regardless of its real permissions. That gap is
  ;; exactly what `my/pass--invocation' (config/init.el) exists to route around, by
  ;; running this same script THROUGH the bundled shell instead of as a program in its
  ;; own right --- see that function's docstring. The syntax check below is still real
  ;; and still runs on every platform.
  (unless (eq system-type 'windows-nt)
    (should (file-executable-p (pt--real-pass-program))))
  (should (equal (call-process "bash" nil nil nil "-n" (pt--real-pass-program)) 0)))

(ert-deftest pass/program-resolves-to-something-real-when-bundled-or-on-path ()
  ;; Not using `pt--real-pass-program' here --- this is the one test that
  ;; actually exercises `my/pass-program''s own real resolution, the same
  ;; distinction `gitfolders.el' draws between its "stub" tests and its one
  ;; real-script test.
  (when-let* ((prog (my/pass-program)))
    (should (or (file-executable-p prog) (executable-find prog)))))

(defmacro pt-no-prompts (&rest body)
  "Run BODY with every interactive prompt `C-c p I'/`C-c p i' might use
stubbed to always proceed --- a real key-generation confirmation, a real
name/email, a real secret. Each test overrides what it actually cares about."
  (declare (indent 0))
  `(cl-letf (((symbol-function 'y-or-n-p) (lambda (&rest _) t))
             ((symbol-function 'read-string)
              (lambda (prompt &rest _)
                (cond ((string-match-p "name" prompt) "Test User")
                      ((string-match-p "email" prompt) "test@example.com")
                      (t ""))))
             ((symbol-function 'read-passwd) (lambda (&rest _) "a real test secret")))
     ,@body))

(ert-deftest pass/keys-are-bound ()
  (should (eq (key-binding (kbd "C-c p f")) (if (my/pass-program) #'my/pass-find #'my/pass-missing)))
  (should (eq (key-binding (kbd "C-c p i")) (if (my/pass-program) #'my/pass-insert #'my/pass-missing)))
  (should (eq (key-binding (kbd "C-c p g")) (if (my/pass-program) #'my/pass-generate #'my/pass-missing)))
  (should (eq (key-binding (kbd "C-c p I")) (if (my/pass-program) #'my/pass-init #'my/pass-missing))))

(ert-deftest pass/init-generates-a-key-when-none-exists-and-sets-up-the-store ()
  (pt-need-pass)
  (pt-with-store store
    (should-not (epg-list-keys (epg-make-context) nil 'public))
    (pt-no-prompts (my/pass-init))
    (should (epg-list-keys (epg-make-context) nil 'public))
    (should (file-exists-p (expand-file-name ".gpg-id" store)))))

(ert-deftest pass/init-is-a-clean-no-op-the-second-time ()
  (pt-need-pass)
  (pt-with-store store
    (pt-no-prompts (my/pass-init))
    (let (asked)
      (cl-letf (((symbol-function 'y-or-n-p) (lambda (&rest _) (setq asked t) t)))
        (my/pass-init))
      (should-not asked))))

(ert-deftest pass/insert-then-find-round-trips-a-real-secret ()
  (pt-need-pass)
  (pt-with-store store
    (pt-no-prompts
     (cl-letf (((symbol-function 'read-passwd) (lambda (&rest _) "correct-horse-battery-staple")))
       (my/pass-insert "sites/example")))
    (should (member "sites/example" (my/pass-list)))
    (my/pass-find "sites/example")
    (should (equal (car kill-ring) "correct-horse-battery-staple"))))

(ert-deftest pass/insert-asks-before-overwriting-an-existing-entry ()
  (pt-need-pass)
  (pt-with-store store
    (pt-no-prompts (my/pass-insert "sites/example"))
    (cl-letf (((symbol-function 'y-or-n-p) (lambda (&rest _) nil)))
      (should-error (my/pass-insert "sites/example") :type 'user-error))))

(ert-deftest pass/generate-makes-a-real-random-password-of-the-right-length ()
  (pt-need-pass)
  (pt-with-store store
    (pt-no-prompts (my/pass-generate "sites/random" 24))
    (should (= (length (car kill-ring)) 24))
    (my/pass-find "sites/random")
    (should (= (length (car kill-ring)) 24))))

(ert-deftest pass/generate-is-silent-for-a-brand-new-entry-but-asks-to-overwrite ()
  (pt-need-pass)
  (pt-with-store store
    (let (asked)
      (cl-letf (((symbol-function 'y-or-n-p) (lambda (&rest _) (setq asked t) t)))
        (pt-no-prompts (my/pass-generate "sites/random" 16)))
      (should-not asked)) ; a brand-new entry needs no confirmation at all
    (cl-letf (((symbol-function 'y-or-n-p) (lambda (&rest _) nil)))
      (let ((before (my/pass-list)))
        (should-error (my/pass-generate "sites/random" 10) :type 'user-error)
        ;; Declining the overwrite must leave the real existing entry alone.
        (should (equal (my/pass-list) before))))))

(ert-deftest pass/list-reflects-real-files-on-disk-including-nested-ones ()
  (pt-need-pass)
  (pt-with-store store
    (pt-no-prompts
     (my/pass-insert "a")
     (my/pass-insert "folder/b"))
    (should (equal (sort (my/pass-list) #'string<) '("a" "folder/b")))))

;;; pass.el ends here
