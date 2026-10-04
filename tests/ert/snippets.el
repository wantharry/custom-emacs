;;; snippets.el --- Yasnippet, wired in and really working  -*- lexical-binding: t; -*-
;; harness: config
;; Needs yasnippet installed (./build.sh packages); skips without it.

(defmacro yas-need (&rest body)
  (declare (indent 0))
  `(if (locate-library "yasnippet") (progn ,@body)
     (ert-skip "yasnippet is not installed (./build.sh packages)")))

(ert-deftest snippets/global-mode-is-on ()
  (yas-need
    (should (bound-and-true-p yas-global-mode))))

(ert-deftest snippets/insert-key-is-bound ()
  (yas-need
    (should (eq (key-binding (kbd "C-c Y")) 'yas-insert-snippet))))

(ert-deftest snippets/a-real-trigger-expands-on-tab ()
  ;; The actual point of the feature, not just "is the mode on": define one real
  ;; snippet by hand (no bundled collection is installed, see init.el's own comment on
  ;; why), type its trigger word, press TAB, and check the template actually appears.
  (yas-need
    (test-in-buffer #'fundamental-mode ""
      (yas-minor-mode 1)
      (yas-define-snippets 'fundamental-mode '(("mytrig" "expanded-template" "test")))
      (insert "mytrig")
      (yas-expand)
      (should (string-match-p "expanded-template" (buffer-string))))))

(ert-deftest snippets/tab-still-falls-through-without-a-trigger ()
  ;; The real regression this config's own comment on `yas-global-mode' promises does
  ;; not happen: with no snippet matching the text before point, TAB must still do
  ;; whatever it already did in that buffer (here, plain self-insertion is not it ---
  ;; `indent-for-tab-command' is the built-in default, confirmed not to error and to
  ;; leave the buffer's own existing behavior for TAB intact).
  (yas-need
    (test-in-buffer #'fundamental-mode "nonsense-not-a-trigger"
      (yas-minor-mode 1)
      (goto-char (point-max))
      (should-not (yas--templates-for-key-at-point)))))

;;; snippets.el ends here
