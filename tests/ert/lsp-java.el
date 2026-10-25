;;; lsp-java.el --- the lsp-java branch's own config/lsp-java.el  -*- lexical-binding: t; -*-
;; harness: config

;; `config/lsp-java.el' is a plain `load'ed file (autoloaded by filename from init.el,
;; same as `C-c L' itself), not a `provide'/`require' feature --- and it happens to
;; share its own basename with the real, separate ELPA package also called `lsp-java'
;; (`require'ing the symbol `lsp-java' here would ambiguously resolve to THAT package
;; instead, or error outright since this file never `provide's anything itself).
(load (expand-file-name "lsp-java" user-emacs-directory) nil t)

(ert-deftest lsp-java/key-is-bound ()
  (should (eq (key-binding (kbd "C-c L")) 'my/lsp-java)))

(ert-deftest lsp-java/sanitize-filename-strips-every-windows-invalid-char ()
  (should (equal (my/lsp-java--sanitize-filename "System.java(<java.lang(System.class)")
                 "System.java(_java.lang(System.class)"))
  (should (equal (my/lsp-java--sanitize-filename "a<b>c:d\"e|f?g*h") "a_b_c_d_e_f_g_h"))
  ;; already-safe names pass through unchanged.
  (should (equal (my/lsp-java--sanitize-filename "java.lang.System.java") "java.lang.System.java")))

;; real, user-hit bug: clicking into a JDK MODULE class (e.g. `System.out.println', go-to-
;; definition into `System.class') makes jdtls return a `jdt://' URI whose query embeds the
;; class path a second time with characters it never escapes (`<', confirmed by reconstructing
;; the real shape and tracing `lsp-java--get-filename''s own fallback branch by hand --- see
;; config/lsp-java.el's own comment on `my/lsp-java--sanitize-filename' for the full account).
;; That branch only strips `/' and `\\', so the generated LOCAL CACHE filename still contains
;; `<', which Windows/NTFS refuses to create a file with ("Invalid argument", the exact real
;; error hit). The advice added here must make ANY such filename Windows-safe end to end.
(ert-deftest lsp-java/get-filename-advice-sanitizes-a-real-module-class-uri ()
  (skip-unless (and (locate-library "lsp-java") (locate-library "dash") (locate-library "s")))
  (require 'lsp-java)
  (let* ((url (concat "jdt://contents/System.class?"
                       (url-hexify-string "=mavenproject/<java.lang(System.class<java.base=/maven.pomderived=/true=/")))
         (name (lsp-java--get-filename url)))
    (should-not (string-match-p "[<>:\"|?*]" name))))

;;; lsp-java.el ends here
