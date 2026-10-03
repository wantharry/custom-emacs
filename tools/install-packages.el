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
                        avy ace-window wgrep helpful symbol-overlay magit-delta theme-buffet atom-one-dark-theme catppuccin-theme solo-jazz-theme nimbus-theme rebecca-theme subatomic-theme night-owl-theme shanty-themes snazzy-theme horizon-theme immaterial-theme zenburn-theme solarized-theme dracula-theme kaolin-themes
                        casual csv-mode)
  "Packages this configuration uses.  Everything else is built in.
`avy'/`ace-window' were already on disk as Treemacs's own dependencies before they were
first bound to a key here --- listed explicitly now that they are actually used, so
they stay installed even if Treemacs ever stops needing them itself.
`transient' (what `casual' and Magit are both built on) is NOT listed here --- it is
built into Emacs itself now, confirmed directly (`emacs-src/lisp/transient.el'), the
same way `which-key' turned out to be. `csv-mode' is `casual''s own real dependency (its
`casual-dired-sort-by.el' module uses it), not something this config needs on its own.")

(let ((missing (seq-remove #'package-installed-p my/packages)))
  (if (null missing)
      (message "All packages already installed: %S" my/packages)
    (package-refresh-contents)
    (dolist (p missing)
      (package-install p)
      (message "Installed %s" p))))

;; WHAT: packages not published on any of the archives above (`gnu'/`nongnu'/`melpa'),
;; installed straight from their own git repository instead. WHY: each of these (color
;; themes, see `my/themes' in init.el) was checked directly against all three archives
;; (confirmed 404 on each) and genuinely isn't on any of them --- not a lookup mistake.
;; HOW: `package-vc-install', Emacs's own built-in mechanism for this exact case
;; (`package-vc' ships with Emacs 29+); each entry is (NAME . URL).
;; `package-installed-p' is deliberately NOT used to check whether one is already
;; installed, unlike `my/packages' above --- confirmed directly, the hard way: it
;; relies on `package-alist'/`package-vc-selected-packages', and the latter is normally
;; persisted to the user's `custom-file', which this config deliberately has none of (no
;; personal `custom.el' --- see docs/CUSTOMIZING.md); so in a fresh batch process
;; `package-installed-p' always said "not installed" here, even right after a real,
;; successful clone, and `package-vc-install' would then try to `git clone' into the
;; same now-non-empty directory and fail. Checking the directory itself exists instead
;; is what every other part of this config already does for `config/elpa' anyway (see
;; `init.el''s own `load-path' loop), so this matches that, not `package-installed-p'.
;; `ember-theme' additionally needs `doom-themes' (a hard `require' in its own source)
;; --- NOT added to `my/packages' above on purpose: this project's own
;; `startup/no-third-party-features-loaded' test (tests/ert/startup-perf.el) asserts
;; `doom-themes' never loads automatically, so `ember' is wired into `my/themes' as a
;; manually-selectable theme only, deliberately left out of `theme-buffet''s light/dark
;; rotation lists in init.el (loading it there would load `doom-themes' at every
;; automatic rotation, silently, at startup or on the hourly recheck).
(require 'package-vc)
(defconst my/vc-packages
  '((seti-theme . "https://github.com/caisah/seti-theme.git")
    (xcode-theme . "https://github.com/juniorxxue/xcode-theme.git")
    (ember-theme . "https://github.com/ember-theme/emacs.git"))
  "Packages not on any configured archive, installed directly from their own git
repository with `package-vc-install'.  Each entry is (NAME . URL).")
(dolist (entry my/vc-packages)
  (let ((dir (expand-file-name (symbol-name (car entry)) package-user-dir)))
    (unless (file-directory-p dir)
      ;; `package-vc-install' is (PACKAGE &optional REV BACKEND NAME) --- NAME is the
      ;; 4th argument, not the 2nd; passing it positionally as REV instead (a symbol,
      ;; not a revision string) makes the underlying `git checkout' call crash with
      ;; "Wrong type argument: stringp" the moment a fresh clone is actually attempted.
      (package-vc-install (cdr entry) nil nil (car entry))
      (message "Installed %s (via VC)" (car entry)))))

;;; install-packages.el ends here
