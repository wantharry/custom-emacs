;;; llm-council.el --- ask several local models at once, then have a bigger one summarize  -*- lexical-binding: t; -*-

;; `C-c a c' sends one question to three different local Ollama models in parallel, then
;; sends a fourth, bigger model all three answers and asks it to compare and summarize
;; them.  Everything shows up in one buffer: the summary is expanded at the top; each
;; model's own full answer is folded shut below it (`outline-mode', TAB to expand/
;; collapse, same as `my/shortcuts' and `my/docs') so you see the synthesis first and
;; only dig into an individual model's wording if you want to.
;;
;; The three "council" models are chosen for being from different trainers/families
;; (not near-duplicates of each other, which would make comparing them pointless); the
;; summarizer is the largest general-purpose model available.  `my/llm-council-models'
;; and `my/llm-council-summarizer-models' below list preferred names in priority order,
;; but this only ever picks from whatever `my/llm-ollama-models' (llm.el's own live
;; query of Ollama's `/api/tags') reports right now --- so on a machine with a different
;; set of models pulled, it degrades to whatever is actually there instead of erroring.
;;
;; Every request uses `:stream nil': each model's callback then fires exactly once with
;; its complete answer, so the buffer only needs to redraw once per model (four times
;; total: three council answers plus the summary) instead of re-folding on every
;; streamed chunk.
;;
;; See docs/LLM.md.

(require 'llm (expand-file-name "llm" user-emacs-directory))
(require 'outline)
(require 'cl-lib)
(require 'seq)

(defvar my/llm-council-models
  '(qwen3:8b llama3.1:8b gemma2:9b mistral:7b qwen2.5:7b hermes3:8b
    deepseek-r1:8b phi3:mini llama3:latest llama3.2:latest)
  "Preferred council models, most-preferred first: three different, meaningfully
distinct general-purpose chat models (Alibaba/Qwen, Meta/Llama, Google/Gemma, ... as
fallbacks) to ask the same question in parallel.  Only names Ollama actually reports
right now (`my/llm-ollama-models') are ever used; see `my/llm-council--pick'.")

