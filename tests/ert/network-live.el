;;; network-live.el --- real downloads (only with RUN_NETWORK_TESTS=1)  -*- lexical-binding: t; -*-
;; harness: bare
;; These would have caught the mm-archive pruning bug.

(require 'package) (require 'url)

(defconst live--archives '(("gnu" . "https://elpa.gnu.org/packages/")
                           ("nongnu" . "https://elpa.nongnu.org/nongnu/")))

(ert-deftest live/https-fetch ()
  (test-skip-unless-network)
  (with-current-buffer (url-retrieve-synchronously
                        "https://elpa.gnu.org/packages/archive-contents" t nil 30)
    (should (> (buffer-size) 1000))
    (kill-buffer)))

(ert-deftest live/package-refresh-finds-packages ()
  (test-skip-unless-network)
  (test-with-temp-dir d
    (let ((package-user-dir (concat d "pkgs")) (package-archives live--archives))
      (package-refresh-contents)
      (should (assq 'evil package-archive-contents))
      (should (assq 'compat package-archive-contents)))))

(ert-deftest live/package-install-works ()
  (test-skip-unless-network)
  (test-with-temp-dir d
    (let ((package-user-dir (concat d "pkgs")) (package-archives live--archives))
      (package-initialize)
      (package-refresh-contents)
      (package-install 'rainbow-mode)
      (should (package-installed-p 'rainbow-mode)))))

(ert-deftest live/nongnu-archive-contents-is-fetchable ()
  (test-skip-unless-network)
  (with-current-buffer (url-retrieve-synchronously
                        "https://elpa.nongnu.org/nongnu/archive-contents" t nil 30)
    (should (> (buffer-size) 1000))
    (kill-buffer)))

(ert-deftest live/https-fetch-returns-a-real-http-status ()
  (test-skip-unless-network)
  (require 'url-http)
  (with-current-buffer (url-retrieve-synchronously
                        "https://elpa.gnu.org/packages/archive-contents" t nil 30)
    (should (= 200 url-http-response-status))
    (kill-buffer)))

(ert-deftest live/package-archive-entries-have-real-version-info ()
  (test-skip-unless-network)
  (test-with-temp-dir d
    (let ((package-user-dir (concat d "pkgs")) (package-archives live--archives))
      (package-refresh-contents)
      (let ((entry (assq 'evil package-archive-contents)))
        (should entry)
        (should (package-desc-version (cadr entry)))))))

(ert-deftest live/magit-declares-its-real-dependencies ()
  (test-skip-unless-network)
  (test-with-temp-dir d
    (let ((package-user-dir (concat d "pkgs")) (package-archives live--archives))
      (package-refresh-contents)
      (let ((entry (assq 'magit package-archive-contents)))
        (should entry)
        (should (assq 'transient (package-desc-reqs (cadr entry))))))))

;;; network-live.el ends here
