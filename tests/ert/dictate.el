;;; dictate.el --- local speech-to-text dictation (C-c m) works  -*- lexical-binding: t; -*-
;; harness: config
;; Real-transcription tests only run if a real whisper-cli + model are actually
;; installed at the configured paths (they are never bundled with this project; see
;; docs/DICTATE.md) --- the same "skip if the real local tool is not set up" pattern
;; llm.el uses for Ollama.
;;
;; Live dictation (`C-c M') talks to a real `whisper-server' subprocess over HTTP,
;; started fresh by the tests that need one. Its startup has real timing subtleties,
;; worked out the hard way (see docs/DICTATE.md and docs/CONVERSATION-LOG.md): the
;; listening socket accepts a connection a short time before the server's request
;; handling is actually ready to serve one, which needed a settle delay after the
;; readiness probe, not just before it. `dictate/live-server-really-starts-and-answers'
;; below has a known, pre-existing flake tied to this same cold-start timing ---
;; reproduced across several separate, unrelated sessions and never root-caused; it is
;; not something a change to this file is expected to cause or fix.

(require 'dictate (expand-file-name "dictate" (or (getenv "CONFIG_DIR") user-emacs-directory)))

(defmacro dict-isolated (&rest body)
  "Run BODY with all of dictate.el's state variables reset, so no test can see
what a previous one left behind.  Deliberately leaves `my/dictate-live--server-process'
alone, the same as the real code does between real sessions: it is meant to persist."
  (declare (indent 0))
  `(let (my/dictate--process my/dictate--transcribing my/dictate--wav-file
         my/dictate--target-buffer my/dictate--target-marker
         my/dictate-live--active my/dictate-live--timer my/dictate-live--recording-process
         my/dictate-live--wav-file my/dictate-live--target-buffer my/dictate-live--target-marker)
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

;;; Recording, per platform. `my/dictate--record-command'/`--stop-recording' read
;;; `system-type' directly rather than taking it as a parameter (unlike
;;; gitfolders.el's platform-pure functions): none of them touch a real Windows-only
;;; primitive, so this is safe, but the Windows-shaped command/stop mechanism is still
;;; only exercised for real, never faked, guarded by a real `system-type' check.

(ert-deftest dictate/record-command-shape-on-this-platform ()
  (let ((cmd (my/dictate--record-command "/tmp/x.wav")))
    (if (eq system-type 'windows-nt)
        (progn
          (should (equal (car cmd) my/dictate-ffmpeg))
          (should (member "/tmp/x.wav" cmd))
          (should (cl-some (lambda (a) (string-prefix-p "audio=" a)) cmd)))
      (should (equal cmd (list my/dictate-parecord "--channels=1" "--rate=16000"
                               "--format=s16le" "/tmp/x.wav"))))))

(ert-deftest dictate/windows-audio-device-parses-real-looking-ffmpeg-output ()
  ;; Safe on any platform: this only exercises text parsing, no real ffmpeg or device.
  (let ((sample "[in#0] \"Logitech BRIO\" (video)\n[in#0]   Alternative name \"@device...\"\n[in#0] \"Microphone (Logitech BRIO)\" (audio)\n[in#0]   Alternative name \"@device_cm...\"\n"))
    (cl-letf (((symbol-function 'call-process)
               (lambda (&rest _) (insert sample) 1))
              (my/dictate-audio-device nil))
      (should (equal (my/dictate--windows-audio-device) "Microphone (Logitech BRIO)")))))

(ert-deftest dictate/windows-audio-device-is-cached ()
  (let ((calls 0))
    (cl-letf (((symbol-function 'call-process)
               (lambda (&rest _) (cl-incf calls) (insert "\"Mic A\" (audio)\n") 1))
              (my/dictate-audio-device nil))
      (should (equal (my/dictate--windows-audio-device) "Mic A"))
      (should (equal (my/dictate--windows-audio-device) "Mic A"))
      (should (= calls 1)))))

(ert-deftest dictate/windows-audio-device-errors-clearly-when-none-found ()
  (cl-letf (((symbol-function 'call-process) (lambda (&rest _) 1))
            (my/dictate-audio-device nil))
    (should-error (my/dictate--windows-audio-device))))

(ert-deftest dictate/stop-recording-uses-the-right-mechanism-for-this-platform ()
  (dict-isolated
    (let* ((real-make-process (symbol-function 'make-process))
           (proc (funcall real-make-process :name "dictate-stoptest" :buffer nil :noquery t
                          :command '("sleep" "5")))
           sent-string signaled)
      (cl-letf (((symbol-function 'process-send-string)
                 (lambda (_p s) (setq sent-string s)))
                ((symbol-function 'signal-process)
                 (lambda (_p sig) (setq signaled sig) (ignore-errors (kill-process proc)))))
        (my/dictate--stop-recording proc)
        (if (eq system-type 'windows-nt)
            (should (equal sent-string "q"))
          (should (eq signaled 'SIGTERM))))
      (when (process-live-p proc) (delete-process proc)))))

;;; Live dictation (C-c M): transcribed a few seconds at a time, not only once you stop.
;;; Several of these exist specifically because real behavior surprised real testing:
;;;
;;; - `my/dictate-live-start' must set the target marker's insertion type to `t': a plain
;;;   `(point-marker)' (type nil, the default) does not advance past text inserted at its
;;;   own position, so every chunk after the first was landing BEFORE the previous one,
;;;   not after --- confirmed for real, in a full audio-loopback test, before being fixed.
;;;   `dictate/live-start-sets-an-advancing-marker' pins this down for good.
;;; - `my/dictate-live--blank-p' exists because whisper's own "nothing here" marker is a
;;;   literal bracketed tag ("[BLANK_AUDIO]"), not empty text --- confirmed for real too.

(ert-deftest dictate/live-key-is-bound ()
  (should (eq (key-binding (kbd "C-c M")) 'my/dictate-live)))

(ert-deftest dictate/live-declines-when-the-server-binary-is-missing ()
  (cl-letf (((symbol-function 'executable-find) (lambda (_c) "/usr/bin/parecord"))
            ((symbol-function 'file-executable-p)
             (lambda (f) (not (equal f my/dictate-server-binary))))
            ((symbol-function 'file-readable-p) (lambda (_f) t)))
    (should (string-match-p "whisper-server" (my/dictate-live--ready-reason)))))

(ert-deftest dictate/live-declines-when-the-live-model-is-missing ()
  (cl-letf (((symbol-function 'executable-find) (lambda (_c) "/usr/bin/parecord"))
            ((symbol-function 'file-executable-p) (lambda (_f) t))
            ((symbol-function 'file-readable-p)
             (lambda (f) (not (equal f my/dictate-live-model)))))
    (should (string-match-p "live-dictation model" (my/dictate-live--ready-reason)))))

(ert-deftest dictate/live-ready-reason-also-checks-the-base-requirements ()
  ;; my/dictate--ready-reason (parecord/ffmpeg missing) is consulted first, not
  ;; duplicated: live dictation needs everything C-c m needs, plus its own two things.
  (cl-letf (((symbol-function 'executable-find) (lambda (_c) nil)))
    (should (string-match-p "parecord\\|ffmpeg" (my/dictate-live--ready-reason)))))

(ert-deftest dictate/live-ready-is-nil-when-everything-is-present ()
  (cl-letf (((symbol-function 'executable-find) (lambda (_c) "/usr/bin/parecord"))
            ((symbol-function 'file-executable-p) (lambda (_f) t))
            ((symbol-function 'file-readable-p) (lambda (_f) t)))
    (should-not (my/dictate-live--ready-reason))))

(ert-deftest dictate/live-toggle-starts-then-stops ()
  (dict-isolated
    (cl-letf (((symbol-function 'my/dictate-live--ready-reason) (lambda () nil))
              ((symbol-function 'my/dictate-live--ensure-server) (lambda () nil))
              ((symbol-function 'my/dictate-live--rotate) (lambda (&optional _stop) nil)))
      (my/dictate-live)
      (should my/dictate-live--active)
      (my/dictate-live)
      (should-not my/dictate-live--active))))

(ert-deftest dictate/live-starting-twice-is-a-user-error ()
  (dict-isolated
    (cl-letf (((symbol-function 'my/dictate-live--ready-reason) (lambda () nil))
              ((symbol-function 'my/dictate-live--ensure-server) (lambda () nil))
              ((symbol-function 'my/dictate-live--rotate) (lambda (&optional _stop) nil)))
      (my/dictate-live-start)
      (should-error (my/dictate-live-start) :type 'user-error))))

(ert-deftest dictate/live-stopping-when-not-active-is-a-user-error ()
  (dict-isolated
    (should-error (my/dictate-live-stop) :type 'user-error)))

(ert-deftest dictate/live-start-sets-an-advancing-marker ()
  ;; The real regression: without insertion-type t, chunks land in reverse order. See the
  ;; section comment above.
  (dict-isolated
    (cl-letf (((symbol-function 'my/dictate-live--ready-reason) (lambda () nil))
              ((symbol-function 'my/dictate-live--ensure-server) (lambda () nil))
              ((symbol-function 'my/dictate-live--rotate) (lambda (&optional _stop) nil)))
      (my/dictate-live-start)
      (should (eq (marker-insertion-type my/dictate-live--target-marker) t)))))

(ert-deftest dictate/live-declines-up-front-in-a-read-only-buffer ()
  ;; A real bug, found only by a real user: without this check, live dictation would
  ;; start anyway in a read-only buffer (e.g. `*Messages*') and every single chunk would
  ;; silently fall back to a `message' instead of inserting, with no clear explanation
  ;; why until asked --- see `my/dictate-live--rotate''s own read-only fallback and the
  ;; comment on `my/dictate-live-start' itself.
  (dict-isolated
    (cl-letf (((symbol-function 'my/dictate-live--ready-reason) (lambda () nil))
              ((symbol-function 'my/dictate-live--ensure-server) (lambda () nil))
              ((symbol-function 'my/dictate-live--rotate) (lambda (&optional _stop) nil))
              ((symbol-function 'message) (lambda (fmt &rest a) (apply #'format fmt a))))
      (with-temp-buffer
        (setq buffer-read-only t)
        (should (string-match-p "read-only" (my/dictate-live-start)))
        (should-not my/dictate-live--active)))))

(ert-deftest dictate/blank-audio-tag-is-recognized-but-real-speech-is-not ()
  (should (my/dictate-live--blank-p "[BLANK_AUDIO]"))
  (should (my/dictate-live--blank-p "[SILENCE]"))
  (should (my/dictate-live--blank-p "[MUSIC]"))
  (should-not (my/dictate-live--blank-p ""))
  (should-not (my/dictate-live--blank-p "hello there"))
  ;; a real sentence that happens to end in a bracketed aside must not be mistaken for one
  (should-not (my/dictate-live--blank-p "he said hello [laughing]")))

(ert-deftest dictate/multipart-body-has-the-right-shape ()
  (let* ((f (make-temp-file "dictate-multipart-test-"))
         (_ (with-temp-file f (insert "not really a wav, just some bytes")))
         (body (unwind-protect (my/dictate-live--multipart-body f "TESTBOUNDARY")
                 (delete-file f))))
    (should (string-match-p "\\`--TESTBOUNDARY\r\n" body))
    (should (string-match-p "name=\"response_format\"" body))
    (should (string-match-p "\r\n\r\ntext\r\n" body))
    (should (string-match-p "name=\"file\"; filename=\"chunk.wav\"" body))
    (should (string-match-p "Content-Type: audio/wav" body))
    (should (string-match-p "not really a wav, just some bytes" body))
    (should (string-match-p "--TESTBOUNDARY--\r\n\\'" body))))

;;; Against the real whisper-server in this environment (skips if not built/downloaded)

(ert-deftest dictate/live-server-really-starts-and-answers ()
  ;; The known flake described in the file header lives here: a real `whisper-server'
  ;; cold start, timing-sensitive, reproduced more than once and still not root-caused.
  (skip-unless (file-executable-p my/dictate-server-binary))
  (skip-unless (file-readable-p my/dictate-live-model))
  (dict-isolated
    (unwind-protect
        (progn
          (my/dictate-live--ensure-server)
          (should (process-live-p my/dictate-live--server-process))
          (should (my/dictate-live--server-up-p)))
      (when (process-live-p my/dictate-live--server-process)
        (delete-process my/dictate-live--server-process)))))

(ert-deftest dictate/live-transcribe-a-real-known-recording ()
  ;; The real HTTP round trip, using a known-good pre-recorded WAV in place of a live
  ;; microphone --- confirms the server, the by-hand multipart body, and response parsing
  ;; all really work together, the same real-pipeline confidence
  ;; `dictate/a-real-known-recording-transcribes-correctly' gives the non-live path.
  (skip-unless (file-executable-p my/dictate-server-binary))
  (skip-unless (file-readable-p my/dictate-live-model))
  (skip-unless (file-readable-p "/tmp/whisper-test-sample.wav"))
  (dict-isolated
    (unwind-protect
        (progn
          (my/dictate-live--ensure-server)
          (let ((text (my/dictate-live--transcribe "/tmp/whisper-test-sample.wav")))
            (should (string-match-p "quick brown fox" text))))
      (when (process-live-p my/dictate-live--server-process)
        (delete-process my/dictate-live--server-process)))))

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
