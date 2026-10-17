;;; early-init.el --- runs before the GUI and package system start  -*- lexical-binding: t; -*-

;; Avoid garbage collection during startup; restored in init.el afterwards.
(setq gc-cons-threshold most-positive-fixnum)

;; Skip UI elements before the first frame is drawn (avoids a flash).
(push '(tool-bar-lines . 0) default-frame-alist)
(push '(vertical-scroll-bars) default-frame-alist)
(setq inhibit-startup-screen t
      frame-inhibit-implied-resize t)

;; Native compilation: compile in the background, don't spam warnings.
(when (featurep 'native-compile)
  (setq native-comp-async-report-warnings-errors 'silent
        ;; The portable bundle (docs/DISTRIBUTION.md) is moved between machines that may have no
        ;; compiler, so it does not compile in the background; it runs the byte-compiled code.
        native-comp-jit-compilation (not (getenv "CUSTOM_EMACS_PORTABLE"))))

;;; early-init.el ends here
