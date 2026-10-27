;;; synonyms.el --- on-demand synonym suggestions while writing prose  -*- lexical-binding: t; -*-
;; harness: config

(require 'synonyms (expand-file-name "synonyms" user-emacs-directory))

(ert-deftest synonyms/new-writing-buffer-key-is-bound ()
  (should (eq (key-binding (kbd "C-c B")) 'my/writing)))

(ert-deftest synonyms/toggle-key-is-bound ()
  (should (eq (key-binding (kbd "C-c S")) 'my/synonyms-mode)))

;; real, confirmed user report: `C-M-i' reached Emacs as plain `TAB' (`C-h k' showed
;; `indent-for-tab-command' running, not `completion-at-point') --- Windows commonly treats
;; `Ctrl+Alt' pressed together as `AltGr' and intercepts it before the app ever sees it,
;; independent of which physical key is Alt. `F7' needs no such combination.
(ert-deftest synonyms/f7-looks-up-synonyms-without-needing-ctrl-alt-together ()
  (with-temp-buffer
    (text-mode)
    (my/synonyms-mode 1)
    (should (eq (key-binding (kbd "<f7>")) 'my/synonyms-lookup))
    (cl-letf (((symbol-function 'completion-at-point)
               (lambda () (setq-local synonyms-test--f7-called t))))
      (call-interactively #'my/synonyms-lookup)
      (should (local-variable-p 'synonyms-test--f7-called)))))

(ert-deftest synonyms/f7-is-buffer-local-to-synonyms-mode ()
  (with-temp-buffer
    (text-mode)
    (should-not (eq (key-binding (kbd "<f7>")) 'my/synonyms-lookup))))

;; direct, explicit user follow-up: "a writing buffer is not same as untitiled
;; buffer, i want writing buffer to show up only when i press some command and not
;; on all the buffers" --- `C-c B' itself must open a PLAIN, inert buffer (no
;; suggestions yet); only a later, separate command (`C-c S') turns suggestions on
;; AND is what actually makes it a "writing buffer" (confirmed below by the rename).

(ert-deftest synonyms/writing-opens-a-plain-untitled-buffer-with-the-mode-off ()
  (unwind-protect
      (progn
        (my/writing "")
        (should (equal (buffer-name) "untitled"))
        (should (derived-mode-p 'text-mode))
        (should-not (bound-and-true-p my/synonyms-mode)))
    (when (get-buffer "untitled") (kill-buffer "untitled"))))

(ert-deftest synonyms/writing-with-a-name-uses-that-buffer ()
  (unwind-protect
      (progn
        (my/writing "a real email")
        (should (equal (buffer-name) "a real email")))
    (when (get-buffer "a real email") (kill-buffer "a real email"))))

(ert-deftest synonyms/turning-suggestions-on-renames-untitled-to-writing ()
  (unwind-protect
      (progn
        (my/writing "")
        (should (equal (buffer-name) "untitled"))
        (my/synonyms-mode 1)
        (should (equal (buffer-name) "writing"))
        (should (bound-and-true-p my/synonyms-mode)))
    (when (get-buffer "writing") (kill-buffer "writing"))
    (when (get-buffer "untitled") (kill-buffer "untitled"))))

;; a buffer that was already something else (a real email draft, an existing file)
;; must keep its own real name --- renaming THAT would be actively unwanted.
(ert-deftest synonyms/turning-suggestions-on-does-not-rename-a-real-buffer ()
  (unwind-protect
      (progn
        (my/writing "a real email")
        (my/synonyms-mode 1)
        (should (equal (buffer-name) "a real email")))
    (when (get-buffer "a real email") (kill-buffer "a real email"))))

(ert-deftest synonyms/turning-suggestions-off-does-not-rename-back ()
  (unwind-protect
      (progn
        (my/writing "")
        (my/synonyms-mode 1)
        (should (equal (buffer-name) "writing"))
        (my/synonyms-mode -1)
        (should (equal (buffer-name) "writing")))
    (when (get-buffer "writing") (kill-buffer "writing"))))

(ert-deftest synonyms/mode-toggle-adds-and-removes-the-capf ()
  (with-temp-buffer
    (text-mode)
    (should-not (memq #'my/synonyms-capf completion-at-point-functions))
    (my/synonyms-mode 1)
    (should (memq #'my/synonyms-capf completion-at-point-functions))
    (my/synonyms-mode -1)
    (should-not (memq #'my/synonyms-capf completion-at-point-functions))))

;; direct, explicit user follow-up request: "it shouldnt be a keybound it should be
;; automatically shows up as i type." A real, confirmed implementation detail: a bare
;; `(setq-local corfu-auto t)' alone does NOT actually turn auto-popup on --- `corfu-
;; mode' (already active everywhere via `global-corfu-mode') only wires up the real
;; trigger hook ONCE, when it itself turns on, which already happened before
;; `my/synonyms-mode' runs, with `corfu-auto' still nil at that moment.
;; Checks `local-variable-p', not a hardcoded nil/t value --- a branch can set a
;; different GLOBAL default for `corfu-auto' for its own unrelated reasons (the
;; `lsp-java' branch turns it on globally for real Eglot/jdtls Java completion), so
;; the real, branch-agnostic invariant `my/synonyms-mode' must uphold is "this
;; buffer specifically got its own LOCAL binding, another untouched buffer did
;; not" --- not "the resulting boolean happens to be nil elsewhere."
(ert-deftest synonyms/mode-on-turns-on-corfu-auto-for-this-buffer-only ()
  (let ((other (generate-new-buffer "syn-other")))
    (unwind-protect
        (with-temp-buffer
          (text-mode)
          (should-not (local-variable-p 'corfu-auto))
          (my/synonyms-mode 1)
          (should corfu-auto)
          (should (local-variable-p 'corfu-auto))
          (should (memq #'corfu-auto--post-command post-command-hook))
          ;; buffer-local, not global --- my/synonyms-mode itself must not have
          ;; made `corfu-auto' buffer-local in another, unrelated buffer.
          (should-not (with-current-buffer other (local-variable-p 'corfu-auto))))
      (kill-buffer other))))

(ert-deftest synonyms/mode-off-reverts-corfu-auto ()
  (with-temp-buffer
    (text-mode)
    (my/synonyms-mode 1)
    (my/synonyms-mode -1)
    (should-not (local-variable-p 'corfu-auto))
    (should-not (memq #'corfu-auto--post-command post-command-hook))))

;; real, user-hit bug, fixed this session: `try-completion' on a table whose
;; candidates share no common prefix with each other collapses to the EMPTY shared
;; prefix --- `completion-in-region' then used that to silently DELETE the whole
;; word being looked up before a single candidate was ever shown.
(ert-deftest synonyms/picking-a-candidate-does-not-delete-the-word-first ()
  (cl-letf (((symbol-function 'my/synonyms--fetch)
             (lambda (_word) '("halcyon" "content" "bright"))))
    (test-in-buffer #'text-mode "happy"
      (my/synonyms-mode 1)
      (goto-char (point-max))
      (let* ((result (my/synonyms-capf)) (table (nth 2 result)))
        ;; the real word, not an empty string --- the shape `corfu-auto''s own
        ;; internal `corfu--try-completion' actually calls this with.
        (should (equal (try-completion "happy" table) "happy"))
        (should (equal (buffer-string) "happy"))))))

;; a real need, not speculative: auto-popup can re-trigger several times while
;; typing ONE word (each pause after a new letter); caching the same word must not
;; cost a second real network request.
(ert-deftest synonyms/fetch-caches-so-the-same-word-is-not-fetched-twice ()
  (let ((calls 0))
    (cl-letf (((symbol-function 'my/synonyms--fetch-1)
               (lambda (_word) (setq calls (1+ calls)) '("halcyon"))))
      (my/synonyms--fetch "synonyms-test-word-gamma")
      (my/synonyms--fetch "synonyms-test-word-gamma")
      (should (= calls 1)))))

(ert-deftest synonyms/fetch-caches-a-failed-lookup-too ()
  (let ((calls 0))
    (cl-letf (((symbol-function 'my/synonyms--fetch-1) (lambda (_word) (setq calls (1+ calls)) nil)))
      (my/synonyms--fetch "synonyms-test-word-delta")
      (my/synonyms--fetch "synonyms-test-word-delta")
      (should (= calls 1)))))

(ert-deftest synonyms/mode-toggle-is-buffer-local ()
  (let ((a (generate-new-buffer "syn-a")) (b (generate-new-buffer "syn-b")))
    (unwind-protect
        (progn
          (with-current-buffer a (text-mode) (my/synonyms-mode 1))
          (should (buffer-local-value 'my/synonyms-mode a))
          (should-not (buffer-local-value 'my/synonyms-mode b)))
      (kill-buffer a) (kill-buffer b))))

;; `my/synonyms--fetch' must never signal --- a bad/missing network, an API outage, or a
;; malformed response should all just mean "no suggestions", the same reasoning
;; `my/disk-usage--load-cache' already uses for its own cache file.

;; distinct, made-up-looking words in each of these (never real `"happy"', used only
;; by the real-network test further down) --- `my/synonyms--fetch' now caches by
;; word for the rest of the session (see `my/synonyms--cache'), so two tests mocking
;; DIFFERENT results for the SAME word would collide with each other, and with the
;; real-network test's own real result for `"happy"'.

(ert-deftest synonyms/fetch-returns-nil-when-the-network-is-unavailable ()
  (cl-letf (((symbol-function 'url-retrieve-synchronously) (lambda (&rest _) nil)))
    (should-not (my/synonyms--fetch "synonyms-test-word-alpha"))))

(ert-deftest synonyms/fetch-parses-a-real-shaped-json-response ()
  (cl-letf (((symbol-function 'url-retrieve-synchronously)
             (lambda (&rest _)
               (let ((buf (generate-new-buffer " *fake-datamuse*")))
                 (with-current-buffer buf
                   (insert "HTTP/1.1 200 OK\nContent-Type: application/json\n\n")
                   (insert "[{\"word\":\"halcyon\",\"score\":61042},{\"word\":\"content\",\"score\":57050}]"))
                 buf))))
    (should (equal (my/synonyms--fetch "synonyms-test-word-beta") '("halcyon" "content")))))

(ert-deftest synonyms/fetch-returns-nil-on-an-empty-results-array ()
  (cl-letf (((symbol-function 'url-retrieve-synchronously)
             (lambda (&rest _)
               (let ((buf (generate-new-buffer " *fake-datamuse*")))
                 (with-current-buffer buf (insert "HTTP/1.1 200 OK\n\n[]"))
                 buf))))
    (should-not (my/synonyms--fetch "zxqvblorptasdf"))))

;; the real, critical correctness property of the capf: candidates are semantically
;; related, not prefix-related, to the word typed --- `completion-at-point''s own
;; default prefix filtering would otherwise silently drop nearly every real synonym.
(ert-deftest synonyms/capf-offers-every-candidate-regardless-of-the-typed-prefix ()
  (cl-letf (((symbol-function 'my/synonyms--fetch)
             (lambda (_word) '("halcyon" "content" "bright"))))
    (test-in-buffer #'text-mode "happy"
      (my/synonyms-mode 1)
      (goto-char (point-max))
      (let* ((result (my/synonyms-capf))
             (table (nth 2 result)))
        (should (equal (nth 0 result) 1))
        (should (equal (nth 1 result) 6))
        ;; the word itself is a terrible prefix match for its own synonyms --- all
        ;; three must still come back, not be filtered out.
        (should (equal (sort (complete-with-action t table "happy" nil) #'string<)
                        '("bright" "content" "halcyon")))))))

(ert-deftest synonyms/capf-returns-nil-when-there-are-no-synonyms ()
  (cl-letf (((symbol-function 'my/synonyms--fetch) (lambda (_word) nil)))
    (test-in-buffer #'text-mode "zxqvblorptasdf"
      (my/synonyms-mode 1)
      (goto-char (point-max))
      (should-not (my/synonyms-capf)))))

;; a real, live network call --- `tests/run-all.sh --network' only.
(ert-deftest synonyms/real-network-fetch-returns-real-synonyms ()
  (test-skip-unless-network)
  (let ((syns (my/synonyms--fetch "happy")))
    (should syns)
    (should (member "joyful" syns))))

;;; synonyms.el ends here
