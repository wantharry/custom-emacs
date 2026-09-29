;;; dictate.el --- local speech-to-text dictation (C-c m) works  -*- lexical-binding: t; -*-
;; harness: config
;; Real-transcription tests only run if a real whisper-cli + model are actually
;; installed at the configured paths (they are never bundled with this project; see
;; docs/DICTATE.md) --- the same "skip if the real local tool is not set up" pattern
;; llm.el uses for Ollama.

(require 'dictate (expand-file-name "dictate" (or (getenv "CONFIG_DIR") user-emacs-directory)))

(defmacro dict-isolated (&rest body)
  "Run BODY with all of dictate.el's state variables reset, so no test can see
what a previous one left behind."
  (declare (indent 0))
  `(let (my/dictate--process my/dictate--transcribing my/dictate--wav-file
         my/dictate--target-buffer my/dictate--target-marker)
     ,@body))

;;; Wiring

(ert-deftest dictate/key-is-bound ()
  (should (eq (key-binding (kbd "C-c m")) 'my/dictate)))

(ert-deftest dictate/is-not-loaded-until-used ()
  (let ((out (with-output-to-string
               (with-current-buffer standard-output
                 (call-process test-emacs nil t nil "--batch" "--init-directory" (getenv "CONFIG_DIR")
                               "-l" (expand-file-name "early-init.el" (getenv "CONFIG_DIR"))
                               "-l" (expand-file-name "init.el" (getenv "CONFIG_DIR"))
                               "--eval" "(princ (list (featurep 'dictate) (autoloadp (symbol-function 'my/dictate))))")))))
    (should (string-match-p "(nil t)" out))))

(ert-deftest dictate/does-not-slow-startup ()
  (let ((best most-positive-fixnum))
    (dotimes (_ 3)
      (let ((t0 (float-time)))
        (call-process test-emacs nil nil nil "--batch" "--init-directory" (getenv "CONFIG_DIR")
                      "-l" (expand-file-name "early-init.el" (getenv "CONFIG_DIR"))
                      "-l" (expand-file-name "init.el" (getenv "CONFIG_DIR"))
                      "--eval" "(kill-emacs)")
        (setq best (min best (- (float-time) t0)))))
    (should (< best 0.5))))

;;; Declining clearly when something is missing, without needing the real tools installed

(ert-deftest dictate/declines-when-parecord-is-missing ()
  (cl-letf (((symbol-function 'executable-find) (lambda (_c) nil)))
    (should (string-match-p "parecord" (my/dictate--ready-reason)))))

(ert-deftest dictate/declines-when-whisper-cli-is-missing ()
  (cl-letf (((symbol-function 'executable-find) (lambda (_c) "/usr/bin/parecord"))
            ((symbol-function 'file-executable-p) (lambda (_f) nil)))
    (should (string-match-p "whisper-cli" (my/dictate--ready-reason)))))

(ert-deftest dictate/declines-when-the-model-is-missing ()
  (cl-letf (((symbol-function 'executable-find) (lambda (_c) "/usr/bin/parecord"))
            ((symbol-function 'file-executable-p) (lambda (_f) t))
            ((symbol-function 'file-readable-p) (lambda (_f) nil)))
    (should (string-match-p "model" (my/dictate--ready-reason)))))

(ert-deftest dictate/ready-is-nil-when-everything-is-present ()
  (cl-letf (((symbol-function 'executable-find) (lambda (_c) "/usr/bin/parecord"))
            ((symbol-function 'file-executable-p) (lambda (_f) t))
            ((symbol-function 'file-readable-p) (lambda (_f) t)))
    (should-not (my/dictate--ready-reason))))

(ert-deftest dictate/my-dictate-start-says-so-and-does-not-start-when-not-ready ()
  (dict-isolated
    (cl-letf (((symbol-function 'my/dictate--ready-reason) (lambda () "pretend nothing is installed"))
              ((symbol-function 'message) (lambda (fmt &rest a) (apply #'format fmt a))))
      (should (string-match-p "pretend nothing is installed" (my/dictate-start)))
      (should-not (my/dictate--recording-p)))))

;;; State machine: start/stop, without needing a real recording

(ert-deftest dictate/start-then-recording-p-is-true ()
  (dict-isolated
    (cl-letf* ((real-make-process (symbol-function 'make-process))
               ((symbol-function 'my/dictate--ready-reason) (lambda () nil))
               ((symbol-function 'make-process)
                (lambda (&rest _) (funcall real-make-process :name "dictate-test" :buffer nil :noquery t
                                          :command '("sleep" "5")))))
      (my/dictate-start)
      (should (my/dictate--recording-p))
      (delete-process my/dictate--process))))

(ert-deftest dictate/starting-twice-is-a-user-error ()
  (dict-isolated
    (cl-letf* ((real-make-process (symbol-function 'make-process))
               ((symbol-function 'my/dictate--ready-reason) (lambda () nil))
               ((symbol-function 'make-process)
                (lambda (&rest _) (funcall real-make-process :name "dictate-test" :buffer nil :noquery t
                                          :command '("sleep" "5")))))
      (my/dictate-start)
      (should-error (my/dictate-start) :type 'user-error)
      (delete-process my/dictate--process))))

(ert-deftest dictate/stopping-when-not-recording-is-a-user-error ()
  (dict-isolated
    (should-error (my/dictate-stop) :type 'user-error)))

(ert-deftest dictate/toggle-starts-then-stops ()
  (dict-isolated
    (cl-letf* ((real-make-process (symbol-function 'make-process))
               ((symbol-function 'my/dictate--ready-reason) (lambda () nil))
               ((symbol-function 'make-process)
                (lambda (&rest _) (funcall real-make-process :name "dictate-test" :buffer nil :noquery t
                                          :command '("sleep" "5")))))
      (my/dictate)
      (should (my/dictate--recording-p))
      ;; toggling again should call `my/dictate-stop', not start a second recording
      (let (stopped)
        (cl-letf (((symbol-function 'my/dictate-stop) (lambda () (setq stopped t))))
          (my/dictate))
        (should stopped))
      (when (process-live-p my/dictate--process) (delete-process my/dictate--process)))))

;;; Against the real, locally-built whisper.cpp in this environment (skips if absent)

(ert-deftest dictate/a-real-recording-produces-a-valid-wav-file ()
  ;; Exercises the real recording path (parecord), not transcription: confirms this
  ;; project's actual stop sequence (an explicit SIGTERM, waited out, only then
  ;; `delete-process') leaves a valid, readable WAV file.  `delete-process' alone does
  ;; NOT do this --- confirmed for real: the file exists but its fmt/data chunks are
  ;; missing, since parecord never gets a chance to finalize the header.  That is
  ;; exactly the bug this test (and the fix in `my/dictate-stop') is guarding against.
  (skip-unless (executable-find my/dictate-parecord))
  (skip-unless (executable-find "python3"))
  (dict-isolated
    (let ((wav (make-temp-file "dictate-wavtest-" nil ".wav")))
      (unwind-protect
          (let ((proc (make-process :name "dictate-wavtest" :buffer nil :noquery t
                                    :command (list my/dictate-parecord "--channels=1" "--rate=16000"
                                                   "--format=s16le" wav))))
            (sleep-for 0.5)
            (signal-process proc 'SIGTERM)
            (let ((n 0))
              (while (and (< n 20) (process-live-p proc)) (accept-process-output proc 0.1) (setq n (1+ n))))
            (delete-process proc)
            (should (> (file-attribute-size (file-attributes wav)) 44))  ; more than just a WAV header
            (should (= 0 (call-process "python3" nil nil nil "-c"
                                       (format "import wave; wave.open(%S, 'rb').close()" wav)))))
        (ignore-errors (delete-file wav))))))

(ert-deftest dictate/a-real-known-recording-transcribes-correctly ()
  ;; The full real pipeline, using a known-good pre-recorded WAV in place of a live
  ;; microphone: confirms whisper-cli itself, LD_LIBRARY_PATH, stdout/stderr separation,
  ;; the sentinel, and buffer insertion at the right marker all really work together.
  (skip-unless (file-executable-p my/dictate-whisper-cli))
  (skip-unless (file-readable-p my/dictate-model))
  (skip-unless (file-readable-p "/tmp/whisper-test-sample.wav"))
  (dict-isolated
    (with-temp-buffer
      (insert "Before: ")
      (let ((reason (my/dictate--ready-reason)))
        (skip-unless (not reason)))
      (my/dictate-start)
      (delete-process my/dictate--process)
      (copy-file "/tmp/whisper-test-sample.wav" my/dictate--wav-file t)
      (setq my/dictate--process (start-process "dictate-dummy" nil "true"))
      (my/dictate-stop)
      (let ((n 0))
        (while (and (< n 150) my/dictate--transcribing) (accept-process-output nil 0.2) (setq n (1+ n))))
      (should (string-match-p "Before: The quick brown fox" (buffer-string))))))

;;; dictate.el ends here
