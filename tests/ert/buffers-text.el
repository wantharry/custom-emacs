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

;;; buffers-text.el ends here
