;;; mail-shr.el --- mail parsing and HTML rendering  -*- lexical-binding: t; -*-
;; harness: bare

(require 'rfc822) (require 'mail-extr) (require 'mail-utils) (require 'message)
(require 'rfc2047) (require 'mailcap) (require 'shr) (require 'dom)

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

;;; mail-shr.el ends here
