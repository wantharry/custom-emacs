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
                    consult-fd consult-buffer gptel-menu my/llm-chat my/llm-council
                    my/treemacs my/treemacs-reveal
                    embark-act embark-dwim embark-bindings)))
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

;;; The packages section: open/close/commands text is shown, and the underlying real
;;; facts (checked against the actual keymaps, not just recited) are what they claim.

(ert-deftest shortcuts/packages-buffer-shows-every-entry ()
  (let ((txt (with-current-buffer (my/shortcuts-buffer) (buffer-string))))
    (dolist (pkg my/shortcuts-packages)
      (cl-destructuring-bind (name open close commands) pkg
        (should (string-match-p (regexp-quote name) txt))
        (should (string-match-p (regexp-quote open) txt))
        (should (string-match-p (regexp-quote close) txt))
        (dolist (c commands)
          (should (string-match-p (regexp-quote (car c)) txt))
          (should (string-match-p (regexp-quote (cdr c)) txt)))))))

(ert-deftest shortcuts/magit-facts-are-real ()
  (skip-unless (locate-library "magit"))
  (require 'magit)
  ;; close, and section navigation (magit-mode-map / magit-section-mode-map)
  (should (eq (lookup-key magit-mode-map (kbd "q")) 'magit-mode-bury-buffer))
  (should (eq (lookup-key magit-section-mode-map (kbd "TAB")) 'magit-section-toggle))
  (should (eq (lookup-key magit-mode-map (kbd "RET")) 'magit-visit-thing))
  ;; the transient-based ones the flat text can't express: "c c", "P p", "F p", "l l".
  ;; Before a transient is ever entered interactively, `transient-get-suffix' hands back
  ;; a plain (transient-suffix :key ... :command ...) list, not a real EIEIO object yet
  ;; (confirmed for real: `type-of' on it is `cons', and `oref'/`slot-value' both refuse
  ;; it) --- so pull `:command' out with `plist-get', not an object accessor.
  (dolist (spec '((magit-commit "c" magit-commit-create)
                  (magit-push "p" magit-push-current-to-pushremote)
                  (magit-pull "p" magit-pull-from-pushremote)
                  (magit-log "l" magit-log-current)))
    (should (eq (plist-get (cdr (transient-get-suffix (nth 0 spec) (nth 1 spec))) :command)
                (nth 2 spec)))))

(ert-deftest shortcuts/treemacs-facts-are-real ()
  (skip-unless (locate-library "treemacs"))
  (require 'treemacs)
  (should (eq (lookup-key treemacs-mode-map "q") 'treemacs-quit))
  (should (eq (lookup-key treemacs-mode-map "Q") 'treemacs-kill-buffer))
  (should (eq (lookup-key treemacs-mode-map (kbd "RET")) 'treemacs-RET-action))
  (should (eq (lookup-key treemacs-mode-map "cf") 'treemacs-create-file))
  (should (eq (lookup-key treemacs-mode-map "cd") 'treemacs-create-dir))
  (should (eq (lookup-key treemacs-mode-map "d") 'treemacs-delete-file))
  (should (eq (lookup-key treemacs-mode-map "R") 'treemacs-rename-file))
  (should (eq (lookup-key treemacs-mode-map "g") 'treemacs-refresh))
  (should (eq (lookup-key treemacs-mode-map "r") 'treemacs-refresh)))

(ert-deftest shortcuts/gptel-send-key-is-real ()
  (skip-unless (locate-library "gptel"))
  (require 'gptel)
  (should (eq (lookup-key gptel-mode-map (kbd "C-c RET")) 'gptel-send)))

(ert-deftest shortcuts/newsticker-facts-are-real ()
  ;; Built into Emacs itself, not an optional package: no skip needed.
  (require 'newst-treeview)
  (should (eq (lookup-key newsticker-treeview-mode-map "q") 'newsticker-treeview-quit))
  (should (eq (lookup-key newsticker-treeview-mode-map "n") 'newsticker-treeview-next-item))
  (should (eq (lookup-key newsticker-treeview-mode-map "p") 'newsticker-treeview-prev-item))
  (should (eq (lookup-key newsticker-treeview-mode-map "o") 'newsticker-treeview-mark-item-old))
  (should (eq (lookup-key newsticker-treeview-mode-map "g") 'newsticker-treeview-get-news))
  (should (eq (lookup-key newsticker-treeview-mode-map "G") 'newsticker-get-all-news)))

(ert-deftest shortcuts/docs-buffer-close-and-fold-keys-are-real ()
  (let ((my/docs-root test-root))
    (with-current-buffer (my/docs-rebuild)
      (should (eq (key-binding (kbd "q")) 'quit-window))
      (should (eq (key-binding (kbd "C-c C-n")) 'outline-next-visible-heading))
      (should (eq (key-binding (kbd "C-c C-p")) 'outline-previous-visible-heading)))))

(ert-deftest shortcuts/shortcuts-buffer-close-and-fold-keys-are-real ()
  (with-current-buffer (my/shortcuts-buffer)
    (should (eq (key-binding (kbd "q")) 'quit-window))
    ;; `TAB' only folds on a heading line (outline-mode-map's own menu-item filter);
    ;; point-min here is the title text, not a heading, so move to one first.
    (goto-char (point-min))
    (search-forward "* ")
    (beginning-of-line)
    (should (eq (key-binding (kbd "TAB")) 'outline-cycle))))

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
