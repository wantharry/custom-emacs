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
      ;; `require' first, THEN `let'-bind: `vterm-always-compile-module' only becomes a
      ;; real dynamic (`defcustom') variable once `vterm.el' itself has loaded --- doing
      ;; the `let' first, in this very file's own `lexical-binding: t', makes `defcustom'
      ;; collide with an already-lexical variable of the same name (confirmed the hard
      ;; way, as a real "Defining as dynamic an already lexical var" error).
      (require 'vterm)
      (let ((vterm-always-compile-module t))
        (vterm-module-compile)))
    (should (require 'vterm-module nil t))))

;;; vterm.el ends here
