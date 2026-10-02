;;; install-packages.el --- install the packages we chose into config/elpa  -*- lexical-binding: t; -*-
;; Usage: ./build.sh packages
;; (emacs --batch --init-directory=config -l tools/install-packages.el)
;; Needs network.

(require 'package)
(setq package-user-dir (expand-file-name "elpa" user-emacs-directory)
      package-archives '(("gnu"    . "https://elpa.gnu.org/packages/")
                         ("nongnu" . "https://elpa.nongnu.org/nongnu/")
                         ;; Treemacs is only published here
                         ("melpa"  . "https://melpa.org/packages/")))
(package-initialize)

(defconst my/packages '(evil magit treemacs consult gptel
                        vertico orderless marginalia embark embark-consult
                        avy ace-window wgrep helpful symbol-overlay magit-delta theme-buffet)
  "Packages this configuration uses.  Everything else is built in.
`avy'/`ace-window' were already on disk as Treemacs's own dependencies before they were
first bound to a key here --- listed explicitly now that they are actually used, so
they stay installed even if Treemacs ever stops needing them itself.")

(let ((missing (seq-remove #'package-installed-p my/packages)))
  (if (null missing)
      (message "All packages already installed: %S" my/packages)
    (package-refresh-contents)
    (dolist (p missing)
      (package-install p)
      (message "Installed %s" p))))

;;; install-packages.el ends here
