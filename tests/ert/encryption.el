;;; encryption.el --- C-c x e/d/E/D, real GnuPG round-trips  -*- lexical-binding: t; -*-
;; harness: config

;; WHAT/WHY: every test that actually touches `gpg' runs with `GNUPGHOME' pointed
;; at a fresh temp directory (the same `process-environment' isolation trick
;; `test-git' already uses for `GIT_*'), never the real user's own `~/.gnupg' ---
;; confirmed necessary the hard way while building this feature: a real test key
;; generated without this isolation left a stray key behind in the real keyring.

(defvar et--gpg-homedir-style 'unknown
  "Cached: `posix' if the real `gpg' on PATH wants a Cygwin/MSYS-style
homedir (\"/c/Users/...\"), `native' if it wants a plain one (\"C:/Users/
...\") --- only ambiguous on Windows, where more than one real gpg build can
end up on PATH (a native GnuPG4Win-style build, or an MSYS/Cygwin one such as
Git for Windows' own bundled `gpg') and each wants its OWN flavor; handing it
the wrong one does not fail cleanly, it silently prepends gpg's own current
directory to the path instead --- confirmed directly, a real failure on a
machine with Git for Windows' own MSYS `gpg' resolved from PATH and
`GNUPGHOME' set to Emacs's native-style temp dir: every real gpg operation
failed with a mangled, confusing \"No such file or directory\", the isolated
temp homedir itself never at fault.")

(defun et--gpg-wants-posix-homedir-p ()
  "Non-nil if the real `gpg' on PATH expects a Cygwin/MSYS-style homedir
path rather than a native one --- see `et--gpg-homedir-style'. Detected
once, from `gpg --version''s own \"Home:\" line, which always echoes back
whichever style THAT binary itself expects, so this needs no guessing at
which gpg build is actually on PATH."
  (when (eq et--gpg-homedir-style 'unknown)
    (setq et--gpg-homedir-style
          (with-temp-buffer
            (ignore-errors (call-process "gpg" nil t nil "--version"))
            (goto-char (point-min))
            (if (re-search-forward "^Home: /[a-zA-Z]/" nil t) 'posix 'native))))
  (eq et--gpg-homedir-style 'posix))

(defun et--gpg-homedir (dir)
  "DIR (a plain, native-style absolute path), converted to whichever path
flavor the real `gpg' on PATH actually expects --- see
`et--gpg-wants-posix-homedir-p'; a no-op on a real POSIX system, where
there is only ever one flavor to begin with."
  (if (and (eq system-type 'windows-nt) (et--gpg-wants-posix-homedir-p)
           (string-match "\\`\\([a-zA-Z]\\):" dir))
      (concat "/" (downcase (match-string 1 dir)) (substring dir (match-end 0)))
    dir))

(defmacro et-with-gpg-home (var &rest body)
  "Run BODY with a fresh, isolated GNUPGHOME in VAR."
  (declare (indent 1))
  `(test-with-temp-dir ,var
     (set-file-modes ,var #o700) ; gpg refuses a homedir with group/other access
     (let ((process-environment
            (cons (concat "GNUPGHOME=" (et--gpg-homedir (directory-file-name ,var)))
                  process-environment)))
       ,@body)))

(defun et--generate-test-key (homedir)
  "A real, no-passphrase test key, isolated to HOMEDIR."
  (let ((process-environment
         (cons (concat "GNUPGHOME=" (et--gpg-homedir (directory-file-name homedir)))
               process-environment)))
    (call-process "gpg" nil nil nil "--batch" "--yes" "--passphrase" ""
                  "--quick-generate-key" "Test User <test@example.com>"
                  "default" "default" "never")))

(defun et-need-gpg ()
  (unless (executable-find "gpg")
    (ert-skip "gpg is not installed")))

(ert-deftest encryption/keys-are-bound ()
  (should (eq (key-binding (kbd "C-c x e")) #'my/encrypt-file))
  (should (eq (key-binding (kbd "C-c x d")) #'my/decrypt-file))
  (should (eq (key-binding (kbd "C-c x E")) #'my/encrypt-folder))
  (should (eq (key-binding (kbd "C-c x D")) #'my/decrypt-folder)))

(ert-deftest encryption/gpg-run-signals-a-real-error-on-failure ()
  (et-need-gpg)
  (should-error (my/gpg--run (list "--this-flag-does-not-exist"))))

(ert-deftest encryption/with-passphrase-writes-a-0600-file-and-cleans-up ()
  (let (seen-path seen-mode seen-content)
    (my/gpg--with-passphrase
     "a real passphrase"
     (lambda (pf)
       (setq seen-path pf
             seen-mode (file-modes pf)
             seen-content (with-temp-buffer (insert-file-contents pf) (buffer-string)))))
    (should (equal seen-content "a real passphrase"))
    (should (= (logand seen-mode #o777) #o600))
    (should-not (file-exists-p seen-path))))

(ert-deftest encryption/with-passphrase-cleans-up-even-on-a-real-error ()
  (let (path)
    (should-error
     (my/gpg--with-passphrase "x" (lambda (pf) (setq path pf) (error "boom"))))
    (should-not (file-exists-p path))))

;;; Real round-trips --- a real file, a real password or a real key, a real gpg.

(ert-deftest encryption/file-round-trips-with-a-password ()
  (et-need-gpg)
  (et-with-gpg-home home
    (let* ((plain (expand-file-name "secret.txt" home))
           (content "real secret content, not a fixture placeholder"))
      (with-temp-file plain (insert content))
      (cl-letf (((symbol-function 'read-passwd) (lambda (&rest _) "a real test password")))
        (my/encrypt-file plain))
      (should (file-exists-p (concat plain ".gpg")))
      ;; A real, independent confirmation that this is genuinely encrypted, not
      ;; just copied --- the plaintext string must not appear in the cipher file.
      ;; `insert-file-contents-literally', not plain `insert-file-contents': a
      ;; real, found-the-hard-way gotcha --- `epa-file' registers itself in
      ;; `file-name-handler-alist' for any `*.gpg' name and transparently tries
      ;; to decrypt on a plain read too, which corrupted the LATER, real decrypt
      ;; below (a second, conflicting gpg-agent interaction over the same
      ;; symmetric session). The `-literally' variant bypasses every such
      ;; handler, reading the real raw bytes, which is also the actually
      ;; correct way to inspect a binary file's content regardless.
      (should-not (string-search content (with-temp-buffer
                                            (insert-file-contents-literally (concat plain ".gpg"))
                                            (buffer-string))))
      (delete-file plain)
      (cl-letf (((symbol-function 'read-passwd) (lambda (&rest _) "a real test password")))
        (my/decrypt-file (concat plain ".gpg")))
      (should (equal (with-temp-buffer (insert-file-contents plain) (buffer-string))
                      content)))))

(ert-deftest encryption/file-round-trips-with-a-real-gpg-key ()
  (et-need-gpg)
  (et-with-gpg-home home
    (et--generate-test-key home)
    (let* ((plain (expand-file-name "secret.txt" home))
           (content "key-encrypted content"))
      (with-temp-file plain (insert content))
      (cl-letf (((symbol-function 'completing-read) (lambda (&rest _) "Test User <test@example.com>")))
        (my/encrypt-file plain))
      (should (file-exists-p (concat plain ".gpg")))
      (delete-file plain)
      ;; The test key has no passphrase, so decrypting needs no `read-passwd' at
      ;; all --- stubbed anyway, to fail loudly (rather than hang) if that ever
      ;; stops being true.
      (cl-letf (((symbol-function 'read-passwd) (lambda (&rest _) (error "should not be asked"))))
        (my/decrypt-file (concat plain ".gpg")))
      (should (equal (with-temp-buffer (insert-file-contents plain) (buffer-string))
                      content)))))

(ert-deftest encryption/wrong-password-fails-cleanly-not-silently ()
  (et-need-gpg)
  (et-with-gpg-home home
    (let ((plain (expand-file-name "secret.txt" home)))
      (with-temp-file plain (insert "content"))
      (cl-letf (((symbol-function 'read-passwd) (lambda (&rest _) "the-real-password")))
        (my/encrypt-file plain))
      (delete-file plain)
      (cl-letf (((symbol-function 'read-passwd) (lambda (&rest _) "a-wrong-password")))
        (should-error (my/decrypt-file (concat plain ".gpg"))))
      (should-not (file-exists-p plain)))))

;;; Folders --- tarred first, so structure and filenames are hidden too.

(ert-deftest encryption/folder-round-trips-with-a-password-including-a-subdirectory ()
  (et-need-gpg)
  (et-with-gpg-home home
    (let ((dir (expand-file-name "myfolder" home)))
      (make-directory (expand-file-name "sub" dir) t)
      (with-temp-file (expand-file-name "one.txt" dir) (insert "file one"))
      (with-temp-file (expand-file-name "sub/two.txt" dir) (insert "nested file two"))
      (cl-letf (((symbol-function 'completing-read) (lambda (&rest _) ""))
                ((symbol-function 'read-passwd) (lambda (&rest _) "folder password")))
        (my/encrypt-folder dir))
      (let ((archive (concat (directory-file-name dir) ".tar.gpg")))
        (should (file-exists-p archive))
        (should-not (file-exists-p (concat (directory-file-name dir) ".tar"))) ; cleaned up
        (delete-directory dir t)
        (cl-letf (((symbol-function 'read-passwd) (lambda (&rest _) "folder password")))
          (my/decrypt-folder archive))
        (should (equal (with-temp-buffer (insert-file-contents (expand-file-name "one.txt" dir)) (buffer-string))
                        "file one"))
        (should (equal (with-temp-buffer (insert-file-contents (expand-file-name "sub/two.txt" dir)) (buffer-string))
                        "nested file two"))
        ;; The encrypted archive itself is kept (only the intermediate plain
        ;; .tar is cleaned up, on both the encrypt and decrypt side).
        (should (file-exists-p archive))
        (should-not (file-exists-p (concat (directory-file-name dir) ".tar")))))))

;;; encryption.el ends here
