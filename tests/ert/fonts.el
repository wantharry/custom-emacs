;;; fonts.el --- pick a font by number (C-c F) or cycle (C-c }/{)  -*- lexical-binding: t; -*-
;; harness: config
;; `find-font' needs a real display connection to mean anything (confirmed directly:
;; it returns nil for every font, installed or not, in a real --batch run with no
;; display) --- every test here mocks it instead of relying on this machine's own,
;; real, but untestable-in-batch set of installed fonts.

(defmacro fonts-test-with-mocked-find-font (installed-names &rest body)
  "Run BODY with `find-font' faked to report exactly INSTALLED-NAMES (a list of
font family strings) as present, nothing else."
  (declare (indent 1))
  `(cl-letf (((symbol-function 'find-font)
              (lambda (spec) (and (member (font-get spec :name) ,installed-names) t))))
     ,@body))

(ert-deftest fonts/key-is-bound ()
  (should (eq (key-binding (kbd "C-c F")) 'my/load-font-by-number))
  (should (eq (key-binding (kbd "C-c }")) 'my/cycle-font))
  (should (eq (key-binding (kbd "C-c {")) 'my/cycle-font-previous)))

(ert-deftest fonts/list-has-twenty-real-distinct-entries ()
  (should (= (length my/fonts) 20))
  (should (= (length (delete-dups (mapcar #'car my/fonts))) 20))   ; no duplicate keys
  (should (= (length (delete-dups (mapcar #'cdr my/fonts))) 20)))  ; no duplicate font names

(ert-deftest fonts/switching-to-an-installed-font-works ()
  (fonts-test-with-mocked-find-font '("Iosevka")
    (unwind-protect
        (let (captured)
          (cl-letf (((symbol-function 'message)
                     (lambda (fmt &rest args) (setq captured (apply #'format fmt args)))))
            (my/load-font-by-number ?2))   ; ?2 is Iosevka, see my/fonts
          (should (equal (face-attribute 'default :family nil 'default) "Iosevka"))
          (should (equal captured "Font: Iosevka")))
      (set-face-attribute 'default nil :family nil))))

(ert-deftest fonts/switching-to-a-not-installed-font-says-so-and-changes-nothing ()
  (fonts-test-with-mocked-find-font '()   ; nothing is "installed"
    (let ((before (face-attribute 'default :family nil 'default))
          captured)
      (cl-letf (((symbol-function 'message)
                 (lambda (fmt &rest args) (setq captured (apply #'format fmt args)))))
        (my/load-font-by-number ?2))   ; Iosevka, per the mock, not installed
      (should (string-match-p "not installed" captured))
      (should (equal (face-attribute 'default :family nil 'default) before)))))

(ert-deftest fonts/an-unbound-number-changes-nothing-and-says-so ()
  (should-not (alist-get ?Z my/fonts))
  (let ((before (face-attribute 'default :family nil 'default))
        captured)
    (cl-letf (((symbol-function 'message)
               (lambda (fmt &rest args) (setq captured (apply #'format fmt args)))))
      (my/load-font-by-number ?Z))
    (should (string-match-p "No font bound" captured))
    (should (equal (face-attribute 'default :family nil 'default) before))))

(ert-deftest fonts/cycle-skips-anything-not-installed ()
  ;; Only the 2nd and 4th fonts in `my/fonts' are "installed" per the mock --- cycling
  ;; forward from the 2nd must land on the 4th directly, never on the 3rd (not
  ;; installed) in between.
  (let* ((second (cdr (nth 1 my/fonts)))
         (fourth (cdr (nth 3 my/fonts))))
    (fonts-test-with-mocked-find-font (list second fourth)
      (unwind-protect
          (progn
            (set-face-attribute 'default nil :family second)
            (my/cycle-font)
            (should (equal (face-attribute 'default :family nil 'default) fourth))
            (my/cycle-font)   ; wraps back around to `second', the only other installed one
            (should (equal (face-attribute 'default :family nil 'default) second)))
        (set-face-attribute 'default nil :family nil)))))

(ert-deftest fonts/cycle-previous-goes-backward ()
  (let* ((second (cdr (nth 1 my/fonts)))
         (fourth (cdr (nth 3 my/fonts))))
    (fonts-test-with-mocked-find-font (list second fourth)
      (unwind-protect
          (progn
            (set-face-attribute 'default nil :family fourth)
            (my/cycle-font-previous)
            (should (equal (face-attribute 'default :family nil 'default) second)))
        (set-face-attribute 'default nil :family nil)))))

(ert-deftest fonts/cycle-with-nothing-installed-says-so ()
  (fonts-test-with-mocked-find-font '()
    (let (captured)
      (cl-letf (((symbol-function 'message)
                 (lambda (fmt &rest args) (setq captured (apply #'format fmt args)))))
        (my/cycle-font))
      (should (string-match-p "No fonts in my/fonts are actually installed" captured)))))

(ert-deftest fonts/relative-line-numbers-is-on ()
  ;; User request, directly: `display-line-numbers-type' set to `relative' so each
  ;; line shows its distance from point, not its own absolute number.
  (should (eq display-line-numbers-type 'relative))
  (with-temp-buffer
    (text-mode)
    (insert "a\nb\nc\n")
    (display-line-numbers-mode 1)
    (should (eq display-line-numbers 'relative))))

;;; fonts.el ends here
