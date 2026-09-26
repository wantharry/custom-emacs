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

;;; search-regex.el ends here
