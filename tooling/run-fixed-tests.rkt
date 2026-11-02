#lang racket

(require json "trace.rkt" "json-suite.rkt")
(provide run-fixed-tests)

;; Packages provide tooling/adapter.rkt and authored suites under tests/.
;; The runner has no dependency on a package's model, term representation, or codec.
(define (collect-suites package)
  (define source (build-path package "tests"))
  (define adapter (build-path package "tooling" "adapter.rkt"))
  (define evaluate (dynamic-require adapter 'evaluate))
  (define condition->json (dynamic-require adapter 'condition->json))
  (define value->json (dynamic-require adapter 'value->json))
  (define ids (make-hash))
  (define paths
    (sort (find-files (lambda (p) (and (file-exists? p) (regexp-match? #rx"[.]rkt$" p))) source)
          path<?))
  (when (null? paths) (error 'fixed-tests "no fixed test modules found: ~a" source))
  (for/list ([path paths])
    (define tests (dynamic-require path 'tests))
    (unless (and (procedure? tests) (procedure-arity-includes? tests 0))
      (error 'fixed-tests "~a must export a zero-argument tests procedure" path))
    (define suite (call-with-evaluation-trace tests #:evaluate evaluate
                                            #:condition->json condition->json
                                            #:subject->json value->json))
    (unless (equal? suite (string->jsexpr (jsexpr->string suite)))
      (error 'fixed-tests "JSON round trip changed the trace: ~a" path))
    (for ([entry (hash-ref suite 'cases)])
      (define id (hash-ref entry 'id))
      (when (hash-has-key? ids id)
        (error 'fixed-tests "duplicate case id ~a in ~a and ~a" id (hash-ref ids id) path))
      (hash-set! ids id path))
    (cons (path-replace-extension (find-relative-path source path) #".json") suite)))

(define (run-fixed-tests mode package [output #f])
  (unless (memq mode '(test check export)) (error 'fixed-tests "unsupported mode: ~s" mode))
  (define package-root (simplify-path (path->complete-path package)))
  (define output-root (if output (simplify-path (path->complete-path output))
                          (build-path package-root "conformance")))
  ;; Finish all assertions and serialization checks before writing any fixture.
  (define suites (collect-suites package-root))
  (for ([entry suites])
    (define target (build-path output-root (car entry)))
    (case mode
      [(test) (void)]
      [(check)
       (unless (equal? (cdr entry) (call-with-input-file target read-json))
         (error 'fixed-tests "trace differs from ~a; review the authored tests and export again" target))]
      [(export)
       (make-directory* (path-only target))
       (write-suite target (cdr entry))]))
  (printf "~a ~a fixed tests from ~a suites.\n"
          (case mode [(test) "Ran"] [(check) "Checked"] [(export) "Exported"])
          (for/sum ([entry suites]) (length (hash-ref (cdr entry) 'cases)))
          (length suites)))

(module+ main
  (define (usage)
    (error 'fixed-tests "usage: racket tooling/run-fixed-tests.rkt --package PACKAGE_DIRECTORY [--test | --check | --export [OUTPUT_DIRECTORY]]"))
  (match (vector->list (current-command-line-arguments))
    [(list "--package" package args ...)
     (match args
       [(or '() (list "--test")) (run-fixed-tests 'test package)]
       [(list "--check") (run-fixed-tests 'check package)]
       [(list "--export") (run-fixed-tests 'export package)]
       [(list "--export" output) (run-fixed-tests 'export package output)]
       [_ (usage)])]
    [_ (usage)]))
