;;; ai-tools.el --- four AI coding-assistant tools, compared (dev-ui-ai branch)  -*- lexical-binding: t; -*-
;; harness: config
;; `dev-ui-ai'-only. See docs/AI-TOOLS.md for the full comparison write-up, including
;; what was and was not verified by hand (copilot needs a real GitHub login this
;; config cannot do for you; aidermacs/claude-code-ide were deliberately never run
;; through an actual autonomous edit from this test suite either --- same reason the
;; Bash tool itself refused to run `aider --yes-always' directly: an unsupervised
;; coding agent acting with no human in the loop, which a TEST SUITE running
;; unattended is definitionally not able to supervise any better than a shell
;; command was).  What IS checked here for real: wiring (keys, exec-path/PATH,
;; config values), and --- gated behind a real, reachable Ollama server, the same
;; opt-in shape as `RUN_LSP_TESTS' --- a real `wingman' Emulated FIM completion
;; request, since that one genuinely needs no human supervision to verify (a single
;; read-only completion request/response, not an agent making file edits).

(defun at--skip-unless-ollama ()
  (unless (ignore-errors (url-retrieve-synchronously (format "http://%s/api/tags" my/llm-ollama-host) t t 3))
    (ert-skip "no reachable Ollama server at my/llm-ollama-host")))

;;; Wiring: keys, nothing loads eagerly

