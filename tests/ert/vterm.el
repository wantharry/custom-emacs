;;; vterm.el --- a real terminal emulator, wired in and really working  -*- lexical-binding: t; -*-
;; harness: config
;; Needs vterm installed (./build.sh packages); skips without it. The real terminal
;; session itself (a real shell prompt, a real command run inside it, real output read
;; back) is covered by tests/test_tui.py instead --- `vterm' needs a real pty, which
;; --batch cannot give it; what IS checked here, without a display, is the one thing
;; that actually took real research this session: that the native module really
;; compiles on this machine without needing anything installed by hand first.

(defmacro vterm-need (&rest body)
  (declare (indent 0))
  `(if (locate-library "vterm") (progn ,@body)
     (ert-skip "vterm is not installed (./build.sh packages)")))

(ert-deftest vterm/key-is-bound ()
  (vterm-need
    (should (eq (key-binding (kbd "C-c V")) 'vterm))))

(ert-deftest vterm/native-module-compiles-without-a-system-libvterm ()
  ;; Confirmed directly in vterm's own `CMakeLists.txt' and by actually running the
  ;; compile for real (not assumed): it looks for a system `libvterm' first and, since
  ;; none is installed on this machine (confirmed with `pkg-config --exists libvterm'
  ;; failing), downloads and builds its own vendored copy automatically --- nothing
  ;; extra had to be installed by hand for this one, unlike `pdf-tools' (see
  ;; tests/ert/pdf-tools.el).  A real compile, run once here with a long timeout since
  ;; it downloads and builds a real C library the first time; `vterm-module-compile'
  ;; itself is a no-op on every run after the first (it checks the `.so' already
  ;; exists).
  (vterm-need
    (unless (require 'vterm-module nil t)
      ;; A real, found-the-hard-way-TWICE ordering requirement: `(require 'vterm)'
      ;; itself (not just `vterm-module-compile') checks `vterm-always-compile-module'
      ;; at its own top level and, if nil, calls `y-or-n-p' to ask interactively ---
      ;; which errors immediately ("Error reading from stdin") in a real `--batch'
      ;; process with no terminal attached. It has to be set BEFORE the `require', not
      ;; wrapped around a later call to `vterm-module-compile' alone (confirmed the
      ;; hard way: a `--batch' run that reached `vterm-module-compile' just fine still
      ;; failed, because the prompt had already fired during `require' itself). It also
      ;; has to be a top-level `setq', not a `let': in this very file's own
      ;; `lexical-binding: t', `let'-binding it BEFORE `vterm-always-compile-module'
      ;; exists as a real special variable (`vterm.el''s own `defcustom', which only
      ;; runs once `require' actually loads the file) collides with it as an
      ;; already-lexical variable of the same name instead (confirmed directly, a real
      ;; "Defining as dynamic an already lexical var" error) --- a plain top-level
      ;; `setq', with no enclosing `let', does not create that lexical binding in the
      ;; first place.
      (setq vterm-always-compile-module t)
      (require 'vterm)
      (vterm-module-compile))
    (should (require 'vterm-module nil t))))

;;; Real interactive sessions --- found, the hard way, that these ARE possible in a plain
;;; `--batch' process after all: `vterm' allocates its own real pty independent of whether
;;; Emacs's own stdin/stdout are a terminal, confirmed directly by actually starting one
;;; here and running a real command through it. `vt-with-vterm' is the shared fixture:
;;; `set-process-query-on-exit-flag' nil right away, since nothing here ever answers the
;;; "kill buffer with a running process?" prompt that would otherwise hang (same class of
;;; problem as `yes-or-no-p' elsewhere in this suite) and `kill-buffer-query-functions'
;;; let-bound to nil around teardown as a second line of defense.

(defmacro vt-with-vterm (var &rest body)
  "Bind VAR to a fresh real vterm buffer (with a live process) around BODY."
  (declare (indent 1))
  `(vterm-need
     (let ((,var (vterm '(4)))) ; non-numeric prefix: always a new session, never reused
       (set-process-query-on-exit-flag (get-buffer-process ,var) nil)
       (unwind-protect (with-current-buffer ,var ,@body)
         (when (buffer-live-p ,var)
           (let ((kill-buffer-query-functions nil)) (kill-buffer ,var)))))))

(defun vt-wait (seconds predicate)
  "Poll PREDICATE (a function of no args) for up to SECONDS, processing the
real pty's output as it arrives, via the buffer-local vterm process."
  (with-timeout (seconds (ert-fail "timed out waiting for the terminal"))
    (while (not (funcall predicate))
      (accept-process-output (get-buffer-process (current-buffer)) 0.1))))

(ert-deftest vterm/starting-creates-a-live-buffer-with-a-real-process ()
  (vt-with-vterm buf
    (should (buffer-live-p buf))
    (should (process-live-p (get-buffer-process buf)))))

(ert-deftest vterm/major-mode-is-vterm-mode ()
  (vt-with-vterm buf
    (should (eq major-mode 'vterm-mode))))

(ert-deftest vterm/running-a-real-command-echoes-its-real-output ()
  (vt-with-vterm buf
    (vterm-send-string "echo vterm-regression-marker-1")
    (vterm-send-return)
    (vt-wait 5 (lambda () (string-match-p "vterm-regression-marker-1\n" (buffer-string))))
    (should (string-match-p "vterm-regression-marker-1" (buffer-string)))))

(ert-deftest vterm/backspace-edits-the-pending-command-line-before-return ()
  (vt-with-vterm buf
    (vterm-send-string "echo backspace-tesz")
    (vterm-send-backspace)
    (vterm-send-string "t")
    (vt-wait 5 (lambda () (string-match-p "echo backspace-test" (buffer-string))))
    (vterm-send-return)
    (vt-wait 5 (lambda () (string-match-p "\nbackspace-test\n" (buffer-string))))
    (should (string-match-p "\nbackspace-test\n" (buffer-string)))))

(ert-deftest vterm/copy-mode-swaps-in-and-back-out-of-the-raw-keyboard-map ()
  ;; A vterm buffer is ALWAYS read-only (you send keys through the pty, you never edit
  ;; the buffer text directly) --- `vterm-copy-mode''s own real, distinguishing effect
  ;; (confirmed directly in its source) is dropping the local keymap entirely so normal
  ;; Emacs movement/selection commands reach the buffer instead of `vterm-mode-map'
  ;; capturing every keystroke as terminal input, then restoring it on exit.
  (vt-with-vterm buf
    (should (eq (current-local-map) vterm-mode-map))
    (vterm-copy-mode 1)
    (should-not (current-local-map))
    (vterm-copy-mode -1)
    (should (eq (current-local-map) vterm-mode-map))))

(ert-deftest vterm/clear-erases-the-visible-screen ()
  (vt-with-vterm buf
    (vterm-send-string "echo before-clear-marker")
    (vterm-send-return)
    (vt-wait 5 (lambda () (string-match-p "before-clear-marker\n" (buffer-string))))
    (vterm-clear)
    (vt-wait 5 (lambda () (not (string-match-p "before-clear-marker" (buffer-string)))))
    (should-not (string-match-p "before-clear-marker" (buffer-string)))))

(ert-deftest vterm/keymap-exceptions-exclude-known-emacs-chords-from-the-terminal ()
  ;; `vterm-keymap-exceptions' (the default list: "C-c" "C-x" "C-u" "C-g" "C-h" "C-l"
  ;; "M-x" "M-o" "C-y" "M-y") is what keeps these chords working as real Emacs commands
  ;; in a vterm buffer instead of being sent straight to the shell as raw keystrokes ---
  ;; checked directly against the real `vterm-mode-map' every vterm buffer actually uses,
  ;; not a reimplementation of `vterm--exclude-keys''s own internal algorithm.
  (vterm-need
    (dolist (key vterm-keymap-exceptions)
      (should-not (eq (lookup-key vterm-mode-map (kbd key)) #'vterm--self-insert))
      (should-not (eq (lookup-key vterm-mode-map (kbd key)) #'vterm--self-insert-meta)))
    ;; A real, unexcepted control key still goes straight to the terminal.
    (should (eq (lookup-key vterm-mode-map (kbd "C-a")) #'vterm--self-insert))))

(ert-deftest vterm/color-palette-has-the-16-real-ansi-colors ()
  (vterm-need
    (should (>= (length vterm-color-palette) 16))
    ;; Each entry is a real FACE name (`vterm-color-black', `vterm-color-red', ...),
    ;; not a literal hex string --- confirmed directly in the source.
    (should (cl-every #'facep vterm-color-palette))
    (should (seq-contains-p vterm-color-palette 'vterm-color-black))
    (should (seq-contains-p vterm-color-palette 'vterm-color-red))))

(ert-deftest vterm/a-nonnumeric-prefix-arg-creates-a-second-separate-session ()
  (vt-with-vterm buf1
    (vt-with-vterm buf2
      (should-not (eq buf1 buf2))
      (should (process-live-p (get-buffer-process buf1)))
      (should (process-live-p (get-buffer-process buf2))))))

(ert-deftest vterm/environment-variables-are-visible-inside-the-real-shell ()
  (vterm-need
    (let* ((vterm-environment '("VTERM_TEST_MARKER=real-env-value")))
      (vt-with-vterm buf
        (vterm-send-string "echo $VTERM_TEST_MARKER")
        (vterm-send-return)
        (vt-wait 5 (lambda () (string-match-p "real-env-value\n" (buffer-string))))
        (should (string-match-p "real-env-value" (buffer-string)))))))

(ert-deftest vterm/vterm-shell-customization-is-what-actually-launches ()
  ;; `vterm-shell' is invoked directly as ONE program (confirmed directly in
  ;; `vterm--internal'/`vterm--get-shell': no shell parsing of its value), so a compound
  ;; "echo foo; sleep 30" string is not valid here --- a real, throwaway executable
  ;; script is the honest way to prove this customization is really what gets launched.
  (vterm-need
    (test-with-temp-dir d
      (let ((script (concat d "fake-shell.sh")))
        (test-write-file script "#!/bin/sh\necho shell-override-marker\nsleep 30\n")
        (set-file-modes script #o755)
        (let ((vterm-shell script))
          (vt-with-vterm buf
            (vt-wait 5 (lambda () (string-match-p "shell-override-marker" (buffer-string))))
            (should (string-match-p "shell-override-marker" (buffer-string)))))))))

(ert-deftest vterm/exit-functions-hook-runs-with-the-buffer-and-the-event ()
  (vterm-need
    (let* ((vterm-shell (executable-find "true"))
           (vterm-kill-buffer-on-exit nil)
           calls
           (vterm-exit-functions (list (lambda (buf event) (push (cons buf event) calls)))))
      (vt-with-vterm buf
        (with-timeout (5 (ert-fail "exit hook never ran"))
          (while (not calls) (accept-process-output (get-buffer-process buf) 0.1)))
        (should (equal (caar calls) buf))
        (should (stringp (cdar calls)))))))

(ert-deftest vterm/kill-buffer-on-exit-closes-the-buffer-when-the-process-exits ()
  (vterm-need
    (let* ((vterm-shell (executable-find "true")))
      (let ((buf (vterm '(4))))
        (set-process-query-on-exit-flag (get-buffer-process buf) nil)
        (with-timeout (5 (ert-fail "buffer was never auto-killed"))
          (while (buffer-live-p buf) (sleep-for 0.1)))
        (should-not (buffer-live-p buf))))))

(ert-deftest vterm/kill-buffer-on-exit-can-be-disabled ()
  (vterm-need
    (let* ((vterm-shell (executable-find "true"))
           (vterm-kill-buffer-on-exit nil))
      (vt-with-vterm buf
        (with-timeout (5 (ert-fail "process never exited"))
          (while (process-live-p (get-buffer-process buf)) (accept-process-output nil 0.1)))
        (should (buffer-live-p buf))))))

(ert-deftest vterm/bookmark-record-has-the-right-shape ()
  (vt-with-vterm buf
    (let ((record (vterm--bookmark-make-record)))
      (should (eq (alist-get 'handler record) #'vterm--bookmark-handler))
      (should (equal (alist-get 'thisdir record) default-directory))
      (should (equal (alist-get 'buf-name record) (buffer-name buf))))))

(ert-deftest vterm/bookmark-handler-reopens-vterm-in-the-recorded-directory ()
  (vterm-need
    (test-with-temp-dir d
      (let* ((record `("test-vterm-bookmark" (handler . vterm--bookmark-handler)
                        (thisdir . ,d) (buf-name . "test-vterm-bookmark") (defaults . nil))))
        (vterm--bookmark-handler record)
        (let ((buf (get-buffer "test-vterm-bookmark")))
          (unwind-protect
              (progn
                (should buf)
                (with-current-buffer buf
                  (should (eq major-mode 'vterm-mode))
                  (should (equal (file-truename default-directory) (file-truename d)))))
            (when (and buf (buffer-live-p buf))
              (set-process-query-on-exit-flag (get-buffer-process buf) nil)
              (let ((kill-buffer-query-functions nil)) (kill-buffer buf)))))))))

(ert-deftest vterm/max-scrollback-limits-buffer-growth ()
  (vterm-need
    (let ((vterm-max-scrollback 50))
      (vt-with-vterm buf
        (dotimes (i 100)
          (vterm-send-string (format "echo scrollback-line-%d" i))
          (vterm-send-return))
        (vt-wait 10 (lambda () (string-match-p "scrollback-line-99" (buffer-string))))
        ;; Not an exact bound (libvterm's own accounting, not this test's to pin down
        ;; precisely) --- the real point is that 100 extra lines did not all accumulate
        ;; forever; a huge multiple of the configured scrollback would mean the setting
        ;; was never actually honored.
        (should (< (line-number-at-pos (point-max)) 300))))))

(ert-deftest vterm/c-c-v-really-opens-a-new-vterm-buffer ()
  (vterm-need
    (let ((before (buffer-list)))
      (let ((buf (call-interactively (key-binding (kbd "C-c V")))))
        (unwind-protect
            (progn
              (should (buffer-live-p buf))
              (should-not (memq buf before))
              (should (eq (buffer-local-value 'major-mode buf) 'vterm-mode)))
          (when (buffer-live-p buf)
            (set-process-query-on-exit-flag (get-buffer-process buf) nil)
            (let ((kill-buffer-query-functions nil)) (kill-buffer buf))))))))

;;; vterm.el ends here
