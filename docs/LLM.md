# Chatting with an LLM (gptel)

Status as of 2026-09-27, on Ubuntu 24.04 (WSL2) and the Windows bundle. Everything below
marked *measured* was run here, for real, against a real local Ollama server.

## What is set up

| Piece | What it does | Where |
|---|---|---|
| `gptel` (package) | the chat client: `C-c a a` opens a buffer, `C-c a m` its menu | `config/elpa`, installed by `./build.sh packages` |
| `config/llm.el` | registers the Ollama backend, reading real models from Ollama's own API | tracked |
| Ollama backend | a local model server, no API key, no network egress | `my/llm-setup-ollama`, run automatically the moment `gptel` loads at all |

Nothing loads until `gptel` is touched some way --- `C-c a a`, `C-c a m`, or anything
else that reaches it --- at which point Ollama becomes the active backend automatically,
**not** `gptel`'s own factory-default ChatGPT (a real OpenAI endpoint this config never
puts an API key behind; using it without one fails with a real 401 Unauthorized). The
hook that does this lives in `config/init.el` itself, not `config/llm.el` --- a real,
found-the-hard-way reason: `config/llm.el` is itself lazily autoloaded, only loaded the
first time `my/llm-chat`/`my/llm-council` runs, so a hook registered inside it would
never even be registered if `gptel` were reached some other way first (`C-c a m`
autoloads `gptel-transient` directly, for one). `config/init.el`'s own hook is always
present, and, like Consult, Magit and Treemacs, still costs nothing at startup (see
`config/init.el`'s own explicit `autoload`s --- this config never loads package.el's own
generated autoloads file, for startup speed; see the "Packages" section of `init.el` for
why) --- `with-eval-after-load` only registers a callback; nothing in it runs until
`gptel` is actually loaded, whichever of those paths gets there first.

## How it works

Whatever reaches `gptel` first --- `C-c a a`, `C-c a m`, or `gptel-mode` turned on
directly in some other buffer --- does two things, once, that first time:

1. Queries Ollama's own HTTP API (`GET /api/tags`) and turns its answer into the model
   list `gptel-menu` offers --- whatever you have pulled, right now, not a hand-
   maintained list that goes stale. This is a plain HTTP request (`url.el`, built into
   Emacs), **not** a call to the `ollama` command-line tool, deliberately: that tool is
   not on Windows' own `PATH` even when, as here, the server itself (running in WSL) is
   perfectly reachable from Windows --- querying the API directly works identically on
   both sides. *Measured*: 24 pulled models found this way, identically on WSL/Linux
   and on the Windows bundle, where `(executable-find "ollama")` is confirmed `nil`.
2. Registers that as a `gptel` backend (`gptel-make-ollama`), pointed at
   `my/llm-ollama-host` (default `localhost:11434`), and opens a chat buffer.

Every later `C-c a a` just reuses that backend and opens (or switches to) the chat
buffer; calling `M-x my/llm-setup-ollama` again re-queries the API, picking up anything
newly pulled or removed. `C-c a m` (`gptel-menu`) is gptel's own transient menu: pick a
different model from the ones just listed, switch system prompt, toggle streaming, or
switch backend entirely.

If the server is not reachable (down, or nothing listening on that host/port),
`my/llm-chat` still opens a chat buffer, with one placeholder model name and a message
saying so in the echo area, rather than failing outright.

## Works the same from WSL/Linux and from the Windows bundle

Ollama only needs to run **once**, in WSL/Linux (here, as a systemd service: `ollama
serve`, already running). Both sides reach it at the exact same address:

- **WSL/Linux Emacs**: `localhost:11434` directly (same machine).
- **Windows Emacs** (the portable bundle): also `localhost:11434` --- WSL2 forwards
  loopback ports both ways automatically, even though Ollama itself only listens on
  `127.0.0.1` inside WSL, not `0.0.0.0`. *Measured*: `Invoke-WebRequest
  http://localhost:11434/api/tags` from real Windows PowerShell returned Ollama's real
  model list, and so did Emacs itself on Windows (see below) --- with no `ollama.exe`
  installed there at all.

So `my/llm-ollama-host`'s default needs no changing on either side, and nothing runs
Ollama itself on Windows; Windows Emacs is only ever an HTTP client of the one instance
already running in WSL.

## Measured