(ert-deftest at/copilot-key-is-bound-when-installed ()
  (skip-unless (locate-library "copilot"))
  (should (eq (key-binding (kbd "C-c b")) #'copilot-menu)))

(ert-deftest at/aidermacs-key-is-bound-when-installed ()
  (skip-unless (locate-library "aidermacs"))
  (should (eq (key-binding (kbd "C-c A")) #'aidermacs-transient-menu)))

(ert-deftest at/claude-code-ide-key-is-bound-when-installed ()
  (skip-unless (locate-library "claude-code-ide"))
  (should (eq (key-binding (kbd "C-c C-'")) #'claude-code-ide-menu)))

(ert-deftest at/missing-tool-fallback-is-clear ()
  (dolist (spec '(("copilot" . "C-c b") ("aidermacs" . "C-c A") ("claude-code-ide" . "C-c C-'")))
    (unless (locate-library (car spec))
      (should (eq (key-binding (kbd (cdr spec))) #'my/ai-tool-missing)))))

;; "Nothing loads at startup" is checked in tests/ert/startup-perf.el's own
;; `startup/no-third-party-features-loaded' instead of here --- that test needs a
;; process where NOTHING has required these features yet, which this file's own
;; other tests (deliberately requiring copilot/wingman/aidermacs to check their
;; real config) would immediately violate if both lived in the same shared-process
;; test file; `tests/run-all.sh' gives every ERT FILE its own fresh process, so the
;; concern is file-scoped, not just test-scoped.

;;; Wiring: the two tools NOT on any package archive (my/vc-packages, not
;;; my/packages) really got checked that way before being added, not assumed

(ert-deftest at/wingman-and-claude-code-ide-are-really-not-on-any-archive ()
  (skip-unless (and (locate-library "wingman") (locate-library "claude-code-ide")))
  (require 'package)
  (unless package-archive-contents (ignore-errors (package-refresh-contents)))
  (skip-unless package-archive-contents)
  (should-not (assq 'wingman package-archive-contents))
  (should-not (assq 'claude-code-ide package-archive-contents)))

;;; Aider: the separate, real CLI tool aidermacs drives (tools/aider/), and the
;;; Ollama wiring config/ai-tools.el sets up for it

;; `my/aider-bin-dir' is defined inside config/ai-tools.el, which --- by design,
;; see config/init.el's own comment --- only loads via `with-eval-after-load
;; 'aidermacs', not merely because `(locate-library "aidermacs")' found the file on
;; disk; a real `(require 'aidermacs)' first is what actually triggers it (caught
;; directly: an earlier version of these two tests skipped, via `skip-unless' own
;; error-swallowing, on a `(void-variable my/aider-bin-dir)' it never surfaced
;; until checked by hand outside `skip-unless').
(defmacro at--skip-unless-aider-installed ()
  '(progn (require 'aidermacs) (skip-unless (file-directory-p my/aider-bin-dir))))

(ert-deftest at/aider-bin-dir-is-on-exec-path-and-path-when-present ()
  (skip-unless (locate-library "aidermacs"))
  (at--skip-unless-aider-installed)
  (should (member my/aider-bin-dir exec-path))
  (should (member my/aider-bin-dir (split-string (getenv "PATH") path-separator))))

(ert-deftest at/aider-binary-is-executable ()
  (skip-unless (locate-library "aidermacs"))
  (at--skip-unless-aider-installed)
  (should (file-executable-p (expand-file-name "aider" my/aider-bin-dir))))

(ert-deftest at/aidermacs-points-at-the-real-local-aider ()
  (skip-unless (locate-library "aidermacs"))
  (at--skip-unless-aider-installed)
  (require 'aidermacs)
  (should (equal aidermacs-program (expand-file-name "aider" my/aider-bin-dir))))

(ert-deftest at/aidermacs-defaults-to-the-existing-ollama-setup ()
  ;; Reuses config/llm.el's own `my/llm-ollama-host' rather than a second,
  ;; separately-maintained host string --- checked directly, not just that SOME
  ;; value got set.
  (skip-unless (locate-library "aidermacs"))
  (require 'aidermacs)
  (should (equal aidermacs-default-model "ollama_chat/hermes3:8b"))
  (should (equal (getenv "OLLAMA_API_BASE") (concat "http://" my/llm-ollama-host))))

;;; wingman: Emulated FIM (gptel/Ollama) --- `wingman-prefix-key' must be set
;;; before the package loads, same ordering rule `projectile-keymap-prefix'/
;;; `persp-mode-prefix-key' already need elsewhere in this config

(ert-deftest at/wingman-prefix-key-is-not-the-conflicting-c-c-w-default ()
  (skip-unless (locate-library "wingman"))
  ;; `C-c w' is already this config's session-management prefix, a real keymap
  ;; (`C-c w s'/`w r'/etc, config/emacs-session.el) --- confirmed live via
  ;; `key-binding', not just grep, before `wingman-prefix-key' was set to `C-c z'
  ;; instead.
  (should (equal wingman-prefix-key (kbd "C-c z")))
  (should (eq (key-binding (kbd "C-c w s")) 'my/session-save)))

;; A real, confirmed request/response round trip against the actual Ollama server
;; already running on this machine --- not a mock, and not gated behind
;; `RUN_LSP_TESTS' (a different opt-in than the LSP servers above, since this is a
;; single read-only completion round trip, not a long-lived server connection).
(ert-deftest at/wingman-emulated-fim-gets-a-real-completion-from-ollama ()
  (skip-unless (locate-library "wingman"))
  (at--skip-unless-ollama)
  (require 'wingman) (require 'gptel)
  (require 'llm (expand-file-name "llm" user-emacs-directory))
  (my/llm-setup-ollama)
  (test-with-temp-dir d
    (let ((buf (find-file-noselect (test-write-file (concat d "bubble.py") "def bubble_sort(arr):\n"))))
      (unwind-protect
          (with-current-buffer buf
            (wingman-mode 1)
            (goto-char (point-max))
            (let* ((ctx (wingman--collect-local-context))
                   (prompt (wingman--build-emulated-fim-prompt ctx)))
              (wingman--gptel-fim-request "Ollama" "hermes3:8b" prompt))
            (let ((deadline (+ (float-time) 40)))
              (while (and (not (bound-and-true-p wingman--hint-overlay)) (< (float-time) deadline))
                (sleep-for 0.5)))
            (should (overlayp (bound-and-true-p wingman--hint-overlay))))
        (kill-buffer buf)))))

;;; copilot: the real language-server binary --- an npm install this config can run
;;; non-interactively (confirmed directly: it only downloads a binary, same as
;;; copilot.el's own `copilot-install-server'), unlike `copilot-login' itself (a
;;; real OAuth device-flow login this config cannot do on your behalf, so it is
;;; never run here, and nothing below depends on having actually logged in)

(ert-deftest at/copilot-completion-map-keys-are-bound ()
  (skip-unless (locate-library "copilot"))
  (require 'copilot)
  (should (eq (lookup-key copilot-completion-map (kbd "<tab>")) #'copilot-accept-completion))
  (should (eq (lookup-key copilot-completion-map (kbd "C-n")) #'copilot-next-completion)))

;;; ai-tools.el ends here
