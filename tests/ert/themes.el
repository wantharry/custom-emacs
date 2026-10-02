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
  ;; echo area.
  (unwind-protect
      (let (captured)
        (my/load-theme-by-number ?1)
        (cl-letf (((symbol-function 'message)
                   (lambda (fmt &rest args) (setq captured (apply #'format fmt args)))))
          (my/load-theme-by-number ?9))   ; nothing mapped to 9
        (should-not custom-enabled-themes)   ; disabled (all themes cleared first), not left stale
        (should (string-match-p "No theme bound to 9" captured)))
    (mapc #'disable-theme custom-enabled-themes)))

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
