;;; processes.el --- subprocesses and timers  -*- lexical-binding: t; -*-
;; harness: bare

(ert-deftest processes/call-process-captures-output ()
  (with-temp-buffer
    (should (= 0 (call-process "echo" nil t nil "hello")))
    (should (equal (buffer-string) "hello\n"))))

(ert-deftest processes/exit-status-is-returned ()
  (should (= 3 (call-process "sh" nil nil nil "-c" "exit 3"))))

(ert-deftest processes/process-lines ()
  (should (equal (process-lines "printf" "a\\nb\\n") '("a" "b"))))

(ert-deftest processes/environment-is-passed ()
  (let ((process-environment (cons "TEST_VAR=xyz" process-environment)))
    (should (equal (string-trim (shell-command-to-string "echo $TEST_VAR")) "xyz"))))

(ert-deftest processes/call-process-region-pipes-stdin ()
  (with-temp-buffer
    (insert "hello")
    (call-process-region (point-min) (point-max) "tr" t t nil "a-z" "A-Z")
    (should (equal (buffer-string) "HELLO"))))

(ert-deftest processes/async-filter-and-sentinel ()
  (let ((out "") (done nil))
    (let ((p (make-process :name "t" :command '("sh" "-c" "echo one; echo two")
                           :filter (lambda (_ s) (setq out (concat out s)))
                           :sentinel (lambda (_ _) (setq done t)))))
      (with-timeout (5 (ert-fail "timeout"))
        (while (not done) (accept-process-output p 0.1)))
      (should (equal out "one\ntwo\n"))
      (should (= 0 (process-exit-status p))))))

(ert-deftest processes/send-input-to-live-process ()
  (let* ((out "")
         (p (make-process :name "cat" :command '("cat") :noquery t
                          :filter (lambda (_ s) (setq out (concat out s))))))
    (unwind-protect
        (progn (process-send-string p "ping\n")
               (with-timeout (5 (ert-fail "timeout"))
                 (while (string= out "") (accept-process-output p 0.1)))
               (should (equal out "ping\n")))
      (delete-process p))))

(ert-deftest processes/kill-a-running-process ()
  (let ((p (make-process :name "sleeper" :command '("sleep" "30") :noquery t)))
    (should (process-live-p p))
    (delete-process p)
    (should-not (process-live-p p))))

(ert-deftest processes/timers-fire ()
  (let ((fired nil))
    (run-with-timer 0.05 nil (lambda () (setq fired t)))
    (with-timeout (2 (ert-fail "timeout"))
      (while (not fired) (sit-for 0.05)))
    (should fired)))

;;; processes.el ends here
