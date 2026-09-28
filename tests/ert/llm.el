;;; llm.el --- chatting with an LLM (gptel) works, and Ollama's real models are found  -*- lexical-binding: t; -*-
;; harness: config
;; Real-service tests (a real HTTP round trip through Ollama) only run with RUN_LSP_TESTS=1
;; (tests/run-all.sh --lsp): the same opt-in flag as the real jdtls/rust-analyzer sessions
;; in languages-java-rust.el, since this is the same kind of thing --- a real, already-
;; running local service, not something every environment running `./build.sh test' has.

(require 'llm (expand-file-name "llm" (or (getenv "CONFIG_DIR") user-emacs-directory)))

(defmacro llm-need-gptel ()
  `(skip-unless (locate-library "gptel")))

;;; Wiring

(ert-deftest llm/keys-are-bound ()
  (should (eq (key-binding (kbd "C-c a a")) 'my/llm-chat))
  (when (locate-library "gptel")
    (should (eq (key-binding (kbd "C-c a m")) 'gptel-menu))))

(ert-deftest llm/is-not-loaded-until-used ()
  (let ((out (with-output-to-string
               (with-current-buffer standard-output
                 (call-process test-emacs nil t nil "--batch" "--init-directory" (getenv "CONFIG_DIR")
                               "-l" (expand-file-name "early-init.el" (getenv "CONFIG_DIR"))
                               "-l" (expand-file-name "init.el" (getenv "CONFIG_DIR"))
                               "--eval" "(princ (list (featurep 'llm) (featurep 'gptel) (autoloadp (symbol-function 'my/llm-chat))))")))))
    (should (string-match-p "(nil nil t)" out))))

(ert-deftest llm/does-not-slow-startup ()
  (let ((best most-positive-fixnum))
    (dotimes (_ 3)
      (let ((t0 (float-time)))
        (call-process test-emacs nil nil nil "--batch" "--init-directory" (getenv "CONFIG_DIR")
                      "-l" (expand-file-name "early-init.el" (getenv "CONFIG_DIR"))
                      "-l" (expand-file-name "init.el" (getenv "CONFIG_DIR"))
                      "--eval" "(kill-emacs)")
        (setq best (min best (- (float-time) t0)))))
    (should (< best 0.5))))

;;; Parsing Ollama's `/api/tags' response, without needing a real server reachable

(defconst llm--sample-tags-json
  "{\"models\":[{\"name\":\"hermes3:8b\",\"model\":\"hermes3:8b\"},{\"name\":\"qwen2.5-coder:7b\",\"model\":\"qwen2.5-coder:7b\"}]}")

(defun llm--fake-http-buffer (body)
  "A buffer shaped like what `url-retrieve-synchronously' hands back: HTTP headers,
a blank line, then BODY, exactly the part `my/llm-ollama-models' looks for."
  (let ((buf (generate-new-buffer " *llm-test-http*")))
    (with-current-buffer buf
      (insert "HTTP/1.1 200 OK\nContent-Type: application/json\n\n" body))
    buf))

(ert-deftest llm/ollama-models-parses-a-real-looking-api-response ()
  (llm-need-gptel)
  (cl-letf (((symbol-function 'url-retrieve-synchronously)
             (lambda (&rest _) (llm--fake-http-buffer llm--sample-tags-json))))
    (should (equal (my/llm-ollama-models) '(hermes3:8b qwen2.5-coder:7b)))))

(ert-deftest llm/ollama-models-is-nil-when-the-server-is-not-reachable ()
  ;; `url-retrieve-synchronously' returns nil on a connection failure/timeout (it never
  ;; signals in that case); either way this must come back nil, not error.
  (cl-letf (((symbol-function 'url-retrieve-synchronously) (lambda (&rest _) nil)))
    (should-not (my/llm-ollama-models))))

(ert-deftest llm/ollama-models-is-nil-if-the-response-is-not-valid-json ()
  (cl-letf (((symbol-function 'url-retrieve-synchronously)
             (lambda (&rest _) (llm--fake-http-buffer "not json at all"))))
    (should-not (my/llm-ollama-models))))

;;; Setting up the backend

;; Each test here starts from `gptel-backend' nil, regardless of what an earlier test (or
;; a real backend-setup test that only runs with RUN_LSP_TESTS=1) left it as: `gptel-backend'
;; is a global, so nothing here can assume what state a previous test left it in.

(ert-deftest llm/setup-ollama-uses-the-real-models-when-available ()
  (llm-need-gptel)
  (require 'gptel-ollama)
  (let (gptel-backend)
    (cl-letf (((symbol-function 'my/llm-ollama-models) (lambda () '(alpha:1b beta:2b))))
      (my/llm-setup-ollama)
      (should (gptel-ollama-p gptel-backend))
      (should (equal (gptel-backend-host gptel-backend) my/llm-ollama-host))
      (should (equal (gptel-backend-models gptel-backend) '(alpha:1b beta:2b))))))

(ert-deftest llm/setup-ollama-falls-back-to-a-placeholder-model-when-the-list-fails ()
  (llm-need-gptel)
  (require 'gptel-ollama)
  (let (gptel-backend)
    (cl-letf (((symbol-function 'my/llm-ollama-models) (lambda () nil))
              ((symbol-function 'message) (lambda (&rest _) nil)))
      (my/llm-setup-ollama)
      (should (gptel-backend-models gptel-backend)))))

(ert-deftest llm/chat-sets-up-ollama-only-once ()
  (llm-need-gptel)
  (require 'gptel-ollama)
  (let (gptel-backend (calls 0))
    (cl-letf (((symbol-function 'my/llm-setup-ollama) (lambda () (cl-incf calls) (setq gptel-backend (gptel--make-ollama))))
              ((symbol-function 'call-interactively) (lambda (_cmd) nil)))
      (my/llm-chat)
      (my/llm-chat)
      (should (= 1 calls)))))

;;; Following a response: gptel itself restores point to wherever it was before
;;; inserting a response (`save-excursion', in case something else was going on in
;;; the buffer); this config moves it to the end of the response instead, so the
;;; chat buffer follows along.

(ert-deftest llm/follow-response-moves-point-to-the-responses-end ()
  (with-temp-buffer
    (insert "some text before, where point happened to be\n")
    (goto-char (point-min))
    (my/llm--follow-response (point-min) 12)
    (should (= (point) 12))))

(ert-deftest llm/follow-response-is-hooked-into-gptel ()
  (llm-need-gptel)
  (require 'gptel)
  (should (memq #'my/llm--follow-response gptel-post-response-functions)))

;;; Against the real, already-running Ollama in this environment (skips if unreachable).
;;; Neither test needs the `ollama' command itself on PATH --- only the server, over HTTP.

(ert-deftest llm/the-real-ollama-reports-at-least-one-model ()
  (let ((models (my/llm-ollama-models)))
    (skip-unless models)                ; the server might not be running right now
    (should (cl-every #'symbolp models))
    (should (> (length models) 0))))

(ert-deftest llm/a-real-chat-request-through-ollama-gets-a-real-answer ()
  ;; Opt-in only: a real HTTP round trip to a real, already-running local model.
  (skip-unless (getenv "RUN_LSP_TESTS"))
  (llm-need-gptel)
  (skip-unless (my/llm-ollama-models))
  (require 'gptel-ollama)
  (let ((gptel-backend gptel-backend))  ; isolate: do not leak this real backend to later tests
    (my/llm-setup-ollama)
    (skip-unless (gptel-backend-models gptel-backend))
    (let ((gptel-model (car (gptel-backend-models gptel-backend)))
          (response nil) (done nil))
      (gptel-request "Reply with exactly one word: PONG"
        :callback (lambda (resp _info) (setq response resp done t)))
      (let ((n 0))
        (while (and (not done) (< n 300)) (accept-process-output nil 0.2) (setq n (1+ n))))
      (should done)
      (should (stringp response))
      (should (> (length response) 0)))))

;;; llm.el ends here
