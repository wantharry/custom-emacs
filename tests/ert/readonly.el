;;; readonly.el --- files open read-only; one typed command allows editing  -*- lexical-binding: t; -*-
;; harness: config

(require 'ibuffer) (require 'dired)

(defmacro ro-with-file (spec &rest body)
  "Bind (VAR) to a file buffer for a temp file NAME with CONTENT, shown in the window.
SPEC is (VAR NAME CONTENT).  The file is opened the normal way, so the read-only
hook runs.  Also binds `ro-file' to the path."
  (declare (indent 1))
  (let ((var (nth 0 spec)) (name (nth 1 spec)) (content (nth 2 spec)))
    `(test-with-temp-dir ro-dir
       (let* ((ro-file (test-write-file (concat ro-dir ,name) ,content))
              (,var (find-file-noselect ro-file))
              (ro-win (selected-window)) (ro-old (window-buffer ro-win)))
         (unwind-protect
             (progn (set-window-buffer ro-win ,var)
                    (with-current-buffer ,var ,@body))
           (set-window-buffer ro-win ro-old)
           (with-current-buffer ,var (set-buffer-modified-p nil))
           (kill-buffer ,var))))))

(ert-deftest readonly/existing-file-opens-read-only ()
  (ro-with-file (b "a.txt" "hello\n")
    (should buffer-read-only)
    (should-error (insert "x") :type 'buffer-read-only)
    (should (equal (buffer-string) "hello\n"))
    (should-not (buffer-modified-p))))

(ert-deftest readonly/every-kind-of-file-opens-read-only ()
  (dolist (name '("a.py" "a.rs" "a.java" "a.el" "a.txt" "a.json" "a.c" "a.js" "Makefile" "noext"))
    (ro-with-file (b name "x\n")
      (should buffer-read-only))))

(ert-deftest readonly/the-file-on-disk-is-never-touched ()
  (ro-with-file (b "a.txt" "original\n")
    (let ((mtime (file-attribute-modification-time (file-attributes ro-file))))
      (ignore-errors (insert "zzz"))
      (ignore-errors (save-buffer))
      (should (equal (test-read-file ro-file) "original\n"))
      (should (equal mtime (file-attribute-modification-time (file-attributes ro-file)))))))

(ert-deftest readonly/a-file-that-does-not-exist-yet-opens-read-only ()
  (test-with-temp-dir d
    (let ((b (find-file-noselect (concat d "new.txt"))))
      (unwind-protect
          (with-current-buffer b
            (should buffer-read-only)
            (should-error (insert "x") :type 'buffer-read-only))
        (kill-buffer b)))))

(ert-deftest readonly/symlinked-files-open-read-only ()
  (test-with-temp-dir d
    (let* ((real (test-write-file (concat d "real.txt") "x")) (link (concat d "link.txt")))
      (condition-case nil (make-symbolic-link real link)
        (file-error (ert-skip "this system will not create symbolic links (Windows needs Developer Mode)")))
      (let ((b (find-file-noselect link)))
        (unwind-protect (should (buffer-local-value 'buffer-read-only b))
          (kill-buffer b))))))

(ert-deftest readonly/reopening-a-file-is-read-only-again ()
  (test-with-temp-dir d
    (let ((f (test-write-file (concat d "a.txt") "x\n")))
      (dotimes (_ 3)
        (let ((b (find-file-noselect f)))
          (unwind-protect
              (with-current-buffer b
                (should buffer-read-only)
                (allow-editing)
                (should-not buffer-read-only))
            (with-current-buffer b (set-buffer-modified-p nil))
            (kill-buffer b)))))))

(ert-deftest readonly/nothing-else-can-make-it-writable-again ()
  ;; Something running before our hook (like version control) tries to unlock it.
  (let ((unlock (lambda () (setq buffer-read-only nil))))
    (add-hook 'find-file-hook unlock 50)
    (unwind-protect
        (ro-with-file (b "a.txt" "x\n") (should buffer-read-only))
      (remove-hook 'find-file-hook unlock))))

;;; The one deliberate way to edit

(ert-deftest readonly/allow-editing-makes-the-buffer-editable ()
  (ro-with-file (b "a.txt" "hello\n")
    (allow-editing)
    (should-not buffer-read-only)
    (goto-char (point-max))
    (insert "world\n")
    (should (equal (buffer-string) "hello\nworld\n"))))

(ert-deftest readonly/edits-reach-the-disk-only-after-saving ()
  (ro-with-file (b "a.txt" "hello\n")
    (allow-editing)
    (insert "X")
    (should (equal (test-read-file ro-file) "hello\n"))
    (save-buffer)
    (should (equal (test-read-file ro-file) "Xhello\n"))))

(ert-deftest readonly/stop-editing-locks-it-again ()
  (ro-with-file (b "a.txt" "hello\n")
    (allow-editing)
    (stop-editing)
    (should buffer-read-only)
    (should-error (insert "x") :type 'buffer-read-only)))

(ert-deftest readonly/stop-editing-warns-about-unsaved-changes ()
  (ro-with-file (b "a.txt" "hello\n")
    (allow-editing)
    (insert "X")
    (let ((msg (let ((inhibit-message t)) (stop-editing) (current-message))))
      (should (string-match-p "UNSAVED" (or (with-current-buffer "*Messages*" (buffer-substring (max (point-min) (- (point-max) 300)) (point-max))) msg))))))

(ert-deftest readonly/allow-editing-when-already-editable-is-harmless ()
  (ro-with-file (b "a.txt" "hello\n")
    (allow-editing)
    (allow-editing)
    (should-not buffer-read-only)))

(ert-deftest readonly/allow-editing-creates-new-files ()
  (test-with-temp-dir d
    (let* ((f (concat d "brand-new.txt")) (b (find-file-noselect f)))
      (unwind-protect
          (with-current-buffer b
            (allow-editing)
            (insert "fresh\n")
            (save-buffer)
            (should (equal (test-read-file f) "fresh\n")))
        (with-current-buffer b (set-buffer-modified-p nil))
        (kill-buffer b)))))

(ert-deftest readonly/allow-editing-is-a-typeable-command ()
  (should (commandp 'allow-editing))
  (should (commandp 'stop-editing))
  (should (commandp 'my/read-only-hint)))

;;; Slips of the fingers must not edit anything

(ert-deftest readonly/c-x-c-q-does-not-enable-editing ()
  (should (eq (key-binding (kbd "C-x C-q")) 'my/read-only-hint))
  (ro-with-file (b "a.txt" "hello\n")
    (execute-kbd-macro (kbd "C-x C-q"))
    (should buffer-read-only)))

(ert-deftest readonly/the-standard-toggle-has-no-other-easy-key ()
  ;; Only the typed commands (or `M-x read-only-mode') can turn editing on.
  (should-not (where-is-internal 'read-only-mode global-map))
  (should-not (where-is-internal 'toggle-read-only global-map)))

(ert-deftest readonly/typing-text-changes-nothing ()
  (ro-with-file (b "a.txt" "hello\n")
    (dolist (keys '("x" "hello world" "RET" "TAB" "DEL"))
      (ignore-errors (execute-kbd-macro (kbd keys))))
    (should (equal (buffer-string) "hello\n"))
    (should-not (buffer-modified-p))))

(ert-deftest readonly/mistyped-editing-shortcuts-change-nothing ()
  ;; Emacs editing keys someone might hit by accident while learning.
  (ro-with-file (b "a.txt" "alpha beta\ngamma delta\n")
    (dolist (keys '("C-k" "C-y" "M-d" "C-w" "C-d" "C-o" "C-t" "M-t" "M-u" "M-l" "M-c"
                    "C-j" "M-q" "M-;" "C-x C-t" "M-DEL" "M-z x" "C-M-k" "M-\\" "C-x C-o"))
      (goto-char (point-min))
      (ignore-errors (execute-kbd-macro (kbd keys)))
      (should (equal (buffer-string) "alpha beta\ngamma delta\n")))
    (should-not (buffer-modified-p))))

(ert-deftest readonly/save-is-a-no-op-on-an-unchanged-buffer ()
  (ro-with-file (b "a.txt" "hello\n")
    (execute-kbd-macro (kbd "C-x C-s"))
    (should (equal (test-read-file ro-file) "hello\n"))))

(ert-deftest readonly/evil-typing-changes-nothing ()
  (skip-unless (locate-library "evil"))
  (ro-with-file (b "a.txt" "hello\n")
    (my/toggle-evil)
    (unwind-protect
        (progn (dolist (keys '("i x" "a x" "o x" "x" "dd" "p" "cw y"))
                 (ignore-errors (execute-kbd-macro (kbd keys)))
                 (ignore-errors (execute-kbd-macro (kbd "<escape>"))))
               (should (equal (buffer-string) "hello\n")))
      (evil-mode -1))))

;;; Key bindings for the two commands (deliberate three-key chords)

(ert-deftest readonly/edit-chord-turns-editing-on-and-lock-chord-turns-it-off ()
  (ro-with-file (b "a.txt" "hello\n")
    (should buffer-read-only)
    (execute-kbd-macro (kbd "C-c e e"))
    (should-not buffer-read-only)
    (execute-kbd-macro (kbd "C-c e l"))
    (should buffer-read-only)))

(ert-deftest readonly/chords-are-bound-globally-to-the-commands ()
  (should (eq (key-binding (kbd "C-c e e")) 'allow-editing))
  (should (eq (key-binding (kbd "C-c e l")) 'stop-editing)))

(ert-deftest readonly/no-single-or-double-key-turns-editing-on ()
  ;; The unlock needs three keys, and the partial sequences do nothing.
  (should (= 3 (length (kbd "C-c e e"))))
  (dolist (keys '("C-c" "C-c e" "C-c e x" "C-c e RET" "C-c l" "C-c e C-g"))
    (ro-with-file (b "a.txt" "hello\n")
      (ignore-errors (execute-kbd-macro (kbd keys)))
      (should buffer-read-only))))

(ert-deftest readonly/only-long-chords-are-bound-to-allow-editing ()
  ;; Whatever keys exist for it, every one must need three or more keystrokes.
  (let ((keys (where-is-internal 'allow-editing nil)))
    (should keys)
    (dolist (k keys)
      (should (>= (length k) 3)))))

(ert-deftest readonly/the-chord-works-in-every-kind-of-buffer ()
  (dolist (spec '(("a.el" . emacs-lisp-mode) ("a.py" . python-mode) ("a.c" . c-mode)
                  ("a.txt" . text-mode) ("a.json" . js-json-mode)))
    (ro-with-file (b (car spec) "x\n")
      (should (eq major-mode (cdr spec)))
      (should (eq (key-binding (kbd "C-c e e")) 'allow-editing))
      (execute-kbd-macro (kbd "C-c e e"))
      (should-not buffer-read-only))))

(ert-deftest readonly/the-chord-works-in-tree-sitter-java-and-rust-buffers ()
  (dolist (spec '(("A.java" java . java-ts-mode) ("a.rs" rust . rust-ts-mode)))
    (when (treesit-language-available-p (nth 1 spec))
      (ro-with-file (b (car spec) "x\n")
        (should (eq major-mode (nthcdr 2 spec)))
        (execute-kbd-macro (kbd "C-c e e"))
        (should-not buffer-read-only)))))

(ert-deftest readonly/the-chord-is-not-shadowed-by-evil ()
  (skip-unless (locate-library "evil"))
  (ro-with-file (b "a.txt" "hello\n")
    (my/toggle-evil)
    (unwind-protect
        (progn (should (eq (key-binding (kbd "C-c e e")) 'allow-editing))
               (execute-kbd-macro (kbd "C-c e e"))
               (should-not buffer-read-only)
               (execute-kbd-macro (kbd "C-c e l"))
               (should buffer-read-only))
      (evil-mode -1))))

(ert-deftest readonly/the-chord-is-not-shadowed-in-dired-or-ibuffer ()
  (test-with-temp-dir d
    (let ((b (dired-noselect d)))
      (unwind-protect (with-current-buffer b (should (eq (key-binding (kbd "C-c e e")) 'allow-editing)))
        (kill-buffer b))))
  (test-in-buffer #'ibuffer-mode "" (should (eq (key-binding (kbd "C-c e e")) 'allow-editing))))

(ert-deftest readonly/the-reminder-mentions-the-chord ()
  (let ((msg (let ((inhibit-message t)) (my/read-only-hint) (current-message))))
    (should (string-match-p "C-c e e" (with-current-buffer "*Messages*" (buffer-substring (max (point-min) (- (point-max) 200)) (point-max)))))))

;;; What must keep working

(ert-deftest readonly/scratch-and-other-non-file-buffers-stay-editable ()
  (with-temp-buffer (insert "x") (should (equal (buffer-string) "x")))
  (test-in-buffer #'text-mode "" (insert "y") (should-not buffer-read-only)))

(ert-deftest readonly/customize-can-still-save-settings ()
  (require 'cus-edit)
  (test-with-temp-dir d
    (let ((user-init-file (concat d "init.el")) (custom-file (concat d "custom.el")))
      (put 'calendar-week-start-day 'saved-value '(1))
      (unwind-protect
          (progn (custom-save-all)
                 (should (string-match-p "calendar-week-start-day" (test-read-file custom-file))))
        (put 'calendar-week-start-day 'saved-value nil)))))

(ert-deftest readonly/recent-files-list-still-saves ()
  (test-with-temp-dir d
    (let ((recentf-save-file (concat d "recentf")))
      (recentf-add-file (concat d "x"))
      (recentf-save-list)
      (should (file-exists-p recentf-save-file)))))

(ert-deftest readonly/dired-and-file-operations-still-work ()
  (test-with-temp-dir d
    (let ((a (test-write-file (concat d "a") "data")))
      (copy-file a (concat d "b"))
      (rename-file (concat d "b") (concat d "c"))
      (should (equal (test-read-file (concat d "c")) "data"))
      (let ((b (dired-noselect d)))
        (unwind-protect (should (string-match-p "\\bc\\b" (with-current-buffer b (buffer-string))))
          (kill-buffer b))))))

;;; readonly.el ends here
