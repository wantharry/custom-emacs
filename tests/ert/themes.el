;;; themes.el --- pick a color theme by number (C-c c), no stacking  -*- lexical-binding: t; -*-
;; harness: config

(ert-deftest themes/key-is-bound ()
  (should (eq (key-binding (kbd "C-c c")) 'my/load-theme-by-number)))

(ert-deftest themes/every-mapped-theme-is-real-and-loadable ()
  ;; Catches a typo'd or removed theme symbol in `my/themes' directly, rather than only
  ;; finding out the hard way when someone actually presses that number. `load-theme'
  ;; with NO-ENABLE=t is the real, idiomatic check (not hand-rolling `locate-file'
  ;; against `custom-theme-load-path', which holds the special sentinel `t' for
  ;; `custom-theme-directory' among its entries, not just plain directory strings) ---
  ;; it loads/registers the theme's definition without actually switching to it.
  (dolist (entry my/themes)
    (let ((theme (cdr entry)))
      (ert-info ((format "theme %s (key %c)" theme (car entry)))
        (should (load-theme theme t t))))))

(ert-deftest themes/switching-never-stacks-two-themes ()
  (unwind-protect
      (progn
        (my/load-theme-by-number ?1)
        (should (equal custom-enabled-themes (list (alist-get ?1 my/themes))))
        (my/load-theme-by-number ?5)
        ;; Exactly the one just switched to --- not both 1 and 5 active together.
        (should (equal custom-enabled-themes (list (alist-get ?5 my/themes)))))
    (mapc #'disable-theme custom-enabled-themes)))

(ert-deftest themes/zero-disables-everything ()
  (unwind-protect
      (progn
        (my/load-theme-by-number ?1)
        (should custom-enabled-themes)
        (my/load-theme-by-number ?0)
        (should-not custom-enabled-themes))
    (mapc #'disable-theme custom-enabled-themes)))

(ert-deftest themes/an-unbound-number-changes-nothing-and-says-so ()
  ;; `current-message' is not reliable to read back in a batch ERT run, so the message
  ;; itself is captured directly by temporarily replacing `message', not by polling the
  ;; echo area. `U' (not `9') is the genuinely unbound character now that `my/themes'
  ;; uses digits 1-9, lowercase a-z and uppercase A-T (55 entries) --- see the WHAT/WHY
  ;; comment above `my/themes' in config/init.el.
  (should-not (alist-get ?U my/themes))
  (unwind-protect
      (let (captured)
        (my/load-theme-by-number ?1)
        (cl-letf (((symbol-function 'message)
                   (lambda (fmt &rest args) (setq captured (apply #'format fmt args)))))
          (my/load-theme-by-number ?U))   ; nothing mapped to U
        (should-not custom-enabled-themes)   ; disabled (all themes cleared first), not left stale
        (should (string-match-p "No theme bound to U" captured)))
    (mapc #'disable-theme custom-enabled-themes)))

(ert-deftest themes/custom-theme-load-path-includes-every-elpa-package-dir ()
  ;; Pins down a real bug found while wiring up the 47 non-Modus themes: `load-theme'
  ;; never consults `load-path' --- it always does its own `locate-file' search through
  ;; `custom-theme-load-path', whose `t' entry expands to Emacs's *built-in* themes
  ;; directory, never to `load-path'. A theme package can `require' fine while still
  ;; being entirely invisible to `load-theme'/`consult-theme' unless its directory is
  ;; *also* on `custom-theme-load-path' --- confirmed directly: every one of the 47
  ;; non-Modus entries in `my/themes' failed with "Unable to find theme file" before
  ;; this fix, despite `locate-library' finding each one without any trouble.
  (dolist (dir (file-expand-wildcards (expand-file-name "*" my/elpa-dir)))
    (when (and (file-directory-p dir)
               (not (member (file-name-nondirectory dir) '("archives" "gnupg"))))
      (ert-info ((format "dir %s" dir))
        (should (member dir custom-theme-load-path))))))

(ert-deftest themes/cycle-theme-steps-forward-and-wraps-around ()
  (unwind-protect
      (progn
        (mapc #'disable-theme custom-enabled-themes)
        (my/load-theme-by-number ?1)
        (my/cycle-theme)
        (should (equal custom-enabled-themes (list (alist-get ?2 my/themes))))
        ;; From the very last theme, the next one wraps back to the first.
        (mapc #'disable-theme custom-enabled-themes)
        (load-theme (cdr (car (last my/themes))) t)
        (my/cycle-theme)
        (should (equal custom-enabled-themes (list (cdr (car my/themes))))))
    (mapc #'disable-theme custom-enabled-themes)))

(ert-deftest themes/cycle-theme-previous-steps-backward-and-wraps-around ()
  (unwind-protect
      (progn
        (mapc #'disable-theme custom-enabled-themes)
        (my/load-theme-by-number ?2)
        (my/cycle-theme-previous)
        (should (equal custom-enabled-themes (list (alist-get ?1 my/themes))))
        ;; From the very first theme, the previous one wraps around to the last.
        (my/cycle-theme-previous)
        (should (equal custom-enabled-themes (list (cdr (car (last my/themes)))))))
    (mapc #'disable-theme custom-enabled-themes)))

(ert-deftest themes/cycle-theme-from-no-active-theme-starts-at-the-first-one ()
  (unwind-protect
      (progn
        (mapc #'disable-theme custom-enabled-themes)
        (my/cycle-theme)
        (should (equal custom-enabled-themes (list (cdr (car my/themes))))))
    (mapc #'disable-theme custom-enabled-themes)))

(ert-deftest themes/cycle-keys-are-bound ()
  (should (eq (key-binding (kbd "C-c .")) 'my/cycle-theme))
  (should (eq (key-binding (kbd "C-c ,")) 'my/cycle-theme-previous)))

(ert-deftest themes/consult-theme-key-is-bound-when-consult-is-installed ()
  (if (locate-library "consult")
      (should (eq (key-binding (kbd "C-c C")) 'consult-theme))
    (should (eq (key-binding (kbd "C-c C")) 'my/consult-missing))))

(ert-deftest themes/cursor-stays-visible-regardless-of-the-active-theme ()
  ;; A real, found-by-using-it problem: several of the 55 themes in `my/themes' don't
  ;; give enough contrast between their own `cursor' face and their own `hl-line' face
  ;; (`global-hl-line-mode' is on), so the actual insertion point can disappear into
  ;; the highlighted current line. `enable-theme-functions' (built into Emacs 29+) is
  ;; the one hook point that runs after any theme is enabled, through every entry point
  ;; here (`C-c c', `C-c .'/`C-c ,', `C-c C', `theme-buffet', or Emacs's own startup).
  (unwind-protect
      (progn
        (my/load-theme-by-number ?3)   ; solo-jazz: a theme where this was visibly wrong
        (should (equal (face-attribute 'cursor :background) "DarkOrange"))
        ;; `C-c c 0' disables every theme rather than enabling one, so it does not run
        ;; `enable-theme-functions' on its own --- `my/load-theme-by-number' must call
        ;; `my/ensure-visible-cursor' directly for this case.
        (my/load-theme-by-number ?0)
        (should (equal (face-attribute 'cursor :background) "DarkOrange")))
    (mapc #'disable-theme custom-enabled-themes)))

(ert-deftest themes/missing-lexical-binding-cookie-warning-is-suppressed ()
  ;; Several of the 15 theme packages (`rebecca-theme', `night-owl-theme', `seti-theme')
  ;; are old enough to never declare `lexical-binding: t' on their first line --- the
  ;; theme still loads and works correctly either way (`lexical-binding' only affects
  ;; how that file's own code captures variables), but Emacs otherwise warns loudly
  ;; about it every single time the theme is actually switched to, not just once.
  (should (member '(files missing-lexbind-cookie) warning-suppress-log-types)))

(ert-deftest themes/does-not-slow-startup ()
  (let ((best most-positive-fixnum))
    (dotimes (_ 3)
      (let ((t0 (float-time)))
        (call-process test-emacs nil nil nil "--batch" "--init-directory" (getenv "CONFIG_DIR")
                      "-l" (expand-file-name "early-init.el" (getenv "CONFIG_DIR"))
                      "-l" (expand-file-name "init.el" (getenv "CONFIG_DIR")) "--eval" "(kill-emacs)")
        (setq best (min best (- (float-time) t0)))))
    (should (< best 0.5))))

;;; theme-buffet: automatic light/dark switching through the day

(ert-deftest themes/theme-buffet-is-in-the-package-list ()
  (with-temp-buffer
    (insert-file-contents (expand-file-name "tools/install-packages.el" test-root))
    (should (re-search-forward "(defconst my/packages '([^)]*\\btheme-buffet\\b" nil t))))

(ert-deftest themes/theme-buffet-light-and-dark-lists-only-hold-real-mapped-themes ()
  ;; Every theme in `my/themes-light'/`-dark' must also be one of `my/themes''s own
  ;; values --- catches the two lists drifting apart (a theme removed from `my/themes'
  ;; but left behind here, or a typo) directly, rather than only at buffet-switch time.
  (unless (locate-library "theme-buffet") (ert-skip "theme-buffet is not installed"))
  (let ((mapped (mapcar #'cdr my/themes)))
    (dolist (theme (append my/themes-light my/themes-dark))
      (ert-info ((format "theme %s" theme))
        (should (memq theme mapped))))))

(ert-deftest themes/theme-buffet-is-configured-with-our-light-and-dark-lists ()
  (unless (locate-library "theme-buffet") (ert-skip "theme-buffet is not installed"))
  (require 'theme-buffet)
  (should (eq theme-buffet-menu 'end-user))
  (should (equal (plist-get theme-buffet-end-user :morning) my/themes-light))
  (should (equal (plist-get theme-buffet-end-user :afternoon) my/themes-light))
  (should (equal (plist-get theme-buffet-end-user :evening) my/themes-dark))
  (should (equal (plist-get theme-buffet-end-user :night) my/themes-dark)))

(ert-deftest themes/theme-buffet-applies-a-theme-and-starts-its-timer-at-startup ()
  ;; Real, fresh subprocess: confirms the effect of the actual startup wiring (`theme-
  ;; buffet-a-la-carte' + `theme-buffet-timer-hours' in init.el), not just that the
  ;; functions exist.
  (unless (locate-library "theme-buffet") (ert-skip "theme-buffet is not installed"))
  (let ((out (with-output-to-string
               (with-current-buffer standard-output
                 (call-process test-emacs nil t nil "--batch" "--init-directory" (getenv "CONFIG_DIR")
                               "-l" (expand-file-name "early-init.el" (getenv "CONFIG_DIR"))
                               "-l" (expand-file-name "init.el" (getenv "CONFIG_DIR"))
                               "--eval" "(princ (list (and custom-enabled-themes t) (and theme-buffet-timer-hours t)))")))))
    (should (string-match-p "(t t)" out))))

;;; themes.el ends here
