;;; evil.el --- the optional Evil (vi keys) toggle  -*- lexical-binding: t; -*-
;; harness: config
;; Needs Evil installed in config/elpa (./build.sh packages).

(defmacro evil-test-with-clean-state (&rest body)
  "Run BODY, then make sure Evil is switched off again."
  (declare (indent 0))
  `(progn
     (skip-unless (locate-library "evil"))
     (unwind-protect (progn ,@body)
       (when (bound-and-true-p evil-mode) (evil-mode -1)))))

(ert-deftest evil/no-post-command-hook-errors-on-emacs-32 ()
  "Regression: Evil 1.15 needs `evil-mode-buffers', which Emacs 32 dropped."
  (evil-test-with-clean-state
    (should (boundp 'evil-mode-buffers))
    (test-in-buffer #'text-mode "hello world"
      (my/toggle-evil)
      (execute-kbd-macro "w")
      ;; An error here is what Emacs would otherwise swallow, drop the hook
      ;; over, and report as "Error in post-command-hook".
      (should-not (condition-case e (progn (run-hooks 'post-command-hook) nil)
                    (error e))))))

(ert-deftest evil/toggle-command-is-bound-to-c-c-v ()
  (should (commandp 'my/toggle-evil))
  (should (eq (key-binding (kbd "C-c v")) 'my/toggle-evil)))

(ert-deftest evil/enabling-starts-in-normal-state ()
  (evil-test-with-clean-state
    (test-in-buffer #'text-mode "hello"
      (my/toggle-evil)
      (should evil-mode)
      (should evil-local-mode)
      (should (eq evil-state 'normal)))))

(ert-deftest evil/normal-state-remaps-i-to-insert ()
  (evil-test-with-clean-state
    (test-in-buffer #'text-mode "hello"
      (my/toggle-evil)
      (should (eq (key-binding "i") 'evil-insert)))))

(ert-deftest evil/switching-between-states ()
  (evil-test-with-clean-state
    (test-in-buffer #'text-mode "hello"
      (my/toggle-evil)
      (evil-insert-state) (should (eq evil-state 'insert))
      (evil-normal-state) (should (eq evil-state 'normal))
      (evil-visual-state) (should (eq evil-state 'visual)))))

(ert-deftest evil/disabling-restores-plain-emacs-keys ()
  (evil-test-with-clean-state
    (test-in-buffer #'text-mode "hello"
      (should (eq (key-binding "i") 'self-insert-command))
      (my/toggle-evil)
      (my/toggle-evil)
      (should-not evil-mode)
      (should-not evil-local-mode)
      (should (eq (key-binding "i") 'self-insert-command)))))

(ert-deftest evil/toggle-cycle-is-repeatable ()
  (evil-test-with-clean-state
    (test-in-buffer #'text-mode "hello"
      (dotimes (_ 3)
        (my/toggle-evil) (should evil-mode)
        (my/toggle-evil) (should-not evil-mode)))))

(ert-deftest evil/toggling-again-does-not-reload-evil ()
  (evil-test-with-clean-state
    (my/toggle-evil) (my/toggle-evil)
    (let ((count (length features)))
      (my/toggle-evil) (my/toggle-evil)
      (should (= count (length features))))))

(ert-deftest evil/w-moves-to-next-word ()
  (evil-test-with-clean-state
    (test-in-buffer #'text-mode "one two three"
      (my/toggle-evil)
      (execute-kbd-macro "w")
      (should (= (point) 5)))))

(ert-deftest evil/dw-deletes-a-word ()
  (evil-test-with-clean-state
    (test-in-buffer #'text-mode "one two three"
      (my/toggle-evil)
      (execute-kbd-macro "dw")
      (should (equal (buffer-string) "two three")))))

(ert-deftest evil/dd-deletes-a-line-and-yyp-copies-one ()
  (evil-test-with-clean-state
    (test-in-buffer #'text-mode "a\nb\n"
      (my/toggle-evil)
      (execute-kbd-macro "yyp")
      (should (equal (buffer-string) "a\na\nb\n"))
      (execute-kbd-macro "dd")
      (should (equal (buffer-string) "a\nb\n")))))

(ert-deftest evil/typing-in-insert-state ()
  (evil-test-with-clean-state
    (test-in-buffer #'text-mode "world"
      (my/toggle-evil)
      (execute-kbd-macro (kbd "i h i <escape>"))
      (should (equal (buffer-string) "hiworld"))
      (should (eq evil-state 'normal)))))

(ert-deftest evil/c-c-v-still-works-in-normal-state-to-turn-it-off ()
  (evil-test-with-clean-state
    (test-in-buffer #'text-mode "hello"
      (my/toggle-evil)
      (should evil-mode)
      (execute-kbd-macro (kbd "C-c v"))
      (should-not evil-mode))))

(ert-deftest evil/emacs-bindings-survive-while-on ()
  (evil-test-with-clean-state
    (test-in-buffer #'text-mode "hello"
      (my/toggle-evil)
      (should (eq (key-binding (kbd "C-x C-b")) 'ibuffer))
      (should (eq (key-binding (kbd "C-x C-f")) 'find-file))
      (should (eq (key-binding (kbd "M-x")) 'execute-extended-command)))))

(ert-deftest evil/local-mode-affects-only-one-buffer ()
  (evil-test-with-clean-state
    (require 'evil)
    (let ((a (generate-new-buffer "a")) (b (generate-new-buffer "b")))
      (unwind-protect
          (progn (with-current-buffer a (evil-local-mode 1))
                 (should (buffer-local-value 'evil-local-mode a))
                 (should-not (buffer-local-value 'evil-local-mode b)))
        (kill-buffer a) (kill-buffer b)))))

;;; evil.el ends here
