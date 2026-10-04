;;; install-packages.el --- install the packages we chose into config/elpa  -*- lexical-binding: t; -*-
;; Usage: ./build.sh packages
;; (emacs --batch --init-directory=config -l tools/install-packages.el)
;; Needs network.

(require 'package)
;; `package-user-dir' points into this config's own `config/elpa' (what `my/elpa-dir' in
;; init.el also points at), not the Emacs default of `~/.emacs.d/elpa' --- so everything
;; this script installs stays inside this project, gitignored, instead of leaking into
;; wherever else Emacs happens to be run on this machine.
(setq package-user-dir (expand-file-name "elpa" user-emacs-directory)
      package-archives '(("gnu"    . "https://elpa.gnu.org/packages/")
                         ("nongnu" . "https://elpa.nongnu.org/nongnu/")
                         ;; Treemacs is only published here
                         ("melpa"  . "https://melpa.org/packages/")))
(package-initialize)

(defconst my/packages '(evil magit treemacs consult gptel
                        vertico orderless marginalia embark embark-consult
                        avy ace-window wgrep helpful symbol-overlay magit-delta theme-buffet atom-one-dark-theme catppuccin-theme solo-jazz-theme nimbus-theme rebecca-theme subatomic-theme night-owl-theme shanty-themes snazzy-theme horizon-theme immaterial-theme zenburn-theme solarized-theme dracula-theme kaolin-themes
                        casual csv-mode
                        corfu yasnippet expand-region diff-hl vterm pdf-tools
                        ranger
                        docker dockerfile-mode kubernetes)
  "Packages this configuration uses.  Everything else is built in.
`avy'/`ace-window' were already on disk as Treemacs's own dependencies before they were
first bound to a key here --- listed explicitly now that they are actually used, so
they stay installed even if Treemacs ever stops needing them itself.
`transient' (what `casual' and Magit are both built on) is NOT listed here --- it is
built into Emacs itself now, confirmed directly (`emacs-src/lisp/transient.el'), the
same way `which-key' turned out to be. `csv-mode' is `casual''s own real dependency (its
`casual-dired-sort-by.el' module uses it), not something this config needs on its own.
`corfu-terminal' (a real NonGNU ELPA package, Corfu's own documented fix for its popup
being a child frame that does not exist in older terminal Emacs) was tried and then
deliberately left back out again --- confirmed directly, by actually watching a real
completion popup render in a real `-nw' terminal session without it: this project's
own Emacs (32.0.50) already has native tty-child-frame support, and Corfu's own source
(`corfu.el') detects exactly this and warns `corfu-terminal' is not needed at all on
Emacs 31+, so installing it here would only add a package and a startup warning for no
real benefit. `vterm' and `pdf-tools' each need a native helper compiled from C at
first real use (`vterm-module.so' via `cmake', `epdfinfo' via `make') --- `vterm'
confirmed to vendor/fetch its own copy of `libvterm' automatically when no system copy
is found (confirmed directly in its own `CMakeLists.txt'), so nothing extra was needed
for it; `pdf-tools' genuinely needs one real system package (`libpoppler-glib-dev')
this build process cannot install for itself (confirmed missing here, see init.el's own
comment on `pdf-loader-install' for how that gap is handled without a regression).
`compat' (`consult''s own declared dependency, confirmed in `consult-pkg.el' ---
found while looking into a DIFFERENT package, `dirvish', that also declared it, then
turned out not to be the right fit; see `ranger' below) is deliberately NOT listed
here --- tried first, then checked directly with `locate-library' rather than
assumed: it is already bundled INTO this Emacs build itself (`lisp/emacs-lisp/
compat.elc'), so `package-installed-p' already reports it present with nothing in
`config/elpa' at all, and adding it here would just install a second, redundant copy.
`ranger' is a real ranger-style file manager, bound to its own separate key (`C-c R',
see init.el's own, much longer comment for the full account of why `dirvish' was
tried and rejected first) rather than replacing plain Dired --- a real, explicit user
requirement, not a default choice.
`docker' is a Magit-style transient UI for containers/images/volumes/networks
(list, start/stop/rm, logs, exec, and TRAMP file browsing into a running container);
`dockerfile-mode' is a plain major mode (syntax highlighting/indentation, a one-key
build-from-buffer command) for this project's own `Dockerfile'. `docker-compose-mode'
is NOT listed here --- checked directly, not assumed: it is not published on any of
the three archives above any more (confirmed 404/\"unavailable\" on all three), and is
redundant anyway --- `docker' itself already bundles its own `docker-compose.el'
module (confirmed directly in its own source), with compose support built into the
same transient UI, not a separate package. `kubernetes' (the real MELPA package name;
its own menu/command calls itself `kubernetes-overview') is the same Magit-style idea
one layer up, for a Kubernetes cluster rather than plain Docker --- unrelated to this
repo's own `Dockerfile', included only because the user asked for everything in the
family.
`docker'/`kubernetes' share a real, genuinely new dependency, `tablist' --- the first
package this project has ever installed that hard-requires part of CEDET/Semantic
(`semantic/wisent/comp.el', for `tablist-filter''s on-the-fly filter-expression
grammar) at its own top level, confirmed directly by actually trying to `require' it
and getting a real \"Cannot open load file\" error --- `prune.list' (project root) has
the full account of the fix, a single explicit keep added there.")

;; `package-refresh-contents' (one network fetch of every archive's index) only runs
;; when something is actually missing --- re-running this script on an already-complete
;; install does no network access at all, not even to check for updates.
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
