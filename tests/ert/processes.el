;;; processes.el --- subprocesses and timers  -*- lexical-binding: t; -*-
;; harness: bare
;; Plain Elisp coverage for the process primitives (synchronous and asynchronous,
;; `:filter'/`:sentinel', `accept-process-output') that this config's own background work
;; is built on --- fastfind.el's background index build (see config/fastfind.el) is the
;; main real user of exactly this `make-process' shape elsewhere in this repo.

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
    (should (equal (string-trim (shell-command-to-string (if (eq system-type (quote windows-nt)) "echo %TEST_VAR%" "echo $TEST_VAR"))) "xyz"))))

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

(ert-deftest processes/call-process-shell-command-runs-a-real-shell ()
  (with-temp-buffer
    (should (= 0 (call-process-shell-command "echo hi && exit 0" nil t nil)))
    (should (equal (buffer-string) "hi\n"))))

(ert-deftest processes/stderr-can-be-captured-separately-from-stdout ()
  (let ((errfile (make-temp-file "test-stderr-")))
    (unwind-protect
        (with-temp-buffer
          (call-process "sh" nil (list t errfile) nil "-c" "echo out; echo err 1>&2")
          (should (equal (buffer-string) "out\n"))
          (should (equal (test-read-file errfile) "err\n")))
      (delete-file errfile))))

(ert-deftest processes/process-get-and-put-store-arbitrary-data ()
  (let ((p (make-process :name "pg" :command '("sleep" "30") :noquery t)))
    (unwind-protect
        (progn
          (process-put p 'my-key 'my-value)
          (should (eq (process-get p 'my-key) 'my-value)))
      (delete-process p))))

(ert-deftest processes/process-command-returns-the-real-argv ()
  (let ((p (make-process :name "pc" :command '("sleep" "30") :noquery t)))
    (unwind-protect
        (should (equal (process-command p) '("sleep" "30")))
      (delete-process p))))

(ert-deftest processes/query-on-exit-flag-can-be-toggled ()
  (let ((p (make-process :name "qf" :command '("sleep" "30") :noquery t)))
    (unwind-protect
        (progn
          (set-process-query-on-exit-flag p nil)
          (should-not (process-query-on-exit-flag p))
          (set-process-query-on-exit-flag p t)
          (should (process-query-on-exit-flag p)))
      (delete-process p))))

(ert-deftest processes/cancel-timer-prevents-it-firing ()
  (let* ((fired nil)
         (tm (run-with-timer 0.2 nil (lambda () (setq fired t)))))
    (cancel-timer tm)
    (sit-for 0.4)
    (should-not fired)))

(ert-deftest processes/repeating-timer-fires-more-than-once ()
  (let* ((count 0)
         (tm (run-with-timer 0.05 0.05 (lambda () (setq count (1+ count))))))
    (unwind-protect
        (with-timeout (3 (ert-fail "timeout"))
          (while (< count 3) (sit-for 0.05)))
      (cancel-timer tm))
    (should (>= count 3))))

(ert-deftest processes/changing-the-filter-after-creation-takes-effect ()
  (let* ((old-out "") (new-out "")
         (p (make-process :name "cf" :command '("cat") :noquery t
                          :filter (lambda (_ s) (setq old-out (concat old-out s))))))
    (unwind-protect
        (progn
          (set-process-filter p (lambda (_ s) (setq new-out (concat new-out s))))
          (process-send-string p "ping\n")
          (with-timeout (5 (ert-fail "timeout"))
            (while (string= new-out "") (accept-process-output p 0.1)))
          (should (equal new-out "ping\n"))
          (should (equal old-out "")))
      (delete-process p))))

(ert-deftest processes/killed-process-reports-signal-status ()
  (let* ((done nil)
         (p (make-process :name "ks" :command '("sleep" "30") :noquery t
                          :sentinel (lambda (_ _e) (setq done t)))))
    (kill-process p)
    (with-timeout (5 (ert-fail "timeout"))
      (while (not done) (accept-process-output p 0.1)))
    (should (eq (process-status p) 'signal))))

(ert-deftest processes/process-send-eof-closes-stdin-and-the-process-exits ()
  (let* ((out "") (done nil)
         (p (make-process :name "eof" :command '("cat") :noquery t
                          :filter (lambda (_ s) (setq out (concat out s)))
                          :sentinel (lambda (_ _e) (setq done t)))))
    (process-send-string p "bye\n")
    (process-send-eof p)
    (with-timeout (5 (ert-fail "timeout"))
      (while (not done) (accept-process-output p 0.1)))
    (should (equal out "bye\n"))
    (should (eq (process-status p) 'exit))
    (should (= 0 (process-exit-status p)))))

(ert-deftest processes/buffer-accumulates-output-without-an-explicit-filter ()
  (let* ((buf (generate-new-buffer "pbuf"))
         (done nil)
         (p (make-process :name "pb" :command '("sh" "-c" "echo one; echo two") :noquery t
                          :buffer buf :sentinel (lambda (_ _e) (setq done t)))))
    (unwind-protect
        (progn
          (with-timeout (5 (ert-fail "timeout"))
            (while (not done) (accept-process-output p 0.1)))
          (should (equal (with-current-buffer buf (buffer-string)) "one\ntwo\n")))
      (kill-buffer buf))))

;;; processes.el ends here
