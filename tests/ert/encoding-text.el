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

;;; encoding-text.el ends here
