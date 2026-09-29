;;; dictate.el --- speech-to-text dictation into the buffer, via a local Whisper model  -*- lexical-binding: t; -*-

;; `C-c m' starts recording from the microphone; press it again to stop, transcribe, and
;; insert the result at point.  Runs entirely locally --- no cloud, no API key, no network
;; --- using a local build of whisper.cpp (https://github.com/ggerganov/whisper.cpp) to
;; transcribe what was recorded.  Verified for real, both platforms: a synthesized test
;; sentence came back 100% correct on WSL/Linux (`parecord') and on real Windows (a
;; cross-compiled whisper-cli.exe, `ffmpeg' + dshow for the microphone).  See
;; docs/DICTATE.md for real numbers, and for how to rebuild with GPU acceleration if you
;; have a working CUDA toolkit.
;;
;; Recording and stopping differ by platform, both confirmed necessary for real:
;;   - Linux/WSL: `parecord' (PulseAudio), stopped with an explicit SIGTERM, waited out.
;;     `delete-process' alone does not give it a chance to finalize the WAV header ---
;;     confirmed for real: the file exists but is missing its fmt/data chunks.
;;   - Windows: `ffmpeg' with a dshow audio input, stopped by sending it "q" on stdin,
;;     the only way it finalizes an output file cleanly (there is no SIGTERM-equivalent
;;     signal to send a Windows process); the device name is auto-detected from
;;     `ffmpeg -list_devices'.
;;
;; Neither whisper.cpp/ffmpeg nor the model is bundled with this project (the model
;; alone is hundreds of MB) --- see "Setting it up" in docs/DICTATE.md for how to
;; build/download them; this file only wires them in, and declines clearly if something
;; is missing.
;;
;; See docs/DICTATE.md.

(defvar my/dictate-whisper-cli
  (expand-file-name (if (eq system-type 'windows-nt)
                        "~/.local/share/whisper-cpp/whisper-cli.exe"
                      "~/.local/share/whisper-cpp/whisper-cli"))
  "Path to a built whisper.cpp `whisper-cli' binary.")
(defvar my/dictate-model (expand-file-name "~/.local/share/whisper-cpp/models/ggml-small.en.bin")
  "Path to a whisper.cpp GGML model file.")
