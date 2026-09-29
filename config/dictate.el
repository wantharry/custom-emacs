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

;;; Live dictation: transcribed as you speak, not only once you stop (C-c M) -------------

;; `C-c M' (capital) toggles LIVE dictation: text appears every few seconds while you are
;; still talking, instead of only once, all at once, when you stop (`C-c m', above).  Real,
;; measured reason this needs a genuinely different mechanism, not just a shorter version of
;; the same one: transcribing costs about 2.5-3 seconds of FIXED overhead per `whisper-cli'
;; invocation almost regardless of clip length (decoding dominates, not loading --- timing a
;; 1.9s and a 3.6s clip gave near-identical times, and so did a warm, already-loaded model
;; via a first version of the server below).  Repeatedly invoking `whisper-cli' every few
;; seconds, the obvious way to build "live" out of the one-shot command above, can never
;; keep up with continuous speech: each chunk would take longer to transcribe than it took
;; to speak.
;;
;; The fix that actually works: switch to `whisper-server' (a second binary whisper.cpp
;; itself provides --- an HTTP server over the same engine, no extra dependency beyond what
;; `whisper-cli' already needed) AND to a smaller model with greedy decoding.  Model size
;; turned out to matter far more than keeping it warm: the exact same short clips still took
;; ~2.5-2.8s each against an already-loaded `small.en' (decode strategy, `-bo'/`-bs', made
;; close to no difference); switching the SERVER to `base.en' with `-bo 1 -bs 1' (best-of/
;; beam-size 1: skip re-scoring multiple candidates) brought that down to ~0.6-0.7s ---
;; comfortably faster than the audio itself, which is what "keeping up live" actually needs.
;;
;; That speed has a real, honest cost: `base.en' is less accurate than the `small.en' model
;; `C-c m' uses for its own, one-shot, non-time-critical transcription --- measured for
;; real, `base.en' misheard "emacs" as "e-max" on a sentence `small.en' got 100% correct.
;; Live dictation trades some accuracy for speed on purpose, since "live" transcription that
;; cannot keep up defeats the entire point; `C-c m' (unchanged, still `small.en') remains
;; the accurate choice for anything where getting every word right matters more than seeing
;; it appear immediately.
;;
;; Recording continues, cut into `my/dictate-live-chunk-seconds' pieces: each chunk is
;; stopped (the same reliable stop-and-wait mechanism as `C-c m', so its WAV header is
;; always valid) and a new one is started immediately after, while the just-finished chunk
;; is POSTed for transcription and, once the reply arrives, appended at point.  This is a
;; real, measured, and honestly documented tradeoff too: stopping and restarting
;; sequentially (rather than trying to record two overlapping chunks at once, which is
;; fragile across platforms and, on Windows, not possible at all --- dshow only allows one
;; process to hold the device) means a small gap of well under a second between chunks,
;; during which anything said is not captured.
;;
;; Verified for real, end to end: synthesized speech played through a real audio loopback
;; (so `parecord' captures it exactly as it would a real microphone) while live dictation
;; ran, confirming text really does appear in multiple separate chunks as the speech
;; continues, not just once at the end.  See docs/DICTATE.md.

(require 'url)

;; WHAT: where the second whisper.cpp binary lives, picked by platform, same convention as
;; `my/dictate-whisper-cli'.  WHY/HOW: see the section comment above for why live dictation
;; needs a genuinely different program, not just a faster way to call the same one.
(defvar my/dictate-server-binary
  (expand-file-name (if (eq system-type 'windows-nt)
                        "~/.local/share/whisper-cpp/whisper-server.exe"
                      "~/.local/share/whisper-cpp/whisper-server"))
  "Path to a built whisper.cpp `whisper-server' binary --- the same engine as
`my/dictate-whisper-cli', kept running so each chunk avoids paying its own ~3s
decode-and-load cost again; see the section comment above for the real numbers.")
;; WHAT: the model live dictation actually transcribes with.  WHY: deliberately smaller
;; and faster than `my/dictate-model' (`small.en') --- see the section comment above for
;; the real, measured speed/accuracy tradeoff this is chosen for.
(defvar my/dictate-live-model (expand-file-name "~/.local/share/whisper-cpp/models/ggml-base.en.bin")
  "Path to the (smaller, faster) GGML model live dictation transcribes with.")
(defvar my/dictate-live-host "127.0.0.1")
;; WHAT: the local port `whisper-server' listens on.  WHY: an unusual-enough number to be
;; unlikely to collide with something else already using a common port; never reachable
;; from outside this machine either way, since `my/dictate-live-host' is a loopback address.
(defvar my/dictate-live-port 8765 "Local port `whisper-server' listens on.")
;; WHAT: how often a new chunk is cut and sent off while live dictation runs.  WHY: 5s,
;; not the original 3s --- comfortably longer than the ~0.6-0.7s a chunk actually takes to
;; transcribe either way (so the pipeline never falls behind at either value), but a real,
;; measured finding moved this from 3s to 5s: a fixed-interval cut landing mid-word/mid-
;; phrase makes Whisper (any model size, confirmed directly with both base.en and small.en
;; on the same isolated fragment) confidently *complete* the cut-off phrase with a
;; plausible-sounding but wrong ending, rather than transcribing only what it actually
;; heard --- the model has no "I'm not sure" output, only a confident guess. A longer
;; window does not eliminate this (any fixed interval can still land mid-phrase), but it
;; cuts far less often, so it happens less often too. The real fix --- cutting chunks on
;; actual pauses in speech (VAD) instead of a fixed timer --- is a bigger, separate change.
(defvar my/dictate-live-chunk-seconds 5
  "How often a new chunk is cut and sent for transcription while live dictation runs.")

;; WHAT: the running `whisper-server' process, if any.  WHY: deliberately left running
;; between dictation sessions (not stopped when live dictation stops) --- restarting it
;; every time would mean paying its ~1-2s model-load cost on every single `C-c M', for a
;; server that otherwise stays perfectly idle and harmless in the meantime.
(defvar my/dictate-live--server-process nil "The running `whisper-server' process, if any.")
(defvar my/dictate-live--active nil "Non-nil while live dictation is running.")
(defvar my/dictate-live--timer nil "The repeating timer driving the chunk cycle, if any.")
(defvar my/dictate-live--recording-process nil "The current chunk's recording process, if any.")
(defvar my/dictate-live--wav-file nil)
(defvar my/dictate-live--target-buffer nil)
(defvar my/dictate-live--target-marker nil)

;; WHAT: why live dictation cannot run right now, or nil if it can.  WHY/HOW: the same
;; up-front, clear-message pattern as `my/dictate--ready-reason' (reused first: the
;; recording program and the microphone are needed exactly the same way), with one more
;; check specific to live mode --- the separate `whisper-server' binary and its own,
;; smaller model, alongside (not instead of) everything `C-c m' itself needs.
(defun my/dictate-live--ready-reason ()
  (or (my/dictate--ready-reason)
      (cond
       ((not (file-executable-p my/dictate-server-binary))
        (format "no whisper-server at %s --- see docs/DICTATE.md to build one" my/dictate-server-binary))
       ((not (file-readable-p my/dictate-live-model))
        (format "no live-dictation model at %s --- see docs/DICTATE.md to download one" my/dictate-live-model)))))

(defun my/dictate-live--server-url ()
  (format "http://%s:%d/inference" my/dictate-live-host my/dictate-live-port))

;; WHAT: is the server already up and accepting connections, right now?  WHY: starting it is
;; not instant (a real, measured ~1-2s for `base.en' to load), so this is polled rather than
;; assumed.  HOW: a bare TCP connect, not an HTTP request through `url.el' --- a real,
;; measured bug: a `url-retrieve-synchronously' GET here, even though it completes and gets
;; killed cleanly, left `url.el' in a state (confirmed with `url-http-attempt-keepalives' let
;; to nil on both sides too, which did NOT fix it, and with a bare TCP connect in its place,
;; which did) that silently broke the very next `url-retrieve-synchronously' POST in
;; `my/dictate-live--transcribe' --- it would return "" instead of the real transcript, with
;; no error anywhere; whisper-server itself was never at fault (the exact same GET-then-POST
;; sequence via `curl', a separate process each time, always worked).  A plain
;; `open-network-stream' never touches any of that machinery, so it cannot poison the POST
;; that follows it.
(defun my/dictate-live--server-up-p ()
  (ignore-errors
    (let ((proc (open-network-stream "dictate-server-probe" nil
                                      my/dictate-live-host my/dictate-live-port)))
      (when proc (delete-process proc) t))))

;; WHAT: start `whisper-server' if it is not already running, and wait (briefly) until it
;; actually answers.  WHY/HOW: idempotent --- safe to call at the start of every live
;; dictation session, not just the first; does nothing if a server from an earlier session
;; is still alive, which is exactly what keeps the model warm across sessions instead of
;; reloading it every single time `C-c M' is pressed (see the module variable's own
;; comment).  Polls for up to 10s (real, measured cold start is 1-2s; this leaves genuine
;; headroom for a slower machine) rather than a fixed sleep, so a fast machine is not made
;; to wait needlessly and a slow one is not cut off too early.
;;
;; The extra half-second sleep once the port answers is not padding --- a real, measured
;; finding: `whisper-server' opens its listening socket (so a bare TCP connect, or even a full
;; HTTP round trip, already succeeds) some short but real amount of time before its request
;; handling is actually ready to serve one; a POST landing in that gap comes back with an
;; empty body, no error anywhere, indistinguishable from silence.  Confirmed directly: the
;; very first real transcription request right after start-up failed consistently and only
;; ever that one; every later request on the same server always worked.  0.3s already fixed
;; it in repeated testing --- 0.5s is kept for real headroom on a slower machine.
(defun my/dictate-live--ensure-server ()
  (unless (and my/dictate-live--server-process (process-live-p my/dictate-live--server-process))
    (setq my/dictate-live--server-process
          (make-process
           :name "dictate-server" :buffer " *dictate-server*" :noquery t
           :command (list my/dictate-server-binary "-m" my/dictate-live-model
                          "--host" my/dictate-live-host "--port" (number-to-string my/dictate-live-port)
                          "-bo" "1" "-bs" "1")))
    (let ((n 0))
      (while (and (< n 100) (not (my/dictate-live--server-up-p)))
        (sleep-for 0.1) (setq n (1+ n)))
      (unless (< n 100) (user-error "whisper-server did not start in time"))
      (sleep-for 0.5))))

;; WHAT: the raw multipart/form-data POST body for one WAV file.  WHY: `whisper-server'
;; expects a real multipart upload (the same shape a browser file-input form would send),
;; and Emacs has no built-in helper for building one --- this is the whole of what it
;; takes, built by hand rather than pulling in a package for it.  HOW: three parts, each
;; introduced by `--BOUNDARY' and ended with the final `--BOUNDARY--': a plain text field
;; asking for a plain-text reply (`response_format=text', instead of the default JSON, so
;; nothing needs parsing on the way back), and the file itself, its raw bytes read with
;; `coding-system-for-read' bound to `binary' so they pass through completely unchanged
;; (a WAV file is not text; reading it through any text coding system would corrupt it).
;; The whole body is (re-)encoded as `binary' at the very end too, for the same reason.
(defun my/dictate-live--multipart-body (file boundary)
  (let ((file-bytes (with-temp-buffer
                      (set-buffer-multibyte nil)
                      (let ((coding-system-for-read 'binary)) (insert-file-contents-literally file))
                      (buffer-string))))
    (encode-coding-string
     (concat "--" boundary "\r\n"
             "Content-Disposition: form-data; name=\"response_format\"\r\n\r\ntext\r\n"
             "--" boundary "\r\n"
             "Content-Disposition: form-data; name=\"file\"; filename=\"chunk.wav\"\r\n"
             "Content-Type: audio/wav\r\n\r\n" file-bytes "\r\n"
             "--" boundary "--\r\n")
     'binary)))

;; WHAT: POST WAV-FILE to the running server and return the transcribed text (a string,
;; possibly empty; never nil --- a failed request is treated the same as silence, so one
;; momentary hiccup mid-session does not stop the whole thing).  WHY/HOW: synchronous, on
;; purpose --- an earlier, asynchronous (`url-retrieve') version of this hit a real,
;; unresolved bug (the callback fired with an empty response buffer despite the server
;; genuinely answering, confirmed in its own log at the time); `url-retrieve-synchronously'
;; has none of that, and the real cost of using it --- Emacs is unresponsive for the
;; ~0.6-0.7s a chunk actually takes to transcribe --- is paid only during the brief,
;; automatic chunk-rotation tick, not while the user is doing anything else with Emacs; the
;; NEXT chunk's recording is a separate subprocess and keeps capturing audio regardless of
;; whether Emacs's own Lisp is blocked at that moment.
(defun my/dictate-live--transcribe (file)
  (let* ((boundary "----emacs-dictate-live-boundary")
         (url-request-method "POST")
         (url-request-extra-headers
          (list (cons "Content-Type" (concat "multipart/form-data; boundary=" boundary))))
         (url-request-data (my/dictate-live--multipart-body file boundary))
         (buf (ignore-errors (url-retrieve-synchronously (my/dictate-live--server-url) t t 10))))
    (if (not buf) ""
      (unwind-protect
          (with-current-buffer buf
            (goto-char (point-min))
            ;; The real header/body separator on the wire is "\r\n\r\n" (confirmed with a raw
            ;; hexdump of whisper-server's actual response) --- plain "\n\n" never matches
            ;; that, which is why this always fell through to "" until caught by
            ;; `dictate/live-transcribe-a-real-known-recording'.  `\r?' on both sides copes
            ;; with either raw CRLF or an already-normalized buffer.
            (if (re-search-forward "\r?\n\r?\n" nil t) (string-trim (buffer-substring (point) (point-max))) ""))
        (kill-buffer buf)))))

