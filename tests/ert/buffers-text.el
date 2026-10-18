;;; buffers-text.el --- buffers, text, markers, properties, overlays  -*- lexical-binding: t; -*-
;; harness: bare

(ert-deftest buffers/insert-and-point ()
  (test-in-buffer #'text-mode ""
    (insert "hello")
    (should (= (point) 6))
    (should (equal (buffer-string) "hello"))
    (should (= (buffer-size) 5))))

(ert-deftest buffers/delete-and-undo ()
  (test-in-buffer #'text-mode ""
    (buffer-enable-undo)
    (insert "abc")
    (undo-boundary)
    (delete-region 1 3)
    (undo-boundary)
    (should (equal (buffer-string) "c"))
    (primitive-undo 1 (cdr buffer-undo-list))
    (should (equal (buffer-string) "abc"))))

(ert-deftest buffers/narrowing ()
  (test-in-buffer #'text-mode "0123456789"
    (narrow-to-region 3 6)
    (should (equal (buffer-string) "234"))
    (should (= (point-min) 3))
    (widen)
    (should (= (buffer-size) 10))))

(ert-deftest buffers/save-excursion-and-restriction ()
  (test-in-buffer #'text-mode "abcdef"
    (goto-char 3)
    (save-excursion (goto-char (point-max)) (insert "X"))
    (should (= (point) 3))
    (save-restriction (narrow-to-region 2 4))
    (should (= (point-min) 1))))

(ert-deftest buffers/markers-follow-edits ()
  (test-in-buffer #'text-mode "abcdef"
    (let ((m (copy-marker 4)))
      (goto-char 1) (insert "XX")
      (should (= (marker-position m) 6))
      (set-marker m nil))))

(ert-deftest buffers/text-properties ()
  (test-in-buffer #'text-mode "hello world"
    (put-text-property 1 6 'face 'bold)
    (should (eq (get-text-property 3 'face) 'bold))
    (should-not (get-text-property 8 'face))
    (should (= (next-single-property-change 1 'face) 6))))

(ert-deftest buffers/overlays ()
  (test-in-buffer #'text-mode "hello world"
    (let ((ov (make-overlay 1 6)))
      (overlay-put ov 'face 'italic)
      (should (memq ov (overlays-at 3)))
      (should (eq (overlay-get ov 'face) 'italic))
      (delete-overlay ov)
      (should-not (overlays-at 3)))))

(ert-deftest buffers/buffer-local-variables ()
  (test-in-buffer #'text-mode ""
    (let ((global-value (default-value 'fill-column)))
      (setq-local fill-column 33)
      (should (= 33 (buffer-local-value 'fill-column (current-buffer))))
      (should (= global-value (default-value 'fill-column)))
      (kill-all-local-variables)
      (should (= global-value fill-column)))))

(ert-deftest buffers/create-rename-kill ()
  (let ((b (get-buffer-create "buffers-test-a")))
    (should (memq b (buffer-list)))
    (with-current-buffer b (rename-buffer "buffers-test-b"))
    (should (get-buffer "buffers-test-b"))
    (kill-buffer b)
    (should-not (buffer-live-p b))))

(ert-deftest buffers/lines-and-positions ()
  (test-in-buffer #'text-mode "one\ntwo\nthree\n"
    (should (= 3 (count-lines (point-min) (point-max))))
    (forward-line 1)
    (should (= 2 (line-number-at-pos)))
    (should (= 5 (line-beginning-position)))
    (should (= 8 (line-end-position)))))

(ert-deftest buffers/thing-at-point ()
  (test-in-buffer #'text-mode "foo-bar 1234 baz"
    (goto-char 2)
    (should (equal (thing-at-point 'word) "foo"))
    (should (equal (thing-at-point 'symbol) "foo-bar"))
    (goto-char 10)
    (should (= 1234 (thing-at-point 'number)))))

(ert-deftest buffers/position-predicates-and-char-at-point ()
  (test-in-buffer #'text-mode "ab\ncd"
    (should (bobp))
    (should-not (eobp))
    (should (= (char-after) ?a))
    (goto-char (point-max))
    (should (eobp))
    (should (= (char-before) ?d))
    (goto-char 3) ; right after "ab", before the newline
    (should (eolp))
    (should-not (bolp))
    (goto-char 4) ; right after the newline, start of "cd"
    (should (bolp))
    (should-not (eolp))))

(ert-deftest buffers/search-forward-and-replace-match ()
  (test-in-buffer #'text-mode "one two three"
    (should (search-forward "two" nil t))
    (should (= (match-beginning 0) 5))
    (replace-match "TWO")
    (should (equal (buffer-string) "one TWO three"))
    (goto-char (point-min))
    (should (re-search-forward "t[a-z]+e" nil t))
    (should (equal (match-string 0) "three"))))

(ert-deftest buffers/buffer-modified-p-tracks-real-edits ()
  (test-in-buffer #'text-mode "hello"
    (set-buffer-modified-p nil) ; the setup insert above already marked it modified
    (should-not (buffer-modified-p))
    (insert "!")
    (should (buffer-modified-p))
    (set-buffer-modified-p nil)
    (should-not (buffer-modified-p))))

(ert-deftest buffers/marker-insertion-type-controls-which-side-it-sticks-to ()
  (test-in-buffer #'text-mode "abcdef"
    (let ((sticky-before (copy-marker 3 nil))  ; stays before text inserted at it
          (sticky-after (copy-marker 3 t)))    ; advances past text inserted at it
      (goto-char 3) (insert "XX")
      (should (= (marker-position sticky-before) 3))
      (should (= (marker-position sticky-after) 5))
      (set-marker sticky-before nil) (set-marker sticky-after nil))))

(ert-deftest buffers/propertize-then-strip-properties ()
  (let ((s (propertize "hi" 'face 'bold)))
    (should (eq (get-text-property 0 'face s) 'bold))
    (should (equal (substring-no-properties s) "hi"))
    (test-in-buffer #'text-mode ""
      (insert s)
      (should (eq (get-text-property 1 'face) 'bold))
      (should (equal (buffer-substring-no-properties (point-min) (point-max)) "hi")))))

(ert-deftest buffers/forward-and-backward-paragraph ()
  (test-in-buffer #'text-mode "one\ntwo\n\nthree\nfour\n"
    (goto-char (point-min))
    (forward-paragraph)
    (should (= (point) 9)) ; just past "one\ntwo\n", at the blank line
    (forward-paragraph)
    (should (= (point) (point-max)))
    (backward-paragraph)
    (should (= (point) 9)))) ; the blank line itself, the paragraph separator

(ert-deftest buffers/overlays-in-finds-every-overlay-touching-a-range ()
  (test-in-buffer #'text-mode "0123456789"
    (let ((a (make-overlay 1 3))
          (b (make-overlay 5 8))
          (c (make-overlay 9 10)))
      (should (equal (list a b) (overlays-in 2 6)))
      (mapc #'delete-overlay (list a b c)))))

(ert-deftest buffers/generate-new-buffer-name-avoids-collisions ()
  (let ((b (get-buffer-create "buffers-test-dup")))
    (unwind-protect
        (should (equal (generate-new-buffer-name "buffers-test-dup") "buffers-test-dup<2>"))
      (kill-buffer b))))

(ert-deftest buffers/forward-sexp-skips-a-balanced-form ()
  (test-in-buffer #'emacs-lisp-mode "(foo (bar baz) qux) trailing"
    (goto-char (point-min))
    (forward-sexp)
    (should (= (point) 20))
    (should (equal (buffer-substring (point-min) (point)) "(foo (bar baz) qux)"))))

;;; buffers-text.el ends here
