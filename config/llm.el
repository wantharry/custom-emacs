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
  (let* ((models (my/llm-ollama-models))
         ;; a placeholder if `ollama list' could not be read, so gptel still has
         ;; *something* to offer in its menu
         (model-list (or models '(llama3.2:latest))))
    (setq gptel-backend
          (gptel-make-ollama "Ollama" :host my/llm-ollama-host :stream t :models model-list)
          ;; WHY: `gptel-model' otherwise stays at whatever it was before (nil, the
          ;; first time gptel is ever touched) --- gptel itself then warns loudly
          ;; ("Preferred `gptel-model' ... not supported in \"Ollama\"") and silently
          ;; falls back to one of `model-list' anyway every single time this backend is
          ;; (re)built; setting it explicitly here gets the same real result without
          ;; the warning.
          gptel-model (car model-list))
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

;;; Cloud backends: ChatGPT, Claude, Gemini, all *available*, none of them active -------
;;
;; WHAT: registers three well-known cloud backends with `gptel-menu' (`C-c a m') so they
;; show up as choices --- picking one is then a matter of `C-c a m' → Backend, no config
;; editing needed for that part.  WHY: Ollama stays the actual default either way (see
;; the "Chat with an LLM" section of `init.el', which runs after this and sets it) ---
;; `gptel-make-*' only *registers* a backend into `gptel-menu''s list, it does not
;; activate it (confirmed directly in `gptel-openai.el': it ends with `(setf (alist-get
;; name gptel--known-backends ...) backend)', nothing touching `gptel-backend' itself) ---
;; so having these three always registered costs nothing and changes nothing about the
;; default; you would only ever end up talking to one of these if you deliberately picked
;; it from the menu. HOW, to actually use one once picked:
;;
;; 1. This file is tracked by git: never put a real API key in it. Put it in
;;    `~/.authinfo.gpg' (recommended, encrypted) or `~/.authinfo' instead, one line per
;;    service:
;;      machine api.openai.com login apikey password sk-...
;;      machine api.anthropic.com login apikey password sk-ant-...
;;      machine generativelanguage.googleapis.com login apikey password AIza...
;; 2. `C-c a m' → Backend → the one you want. Without a key in place, the backend still
;;    shows up (nothing here fails just because a key is missing --- `auth-source-pick-
;;    first-password' below just returns nil, which fails only once you actually try to
;;    send something, exactly like the real 401 that prompted adding this at all), it
;;    just won't successfully send anything until you add one.
;;
;; More providers gptel supports the same way (`gptel-make-perplexity', `-deepseek',
;; `-xai', `-azure', `-kagi', ...): copy one of the three below and change the function
;; name, host and env var/`:key' lookup --- see `config/elpa/gptel-*/gptel-*.el' for
;; each one's exact keyword arguments.
(with-eval-after-load 'gptel
  ;; `gptel-make-openai'/`-anthropic'/`-gemini' each live in their own file
  ;; (gptel-openai.el/gptel-anthropic.el/gptel-gemini.el), none of them loaded just
  ;; because `gptel' itself is --- same reason `my/llm-setup-ollama' above explicitly
  ;; `require's `gptel-ollama' before calling `gptel-make-ollama'.
  (require 'gptel-openai)
  (require 'gptel-anthropic)
  (require 'gptel-gemini)
  (gptel-make-openai "ChatGPT"
    :key (lambda () (auth-source-pick-first-password :host "api.openai.com"))
    :stream t)
  (gptel-make-anthropic "Claude"
    :key (lambda () (auth-source-pick-first-password :host "api.anthropic.com"))
    :stream t)
  (gptel-make-gemini "Gemini"
    :key (lambda () (auth-source-pick-first-password :host "generativelanguage.googleapis.com"))
    :stream t))

(provide 'llm)
;;; llm.el ends here
