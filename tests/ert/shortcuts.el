;;; shortcuts.el --- the shortcuts reference (C-c k) stays accurate  -*- lexical-binding: t; -*-
;; harness: config

(require 'shortcuts (expand-file-name "shortcuts" (or (getenv "CONFIG_DIR") user-emacs-directory)))

(ert-deftest shortcuts/key-is-bound ()
  (should (eq (key-binding (kbd "C-c k")) 'my/shortcuts)))

(ert-deftest shortcuts/every-listed-key-really-runs-the-command-it-claims ()
  ;; Catches bit-rot directly: if a key gets rebound elsewhere, or a command is
  ;; renamed, this fails instead of the buffer silently showing a stale shortcut.
  ;; Commands only present when an optional package is installed (Magit, Consult,
  ;; gptel, Treemacs) are skipped rather than failed, matching how the rest of this
  ;; config treats those packages as optional.
  (let ((optional '(magit-status magit-file-dispatch consult-line consult-ripgrep
                    consult-fd consult-buffer gptel-menu my/llm-chat my/treemacs
                    my/treemacs-reveal)))
    (dolist (topic my/shortcuts-list)
      (dolist (row (cdr topic))
        (cl-destructuring-bind (key command _desc) row
          (if (memq command optional)
              (when (fboundp command)
                (should (eq (key-binding (kbd key)) command)))
            (should (eq (key-binding (kbd key)) command))))))))

(ert-deftest shortcuts/every-key-is-unique ()
  (let ((keys (cl-loop for topic in my/shortcuts-list
                       append (mapcar #'car (cdr topic)))))
    (should (= (length keys) (length (delete-dups (copy-sequence keys)))))))

(ert-deftest shortcuts/buffer-is-read-only-and-foldable ()
  (with-current-buffer (my/shortcuts-buffer)
    (should buffer-read-only)
    (should (derived-mode-p 'outline-mode))
    (should-error (let ((buffer-read-only t)) (insert "x")) :type 'buffer-read-only)
    (should (string-match-p "Finding files" (buffer-string)))
    (should (string-match-p "LLM chat" (buffer-string)))))

(ert-deftest shortcuts/shows-every-topic-and-description ()
  (let ((txt (with-current-buffer (my/shortcuts-buffer) (buffer-string))))
    (dolist (topic my/shortcuts-list)
      (should (string-match-p (regexp-quote (car topic)) txt))
      (dolist (row (cdr topic))
        (should (string-match-p (regexp-quote (nth 0 row)) txt))
        (should (string-match-p (regexp-quote (nth 2 row)) txt))))))

;;; Showing it split next to the start screen at startup (a fresh frame is not needed:
;;; this only checks the hook's own decision logic, with the window primitives it would
;;; call recorded rather than actually run).

(defmacro shortcuts--with-recorded-window-calls (&rest body)
  "Run BODY with `split-window', `select-window' and `switch-to-buffer' replaced by
recorders; binds `calls', a list of each call in order, newest first."
  (declare (indent 0))
  `(let (calls)
     (cl-letf (((symbol-function 'split-window)
                (lambda (&rest args) (push (cons 'split-window args) calls) 'other-window))
               ((symbol-function 'select-window)
                (lambda (&rest args) (push (cons 'select-window args) calls) nil))
               ((symbol-function 'switch-to-buffer)
                (lambda (&rest args) (push (cons 'switch-to-buffer args) calls) nil)))
       ,@body
       (setq calls (nreverse calls)))))

(ert-deftest shortcuts/shown-split-next-to-the-start-screen-when-that-is-what-opened ()
  (let ((start-buf (generate-new-buffer "*start*")))
    (unwind-protect
        (cl-letf (((symbol-function 'window-buffer) (lambda (&rest _) start-buf))
                  ((symbol-function 'get-buffer) (lambda (name) (and (equal name "*start*") start-buf)))
                  ((symbol-function 'one-window-p) (lambda (&rest _) t))
                  ((symbol-function 'selected-window) (lambda () 'main-window)))
          (let ((calls (shortcuts--with-recorded-window-calls (my/shortcuts--maybe-show-at-startup))))
            (should (assq 'split-window calls))
            (should (memq 'switch-to-buffer (mapcar #'car calls)))
            ;; ends with the main window selected again, not the new shortcuts window
            (should (equal (car (last calls)) '(select-window main-window)))))
      (kill-buffer start-buf))))

(ert-deftest shortcuts/not-shown-when-a-file-was-given-on-the-command-line ()
  (let ((start-buf (generate-new-buffer "*start*")) (file-buf (generate-new-buffer "some-file.txt")))
    (unwind-protect
        (cl-letf (((symbol-function 'window-buffer) (lambda (&rest _) file-buf))
                  ((symbol-function 'get-buffer) (lambda (name) (and (equal name "*start*") start-buf)))
                  ((symbol-function 'one-window-p) (lambda (&rest _) t)))
          (let ((calls (shortcuts--with-recorded-window-calls (my/shortcuts--maybe-show-at-startup))))
            (should-not calls)))
      (kill-buffer start-buf) (kill-buffer file-buf))))

(ert-deftest shortcuts/not-shown-if-the-window-layout-is-already-split ()
  (let ((start-buf (generate-new-buffer "*start*")))
    (unwind-protect
        (cl-letf (((symbol-function 'window-buffer) (lambda (&rest _) start-buf))
                  ((symbol-function 'get-buffer) (lambda (name) (and (equal name "*start*") start-buf)))
                  ((symbol-function 'one-window-p) (lambda (&rest _) nil)))
          (let ((calls (shortcuts--with-recorded-window-calls (my/shortcuts--maybe-show-at-startup))))
            (should-not calls)))
      (kill-buffer start-buf))))

(ert-deftest shortcuts/does-not-slow-startup ()
  (let ((best most-positive-fixnum))
    (dotimes (_ 3)
      (let ((t0 (float-time)))
        (call-process test-emacs nil nil nil "--batch" "--init-directory" (getenv "CONFIG_DIR")
                      "-l" (expand-file-name "early-init.el" (getenv "CONFIG_DIR"))
                      "-l" (expand-file-name "init.el" (getenv "CONFIG_DIR"))
                      "--eval" "(kill-emacs)")
        (setq best (min best (- (float-time) t0)))))
    (should (< best 0.5))))

;;; shortcuts.el ends here
