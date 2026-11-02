#lang racket

(require json racket/runtime-path redex/reduction-semantics
         "../formal/semantics.rkt" "samples.rkt" "determinism.rkt" "json-codec.rkt" "../../../tooling/json-suite.rkt")
(provide generate-suite check-suite generate-file)

(define-runtime-path frozen "../conformance/generated/determinism.json")
(define (outcome result)
  (unless (member result '(#t #f error))
    (error 'determinism "invalid evaluation result: ~s" result))
  (if (eq? result 'error) "error" result))

(define (generate-suite seed count)
  (hasheq
   'version "1.0" 'kind "determinism"
   'cases
   (for/list ([input (generate-determinism-inputs seed count)] [i (in-naturals 1)])
     (match-define (list c doc other other-doc) input)
     (unless (deterministic-evaluation? evaluate c doc other other-doc)
       (error 'determinism "non-deterministic sample ~a: ~s" i input))
     (define conditions (hasheq 'primary c 'interference other))
     (define subjects (hasheq 'primary doc 'interference other-doc))
     ;; Fix the oracle answers before replay, so later calls cannot silently
     ;; update the expected primary outcome after interference.
     (define expected
       (for*/hash ([cid '(primary interference)] [sid '(primary interference)])
         (values (list cid sid)
                 (parameterize ([caching-enabled? #f])
                   (outcome (evaluate (hash-ref conditions cid) (hash-ref subjects sid)))))))
     (hasheq
      'id (format "determinism-~a-~a" seed i)
      'description (format "Repeated and interleaved evaluation; sample ~a from seed ~a" i seed)
      'conditions (for/hasheq ([(key value) (in-hash conditions)])
                    (values key (condition->json value)))
      'subjects (for/hasheq ([(key value) (in-hash subjects)])
                  (values key (value->json value)))
      'steps (for/list ([call determinism-schedule])
               (match-define (list cache? cid sid) call)
               (hasheq 'cache cache? 'condition (symbol->string cid) 'subject (symbol->string sid)
                       'expected (hash-ref expected (list cid sid))))))))

(define (check-suite suite [eval evaluate])
  (unless (and (equal? (hash-ref suite 'version) "1.0")
               (equal? (hash-ref suite 'kind) "determinism"))
    (error 'determinism "unsupported sequence suite"))
  (define ids (make-hash))
  (define cases (hash-ref suite 'cases))
  (unless (and (list? cases) (pair? cases))
    (error 'determinism "sequence suite must contain cases"))
  (for/sum ([entry cases])
    (define id (hash-ref entry 'id))
    (when (hash-has-key? ids id) (error 'determinism "duplicate id: ~a" id))
    (hash-set! ids id #t)
    ;; Decode once per sequence. Reusing these objects is essential to testing
    ;; caches that key by AST or subject identity.
    (define conditions
      (for/hasheq ([(key value) (in-hash (hash-ref entry 'conditions))])
        (values key (json->condition value))))
    (define subjects
      (for/hasheq ([(key value) (in-hash (hash-ref entry 'subjects))])
        (values key (json->value value))))
    (define steps (hash-ref entry 'steps))
    (unless (equal? determinism-schedule
                    (for/list ([step steps])
                      (list (hash-ref step 'cache)
                            (string->symbol (hash-ref step 'condition))
                            (string->symbol (hash-ref step 'subject)))))
      (error 'determinism "~a: invalid determinism call schedule" id))
    (define step-number 0)
    (run-determinism-schedule
     eval conditions subjects
     (lambda (_call result)
       (define step (list-ref steps step-number))
       (set! step-number (add1 step-number))
       (define actual (outcome result))
       (unless (equal? actual (hash-ref step 'expected))
         (error 'determinism "~a step ~a: expected ~s, got ~s"
                id step-number (hash-ref step 'expected) actual))
       #t))
    (length steps)))

(define (check-file path)
  (define suite (call-with-input-file path read-json))
  (define calls (check-suite suite))
  (printf "Checked ~a determinism sequences (~a ordered calls).\n"
          (length (hash-ref suite 'cases)) calls))

(define (generate-file seed count output)
  (define suite (generate-suite seed count))
  ;; Validate serialization and replay before replacing the saved suite.
  (check-suite (string->jsexpr (jsexpr->string suite)))
  (write-suite output suite)
  (printf "Saved ~a determinism sequences (~a ordered calls).\n" count (* count (length determinism-schedule))))

(module+ main
  (match (vector->list (current-command-line-arguments))
    [(list "--check") (check-file frozen)]
    [(list "--check" path) (check-file path)]
    [(list seed-text count-text output)
     (define seed (string->number seed-text))
     (define count (string->number count-text))
     (unless (and (exact-nonnegative-integer? seed) (< seed (expt 2 31))
                  (exact-positive-integer? count) (<= count 100000))
       (error 'determinism "seed must be 0..2^31-1 and count 1..100000"))
     (generate-file seed count output)]
    [_ (error 'determinism "usage: racket generate-determinism.rkt --check [SUITE.json] | SEED COUNT OUTPUT.json")]))

(module+ test
  (require rackunit)
  (define suite (generate-suite 20261025 20))
  (check-equal? suite (generate-suite 20261025 20))
  (define decoded (string->jsexpr (jsexpr->string suite)))
  (check-equal? (check-suite decoded) 260)
  ;; Inspect the generated primary baseline, rather than running a duplicate
  ;; stream of random checks, to ensure the fixture sample exercises all outcomes.
  (define primary-outcomes
    (for/list ([entry (hash-ref decoded 'cases)])
      (hash-ref (car (hash-ref entry 'steps)) 'expected)))
  (for ([expected '(#t #f "error")])
    (check-not-false (member expected primary-outcomes)
                     (format "generated determinism sequences exercise ~s" expected)))
  (define entry (car (hash-ref decoded 'cases)))
  (define (with-entry replacement)
    (hash-set decoded 'cases (cons replacement (cdr (hash-ref decoded 'cases)))))
  (check-exn #rx"invalid determinism call schedule"
             (lambda () (check-suite (with-entry (hash-set entry 'steps (cdr (hash-ref entry 'steps)))))))
  (check-exn #rx"expected"
             (lambda ()
               (check-suite decoded
                            (lambda (c doc) (if (eq? (evaluate c doc) #t) #f #t)))))
  (check-exn #rx"duplicate id"
             (lambda () (check-suite (hash-set decoded 'cases (list entry entry)))))
  (check-exn #rx"must contain cases"
             (lambda () (check-suite (hash-set decoded 'cases '())))))