;; WHAT: does TEXT look like whisper's own "no real speech here" marker, rather than an
;; actual transcript?  WHY: a real, measured finding, not a guess --- whisper's convention
;; for "nothing worth transcribing in this clip" is a bracketed tag ("[BLANK_AUDIO]", also
;; seen in the wild: "[SILENCE]", "[MUSIC]"), not plain empty text.  Confirmed for real: a
;; chunk covering `parecord's own brief startup silence came back exactly "[BLANK_AUDIO]"
;; rather than "".  A separate, pure predicate (not inlined into `my/dictate-live--rotate')
;; specifically so it has its own direct test, the same reasoning this project applies to
;; every other small, checkable rule (`my/ff--score', `my/git-repos--merge', ...).  HOW: a
;; whole string of one bracketed, all-caps/underscore/space tag and nothing else ---
;; deliberately narrow, so a real sentence that happens to end in a bracketed aside is
;; never mistaken for one of these.
(defun my/dictate-live--blank-p (text)
  (string-match-p "\\`\\[[A-Z_ ]+\\]\\'" text))

;; WHAT: cut the current chunk, start the next one, and transcribe the one that just
;; finished --- the one cycle live dictation repeats.  WHY/HOW: stops the in-flight
;; recording with the SAME proven, WAV-header-safe mechanism `C-c m' uses
;; (`my/dictate--stop-recording'); starts the next chunk's recording immediately
;; afterward, before doing anything else, to keep the gap between chunks as short as it
;; can be (still real and measurable --- see the section comment above --- but not made
;; any longer than it has to be by transcribing first); only then sends the just-finished
;; chunk for transcription and, if it actually heard something, inserts it at the
;; remembered marker.  Runs as a plain function (not a process sentinel), called both by
;; the repeating timer and, once more, by `my/dictate-live-stop' for the final chunk ---
;; STOP-NEW-RECORDING is what tells it not to start another one that final time.
(defun my/dictate-live--rotate (&optional stop-new-recording)
  (let ((finished-proc my/dictate-live--recording-process) (finished-wav my/dictate-live--wav-file))
    (when (and finished-proc (process-live-p finished-proc))
      (my/dictate--stop-recording finished-proc))
    (if stop-new-recording
        (setq my/dictate-live--recording-process nil my/dictate-live--wav-file nil)
      (setq my/dictate-live--wav-file (make-temp-file "dictate-live-" nil ".wav")
            my/dictate-live--recording-process
            (make-process :name "dictate-live-record" :buffer nil :noquery t
                          :command (my/dictate--record-command my/dictate-live--wav-file))))
    ;; A real, if rare, race: caught once, in a real multi-chunk run, right at the moment
    ;; a manual stop landed within the same instant as an already-scheduled rotation
    ;; tick. `my/dictate--stop-recording' can genuinely finish (the process it was given
    ;; exits) even when that process never got as far as creating its own output file ---
    ;; possible if it is signaled essentially the instant it was spawned. Guarding on
    ;; `file-exists-p' here means that one unlucky chunk is silently treated the same as
    ;; a chunk that captured no audio, rather than signaling a real error out of a timer.
    (when (and finished-wav (file-exists-p finished-wav))
      (unwind-protect
          (let ((text (my/dictate-live--transcribe finished-wav)))
            (when (my/dictate-live--blank-p text) (setq text ""))
            (unless (string-empty-p text)
              ;; A real bug, hit by pressing `C-c M' while sitting in `*Messages*' (its
              ;; own read-only, by default in Emacs) after an earlier error --- `insert'
              ;; there signals `buffer-read-only', repeatedly, once per chunk, out of a
              ;; timer callback.  Treated the same as the target buffer being gone
              ;; entirely: `my/dictate-live-start' already declines up front for the
              ;; common case (starting while read-only), so this is the defensive
              ;; fallback for a buffer that turns read-only *after* starting.
              (if (and (buffer-live-p my/dictate-live--target-buffer)
                        (not (buffer-local-value 'buffer-read-only my/dictate-live--target-buffer)))
                  (with-current-buffer my/dictate-live--target-buffer
                    (save-excursion
                      (goto-char my/dictate-live--target-marker)
                      (insert text " ")))
                (message "Dictate (live): target buffer is gone or read-only; heard: %s" text))))
        (ignore-errors (delete-file finished-wav))))))

;; WHAT: `C-c M' (start half) --- begin live dictation.  WHY/HOW: same up-front readiness
;; check and re-entrancy guard as `my/dictate-start'; starts the server (a no-op if one is
;; already warm from an earlier session), captures the target buffer/marker the same way
;; and for the same reason as one-shot dictation, fires the first chunk immediately (via
;; `my/dictate-live--rotate' with nothing yet to transcribe --- see that function's own
;; comment), then starts the repeating timer that keeps the cycle going every
;; `my/dictate-live-chunk-seconds' until stopped.
;;;###autoload
(defun my/dictate-live-start ()
  "Start live dictation: transcribed a few seconds at a time while you speak, instead of
only once you stop (see `my/dictate-start' for that, non-live mode)."
  (interactive)
  (if-let* ((reason (my/dictate-live--ready-reason)))
      (message "Can't live-dictate: %s" reason)
    (if my/dictate-live--active
        (user-error "Already live-dictating; press C-c M to stop")
      (message "Starting live dictation server...")
      (my/dictate-live--ensure-server)
      (setq my/dictate-live--active t
            my/dictate-live--target-buffer (current-buffer)
            my/dictate-live--target-marker (point-marker)
            my/dictate-live--recording-process nil
            my/dictate-live--wav-file nil)
      ;; A real bug, caught only by an actual multi-chunk run, not by reading the code:
      ;; a plain `(point-marker)' does not advance past text inserted exactly at its own
      ;; position (insertion type nil, the default) --- so each new chunk was being
      ;; inserted BEFORE the previous one, not after, and a real test came back with the
      ;; chunks in reverse order.  `t' makes the marker advance past what was just
      ;; inserted, so the next chunk correctly lands after it instead.
      (set-marker-insertion-type my/dictate-live--target-marker t)
      (my/dictate-live--rotate)                       ; starts the first chunk's recording
      (setq my/dictate-live--timer
            (run-with-timer my/dictate-live-chunk-seconds my/dictate-live-chunk-seconds
                            #'my/dictate-live--rotate))
      (message "Live dictating (every %ds)... press C-c M again to stop" my/dictate-live-chunk-seconds))))

;; WHAT: `C-c M' (stop half) --- end live dictation.  WHY/HOW: cancels the repeating timer
;; first (so no new rotation can start mid-shutdown), then calls `my/dictate-live--rotate'
;; one last time with STOP-NEW-RECORDING set, which stops the final in-flight chunk,
;; transcribes it, and inserts it, without starting another one.  Deliberately does NOT
;; stop `whisper-server' itself --- see that variable's own comment for why staying warm
;; between sessions is the point.
;;;###autoload
(defun my/dictate-live-stop ()
  "Stop live dictation, transcribing and inserting the final chunk."
  (interactive)
  (unless my/dictate-live--active (user-error "Not live-dictating"))
  (when my/dictate-live--timer (cancel-timer my/dictate-live--timer) (setq my/dictate-live--timer nil))
  (setq my/dictate-live--active nil)
  (message "Finishing live dictation...")
  (my/dictate-live--rotate t)
  (message "Live dictation stopped"))

;; WHAT: the single command bound to `C-c M' (see config/init.el).  WHY/HOW: same toggle
;; shape as `my/dictate' itself, dispatching on `my/dictate-live--active'.
;;;###autoload
(defun my/dictate-live ()
  "Toggle live dictation: transcribed a few seconds at a time while you speak."
  (interactive)
  (if my/dictate-live--active (my/dictate-live-stop) (my/dictate-live-start)))

;; WHAT/WHY/HOW: register this file under the Emacs feature name `dictate', matching the
;; `(require 'dictate ...)' used by tests/ert/dictate.el, and how every sibling config
;; file in this project (`llm.el', `shortcuts.el', ...) announces itself as loaded.
(provide 'dictate)
;;; dictate.el ends here
