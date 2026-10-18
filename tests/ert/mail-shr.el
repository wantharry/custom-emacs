;;; mail-shr.el --- mail parsing and HTML rendering  -*- lexical-binding: t; -*-
;; harness: bare

(require 'rfc822) (require 'mail-extr) (require 'mail-utils) (require 'message)
(require 'rfc2047) (require 'mailcap) (require 'shr) (require 'dom) (require 'mail-parse)

(ert-deftest mail/parses-address-lists ()
  (should (equal (rfc822-addresses "Ann <ann@x.org>, bob@y.net") '("ann@x.org" "bob@y.net"))))

(ert-deftest mail/splits-name-and-address ()
  (should (equal (mail-extract-address-components "Joe Smith <joe@x.org>") '("Joe Smith" "joe@x.org"))))

(ert-deftest mail/reads-header-fields ()
  (with-temp-buffer
    (insert "To: a@b.c\nSubject: Hi there\n")
    (should (equal (mail-fetch-field "subject") "Hi there"))
    (should (equal (mail-fetch-field "to") "a@b.c"))))

(ert-deftest mail/message-mode-headers ()
  (test-in-buffer #'message-mode "To: a@b\nSubject: t\n--text follows this line--\nhi"
    (should (equal (message-fetch-field "to") "a@b"))
    (should (equal (message-fetch-field "subject") "t"))))

(ert-deftest mail/rfc2047-encoded-words-roundtrip ()
  (let ((e (rfc2047-encode-string "héllo")))
    (should (string-match-p "=\\?" e))
    (should (equal (rfc2047-decode-string e) "héllo"))))

(ert-deftest mail/mime-types-by-extension ()
  (should (equal (mailcap-extension-to-mime "png") "image/png"))
  (should (equal (mailcap-file-name-to-mime-type "a.html") "text/html")))

(ert-deftest shr/renders-html-to-text ()
  (with-temp-buffer
   (let ((shr-width 200))
    (insert "<html><body><h1>Title</h1><p>Some <b>bold</b> text</p><ul><li>one</li><li>two</li></ul></body></html>")
    (let ((dom (libxml-parse-html-region (point-min) (point-max))))
      (erase-buffer) (shr-insert-document dom))
    (let ((s (buffer-string)))
      (should (string-match-p "Title" s))
      (should (string-match-p "Some[ \n]+bold[ \n]+text" s))
      (should (string-match-p "one" s))
      (should (string-match-p "two" s))))))

(ert-deftest shr/links-carry-their-url ()
  (with-temp-buffer
    (insert "<html><body><a href='http://e.x/'>go</a></body></html>")
    (let ((dom (libxml-parse-html-region (point-min) (point-max))))
      (erase-buffer) (shr-insert-document dom))
    (goto-char (point-min))
    (search-forward "go")
    (should (equal (get-text-property (1- (point)) 'shr-url) "http://e.x/"))))

(ert-deftest mail/rfc822-addresses-with-display-name-and-comment ()
  (should (equal (rfc822-addresses "Ann Lee <ann@x.org> (work), bob@y.net")
                 '("ann@x.org" "bob@y.net"))))

(ert-deftest mail/mail-strip-quoted-names-removes-the-display-name ()
  (should (equal (mail-strip-quoted-names "Joe Smith <joe@x.org>") "joe@x.org"))
  (should (equal (mail-strip-quoted-names "plain@x.org") "plain@x.org")))

(ert-deftest mail/mail-header-parse-address-splits-name-and-address ()
  (should (equal (mail-header-parse-address "Joe Smith <joe@x.org>") '("joe@x.org" . "Joe Smith")))
  (should (equal (mail-header-parse-address "plain@x.org") '("plain@x.org"))))

(ert-deftest mail/rfc2047-decodes-quoted-printable-and-base64 ()
  (should (equal (rfc2047-decode-string "=?utf-8?Q?h=C3=A9llo?=") "héllo"))
  (should (equal (rfc2047-decode-string
                  (concat "=?utf-8?B?" (base64-encode-string (encode-coding-string "héllo" 'utf-8)) "?="))
                 "héllo")))

(ert-deftest mail/message-mode-can-replace-a-header ()
  (test-in-buffer #'message-mode "To: a@b\nSubject: old\n--text follows this line--\nhi"
    (message-replace-header "Subject" "new")
    (should (equal (message-fetch-field "subject") "new"))))

(ert-deftest mail/message-point-in-header-p ()
  (test-in-buffer #'message-mode "To: a@b\nSubject: t\n--text follows this line--\nhi"
    (goto-char (point-min))
    (should (message-point-in-header-p))
    (goto-char (point-max))
    (should-not (message-point-in-header-p))))

(ert-deftest mailcap/mime-type-roundtrip-for-common-extensions ()
  (should (equal (mailcap-extension-to-mime "jpg") "image/jpeg"))
  (should (equal (mailcap-extension-to-mime "pdf") "application/pdf"))
  (should (equal (mailcap-extension-to-mime "txt") "text/plain")))

(ert-deftest shr/renders-tables ()
  (with-temp-buffer
    (let ((shr-width 200))
      (insert "<table><tr><td>A1</td><td>B1</td></tr><tr><td>A2</td><td>B2</td></tr></table>")
      (let ((dom (libxml-parse-html-region (point-min) (point-max))))
        (erase-buffer) (shr-insert-document dom))
      (let ((s (buffer-string)))
        (should (string-match-p "A1" s))
        (should (string-match-p "B2" s))))))

(ert-deftest shr/respects-configured-width-for-wrapping ()
  (with-temp-buffer
    (let ((shr-width 10))
      (insert "<html><body><p>one two three four five six seven eight</p></body></html>")
      (let ((dom (libxml-parse-html-region (point-min) (point-max))))
        (erase-buffer) (shr-insert-document dom))
      (should (> (length (split-string (buffer-string) "\n" t)) 1)))))

(ert-deftest shr/preformatted-text-preserves-whitespace ()
  (with-temp-buffer
    (insert "<pre>line1\n  line2</pre>")
    (let ((dom (libxml-parse-html-region (point-min) (point-max))))
      (erase-buffer) (shr-insert-document dom))
    (should (string-match-p "line1\n[ ]+line2" (buffer-string)))))

(ert-deftest shr/nested-lists-render-each-with-its-own-bullet ()
  (with-temp-buffer
    (let ((shr-width 200))
      (insert "<ul><li>top<ul><li>nested</li></ul></li></ul>")
      (let ((dom (libxml-parse-html-region (point-min) (point-max))))
        (erase-buffer) (shr-insert-document dom))
      (let ((s (buffer-string)))
        (should (< (string-match "top" s) (string-match "nested" s)))
        (should (= 2 (cl-count ?* s)))))))

(ert-deftest shr/headings-carry-their-own-face ()
  (with-temp-buffer
    (insert "<h1>Head</h1><p>body</p>")
    (let ((dom (libxml-parse-html-region (point-min) (point-max))))
      (erase-buffer) (shr-insert-document dom))
    (goto-char (point-min))
    (search-forward "Head")
    (should (get-text-property (1- (point)) 'face))))

;;; mail-shr.el ends here
