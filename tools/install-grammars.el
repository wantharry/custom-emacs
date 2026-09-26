;;; install-grammars.el --- build the tree-sitter grammars we use  -*- lexical-binding: t; -*-
;; Usage: ./build.sh grammars      (needs network, git and a C compiler)
;; Installs into config/tree-sitter/.  Versions come from `treesit-language-source-alist'
;; in config/init.el, which pins ones compatible with our tree-sitter library.

(load (expand-file-name "init.el" user-emacs-directory) nil t)
(require 'treesit)

(let ((out (expand-file-name "tree-sitter" user-emacs-directory)))
  (make-directory out t)
  (dolist (entry treesit-language-source-alist)
    (let ((lang (car entry)))
      (if (treesit-language-available-p lang)
          (message "Grammar already installed: %s" lang)
        (message "Installing grammar: %s" lang)
        (treesit-install-language-grammar lang out)
        (message "Installed %s (parser ABI %s, library supports up to %s)"
                 lang (treesit-language-abi-version lang) (treesit-library-abi-version))))))

;;; install-grammars.el ends here
