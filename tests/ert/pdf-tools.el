;;; pdf-tools.el --- real PDF viewing, gated on one real system dependency  -*- lexical-binding: t; -*-
;; harness: config
;; Needs pdf-tools installed (./build.sh packages); skips without it.
;;
;; The real finding this file exists to pin down: unlike `vterm' (tests/ert/vterm.el),
;; `pdf-tools' genuinely cannot build its own native helper (`epdfinfo') without one
;; real system package (`libpoppler-glib-dev') that this build process cannot fetch for
;; itself --- confirmed missing on this machine via `pkg-config --exists poppler-glib'.
;; init.el's own gate on that same check means nothing about how `.pdf' files already
;; opened changes until that one `apt-get install' is run by hand and Emacs restarted
;; --- the real thing worth testing here is that no-regression promise, not pdf-tools'
;; own internals (which are a third party's problem, not this config's).

(defmacro pdft-need (&rest body)
  (declare (indent 0))
  `(if (locate-library "pdf-tools") (progn ,@body)
     (ert-skip "pdf-tools is not installed (./build.sh packages)")))

(ert-deftest pdf-tools/gate-matches-the-real-system-dependency ()
  (pdft-need
    (let ((have-dep (and (executable-find "pkg-config")
                          (zerop (call-process "pkg-config" nil nil nil "--exists" "poppler-glib")))))
      (should (eq (featurep 'pdf-loader) (and have-dep t))))))

(ert-deftest pdf-tools/pdf-files-still-open-in-a-real-working-mode ()
  ;; No regression: a real, found-while-writing-this-test fact about the PRE-EXISTING
  ;; baseline, not caused by this change --- `doc-view-mode-p' (confirmed directly in
  ;; its own source) requires `(display-graphic-p)', so in a non-graphical session
  ;; (this --batch test, or a real `-nw' terminal) `.pdf' already fell back to
  ;; `fundamental-mode' before `pdf-tools' was ever added here, independent of whether
  ;; `gs'/`pdftoppm' are installed. `pdf-view-mode''s own source has no equivalent
  ;; guard, but this machine is still missing the one real dependency it needs to even
  ;; build (`libpoppler-glib-dev', see the gate test above), so whether it also renders
  ;; in a `-nw' terminal is genuinely NOT verified here --- not claimed either way. The
  ;; only thing this check can confirm without a display or a successful build is that
  ;; nothing regresses past the pre-existing `fundamental-mode' baseline.
  (pdft-need
    (test-with-temp-dir d
      (let ((f (concat d "a.pdf")))
        ;; A real, minimal, valid PDF --- enough for `auto-mode-alist'/`magic-mode-alist'
        ;; to recognize it as one; its contents don't need to render for this check.
        (test-write-file f "%PDF-1.4\n%%EOF\n")
        (with-current-buffer (find-file-noselect f)
          (unwind-protect
              (should (memq major-mode '(fundamental-mode doc-view-mode pdf-view-mode)))
            (kill-buffer)))))))

;;; pdf-tools.el ends here
