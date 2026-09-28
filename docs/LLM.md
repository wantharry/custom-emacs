# Chatting with an LLM (gptel)

Status as of 2026-09-27, on Ubuntu 24.04 (WSL2) and the Windows bundle. Everything below
marked *measured* was run here, for real, against a real local Ollama server.

## What is set up

| Piece | What it does | Where |
|---|---|---|
| `gptel` (package) | the chat client: `C-c a a` opens a buffer, `C-c a m` its menu | `config/elpa`, installed by `./build.sh packages` |
| `config/llm.el` | registers the Ollama backend, reading real models from Ollama's own API | tracked |
| Ollama backend | a local model server, no API key, no network egress | `my/llm-setup-ollama`, run automatically the first time |

Nothing loads until `C-c a a` or `C-c a m` is pressed: like Consult, Magit and Treemacs,
`gptel` costs nothing at startup (see `config/init.el`'s own explicit `autoload`s ---
this config never loads package.el's own generated autoloads file, for
startup speed; see the "Packages" section of `init.el` for why).

## How it works

`C-c a a` (`my/llm-chat`) does two things the first time it runs:

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

## Known limits

- No language-server-style code assistance here; this is a general chat client, not
  Eglot (see [EGLOT.md](EGLOT.md) and [LANGUAGES.md](LANGUAGES.md) for that).
- `gptel-org.el` (one file inside the `gptel` package, for rendering chats as Org
  markup) fails to byte-compile in this build: this Emacs ships only a small trimmed
  slice of Org (`org-macs`, `org-element-ast`), not the full `org-element` that file
  needs, since Org is one of the packages this minimal build deliberately does not
  carry in full (see `prune.list`). This is harmless: nothing here `require`s
  `gptel-org`, and the rest of the package (including the Ollama backend and the
  plain-text chat buffer) is unaffected.
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
