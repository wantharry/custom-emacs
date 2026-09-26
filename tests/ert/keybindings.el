;;; keybindings.el --- docs/KEYBOARD.md matches this Emacs  -*- lexical-binding: t; -*-
;; harness: config
;; Reads every table row of the form  | `KEY` | `command` | ...  in the guide and
;; checks that KEY really runs `command` in the keymap named by the preceding
;; <!-- keymap: NAME --> marker (default: global, with our config loaded).

(require 'dired) (require 'wdired) (require 'ibuffer) (require 'isearch)

(defun kb--rows ()
  "Return a list of (MAP KEY COMMAND LINE) parsed from docs/KEYBOARD.md."
  (with-temp-buffer
    (insert-file-contents (expand-file-name "docs/KEYBOARD.md" test-root))
    (let ((map "global") rows (n 0))
      (dolist (line (split-string (buffer-string) "\n"))
        (setq n (1+ n))
        (cond ((string-match "<!-- keymap: \\([^ ]+\\) -->" line)
               (setq map (match-string 1 line)))
              ((string-match "\\`| `\\([^`]+\\)` | `\\([^`]+\\)` |" line)
               (push (list map (match-string 1 line) (match-string 2 line) n) rows))))
      (nreverse rows))))

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
            (push (format "line %d: %s %s -> documented %s, actual %S"
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
          (push (format "line %d: %s is not a command" (nth 3 r) cmd) bad))))
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

;;; keybindings.el ends here
