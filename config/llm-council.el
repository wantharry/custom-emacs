;;; llm-council.el --- ask several local models at once, then have a bigger one summarize  -*- lexical-binding: t; -*-

;; `C-c a c' sends one question to three different local Ollama models in parallel, then
;; sends a fourth, bigger model all three answers and asks it to compare and summarize
;; them.  Everything shows up in one buffer: the summary is expanded at the top; each
;; model's own full answer is folded shut below it (`outline-mode', TAB to expand/
;; collapse, same as `my/shortcuts' and `my/docs') so you see the synthesis first and
;; only dig into an individual model's wording if you want to.
;;
;; The three "council" models are chosen for being small and fast --- closest to
;; `my/llm-council-target-size-gb' (2-3GB) on disk of whatever is actually pulled, so
;; asking three of them in parallel does not noticeably slow the machine down; the
;; summarizer is chosen separately, closest to `my/llm-council-target-summarizer-
;; params-b' (7B) parameters, and never the largest pull available (excluded outright
;; by `my/llm-council-summarizer-exclude', a real, explicit choice --- it visibly slows
;; this machine down for a task that does not need it). Sizes and parameter counts come
;; from a live query of Ollama's own `/api/tags' (`my/llm-council--available-models'),
;; so nothing here needs to be kept in sync with any one machine's actual pulled models;
;; on a machine with fewer models, or only one, it degrades gracefully rather than
;; erroring --- with only one model pulled at all, that one model is asked to fill both
;; roles (the council's only answer, and its own summarizer) instead of the summarizer
;; coming back empty. See `my/llm-council--choose' for exactly how.
;;
;; Every request uses `:stream nil': each model's callback then fires exactly once with
;; its complete answer, so the buffer only needs to redraw once per model (four times
;; total: three council answers plus the summary) instead of re-folding on every
;; streamed chunk.
;;
;; See docs/LLM.md.

;; WHAT: pull in this config's own `llm.el' (for `my/llm-ollama-models', `my/llm-setup-
;; ollama' and `my/llm-chat').  WHY: this file reuses that live-model-query and backend-
;; setup logic rather than duplicating it.  HOW: `expand-file-name' resolves "llm" next
;; to this file (both live directly in `user-emacs-directory'), so this works whether
;; llm-council.el is loaded from the repo or from an installed/copied config directory.
(require 'llm (expand-file-name "llm" user-emacs-directory))
;; WHAT: Emacs's built-in outlining library.  WHY: the results buffer is an outline
;; (headings + foldable bodies), same mechanism `my/shortcuts' and `my/docs' already use
;; for "fold everything, expand just what you want to read".  HOW: gives us `outline-
;; mode' to derive from and `outline-hide-body'/`outline-show-subtree' to fold/unfold.
(require 'outline)
;; WHAT: Common Lisp compatibility macros.  WHY: this file uses `cl-decf' (decrement a
;; place) and `dolist'/`cl-defstruct'-style struct accessors from gptel's own API.  HOW:
;; just makes those macros available; costs nothing extra since gptel already depends on
;; it too.
(require 'cl-lib)
;; WHAT: Emacs's built-in generic sequence library.  WHY: this file uses `seq-take' (pick
;; the first N models) and `seq-filter' (keep only the "done" answers).  HOW: works on
;; both lists here, no extra dependency beyond what ships with Emacs.
(require 'seq)

;; WHAT: the council's target size on disk, and the summarizer's target parameter count.
;; WHY: the user's own explicit ask --- small, fast council models (this machine slows
;; down noticeably under a large one) sized around 2-3GB on disk, and a summarizer sized
;; around 7B parameters rather than the biggest pull available (`gpt-oss:20b', ~13GB,
;; ~21B params, was the previous default and is now excluded outright, not just
;; deprioritized --- see `my/llm-council-summarizer-exclude').  These are two different
;; units on purpose: disk size for the council (what actually determines load/inference
;; speed), parameter count for the summarizer (what Ollama's API reports directly, and
;; what "7b" naturally means) --- a 7B model at typical quantization is usually ~4GB on
;; disk, not 2-3GB, so picking the summarizer by disk size against the same 2-3GB window
;; would pick something far smaller than a real 7B model.
(defvar my/llm-council-target-size-gb 2.5
  "Target disk size, in GB, council models are picked closest to.")
(defvar my/llm-council-target-summarizer-params-b 7.0
  "Target parameter count, in billions, the summarizer is picked closest to.")
;; WHAT: models never chosen as the summarizer, no matter what.  WHY: excluded outright
;; (not just deprioritized) since this is exactly the model the user asked to avoid.
(defvar my/llm-council-summarizer-exclude '(gpt-oss:20b gpt-oss:20b-32k)
  "Models never chosen as the summarizer, regardless of what else is available.")

;; WHAT: parse Ollama's PARAMETER_SIZE string (e.g. "7.6B", "751.63M") into a plain
;; float count of billions, or nil if S is empty/unparseable.  WHY: `my/llm-council--
;; order-by' below needs a plain number to compare against a target; Ollama reports this
;; as a unit-suffixed string, not a number.
(defun my/llm-council--parse-param-size (s)
  (when (and s (stringp s) (not (string-empty-p s)))
    (let ((n (ignore-errors (string-to-number s))))
      (cond ((string-suffix-p "B" s) n)
            ((string-suffix-p "M" s) (and n (/ n 1000.0)))))))

;; WHAT: a fresh, live query of Ollama's own `/api/tags', like `my/llm-ollama-models'
;; (llm.el) but keeping each model's disk size and parameter count too.  WHY: a separate
;; query rather than a change to `my/llm-ollama-models' itself --- that function's only
;; other caller (`my/llm-setup-ollama') just needs plain names, and this file reusing it
;; instead of duplicating the query risks nothing for that caller if this one changes.
;; HOW: identical HTTP round trip and response parsing to `my/llm-ollama-models', just
;; keeping :size and :details/:parameter_size from each entry instead of discarding them.
(defun my/llm-council--available-models ()
  "Models Ollama's own API reports right now, each as a plist (:name SYMBOL :size-gb
FLOAT :params-b FLOAT-OR-NIL), or nil if the server is not reachable."
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
                    (mapcar (lambda (m)
                              (list :name (intern (plist-get m :name))
                                    :size-gb (/ (plist-get m :size) 1073741824.0)
                                    :params-b (my/llm-council--parse-param-size
                                               (plist-get (plist-get m :details)
                                                          :parameter_size))))
                            models))))
            (kill-buffer buf))))
    (error nil)))

