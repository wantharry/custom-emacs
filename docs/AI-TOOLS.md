# AI coding-assistant tools, compared (`dev-ui-ai` branch)

Status as of 2026-10-28. User request, after asking whether Emacs has anything like
IntelliJ/VS Code's inline AI completion, and anything like Cursor/Copilot Workspace's
"read the whole project and fix it" agentic editing: "let's figure out which is
good, install all so we can test it." Four tools installed side by side, on their
own branch (`dev-ui-ai`, off `dev-ui`), **not merged anywhere** until actually tried
for real.

## What is set up

| Tool | Category | Key | What it needs that this config cannot provide |
|---|---|---|---|
| [`copilot.el`](https://github.com/copilot-emacs/copilot.el) | ghost-text completion | `C-c b` (menu); `copilot-mode` to enable | a real GitHub account with an active Copilot subscription (`M-x copilot-login`, an interactive OAuth device-flow login) |
| [`wingman.el`](https://github.com/mjrusso/wingman) | ghost-text completion | `C-c z` (prefix); `wingman-mode` to enable | nothing, for Emulated FIM mode --- see below for what Native FIM would additionally need |
| [`aidermacs`](https://github.com/MatthewZMD/aidermacs) | project-wide agentic editing | `C-c A` | nothing to configure; **running an actual autonomous edit is a decision only you should make**, see "What was deliberately never run" below |
| [`claude-code-ide.el`](https://github.com/manzaltu/claude-code-ide.el) | project-wide agentic editing | `C-c C-'` | nothing to configure; same caveat as aidermacs |

Only ONE of the two ghost-text tools should be enabled per buffer at a time --- running
both together would show two competing overlays. Try one with `M-x copilot-mode`,
the other with `M-x wingman-mode`; there is no switcher command, by design, since
comparing them is the whole point of this branch.

Nothing loads at startup --- confirmed the same way as every other optional package in
this config (`startup/no-third-party-features-loaded`, extended with all four of
these). Each loads the first time its own key, or `M-x`, actually reaches it.

## Installation

`copilot`/`aidermacs` are on MELPA/NonGNU ELPA; `wingman`/`claude-code-ide` are not on
any package archive (confirmed directly against a real `package-refresh-contents`,
not assumed) and install via `package-vc-install` instead --- all four are listed in
`tools/install-packages.el`, installed the normal way with `./build.sh packages`.

`aider` itself --- the real Python CLI `aidermacs` drives, a separate tool, not an
Emacs package --- is installed self-contained into `tools/aider/.venv/` (Python 3.12,
confirmed as the version Aider currently supports), the same "not system-wide" shape
as `tools/node-lsp/`/`tools/node/` on `dev-ui`:

```
python3 -m venv tools/aider/.venv
tools/aider/.venv/bin/pip install aider-chat
```

Its `bin/` is added to both `exec-path` and `PATH` (see config/ai-tools.el, and
config/init.el's own comment on why `exec-path' alone is not enough for `compile'-
style invocations --- the same real gap found and fixed on `dev-ui` for the npm/Nest/
Angular CLI commands).

## What was actually verified, and how

- **`wingman' Emulated FIM**: a real, non-interactive request/response round trip
  against this machine's own already-running Ollama server (model `hermes3:8b`,
  reusing `config/llm.el`'s existing setup) --- confirmed a real ghost-text overlay
  appeared with real suggested text. This is the one thing in this whole comparison
  that is both fully testable AND genuinely safe to automate (a single read-only
  completion request, not an agent making file edits) --- it is the only one with a
  real, repeatable ERT test (`tests/ert/ai-tools.el`,
  `at/wingman-emulated-fim-gets-a-real-completion-from-ollama`).
- **`copilot-install-server`**: confirmed it really downloads the real
  `copilot-language-server' binary (version 1.562.0 at the time of writing) via a
  real `npm install`, non-interactively --- safe to run, and genuinely different from
  `copilot-login`, which this config cannot do on your behalf.
- **`aidermacs`/`aider`**: confirmed the CLI itself installs and runs (`aider
  --version`), and that `aidermacs-program`/`aidermacs-default-model`/
  `OLLAMA_API_BASE` are all correctly wired to this machine's real local `aider` and
  Ollama server. **Not** confirmed: an actual autonomous edit --- see below.
- **`claude-code-ide'**: confirmed the real `claude` CLI and `vterm` are both found,
  the menu command is bound and callable, and `claude-code-ide-emacs-tools-setup`
  (exposing real Emacs commands --- xref, tree-sitter, project info --- as MCP tools)
  runs without error. **Not** confirmed: an actual live session.

## What was deliberately never run

Two real, separate things stopped a full end-to-end "ask it to fix something, watch
it edit files" test of the two agentic tools:

1. **A real safety classifier refusal, not a workaround target.** Running `aider
   --yes-always --message "..."` directly (to test an autonomous edit the same way
   the other three tools were tested) was refused by the Bash tool's own permission
   classifier: "Create Unsafe Agents." This is correct, not a bug to route around ---
   spawning an autonomous coding agent with no human reviewing its actions as they
   happen is exactly the class of action that check exists to catch, whether invoked
   via a shell command or through Emacs.
2. **The same concern applies just as much from inside Emacs.** Actually starting a
   live `aidermacs`/`claude-code-ide` session and then typing an instruction into it
   myself would be the identical unsupervised-agent pattern, just through a
   different front door --- not something this session should do on your behalf
   either. **This is the one thing left for you to try by hand**: `C-c A` then `a`
   (start an Aider session) or `C-c C-'` then start a session, work inside it
   interactively, and judge for yourself which of the two actually does what you
   want on a real task.

## Known rough edges (observed, not fixed)

- `wingman`'s Emulated FIM run above also logged `[error] request--callback:
  peculiar error` and `wingman: background prime failed for project 'global'` ---
  neither stopped the real completion from working, but neither was investigated
  further; likely wingman's own project-context-priming feature hitting something
  this machine's setup does not satisfy.
- `wingman`'s **Native FIM** mode (the fully-automatic, no-manual-trigger mode most
  comparable to Copilot) needs a real `llama.cpp` server (its own `/infill`
  endpoint, not Ollama's API) running a FIM-capable model --- not set up on this
  branch; Emulated FIM (manually triggered, via gptel) is what was actually tried.
- `copilot-login`'s interactive OAuth device-flow needs a real GitHub account with
  an active Copilot subscription --- only you can do this step.

See `tests/ert/ai-tools.el` for the real, repeatable checks, and `config/ai-tools.el`
for the full WHAT/WHY on every piece of wiring.
