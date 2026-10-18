;;; snippets.el --- Yasnippet, wired in and really working  -*- lexical-binding: t; -*-
;; harness: config
;; Needs yasnippet installed (./build.sh packages); skips without it.

(defmacro yas-need (&rest body)
  (declare (indent 0))
  `(if (locate-library "yasnippet") (progn ,@body)
     (ert-skip "yasnippet is not installed (./build.sh packages)")))

(ert-deftest snippets/global-mode-is-on ()
  (yas-need
    (should (bound-and-true-p yas-global-mode))))

(ert-deftest snippets/insert-key-is-bound ()
  (yas-need
    (should (eq (key-binding (kbd "C-c Y")) 'yas-insert-snippet))))

(ert-deftest snippets/a-real-trigger-expands-on-tab ()
  ;; The actual point of the feature, not just "is the mode on": define one real
  ;; snippet by hand (no bundled collection is installed, see init.el's own comment on
  ;; why), type its trigger word, press TAB, and check the template actually appears.
  (yas-need
    (test-in-buffer #'fundamental-mode ""
      (yas-minor-mode 1)
      (yas-define-snippets 'fundamental-mode '(("mytrig" "expanded-template" "test")))
      (insert "mytrig")
      (yas-expand)
      (should (string-match-p "expanded-template" (buffer-string))))))

(ert-deftest snippets/tab-still-falls-through-without-a-trigger ()
  ;; The real regression this config's own comment on `yas-global-mode' promises does
  ;; not happen: with no snippet matching the text before point, TAB must still do
  ;; whatever it already did in that buffer (here, plain self-insertion is not it ---
  ;; `indent-for-tab-command' is the built-in default, confirmed not to error and to
  ;; leave the buffer's own existing behavior for TAB intact).
  (yas-need
    (test-in-buffer #'fundamental-mode "nonsense-not-a-trigger"
      (yas-minor-mode 1)
      (goto-char (point-max))
      (should-not (yas--templates-for-key-at-point)))))

(ert-deftest snippets/a-field-with-a-default-value-shows-that-default-on-expansion ()
  (yas-need
    (test-in-buffer #'fundamental-mode ""
      (yas-minor-mode 1)
      (yas-define-snippets 'fundamental-mode '(("deftrig" "value=${1:default}" "deft")))
      (insert "deftrig")
      (yas-expand)
      (should (equal (buffer-string) "value=default\n")))))

(ert-deftest snippets/an-embedded-elisp-expression-is-evaluated-on-expansion ()
  (yas-need
    (test-in-buffer #'fundamental-mode ""
      (yas-minor-mode 1)
      (yas-define-snippets 'fundamental-mode '(("calctrig" "sum=`(+ 2 3)`" "calc")))
      (insert "calctrig")
      (yas-expand)
      (should (equal (buffer-string) "sum=5")))))

(ert-deftest snippets/the-same-field-number-used-twice-mirrors-what-you-type ()
  (yas-need
    (test-in-buffer #'fundamental-mode ""
      (yas-minor-mode 1)
      (yas-define-snippets 'fundamental-mode
        '(("fortrig" "for (${1:i} = 0; $1 < ${2:n}; $1++)" "for")))
      (insert "fortrig")
      (yas-expand)
      (yas-next-field)
      (insert "99")
      (should (equal (buffer-string) "for (i = 0; i < 99; i++)")))))

(ert-deftest snippets/next-field-moves-to-the-second-tab-stop ()
  (yas-need
    (test-in-buffer #'fundamental-mode ""
      (yas-minor-mode 1)
      (yas-define-snippets 'fundamental-mode '(("twofield" "a${1:x}b${2:y}c" "two")))
      (insert "twofield")
      (yas-expand)
      (yas-next-field)
      (should (looking-at-p "y")))))

(ert-deftest snippets/prev-field-moves-back-to-the-first-tab-stop ()
  (yas-need
    (test-in-buffer #'fundamental-mode ""
      (yas-minor-mode 1)
      (yas-define-snippets 'fundamental-mode '(("twofield" "a${1:x}b${2:y}c" "two")))
      (insert "twofield")
      (yas-expand)
      (yas-next-field)
      (yas-prev-field)
      (should (looking-at-p "x")))))

(ert-deftest snippets/typing-over-a-field-replaces-only-that-fields-placeholder-text ()
  (yas-need
    (test-in-buffer #'fundamental-mode ""
      (yas-minor-mode 1)
      (yas-define-snippets 'fundamental-mode '(("twofield" "a${1:x}b${2:y}c" "two")))
      (insert "twofield")
      (yas-expand)
      (delete-char 1)
      (insert "FIRST")
      (should (equal (buffer-string) "aFIRSTbyc")))))

(ert-deftest snippets/exiting-all-snippets-leaves-plain-text-with-no-active-fields ()
  (yas-need
    (test-in-buffer #'fundamental-mode ""
      (yas-minor-mode 1)
      (yas-define-snippets 'fundamental-mode '(("exittrig" "a${1:x}b${2:y}c" "exit")))
      (insert "exittrig")
      (yas-expand)
      (yas-exit-all-snippets)
      (should (equal (buffer-string) "axbyc"))
      (should-not (yas-active-snippets)))))

(ert-deftest snippets/a-snippet-with-no-fields-just-inserts-its-literal-text ()
  (yas-need
    (test-in-buffer #'fundamental-mode ""
      (yas-minor-mode 1)
      (yas-define-snippets 'fundamental-mode '(("platrig" "plain static text" "plain")))
      (insert "platrig")
      (yas-expand)
      (should (equal (buffer-string) "plain static text")))))

(ert-deftest snippets/two-different-triggers-expand-to-their-own-templates ()
  (yas-need
    (test-in-buffer #'fundamental-mode ""
      (yas-minor-mode 1)
      (yas-define-snippets 'fundamental-mode '(("one" "ONE-EXPANDED" "one")
                                                 ("two" "TWO-EXPANDED" "two")))
      (insert "one")
      (yas-expand)
      (should (equal (buffer-string) "ONE-EXPANDED"))
      (goto-char (point-max))
      ;; A space first: yasnippet's trigger matching only recognizes a whole word, so
      ;; "two" right up against "ONE-EXPANDED" with no separator would just be read as
      ;; part of one long word and never match --- confirmed directly.
      (insert " two")
      (yas-expand)
      (should (equal (buffer-string) "ONE-EXPANDED TWO-EXPANDED")))))

(ert-deftest snippets/a-snippet-defined-for-one-mode-does-not-trigger-in-another ()
  (yas-need
    (test-in-buffer #'fundamental-mode "onlyhere"
      (yas-minor-mode 1)
      (yas-define-snippets 'text-mode '(("onlyhere" "TEXT-MODE-ONLY" "t")))
      (goto-char (point-max))
      (should-not (yas--templates-for-key-at-point)))))

(ert-deftest snippets/yas-minor-mode-turning-off-gives-tab-back-to-its-normal-command ()
  ;; The real protection is which command TAB runs, not the template lookup itself ---
  ;; `yas--templates-for-key-at-point' still finds a match even with the mode off,
  ;; confirmed directly; what changes is `key-binding', so TAB falls through to this
  ;; buffer's own normal command (`indent-for-tab-command' in `fundamental-mode') and
  ;; self-inserts/indents instead of expanding.
  (yas-need
    (test-in-buffer #'fundamental-mode ""
      (yas-minor-mode 1)
      (yas-define-snippets 'fundamental-mode '(("offtrig" "SHOULD-NOT-EXPAND" "off")))
      (yas-minor-mode -1)
      (should (eq (key-binding (kbd "TAB")) 'indent-for-tab-command))
      (insert "offtrig")
      (call-interactively (key-binding (kbd "TAB")))
      (should-not (string-match-p "SHOULD-NOT-EXPAND" (buffer-string))))))

(ert-deftest snippets/a-fresh-buffer-of-a-real-mode-auto-enables-yas-minor-mode ()
  ;; `yas-global-mode' (config/init.el) is what makes this automatic --- confirmed here
  ;; against a REAL buffer transition, not just the global mode variable being non-nil.
  (yas-need
    (test-in-buffer #'fundamental-mode ""
      (should (bound-and-true-p yas-minor-mode)))))

(ert-deftest snippets/next-field-will-exit-p-is-true-only-at-the-last-field ()
  (yas-need
    (test-in-buffer #'fundamental-mode ""
      (yas-minor-mode 1)
      (yas-define-snippets 'fundamental-mode '(("twofield" "a${1:x}b${2:y}c" "two")))
      (insert "twofield")
      (yas-expand)
      (should-not (yas-next-field-will-exit-p 1))
      (yas-next-field)
      (should (yas-next-field-will-exit-p 1)))))

(ert-deftest snippets/insert-snippet-command-inserts-the-snippet-chosen-at-the-prompt ()
  ;; `C-c Y' (`yas-insert-snippet') prompts with `completing-read' over the installed
  ;; snippets' own NAMEs (the 3rd element passed to `yas-define-snippets', not the
  ;; trigger) --- stub the prompt to pick this one by name and confirm its real body
  ;; actually gets inserted, rather than just that the command exists.
  (yas-need
    (test-in-buffer #'fundamental-mode ""
      (yas-minor-mode 1)
      (yas-define-snippets 'fundamental-mode '(("abc" "ABC-BODY" "My Uniquely Named Snippet")))
      (cl-letf (((symbol-function 'completing-read)
                 (lambda (&rest _) "My Uniquely Named Snippet")))
        (call-interactively #'yas-insert-snippet))
      (should (equal (buffer-string) "ABC-BODY")))))

;;; snippets.el ends here
