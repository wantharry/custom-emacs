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

;; WHAT: where the whisper.cpp transcriber binary lives, picked by platform at load time.
;; WHY: Windows and Linux/WSL each got their own build (see the file header and docs/
;; DICTATE.md for how each was actually built --- the Windows one is cross-compiled from
;; WSL via zig, since no Windows compiler is needed here), with different filenames
;; (".exe" vs none) and, deliberately, neither one bundled into this repo/dist (a model
;; alone is hundreds of MB --- see docs/DICTATE.md's size accounting).  HOW: `~' expands
;; to the real per-platform home directory (`%USERPROFILE%' on Windows, via this
;; project's own launcher), so the same relative path works unmodified on both sides;
;; `eq system-type 'windows-nt' is Emacs's own standard way to detect "really running on
;; Windows" at run time.
(defvar my/dictate-whisper-cli
  (expand-file-name (if (eq system-type 'windows-nt)
                        "~/.local/share/whisper-cpp/whisper-cli.exe"
                      "~/.local/share/whisper-cpp/whisper-cli"))
  "Path to a built whisper.cpp `whisper-cli' binary.")
;; WHAT: the GGML model file whisper-cli actually transcribes with.  WHY: `small.en'
;; (English-only, ~465-487MB) was chosen as the real, measured sweet spot: 100% correct
;; on the test sentence, ~3.6-3.8s to transcribe an 8-second clip (see docs/DICTATE.md).
;; HOW: same platform-independent `~' path on both sides --- unlike the binary, the model
;; file itself is identical bytes on both platforms, so there's no per-OS branch here.
(defvar my/dictate-model (expand-file-name "~/.local/share/whisper-cpp/models/ggml-small.en.bin")
  "Path to a whisper.cpp GGML model file.")
;; WHAT: a directory added to LD_LIBRARY_PATH before running whisper-cli on Linux/WSL.
;; WHY: this whisper.cpp was built locally (not installed via the system package
;; manager), so its shared libraries (libwhisper.so etc.) are not anywhere the dynamic
;; linker looks by default --- without this, `whisper-cli' would fail to start at all
;; with a "shared library not found" error.  HOW: only ever consulted on Linux/WSL (see
;; `my/dictate-stop' below); the Windows build is fully static, so nothing analogous is
;; needed there.
(defvar my/dictate-lib-dir (expand-file-name "~/.local/share/whisper-cpp")
  "Where whisper-cli's shared libraries (libwhisper.so and friends) live, on
Linux/WSL, put on LD_LIBRARY_PATH when running it, since a self-built whisper.cpp is
not installed system-wide.  Unused on Windows: that build is fully static.")
;; WHAT: the Linux/WSL microphone-recording program.  WHY: `parecord' is PulseAudio's
;; own command-line client, already present in this environment (WSLg ships PulseAudio),
;; and it can write a plain WAV file directly --- no extra recording library needed.
;; HOW: overridable as a plain defvar, in case a machine has it somewhere non-standard;
;; `my/dictate--record-program' below is what actually decides, per platform, whether
;; this or `my/dictate-ffmpeg' is the "record program" in effect.
(defvar my/dictate-parecord "parecord"
  "Linux/WSL only: the program that records the microphone (PulseAudio's client tool).")
;; WHAT: the Windows microphone-recording (and, separately, transcoding) program.  WHY:
;; Windows has no PulseAudio/`parecord' equivalent; `ffmpeg's `-f dshow' input driver is
;; the real, confirmed-working way to capture a microphone there, and the very same
;; `ffmpeg' binary is also used ahead of time (once, cached) just to list device names ---
;; see `my/dictate--windows-audio-device' below.
(defvar my/dictate-ffmpeg "ffmpeg"
  "Windows only: the program used to record the microphone (dshow input).")
;; WHAT: the dshow device name `ffmpeg' should record from, on Windows.  WHY: dshow
;; requires an exact device name string (e.g. "Microphone (Logitech BRIO)"), not just
;; "the default mic" --- there is no universal "use whatever the default input is" flag
;; for this driver.  HOW: starts nil (meaning "not yet detected"); the first real
;; recording triggers `my/dictate--windows-audio-device' to look it up and cache its
;; result directly into this variable, so every later recording reuses the same device
;; without re-probing `ffmpeg' each time.  Left as a plain overridable defvar so a
;; person with more than one microphone can set it by hand instead.
(defvar my/dictate-audio-device nil
  "Windows only: the dshow audio device name to record from.  nil means auto-detect
the first one `ffmpeg -list_devices' reports, caching the result here.")

;; WHAT: the one recording-or-transcription subprocess in flight, if any, at any given
;; moment.  WHY: dictation only ever has one thing running at a time (you can't be
;; recording and transcribing simultaneously, nor run two recordings at once from this
;; command) --- a single slot is enough state, and its liveness is exactly how
;; `my/dictate--busy-p' below decides whether `C-c m' is allowed to start something new.
(defvar my/dictate--process nil "The in-flight recording or transcription process, if any.")
;; WHAT: which phase that one process is in.  WHY: the SAME variable, `my/dictate--
;; process', holds first the recording process and later (a different, second) process
;; for transcription --- this flag is what lets `my/dictate--recording-p' distinguish
;; "still recording" (this is nil) from "recording just stopped, now transcribing"
;; (this is t), even though both states have a live process in `my/dictate--process'.
(defvar my/dictate--transcribing nil "Non-nil once recording has stopped and transcription has started.")
;; WHAT: the path to the temporary WAV file the current recording is being written to
;; (and the transcription step reads back from).  WHY: needs to survive from `my/dictate-
;; start' through to `my/dictate-stop's cleanup, where it's deleted once transcription
;; finishes --- see the sentinel in `my/dictate-stop' below.
(defvar my/dictate--wav-file nil)
;; WHAT: the buffer the transcribed text should ultimately be inserted into.  WHY:
;; recording and transcription both take real wall-clock time (seconds), during which
;; the user is free to switch to a different buffer or window --- capturing this at
;; `my/dictate-start' time (not looking up `current-buffer' again later, when the
;; transcription sentinel fires) is what makes the text land back where dictation was
;; actually started, not wherever the user happens to be looking when it finishes.
(defvar my/dictate--target-buffer nil "Where to insert the transcribed text.")
;; WHAT: exactly where in that buffer the text should be inserted.  WHY: a marker (not a
;; plain integer position) is used deliberately, so it stays correct even if the buffer's
;; contents shift (other edits, in other buffers or even this one) during the several
;; seconds recording and transcribing take.
(defvar my/dictate--target-marker nil)

;; WHAT: which external program actually does the recording, for the current platform.
;; WHY: centralizes the one Windows/Linux branch that several other functions below
;; (readiness checking, the actual record command) both need, instead of repeating the
;; same `eq system-type 'windows-nt' check in more than one place.
(defun my/dictate--record-program ()
  (if (eq system-type 'windows-nt) my/dictate-ffmpeg my/dictate-parecord))

;; WHAT: a human-readable reason dictation can't run right now, or nil if everything
;; needed is actually present.  WHY: rather than letting `C-c m' fail deep inside a
;; subprocess call with a cryptic Lisp error, every prerequisite is checked up front so
;; `my/dictate-start' can show one clear message in the echo area and simply decline.
;; HOW: three checks, most likely failure first: the recording program on PATH (the
;; message names the right thing to install, ffmpeg vs PulseAudio's tools, depending on
;; platform); the whisper-cli binary actually executable at its expected path; the model
;; file actually readable there.  Each message points at docs/DICTATE.md, since setting
;; either of the latter two up is a real, multi-step, one-time task this file
;; deliberately does not automate (see the file header comment: neither is bundled).
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

;; WHAT: true only while actively recording (not yet stopped, not transcribing).  WHY:
;; this is exactly the condition `my/dictate' (the toggle command bound to `C-c m') uses
;; to decide whether pressing the key again should mean "stop and transcribe" versus
;; "start a new recording".  HOW: needs a genuinely live process (a recording that
;; already finished or crashed doesn't count) *and* `my/dictate--transcribing' still nil
;; --- once stopping begins, this immediately becomes false even though the (now
;; transcription) process in `my/dictate--process' is still alive.
(defun my/dictate--recording-p ()
  (and my/dictate--process (process-live-p my/dictate--process) (not my/dictate--transcribing)))

;; WHAT: true whenever *anything* --- recording or transcribing --- is currently in
;; flight.  WHY: `my/dictate-start' uses this (not `my/dictate--recording-p') to refuse
;; starting a second recording while a previous one is still being transcribed, which
;; `my/dictate--recording-p' alone would not catch (it would report `nil' during
;; transcription, wrongly implying it's safe to start again).
(defun my/dictate--busy-p ()
  (and my/dictate--process (process-live-p my/dictate--process)))

;; WHAT: figure out (once) which dshow device name to record from, on Windows, and
;; remember it.  WHY: see `my/dictate-audio-device's own comment above for why dshow
;; needs an exact name and why this can't just default to "the microphone".  HOW: if
;; `my/dictate-audio-device' is already set (by a previous call, or by hand), reuse it
;; immediately without touching `ffmpeg' again; otherwise, run `ffmpeg -list_devices'
;; (which, unusually, prints its device list to stderr even on success --- `call-process'
;; with a single output buffer captures both stdout and stderr together here, so nothing
;; is missed), then regexp-search the output for the first line shaped like `"NAME"
;; (audio)' --- ffmpeg's own dshow listing marks audio devices this way, distinct from
;; video ones.  A device list ffmpeg cannot produce anything usable from (e.g. no
;; microphone attached at all) raises a clear `user-error' instead of silently recording
;; nothing.
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

;; WHAT: the exact command line (a list of strings, ready for `make-process') that starts
;; recording into WAV-FILE, for whichever platform this is running on.  WHY: recording
;; itself needs genuinely different programs and arguments per platform (see the file
;; header comment), so this is the one place that difference lives, kept separate from
;; the process-management logic in `my/dictate-start' below.  HOW: on Windows, `ffmpeg'
;; is told to capture from the dshow device found above, resampled to 16kHz mono (`-ar
;; 16000 -ac 1') --- the sample rate/channel layout whisper.cpp expects, so no separate
;; conversion step is ever needed; on Linux/WSL, `parecord' is asked to record directly
;; in that same format (`--format=s16le' is signed 16-bit little-endian, i.e. plain
;; uncompressed PCM, matching a standard WAV body).
(defun my/dictate--record-command (wav-file)
  "The command line to start recording into WAV-FILE, for this platform."
  (if (eq system-type 'windows-nt)
      (list my/dictate-ffmpeg "-y" "-f" "dshow" "-i"
            (concat "audio=" (my/dictate--windows-audio-device))
            "-ar" "16000" "-ac" "1" wav-file)
    (list my/dictate-parecord "--channels=1" "--rate=16000" "--format=s16le" wav-file)))

;; WHAT: stop the recording process PROC the right way for this platform, and block
;; (briefly) until it has genuinely exited, before returning.  WHY: this is a real bug
;; fix, not a style choice --- confirmed directly, `delete-process' by itself kills the
;; process but does not give either `parecord' or `ffmpeg' a chance to flush and
;; finalize their WAV file's header, producing a file whisper.cpp then refuses to read
;; ("fmt chunk and/or data chunk missing").  HOW: on Windows, writing the single
;; character "q" to the process's stdin is confirmed (via a real, separate test) to be
;; the only way `ffmpeg' cleanly finalizes its output there --- there is no SIGTERM-
;; equivalent signal Emacs can deliver to a Windows process; on Linux/WSL, an actual
;; `SIGTERM' does the equivalent job for `parecord'.  Either way, the loop after that
;; polls `process-live-p' (via `accept-process-output', which also lets Emacs's event
;; loop keep running rather than blocking dead) for up to 3 seconds (30 polls x 0.1s) to
;; let the program actually finish writing before `delete-process' releases the process
;; object --- calling `delete-process' any earlier would risk the exact same truncation
;; bug this function exists to avoid.
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

;; WHAT: begin recording from the microphone.  WHY: this is one half of the `C-c m'
;; toggle (`my/dictate--stop' being the other); split into its own command so it can
;; also be bound or called directly if ever wanted.  HOW: `my/dictate--ready-reason'
;; (see above) is checked first and reported plainly if anything is missing, rather than
;; letting `make-process' fail with a raw Lisp error; `my/dictate--busy-p' then refuses
;; to stomp on an already-running recording or transcription.  Once clear to proceed: a
;; fresh temp WAV path is allocated (`make-temp-file', with a ".wav" suffix so external
;; tools recognize it by extension); the current buffer and point are captured right now
;; (see `my/dictate--target-buffer's own comment for why that timing matters);
;; `my/dictate--transcribing' is explicitly reset to nil (defensive, in case a previous
;; run somehow left it set); and `make-process' is started with `:buffer nil' (recording
;; output is the WAV file itself, not anything Emacs needs to capture) and `:noquery t'
;; (so Emacs never prompts to kill this process on exit --- it's expected to be short-
;; lived and self-managed).
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

;; WHAT: stop the current recording, transcribe it, and insert the result.  WHY: the
;; other half of the `C-c m' toggle.  HOW, in order: refuses immediately if nothing is
;; actually recording right now (`my/dictate--recording-p'); captures every piece of
;; state this async operation will still need once it's done (the process, WAV path,
;; target buffer/marker) into plain local variables, since the module-level `my/dictate-
;; --*' variables could in principle be reused/reset before the transcription finishes;
;; two scratch buffers are created up front to capture whisper-cli's stdout (the
;; transcript text itself, via `-nt' which tells it to print plain text with no
;; timestamps) and stderr (its own diagnostic/progress output) separately, so the
;; transcript text stays clean; `my/dictate--transcribing' flips to t immediately so a
;; second `C-c m' press during transcription is correctly refused by `my/dictate--busy-
;; p'; `my/dictate--stop-recording' (above) then blocks briefly until the recording
;; process has genuinely finished and finalized its WAV file.  The transcription process
;; itself is started with `LD_LIBRARY_PATH' extended on Linux/WSL only (see `my/dictate-
;; lib-dir's own comment for why that's needed there and not on Windows) via a let-bound
;; copy of `process-environment' (never mutating the global one).  Its `:sentinel'
;; --- called by Emacs whenever the process's status changes, potentially more than once
;; --- first checks the process is actually no longer alive (a sentinel can fire for
;; other status changes too, not just exit) before doing anything; then resets the two
;; module-level flags so a new recording can start; then, inside `unwind-protect' (so
;; the temp WAV file and both scratch buffers are always cleaned up even if something
;; below errors), reads and trims the transcript text.  An empty result (silence, or a
;; failed transcription) says so plainly rather than inserting nothing silently; if the
;; original target buffer was killed in the meantime, the transcript is still shown (in
;; the echo area) instead of being lost outright, just not inserted anywhere;
;; otherwise the text is inserted at the remembered marker, wrapped in `save-excursion'
;; so it doesn't move point in the target buffer around unexpectedly if that buffer
;; happens to be visible and being looked at elsewhere while this finishes.
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

;; WHAT: the single command actually bound to `C-c m' (see config/init.el).  WHY: one
;; key that does the natural thing whichever state you're in, rather than needing two
;; separate keybindings for start and stop.  HOW: just dispatches on `my/dictate--
;; recording-p', defined above.
;;;###autoload
(defun my/dictate ()
  "Toggle dictation: start recording, or (pressed again) stop and insert the result."
  (interactive)
  (if (my/dictate--recording-p) (my/dictate-stop) (my/dictate-start)))

;; WHAT/WHY/HOW: register this file under the Emacs feature name `dictate', matching the
;; `(require 'dictate ...)' used by tests/ert/dictate.el, and how every sibling config
;; file in this project (`llm.el', `shortcuts.el', ...) announces itself as loaded.
(provide 'dictate)
;;; dictate.el ends here
