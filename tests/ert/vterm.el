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

;;; vterm.el ends here
