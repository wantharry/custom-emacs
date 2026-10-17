;;; everyday-bench.el --- on-demand real-GUI timing for everyday operations  -*- lexical-binding: t; -*-

;; WHAT: timing for a broad set of everyday operations --- opening a real file,
;; typing, paging, saving, a project-wide ripgrep search, Magit status, a theme
;; switch, isearch, and multiple-cursors --- against a real, medium-sized (40
;; files, ~6000 lines) demo project, driven through the real command loop
;; (`execute-kbd-macro' + explicit `redisplay'), the same discipline this
;; project's own line-numbers performance investigation established.
;;
;; WHY NOT an ERT test / NOT run by tests/run-all.sh: explicit user request,
;; same reasoning as tests/stress/bigfile-bench.el --- needs a real GUI frame
;; (a plain `--batch' invocation never exercises real redisplay) and is about
;; measuring speed, not correctness. Run via tools/stress-everyday.sh, on
;; demand, never wired into the regular regression suite.
;;
;; HOW (two real gotchas found building this, both about prompts a non-
;; interactive driver can never answer):
;;   - `mc/mark-all-like-this' asks a real `y-or-n-p' before marking a large
;;     number of matches --- auto-confirmed here, the same way a real user
;;     would just press y.
;;   - Each timed step uses its OWN untouched file where it matters (isearch,
;;     multiple-cursors) rather than the one file/type/save step mutates ---
;;     found the hard way: an earlier version typed into, then imperfectly
;;     un-typed from, the SAME file later steps searched, so a benchmark bug
;;     (not a real product issue) made "the needle string" vanish from disk.

(defvar eb/demo-dir nil
  "Set by tools/stress-everyday.sh before loading this file --- a fresh
temp directory, never the real repo, that holds the demo project.")

(defun eb/time (fn)
  (let ((start (float-time)))
    (funcall fn)
    (- (float-time) start)))

(defun eb/key (k) (execute-kbd-macro (kbd k)) (redisplay t))

(defun eb/setup-demo-project ()
  "40 real, varied Java-ish files, ~150 lines each (~6000 lines total) in a
real git repo --- a realistic 'medium project' size, not a toy 3-file fixture."
  (unless (file-directory-p eb/demo-dir)
    (make-directory eb/demo-dir t)
    (let ((default-directory eb/demo-dir))
      (call-process "git" nil nil nil "init" "-q")
      (call-process "git" nil nil nil "config" "user.email" "t@t")
      (call-process "git" nil nil nil "config" "user.name" "t")
      (dotimes (i 40)
        (with-temp-file (expand-file-name (format "File%d.java" i) eb/demo-dir)
          (insert (format "public class File%d {\n" i))
          (dotimes (j 150)
            (insert (format "    // line %d of file %d, a needle-free filler line for search benchmarks\n" j i)))
          (insert "    public static int computeNeedleValue() { return 42; }\n")
          (insert "}\n")))
      (call-process "git" nil nil nil "add" "-A")
      (call-process "git" nil nil nil "commit" "-q" "-m" "init"))))

(defun eb/round (label)
  (let (results)
    (eb/setup-demo-project)
    ;; 1. Open a real, medium file (first open, not from any cache).
    (push (list :label label :case "open a 150-line file (first time)"
                 :seconds (eb/time (lambda () (find-file (expand-file-name "File0.java" eb/demo-dir)))))
          results)
    (with-current-buffer (get-file-buffer (expand-file-name "File0.java" eb/demo-dir))
      (allow-editing)
      (goto-char (point-min))
      ;; 2. Typing: 100 real characters, one at a time (self-insert-command path).
      (push (list :label label :case "type 100 characters"
                   :seconds (eb/time (lambda () (dotimes (_ 100) (eb/key "x")))))
            results)
      (dotimes (_ 100) (ignore-errors (eb/key "<backspace>")))
      ;; 3. Scroll through the whole file with real C-v page-downs.
      (goto-char (point-min))
      (push (list :label label :case "page through the whole file (C-v x10)"
                   :seconds (eb/time (lambda () (dotimes (_ 10) (ignore-errors (eb/key "C-v"))))))
            results)
      ;; 4. Save --- back to its original, untouched content either way.
      (push (list :label label :case "save"
                   :seconds (eb/time (lambda () (basic-save-buffer))))
            results))
    ;; 5. A real, project-wide ripgrep search across all 40 files/~6000 lines.
    (let ((default-directory eb/demo-dir))
      (push (list :label label :case "ripgrep across the whole demo project (40 files, ~6000 lines)"
                   :seconds (eb/time (lambda ()
                     (with-temp-buffer
                       (call-process "rg" nil t nil "computeNeedleValue" eb/demo-dir)))))
            results))
    ;; 6. Magit status on that same real repo.
    (when (locate-library "magit")
      (require 'magit)
      (let ((default-directory eb/demo-dir))
        (push (list :label label :case "magit-status (first call, real repo, 40 files)"
                     :seconds (eb/time (lambda () (magit-status-setup-buffer default-directory))))
              results)
        (when-let* ((buf (magit-get-mode-buffer 'magit-status-mode)))
          (kill-buffer buf))))
    ;; 7. Theme switch.
    (push (list :label label :case "switch theme (C-c c 1)"
                 :seconds (eb/time (lambda () (my/load-theme-by-number ?1))))
          results)
    ;; 8. isearch in a real, UNTOUCHED file --- not the one step 2/3 typed into.
    (with-current-buffer (find-file-noselect (expand-file-name "File1.java" eb/demo-dir))
      (goto-char (point-min))
      (push (list :label label :case "isearch for a real string in the buffer"
                   :seconds (eb/time (lambda ()
                     (unless (search-forward "computeNeedleValue" nil t)
                       (error "benchmark bug: needle string not found")))))
            results))
    ;; 9. Multiple-cursors, in yet another untouched file.
    (when (locate-library "multiple-cursors")
      (require 'multiple-cursors)
      (with-current-buffer (find-file-noselect (expand-file-name "File2.java" eb/demo-dir))
        (goto-char (point-min))
        (re-search-forward "line" nil t)
        (push (list :label label :case "multiple-cursors: mark-all-like-this (\"line\", ~150 matches)"
                     :seconds (eb/time (lambda ()
                       (set-mark (match-beginning 0)) (goto-char (match-end 0))
                       (cl-letf (((symbol-function 'y-or-n-p) (lambda (&rest _) t))
                                 ((symbol-function 'yes-or-no-p) (lambda (&rest _) t)))
                         (ignore-errors (mc/mark-all-like-this)))
                       (when (bound-and-true-p multiple-cursors-mode) (mc/keyboard-quit)))))
              results)))
    ;; 10. The shortcuts reference buffer build (C-c k) --- a local tree build, no network.
    (push (list :label label :case "shortcuts buffer build (C-c k)"
                 :seconds (eb/time (lambda () (my/shortcuts-buffer))))
          results)
    (nreverse results)))

(defun eb/cleanup-buffers ()
  "Kill the per-round demo buffers so repeated rounds start clean."
  (dolist (name '("File0.java" "File1.java" "File2.java"))
    (when (get-buffer name)
      (with-current-buffer name (set-buffer-modified-p nil))
      (kill-buffer name))))

;;; everyday-bench.el ends here