(defvar my/llm-council-summarizer-models
  '(gpt-oss:20b gpt-oss:20b-32k qwen3.5:9b llama3.1:8b-32k deepseek-r1:8b qwen3:8b)
  "Preferred summarizer models, most-preferred first: the largest general-purpose
model available, used to compare and synthesize the council's three answers.  Only
names Ollama actually reports right now are ever used.")

(defun my/llm-council--pick (n preferred available &optional exclude)
  "Pick N models from PREFERRED (in order) that are also in AVAILABLE and not in
EXCLUDE, padding with whatever else is in AVAILABLE (in its own order) if PREFERRED
does not supply enough.  AVAILABLE and EXCLUDE are lists of symbols; returns a list of
at most N symbols, each one only once."
  (let (chosen)
    (dolist (m preferred)
      (when (and (memq m available) (not (memq m exclude)) (not (memq m chosen)))
        (push m chosen)))
    (dolist (m available)
      (when (and (not (memq m exclude)) (not (memq m chosen)))
        (push m chosen)))
    (seq-take (nreverse chosen) n)))

(defun my/llm-council--choose (available)
  "Return (COUNCIL . SUMMARIZER) chosen from AVAILABLE (a list of model symbols, as
`my/llm-ollama-models' returns).  COUNCIL is up to 3 models; SUMMARIZER is one more
model distinct from all of them, or nil if AVAILABLE has nothing left to offer."
  (let* ((council (my/llm-council--pick 3 my/llm-council-models available))
         (summarizer (car (my/llm-council--pick
                            1 my/llm-council-summarizer-models available council))))
    (cons council summarizer)))

;;; The results buffer -------------------------------------------------------------------

(defconst my/llm-council-buffer-name "*llm-council*")

(defvar-local my/llm-council--query nil)
(defvar-local my/llm-council--summarizer nil)
;; An ordered alist: (MODEL . PLIST), PLIST one of
;;   (:status pending)
;;   (:status done   :text "...")
;;   (:status failed)
;; MODEL is a model symbol for a council entry, or the symbol `summary' for the
;; synthesis (always the first entry, so it renders first).
(defvar-local my/llm-council--entries nil)

(defvar my/llm-council-mode-map
  (let ((m (make-sparse-keymap)))
    (set-keymap-parent m outline-mode-map)
    (define-key m "q" #'quit-window)
    m))

(define-derived-mode my/llm-council-mode outline-mode "Council"
  "One question, answered by several local models and summarized by a bigger one.
See `my/llm-council'."
  (setq-local outline-regexp "\\* ")
  (setq-local buffer-read-only t))

(defun my/llm-council--status-line (entry)
  "Text shown under a heading for ENTRY, a (MODEL . PLIST) cons from
`my/llm-council--entries'."
  (pcase (plist-get (cdr entry) :status)
    ('pending "  (waiting for a response...)\n")
    ('failed  "  (no response --- this request failed; see the echo area)\n")
    ('done    (concat (plist-get (cdr entry) :text) "\n"))))

(defun my/llm-council--insert ()
  (insert (propertize (format "Council: %s\n\n" my/llm-council--query)
                      'face '(:height 1.2 :weight bold)))
  (insert "  TAB folds/unfolds a model's answer; RET/click on a heading also works.\n\n")
  (dolist (entry my/llm-council--entries)
    (let ((model (car entry)))
      (insert (format "* %s\n"
                      (if (eq model 'summary)
                          (format "Summary%s" (if my/llm-council--summarizer
                                                  (format " (by %s)" my/llm-council--summarizer)
                                                ""))
                        (symbol-name model))))
      (insert (my/llm-council--status-line entry)))
    (insert "\n")))

(defun my/llm-council--fold ()
  "Show the summary expanded; fold every model's own answer shut."
  (goto-char (point-min))
  (outline-hide-body)
  (when (re-search-forward "^\\* Summary" nil t)
    (outline-show-subtree)))

(defun my/llm-council--render ()
  "Redraw the whole council buffer from `my/llm-council--entries'."
  (let ((buf (get-buffer my/llm-council-buffer-name)))
    (when buf
      (with-current-buffer buf
        (let ((inhibit-read-only t) (pos (point)))
          (erase-buffer)
          (my/llm-council--insert)
          (my/llm-council--fold)
          (goto-char (min pos (point-max)))
          (set-buffer-modified-p nil))))))

(defun my/llm-council--set (model &rest plist)
  "Update MODEL's entry (or add it) to PLIST and redraw."
  (setf (alist-get model my/llm-council--entries) plist)
  (my/llm-council--render))

;;; Sending the requests ------------------------------------------------------------------

(defun my/llm-council--summary-prompt (query entries)
  "The prompt sent to the summarizer: QUERY plus each done ENTRIES answer, labeled by
model.  Only entries with :status done are included --- a model that failed is left
out rather than confusing the summarizer with a blank answer attributed to it."
  (concat
   "Several different AI models were each asked the same question, independently. "
   "Compare their answers: note where they agree, where they disagree, and give one "
   "clear, concise best-answer summary.\n\n"
   "Question: " query "\n"
   (mapconcat
    (lambda (entry)
      (format "\n%s answered:\n%s\n" (car entry) (plist-get (cdr entry) :text)))
    (seq-filter (lambda (e) (eq (plist-get (cdr e) :status) 'done)) entries)
    "")))

(defun my/llm-council--request-summary ()
  (let* ((done (seq-filter (lambda (e) (and (not (eq (car e) 'summary))
                                        (eq (plist-get (cdr e) :status) 'done)))
                            my/llm-council--entries)))
    (cond
     ((null my/llm-council--summarizer)
      (my/llm-council--set 'summary :status 'failed))
     ((null done)
      (my/llm-council--set 'summary :status 'failed)
      (message "my/llm-council: every council model failed; nothing to summarize"))
     (t
      (let ((gptel-model my/llm-council--summarizer)
            (prompt (my/llm-council--summary-prompt my/llm-council--query done)))
        (gptel-request prompt
          :stream nil
          :callback
          (lambda (response _info)
            (if (stringp response)
                (my/llm-council--set 'summary :status 'done :text response)
              (my/llm-council--set 'summary :status 'failed)))))))))

(defun my/llm-council--request-one (model pending)
  "Ask MODEL the query, decrementing PENDING (a cons cell whose car is the count of
still-outstanding council requests) when its answer arrives, and firing the summary
request once PENDING reaches 0."
  (let ((gptel-model model))
    (gptel-request my/llm-council--query
      :stream nil
      :callback
      (lambda (response _info)
        (if (stringp response)
            (my/llm-council--set model :status 'done :text response)
          (my/llm-council--set model :status 'failed))
        (cl-decf (car pending))
        (when (zerop (car pending))
          (my/llm-council--request-summary))))))

;;;###autoload
(defun my/llm-council (query)
  "Ask QUERY of three different local Ollama models in parallel, then have a fourth,
bigger model compare and summarize their answers.  See the file header comment in
llm-council.el for why these particular models, and docs/LLM.md."
  (interactive "sAsk the council: ")
  (require 'gptel)
  (unless (and (bound-and-true-p gptel-backend) (gptel-ollama-p gptel-backend))
    (my/llm-setup-ollama))
  (let* ((available (or (my/llm-ollama-models)
                        (and (gptel-backend-p gptel-backend) (gptel-backend-models gptel-backend))))
         (choice (my/llm-council--choose available))
         (council (car choice)) (summarizer (cdr choice)))
    (unless council
      (user-error "my/llm-council: no Ollama models available (is `ollama serve' running?)"))
    (let ((buf (get-buffer-create my/llm-council-buffer-name)))
      (with-current-buffer buf
        (unless (derived-mode-p 'my/llm-council-mode) (my/llm-council-mode))
        (setq my/llm-council--query query
              my/llm-council--summarizer summarizer
              my/llm-council--entries
              (append (list (cons 'summary (list :status 'pending)))
                      (mapcar (lambda (m) (cons m (list :status 'pending))) council)))
        (my/llm-council--render))
      (switch-to-buffer buf))
    (let ((pending (cons (length council) nil)))
      (dolist (model council)
        (my/llm-council--request-one model pending)))))

(provide 'llm-council)
;;; llm-council.el ends here
