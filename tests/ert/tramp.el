;;; tramp.el --- remote file names (no connection is made)  -*- lexical-binding: t; -*-
;; harness: bare

(require 'tramp)

(ert-deftest tramp/dissects-an-ssh-name ()
  ;; `#2222' here, not `:2222' --- Tramp's own file-name syntax writes a non-default port
  ;; after `#' in the host field, since `:' already separates the host from the real
  ;; (local) path that follows it.
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

(ert-deftest tramp/dissects-an-scp-name ()
  (let ((v (tramp-dissect-file-name "/scp:bob@host.example:/var/log")))
    (should (equal (tramp-file-name-method v) "scp"))
    (should (equal (tramp-file-name-user v) "bob"))
    (should (equal (tramp-file-name-host v) "host.example"))
    (should (equal (tramp-file-name-localname v) "/var/log"))))

(ert-deftest tramp/dissects-a-rsync-name ()
  (let ((v (tramp-dissect-file-name "/rsync:bob@host:/data")))
    (should (equal (tramp-file-name-method v) "rsync"))
    (should (equal (tramp-file-name-user v) "bob"))
    (should (equal (tramp-file-name-host v) "host"))))

(ert-deftest tramp/sudo-with-no-user-defaults-to-root ()
  (let ((v (tramp-dissect-file-name "/sudo::/etc/passwd")))
    (should (equal (tramp-file-name-method v) "sudo"))
    (should (equal (tramp-file-name-user v) "root"))
    (should (equal (tramp-file-name-localname v) "/etc/passwd"))))

(ert-deftest tramp/sudo-with-an-explicit-user-overrides-the-default ()
  (let ((v (tramp-dissect-file-name "/sudo:bob@host:/etc")))
    (should (equal (tramp-file-name-user v) "bob"))
    (should (equal (tramp-file-name-host v) "host"))))

(ert-deftest tramp/su-defaults-its-user-to-root-too ()
  (let ((v (tramp-dissect-file-name "/su::/root/.bashrc")))
    (should (equal (tramp-file-name-method v) "su"))
    (should (equal (tramp-file-name-user v) "root"))))

(ert-deftest tramp/dissects-a-bracketed-ipv6-host ()
  (let ((v (tramp-dissect-file-name "/ssh:a@[2001:db8::1]:/root")))
    (should (equal (tramp-file-name-host v) "2001:db8::1"))))

(ert-deftest tramp/tramp-file-p-distinguishes-remote-from-local ()
  (should (tramp-tramp-file-p "/ssh:a@b:/x"))
  (should-not (tramp-tramp-file-p "/tmp/x"))
  (should-not (tramp-tramp-file-p "relative/path")))

(ert-deftest tramp/file-remote-p-reports-each-part ()
  (should (equal (file-remote-p "/ssh:alice@b:/x" 'method) "ssh"))
  (should (equal (file-remote-p "/ssh:alice@b:/x" 'user) "alice"))
  (should (equal (file-remote-p "/ssh:alice@b:/x" 'host) "b"))
  (should (equal (file-remote-p "/ssh:alice@b:/x" 'localname) "/x")))

(ert-deftest tramp/multi-hop-name-is-recognized-and-dissects-the-final-hop ()
  (let ((v (tramp-dissect-file-name "/ssh:a@b|sudo::/etc/hosts")))
    (should (tramp-tramp-file-p "/ssh:a@b|sudo::/etc/hosts"))
    (should (equal (tramp-file-name-method v) "sudo"))
    (should (equal (tramp-file-name-localname v) "/etc/hosts"))))

(ert-deftest tramp/directory-file-name-strips-the-trailing-slash-but-keeps-the-prefix ()
  (should (equal (directory-file-name "/ssh:a@b:/tmp/sub/") "/ssh:a@b:/tmp/sub")))

(ert-deftest tramp/file-name-as-directory-adds-a-trailing-slash-but-keeps-the-prefix ()
  (should (equal (file-name-as-directory "/ssh:a@b:/tmp/sub") "/ssh:a@b:/tmp/sub/")))

(ert-deftest tramp/file-name-absolute-p-is-true-for-remote-names ()
  (should (file-name-absolute-p "/ssh:a@b:/tmp")))

(ert-deftest tramp/relative-name-between-two-paths-on-the-same-remote ()
  (should (equal (file-relative-name "/ssh:a@b:/x/y" "/ssh:a@b:/x/") "y")))

(ert-deftest tramp/known-method-has-a-real-login-program ()
  (should (equal (tramp-get-method-parameter (tramp-dissect-file-name "/ssh:a@b:/x")
                                             'tramp-login-program)
                 "ssh")))

(ert-deftest tramp/default-method-is-itself-a-known-method ()
  (should (assoc tramp-default-method tramp-methods)))

;;; tramp.el ends here
