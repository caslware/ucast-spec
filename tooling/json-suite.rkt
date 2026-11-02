#lang racket

(require json)
(provide write-suite)

;; Keep a readable envelope and one case per line for reviewable fixture diffs.
;; Callers finish generation and validation before asking this writer to replace a file.
(define (write-suite path suite)
  (call-with-output-file path #:exists 'truncate/replace
    (lambda (out)
      (display "{\n  \"version\": " out)
      (write-json (hash-ref suite 'version) out)
      (when (hash-has-key? suite 'kind)
        (display ",\n  \"kind\": " out)
        (write-json (hash-ref suite 'kind) out))
      (display ",\n  \"cases\": [\n" out)
      (for ([entry (hash-ref suite 'cases)] [i (in-naturals)])
        (unless (zero? i) (display ",\n" out))
        (display "    " out)
        (write-json entry out))
      (display "\n  ]\n}\n" out))))
