;;; llm.el --- chat with an LLM from Emacs, via gptel  -*- lexical-binding: t; -*-

;; `C-c a a' opens a chat buffer; `C-c a m' opens gptel's own menu to switch model,
;; backend or system prompt.  Ollama (a local model server) is set up automatically the
;; first time, reading whatever models it reports right now, straight from its own API
;; --- so the list always matches what you actually have pulled, with nothing to
;; hand-edit here when you pull or remove a model, and no dependency on the `ollama'
;; command itself being on this machine's PATH (only the server needs to be reachable).
;;
;; This works identically from WSL/Linux Emacs and from the Windows bundle: Ollama only
;; needs to run once, in WSL/Linux (`ollama serve', or as a systemd service, as it
;; already does here); WSL2 forwards `localhost' both ways, so Windows reaches the exact
;; same http://localhost:11434 with no extra setup --- even though `ollama' itself (the
;; command-line tool) is not installed on Windows here; only the server needs to be
;; reachable, and it is.  Verified for real from both sides.
;;
;; A cloud backend (Anthropic, OpenAI, ...) needs an API key --- see "Adding a cloud
;; backend" below for where that goes (never in this file, which is tracked by git).
;;
;; See docs/LLM.md.

(defvar my/llm-ollama-host "localhost:11434"
  "Where Ollama's API is reachable.  The default already works from both WSL/Linux
and the Windows bundle (see the file header comment); change it only if Ollama runs
somewhere else, or on a different port.")

(defun my/llm-ollama-models ()
  "Model names Ollama's own API (`/api/tags') reports right now, as symbols, or nil if
the server at `my/llm-ollama-host' is not reachable.  Queried over plain HTTP rather
than by shelling out to the `ollama' command, so this works the same way whether or
not the `ollama' binary itself is on this machine's PATH --- it usually is not on
Windows, even when, as here, the server (running in WSL) is perfectly reachable from
Windows too.  Called fresh each time the Ollama backend is built, so `gptel-menu'
always matches what is actually pulled."
  (condition-case nil
      (let ((buf (url-retrieve-synchronously (format "http://%s/api/tags" my/llm-ollama-host)
                                             t t 3)))
        (when buf
          (unwind-protect
              (with-current-buffer buf
                (goto-char (point-min))
                (when (re-search-forward "\n\n" nil t)   ; end of the HTTP headers
                  (let* ((data (json-parse-buffer :object-type 'plist :array-type 'list))
                         (models (plist-get data :models)))
                    (mapcar (lambda (m) (intern (plist-get m :name))) models))))
            (kill-buffer buf))))
    (error nil)))

(defun my/llm-setup-ollama ()
  "Register (or re-register, picking up any newly pulled models) the Ollama backend."
  (interactive)
  (require 'gptel)
  ;; `gptel-make-ollama' lives in gptel-ollama.el, a separate file gptel.el does not
  ;; load itself (this config never loads package.el's own autoloads file, which is
  ;; the only other thing that would have pulled it in --- see init.el's "Packages"
  ;; section for why).
  (require 'gptel-ollama)
  (let ((models (my/llm-ollama-models)))
    (setq gptel-backend
          (gptel-make-ollama "Ollama" :host my/llm-ollama-host :stream t
                             ;; a placeholder if `ollama list' could not be read, so
                             ;; gptel still has *something* to offer in its menu
                             :models (or models '(llama3.2:latest))))
    (if models
        (message "Ollama backend ready: %d model%s (%s)" (length models)
                 (if (= (length models) 1) "" "s") my/llm-ollama-host)
      (message "my/llm-setup-ollama: could not list Ollama's models (is `ollama serve' running?)"))))

;;;###autoload
(defun my/llm-chat ()
  "Open a chat buffer.  Sets up the local Ollama backend the first time this runs."
  (interactive)
  (require 'gptel)
  (unless (and (bound-and-true-p gptel-backend) (gptel-ollama-p gptel-backend))
    (my/llm-setup-ollama))
  (call-interactively #'gptel))

;; gptel deliberately restores your previous cursor position after inserting a
;; response (it wraps the insertion in `save-excursion', in case you were doing
;; something else in the buffer at the time) --- so without this, you have to
;; scroll or press `M-x gptel-end-of-response' by hand to see a reply that just
;; streamed in.  This makes the chat buffer follow along instead, which is what
;; you want for a straightforward back-and-forth conversation.
(defun my/llm--follow-response (_beg end)
  "Move point to the END of the response that just finished."
  (goto-char end))
(with-eval-after-load 'gptel
  (add-hook 'gptel-post-response-functions #'my/llm--follow-response))

;;; Adding a cloud backend (Anthropic, OpenAI, ...) ------------------------------------
;;
;; This file is tracked by git: never put a real API key in it.  Instead:
;;
;; 1. Put the key in `~/.authinfo.gpg' (recommended, encrypted) or `~/.authinfo', one
;;    line, e.g. for Anthropic:
;;      machine api.anthropic.com login apikey password sk-ant-...
;;
;; 2. Uncomment and adjust one of these (each only needs to run once; `with-eval-after-
;;    load' means it costs nothing until `gptel' is actually loaded, i.e. until `C-c a a'
;;    or `C-c a m' is used):
;;
;; (with-eval-after-load 'gptel
;;   (gptel-make-anthropic "Claude"
;;     :key (lambda () (auth-source-pick-first-password :host "api.anthropic.com"))
;;     :stream t))
;;
;; (with-eval-after-load 'gptel
;;   (gptel-make-openai "ChatGPT"
;;     :key (lambda () (auth-source-pick-first-password :host "api.openai.com"))
;;     :stream t
;;     :models '(gpt-4o gpt-4o-mini)))
;;
;; 3. `M-x gptel-menu' (`C-c a m') to switch to it: whichever backend `gptel-make-*' ran
;;    last becomes the default, but the menu lets you pick per-buffer.

(provide 'llm)
;;; llm.el ends here
