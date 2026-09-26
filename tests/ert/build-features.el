;;; build-features.el --- what this Emacs build can do  -*- lexical-binding: t; -*-
;; harness: bare

(ert-deftest build/version-is-32-or-newer ()
  (should (>= emacs-major-version 32)))

(ert-deftest build/native-compilation-available ()
  (should (native-comp-available-p)))

(ert-deftest build/native-compile-at-runtime ()
  (let ((f (native-compile '(lambda (x) (* x 3)))))
    (should (native-comp-function-p f))
    (should (= 15 (funcall f 5)))))

(ert-deftest build/byte-compile-at-runtime ()
  (let ((f (byte-compile '(lambda (x) (+ x 1)))))
    (should (byte-code-function-p f))
    (should (= 3 (funcall f 2)))))

(ert-deftest build/treesit-available ()
  (should (treesit-available-p)))

(ert-deftest build/sqlite-available ()
  (should (sqlite-available-p)))

(ert-deftest build/gnutls-available ()
  (should (gnutls-available-p)))

(ert-deftest build/libxml-available ()
  (should (libxml-available-p)))

(ert-deftest build/dynamic-modules-supported ()
  (should (stringp module-file-suffix)))

(ert-deftest build/threads-supported ()
  (let ((th (make-thread (lambda () 42))))
    (should (= 42 (thread-join th)))))

(ert-deftest build/portable-dump-in-use ()
  (should (pdumper-stats)))

(ert-deftest build/gtk-wayland-toolkit-on-linux ()
  (skip-unless (eq system-type 'gnu/linux))
  (should (featurep 'pgtk)))

;;; build-features.el ends here
