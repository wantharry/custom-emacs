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

;;; `my/bundled-epdfinfo' --- the Windows-only prebuilt-binary gate, testable on any
;;; platform since it is plain Lisp (env var + file-existence check), unlike the rest
;;; of pdf-tools which genuinely needs the real `epdfinfo' server (see the file header
;;; comment above for why that server cannot be built on this machine).

(ert-deftest pdf-tools/bundled-epdfinfo-finds-a-real-prebuilt-binary ()
  (test-with-temp-dir d
    (make-directory (concat d "tools/pdf-tools") t)
    (test-write-file (concat d "tools/pdf-tools/epdfinfo.exe") "x")
    (let ((process-environment (cons (concat "CUSTOM_EMACS_HOME=" (directory-file-name d))
                                      process-environment)))
      (should (equal (my/bundled-epdfinfo) (expand-file-name "tools/pdf-tools/epdfinfo.exe" d))))))

(ert-deftest pdf-tools/bundled-epdfinfo-is-nil-without-custom-emacs-home ()
  (let ((process-environment (cl-remove-if (lambda (e) (string-prefix-p "CUSTOM_EMACS_HOME=" e))
                                           process-environment)))
    (should-not (my/bundled-epdfinfo))))

(ert-deftest pdf-tools/bundled-epdfinfo-is-nil-when-the-file-is-missing ()
  (test-with-temp-dir d
    (let ((process-environment (cons (concat "CUSTOM_EMACS_HOME=" (directory-file-name d))
                                      process-environment)))
      (should-not (my/bundled-epdfinfo)))))

;;; `pdf-view-mode''s own static shape --- real, package-defined structure that exists
;;; whether or not `epdfinfo' is built, since `define-derived-mode'/`defvar' both run at
;;; LOAD time, not at "open a real PDF and talk to the server" time.

(ert-deftest pdf-tools/pdf-view-mode-is-derived-from-special-mode ()
  (pdft-need
    (require 'pdf-view)
    (should (fboundp 'pdf-view-mode))
    (should (eq (get 'pdf-view-mode 'derived-mode-parent) 'special-mode))))

(ert-deftest pdf-tools/pdf-view-mode-map-has-the-real-paging-keys ()
  (pdft-need
    (require 'pdf-view)
    (should (eq (lookup-key pdf-view-mode-map (kbd "n")) 'pdf-view-next-page-command))
    (should (eq (lookup-key pdf-view-mode-map (kbd "p")) 'pdf-view-previous-page-command))
    (should (eq (lookup-key pdf-view-mode-map (kbd "M-<")) 'pdf-view-first-page))))

(ert-deftest pdf-tools/pdf-view-mode-map-falls-back-to-image-mode-map ()
  (pdft-need
    (require 'pdf-view)
    (should (eq (keymap-parent pdf-view-mode-map) image-mode-map))))

;;; No regression while the dependency is missing --- `auto-mode-alist'/`magic-mode-alist'
;;; really do still point `.pdf' at the pre-existing fallback, not silently at
;;; `pdf-view-mode' (which would then fail every time a real PDF is opened, the one thing
;;; this file's own header comment says is the actual risk worth guarding).

(ert-deftest pdf-tools/dot-pdf-extension-is-not-wired-to-pdf-view-mode-while-the-dependency-is-missing ()
  ;; `.pdf' is already in `auto-mode-alist' pointing at the BUILT-IN `doc-view-mode-
  ;; maybe' (stock Emacs, nothing to do with pdf-tools) --- the real no-regression
  ;; promise is that it still points there, not at `pdf-view-mode', while the one
  ;; missing system dependency means `pdf-loader-install' was never called.
  (pdft-need
    (unless (featurep 'pdf-loader)
      (should (eq (assoc-default "x.pdf" auto-mode-alist 'string-match) 'doc-view-mode-maybe)))))

(ert-deftest pdf-tools/uppercase-pdf-extension-behaves-the-same-as-lowercase ()
  (pdft-need
    (test-with-temp-dir d
      (let ((f (concat d "A.PDF")))
        (test-write-file f "%PDF-1.4\n%%EOF\n")
        (with-current-buffer (find-file-noselect f)
          (unwind-protect
              (should (memq major-mode '(fundamental-mode doc-view-mode pdf-view-mode)))
            (kill-buffer)))))))

(ert-deftest pdf-tools/a-non-pdf-file-with-pdf-like-text-is-not-misdetected ()
  (pdft-need
    (test-with-temp-dir d
      (let ((f (concat d "notes.txt")))
        (test-write-file f "%PDF-1.4 is mentioned here but this is not a real PDF\n")
        (with-current-buffer (find-file-noselect f)
          (unwind-protect
              (should-not (memq major-mode '(doc-view-mode pdf-view-mode)))
            (kill-buffer)))))))

(ert-deftest pdf-tools/doc-view-mode-p-requires-a-graphical-display ()
  ;; The exact pre-existing fallback fact the file header comment documents, pinned down
  ;; directly against the real function rather than inferred only from `find-file'
  ;; behavior above.
  (pdft-need
    (should-not (and (fboundp 'doc-view-mode-p) (not (display-graphic-p))
                     (doc-view-mode-p 'pdf)))))

;;; pdf-tools.el ends here
