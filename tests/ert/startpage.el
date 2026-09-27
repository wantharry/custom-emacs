;;; startpage.el --- the start screen: recent files, folders and projects  -*- lexical-binding: t; -*-
;; harness: config

(require 'startpage (expand-file-name "startpage" (or (getenv "CONFIG_DIR") user-emacs-directory)))

(defmacro sp-with-state (&rest body)
  "Run BODY with empty history, a temp store file, and no ignored paths."
  (declare (indent 0))
  `(test-with-temp-dir sp-dir
     (let ((my/start-store-file (concat sp-dir "recents.eld"))
           (my/start--folders nil) (my/start--projects nil)
           (my/start--loaded t) (my/start--dirty nil) (my/start--expanded nil)
           (my/start-ignore nil)
           (recentf-list nil))
       ,@body)))

(defun sp--make-tree (dir n)
  "Create N project folders under DIR, each a git project with one file.  Return the file names."
  (let (files)
    (dotimes (i n)
      (let* ((proj (format "%sproj%02d/" dir i)) (f (concat proj "src/File" (number-to-string i) ".txt")))
        (make-directory (concat proj ".git") t) (make-directory (concat proj "src") t)
        (with-temp-file f (insert "x"))
        (push f files)))
    (nreverse files)))

(defun sp--text (buf) (with-current-buffer buf (buffer-substring-no-properties (point-min) (point-max))))

(ert-deftest start/remembers-folder-and-project-newest-first ()
  (sp-with-state
    (let ((fs (sp--make-tree sp-dir 3)))
      (dolist (f fs) (my/start-remember (file-name-directory f)))
      (should (equal (car my/start--folders) (file-name-directory (nth 2 fs))))
      (should (equal (car my/start--projects) (concat sp-dir "proj02/")))
      ;; revisiting moves to the front instead of duplicating
      (my/start-remember (file-name-directory (car fs)))
      (should (equal (car my/start--folders) (file-name-directory (car fs))))
      (should (= 3 (length my/start--projects))))))

(ert-deftest start/no-project-for-a-plain-folder ()
  (sp-with-state
    (make-directory (concat sp-dir "plain/") t)
    (my/start-remember (concat sp-dir "plain/"))
    (should my/start--folders)
    (should-not my/start--projects)))

(ert-deftest start/ignores-configured-paths-and-remote-and-missing ()
  (sp-with-state
    (make-directory (concat sp-dir "keep/") t) (make-directory (concat sp-dir "skip/") t)
    (let ((my/start-ignore '("/skip/")))
      (my/start-remember (concat sp-dir "keep/"))
      (my/start-remember (concat sp-dir "skip/")))
    (my/start-remember "/ssh:host:/tmp/")
    (my/start-remember (concat sp-dir "nope/"))
    (should (equal my/start--folders (list (concat sp-dir "keep/"))))))

(ert-deftest start/history-is-capped ()
  (sp-with-state
    (let ((my/start-keep 4))
      (dolist (f (sp--make-tree sp-dir 9)) (my/start-remember (file-name-directory f)))
      (should (= 4 (length my/start--folders))))))

(ert-deftest start/save-and-load-round-trip ()
  (sp-with-state
    (dolist (f (sp--make-tree sp-dir 3)) (my/start-remember (file-name-directory f)))
    (my/start-save)
    (should (file-exists-p my/start-store-file))
    (let ((saved my/start--folders))
      (setq my/start--folders nil my/start--projects nil my/start--loaded nil)
      (my/start--load)
      (should (equal my/start--folders saved))
      (should (= 3 (length my/start--projects))))))

(ert-deftest start/a-corrupt-store-file-is-ignored ()
  (sp-with-state
    (with-temp-file my/start-store-file (insert "((folders . (\"a\""))
    (setq my/start--loaded nil)
    (should-not (condition-case nil (progn (my/start--load) nil) (error t)))
    (should-not my/start--folders)))

(ert-deftest start/find-file-and-dired-hooks-record-the-place ()
  (sp-with-state
    (let* ((f (car (sp--make-tree sp-dir 1))) (b (find-file-noselect f)))
      (unwind-protect
          (progn (with-current-buffer b (my/start--on-find-file))
                 (should (equal (car my/start--folders) (file-name-directory f)))
                 (should (equal (car my/start--projects) (concat sp-dir "proj00/"))))
        (kill-buffer b)))
    (make-directory (concat sp-dir "d2/") t)
    (let ((default-directory (concat sp-dir "d2/"))) (my/start--on-dired))
    (should (equal (car my/start--folders) (concat sp-dir "d2/")))
    (should (memq #'my/start--on-find-file find-file-hook))
    (should (memq #'my/start--on-dired dired-mode-hook))))

(ert-deftest start/shows-five-of-each-with-a-more-link ()
  (sp-with-state
    (let ((fs (sp--make-tree sp-dir 9)))
      (setq recentf-list (reverse fs))
      (dolist (f fs) (my/start-remember (file-name-directory f)))
      (let ((txt (sp--text (my/start-buffer))))
        (should (string-match-p "Files" txt)) (should (string-match-p "Folders" txt))
        (should (string-match-p "Projects" txt))
        (should (= 3 (with-temp-buffer (insert txt) (goto-char (point-min))
                                       (let ((n 0)) (while (search-forward "[+ 4 more]" nil t) (cl-incf n)) n))))
        ;; exactly five file rows: File8 ... File4
        (should (string-match-p "File8\\.txt" txt))
        (should (string-match-p "File4\\.txt" txt))
        (should-not (string-match-p "File3\\.txt" txt))))))

(ert-deftest start/more-link-expands-and-collapses-in-place ()
  (sp-with-state
    (let* ((fs (sp--make-tree sp-dir 9)) (buf nil))
      (setq recentf-list (reverse fs))
      (setq buf (my/start-buffer))
      (with-current-buffer buf
        (goto-char (point-min)) (search-forward "[+ 4 more]") (backward-char 2)
        (push-button)
        (should (string-match-p "File0\\.txt" (buffer-string)))
        (should (string-match-p "\\[- show fewer\\]" (buffer-string)))
        (should (memq 'files my/start--expanded))
        ;; the other sections stay collapsed
        (should-not (memq 'folders my/start--expanded))
        (goto-char (point-min)) (search-forward "[- show fewer]") (backward-char 2)
        (push-button)
        (should-not (string-match-p "File0\\.txt" (buffer-string)))))))

(ert-deftest start/enter-on-a-file-folder-and-project-opens-it ()
  (sp-with-state
    (let* ((f (car (sp--make-tree sp-dir 1))) (buf nil))
      (setq recentf-list (list f))
      (my/start-remember (file-name-directory f))
      (setq buf (my/start-buffer))
      (with-current-buffer buf
        (goto-char (point-min)) (search-forward "File0.txt") (backward-char 2)
        (push-button))
      (should (equal (buffer-file-name (window-buffer)) f))
      (kill-buffer (window-buffer))
      (with-current-buffer (my/start-buffer)
        (goto-char (point-min)) (search-forward "Projects") (forward-button 1)
        (push-button))
      (with-current-buffer (window-buffer)
        (should (derived-mode-p 'dired-mode))
        (should (equal (expand-file-name default-directory) (concat sp-dir "proj00/"))))
      (kill-buffer (window-buffer)))))

(ert-deftest start/number-keys-open-the-nth-file ()
  (sp-with-state
    (let ((fs (sp--make-tree sp-dir 3)))
      (setq recentf-list (reverse fs))     ; newest first: File2, File1, File0
      (with-current-buffer (my/start-buffer)
        (cl-letf (((symbol-function 'this-command-keys) (lambda () "2")))
          (my/start-open-nth-file)))
      (should (equal (buffer-file-name (window-buffer)) (nth 1 (reverse fs))))
      (kill-buffer (window-buffer)))))

(ert-deftest start/missing-files-and-folders-are-skipped ()
  (sp-with-state
    (let ((fs (sp--make-tree sp-dir 3)))
      (setq recentf-list (reverse fs))
      (dolist (f fs) (my/start-remember (file-name-directory f)))
      (delete-file (nth 2 fs)) (delete-directory (concat sp-dir "proj02") t)
      (let ((txt (sp--text (my/start-buffer))))
        (should-not (string-match-p "File2\\.txt" txt))
        (should-not (string-match-p "proj02" txt))
        (should (string-match-p "File1\\.txt" txt))))))

(ert-deftest start/first-run-derives-folders-and-projects-from-recentf ()
  (sp-with-state
    (let ((fs (sp--make-tree sp-dir 2)))
      (setq recentf-list (reverse fs))
      (let ((txt (sp--text (my/start-buffer))))
        (should (string-match-p "proj01" txt))
        (should (= 2 (length (my/start--entries 'projects 5))))))))

(ert-deftest start/empty-history-says-so-and-does-not-error ()
  (sp-with-state
    (let ((txt (sp--text (my/start-buffer))))
      (should (string-match-p "nothing yet" txt))
      (should (string-match-p "Recent work" txt)))))

(ert-deftest start/buffer-is-read-only-and-has-no-line-numbers ()
  (sp-with-state
    (with-current-buffer (my/start-buffer)
      (should buffer-read-only)
      (should-not display-line-numbers-mode)
      (should (derived-mode-p 'my/start-mode))
      (should-error (let ((buffer-read-only t)) (insert "x")) :type 'buffer-read-only))))

(ert-deftest start/keys-and-startup-hooks ()
  (should (eq (key-binding (kbd "C-c h")) 'my/start))
  (should (eq initial-buffer-choice #'my/start-initial-buffer))
  (with-temp-buffer
    (use-local-map my/start-mode-map)
    (should (eq (key-binding (kbd "RET")) 'push-button))
    (should (eq (key-binding (kbd "g")) 'my/start-refresh))
    (should (eq (key-binding (kbd "3")) 'my/start-open-nth-file))
    (should (eq (key-binding (kbd "f")) 'my/start-find-in-project))
    (should (eq (key-binding (kbd "m")) 'my/start-open-magit))
    (should (eq (key-binding (kbd "d")) 'my/start-open-dired))
    (should (eq (key-binding (kbd "t")) 'my/start-open-treemacs))))

;;; m/d/t: Magit, Dired and Treemacs directly on any entry (a file, folder or project),
;;; the same three actions as the git-repos list (see gitfolders.el's own tests).

(ert-deftest start/m-opens-magit-on-a-projects-own-folder ()
  (sp-with-state
    (let* ((f (car (sp--make-tree sp-dir 1))) opened (real-fboundp (symbol-function 'fboundp)))
      (my/start-remember (file-name-directory f))
      (cl-letf (((symbol-function 'magit-status) (lambda (dir) (setq opened dir)))
                ((symbol-function 'fboundp) (lambda (fn) (if (eq fn 'magit-status) t (funcall real-fboundp fn)))))
        (with-current-buffer (my/start-buffer)
          (goto-char (point-min)) (search-forward "Projects") (forward-button 1)
          (my/start-open-magit)))
      (should (equal opened (concat sp-dir "proj00/"))))))

(ert-deftest start/m-on-a-file-opens-magit-on-its-containing-folder ()
  (sp-with-state
    (let* ((f (car (sp--make-tree sp-dir 1))) opened (real-fboundp (symbol-function 'fboundp)))
      (setq recentf-list (list f))
      (cl-letf (((symbol-function 'magit-status) (lambda (dir) (setq opened dir)))
                ((symbol-function 'fboundp) (lambda (fn) (if (eq fn 'magit-status) t (funcall real-fboundp fn)))))
        (with-current-buffer (my/start-buffer)
          (goto-char (point-min)) (search-forward "File0.txt") (backward-char 2)
          (my/start-open-magit)))
      (should (equal opened (file-name-directory f))))))

(ert-deftest start/d-opens-dired-on-a-folder-entry ()
  (sp-with-state
    (make-directory (concat sp-dir "plain/") t)
    (my/start-remember (concat sp-dir "plain/"))
    (let (opened)
      (cl-letf (((symbol-function 'dired) (lambda (dir) (setq opened dir))))
        (with-current-buffer (my/start-buffer)
          (goto-char (point-min)) (search-forward "Folders") (forward-button 1)
          (my/start-open-dired)))
      (should (equal opened (concat sp-dir "plain/"))))))

(ert-deftest start/off-an-entry-m-d-and-t-say-so-instead-of-erroring ()
  (sp-with-state
    (let (msg)
      (cl-letf (((symbol-function 'message) (lambda (fmt &rest a) (setq msg (apply #'format fmt a)))))
        (with-current-buffer (my/start-buffer)
          (goto-char (point-min))
          (my/start-open-magit)
          (should (string-match-p "cursor on an entry" msg))
          (setq msg nil) (my/start-open-dired)
          (should (string-match-p "cursor on an entry" msg))
          (setq msg nil) (my/start-open-treemacs)
          (should (string-match-p "cursor on an entry" msg)))))))

(ert-deftest start/t-adds-the-folder-to-treemacs-and-reveals-it ()
  (sp-with-state
    (make-directory (concat sp-dir "plain/") t)
    (my/start-remember (concat sp-dir "plain/"))
    (let (added-path)
      (cl-letf (((symbol-function 'locate-library) (lambda (lib) (and (equal lib "treemacs") "fake.el")))
                ((symbol-function 'require) (lambda (&rest _) t))
                ((symbol-function 'treemacs-canonical-path) #'identity)
                ((symbol-function 'treemacs--find-project-for-path) (lambda (_) nil))
                ((symbol-function 'treemacs-do-add-project-to-workspace) (lambda (path _name) (setq added-path path)))
                ((symbol-function 'treemacs-current-visibility) (lambda () 'none))
                ((symbol-function 'treemacs) (lambda ()))
                ((symbol-function 'treemacs-select-window) (lambda ()))
                ((symbol-function 'treemacs-goto-file-node) (lambda (_path))))
        (with-current-buffer (my/start-buffer)
          (goto-char (point-min)) (search-forward "Folders") (forward-button 1)
          (my/start-open-treemacs)))
      (should (equal added-path (concat sp-dir "plain/"))))))

(ert-deftest start/my-start-shows-a-single-window ()
  (sp-with-state
    (save-window-excursion
      (split-window) (my/start)
      (should (= 1 (length (window-list))))
      (should (equal (buffer-name) "*start*")))))

(ert-deftest start/redraw-keeps-cursor-on-a-link ()
  (sp-with-state
    (let ((fs (sp--make-tree sp-dir 3)))
      (setq recentf-list (reverse fs))
      (with-current-buffer (my/start-buffer)
        (should (button-at (point)))
        (my/start-refresh)
        (should (button-at (point)))))))

(ert-deftest start/startup-shows-the-screen-only-when-no-file-was-opened ()
  (sp-with-state
    (with-current-buffer (get-buffer-create "*scratch*")
      (should (equal (buffer-name (my/start-initial-buffer)) "*start*")))
    (let ((b (generate-new-buffer "opened-from-the-command-line")))
      (unwind-protect (with-current-buffer b (should (eq (my/start-initial-buffer) b)))
        (kill-buffer b)))))

;;; startpage.el ends here
