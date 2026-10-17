;;; requireall.el --- require every built-in package, to compare a pruned Emacs against the full one  -*- lexical-binding: t; -*-
;; Usage: emacs -Q --batch -l tools/requireall.el
;; Prints "FAIL pkg: reason" for anything that fails to load, then one SUMMARY line.
;; See tools/verify-prune.sh, which runs this on both the full and the pruned build and
;; diffs the FAIL lines --- a failure that is new on the pruned build and not on the full
;; one means pruning removed a lisp file something still needs.

;; This is a one-shot smoke test, not a real editing session: skip native-comp's async
;; background compilation of everything `require'd below, which would only slow this down.
(setq native-comp-jit-compilation nil)
(require 'package)
(let ((ok 0) (fail 0))
  ;; `package--builtin-alist' (package.el's own private variable; there is no public
  ;; equivalent) is the actual list of built-in package names package.el knows about ---
  ;; sorted here purely so FAIL lines come out in a stable, readable order across runs.
  (dolist (b (sort (mapcar #'car (package--builtin-alist)) (lambda (a b) (string< (symbol-name a) (symbol-name b)))))
    ;; Each `require' is wrapped on its own, so one package missing after pruning doesn't
    ;; abort the sweep before the rest are even tried; failures print as they happen
    ;; (not collected and printed at the end), so the output is still useful even if the
    ;; whole run is later killed or times out.
    (condition-case e (progn (require b) (setq ok (1+ ok)))
      (error (setq fail (1+ fail))
             (princ (format "FAIL %s: %s\n" b (error-message-string e))))))
  (princ (format "SUMMARY ok=%d fail=%d\n" ok fail)))

;;; requireall.el ends here
