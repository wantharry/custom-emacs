;;; ai-tools.el --- four AI coding-assistant tools, installed side by side to compare  -*- lexical-binding: t; -*-

;; `dev-ui-ai' branch only.  User request, after being told what exists for two
;; distinct things: Copilot-style automatic inline completion ("type the method, the
;; code appears"), and Cursor/Copilot-Workspace-style project-wide agentic editing
;; ("ask it to improve performance, it reads the project and makes the fix") ---
;; "let's figure out which is good, install all so we can test it."  Two tools per
;; category, so none of this is on by default or merged into `dev-ui' until it has
;; actually been tried:
;;
;; Ghost-text completion (pick ONE at a time per buffer --- running both together
;; would show two competing overlays):
;;   - `copilot-mode'  (the official GitHub Copilot client)
;;   - `wingman-mode'  (local-first; Native FIM needs a real llama.cpp server, not
;;     set up here --- Emulated FIM, manually triggered, uses gptel/Ollama, already
;;     configured in config/llm.el)
;;
;; Project-wide agentic editing:
;;   - `aidermacs-transient-menu'  (wraps the real `aider' CLI --- see tools/aider/)
;;   - `claude-code-ide-menu'      (runs the real `claude' CLI via MCP)
;;
;; See docs/AI-TOOLS.md for the full comparison notes, what was and was not
;; verified, and how to actually run each.

;;; Ghost-text completion

;; `copilot-login' needs a real GitHub account with an active Copilot subscription
;; --- an interactive OAuth device-flow login this config cannot do on your behalf.
;; `copilot-install-server' (downloads the real `copilot-language-server' binary) is
;; safe to run non-interactively and is NOT done automatically here, for the same
;; reason nothing else in this file runs unattended: run it yourself, once, the
;; first time you actually want to try this one.
(with-eval-after-load 'copilot
  (define-key copilot-completion-map (kbd "<tab>") #'copilot-accept-completion)
  (define-key copilot-completion-map (kbd "TAB") #'copilot-accept-completion)
  (define-key copilot-completion-map (kbd "C-<tab>") #'copilot-accept-completion-by-word)
  (define-key copilot-completion-map (kbd "C-n") #'copilot-next-completion)
  (define-key copilot-completion-map (kbd "C-p") #'copilot-previous-completion))

;; `wingman-prefix-key' must be set before `wingman' loads --- same ordering rule
;; `persp-mode-prefix-key'/`projectile-keymap-prefix' already need in config/init.el,
;; confirmed the same way: it is read once, building `wingman-mode-prefix-map' as the
;; package loads.  `C-c w' (the package's own documented default) is already this
;; config's session-management prefix (`C-c w s'/`w r'/etc, config/emacs-session.el)
;; --- confirmed live via `key-binding', not just grep, the same lesson learned
;; earlier this session with `C-c P'/`C-c j'.  `C-c z' is free.
(setq wingman-prefix-key (kbd "C-c z"))

;;; Project-wide agentic editing

;; `aider' itself (a separate, real Python CLI tool, not an Emacs package) is
;; installed self-contained into tools/aider/.venv/ --- same "not system-wide" shape
;; as tools/node-lsp/ and tools/node/ above it on this branch --- its own bin/ added
;; to `exec-path'/`PATH' the same two-step way (see config/init.el's own comment on
;; why `exec-path' alone is not enough for `compile'/shell-subprocess tools).
(defvar my/aider-bin-dir (expand-file-name "../tools/aider/.venv/bin" user-emacs-directory)
  "Where this branch's own locally-installed `aider' CLI lives --- see tools/aider/.")
(when (file-directory-p my/aider-bin-dir)
  (add-to-list 'exec-path my/aider-bin-dir)
  (setenv "PATH" (concat my/aider-bin-dir path-separator (getenv "PATH"))))
(with-eval-after-load 'aidermacs
  (when (file-directory-p my/aider-bin-dir)
    (setq aidermacs-program (expand-file-name "aider" my/aider-bin-dir)))
  ;; Ollama by default --- reuses config/llm.el's own `my/llm-ollama-host' rather
  ;; than a second, separately-maintained host string; `ollama_chat/' (not plain
  ;; `ollama/') is litellm's own convention for Ollama's chat-completions endpoint,
  ;; confirmed directly in Aider's own docs, not guessed. No API key needed or set
  ;; anywhere in this file, which is tracked by git --- the same reason config/llm.el
  ;; never puts one here either.
  (require 'llm (expand-file-name "llm" user-emacs-directory))
  (setenv "OLLAMA_API_BASE" (concat "http://" my/llm-ollama-host))
  (setq aidermacs-default-model "ollama_chat/hermes3:8b"))

(provide 'ai-tools)
;;; ai-tools.el ends here
