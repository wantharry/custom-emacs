;;; typing-game.el --- a graduated typing trainer: characters, then Emacs chords  -*- lexical-binding: t; -*-

;; `C-c X' starts it --- prompts for a level, then drills you on random characters
;; (or, at the top level, a mix of characters and real Emacs keybindings) and reports
;; WPM/accuracy at the end. User request, explicit: "can you make a typing game in
;; emacs with alphabets in one session, numbers and alphabets, special characters
;; numbers and alphabets and emacs keys special characters numbers and alphabets in
;; separate session."
;;
;; Four levels, each a superset of the one before (matching the request's own
;; cumulative shape):
;; 1. Alphabet only
;; 2. Alphabet + numbers
;; 3. Alphabet + numbers + special characters
;; 4. All of the above, interleaved with real Emacs keybindings (a curated subset of
;;    docs/TYPING.md's own four-week plan --- reusing that project's existing
;;    curriculum rather than inventing a second, possibly-inconsistent one)
;;
;; HOW: a single synchronous loop (`read-key'/`read-key-sequence-vector'), not an
;; async self-insert-driven minor mode --- deliberately simpler, and the chords in
;; level 4 need exact multi-event key SEQUENCES compared, not single self-inserted
;; characters, so one engine handling both shapes (instead of two incompatible ones)
;; keeps the levels consistent. A chord is NEVER actually executed as the real
;; command --- only its key sequence is compared against what was pressed --- so
;; nothing a level-4 round does can save a file, kill a buffer, or quit Emacs by
;; accident, however it is answered.

