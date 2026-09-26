;;; tramp.el --- remote file names (no connection is made)  -*- lexical-binding: t; -*-
;; harness: bare

(require 'tramp)

(ert-deftest tramp/dissects-an-ssh-name ()
  (let ((v (tramp-dissect-file-name "/ssh:alice@example.com#2222:/etc/hosts")))
    (should (equal (tramp-file-name-method v) "ssh"))
    (should (equal (tramp-file-name-user v) "alice"))
    (should (equal (tramp-file-name-host v) "example.com"))
    (should (equal (tramp-file-name-port v) "2222"))
    (should (equal (tramp-file-name-localname v) "/etc/hosts"))))

(ert-deftest tramp/detects-remote-names ()
  (should (file-remote-p "/ssh:a@b:/tmp"))
  (should-not (file-remote-p "/tmp"))
  (should (equal (file-remote-p "/ssh:a@b:/tmp/x" 'localname) "/tmp/x"))
  (should (equal (file-remote-p "/ssh:a@b:/tmp/x" 'host) "b")))

(ert-deftest tramp/name-arithmetic-keeps-the-prefix ()
  (should (equal (file-name-directory "/ssh:a@b:/tmp/x") "/ssh:a@b:/tmp/"))
  (should (equal (file-name-nondirectory "/ssh:a@b:/tmp/x") "x")))

(ert-deftest tramp/common-methods-are-known ()
  (dolist (m '("ssh" "scp" "sudo" "su" "rsync"))
    (should (assoc m tramp-methods))))

(ert-deftest tramp/local-files-are-untouched ()
  (test-with-temp-dir d
    (should (file-exists-p d))
    (should-not (file-remote-p d))))

;;; tramp.el ends here