;; WHAT: names from AVAILABLE (the plists `my/llm-council--available-models' returns),
;; ordered by how close their FIELD value is to TARGET, closest first; entries missing
;; FIELD (a fallback query with no size info) sort last, in their given order rather than
;; being dropped.  WHY: this is what turns "pick council models around 2-3GB" / "pick a
;; ~7B summarizer" into an actual priority order `my/llm-council--pick' can use --- it
;; already knows how to turn an ordered wish list plus what's really available into a
;; final pick; this is just a different way of building that wish list, by measurement
;; instead of by name.
(defun my/llm-council--order-by (available field target)
  (let ((sized (seq-filter (lambda (m) (plist-get m field)) available))
        (unsized (seq-remove (lambda (m) (plist-get m field)) available)))
    (mapcar (lambda (m) (plist-get m :name))
            (append (sort (copy-sequence sized)
                          (lambda (a b) (< (abs (- (plist-get a field) target))
                                            (abs (- (plist-get b field) target)))))
                    unsized))))

;; WHAT: pick N models out of PREFERRED, but only ones that are actually in AVAILABLE and
;; not in EXCLUDE.  WHY: this is the one place that turns a "wish list" (the two defvars
;; above) into a real, usable set of models on whatever machine this runs on --- without
;; it, a machine missing `qwen3:8b' would just error instead of quietly using its next-
;; best pulled model.  HOW: two passes over a plain list, no sorting/hashing needed since
;; these lists are only ever a handful of items long.
(defun my/llm-council--pick (n preferred available &optional exclude)
  "Pick N models from PREFERRED (in order) that are also in AVAILABLE and not in
EXCLUDE, padding with whatever else is in AVAILABLE (in its own order) if PREFERRED
does not supply enough.  AVAILABLE and EXCLUDE are lists of symbols; returns a list of
at most N symbols, each one only once."
  ;; WHAT: the accumulator, built up in reverse (cheap `push') and reversed once at the
  ;; end.  WHY: appending to the end of a list repeatedly is O(n^2); pushing to the front
  ;; and reversing once is O(n).
  (let (chosen)
    ;; WHAT: first pass, in PREFERRED's own priority order.  WHY: this is what makes the
    ;; wish list actually mean something --- earlier entries in PREFERRED win over later
    ;; ones whenever both are available.  HOW: for each preferred name, take it only if
    ;; Ollama really has it (`memq m available'), it wasn't explicitly excluded (used to
    ;; keep the summarizer distinct from the council, see `my/llm-council--choose'), and
    ;; it hasn't already been chosen (a name could appear more than once by mistake).
    (dolist (m preferred)
      (when (and (memq m available) (not (memq m exclude)) (not (memq m chosen)))
        (push m chosen)))
    ;; WHAT: second pass, in AVAILABLE's own order this time.  WHY: if PREFERRED didn't
    ;; have enough names that were actually available (a machine with an unusual set of
    ;; models pulled), this pads out the result with whatever else Ollama does have,
    ;; instead of returning fewer than N models when more genuinely exist.  HOW: same
    ;; exclude/already-chosen guards as the first pass, just over a different source list.
    (dolist (m available)
      (when (and (not (memq m exclude)) (not (memq m chosen)))
        (push m chosen)))
    ;; WHAT: undo the reverse-accumulation, then keep only the first N.  WHY: `chosen'
    ;; was built newest-first via `push'; `nreverse' restores priority order (best pick
    ;; first) before truncating to how many the caller actually asked for.
    (seq-take (nreverse chosen) n)))

;; WHAT: combine the two orderings above into "3 council models sized near 2-3GB, plus 1
;; more ~7B summarizer distinct from all of them".  WHY: this is the single function
;; `my/llm-council' (the interactive command near the bottom of this file) calls to
;; decide who gets asked --- keeping the "how many, sized how, and how they must differ
;; from each other" policy in one place.  HOW: picks the council first (by disk size),
;; then picks the summarizer (by parameter count, and never `my/llm-council-summarizer-
;; exclude') while excluding whichever models the council already took, so the same
;; model is never asked twice under two different roles --- ONE real exception: if
;; AVAILABLE has only a single model total, there is no one else *to* exclude it in
;; favor of, so that one model is asked to do both jobs (the council's only answer, and
;; its own summarizer) rather than the summarizer coming back empty just because the
;; sole model "conflicts with itself".
(defun my/llm-council--choose (available)
  "Return (COUNCIL . SUMMARIZER) chosen from AVAILABLE (a list of plists, as
`my/llm-council--available-models' returns).  COUNCIL is up to 3 models, sized closest
to `my/llm-council-target-size-gb'; SUMMARIZER is one more model, sized closest to
`my/llm-council-target-summarizer-params-b', distinct from COUNCIL unless AVAILABLE has
only one model total (then that model fills both roles) --- or nil if AVAILABLE has
nothing left to offer."
  (let* ((names (mapcar (lambda (m) (plist-get m :name)) available))
         (council (my/llm-council--pick
                   3 (my/llm-council--order-by available :size-gb my/llm-council-target-size-gb)
                   names))
         (summarizer
          (car (my/llm-council--pick
                1 (my/llm-council--order-by
                   available :params-b my/llm-council-target-summarizer-params-b)
                names
                (append my/llm-council-summarizer-exclude
                        (unless (= (length names) 1) council))))))
    ;; WHAT/HOW: bundle both results into one cons cell so callers get them back from a
    ;; single function call: `(car choice)' is the council list, `(cdr choice)' the
    ;; summarizer (or nil).
    (cons council summarizer)))

