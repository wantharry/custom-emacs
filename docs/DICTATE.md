# Dictation: speech-to-text into the buffer (local Whisper)

Status as of 2026-09-28, on Ubuntu 24.04 (WSL2) **and** on the Windows bundle.
Everything marked *measured* was run for real on both, using a synthesized test
sentence (since testing can't literally speak into a microphone) played through the
same real recording/transcription pipeline `C-c m` uses.

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

## Works on both platforms, with genuinely different plumbing

Recording and stopping cleanly are handled completely differently per platform,
both confirmed necessary for real, not just theoretical:

| | Linux/WSL | Windows |
|---|---|---|
| Records the mic | `parecord` (PulseAudio) | `ffmpeg` (`-f dshow`) |
| Which device | PulseAudio's own default source | auto-detected from `ffmpeg -list_devices` (first audio device found), cached in `my/dictate-audio-device` |
| Stopping cleanly | an explicit `SIGTERM`, waited out | writing `"q"` to its stdin, waited out --- there is no SIGTERM-equivalent signal to send a Windows process at all |
| `whisper-cli` binary | built natively (`cmake` + `g++`) | **cross-compiled from WSL** using `zig cc`/`zig c++` targeting `x86_64-windows-gnu` (the same toolchain this project already uses for the Windows tree-sitter grammars and `Emacs.exe` itself) --- no Windows compiler needed at all |

*Measured*, both platforms, same result: 100% correct transcription of the same test
sentence, in ~3.6-3.8 seconds either way (real device auto-detected as "Microphone
(Logitech BRIO)" on the Windows test machine; real recording process confirmed live;
real clean stop; real transcription; all via the actual `C-c m` code path).

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

### For the Windows bundle (built entirely from WSL, no Windows compiler needed)

No prebuilt Windows binary is published upstream, and no Windows C++ toolchain is
needed here: `whisper-cli.exe` is cross-compiled from WSL using `zig cc`/`zig c++`,
the exact same approach `tools/dist-windows.sh` already uses for the tree-sitter
grammars and `Emacs.exe` itself. `-DGGML_NATIVE=OFF` alone would build with no CPU
SIMD at all (*measured*: a real ~7.5x slowdown, 28.5s instead of 3.7s for the same
clip) --- enabling AVX2/FMA/F16C explicitly instead gets full speed back while
staying portable to any CPU from roughly 2013 onward, not just the exact build
machine's:

```sh
# a small wrapper, since CMake wants a single compiler executable
cat > zigcc  <<'EOF'
#!/bin/sh
exec python3 -m ziglang cc -target x86_64-windows-gnu "$@"
EOF
cat > zigcxx <<'EOF'
#!/bin/sh
exec python3 -m ziglang c++ -target x86_64-windows-gnu "$@"
EOF
chmod +x zigcc zigcxx
pip install ziglang   # or use this project's own dist/.venv, which already has it

cmake -B build-win -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_SYSTEM_NAME=Windows -DCMAKE_SYSTEM_PROCESSOR=x86_64 \
  -DCMAKE_C_COMPILER=./zigcc -DCMAKE_CXX_COMPILER=./zigcxx \
  -DCMAKE_C_COMPILER_WORKS=1 -DCMAKE_CXX_COMPILER_WORKS=1 \
  -DGGML_OPENMP=OFF -DGGML_NATIVE=OFF \
  -DGGML_AVX=ON -DGGML_AVX2=ON -DGGML_FMA=ON -DGGML_F16C=ON -DGGML_SSE42=ON \
  -DWHISPER_SDL2=OFF -DBUILD_SHARED_LIBS=OFF
cmake --build build-win -j"$(nproc)" --target whisper-cli
```

`-DBUILD_SHARED_LIBS=OFF` makes `whisper-cli.exe` fully static --- just the one
`.exe`, no DLLs to carry alongside it. Copy it and the model to
`%USERPROFILE%\.local\share\whisper-cpp\` (`whisper-cli.exe` directly in that
folder, the model under `models\`), matching the Linux layout exactly (`~` resolves
to `%USERPROFILE%` in this bundle's own launcher). `ffmpeg` needs to be on `PATH`
separately (not part of this project); it is not bundled either, same reasoning as
the JDK and Node.js.

### Custom paths

If you put the binary/model somewhere else, set these in your own config (they are
plain `defvar`s in `config/dictate.el`, safe to `setq` after it loads):

```elisp
(setq my/dictate-whisper-cli "/path/to/whisper-cli"
      my/dictate-model       "/path/to/ggml-small.en.bin"
      my/dictate-lib-dir     "/path/to/its/shared/libs")   ; Linux/WSL only
```

On Windows, if the auto-detected microphone (the first one `ffmpeg -list_devices`
reports) is not the one you want, set it explicitly instead of letting it
auto-detect:

```elisp
(setq my/dictate-audio-device "Microphone (Your Device Name)")
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
- Windows: the microphone is auto-detected as the *first* audio device `ffmpeg`
  reports, which may not be the one you want on a machine with several (set
  `my/dictate-audio-device` explicitly in that case). `ffmpeg` itself is not
  bundled and must already be on `PATH`.
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
