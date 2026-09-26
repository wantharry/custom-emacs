;;; evil-missing.el --- the toggle when Evil is not installed  -*- lexical-binding: t; -*-
;; harness: noelpa

(ert-deftest evil-missing/evil-really-is-absent ()
  (should-not (locate-library "evil"))
  (should-not (featurep 'evil)))

(ert-deftest evil-missing/declining-the-install-signals-user-error ()
  (cl-letf (((symbol-function 'y-or-n-p) (lambda (&rest _) nil)))
    (should-error (my/toggle-evil) :type 'user-error))
  (should-not (featurep 'evil)))

(ert-deftest evil-missing/accepting-the-install-calls-the-installer ()
  (let (asked)
    (cl-letf (((symbol-function 'y-or-n-p) (lambda (&rest _) t))
              ((symbol-function 'my/install-package) (lambda (p) (push p asked))))
      (should-error (my/toggle-evil)))
    (should (equal asked '(evil)))))

;;; evil-missing.el ends here
