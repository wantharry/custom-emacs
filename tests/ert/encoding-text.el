;;; encoding-text.el --- coding systems, Unicode, hashing  -*- lexical-binding: t; -*-
;; harness: bare

(require 'url-util)

(ert-deftest encoding/utf8-roundtrip ()
  (let ((s "héllo ✓ 日本"))
    (should (equal (decode-coding-string (encode-coding-string s 'utf-8) 'utf-8) s))))

(ert-deftest encoding/byte-lengths ()
  (should (= 5 (string-bytes "é✓")))
  (should (= 2 (length "é✓"))))

(ert-deftest encoding/latin1 ()
  (should (equal (encode-coding-string "é" 'iso-8859-1) "\351"))
  (should (equal (decode-coding-string "\351" 'iso-8859-1) "é")))

(ert-deftest encoding/detects-utf8 ()
  (let ((c (detect-coding-string (encode-coding-string "héllo ✓" 'utf-8) t)))
    (should (string-prefix-p "utf-8" (symbol-name c)))))

(ert-deftest encoding/display-widths ()
  (should (= 1 (char-width ?a)))
  (should (= 2 (char-width ?日)))
  (should (= 4 (string-width "日本"))))

(ert-deftest encoding/unicode-case-conversion ()
  (should (equal (upcase "straße") "STRASSE"))
  (should (equal (downcase "ÀÉ") "àé"))
  (should (equal (capitalize "élan vital") "Élan Vital")))

(ert-deftest encoding/multibyte-strings ()
  (should (multibyte-string-p "é"))
  (should-not (multibyte-string-p "abc"))
  (should (= 233 (string-to-char "é"))))

(ert-deftest encoding/base64 ()
  (should (equal (base64-encode-string "hello") "aGVsbG8="))
  (should (equal (base64-decode-string "aGVsbG8=") "hello"))
  (should (equal (base64url-encode-string "\377\376" t) "__4")))

(ert-deftest encoding/known-hash-vectors ()
  (should (equal (md5 "abc") "900150983cd24fb0d6963f7d28e17f72"))
  (should (equal (secure-hash 'sha1 "abc") "a9993e364706816aba3e25717850c26c9cd0d89d"))
  (should (equal (secure-hash 'sha256 "abc")
                 "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")))

(ert-deftest encoding/character-properties ()
  (should (eq (get-char-code-property ?A 'general-category) 'Lu))
  (should (eq (get-char-code-property ?9 'general-category) 'Nd))
  (should (equal (url-hexify-string "a b&é") "a%20b%26%C3%A9")))

(ert-deftest encoding/utf16-roundtrip ()
  (let ((s "héllo"))
    (should (equal (decode-coding-string (encode-coding-string s 'utf-16) 'utf-16) s))))

(ert-deftest encoding/coding-system-predicates ()
  (should (coding-system-p 'utf-8))
  (should-not (coding-system-p 'not-a-real-coding-system))
  (should (eq (check-coding-system 'utf-8) 'utf-8)))

(ert-deftest encoding/unibyte-multibyte-roundtrip ()
  (let ((u (string-to-unibyte "abc")))
    (should-not (multibyte-string-p u))
    (should (multibyte-string-p (string-to-multibyte u)))
    (should (equal (string-to-multibyte u) "abc"))))

(ert-deftest encoding/url-hexify-and-unhex-roundtrip ()
  ;; `url-unhex-string' only undoes the percent-encoding; it hands back the raw UTF-8
  ;; BYTES, not decoded text --- `url-hexify-string''s own multibyte characters are
  ;; encoded as UTF-8 first, so decoding those bytes back is the caller's job too.
  (let ((s "a b&é"))
    (should (equal (decode-coding-string (url-unhex-string (url-hexify-string s)) 'utf-8) s))))

(ert-deftest encoding/encode-decode-region-in-a-real-buffer ()
  (with-temp-buffer
    (insert "héllo")
    (encode-coding-region (point-min) (point-max) 'utf-8)
    (should (= (buffer-size) 6)) ; "é" is 2 bytes in UTF-8, the rest are 1 each
    (decode-coding-region (point-min) (point-max) 'utf-8)
    (should (equal (buffer-string) "héllo"))))

(ert-deftest encoding/detects-crlf-line-endings ()
  (should (= 1 (coding-system-eol-type (detect-coding-string "a\r\nb\r\n" t)))))

(ert-deftest encoding/compare-strings-case-fold ()
  (should (eq t (compare-strings "ABC" nil nil "abc" nil nil t)))
  (should-not (eq t (compare-strings "ABC" nil nil "abc" nil nil nil))))

(ert-deftest encoding/string-width-with-wide-characters ()
  (should (= 2 (string-width "日")))
  (should (= 7 (string-width "hi 日本"))))

(ert-deftest encoding/known-sha512-vector ()
  (should (equal (secure-hash 'sha512 "abc")
                 (concat "ddaf35a193617abacc417349ae20413112e6fa4e89a97ea20a9eeee64b55d39"
                         "a2192992a274fc1a836ba3c23a3feebbd454d4423643ce80e2a9ac94fa54ca49f"))))

(ert-deftest encoding/unicode-normalization-nfc-and-nfd ()
  (require 'ucs-normalize)
  ;; "e" + a combining acute accent (U+0301), vs the single precomposed "é".
  (let ((decomposed "é") (precomposed "é"))
    (should (equal (ucs-normalize-NFC-string decomposed) precomposed))
    (should (= 2 (length (ucs-normalize-NFD-string precomposed))))))

;;; encoding-text.el ends here
