;;; search-regex.el --- searching, regexps, replacement  -*- lexical-binding: t; -*-
;; harness: bare

(ert-deftest search/re-search-with-groups ()
  (test-in-buffer #'text-mode "name=alice age=30"
    (should (re-search-forward "age=\\([0-9]+\\)" nil t))
    (should (equal (match-string 1) "30"))
    (should (= (match-beginning 0) 12))))

(ert-deftest search/case-fold ()
  (let ((case-fold-search t))  (should (string-match "HELLO" "say hello")))
  (let ((case-fold-search nil)) (should-not (string-match "HELLO" "say hello"))))

(ert-deftest search/replace-match-in-buffer ()
  (test-in-buffer #'text-mode "foo bar foo"
    (while (re-search-forward "foo" nil t) (replace-match "X"))
    (should (equal (buffer-string) "X bar X"))))

(ert-deftest search/replace-regexp-in-string ()
  (should (equal (replace-regexp-in-string "\\([a-z]+\\)@" "<\\1>@" "joe@x.org")
                 "<joe>@x.org")))

(ert-deftest search/rx-builds-regexps ()
  (should (string-match-p (rx bos (+ digit) "-" (= 2 alpha) eos) "123-ab"))
  (should-not (string-match-p (rx bos (+ digit) eos) "12a"))
  (should (equal (rx (or "cat" "dog")) "\\(?:cat\\|dog\\)")))

(ert-deftest search/regexp-opt ()
  (let ((re (regexp-opt '("apple" "apricot" "banana") 'words)))
    (should (string-match-p re "an apple a day"))
    (should-not (string-match-p re "pineapple"))))

(ert-deftest search/looking-at-and-bounded-search ()
  (test-in-buffer #'text-mode "abc def"
    (should (looking-at "abc"))
    (should-not (search-forward "def" 5 t))
    (should (search-forward "def" nil t))))

(ert-deftest search/keep-and-flush-lines ()
  (test-in-buffer #'text-mode "a1\nb2\na3\n"
    (keep-lines "^a" (point-min) (point-max))
    (should (equal (buffer-string) "a1\na3\n"))
    (flush-lines "3" (point-min) (point-max))
    (should (equal (buffer-string) "a1\n"))))

(ert-deftest search/how-many ()
  (test-in-buffer #'text-mode "aXbXcX"
    (should (= 3 (how-many "X" (point-min) (point-max))))))

(ert-deftest search/string-search-and-split ()
  (should (= 3 (string-search "lo" "hello lo")))
  (should (equal (split-string " a  b c " " +" t) '("a" "b" "c")))
  (should (equal (string-join '("a" "b") "-") "a-b")))

(ert-deftest search/isearch-forward-via-real-keystrokes ()
  (test-in-buffer #'text-mode "foo bar baz bar qux"
    (execute-kbd-macro (kbd "C-s b a r RET"))
    (should (= (point) 8)) ; just past the first "bar"
    (goto-char (point-min))
    (execute-kbd-macro (kbd "C-s b a r C-s RET"))
    (should (= (point) 16)))) ; just past the SECOND "bar"

(ert-deftest search/occur-builds-a-matches-buffer ()
  (test-in-buffer #'text-mode "apple\nbanana\napple pie\n"
    (occur "apple")
    (unwind-protect
        (with-current-buffer "*Occur*"
          (should (string-match-p "2 matches for \"apple\"" (buffer-string)))
          (should (string-match-p "1:apple$" (buffer-string)))
          (should (string-match-p "3:apple pie$" (buffer-string))))
      (when (get-buffer "*Occur*") (kill-buffer "*Occur*")))))

(ert-deftest search/replace-regexp-replaces-every-match ()
  (test-in-buffer #'text-mode "cat1 cat2 cat3"
    (goto-char (point-min))
    (replace-regexp "cat\\([0-9]\\)" "dog\\1")
    (should (equal (buffer-string) "dog1 dog2 dog3"))))

(ert-deftest search/replace-string-is-literal-not-regexp ()
  (test-in-buffer #'text-mode "a.b a.b axb"
    (goto-char (point-min))
    (replace-string "a.b" "X")
    (should (equal (buffer-string) "X X axb")))) ; "axb" untouched: "." is literal here

(ert-deftest search/re-search-backward ()
  (test-in-buffer #'text-mode "one two three two one"
    (goto-char (point-max))
    (should (re-search-backward "two" nil t))
    (should (= (match-beginning 0) 15))
    (should (re-search-backward "two" nil t))
    (should (= (match-beginning 0) 5))))

(ert-deftest search/looking-back-checks-text-before-point ()
  (test-in-buffer #'text-mode "hello world"
    (goto-char 6)
    (should (looking-back "hello" 1))
    (should-not (looking-back "world" 1))))

(ert-deftest search/save-match-data-does-not-leak ()
  (string-match "foo" "a foo b")
  (let ((outer (match-data)))
    (save-match-data
      (string-match "bar" "x bar y"))
    (should (equal (match-data) outer))))

(ert-deftest search/regexp-quote-escapes-special-characters ()
  (should (string-match-p (regexp-quote "a.b*c") "a.b*c"))
  (should-not (string-match-p (regexp-quote "a.b*c") "aXbYYc")))

(ert-deftest search/count-matches ()
  (test-in-buffer #'text-mode "foo\nfoobar\nbaz foo\n"
    (should (= 3 (count-matches "foo" (point-min) (point-max))))))

(ert-deftest search/word-boundary-regexp ()
  (should (string-match-p "\\bcat\\b" "a cat sat"))
  (should-not (string-match-p "\\bcat\\b" "concatenate")))

;;; search-regex.el ends here
