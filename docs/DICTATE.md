# Dictation: speech-to-text into the buffer (local Whisper)

Status as of 2026-09-28, on Ubuntu 24.04 (WSL2). Everything marked *measured* was run
here, for real, using a synthesized test sentence (since testing can't literally speak
into a microphone) played through the same real recording/transcription pipeline `C-c m`
uses.

## What is set up

`C-c m` (`my/dictate`) toggles dictation: press it once to start recording from the
microphone, press it again to stop --- the recording is transcribed and the resulting
text is inserted at the point where you started. Runs entirely locally: no cloud, no
API key, no network request of any kind.

| Piece | What it does | Where |
|---|---|---|
| `parecord` (PulseAudio) | records the microphone to a WAV file | already on this system; not bundled |
| `whisper-cli` (whisper.cpp) | transcribes the WAV file | self-built; not bundled (see below) |
| a GGML model (`ggml-small.en.bin`) | what `whisper-cli` transcribes with | downloaded separately; not bundled (465 MB) |
| `config/dictate.el` | wires the above into `C-c m` | tracked |

Nothing loads, and no process starts, until `C-c m` is pressed; if `parecord`,
`whisper-cli` or the model are missing, it says exactly which one in the echo area
instead of failing confusingly.

## Why local, not cloud, and why CPU here (not GPU)

This machine has a real NVIDIA GPU (`nvidia-smi` works), but **no CUDA toolkit and no
NVIDIA Vulkan driver** are installed --- only the display/graphics passthrough WSLg
itself needs. Installing either needs a system package install (`sudo apt-get install
cuda-toolkit-...`), which this environment could not do without a password. `whisper.cpp`
was built CPU-only as a result (16 threads available). See "Setting it up" below for the
exact commands to add a real CUDA toolkit and rebuild with GPU acceleration, if your
machine has one properly set up.

## A real bug this caught, and the fix

The first version of `my/dictate-stop` called `delete-process` alone to stop the
recording. *Measured*: this left a WAV file that **exists but is invalid** ---
`parecord` never got the chance to finalize its header, so the file is missing its
`fmt`/`data` chunks entirely (`wave.Error: fmt chunk and/or data chunk missing`).
Confirmed with a real, isolated test in each direction (`tests/ert/dictate.el`):

- `delete-process` alone → invalid WAV.
- An explicit `(signal-process proc 'SIGTERM)`, waited out (`process-live-p` goes to
  nil), *then* `delete-process` (just for Emacs's own bookkeeping) → a clean, valid,
  readable WAV, every time.

`my/dictate-stop` does the latter now.

## Measured

| What | Result |
|---|---|
| Transcription accuracy (`small.en` model, a synthesized test sentence with known text) | **100% correct**, word for word, with correct capitalization ("Emacs") added |
| Time to transcribe an 8-second clip | **~3.8 s** (faster than real-time), default thread count |
| Time with `-t 16` (all cores) instead | **~5.1 s** --- slower: more threads added overhead here, not less |
| `base.en` model, same clip | **~3.7 s**, same 100%-correct result --- no clear win over `small.en`, which is generally more robust on real (non-clean-synthetic) speech, so that stays the default |
| A clean SIGTERM (what `my/dictate-stop` sends) on a real recording | valid WAV, confirmed with a real recording + a real Python WAV-header check |
| Full pipeline, start to buffer insertion (real recording substituted with a known WAV before transcription, since testing can't speak) | text landed in the buffer at the exact marker where dictation started |

## Setting it up

Neither `whisper.cpp` nor its model is bundled with this project (the model alone is
hundreds of MB, and this is exactly the kind of dependency `docs/LANGUAGES.md`'s Node.js
discussion already weighed against bundling). Build and place them once:

```sh
# 1. PulseAudio's recording tool (usually already installed on WSLg/most desktops)
#    Debian/Ubuntu: sudo apt-get install -y pulseaudio-utils

# 2. whisper.cpp itself, CPU-only (works with no GPU at all)
git clone --depth=1 https://github.com/ggerganov/whisper.cpp.git
cd whisper.cpp
cmake -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build -j"$(nproc)"

# 3. a model --- small.en is the default this config expects
bash ./models/download-ggml-model.sh small.en

# 4. put the binary, its shared libraries, and the model where dictate.el looks
mkdir -p ~/.local/share/whisper-cpp/models
cp build/bin/whisper-cli ~/.local/share/whisper-cpp/
find build -name '*.so*' -exec cp -L {} ~/.local/share/whisper-cpp/ \;
cp models/ggml-small.en.bin ~/.local/share/whisper-cpp/models/
```

### With a real, working CUDA toolkit

If your machine actually has the NVIDIA CUDA toolkit installed (`nvcc --version`
works, unlike in this environment), reconfigure with `-DGGML_CUDA=ON` before building,
same steps otherwise:

```sh
cmake -B build -DCMAKE_BUILD_TYPE=Release -DGGML_CUDA=ON
cmake --build build -j"$(nproc)"
```

### Custom paths

If you put the binary/model somewhere else, set these in your own config (they are
plain `defvar`s in `config/dictate.el`, safe to `setq` after it loads):

```elisp
(setq my/dictate-whisper-cli "/path/to/whisper-cli"
      my/dictate-model       "/path/to/ggml-small.en.bin"
      my/dictate-lib-dir     "/path/to/its/shared/libs")
```

## Known limits

- English only by default (`small.en`); swap in a multilingual model (drop the `.en`)
  for other languages, at some cost to English accuracy.
- Push-to-talk, not continuous streaming: you get the transcription after you stop
  recording, not word-by-word as you speak. This is deliberate --- whisper.cpp's own
  real-time streaming mode is known to be less accurate (a sliding window that
  re-corrects itself), and this project's own test showed push-to-talk gets clean,
  100%-correct results.
- CPU-only in this environment specifically (no working CUDA toolkit or NVIDIA Vulkan
  driver here); real GPU acceleration needs the CUDA toolkit installed properly, which
  needs `sudo`.
- Whichever buffer/point was active when you pressed `C-c m` to *start* is where the
  text lands, even if you switch buffers while recording; if that buffer is killed
  before you stop, the transcription is reported in a message instead of inserted.

## Tests

`tests/ert/dictate.el`: wiring (key bound, nothing loaded until used, does not slow
startup), declining clearly when `parecord`/`whisper-cli`/the model is missing (without
needing any of them installed to test that), the start/stop/toggle state machine
(including that starting twice, or stopping when not recording, is a clear error).
Two tests touch the real, locally-built whisper.cpp in this environment (skip if
absent): that a clean stop really produces a valid WAV (the exact bug described above),
and the full pipeline end to end using a known pre-recorded WAV in place of a live
microphone.
