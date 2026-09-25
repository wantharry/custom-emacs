;; -*- lexical-binding: t; -*-
(setq native-comp-jit-compilation nil)
(require 'package)
(let ((ok 0) (fail 0))
  (dolist (b (sort (mapcar #'car (package--builtin-alist)) (lambda (a b) (string< (symbol-name a) (symbol-name b)))))
    (condition-case e (progn (require b) (setq ok (1+ ok)))
      (error (setq fail (1+ fail))
             (princ (format "FAIL %s: %s\n" b (error-message-string e))))))
  (princ (format "SUMMARY ok=%d fail=%d\n" ok fail)))
