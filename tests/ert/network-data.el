;;; network-data.el --- URLs, JSON, XML, SQLite, sockets  -*- lexical-binding: t; -*-
;; harness: bare
;; Everything here works offline (sockets use the loopback interface).

(require 'url) (require 'url-util) (require 'json) (require 'xml) (require 'dom)

(ert-deftest data/url-parsing ()
  (let ((u (url-generic-parse-url "https://user@example.com:8443/a/b?x=1&y=2#frag")))
    (should (equal (url-type u) "https"))
    (should (equal (url-host u) "example.com"))
    (should (= (url-port u) 8443))
    (should (equal (url-user u) "user"))
    (should (equal (url-filename u) "/a/b?x=1&y=2"))
    (should (equal (url-target u) "frag"))))

(ert-deftest data/url-encoding ()
  (should (equal (url-hexify-string "a b&c") "a%20b%26c"))
  (should (equal (url-unhex-string "a%20b%26c") "a b&c"))
  (let ((q (url-parse-query-string "x=1&y=two")))
    (should (equal (cadr (assoc "x" q)) "1"))
    (should (equal (cadr (assoc "y" q)) "two"))))

(ert-deftest data/json-parse-and-serialize ()
  (should (equal (json-parse-string "{\"a\":[1,2,{\"b\":true}]}" :object-type 'alist :array-type 'list)
                 '((a 1 2 ((b . t))))))
  (should (equal (json-serialize '((a . 1) (b . [1 2]))) "{\"a\":1,\"b\":[1,2]}"))
  (should (equal (json-parse-string (json-serialize ["é✓"])) ["é✓"])))

(ert-deftest data/json-invalid-input-signals-error ()
  (should-error (json-parse-string "{not json")))

(ert-deftest data/xml-parsing ()
  (let ((tree (with-temp-buffer
                (insert "<a x='1'><b>hi</b></a>")
                (car (xml-parse-region (point-min) (point-max))))))
    (should (eq (car tree) 'a))
    (should (equal (xml-get-attribute tree 'x) "1"))
    (should (equal (car (xml-node-children (car (xml-get-children tree 'b)))) "hi"))))

(ert-deftest data/html-parsing-via-libxml ()
  (with-temp-buffer
    (insert "<html><body><p class='c'>text</p><p>more</p></body></html>")
    (let ((dom (libxml-parse-html-region (point-min) (point-max))))
      (should (= 2 (length (dom-by-tag dom 'p))))
      (should (equal (dom-text (car (dom-by-tag dom 'p))) "text"))
      (should (equal (dom-attr (car (dom-by-tag dom 'p)) 'class) "c")))))

(ert-deftest data/sqlite-insert-and-select ()
  (let ((db (sqlite-open)))
    (unwind-protect
        (progn
          (sqlite-execute db "create table t (id integer primary key, name text)")
          (sqlite-execute db "insert into t (name) values (?)" '("ann"))
          (sqlite-execute db "insert into t (name) values (?)" '("bob"))
          (should (equal (sqlite-select db "select name from t order by id") '(("ann") ("bob"))))
          (should (equal (sqlite-select db "select count(*) from t") '((2)))))
      (sqlite-close db))))

(ert-deftest data/sqlite-transactions-roll-back ()
  (let ((db (sqlite-open)))
    (unwind-protect
        (progn
          (sqlite-execute db "create table t (x)")
          (sqlite-transaction db)
          (sqlite-execute db "insert into t values (1)")
          (sqlite-rollback db)
          (should (equal (sqlite-select db "select count(*) from t") '((0)))))
      (sqlite-close db))))

(ert-deftest network/tcp-echo-over-loopback ()
  (let* ((srv (make-network-process
               :name "echo" :server t :host "127.0.0.1" :service t :family 'ipv4 :noquery t
               :filter (lambda (proc s) (process-send-string proc (upcase s)))))
         (port (process-contact srv :service))
         (got "")
         (cli (make-network-process
               :name "cli" :host "127.0.0.1" :service port :noquery t
               :filter (lambda (_ s) (setq got (concat got s))))))
    (unwind-protect
        (progn (process-send-string cli "ping")
               (with-timeout (5 (ert-fail "timeout"))
                 (while (string= got "") (accept-process-output nil 0.1)))
               (should (equal got "PING")))
      (delete-process cli) (delete-process srv))))

(ert-deftest network/localhost-resolves ()
  (should (network-lookup-address-info "localhost")))

;;; network-data.el ends here