(defvar my/dictate-lib-dir (expand-file-name "~/.local/share/whisper-cpp")
  "Where whisper-cli's shared libraries (libwhisper.so and friends) live, on
Linux/WSL, put on LD_LIBRARY_PATH when running it, since a self-built whisper.cpp is
not installed system-wide.  Unused on Windows: that build is fully static.")
(defvar my/dictate-parecord "parecord"
  "Linux/WSL only: the program that records the microphone (PulseAudio's client tool).")
(defvar my/dictate-ffmpeg "ffmpeg"
  "Windows only: the program used to record the microphone (dshow input).")
(defvar my/dictate-audio-device nil
  "Windows only: the dshow audio device name to record from.  nil means auto-detect
the first one `ffmpeg -list_devices' reports, caching the result here.")

(defvar my/dictate--process nil "The in-flight recording or transcription process, if any.")
(defvar my/dictate--transcribing nil "Non-nil once recording has stopped and transcription has started.")
(defvar my/dictate--wav-file nil)
(defvar my/dictate--target-buffer nil "Where to insert the transcribed text.")
(defvar my/dictate--target-marker nil)

(defun my/dictate--record-program ()
  (if (eq system-type 'windows-nt) my/dictate-ffmpeg my/dictate-parecord))

(defun my/dictate--ready-reason ()
  "Why dictation cannot run right now, or nil if it can."
  (cond
   ((not (executable-find (my/dictate--record-program)))
    (format "`%s' not found (install %s)" (my/dictate--record-program)
            (if (eq system-type 'windows-nt) "ffmpeg" "PulseAudio's client tools")))
   ((not (file-executable-p my/dictate-whisper-cli))
    (format "no whisper-cli at %s --- see docs/DICTATE.md to build one" my/dictate-whisper-cli))
   ((not (file-readable-p my/dictate-model))
    (format "no model at %s --- see docs/DICTATE.md to download one" my/dictate-model))))

(defun my/dictate--recording-p ()
  (and my/dictate--process (process-live-p my/dictate--process) (not my/dictate--transcribing)))

(defun my/dictate--busy-p ()
  (and my/dictate--process (process-live-p my/dictate--process)))

(defun my/dictate--windows-audio-device ()
  "The dshow audio device name to record from: `my/dictate-audio-device' if set,
otherwise the first one `ffmpeg -list_devices' reports (and then cached there)."
  (or my/dictate-audio-device
      (setq my/dictate-audio-device
            (with-temp-buffer
              (call-process my/dictate-ffmpeg nil t nil "-hide_banner"
                            "-list_devices" "true" "-f" "dshow" "-i" "dummy")
              (goto-char (point-min))
              (if (re-search-forward "\"\\([^\"]+\\)\" (audio)" nil t)
                  (match-string 1)
                (user-error "No audio input device found (ffmpeg -list_devices -f dshow)"))))))

(defun my/dictate--record-command (wav-file)
  "The command line to start recording into WAV-FILE, for this platform."
  (if (eq system-type 'windows-nt)
      (list my/dictate-ffmpeg "-y" "-f" "dshow" "-i"
            (concat "audio=" (my/dictate--windows-audio-device))
            "-ar" "16000" "-ac" "1" wav-file)
    (list my/dictate-parecord "--channels=1" "--rate=16000" "--format=s16le" wav-file)))

(defun my/dictate--stop-recording (proc)
  "Stop the recording process PROC cleanly and wait for it to actually exit, so its
WAV file is properly finalized before anything reads it (see the file header comment
for why this differs, and matters, on each platform)."
  (if (eq system-type 'windows-nt)
      (ignore-errors (process-send-string proc "q"))
    (signal-process proc 'SIGTERM))
  (let ((n 0))
    (while (and (< n 30) (process-live-p proc)) (accept-process-output proc 0.1) (setq n (1+ n))))
  (delete-process proc))

;;;###autoload
(defun my/dictate-start ()
  "Start recording from the microphone."
  (interactive)
  (if-let* ((reason (my/dictate--ready-reason)))
      (message "Can't dictate: %s" reason)
    (if (my/dictate--busy-p)
        (user-error "Already recording (or still transcribing); press C-c m to stop")
      (setq my/dictate--wav-file (make-temp-file "dictate-" nil ".wav")
            my/dictate--target-buffer (current-buffer)
            my/dictate--target-marker (point-marker)
            my/dictate--transcribing nil
            my/dictate--process
            (make-process
             :name "dictate-record" :buffer nil :noquery t
             :command (my/dictate--record-command my/dictate--wav-file)))
      (message "Recording... press C-c m again to stop and transcribe"))))

;;;###autoload
(defun my/dictate-stop ()
  "Stop recording and transcribe what was said into the buffer at point."
  (interactive)
  (unless (my/dictate--recording-p) (user-error "Not recording"))
  (let ((proc my/dictate--process) (wav my/dictate--wav-file)
        (buf my/dictate--target-buffer) (marker my/dictate--target-marker)
        (out-buf (generate-new-buffer " *dictate-output*"))
        (err-buf (generate-new-buffer " *dictate-stderr*")))
    (setq my/dictate--transcribing t)
    (my/dictate--stop-recording proc)
    (message "Transcribing...")
    (let ((process-environment
           (if (eq system-type 'windows-nt)
               process-environment
             (cons (concat "LD_LIBRARY_PATH=" my/dictate-lib-dir) process-environment))))
      (setq my/dictate--process
            (make-process
             :name "dictate-transcribe" :buffer out-buf :stderr err-buf :noquery t
             :command (list my/dictate-whisper-cli "-m" my/dictate-model "-f" wav "-nt")
             :sentinel
             (lambda (p _event)
               (unless (process-live-p p)
                 (setq my/dictate--transcribing nil my/dictate--process nil)
                 (unwind-protect
                     (let ((text (string-trim (with-current-buffer out-buf (buffer-string)))))
                       (if (string-empty-p text)
                           (message "Dictate: heard nothing")
                         (if (buffer-live-p buf)
                             (with-current-buffer buf
                               (save-excursion (goto-char marker) (insert text))
                               (message "Dictate: inserted %d characters" (length text)))
                           (message "Dictate: buffer to insert into is gone; heard: %s" text))))
                   (ignore-errors (delete-file wav))
                   (kill-buffer out-buf) (kill-buffer err-buf)))))))))

;;;###autoload
(defun my/dictate ()
  "Toggle dictation: start recording, or (pressed again) stop and insert the result."
  (interactive)
  (if (my/dictate--recording-p) (my/dictate-stop) (my/dictate-start)))

(provide 'dictate)
;;; dictate.el ends here
