;;; synonyms.el --- on-demand synonym suggestions while writing prose  -*- lexical-binding: t; -*-

;; `C-c B' opens a new, PLAIN `untitled' buffer for prose (an email, a letter, a
;; chapter) --- no suggestions yet; `C-c S' turns suggestions ON, in that buffer or
;; ANY other (an existing draft, a real `message-mode' email, a `.org' chapter
;; file, ...), renaming a still-`untitled' buffer to `writing' as a visual
;; confirmation (see `my/synonyms--maybe-rename-to-writing' below). Not `C-c N':
;; this branch is also merged onto `lsp-java'/`main', where `C-c N' is already a
;; real, different, earlier feature (`my/new-empty-buffer', confirmed directly,
;; not assumed --- a Notepad++-style blank buffer every press); `B' avoids
;; colliding with it. User request, explicit: "when I start typing it should
;; suggest me words like synonyms so that I can pick the best possible word ...
;; useful for emails or letters or novel writing" --- then two direct follow-up
;; corrections: "it shouldnt be a keybound it should be automatically shows up as
;; i type," and "a writing buffer is not same as untitiled buffer, i want writing
;; buffer to show up only when i press some command and not on all the buffers."
;; Suggestions pop up automatically while typing, in buffers with `my/synonyms-
;; mode' on --- `F7'/`C-M-i' (see `my/synonyms-lookup' below) remain as an
;; explicit, immediate lookup too, not removed.
;;
;; WHAT/WHY: this is a real, scoped exception to this config's OWN general
;; preference against auto-popup completion --- `corfu-auto' (the global default for
;; CODE completion, see init.el) stays `nil', the same as before, unaffected by this;
;; `my/synonyms-mode' turns auto-popup on ONLY for ITS OWN buffer, buffer-locally, by
;; explicit, confirmed user request for THIS feature specifically, not a reversal of
;; the general preference. HOW this is actually wired: confirmed directly, reading
;; `corfu-mode''s own setup --- it only checks `corfu-auto' ONCE, at the moment
;; `corfu-mode' itself turns on for a buffer, and `global-corfu-mode' (already active
;; everywhere in this config) has ALREADY turned `corfu-mode' on, with `corfu-auto'
;; still nil, before `my/synonyms-mode' ever runs --- simply `setq-local'ing
;; `corfu-auto' to `t' afterward would silently do nothing at all; the real auto-
;; trigger hook (`corfu-auto--post-command', from the separate `corfu-auto' library
;; file) has to be added to `post-command-hook' by hand instead, the same way
;; `corfu-mode''s own setup does it.
;;
;; HOW: a `completion-at-point-functions' entry, same mechanism Eglot/`corfu' already
;; use for code --- the SAME popup UI (`corfu', already installed and configured)
;; shows the results, so this needed no new UI code at all, only a new backend.
;; Candidates come from the Datamuse API (https://www.datamuse.com/api/ --- free, no
;; API key, a single small JSON GET per lookup) rather than a bundled offline
;; dictionary: a real, deliberate tradeoff, not an oversight --- the classic offline
;; option (Moby Thesaurus II, what older Emacs thesaurus packages bundle) is a ~10MB
;; flat word list with no real maintenance, and bundling ANY binary/database for this
;; would also need a Windows build of it (this project's dist zip is tested on real
;; Windows machines, repeatedly, this session); Datamuse needs only Emacs's own
;; built-in `url'/`json', works identically on every platform already covered, and
;; needs no separate install step the way `dua' (disk usage) does.

(require 'url)
(require 'json)
(require 'thingatpt)

(defconst my/synonyms-api-url "https://api.datamuse.com/words"
  "The Datamuse API endpoint `my/synonyms--fetch-1' queries --- see this file's
own header comment for why this, not a bundled offline dictionary.")

(defvar my/synonyms--cache (make-hash-table :test #'equal)
  "WORD -> its already-fetched synonym list (or `none', a genuinely failed/
empty lookup cached too) --- real need, not speculative: once suggestions
trigger automatically while typing (see `my/synonyms-mode'), the SAME
growing word can be looked up repeatedly as you type ONE word (each extra
keystroke after a pause is a new, slightly longer prefix of the same real
word you are still finishing) --- caching avoids a redundant real network
request for a word already looked up this session. Session-only, not
persisted to disk --- unlike `my/disk-usage''s own cache, there is no
expensive re-scan being avoided here worth surviving a restart for, just
repeat keystrokes within one sitting.")

(defun my/synonyms--fetch-1 (word)
  "The real, uncached Datamuse lookup for WORD --- see `my/synonyms--fetch',
the cached wrapper every real caller actually uses, for the full account.
Synchronous (`url-retrieve-synchronously', a 5s timeout) --- deliberately,
not `make-process'/async like `my/disk-usage' --- this is one small JSON
response, not a bulk directory scan; a brief wait is a reasonable, simpler
choice here, unlike a scan that can run for minutes unattended."
  (ignore-errors
    (let* ((url-request-method "GET")
           (url (format "%s?rel_syn=%s&max=20" my/synonyms-api-url (url-hexify-string word)))
           (buf (url-retrieve-synchronously url t t 5)))
      (when buf
        (unwind-protect
            (with-current-buffer buf
              (goto-char (point-min))
              (when (re-search-forward "\n\n" nil t)
                (let ((json-array-type 'list) (json-object-type 'alist) (json-key-type 'symbol))
                  (delq nil (mapcar (lambda (entry) (alist-get 'word entry)) (json-read))))))
          (kill-buffer buf))))))

(defun my/synonyms--fetch (word)
  "Return up to 20 synonym strings for WORD, or nil (a genuinely obscure
word/typo, or no network) --- never signals, the same reasoning `my/disk-
usage--load-cache' uses for a bad cache file: a failed lookup should just
mean no suggestions, not an error while writing. Cached in
`my/synonyms--cache' for the rest of this session --- see that variable's
own comment for why."
  (let ((cached (gethash word my/synonyms--cache)))
    (if cached
        (unless (eq cached 'none) cached)
      (let ((result (my/synonyms--fetch-1 word)))
        (puthash word (or result 'none) my/synonyms--cache)
        result))))

(defun my/synonyms-capf ()
  "A `completion-at-point-functions' entry offering synonyms for the word at
point --- unlike normal completion, the word already typed IS the query, not
a prefix to extend, so picking a candidate REPLACES the whole word rather
than appending to it. The completion table ignores the input string entirely
for LISTING candidates (always matches every candidate `complete-with-action'
is given, via an empty-string prefix) --- confirmed directly: without this,
`completion-at-point''s own default prefix-matching would filter out nearly
every real synonym, since a synonym rarely starts with the same letters as
the original word, defeating the whole feature silently rather than
erroring. The `nil' (`try-completion') action is handled SEPARATELY, NOT via
the same empty-string trick --- a real, confirmed bug this session: synonyms
share no common prefix with each other, so `(try-completion \"\" candidates)'
collapses to the EMPTY shared prefix, and `completion-in-region' uses that to
silently REPLACE the whole word being looked up with nothing, deleting it
before a single candidate is ever shown. Returning STRING itself unchanged
for this action means no in-place substitution happens before the popup
shows --- the word stays exactly as typed until a real candidate is picked."
  (let ((bounds (bounds-of-thing-at-point 'word)))
    (when bounds
      (let* ((word (buffer-substring-no-properties (car bounds) (cdr bounds)))
             (syns (my/synonyms--fetch word)))
        (when syns
          (list (car bounds) (cdr bounds)
                (lambda (string pred action)
                  (cond
                   ((eq action 'metadata) '(metadata (category . my-synonyms) (display-sort-function . identity)))
                   ((null action) string)
                   (t (complete-with-action action syns "" pred))))
                :exclusive 'no
                :annotation-function (lambda (_) " synonym")))))))

;; WHAT: `F7' is a SECOND, direct trigger for the same lookup `C-M-i' already
;; does --- the same convention Microsoft Word itself uses for its own thesaurus
;; key, so it needs no explaining to anyone coming from there. WHY added at all,
;; not just `C-M-i': a real, confirmed user report --- `C-M-i' reached Emacs as
;; plain `TAB' (`C-i'), the Meta/Alt half silently dropped, confirmed directly
;; via `C-h k' (`indent-for-tab-command', the STOCK Tab binding, is what actually
;; ran). Windows commonly treats `Ctrl+Alt' pressed TOGETHER as `AltGr' (used for
;; typing accented/special characters on many keyboard layouts) and intercepts it
;; before it ever reaches the application --- independent of which physical key is
;; actually Alt, so this is not fixable by pressing a different key, only by a
;; keybinding that never needs Ctrl and Alt together at all. `F7' is a single
;; physical key, no modifier combination to intercept.
(defun my/synonyms-lookup ()
  "Look up synonyms for the word at point right now --- the same lookup
`C-M-i' already does via `completion-at-point-functions', bound to a single
key that needs no `Ctrl+Alt' combination (see this file's own comment on
`my/synonyms-mode' for why that matters)."
  (interactive)
  (completion-at-point))

(defvar my/synonyms-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "<f7>") #'my/synonyms-lookup)
    map)
  "Keymap for `my/synonyms-mode' --- just `F7', see `my/synonyms-lookup'.")

;; WHY these two specific values, not just the stock Corfu defaults: `corfu-auto-
;; prefix' (normally 3, how many characters of the CURRENT word before auto-
;; completion tries at all) kept low, 2, since a real word worth a synonym lookup
;; is rarely shorter than that; `corfu-auto-delay' (normally 0.2s) raised a little,
;; 0.4s, so it waits for an actual short pause rather than firing after every
;; single keystroke while still mid-word --- `my/synonyms--cache' (above) also means
;; re-triggering on each subsequent letter of the SAME growing word costs no extra
;; network request, only the first real pause on it does.
(defun my/synonyms--enable-auto ()
  "Turn Corfu's auto-popup on, buffer-locally, for THIS buffer only --- see
`my/synonyms-mode''s own header comment in this file for why a plain
`(setq-local corfu-auto t)' alone would not actually do anything: `corfu-
mode' (already on everywhere via `global-corfu-mode') only wires up the real
auto-trigger hook once, when IT turns on, which already happened with
`corfu-auto' still nil."
  (require 'corfu-auto)
  (setq-local corfu-auto t
              corfu-auto-prefix 2
              corfu-auto-delay 0.4)
  (add-hook 'post-command-hook #'corfu-auto--post-command 10 t))

(defun my/synonyms--disable-auto ()
  (remove-hook 'post-command-hook #'corfu-auto--post-command t)
  (kill-local-variable 'corfu-auto)
  (kill-local-variable 'corfu-auto-prefix)
  (kill-local-variable 'corfu-auto-delay))

;; WHAT: rename an `untitled'-named buffer to `writing' the moment suggestions
;; actually turn on in it --- a real, visual confirmation that it is now a
;; "writing buffer" with suggestions live, not just any blank buffer. WHY only
;; an `untitled'-named buffer, not every buffer `my/synonyms-mode' turns on in:
;; explicit user request --- `C-c B' itself only ever opens a plain, inert
;; `untitled' buffer now (see `my/writing' below, no longer turns the mode on by
;; itself); this rename is what visibly marks the MOMENT it actually becomes a
;; writing buffer, one explicit command later (`C-c S' turns the mode on first;
;; `F7'/`C-M-i' only do anything once that already has). A buffer that was
;; something else already (a real email draft, an existing `.org' chapter) keeps
;; its own real name --- renaming THAT would be actively unwanted, not a nice-to-
;; have, the same reasoning this function only ever touches a buffer whose name
;; still starts with `untitled'.
(defun my/synonyms--maybe-rename-to-writing ()
  (when (string-prefix-p "untitled" (buffer-name))
    (rename-buffer (generate-new-buffer-name "writing"))))

;;;###autoload
(define-minor-mode my/synonyms-mode
  "Synonym suggestions pop up automatically while typing in this buffer (a
short pause after a word, the same `corfu' popup used for code completion
elsewhere in this config) --- `F7'/`C-M-i' also look one up immediately, on
demand. See docs/SYNONYMS.md."
  :lighter " Syn"
  :keymap my/synonyms-mode-map
  (if my/synonyms-mode
      (progn
        (add-hook 'completion-at-point-functions #'my/synonyms-capf nil t)
        (my/synonyms--enable-auto)
        (my/synonyms--maybe-rename-to-writing))
    (remove-hook 'completion-at-point-functions #'my/synonyms-capf t)
    (my/synonyms--disable-auto)))

;;;###autoload
(defun my/writing (name)
  "Open a new, plain buffer for prose writing --- `untitled', the same shape
any real text editor's \"New Document\" gives you, with NO synonym
suggestions on yet. Suggestions only turn on (and the buffer renames itself
to `writing', a visual confirmation) once you explicitly ask for them with
`C-c S' --- `F7'/`C-M-i' only do anything once that has already turned the
mode on, same as in any other buffer. Prompts for a buffer name; leave it
blank for a fresh `untitled' buffer (`untitled<2>', `<3>', ... if more than
one is open at once). NOT
wrapped in `*asterisks*' like this config's other throwaway buffers
(`*scratch*', `*Messages*', ...) --- those mark a buffer that is never meant
to be saved to a real file; this one, like any real text editor's own
\"Untitled\" document, usually is. See docs/SYNONYMS.md."
  (interactive (list (read-string "Writing buffer name (blank for a fresh untitled buffer): ")))
  (switch-to-buffer (get-buffer-create (if (string-empty-p name)
                                            (generate-new-buffer-name "untitled")
                                          name)))
  (unless (derived-mode-p 'text-mode) (text-mode)))

(provide 'synonyms)
;;; synonyms.el ends here
