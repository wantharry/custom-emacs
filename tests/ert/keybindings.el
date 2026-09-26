;;; keybindings.el --- docs/KEYBOARD.md matches this Emacs  -*- lexical-binding: t; -*-
;; harness: config
;; Reads every table row of the form  | `KEY` | `command` | ...  in the guide and
;; checks that KEY really runs `command` in the keymap named by the preceding
;; <!-- keymap: NAME --> marker (default: global, with our config loaded).

(require 'dired) (require 'wdired) (require 'ibuffer) (require 'isearch)

(defun kb--rows ()
  "Return a list of (MAP KEY COMMAND LINE) parsed from the key tables in the guides
(docs/KEYBOARD.md and docs/TYPING.md).  A row whose command cell contains a space
(such as `Esc x') is not a command and is skipped."
  (let (rows)
    ;; A <!-- keymap: none --> marker switches checking off until the next marker, for
    ;; tables that are not "key, command" (for example keys pressed after a chord).
    (dolist (doc '("docs/KEYBOARD.md" "docs/TYPING.md"))
      (with-temp-buffer
        (insert-file-contents (expand-file-name doc test-root))
        (let ((map "global") (n 0))
          (dolist (line (split-string (buffer-string) "\n"))
            (setq n (1+ n))
            (cond ((string-match "<!-- keymap: \\([^ ]+\\) -->" line)
                   (setq map (match-string 1 line)))
                  ((and (not (equal map "none"))
                        (string-match "\\`| `\\([^`]+\\)` | `\\([^` ]+\\)` |" line))
                   (push (list map (match-string 1 line) (match-string 2 line)
                               (format "%s:%d" doc n))
                         rows)))))))
    (nreverse rows)))