| What | WSL/Linux | Windows bundle |
|---|---|---|
| Models found (from Ollama's own API, not the `ollama` command) | **24** | **24** (identical) |
| Is `ollama` (the CLI tool) on `PATH`? | yes | **no** --- and it does not need to be |
| A real request through `gptel-request`, asked to reply with one word | **"PONG"** (`qwen2.5-coder:7b`) | **"PONG"** (`qwen2.5-coder:7b`), reached over `localhost:11434` from Windows |
| Emacs startup cost | unchanged: `gptel` is not loaded until `C-c a a`/`C-c a m` | same |

## Adding a cloud backend (Anthropic, OpenAI, ...)

Ollama needs no key. A cloud backend does --- see the "Adding a cloud backend" section at
the bottom of `config/llm.el` for exactly where that goes: the key lives in
`~/.authinfo.gpg` (or `~/.authinfo`), **never** in `config/llm.el` itself, which is
tracked by git. Two ready-to-uncomment examples are there (Anthropic, OpenAI); `C-c a m`
then lets you switch to it per buffer.

## Point follows the response

gptel itself deliberately restores your cursor to wherever it was *before* a response
was inserted (it wraps the insertion in `save-excursion`, in case you were doing
something else in the buffer at the time) --- so by default, after asking a question,
point stays right where you left it (typically right after what you just typed), not at
the new reply. This config adds a small hook (`my/llm--follow-response`, on
`gptel-post-response-functions`) that moves point to the end of the response instead,
so the chat buffer follows along, which is what you want for a straightforward back-
and-forth conversation. *Measured*: confirmed with a real Ollama round trip.

## Asking a council of models at once (`C-c a c`)

`C-c a c` (`my/llm-council`, `config/llm-council.el`) asks one question of **three**
different local Ollama models **in parallel**, then sends a **fourth, bigger** model all
three answers and asks it to compare and summarize them. Everything lands in one buffer
(`*llm-council*`): the summary is expanded at the top; each model's own full answer is
folded shut below it (`outline-mode`, same as `my/shortcuts`/`my/docs` --- `TAB` to
expand/collapse, `q` to close), so you see the synthesis first and only dig into an
individual model's wording if you want to.

### Which models

Chosen by **size**, not by name or family: the three council models are whichever
pulled models are closest to `my/llm-council-target-size-gb` (2.5GB, i.e. "2-3GB") on
disk --- small and fast, so asking three of them in parallel doesn't noticeably slow the
machine down. The summarizer is chosen separately, closest to `my/llm-council-target-
summarizer-params-b` (7B) **parameters** --- a different unit on purpose, since a 7B
model at typical quantization is usually ~4GB on disk, not 2-3GB, so judging it by the
same disk-size window as the council would pick something far smaller than a real 7B
model. The summarizer is never the largest pull available: `my/llm-council-summarizer-
exclude` (`gpt-oss:20b`, `gpt-oss:20b-32k` here) rules those out outright, not just
deprioritizes them --- a real, explicit choice, not a default, made because that model
visibly slows this machine down for a task that doesn't need it.

Both come from a live query of Ollama's own `/api/tags` (`my/llm-council--available-
models`, alongside `/api/tags` size and parameter-count fields `my/llm-ollama-models`
itself doesn't need and so doesn't keep), filtered down to what is really pulled right
now --- nothing here needs to be kept in sync with any one machine's actual pulled
models. On a machine with fewer models pulled, it degrades gracefully: pads council with
whatever else is available (or no summarizer at all) rather than erroring, only refusing
outright (a clear `user-error`) if nothing is available at all --- with one real
exception: if **only one model total** is pulled, that one model is asked to fill both
roles (the council's only answer, and its own summarizer) instead of the summarizer
coming back empty just because the sole model "conflicts with itself".

### What happens when a model fails

Every request uses `:stream nil`, so each model's callback fires exactly once with its
whole answer (or nil on failure) --- no chunk-by-chunk re-folding. If one council model
fails, its section shows "no response" and it is simply left out of the prompt sent to
the summarizer (not included as a blank answer attributed to it). If every council model
fails, the summary is marked failed too and **no fourth request is ever sent** --- there
would be nothing to summarize.

### Measured

Verified for real against this environment's own Ollama server: a mocked-network test
suite (`tests/ert/llm-council.el`) checks the size/parameter-based model-picking
(including the excluded-summarizer and single-model-does-both-roles cases), folding,
and the whole request/failure/summarize flow deterministically; a real, opt-in round
trip (`--lsp`) sends 4 genuine requests to whichever models this machine's own pulled
set actually resolves to and confirms every section ends up `done`.

## Known limits

- No language-server-style code assistance here; this is a general chat client, not
  Eglot (see [EGLOT.md](EGLOT.md) and [LANGUAGES.md](LANGUAGES.md) for that).
- `gptel-org.el` (one file inside the `gptel` package, for rendering chats as Org
  markup) byte-compiles and works normally --- Org itself is no longer pruned (see
  [PRUNING.md](PRUNING.md)), so the full `org-element` it needs is present. Nothing here
  actually `require`s `gptel-org` by default either way (the plain-text chat buffer is
  what `C-c a a` uses), but it is no longer the *dead* code path it used to be when Org
  was still pruned down to just `org-macs`/`org-element-ast`.
- Multiple Ollama models can be pulled and switched between (`C-c a m`), but only one
  chat conversation's history is kept per gptel buffer; nothing here manages multiple
  named conversations.

## Tests

`tests/ert/llm.el`: wiring (key bound, nothing loaded until used, does not slow
startup), parsing Ollama's `/api/tags` response (including when the server is
unreachable or answers with something that is not valid JSON, without needing a real
server to test either case), backend setup (real models used when available, a
placeholder when not), that `C-c a a` only sets the backend up once, and that point
follows a response (both the plain move-to-end logic and that the hook is really
registered). Two tests
touch the real, already-running Ollama in this environment: one (skips if unreachable)
confirms its model list is readable; the other, a full request round trip, is opt-in
only (`RUN_LSP_TESTS=1`, the same flag `languages-java-rust.el` uses for real
language-server sessions), since it is a real network round trip to a real local
service, not something every environment running `./build.sh test` has pulled models
for.

`tests/ert/llm-council.el`: wiring; model picking (preferred list honored in order,
padding with whatever else is available, never repeating a model, excluding given
models, degrading to fewer than 3 council models or no summarizer, a clear `user-error`
with nothing available); the buffer (summary heading first, every model answer folded
shut but the summary open, close/fold keys); with `gptel-request` mocked (no real
network): each council model asked with its own `gptel-model` and `:stream nil`, the
summary firing only once all three answers are in, the summary prompt naming every
successful answer, a failed answer marked `failed` and excluded from that prompt, and
every model failing leaving the summary `failed` with no 4th request ever sent. One
test is a real, opt-in (`RUN_LSP_TESTS=1`) 4-request round trip against the Ollama
already running in this environment.
