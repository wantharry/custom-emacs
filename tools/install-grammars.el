;;; install-grammars.el --- build the tree-sitter grammars we use  -*- lexical-binding: t; -*-
;; Usage: ./build.sh grammars      (needs network, git and a C compiler)
;; Installs into config/tree-sitter/.  Versions come from `treesit-language-source-alist'
;; in config/init.el, which pins ones compatible with our tree-sitter library.

;; Load the real init.el rather than redeclaring `treesit-language-source-alist' here
;; a second time, so this script always installs whatever languages init.el actually
;; pins --- the two can never drift apart. `nil t' is (NOERROR NOMESSAGE): still errors
;; out loudly if init.el itself fails to load, just without the usual "Loading init.el
;; (source)..." chatter in this script's own batch output.
(load (expand-file-name "init.el" user-emacs-directory) nil t)
(require 'treesit)

(let ((out (expand-file-name "tree-sitter" user-emacs-directory)))
  (make-directory out t)
  (dolist (entry treesit-language-source-alist)
    (let ((lang (car entry)))
      ;; Skip anything already built, so re-running this (e.g. after adding one new
      ;; language to init.el) does not re-clone and recompile every grammar again.
      (if (treesit-language-available-p lang)
          (message "Grammar already installed: %s" lang)
        (message "Installing grammar: %s" lang)
        (treesit-install-language-grammar lang out)
        ;; Report both ABI numbers on success, not just "installed": a grammar built
        ;; against a newer parser ABI than this machine's tree-sitter library supports
        ;; still clones and compiles fine here, but fails silently later at first real
        ;; use --- this line is what would actually show that mismatch.
        (message "Installed %s (parser ABI %s, library supports up to %s)"
                 lang (treesit-language-abi-version lang) (treesit-library-abi-version))))))

;;; install-grammars.el ends here