(require 'cl-lib)

(defconst my/typing-game--alpha "abcdefghijklmnopqrstuvwxyz"
  "The character set for level 1.")
(defconst my/typing-game--digits "0123456789"
  "Added to `my/typing-game--alpha' for level 2.")
(defconst my/typing-game--special "!@#$%^&*()-_=+[]{};:,.<>/?"
  "Added to level 2's set for level 3 (and level 4's character half).")

;; WHY these specific chords, not a freshly invented list: reused directly from
;; docs/TYPING.md's own four-week plan (the project's own existing, already-decided
;; Emacs-keybinding curriculum) --- confirmed by grepping that file's own key/command
;; table rows, not reinvented. Deliberately excludes anything destructive if
;; MISTYPED-AND-ACTUALLY-RUN would matter (it never runs here regardless, see this
;; file's own header comment, but kept conservative anyway): no `C-x C-c' (quit
;; Emacs), no `C-x C-w'/`C-x C-q' circled either, keeping to the safe, everyday
;; movement/editing/file chords that file's own earlier weeks already teach.
(defconst my/typing-game--chords
  '(("C-f" . "forward-char") ("C-b" . "backward-char")
    ("C-n" . "next-line") ("C-p" . "previous-line")
    ("C-a" . "move-beginning-of-line") ("C-e" . "move-end-of-line")
    ("C-k" . "kill-line") ("C-y" . "yank") ("C-g" . "keyboard-quit")
    ("C-s" . "isearch-forward") ("C-r" . "isearch-backward")
    ("C-d" . "delete-char") ("C-w" . "kill-region") ("M-w" . "kill-ring-save")
    ("M-f" . "forward-word") ("M-b" . "backward-word") ("M-d" . "kill-word")
    ("M-x" . "execute-extended-command")
    ("C-x C-f" . "find-file") ("C-x C-s" . "save-buffer") ("C-x C-b" . "ibuffer")
    ("C-x b" . "switch-to-buffer") ("C-x o" . "other-window")
    ("C-x 0" . "delete-window") ("C-x 1" . "delete-other-windows")
    ("C-x 2" . "split-window-below") ("C-x 3" . "split-window-right")
    ("C-x u" . "undo") ("M-<" . "beginning-of-buffer") ("M->" . "end-of-buffer")
    ("C-l" . "recenter-top-bottom"))
  "(KEY-STRING . COMMAND-NAME) pairs drilled in level 4 --- see this file's own
header comment for why this exact list.")

(defcustom my/typing-game-length 20
  "How many characters a level 1-3 session drills, or how many character items
level 4 mixes in alongside `my/typing-game-chord-count' chords.")

(defcustom my/typing-game-chord-count 10
  "How many Emacs-keybinding chords a level 4 session drills.")

(defun my/typing-game--charset-for-level (level)
  "The character set LEVEL (1-4) draws characters from --- level 4 uses the
same full set as level 3 for its own character half."
  (cond ((= level 1) my/typing-game--alpha)
        ((= level 2) (concat my/typing-game--alpha my/typing-game--digits))
        (t (concat my/typing-game--alpha my/typing-game--digits my/typing-game--special))))

(defun my/typing-game--random-char (charset)
  (aref charset (random (length charset))))

(defun my/typing-game--build-items (level)
  "The ordered list of drill items for LEVEL --- each either (char . CHAR) or
(chord . (KEY-STRING . COMMAND-NAME)). Levels 1-3 are all characters; level 4
shuffles `my/typing-game-length' characters together with
`my/typing-game-chord-count' chords (`cl-shuffle-vector/-list' is not
available on older Emacs, hence the plain Fisher-Yates below)."
  (let* ((charset (my/typing-game--charset-for-level level))
         (chars (cl-loop repeat my/typing-game-length
                          collect (cons 'char (my/typing-game--random-char charset)))))
    (if (< level 4)
        chars
      (let* ((chords (cl-loop repeat my/typing-game-chord-count
                               collect (cons 'chord (nth (random (length my/typing-game--chords))
                                                          my/typing-game--chords))))
             (items (vconcat chars chords)))
        ;; Fisher-Yates, in place.
        (cl-loop for i from (1- (length items)) downto 1
                 do (let ((j (random (1+ i))))
                      (cl-rotatef (aref items i) (aref items j))))
        (append items nil)))))

(defun my/typing-game--item-label (item)
  "A human-readable string for ITEM, for the \"Type:\" prompt line."
  (pcase (car item)
    ('char (char-to-string (cdr item)))
    ('chord (format "%s  (%s)" (cadr item) (cddr item)))))

(defvar-local my/typing-game--buffer nil
  "The `*Typing Game*' buffer a running session writes its progress to.")

(defun my/typing-game--render (buf level done total correct errors elapsed current-label)
  (with-current-buffer buf
    (let ((inhibit-read-only t))
      (erase-buffer)
      (insert (format "Typing Game --- Level %d\n\n" level))
      (insert (format "Progress: %d/%d   Correct: %d   Errors: %d   Time: %.0fs\n\n"
                      done total correct errors elapsed))
      (when current-label
        (insert (format "Type: %s\n" current-label)))
      (goto-char (point-min)))))

(defun my/typing-game--wait-for-char (expected)
  "Block for one real keystroke and return non-nil if it matches EXPECTED
(a character). `read-key' (not `read-char') so function/modifier keys do not
signal an error, they just count as a miss."
  (eq (read-key (format "Type: %c" expected)) expected))

(defun my/typing-game--wait-for-chord (key-string)
  "Block for a real key SEQUENCE and return non-nil if it matches KEY-STRING
exactly --- the chord is never actually executed as its real command, only
compared (see this file's own header comment on why)."
  (equal (read-key-sequence-vector (format "Press: %s" key-string))
         (kbd key-string)))

(defun my/typing-game--run (level)
  "Run one full LEVEL session to completion in `*Typing Game*', blocking.
Returns a plist of the final stats --- split out from `my/typing-game' itself
so a test can call it directly against a mocked `read-key'/`read-key-sequence-
vector' without a real interactive loop."
  (let* ((items (my/typing-game--build-items level))
         (total (length items))
         (buf (get-buffer-create "*Typing Game*"))
         (correct 0) (errors 0) (char-correct 0) (char-total 0)
         (chord-correct 0) (chord-total 0)
         (start (float-time)))
    (with-current-buffer buf
      (unless (eq major-mode 'fundamental-mode) (fundamental-mode))
      (setq buffer-read-only nil))
    (cl-loop for item in items for i from 1 do
             (my/typing-game--render buf level (1- i) total correct errors
                                     (- (float-time) start) (my/typing-game--item-label item))
             (let (ok)
               (pcase (car item)
                 ('char (setq char-total (1+ char-total))
                        (setq ok (my/typing-game--wait-for-char (cdr item)))
                        (when ok (setq char-correct (1+ char-correct))))
                 ('chord (setq chord-total (1+ chord-total))
                         (setq ok (my/typing-game--wait-for-chord (cadr item)))
                         (when ok (setq chord-correct (1+ chord-correct)))))
               (if ok (setq correct (1+ correct)) (setq errors (1+ errors)))))
    (let* ((elapsed (max 0.01 (- (float-time) start)))
           (wpm (if (> char-total 0) (/ (/ char-correct 5.0) (/ elapsed 60.0)) 0))
           (accuracy (if (> total 0) (* 100.0 (/ (float correct) total)) 0)))
      (my/typing-game--render buf level total total correct errors elapsed nil)
      (with-current-buffer buf
        (let ((inhibit-read-only t))
          (goto-char (point-max))
          (insert (format "\nDone in %.1fs.\n" elapsed))
          (when (> char-total 0)
            (insert (format "Characters: %d/%d correct (%.0f%% accuracy), %.1f WPM\n"
                            char-correct char-total (* 100.0 (/ (float char-correct) char-total)) wpm)))
          (when (> chord-total 0)
            (insert (format "Emacs keys: %d/%d correct (%.0f%% accuracy)\n"
                            chord-correct chord-total (* 100.0 (/ (float chord-correct) chord-total)))))
          (insert "\nq to quit, any other key to play again.")
          (setq buffer-read-only t)))
      (list :level level :total total :correct correct :errors errors :elapsed elapsed
            :char-total char-total :char-correct char-correct :wpm wpm
            :chord-total chord-total :chord-correct chord-correct :accuracy accuracy))))

(defconst my/typing-game--level-prompts
  '(("1. Alphabet" . 1)
    ("2. Alphabet + numbers" . 2)
    ("3. Alphabet + numbers + special characters" . 3)
    ("4. Alphabet + numbers + special characters + Emacs keys" . 4))
  "What `completing-read' offers in `my/typing-game', and the real level number
each one maps to.")

;;;###autoload
(defun my/typing-game (&optional level)
  "Start a typing-practice session --- prompts for a level (1-4, see
`my/typing-game--level-prompts') if LEVEL is not given. See this file's own
header comment, and docs/TYPING-GAME.md, for the full account."
  (interactive)
  (let ((level (or level
                    (cdr (assoc (completing-read "Level: " (mapcar #'car my/typing-game--level-prompts)
                                                 nil t)
                                my/typing-game--level-prompts)))))
    (switch-to-buffer (get-buffer-create "*Typing Game*"))
    (let (again)
      (setq again t)
      (while again
        (my/typing-game--run level)
        (setq again (not (eq (read-key) ?q)))))
    (quit-window)))

(provide 'typing-game)
;;; typing-game.el ends here
