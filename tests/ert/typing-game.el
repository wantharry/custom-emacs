;;; typing-game.el --- a graduated typing trainer  -*- lexical-binding: t; -*-
;; harness: config

(require 'typing-game (expand-file-name "typing-game" user-emacs-directory))

(ert-deftest typing-game/key-is-bound ()
  (should (eq (key-binding (kbd "C-c X")) 'my/typing-game)))

(ert-deftest typing-game/level-1-items-are-all-characters-from-the-alpha-set ()
  (let ((my/typing-game-length 30))
    (dolist (item (my/typing-game--build-items 1))
      (should (eq (car item) 'char))
      (should (cl-find (cdr item) my/typing-game--alpha)))))

(ert-deftest typing-game/level-2-items-can-include-digits ()
  ;; a large sample makes a digit appearing overwhelmingly likely; not flaky in
  ;; practice (30 draws from a 36-character set with 10 digits).
  (let ((my/typing-game-length 60))
    (let ((items (my/typing-game--build-items 2)))
      (should (cl-every (lambda (i) (eq (car i) 'char)) items))
      (should (cl-some (lambda (i) (cl-find (cdr i) my/typing-game--digits)) items)))))

(ert-deftest typing-game/level-3-items-can-include-special-characters ()
  (let ((my/typing-game-length 80))
    (let ((items (my/typing-game--build-items 3)))
      (should (cl-every (lambda (i) (eq (car i) 'char)) items))
      (should (cl-some (lambda (i) (cl-find (cdr i) my/typing-game--special)) items)))))

(ert-deftest typing-game/level-4-mixes-characters-and-chords ()
  (let ((my/typing-game-length 20) (my/typing-game-chord-count 10))
    (let ((items (my/typing-game--build-items 4)))
      (should (= (length items) 30))
      (should (= (cl-count 'char items :key #'car) 20))
      (should (= (cl-count 'chord items :key #'car) 10))
      ;; every chord item is a real, known chord from the curated list.
      (dolist (item items)
        (when (eq (car item) 'chord)
          (should (assoc (cadr item) my/typing-game--chords)))))))

;; real, confirmed-correct-the-hard-way property: every curated chord's own KEY
;; STRING, run through `kbd', must equal what `my/typing-game--wait-for-chord'
;; compares a real keypress against --- otherwise a correctly-typed chord would
;; never register as correct, silently making that one chord unwinnable.
(ert-deftest typing-game/every-curated-chord-matches-its-own-kbd-form ()
  (dolist (pair my/typing-game--chords)
    (let ((key (car pair)))
      (cl-letf (((symbol-function 'read-key-sequence-vector) (lambda (&rest _) (kbd key))))
        (should (my/typing-game--wait-for-chord key))))))

(ert-deftest typing-game/wait-for-chord-rejects-a-wrong-sequence ()
  (cl-letf (((symbol-function 'read-key-sequence-vector) (lambda (&rest _) (kbd "C-n"))))
    (should-not (my/typing-game--wait-for-chord "C-p"))))

(ert-deftest typing-game/wait-for-char-matches-the-exact-character ()
  (cl-letf (((symbol-function 'read-key) (lambda (&rest _) ?a)))
    (should (my/typing-game--wait-for-char ?a))
    (should-not (my/typing-game--wait-for-char ?b))))

;; the real end-to-end run, mocked input --- a real regression-shaped test: scoring
;; (correct/errors/char stats/chord stats) must match exactly what was "typed."
(ert-deftest typing-game/a-fully-correct-level-1-run-scores-100-percent ()
  (let ((my/typing-game-length 8))
    (cl-letf (((symbol-function 'my/typing-game--wait-for-char) (lambda (_expected) t)))
      (let ((stats (my/typing-game--run 1)))
        (should (= (plist-get stats :total) 8))
        (should (= (plist-get stats :correct) 8))
        (should (= (plist-get stats :errors) 0))
        (should (= (plist-get stats :char-total) 8))
        (should (= (plist-get stats :char-correct) 8))
        (should (= (plist-get stats :accuracy) 100.0))
        (should (> (plist-get stats :wpm) 0))))))

(ert-deftest typing-game/an-all-wrong-level-1-run-scores-0-percent ()
  (let ((my/typing-game-length 5))
    (cl-letf (((symbol-function 'my/typing-game--wait-for-char) (lambda (_expected) nil)))
      (let ((stats (my/typing-game--run 1)))
        (should (= (plist-get stats :correct) 0))
        (should (= (plist-get stats :errors) 5))
        (should (= (plist-get stats :accuracy) 0.0))))))

(ert-deftest typing-game/mixed-correct-and-wrong-scores-match-exactly ()
  (let ((my/typing-game-length 6) (toggle t))
    (cl-letf (((symbol-function 'my/typing-game--wait-for-char)
               (lambda (_expected) (setq toggle (not toggle)) toggle)))
      (let ((stats (my/typing-game--run 1)))
        (should (= (plist-get stats :correct) 3))
        (should (= (plist-get stats :errors) 3))
        (should (= (plist-get stats :accuracy) 50.0))))))

;; level 4's scoring must keep character stats and chord stats SEPARATE --- a
;; blended WPM across two incompatible units (letters vs. multi-key chords) would
;; be a meaningless number, not a real metric.
(ert-deftest typing-game/level-4-reports-char-and-chord-stats-separately ()
  (let ((my/typing-game-length 4) (my/typing-game-chord-count 3))
    (cl-letf (((symbol-function 'my/typing-game--wait-for-char) (lambda (_e) t))
              ((symbol-function 'my/typing-game--wait-for-chord) (lambda (_k) nil)))
      (let ((stats (my/typing-game--run 4)))
        (should (= (plist-get stats :char-total) 4))
        (should (= (plist-get stats :char-correct) 4))
        (should (= (plist-get stats :chord-total) 3))
        (should (= (plist-get stats :chord-correct) 0))
        (should (= (plist-get stats :correct) 4))
        (should (= (plist-get stats :errors) 3))))))

(ert-deftest typing-game/buffer-shows-final-results-after-a-run ()
  (let ((my/typing-game-length 3))
    (cl-letf (((symbol-function 'my/typing-game--wait-for-char) (lambda (_e) t)))
      (my/typing-game--run 1)
      (with-current-buffer "*Typing Game*"
        (should (string-match-p "Done in" (buffer-string)))
        (should (string-match-p "Characters: 3/3 correct" (buffer-string)))))))

;;; typing-game.el ends here
