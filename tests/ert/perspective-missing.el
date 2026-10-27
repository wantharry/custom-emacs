;;; perspective-missing.el --- the toggle when `perspective' is not installed  -*- lexical-binding: t; -*-
;; harness: noelpa

(ert-deftest perspective-missing/perspective-really-is-absent ()
  (should-not (locate-library "perspective"))
  (should-not (featurep 'perspective)))

(ert-deftest perspective-missing/declining-the-install-signals-user-error ()
  (cl-letf (((symbol-function 'y-or-n-p) (lambda (&rest _) nil)))
    (should-error (my/toggle-perspective) :type 'user-error))
  (should-not (featurep 'perspective)))

(ert-deftest perspective-missing/accepting-the-install-calls-the-installer ()
  (let (asked)
    (cl-letf (((symbol-function 'y-or-n-p) (lambda (&rest _) t))
              ((symbol-function 'my/install-package) (lambda (p) (push p asked))))
      (should-error (my/toggle-perspective)))
    (should (equal asked '(perspective)))))

;;; perspective-missing.el ends here