;;; The results buffer -------------------------------------------------------------------

;; WHAT: the fixed name of the one results buffer this feature uses.  WHY: a `defconst'
;; (not a `defvar') because this name is never meant to change at runtime --- every
;; function below that needs the buffer just looks it up by this name via `get-buffer'/
;; `get-buffer-create', so there is only ever one council conversation open at a time
;; (a fresh `C-c a c' reuses/overwrites it, same as `my/shortcuts' reuses `*shortcuts*').
(defconst my/llm-council-buffer-name "*llm-council*")

;; WHAT: the question that was asked, stored per-buffer.  WHY: needed again later to
;; build the summarizer's prompt, and to redraw the buffer's title after any update.
;; HOW: `defvar-local' auto-makes this buffer-local on first `setq', so a second, later
;; council buffer (if one is ever opened) never bleeds its query into this one.
(defvar-local my/llm-council--query nil)
;; WHAT: which model was chosen as the summarizer for this buffer's question.  WHY:
;; shown in the "Summary (by MODEL)" heading, and read again when it's time to actually
;; send the summarizer request.  HOW: same buffer-local pattern as the query above.
(defvar-local my/llm-council--summarizer nil)
;; An ordered alist: (MODEL . PLIST), PLIST one of
;;   (:status pending)
;;   (:status done   :text "...")
;;   (:status failed)
;; MODEL is a model symbol for a council entry, or the symbol `summary' for the
;; synthesis (always the first entry, so it renders first).
;; WHAT: the single source of truth this whole buffer is drawn from.  WHY: keeping all
;; state in one plain data structure (rather than editing buffer text in place as answers
;; arrive) means the buffer can always be redrawn consistently from scratch --- see
;; `my/llm-council--render' below --- instead of hand-patching fragile text positions.
;; HOW: buffer-local, same reasoning as the two variables above.
(defvar-local my/llm-council--entries nil)

