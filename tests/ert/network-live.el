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

;;; network-live.el ends here
