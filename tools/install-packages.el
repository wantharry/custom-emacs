;;; install-packages.el --- install the packages we chose into config/elpa  -*- lexical-binding: t; -*-
;; Usage: ./build.sh packages
;; (emacs --batch --init-directory=config -l tools/install-packages.el)
;; Needs network.

(require 'package)
(setq package-user-dir (expand-file-name "elpa" user-emacs-directory)
      package-archives '(("gnu"    . "https://elpa.gnu.org/packages/")
                         ("nongnu" . "https://elpa.nongnu.org/nongnu/")))
(package-initialize)

(defconst my/packages '(evil)
  "Packages this configuration uses.  Everything else is built in.")

(let ((missing (seq-remove #'package-installed-p my/packages)))
  (if (null missing)
      (message "All packages already installed: %S" my/packages)
    (package-refresh-contents)
    (dolist (p missing)
      (package-install p)
      (message "Installed %s" p))))

;;; install-packages.el ends here