;; WHAT: this buffer's own keymap.  WHY: needs `q' to close (matching every other read-
;; only reference buffer in this config: `my/shortcuts', `my/docs', the start screen),
;; while still inheriting all of plain `outline-mode's folding keys (TAB and friends).
;; HOW: `set-keymap-parent' chains to `outline-mode-map' first, then this map only adds
;; the one binding it needs on top; `define-derived-mode' below picks this up
;; automatically because it's already bound to a variable of the expected name
;; (`my/llm-council-mode-map') before that macro runs.
(defvar my/llm-council-mode-map
  (let ((m (make-sparse-keymap)))
    (set-keymap-parent m outline-mode-map)
    (define-key m "q" #'quit-window)
    m))

;; WHAT: the major mode for the results buffer.  WHY: deriving from `outline-mode' (not
;; writing folding logic from scratch) gets TAB-to-fold, `outline-regexp'-driven heading
;; detection, and all of outline's navigation commands for free.  HOW: `outline-regexp'
;; is set to match this buffer's own heading style ("* " at the start of a line, one
;; level only --- no nested sub-headings are ever used here); `buffer-read-only' is on
;; because nothing in this buffer is meant to be hand-edited, only read (updates go
;; through `my/llm-council--render', which briefly lifts the read-only lock itself).
(define-derived-mode my/llm-council-mode outline-mode "Council"
  "One question, answered by several local models and summarized by a bigger one.
See `my/llm-council'."
  (setq-local outline-regexp "\\* ")
  (setq-local buffer-read-only t))

;; WHAT: turn one entry's status into the line of text shown under its heading.  WHY:
;; centralizes the three possible wordings in one place instead of repeating `pcase'-like
;; logic wherever an entry gets rendered.  HOW: `pcase' dispatches on the `:status' plist
;; value; `pending' and `failed' are fixed strings, `done' interpolates the model's
;; actual answer text.  A trailing "\n" is included in every branch so callers can just
;; `insert' the result directly without needing to remember it themselves.
(defun my/llm-council--status-line (entry)
  "Text shown under a heading for ENTRY, a (MODEL . PLIST) cons from
`my/llm-council--entries'."
  (pcase (plist-get (cdr entry) :status)
    ('pending "  (waiting for a response...)\n")
    ('failed  "  (no response --- this request failed; see the echo area)\n")
    ('done    (concat (plist-get (cdr entry) :text) "\n"))))

;; WHAT: write this buffer's entire visible content, from scratch, based on the current
;; `my/llm-council--query'/`my/llm-council--summarizer'/`my/llm-council--entries'.  WHY:
;; called by `my/llm-council--render' below every single time any entry changes --- see
;; that function's own comment for why "redraw everything" is the chosen strategy here.
;; HOW: title line, then a one-line usage hint, then one outline heading per entry
;; (always `summary' first, since it's always the first element of `my/llm-council--
;; entries' --- see where that list is built in `my/llm-council' near the end of this
;; file) with that entry's status line directly under it.
(defun my/llm-council--insert ()
  (insert (propertize (format "Council: %s\n\n" my/llm-council--query)
                      'face '(:height 1.2 :weight bold)))
  (insert "  TAB folds/unfolds a model's answer; RET/click on a heading also works.\n\n")
  (dolist (entry my/llm-council--entries)
    (let ((model (car entry)))
      ;; WHAT: the heading text itself.  WHY/HOW: the special `summary' entry gets a
      ;; human-friendly "Summary (by MODEL)" heading (or just "Summary" before a
      ;; summarizer has been chosen yet, which `my/llm-council--choose' can return as
      ;; nil); every other entry is simply the model's own name.
      (insert (format "* %s\n"
                      (if (eq model 'summary)
                          (format "Summary%s" (if my/llm-council--summarizer
                                                  (format " (by %s)" my/llm-council--summarizer)
                                                ""))
                        (symbol-name model))))
      (insert (my/llm-council--status-line entry)))
    (insert "\n")))

;; WHAT: apply this buffer's default fold state: everything shown, then every model's own
;; answer folded shut, then the Summary heading re-opened.  WHY: this is what makes the
;; buffer's whole point work at a glance --- you see the synthesis immediately, and only
;; expand a model's raw answer if you want to check its exact wording.  HOW: `outline-
;; hide-body' collapses every heading's body in the whole buffer in one call (simpler and
;; more robust than walking headings one at a time); then a regexp search finds the one
;; "* Summary" heading specifically and `outline-show-subtree' re-opens just that one.
(defun my/llm-council--fold ()
  "Show the summary expanded; fold every model's own answer shut."
  (goto-char (point-min))
  (outline-hide-body)
  (when (re-search-forward "^\\* Summary" nil t)
    (outline-show-subtree)))

;; WHAT: the one function that actually touches the buffer's text.  WHY: rather than
;; trying to surgically patch just the one entry that changed (fragile: text positions
;; shift as answers of different lengths come in, and outline's fold state is keyed to
;; buffer positions too), this always erases and rebuilds the whole buffer from
;; `my/llm-council--entries', then reapplies the same default fold state every time.
;; The tradeoff --- if you had manually expanded a model's answer to read it, the next
;; incoming answer collapses it again --- is accepted deliberately for simplicity; since
;; every request uses `:stream nil' (see the file header comment), this only happens (at
;; most) four times total per question, not on every streamed chunk.  HOW: guards on the
;; buffer actually still existing (a stale, already-answered callback could in principle
;; fire after the user killed the buffer); temporarily disables `buffer-read-only'
;; (`inhibit-read-only') since the buffer is normally locked against edits; tries to keep
;; point roughly where it was (`pos', clamped to the new, possibly-shorter buffer
;; length) instead of always snapping back to the top; and marks the buffer unmodified
;; afterward, since this is generated content, not something the user was editing.
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

;; WHAT: update one entry (by model symbol, or `summary') in the data model, then redraw.
;; WHY: this is the single choke point every request callback below goes through to
;; report a result --- keeping "update the data" and "redraw from it" glued together in
;; one call means no caller can forget to trigger a redraw after changing state.  HOW:
;; `alist-get' as a `setf' place either replaces an existing MODEL entry's plist or adds
;; a brand new one if it somehow wasn't already present; PLIST arrives as the `&rest' of
;; keyword/value pairs the caller passed (e.g. `:status 'done :text "..."'), which is
;; already exactly the plist shape this whole file uses everywhere else.
(defun my/llm-council--set (model &rest plist)
  "Update MODEL's entry (or add it) to PLIST and redraw."
  (setf (alist-get model my/llm-council--entries) plist)
  (my/llm-council--render))

;;; Sending the requests ------------------------------------------------------------------

;; WHAT: build the text prompt sent to the summarizer.  WHY: the summarizer needs to see
;; the original question plus every council model's answer, clearly labeled by which
;; model said what, so it can genuinely compare them rather than just being asked to
;; answer the question itself a fourth time.  HOW: `seq-filter' keeps only entries whose
;; `:status' is `done' (a model that errored is silently left out here --- see the next
;; paragraph in this comment for why that matters); `mapconcat' then turns each surviving
;; entry into a "MODEL answered:\n...text...\n" block and joins them together under one
;; shared instruction/question header.
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

;; WHAT: fire the fourth (summarizer) request, once all three council answers are in.
;; WHY: this is where the "wait for everyone, then only ask the summarizer about who
;; actually answered" policy lives.  HOW: first collects every non-summary entry whose
;; status is `done' (explicitly excluding the `summary' entry itself with `(not (eq (car
;; e) 'summary))', since by the time this runs that entry is still `pending' and would
;; otherwise wrongly count as "done" under a careless status check); then three distinct
;; outcomes, handled by a `cond':
(defun my/llm-council--request-summary ()
  (let* ((done (seq-filter (lambda (e) (and (not (eq (car e) 'summary))
                                        (eq (plist-get (cdr e) :status) 'done)))
                            my/llm-council--entries)))
    (cond
     ;; WHAT/WHY: no summarizer was even chosen (every model got used up as a council
     ;; member, or nothing at all was available past the council pick).  HOW: mark the
     ;; summary failed directly --- there is nothing to send a request to.
     ((null my/llm-council--summarizer)
      (my/llm-council--set 'summary :status 'failed))
     ;; WHAT/WHY: a summarizer exists, but every single council model failed, so there
     ;; would be nothing real to summarize.  HOW: mark it failed too, and tell the user
     ;; why via the echo area (`message'), rather than silently wasting a request asking
     ;; the summarizer to synthesize zero answers.
     ((null done)
      (my/llm-council--set 'summary :status 'failed)
      (message "my/llm-council: every council model failed; nothing to summarize"))
     ;; WHAT/WHY/HOW: the normal case --- at least one real answer exists, and a
     ;; summarizer is available.  `gptel-model' is *dynamically* let-bound here (not
     ;; passed as an argument) because that is exactly the mechanism `gptel-request'
     ;; itself documents for choosing which model a particular request uses: it copies
     ;; the current dynamic value of `gptel-model' into the request at the moment
     ;; `gptel-request' is called (before any network I/O happens), so this let-binding
     ;; reliably targets just this one request without needing to touch the global
     ;; default or any other buffer's local value.  `:stream nil' forces the whole
     ;; answer to arrive in a single callback invocation (see the file header comment
     ;; for why every request in this file does this).  The callback itself mirrors the
     ;; per-model one below: a string response is success (`:status 'done'), anything
     ;; else (nil, or the symbol `abort') is treated as failure.
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

;; WHAT: fire one council request for MODEL, and track when all of them are done.  WHY:
;; this is the per-model half of the fan-out/fan-in: three of these run "in parallel"
;; (really: three independent async HTTP requests in flight at once, each with its own
;; callback), and the last one to finish is responsible for kicking off the summary.
;; HOW: PENDING is a single cons cell (not a plain number) *shared by reference* across
;; all three calls to this function for one question --- every callback below decrements
;; the same `(car pending)' via `cl-decf', so whichever callback happens to run last (in
;; whatever order the three HTTP responses actually arrive, which is not predictable)
;; sees the count reach exactly zero and is the one that triggers the summary. `gptel-
;; model' is let-bound to MODEL for the same reason as in `my/llm-council--request-
;; summary' above: it tells `gptel-request' which model to actually use.
(defun my/llm-council--request-one (model pending)
  "Ask MODEL the query, decrementing PENDING (a cons cell whose car is the count of
still-outstanding council requests) when its answer arrives, and firing the summary
request once PENDING reaches 0."
  (let ((gptel-model model))
    (gptel-request my/llm-council--query
      :stream nil
      :callback
      (lambda (response _info)
        ;; WHAT/WHY/HOW: same success/failure rule as the summarizer's own callback --- a
        ;; string response is a real answer, anything else (a network failure, the model
        ;; not being loaded, an aborted request) is recorded as `failed' so it shows up
        ;; clearly in the buffer instead of silently vanishing.
        (if (stringp response)
            (my/llm-council--set model :status 'done :text response)
          (my/llm-council--set model :status 'failed))
        ;; WHAT/WHY/HOW: this model is no longer outstanding, whether it succeeded or
        ;; failed --- both cases count toward "everyone has answered".  Once the shared
        ;; counter hits zero, every council request has resolved one way or the other, so
        ;; it's time to ask the summarizer (which itself decides, above, whether there
        ;; was anything worth summarizing).
        (cl-decf (car pending))
        (when (zerop (car pending))
          (my/llm-council--request-summary))))))

;; WHAT: the interactive entry point, bound to `C-c a c' in config/init.el.  WHY: this is
;; the one function a person actually calls; everything above it exists to support this.
;; HOW, step by step, matches the numbered comments inline below.
;;;###autoload
(defun my/llm-council (query)
  "Ask QUERY of three different local Ollama models in parallel, then have a fourth,
bigger model compare and summarize their answers.  See the file header comment in
llm-council.el for why these particular models, and docs/LLM.md."
  ;; WHAT: prompt for QUERY with a plain minibuffer read.  WHY: unlike the chat buffer
  ;; (`my/llm-chat'), this is a one-shot "ask once, get a synthesized answer" command,
  ;; not an ongoing conversation, so there's no buffer text to read the question from ---
  ;; asking directly in the minibuffer is the simplest, most predictable input method.
  (interactive "sAsk the council: ")
  ;; WHAT/WHY/HOW: make sure gptel itself is loaded (it's autoloaded and otherwise never
  ;; pulled in at startup, see config/init.el's own comment on that), then make sure the
  ;; Ollama backend is actually set up --- reusing `my/llm-chat's exact same "only set up
  ;; once, and only if it isn't already an Ollama backend" check from config/llm.el, so
  ;; this command and the plain chat command never fight over re-registering the backend
  ;; needlessly.
  (require 'gptel)
  (unless (and (bound-and-true-p gptel-backend) (gptel-ollama-p gptel-backend))
    (my/llm-setup-ollama))
  (let* ((available
          ;; WHAT/WHY/HOW: prefer a fresh, live query of Ollama's own API, sizes and all
          ;; (so the model list is never stale even if the backend was set up a while ago
          ;; in this Emacs session, and so `my/llm-council--choose' has what it needs to
          ;; pick by size); only fall back to whatever the already-registered backend
          ;; remembers if that live query fails (e.g. Ollama briefly not responding) ---
          ;; better to proceed with slightly-stale information than to refuse outright
          ;; when the backend clearly does have *something* usable.  That fallback has no
          ;; size/param info to offer, so it is wrapped into the same plist shape with
          ;; both nil --- `my/llm-council--order-by' already treats a missing field as
          ;; "sorts last, in its given order" rather than erroring on it.
          (or (my/llm-council--available-models)
              (and (gptel-backend-p gptel-backend)
                   (mapcar (lambda (m) (list :name m :size-gb nil :params-b nil))
                           (gptel-backend-models gptel-backend)))))
         ;; WHAT/HOW: hand the real, live model list to the picking logic defined above,
         ;; then split its (COUNCIL . SUMMARIZER) result back into two separate names.
         (choice (my/llm-council--choose available))
         (council (car choice)) (summarizer (cdr choice)))
    ;; WHAT/WHY/HOW: if literally no models could be found at all (Ollama unreachable,
    ;; nothing pulled), COUNCIL comes back nil and there is nothing meaningful this
    ;; command could do --- refuse clearly with `user-error' (shown in the echo area,
    ;; not a stack trace) rather than opening an empty, permanently-"waiting" buffer.
    (unless council
      (user-error "my/llm-council: no Ollama models available (is `ollama serve' running?)"))
    (let ((buf (get-buffer-create my/llm-council-buffer-name)))
      (with-current-buffer buf
        ;; WHAT/WHY: only actually switch on the major mode once --- re-entering it on
        ;; every single `C-c a c' would reset local state needlessly and is simply
        ;; unnecessary work if this buffer already exists from an earlier question.
        (unless (derived-mode-p 'my/llm-council-mode) (my/llm-council-mode))
        ;; WHAT/WHY/HOW: reset this buffer's state for the new question: remember the
        ;; query and summarizer for later (used when building headings and the summary
        ;; prompt), and build the initial entries list --- always `summary' first (so it
        ;; always renders as the first, and only initially expanded, heading), then one
        ;; `pending' entry per council model, in the same order they'll be asked.
        (setq my/llm-council--query query
              my/llm-council--summarizer summarizer
              my/llm-council--entries
              (append (list (cons 'summary (list :status 'pending)))
                      (mapcar (lambda (m) (cons m (list :status 'pending))) council)))
        ;; WHAT/WHY: draw the buffer immediately, showing all three (or however many)
        ;; models as "waiting for a response..." --- so the user sees the question was
        ;; received and work is in progress, rather than a blank buffer until the first
        ;; answer happens to arrive.
        (my/llm-council--render))
      ;; WHAT/WHY: actually show the buffer to the user now, same as `my/shortcuts' and
      ;; `my/llm-chat' both do for their own buffers.
      (switch-to-buffer buf))
    ;; WHAT/WHY/HOW: kick off all three council requests.  PENDING is created here, once,
    ;; as a single shared cons cell (see the long comment on `my/llm-council--request-
    ;; one' above for exactly why it has to be shared-by-reference rather than a plain
    ;; number) and handed to every one of the three calls below, so they all decrement
    ;; the very same counter as their answers come back in whatever order they actually
    ;; do.
    (let ((pending (cons (length council) nil)))
      (dolist (model council)
        (my/llm-council--request-one model pending)))))

;; WHAT/WHY/HOW: register this file under the Emacs feature name `llm-council', so
;; `(require 'llm-council ...)' (used both by config/init.el's autoload machinery and by
;; tests/ert/llm-council.el) can detect it has already been loaded and not load it twice.
(provide 'llm-council)
;;; llm-council.el ends here