(defun kb--binding (map key)
  "The command KEY runs in the mode/keymap named MAP.
Modes are checked from inside a real buffer, so keys inherited from parent
modes (such as `q' from `special-mode') and minor modes are seen as a user
would see them."
  (let ((k (kbd key)))
    (pcase map
      ("global" (key-binding k))
      ("evil-normal"
       (test-in-buffer #'text-mode "x"
         (unless (bound-and-true-p evil-mode) (evil-mode 1))
         (unwind-protect (progn (evil-normal-state) (key-binding k))
           (evil-mode -1))))
      ("dired-mode-map"
       (test-with-temp-dir d
         (let ((b (dired-noselect d))) (unwind-protect (with-current-buffer b (key-binding k)) (kill-buffer b)))))
      ("wdired-mode-map"
       (test-with-temp-dir d
         (let ((b (dired-noselect d)))
           (unwind-protect (with-current-buffer b (wdired-change-to-wdired-mode) (key-binding k))
             (with-current-buffer b (set-buffer-modified-p nil)) (kill-buffer b)))))
      ("ibuffer-mode-map" (test-in-buffer #'ibuffer-mode "" (key-binding k)))
      ("emacs-lisp-mode-map" (test-in-buffer #'emacs-lisp-mode "" (key-binding k)))
      (_ (lookup-key (symbol-value (intern map)) k)))))

(defun kb--mismatches (map)
  "Rows of MAP whose key does not run the documented command."
  (let (bad)
    (dolist (r (kb--rows))
      (when (equal (car r) map)
        (let ((got (kb--binding map (nth 1 r))) (want (intern (nth 2 r))))
          (unless (eq got want)
            (push (format "%s: %s %s -> documented %s, actual %S"
                          (nth 3 r) map (nth 1 r) want got)
                  bad)))))
    (nreverse bad)))

(defun kb--maps () (delete-dups (mapcar #'car (kb--rows))))

(ert-deftest keys/guide-has-a-substantial-number-of-rows ()
  (should (> (length (kb--rows)) 240)))

(ert-deftest keys/guide-covers-the-modes-people-ask-about ()
  (dolist (m '("global" "dired-mode-map" "wdired-mode-map" "ibuffer-mode-map"
               "isearch-mode-map" "minibuffer-local-map" "emacs-lisp-mode-map"
               "evil-normal"))
    (should (member m (kb--maps)))))

(ert-deftest keys/every-documented-command-exists ()
  (when (locate-library "evil") (require 'evil))
  (let (bad)
    (dolist (r (kb--rows))
      (let ((cmd (intern (nth 2 r))))
        (unless (or (commandp cmd) (fboundp cmd)
                    (and (string-prefix-p "evil-" (nth 2 r)) (not (locate-library "evil"))))
          (push (format "%s: %s is not a command" (nth 3 r) cmd) bad))))
    (should-not bad)))

(ert-deftest keys/global-keys-match-the-guide ()
  (should-not (kb--mismatches "global")))

(ert-deftest keys/our-custom-keys-match-the-guide ()
  (should (eq (key-binding (kbd "C-c v")) 'my/toggle-evil))
  (should (eq (key-binding (kbd "M-o")) 'other-window))
  (should (eq (key-binding (kbd "C-c r")) 'recentf-open))
  (should (eq (key-binding (kbd "C-x C-b")) 'ibuffer)))

(ert-deftest keys/dired-keys-match-the-guide ()
  (should-not (kb--mismatches "dired-mode-map")))

(ert-deftest keys/wdired-keys-match-the-guide ()
  (should-not (kb--mismatches "wdired-mode-map")))

(ert-deftest keys/ibuffer-keys-match-the-guide ()
  (should-not (kb--mismatches "ibuffer-mode-map")))

(ert-deftest keys/isearch-keys-match-the-guide ()
  (should-not (kb--mismatches "isearch-mode-map")))

(ert-deftest keys/minibuffer-keys-match-the-guide ()
  (should-not (kb--mismatches "minibuffer-local-map")))

(ert-deftest keys/emacs-lisp-keys-match-the-guide ()
  (should-not (kb--mismatches "emacs-lisp-mode-map")))

(ert-deftest keys/evil-normal-state-keys-match-the-guide ()
  (skip-unless (locate-library "evil"))
  (require 'evil)
  (should-not (kb--mismatches "evil-normal")))


;;; Facts the typing guide (docs/TYPING.md) states in prose

(ert-deftest keys/typing-guide-alternatives-to-modifier-keys ()
  (should (eq (key-binding (kbd "C-@")) 'set-mark-command))            ; when C-SPC is taken
  (should (equal (kbd "C-[") (kbd "ESC")))                             ; C-[ is Esc
  (should (eq (key-binding (kbd "ESC x")) 'execute-extended-command))  ; Esc x is M-x
  (should (eq (key-binding (kbd "ESC ESC ESC")) 'keyboard-escape-quit))
  (should (eq (key-binding (kbd "C-]")) 'abort-recursive-edit)))

(ert-deftest keys/typing-guide-slip-recovery-keys ()
  (should (eq (key-binding (kbd "C-z")) 'suspend-frame))
  (should (eq (key-binding (kbd "C-x C-c")) 'save-buffers-kill-terminal))
  (should (eq (key-binding (kbd "C-x z")) 'repeat)))

(ert-deftest keys/typing-guide-hint-after-m-x ()
  (should (eq (default-value 'suggest-key-bindings) t)))

(ert-deftest keys/typing-guide-repeat-mode-maps ()
  (require 'repeat)
  (should (commandp 'repeat-mode))
  (should (eq (lookup-key other-window-repeat-map "o") 'other-window))
  (should (eq (lookup-key other-window-repeat-map "O") 'other-window-backward))
  (should (eq (lookup-key undo-repeat-map "u") 'undo))
  (should (eq (lookup-key next-error-repeat-map "n") 'next-error))
  (should (eq (lookup-key next-error-repeat-map "p") 'previous-error))
  ;; the guide says it is not on by default in this config
  (should-not (bound-and-true-p repeat-mode)))

(ert-deftest keys/typing-guide-mentions-the-facts-it-relies-on ()
  (let ((text (with-temp-buffer (insert-file-contents (expand-file-name "docs/TYPING.md" test-root)) (buffer-string))))
    (dolist (s '("C-@" "Esc Esc Esc" "C-[" "repeat-mode" "Caps Lock" "PowerToys" "C-h l"))
      (should (string-match-p (regexp-quote s) text)))))

;;; keybindings.el ends here
