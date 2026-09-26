;;; gui-tests.el --- behavior that only exists in a real window  -*- lexical-binding: t; -*-
;; Run with: tests/run-all.sh --gui   (needs a display; skipped without one).
;; These run inside a live graphical Emacs, so fonts, colors, the mode line, the
;; command loop, popups and cursors are the real thing, unlike --batch.

(defmacro gui-deftest (name &rest body)
  "Define an ERT test NAME (a symbol like gui/foo) tagged `gui' that needs a display."
  (declare (indent 1))
  `(ert-deftest ,name ()
     :tags '(gui)
     (unless (display-graphic-p) (ert-skip "no graphical display"))
     ,@body))

(defun gui--drive (keys steps)
  "Feed KEYS through the real command loop and run timed STEPS, then return.
STEPS is a list of (SECONDS . FUNCTION); each FUNCTION runs that long after the
start, and the value of the last one is returned.  If the minibuffer is open at
the end it is aborted."
  ;; A command run inside this nested loop leaves `this-command' set, which makes
  ;; which-key think a command is still executing and suppress its popup.  Real
  ;; typing is unaffected, so clear that state before every feed.
  (setq this-command nil last-command nil real-this-command nil)
  (setq unread-command-events (if (listp keys) keys (listify-key-sequence keys)))
  (let ((result nil) (end 0))
    (dolist (st steps)
      (setq end (max end (car st)))
      (let ((fn (cdr st)))
        (run-with-timer (car st) nil (lambda () (setq result (funcall fn))))))
    (run-with-timer (+ end 0.3) nil
                    (lambda ()
                      (run-with-timer 0.3 nil #'exit-recursive-edit)
                      (when (> (minibuffer-depth) 0) (abort-minibuffers))))
    (condition-case nil (recursive-edit) (quit nil))
    result))

(defun gui--feed (keys delay fn)
  "Feed KEYS through the real command loop; after DELAY seconds call FN and return its value."
  (gui--drive keys (list (cons delay fn))))

(defmacro gui-with-file (spec &rest body)
  "SPEC is (VAR NAME CONTENT).  Open the temp file the normal way and show it in the window."
  (declare (indent 1))
  `(test-with-temp-dir gui-dir
     (let* ((gui-file (test-write-file (concat gui-dir ,(nth 1 spec)) ,(nth 2 spec)))
            (,(car spec) (find-file gui-file))
            (gui-old (window-buffer (selected-window))))
       (unwind-protect (progn (redisplay t) ,@body)
         (with-current-buffer ,(car spec) (set-buffer-modified-p nil))
         (kill-buffer ,(car spec))
         (when (buffer-live-p gui-old) (switch-to-buffer gui-old))))))

(defun gui--mode-line ()
  (format-mode-line mode-line-format nil (selected-window) (current-buffer)))

;;; The frame and the display

(gui-deftest gui/frame-is-a-real-graphical-window
  (should (display-graphic-p))
  (should (memq window-system '(pgtk x w32 ns)))
  (when (eq system-type 'gnu/linux) (should (memq window-system '(pgtk x)))))

(gui-deftest gui/frame-has-a-usable-size
  (should (>= (frame-width) 40))
  (should (>= (frame-height) 10))
  (should (> (frame-char-width) 0))
  (should (> (frame-pixel-width) 300)))

(gui-deftest gui/frame-decoration-follows-the-config
  (should (= 1 (frame-parameter nil 'menu-bar-lines)))
  (should (= 0 (frame-parameter nil 'tool-bar-lines)))
  (should-not (frame-parameter nil 'vertical-scroll-bars))
  (should inhibit-startup-screen))

(gui-deftest gui/startup-in-a-window-is-fast
  (should (< (float-time (time-subtract after-init-time before-init-time)) 1.0)))

;;; Fonts and text

(gui-deftest gui/default-font-is-monospace
  (should (stringp (face-attribute 'default :family)))
  (should (= (string-pixel-width "iiiiii") (string-pixel-width "MMMMMM")))
  (should (= (string-pixel-width "hello") (* 5 (frame-char-width)))))

(gui-deftest gui/config-picked-a-font-from-its-preference-list
  (should (member (face-attribute 'default :family)
                  '("JetBrains Mono" "Fira Code" "Cascadia Code" "DejaVu Sans Mono" "Menlo" "Consolas")))
  (should (= 120 (face-attribute 'default :height))))

(gui-deftest gui/a-monospace-fallback-font-exists
  (should (find-font (font-spec :family "monospace"))))

(gui-deftest gui/font-backend-shapes-text
  (skip-unless (eq system-type 'gnu/linux))
  (should (or (memq 'ftcrhb (frame-parameter nil 'font-backend))
              (memq 'harfbuzz (frame-parameter nil 'font-backend)))))

(gui-deftest gui/common-characters-can-be-displayed
  (dolist (c '(?a ?é ?✓ ?→ ?日))
    (should (char-displayable-p c))))

(gui-deftest gui/image-formats-are-supported
  (dolist (type '(png jpeg gif svg webp tiff))
    (should (image-type-available-p type))))

;;; Colors

(gui-deftest gui/colors-are-available
  (should (display-color-p))
  (should (> (display-color-cells) 256))
  (should (color-defined-p "red"))
  (should (stringp (face-attribute 'default :foreground nil t)))
  (should (stringp (face-attribute 'default :background nil t))))

(gui-deftest gui/syntax-faces-resolve-to-real-colors
  (dolist (f '(font-lock-keyword-face font-lock-type-face font-lock-function-name-face
               font-lock-string-face font-lock-comment-face))
    (let ((fg (face-foreground f nil t)))
      (should (stringp fg))
      (should (color-values fg)))))

(gui-deftest gui/java-source-is-drawn-in-color
  (skip-unless (treesit-language-available-p 'java))
  (gui-with-file (b "A.java" "public class A { int x; }\n")
    (font-lock-ensure)
    (let ((face (car (ensure-list (get-text-property 1 'face)))))
      (should (eq face 'font-lock-keyword-face))
      (should-not (equal (face-foreground face nil t) (face-foreground 'default nil t))))))

;;; The window: mode line, line numbers, highlight, scrolling, splitting

(gui-deftest gui/mode-line-shows-the-read-only-flag-and-the-modes
  (gui-with-file (b "a.txt" "hello\n")
    (should (string-match-p "%%" (gui--mode-line)))
    (should (string-match-p "a\\.txt" (gui--mode-line)))
    (should (string-match-p "WK" (gui--mode-line)))
    (allow-editing)
    (should-not (string-match-p "%%" (gui--mode-line)))
    (insert "x")
    (should (string-match-p "\\*\\*" (gui--mode-line)))))

(gui-deftest gui/line-number-column-is-drawn
  (gui-with-file (b "a.txt" "one\ntwo\nthree\n")
    (redisplay t)
    (should display-line-numbers)
    (should (> (line-number-display-width) 0))))

(gui-deftest gui/current-line-highlight-is-drawn
  (gui-with-file (b "a.txt" "one\ntwo\n")
    (global-hl-line-highlight)
    (should (overlayp global-hl-line-overlay))
    (should (eq (overlay-get global-hl-line-overlay 'face) 'hl-line))
    (should (eq (overlay-buffer global-hl-line-overlay) (current-buffer)))))

(gui-deftest gui/scrolling-moves-the-view
  (gui-with-file (b "long.txt" (mapconcat #'number-to-string (number-sequence 1 400) "\n"))
    (should (> (window-body-height) 10))
    (goto-char (point-min))
    (set-window-start (selected-window) (point-min))
    (redisplay t)
    (scroll-up-command)
    (redisplay t)
    (should (> (window-start) 1))
    (should (pos-visible-in-window-p (point)))))

(gui-deftest gui/splitting-windows-shares-the-frame
  (delete-other-windows)
  (unwind-protect
      (progn (split-window-right)
             (should (= 2 (length (window-list))))
             (should (>= (apply #'+ (mapcar #'window-total-width (window-list)))
                         (- (frame-width) 2)))
             (dolist (w (window-list)) (should (> (window-body-width w) 10))))
    (delete-other-windows)))

(gui-deftest gui/frame-renders-to-a-png
  (skip-unless (fboundp 'x-export-frames))
  (redisplay t)
  (let ((png (x-export-frames nil 'png)))
    (should (stringp png))
    (should (> (length png) 2000))
    (should (string-prefix-p "\211PNG" png))))

;;; Keys through the real command loop

(gui-deftest gui/typing-into-a-file-is-blocked-and-the-window-says-so
  (gui-with-file (b "a.txt" "hello\n")
    (gui--feed "xyz" 0.6 (lambda () nil))
    (should (equal (buffer-string) "hello\n"))
    (should-not (buffer-modified-p))
    (should (string-match-p "Buffer is read-only"
                            (with-current-buffer "*Messages*" (buffer-string))))))

(gui-deftest gui/edit-chord-then-typing-then-lock
  (gui-with-file (b "a.txt" "hello\n")
    (gui--feed (concat (kbd "C-c e e") "hi") 0.6 (lambda () nil))
    (should-not buffer-read-only)
    (should (string-match-p "hi" (buffer-string)))
    (should (equal (test-read-file gui-file) "hello\n"))
    (gui--feed (kbd "C-c e l") 0.5 (lambda () nil))
    (should buffer-read-only)
    (let ((before (buffer-string)))
      (gui--feed "zzz" 0.5 (lambda () nil))
      (should (equal (buffer-string) before)))))

(gui-deftest gui/c-x-c-q-only-reminds
  (gui-with-file (b "a.txt" "hello\n")
    (gui--feed (kbd "C-x C-q") 0.5 (lambda () nil))
    (should buffer-read-only)))

(gui-deftest gui/which-key-popup-appears-and-lists-the-editing-group
  ;; Press C-c and wait: a popup appears in the window and shows the `e' group, so
  ;; the C-c e chords are discoverable.  (The deeper C-c e level needs real key
  ;; events; tests/test_tui.py checks it through a terminal.)
  (should which-key-mode)                     ; the config must have enabled it
  (which-key-mode -1) (which-key-mode 1)     ; then reset, for isolation from earlier tests
  (let ((text (gui--feed (kbd "C-c") 2.0
                         (lambda () (and (get-buffer-window " *which-key*")
                                         (with-current-buffer " *which-key*" (buffer-string)))))))
    (ignore-errors (which-key--hide-popup-ignore-command))
    (should text)
    (should (string-match-p "e : \\+prefix" text))
    (should (string-match-p "recentf-open" text))
    (should (string-match-p "my/toggle-evil" text))))

(gui-deftest gui/vertical-completion-lists-candidates
  (let ((shown (gui--feed (append (listify-key-sequence (kbd "M-x")) (listify-key-sequence "eglo")) 1.6
                          (lambda ()
                            (with-current-buffer (window-buffer (minibuffer-window))
                              (mapconcat (lambda (o) (concat (overlay-get o 'before-string)
                                                             (overlay-get o 'after-string)))
                                         (overlays-in (point-min) (point-max)) ""))))))
    (should (string-match-p "eglot" shown))
    (should (string-match-p "\n" shown))))

;;; The file finder, in the real minibuffer

(require 'fastfind my/ff-library)   ; so `my/ff-cache-dir' is special before it is let-bound

(defun gui--ff-project (dir)
  "Make DIR a git project holding a few files; return the path of Geometry.java."
  (make-directory (concat dir "src/demo") t)
  (dolist (f '("Geometry.java" "Shape.java" "Circle.java"))
    (test-write-file (concat dir "src/demo/" f) "class X {}\n"))
  (let ((default-directory dir))
    (call-process "git" nil nil nil "init" "-q")
    (call-process "git" nil nil nil "add" "-A"))
  (concat dir "src/demo/Geometry.java"))

(defun gui--minibuffer-text ()
  (with-current-buffer (window-buffer (minibuffer-window))
    (concat (buffer-string) "\n"
            (mapconcat (lambda (o) (concat (overlay-get o 'before-string)
                                           (overlay-get o 'after-string)))
                       (overlays-in (point-min) (point-max)) ""))))

(gui-deftest gui/file-finder-shows-a-match-for-a-typo
  ;; Regression: fido replaced the completion style and showed "(No matches)".
  (test-with-temp-dir d
    (let* ((geo (gui--ff-project d))
           (my/ff-cache-dir (concat d "cache/"))
           (buf (find-file geo))
           (shown (gui--feed (append (listify-key-sequence (kbd "C-c f f")) (listify-key-sequence "gmtry")) 2.0
                             #'gui--minibuffer-text)))
      (unwind-protect
          (progn (should (string-match-p "Geometry\\.java" shown))
                 (should-not (string-match-p "No matches" shown))
                 (should-not (string-match-p "Shape\\.java" shown)))
        (kill-buffer buf)))))

(gui-deftest gui/file-finder-enter-opens-the-file
  (test-with-temp-dir d
    (let* ((geo (gui--ff-project d))
           (my/ff-cache-dir (concat d "cache/"))
           (start (find-file geo))
           (opened (gui--feed (append (listify-key-sequence (kbd "C-c f f"))
                                      (listify-key-sequence "circle")
                                      (listify-key-sequence (kbd "RET")))
                              2.5 (lambda () (buffer-file-name (window-buffer (selected-window)))))))
      (unwind-protect
          (should (equal opened (concat d "src/demo/Circle.java")))
        (dolist (b (buffer-list)) (when (buffer-file-name b) (kill-buffer b)))
        (ignore start)))))

;;; The start screen

(gui-deftest gui/start-screen-c-c-h-shows-links-in-a-real-window
  (test-with-temp-dir d
    (let* ((files (gui--ff-project d))
           (b (find-file files))
           (my/start-store-file (concat d "recents.eld"))
           (my/start--folders nil) (my/start--projects nil) (my/start--loaded t)
           (my/start-ignore nil) (recentf-list (list files))
           (info (gui--feed (listify-key-sequence (kbd "C-c h")) 1.0
                            (lambda ()
                              (with-current-buffer (window-buffer (selected-window))
                                (list (buffer-name) (buffer-string)
                                      (and (button-at (point)) t) display-line-numbers-mode
                                      (length (window-list))))))))
      (unwind-protect
          (progn (should (equal (nth 0 info) "*start*"))
                 (should (string-match-p "Recent work" (nth 1 info)))
                 (should (string-match-p "Geometry\\.java" (nth 1 info)))
                 (should (nth 2 info))              ; the cursor starts on a link
                 (should-not (nth 3 info))          ; no line numbers on this screen
                 (should (= 1 (nth 4 info))))
        (kill-buffer b)
        (when (get-buffer "*start*") (kill-buffer "*start*"))))))

;;; Magit

(gui-deftest gui/magit-status-in-a-real-window
  (skip-unless (locate-library "magit"))
  (test-with-temp-dir d
    (let ((default-directory d))
      (dolist (c '(("init" "-q") ("config" "user.email" "t@t") ("config" "user.name" "t")))
        (apply #'call-process "git" nil nil nil c))
      (test-write-file (concat d "a.txt") "one\n")
      (call-process "git" nil nil nil "add" "a.txt") (call-process "git" nil nil nil "commit" "-qm" "first")
      (test-write-file (concat d "a.txt") "one\ntwo\n"))
    (let* ((b (find-file (concat d "a.txt")))
           (info (gui--feed (listify-key-sequence (kbd "C-x g")) 3.0
                            (lambda ()
                              (with-current-buffer (window-buffer (selected-window))
                                (goto-char (point-min))
                                (re-search-forward "Unstaged changes" nil t)
                                (list (buffer-name) (get-text-property (match-beginning 0) 'font-lock-face)
                                      (face-foreground 'magit-section-heading nil t)))))))
      (unwind-protect
          (progn (should (string-match-p "\\`magit: " (nth 0 info)))
                 (should (eq (nth 1 info) 'magit-section-heading))
                 (should (stringp (nth 2 info))))
        (dolist (x (buffer-list)) (when (string-match-p "\\`magit" (buffer-name x)) (kill-buffer x)))
        (kill-buffer b)))))

;;; Evil and the pointer

(gui-deftest gui/evil-cursor-follows-the-state
  (skip-unless (locate-library "evil"))
  (gui-with-file (b "a.txt" "hello\n")
    (my/toggle-evil)
    (unwind-protect
        (progn (evil-normal-state) (should (memq cursor-type '(t box)))
               (evil-insert-state) (should (equal cursor-type '(bar . 2)))
               (evil-normal-state) (should (memq cursor-type '(t box))))
      (evil-mode -1))))

(gui-deftest gui/mouse-menu-and-wheel-bindings
  (should (eq (lookup-key global-map [mouse-1]) 'mouse-set-point))
  (should (lookup-key global-map [down-mouse-1]))
  (should (lookup-key global-map [menu-bar file]))
  (should mouse-wheel-mode))

(gui-deftest gui/clipboard-round-trip
  (let ((got (ignore-errors
               (gui-set-selection 'CLIPBOARD "emacs-gui-clip")
               (gui-get-selection 'CLIPBOARD 'STRING))))
    (unless got (ert-skip "clipboard not available in this session"))
    (should (equal got "emacs-gui-clip"))))

;;; gui-tests.el ends here
