;;; perspective.el --- the optional perspective (named buffer/window groups) toggle  -*- lexical-binding: t; -*-
;; harness: config
;; Needs `perspective' installed in config/elpa (./build.sh packages).

(defmacro persp-test-with-clean-state (&rest body)
  "Run BODY, then make sure `persp-mode' is switched off again."
  (declare (indent 0))
  `(progn
     (skip-unless (locate-library "perspective"))
     (unwind-protect (progn ,@body)
       (when (bound-and-true-p persp-mode) (persp-mode -1)))))

(ert-deftest perspective/toggle-command-is-bound-to-c-c-cap-p ()
  (should (commandp 'my/toggle-perspective))
  (should (eq (key-binding (kbd "C-c P")) 'my/toggle-perspective)))

(ert-deftest perspective/prefix-key-is-c-x-x ()
  (should (equal persp-mode-prefix-key (kbd "C-x x"))))

(ert-deftest perspective/toggling-on-enables-persp-mode ()
  (persp-test-with-clean-state
    (should-not (bound-and-true-p persp-mode))
    (my/toggle-perspective)
    (should persp-mode)))

(ert-deftest perspective/toggling-off-disables-persp-mode ()
  (persp-test-with-clean-state
    (my/toggle-perspective)
    (my/toggle-perspective)
    (should-not persp-mode)))

(ert-deftest perspective/toggle-cycle-is-repeatable ()
  (persp-test-with-clean-state
    (dotimes (_ 3)
      (my/toggle-perspective) (should persp-mode)
      (my/toggle-perspective) (should-not persp-mode))))

;; real, confirmed-live finding (not assumed): `C-x x' is ALSO a real, stock Emacs
;; 28+ prefix of its own (`rename-buffer', `toggle-truncate-lines', ...) --- once
;; `persp-mode' is on, `perspective' must layer ITS OWN commands on top of that,
;; not silently break the stock ones it does not itself define.
(ert-deftest perspective/c-x-x-prefix-reaches-perspective-commands-once-on ()
  (persp-test-with-clean-state
    (my/toggle-perspective)
    (should (eq (key-binding (kbd "C-x x s")) 'persp-switch))
    (should (eq (key-binding (kbd "C-x x r")) 'persp-rename))
    (should (eq (key-binding (kbd "C-x x c")) 'persp-kill))))

(ert-deftest perspective/stock-c-x-x-commands-survive-while-on ()
  (persp-test-with-clean-state
    (my/toggle-perspective)
    ;; `perspective' does not define its own `t' or `i' commands, so these must
    ;; still fall through to the real, stock Emacs 28+ `C-x x' prefix.
    (should (eq (key-binding (kbd "C-x x t")) 'toggle-truncate-lines))
    (should (eq (key-binding (kbd "C-x x i")) 'persp-import))))

(ert-deftest perspective/mode-line-shows-the-current-perspective-once-on ()
  (persp-test-with-clean-state
    (should-not (member '(:eval (persp-mode-line)) global-mode-string))
    (my/toggle-perspective)
    (should (member '(:eval (persp-mode-line)) global-mode-string))))

(ert-deftest perspective/switching-actually-changes-the-current-perspective ()
  (persp-test-with-clean-state
    (my/toggle-perspective)
    (should (equal (persp-current-name) persp-initial-frame-name))
    (persp-switch "a-test-perspective")
    (should (equal (persp-current-name) "a-test-perspective"))))

(ert-deftest perspective/toggling-again-does-not-reload-the-package ()
  (persp-test-with-clean-state
    (my/toggle-perspective) (my/toggle-perspective)
    (let ((count (length features)))
      (my/toggle-perspective) (my/toggle-perspective)
      (should (= count (length features))))))

;;; perspective.el ends here
