;;; gui-screenshot.el --- screenshot files as a real Emacs window draws them  -*- lexical-binding: t; -*-
;; Usage: ./build.sh screenshots OUTDIR FILE...
;; Opens each FILE (or directory) in a real graphical Emacs with our config and saves
;; OUTDIR/NN-name.png.  Use it to look at fonts, colors and the mode line; automated
;; tests can check that colors exist but not that they look good.
;; Env: SHOT_DIR (output), SHOT_FILES (paths separated by ":").

(let ((out (or (getenv "SHOT_DIR") "."))
      (files (split-string (or (getenv "SHOT_FILES") "") ":" t))
      (n 0))
  ;; Whatever happens, exit: a graphical session shows no errors and would
  ;; otherwise stay open forever.
  (unwind-protect
      (condition-case err
          (progn
            (make-directory out t)
            (delete-other-windows)
            (setq inhibit-startup-screen t)
            (dolist (f files)
              (find-file (expand-file-name f))
              ;; `redisplay' alone is not enough to guarantee the frame is actually
              ;; finished drawing: font-lock/tree-sitter highlighting and font loading
              ;; can still be running asynchronously right after a file is opened. The
              ;; short `sit-for' gives that a moment to settle before the screenshot
              ;; below captures whatever happens to be on screen at that instant.
              (redisplay t)
              (sit-for 0.3)
              (setq n (1+ n))
              (let ((png (expand-file-name
                          (format "%02d-%s.png" n (file-name-nondirectory (directory-file-name f)))
                          out)))
                (with-temp-file png
                  ;; `x-export-frames' returns raw binary PNG bytes, not text; the buffer
                  ;; must be unibyte or `insert'/`with-temp-file' would try to encode them
                  ;; as if they were characters and corrupt the written file.
                  (set-buffer-multibyte nil)
                  (insert (x-export-frames nil 'png))))))
        (error (write-region (format "%S\n" err) nil (expand-file-name "ERROR.txt" out))))
    (kill-emacs 0)))

;;; gui-screenshot.el ends here
