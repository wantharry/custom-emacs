;;; llm-council.el --- 3 models asked at once, summarized by a bigger one (C-c a c)  -*- lexical-binding: t; -*-
;; harness: config
;; Real-service tests (a real HTTP round trip through Ollama, 4 real requests) only run
;; with RUN_LSP_TESTS=1 (tests/run-all.sh --lsp), same as llm.el's own real-round-trip
;; test: a real, already-running local service, not something every environment running
;; `./build.sh test' has models pulled for. Every other test here mocks `gptel-request'
;; --- its mock never schedules anything itself; the test calls the recorded callback by
;; hand whenever it wants to simulate an answer arriving, so these run synchronously and
;; deterministically, with no sit-for/timer polling needed.

(require 'llm-council (expand-file-name "llm-council" (or (getenv "CONFIG_DIR") user-emacs-directory)))

(defmacro llm-council-need-gptel ()
  `(skip-unless (locate-library "gptel")))

;;; Wiring

(ert-deftest llm-council/key-is-bound ()
  (when (locate-library "gptel")
    (should (eq (key-binding (kbd "C-c a c")) 'my/llm-council))))

(ert-deftest llm-council/is-not-loaded-until-used ()
  (let ((out (with-output-to-string
               (with-current-buffer standard-output
                 (call-process test-emacs nil t nil "--batch" "--init-directory" (getenv "CONFIG_DIR")
                               "-l" (expand-file-name "early-init.el" (getenv "CONFIG_DIR"))
                               "-l" (expand-file-name "init.el" (getenv "CONFIG_DIR"))
                               "--eval" "(princ (list (featurep 'llm-council) (autoloadp (symbol-function 'my/llm-council))))")))))
    (should (string-match-p "(nil t)" out))))

(ert-deftest llm-council/does-not-slow-startup ()
  (let ((best most-positive-fixnum))
    (dotimes (_ 3)
      (let ((t0 (float-time)))
        (call-process test-emacs nil nil nil "--batch" "--init-directory" (getenv "CONFIG_DIR")
                      "-l" (expand-file-name "early-init.el" (getenv "CONFIG_DIR"))
                      "-l" (expand-file-name "init.el" (getenv "CONFIG_DIR"))
                      "--eval" "(kill-emacs)")
        (setq best (min best (- (float-time) t0)))))
    (should (< best 0.5))))

;;; Picking models: 3 meaningfully different council models, 1 distinct bigger summarizer,
;;; using only whatever `my/llm-ollama-models' actually reports (never hardcoded).

(ert-deftest llm-council/pick-prefers-the-preferred-list-in-order ()
  (should (equal (my/llm-council--pick 3 '(a b c) '(c b a)) '(a b c))))

(ert-deftest llm-council/pick-pads-with-whatever-else-is-available-when-preferred-is-short ()
  (should (equal (my/llm-council--pick 3 '(a) '(x a y)) '(a x y))))

(ert-deftest llm-council/pick-excludes-given-models ()
  (should (equal (my/llm-council--pick 2 '(a b c) '(a b c) '(a)) '(b c))))

(ert-deftest llm-council/pick-never-repeats-a-model-listed-in-both-places ()
  (should (equal (my/llm-council--pick 5 '(a b) '(b a c)) '(a b c))))

(ert-deftest llm-council/choose-picks-council-models-closest-to-the-target-size ()
  (let ((choice (my/llm-council--choose llm-council-test--models)))
    ;; small-c (2.5GB, exact) first, then small-a/small-b (2.4/2.6GB, tied at 0.1 off,
    ;; input order breaks the tie since `sort' is stable) --- never `mid-summarizer'
    ;; (4.5GB) or `gpt-oss:20b' (13GB), both much farther from the 2.5GB target.
    (should (equal (car choice) '(small-c small-a small-b)))))

(ert-deftest llm-council/choose-picks-a-summarizer-closest-to-the-target-params-and-distinct-from-council ()
  (let ((choice (my/llm-council--choose llm-council-test--models)))
    (should (eq (cdr choice) 'mid-summarizer))
    (should-not (memq (cdr choice) (car choice)))))

(ert-deftest llm-council/choose-never-picks-an-excluded-model-as-summarizer ()
  ;; Even when it is the ONLY thing left over --- excluded outright, not just
  ;; deprioritized, matching the user's own explicit "never the 20b" ask.
  (let* ((available (list (list :name 'small-a :size-gb 2.4 :params-b 3.0)
                           (list :name 'small-b :size-gb 2.6 :params-b 3.1)
                           (list :name 'small-c :size-gb 2.5 :params-b 3.2)
                           (list :name 'gpt-oss:20b :size-gb 13.0 :params-b 21.0)))
         (choice (my/llm-council--choose available)))
    (should (equal (car choice) '(small-c small-a small-b)))
    (should-not (cdr choice))))            ; nothing left to be the summarizer but the excluded one

(ert-deftest llm-council/choose-degrades-to-fewer-models-when-fewer-are-available ()
  (let ((choice (my/llm-council--choose (list (list :name 'small-a :size-gb 2.4 :params-b 3.0)
                                               (list :name 'small-b :size-gb 2.6 :params-b 3.1)))))
    (should (equal (car choice) '(small-a small-b)))
    (should-not (cdr choice))))            ; nothing left over to be the summarizer

(ert-deftest llm-council/choose-with-only-one-model-total-uses-it-for-both-roles ()
  ;; The real ask: with nothing else pulled, that one model does all the tasks instead
  ;; of the summarizer coming back empty just because it "conflicts" with the council.
  (let ((choice (my/llm-council--choose (list (list :name 'only-one :size-gb 2.4 :params-b 3.0)))))
    (should (equal (car choice) '(only-one)))
    (should (eq (cdr choice) 'only-one))))

(ert-deftest llm-council/choose-with-only-one-model-and-it-is-excluded-still-uses-it-for-council ()
  ;; An edge case, not the common path: if the *only* model pulled happens to be the
  ;; excluded one, the exclusion still keeps it out of the summarizer role (there is
  ;; nothing to prefer it over), but it still answers as the sole council member.
  (let ((choice (my/llm-council--choose (list (list :name 'gpt-oss:20b :size-gb 13.0 :params-b 21.0)))))
    (should (equal (car choice) '(gpt-oss:20b)))
    (should-not (cdr choice))))

(ert-deftest llm-council/choose-with-nothing-available-returns-nil-for-both ()
  (should (equal (my/llm-council--choose nil) '(nil))))

;;; The results buffer: summary heading first, then one heading per council model.

(defun llm-council--fresh-entries (models)
  (append (list (cons 'summary (list :status 'pending)))
          (mapcar (lambda (m) (cons m (list :status 'pending))) models)))

(defmacro llm-council--with-test-buffer (&rest body)
  "Run BODY in the real `*llm-council*' buffer (killed afterwards), already in
`my/llm-council-mode' with a two-model query set up."
  (declare (indent 0))
  `(let ((buf (get-buffer-create my/llm-council-buffer-name)))
     (unwind-protect
         (with-current-buffer buf
           (unless (derived-mode-p 'my/llm-council-mode) (my/llm-council-mode))
           (setq my/llm-council--query "why is the sky blue?"
                 my/llm-council--summarizer 'gpt-oss:20b
                 my/llm-council--entries (llm-council--fresh-entries '(qwen3:8b llama3.1:8b)))
           (my/llm-council--render)
           ,@body)
       (kill-buffer buf))))

(ert-deftest llm-council/render-shows-the-summary-heading-before-each-model-heading ()
  (llm-council--with-test-buffer
    (let ((txt (buffer-string)))
      (should (string-match-p "why is the sky blue" txt))
      (should (string-match-p "\\* Summary (by gpt-oss:20b)" txt))
      (should (string-match-p "\\* qwen3:8b" txt))
      (should (string-match-p "\\* llama3.1:8b" txt))
      (should (< (string-match "Summary" txt) (string-match "qwen3:8b" txt))))))

(ert-deftest llm-council/render-folds-every-model-answer-but-leaves-the-summary-open ()
  (llm-council--with-test-buffer
    (goto-char (point-min))
    (re-search-forward "^\\* Summary")
    (should-not (outline-invisible-p (1+ (line-end-position))))
    (goto-char (point-min))
    (re-search-forward "^\\* qwen3:8b")
    (should (outline-invisible-p (1+ (line-end-position))))))

(ert-deftest llm-council/mode-close-and-fold-keys-are-real ()
  (llm-council--with-test-buffer
    (should (eq (key-binding (kbd "q")) 'quit-window))
    (goto-char (point-min))
    (search-forward "* ")
    (beginning-of-line)
    (should (eq (key-binding (kbd "TAB")) 'outline-cycle))))

(ert-deftest llm-council/pending-done-and-failed-entries-render-distinct-text ()
  (should (string-match-p "waiting" (my/llm-council--status-line '(m :status pending))))
  (should (string-match-p "failed" (my/llm-council--status-line '(m :status failed))))
  (should (equal "hello\n" (my/llm-council--status-line '(m :status done :text "hello")))))

;;; Sending the requests --- `gptel-request' is mocked, never a real network call here.

(defmacro llm-council--with-mock-gptel-request (calls-var &rest body)
  "Run BODY with `gptel-request' replaced by a recorder.  CALLS-VAR is bound to a list
of plists (:prompt :model :stream :callback), newest call first; nothing is invoked
automatically --- call (funcall (plist-get call :callback) RESPONSE INFO) by hand to
simulate an answer, exactly like `gptel-request's own real calling convention."
  (declare (indent 1))
  `(let (,calls-var)
     (cl-letf (((symbol-function 'gptel-request)
                (lambda (prompt &rest keys)
                  (push (list :prompt prompt :model gptel-model
                              :stream (plist-get keys :stream)
                              :callback (plist-get keys :callback))
                        ,calls-var))))
       ,@body)))

(defmacro llm-council--with-ollama-backend (available &rest body)
  "Run BODY with `gptel-backend' bound to a real Ollama backend advertising the model
names in AVAILABLE (a list of plists, as `my/llm-council--available-models' returns),
and `my/llm-council--available-models' mocked to report the same AVAILABLE (so
`my/llm-council' never needs to call `my/llm-setup-ollama' or touch the network, real
or fake, to pick its models)."
  (declare (indent 1))
  `(progn
     (llm-council-need-gptel)
     (require 'gptel-ollama)
     (let* ((available ,available)
            (names (mapcar (lambda (m) (plist-get m :name)) available))
            (gptel-backend (gptel-make-ollama "Ollama" :host "localhost:11434" :models names)))
       (cl-letf (((symbol-function 'my/llm-council--available-models) (lambda () available)))
         ,@body))))

;; WHAT: five models spanning every real selection case below --- three sized right at
;; the council's 2.5GB target (`small-a/b/c'), one sized right at the summarizer's 7B
;; target but far from 2.5GB on disk (`mid-summarizer', so it is never mistaken for a
;; council pick), and one deliberately huge and explicitly excluded
;; (`gpt-oss:20b', matching the real exclusion in `my/llm-council-summarizer-exclude').
;; WHY: shared across the tests below instead of ad hoc per test, so the same known-good
;; picking result (`small-a small-b small-c' for council, `mid-summarizer' for
;; summarizer) can just be asserted directly wherever it matters.
(defconst llm-council-test--models
  (list (list :name 'small-a :size-gb 2.4 :params-b 3.0)
        (list :name 'small-b :size-gb 2.6 :params-b 3.1)
        (list :name 'small-c :size-gb 2.5 :params-b 3.2)
        (list :name 'mid-summarizer :size-gb 4.5 :params-b 7.0)
        (list :name 'gpt-oss:20b :size-gb 13.0 :params-b 21.0)))

(ert-deftest llm-council/asks-each-council-model-with-its-own-gptel-model-and-no-streaming ()
  (llm-council--with-ollama-backend llm-council-test--models
    (llm-council--with-mock-gptel-request calls
      (unwind-protect
          (progn
            (my/llm-council "does it matter which model answers?")
            (should (= (length calls) 3))
            (should (equal (sort (mapcar (lambda (c) (symbol-name (plist-get c :model))) calls) #'string<)
                           '("small-a" "small-b" "small-c")))
            (should (cl-every (lambda (c) (eq (plist-get c :stream) nil)) calls))
            (should (cl-every (lambda (c) (equal (plist-get c :prompt) "does it matter which model answers?")) calls)))
        (kill-buffer my/llm-council-buffer-name)))))

(ert-deftest llm-council/summary-request-only-fires-once-all-three-council-answers-are-in ()
  (llm-council--with-ollama-backend llm-council-test--models
    (llm-council--with-mock-gptel-request calls
      (unwind-protect
          (progn
            (my/llm-council "q")
            (should (= (length calls) 3))
            (funcall (plist-get (nth 0 calls) :callback) "answer A" nil)
            (funcall (plist-get (nth 1 calls) :callback) "answer B" nil)
            (should (= (length calls) 3))          ; still no 4th (summary) request
            (funcall (plist-get (nth 2 calls) :callback) "answer C" nil)
            (should (= (length calls) 4))          ; the third answer triggered it
            ;; the 7B-sized model, never the excluded `gpt-oss:20b'
            (should (eq (plist-get (nth 0 calls) :model) 'mid-summarizer))
            (should (eq (plist-get (nth 0 calls) :stream) nil)))
        (kill-buffer my/llm-council-buffer-name)))))

(ert-deftest llm-council/summary-prompt-includes-every-successful-answer-labeled-by-model ()
  (llm-council--with-ollama-backend llm-council-test--models
    (llm-council--with-mock-gptel-request calls
      (unwind-protect
          (progn
            (my/llm-council "what is the capital of France?")
            (dolist (c calls) (funcall (plist-get c :callback) (format "[%s's answer]" (plist-get c :model)) nil))
            (let ((summary-prompt (plist-get (nth 0 calls) :prompt)))
              (should (string-match-p "what is the capital of France" summary-prompt))
              (should (string-match-p "small-a answered" summary-prompt))
              (should (string-match-p "small-b answered" summary-prompt))
              (should (string-match-p "small-c answered" summary-prompt))
              (should (string-match-p (regexp-quote "[small-a's answer]") summary-prompt))))
        (kill-buffer my/llm-council-buffer-name)))))

(ert-deftest llm-council/a-failed-council-answer-is-marked-failed-and-left-out-of-the-summary-prompt ()
  (llm-council--with-ollama-backend llm-council-test--models
    (llm-council--with-mock-gptel-request calls
      (unwind-protect
          (progn
            (my/llm-council "q")
            (dolist (c calls)
              (funcall (plist-get c :callback)
                       (if (eq (plist-get c :model) 'small-b) nil "a real answer") nil))
            (should (= (length calls) 4))
            (let ((summary-prompt (plist-get (nth 0 calls) :prompt)))
              (should-not (string-match-p "small-b answered" summary-prompt))
              (should (string-match-p "small-a answered" summary-prompt))
              (should (string-match-p "small-c answered" summary-prompt)))
            (with-current-buffer my/llm-council-buffer-name
              (should (eq (plist-get (alist-get 'small-b my/llm-council--entries) :status) 'failed))
              (should (eq (plist-get (alist-get 'small-a my/llm-council--entries) :status) 'done)))
            ;; and settling the summary's own callback shows up as `done' too
            (funcall (plist-get (nth 0 calls) :callback) "synthesis" nil)
            (with-current-buffer my/llm-council-buffer-name
              (should (eq (plist-get (alist-get 'summary my/llm-council--entries) :status) 'done))
              (should (string-match-p "synthesis" (buffer-string)))))
        (kill-buffer my/llm-council-buffer-name)))))

(ert-deftest llm-council/summary-is-marked-failed-and-no-request-sent-when-every-council-model-fails ()
  (llm-council--with-ollama-backend llm-council-test--models
    (cl-letf (((symbol-function 'message) (lambda (&rest _) nil)))    ; the "nothing to summarize" notice
      (llm-council--with-mock-gptel-request calls
        (unwind-protect
            (progn
              (my/llm-council "q")
              (dolist (c calls) (funcall (plist-get c :callback) nil nil))
              (should (= (length calls) 3))            ; no 4th (summary) request was ever sent
              (with-current-buffer my/llm-council-buffer-name
                (should (eq (plist-get (alist-get 'summary my/llm-council--entries) :status) 'failed))))
          (kill-buffer my/llm-council-buffer-name))))))

(ert-deftest llm-council/errors-clearly-when-no-models-are-available ()
  (llm-council--with-ollama-backend nil
    (should-error (my/llm-council "anything") :type 'user-error)))

;;; Against the real, already-running Ollama in this environment (skips if unreachable).

(ert-deftest llm-council/a-real-council-round-trip-produces-a-summary ()
  ;; Opt-in only: 4 real requests (3 council + 1 summary) to a real, already-running
  ;; local Ollama --- cold model loads can be slow the first time a model is used, so
  ;; this budgets up to 3 minutes, same order of magnitude as languages-java-rust.el's
  ;; own opt-in real-server tests.
  (skip-unless (getenv "RUN_LSP_TESTS"))
  (llm-council-need-gptel)
  (skip-unless (my/llm-ollama-models))
  (require 'gptel-ollama)
  (let ((gptel-backend gptel-backend))     ; isolate: do not leak the real backend
    (unwind-protect
        (progn
          (my/llm-council "Reply with exactly one word: PONG")
          (let ((deadline (+ (float-time) 180)))
            (while (and (< (float-time) deadline)
                        (with-current-buffer my/llm-council-buffer-name
                          (cl-some (lambda (e) (eq (plist-get (cdr e) :status) 'pending))
                                   my/llm-council--entries)))
              (accept-process-output nil 0.5)))
          (with-current-buffer my/llm-council-buffer-name
            (should-not (cl-some (lambda (e) (eq (plist-get (cdr e) :status) 'pending))
                                 my/llm-council--entries))
            (should (cl-some (lambda (e) (eq (plist-get (cdr e) :status) 'done))
                             my/llm-council--entries))))
      (when (get-buffer my/llm-council-buffer-name) (kill-buffer my/llm-council-buffer-name)))))

;;; llm-council.el ends here
