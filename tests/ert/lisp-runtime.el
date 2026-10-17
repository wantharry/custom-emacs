;;; lisp-runtime.el --- the Elisp language itself  -*- lexical-binding: t; -*-
;; harness: bare

(defvar lisp-test-dyn 1)
(defvar lisp-test-hook nil)
(define-minor-mode lisp-test-mode "A test minor mode." :lighter " T")
(define-error 'lisp-test-error "Test error" 'error)

(ert-deftest lisp/closures-capture-lexically ()
  (let* ((n 0) (inc (lambda () (setq n (1+ n)))))
    (funcall inc) (funcall inc)
    (should (= n 2))))

(ert-deftest lisp/dynamic-binding-of-special-variables ()
  (let ((f (lambda () lisp-test-dyn)))
    (should (= 1 (funcall f)))
    (should (= 2 (let ((lisp-test-dyn 2)) (funcall f))))))

(ert-deftest lisp/pcase-destructuring ()
  (should (equal (pcase '(1 (2 3)) (`(,a (,b ,c)) (list c b a))) '(3 2 1)))
  (should (eq 'big (pcase 100 ((pred (< 50)) 'big)))))

(ert-deftest lisp/seq-and-cl-lib ()
  (should (equal (seq-filter #'cl-evenp '(1 2 3 4)) '(2 4)))
  (should (= 6 (seq-reduce #'+ '(1 2 3) 0)))
  (should (equal (cl-loop for x in '(1 2 3) collect (* x x)) '(1 4 9)))
  (should (equal (seq-uniq '(1 1 2)) '(1 2)))
  (should (cl-every #'numberp '(1 2)))
  (should (equal (cl-remove-if #'cl-oddp '(1 2 3)) '(2))))

(ert-deftest lisp/hooks ()
  (let ((log nil) (lisp-test-hook nil))
    (add-hook 'lisp-test-hook (lambda () (push 'a log)))
    (add-hook 'lisp-test-hook (lambda () (push 'b log)) 90)
    (run-hooks 'lisp-test-hook)
    (should (equal (nreverse log) '(a b)))))

(ert-deftest lisp/advice-add-and-remove ()
  (defun lisp-test-fn (x) (* x 2))
  (advice-add 'lisp-test-fn :around (lambda (orig x) (1+ (funcall orig x))) '((name . plus1)))
  (should (= 7 (lisp-test-fn 3)))
  (advice-remove 'lisp-test-fn 'plus1)
  (should (= 6 (lisp-test-fn 3))))

(ert-deftest lisp/errors-cleanup-and-non-local-exit ()
  (let (log)
    (should (equal (condition-case e (unwind-protect (error "boom %d" 1) (push 'cleanup log))
                     (error (error-message-string e)))
                   "boom 1"))
    (should (equal log '(cleanup))))
  (should (condition-case nil (signal 'lisp-test-error nil) (lisp-test-error t)))
  (should (= 5 (catch 'done (throw 'done 5)))))

(ert-deftest lisp/numbers-bignums-and-floats ()
  (should (= (expt 2 100) 1267650600228229401496703205376))
  (should (= 3 (/ 7 2)))
  (should (= 3.5 (/ 7.0 2)))
  (should (= 2 (mod -1 3)))
  (should (equal (number-to-string 1.5) "1.5"))
  (should (= 255 (string-to-number "ff" 16))))

(ert-deftest lisp/format-directives ()
  (should (equal (format "%05.1f|%-4s|%x|%S" 3.14159 "ab" 255 "q") "003.1|ab  |ff|\"q\"")))

(ert-deftest lisp/define-minor-mode ()
  (with-temp-buffer
    (should-not lisp-test-mode)
    (lisp-test-mode 1)
    (should lisp-test-mode)
    (should (memq 'lisp-test-mode minor-mode-list))
    (lisp-test-mode -1)
    (should-not lisp-test-mode)))

(ert-deftest lisp/macros ()
  (defmacro lisp-test-swap (a b) `(let ((tmp ,a)) (setq ,a ,b ,b tmp)))
  (let ((x 1) (y 2))
    (lisp-test-swap x y)
    (should (equal (list x y) '(2 1))))
  (should (equal (macroexpand '(when a b)) '(if a (progn b)))))

(ert-deftest lisp/setf-on-places ()
  (let ((al (list (cons 'a 1))) (v (vector 1 2)))
    (setf (alist-get 'b al) 2)
    (should (equal al '((b . 2) (a . 1))))
    (cl-incf (alist-get 'a al))
    (should (= 2 (alist-get 'a al)))
    (setf (aref v 0) 9)
    (should (equal v [9 2]))))

(ert-deftest lisp/hash-tables ()
  (let ((h (make-hash-table :test 'equal)))
    (puthash "k" 1 h) (puthash "j" 2 h)
    (should (= 1 (gethash "k" h)))
    (should (= 2 (hash-table-count h)))
    (remhash "k" h)
    (should-not (gethash "k" h))))

(ert-deftest lisp/threads-and-mutexes ()
  (let* ((m (make-mutex)) (n 0)
         (ths (cl-loop repeat 4 collect
                       (make-thread (lambda () (dotimes (_ 100) (with-mutex m (setq n (1+ n)))))))))
    (mapc #'thread-join ths)
    (should (= n 400))))

(ert-deftest lisp/eval-and-symbols ()
  (should (= 6 (eval '(* 2 3) t)))
  (should (eq (intern "foo") 'foo))
  (should (fboundp 'car))
  (should (special-form-p 'if))
  (should (macrop 'when)))

;;; lisp-runtime.el ends here
