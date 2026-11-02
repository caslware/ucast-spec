#lang racket

(require json redex/reduction-semantics racket/runtime-path
         "../formal/language.rkt" "../formal/semantics.rkt" "samples.rkt" "coverage.rkt" "json-codec.rkt" "../../../tooling/json-suite.rkt"
         (only-in "generate-determinism.rkt" [check-suite check-determinism-suite]
                  [generate-file generate-determinism-file]))

(define-runtime-path corpus "../conformance")
(define (outcome r) (if (eq? r 'error) "error" r))
(define (check-corpus [directory corpus])
  (define ids (make-hash))
  (define sequences 0)
  (define calls 0)
  (for ([path (sort (find-files (lambda (p) (regexp-match? #rx"[.]json$" p)) directory) path<?)])
    (define suite (call-with-input-file path read-json))
    (unless (equal? (hash-ref suite 'version) "1.0") (error 'corpus "unsupported version: ~a" path))
    (for ([entry (hash-ref suite 'cases)])
      (define id (hash-ref entry 'id))
      (when (hash-has-key? ids id) (error 'corpus "duplicate id: ~a" id))
      (hash-set! ids id #t))
    (match (hash-ref suite 'kind #f)
      ["determinism"
       (set! calls (+ calls (check-determinism-suite suite)))
       (set! sequences (+ sequences (length (hash-ref suite 'cases))))]
      [#f
       (for ([entry (hash-ref suite 'cases)])
         (define actual (outcome (evaluate (json->condition (hash-ref entry 'ast))
                                          (json->value (hash-ref entry 'subject)))))
         (unless (equal? actual (hash-ref entry 'expected))
           (error 'corpus "~a (~a): expected ~s; model returned ~s"
                  (hash-ref entry 'id) path (hash-ref entry 'expected) actual)))]
      [kind (error 'corpus "unsupported suite kind ~s: ~a" kind path)]))
  (printf "Checked ~a corpus cases (~a determinism sequences, ~a ordered sequence calls) against the model.\n"
          (hash-count ids) sequences calls))
(define-syntax-rule (field-sampler op payload)
  (cons 'op (generate-term Sample ((field op path payload) val))))
;; Restrictions of Sample, not constructed AST/document witnesses. Both trees
;; remain independently generated; coverage search focuses on missing operators.
(define root-samplers
  (list (cons 'and (generate-term Sample ((and condition ...) val)))
        (cons 'or (generate-term Sample ((or condition ...) val)))
        (cons 'nor (generate-term Sample ((nor condition ...) val)))
        (cons 'not (generate-term Sample ((not condition) val)))
        (field-sampler eq scalar) (field-sampler ne scalar)
        (field-sampler lt scalar) (field-sampler lte scalar)
        (field-sampler gt scalar) (field-sampler gte scalar)
        (field-sampler exists boolean) (field-sampler size n)
        (field-sampler mod (array n_1 n_2))
        (field-sampler within (array scalar ...))
        (field-sampler in (array scalar ...))
        (field-sampler nin (array scalar ...))
        (field-sampler all (array scalar ...))
        (field-sampler regex (regexp pattern))
        (cons 'elemMatch (generate-term Sample ((elemMatch path condition) val)))))
(define sample-pair (generate-term Sample (condition val)))
(define sample-logical-pair (generate-term Sample (condition_1 condition_2 val)))
(define (generate-cases seed count)
  (define coverage (make-generator-coverage))
  (define attempts 0)
  (define cases
    (parameterize ([redex-pseudo-random-generator (make-pseudo-random-generator)])
      (parameterize ([current-pseudo-random-generator (redex-pseudo-random-generator)]) (random-seed seed))
      (let loop ([saved '()] [i 0] [pending '()])
        ;; Bound unsuccessful search before opening/replacing the output file.
        (when (>= attempts (+ count 200000))
          (error 'generate-tests "coverage search exhausted after ~a attempts; missing: ~s"
                 attempts (missing-coverage coverage)))
        (cond
          [(null? pending)
           (define size (+ 1 (modulo attempts 6)))
           (define candidates
             (cond
               [(not (logical-coverage-complete? coverage))
                (match-define (list a b raw-doc) (sample-logical-pair size))
                (define doc (unique-keys raw-doc))
                (for/list ([variant (logical-variants a b doc)])
                  (match-define (list name c expected) variant)
                  (list name c doc expected))]
               [else
                (define missing-ops (missing-root-operators coverage))
                (define sampler
                  (if (null? missing-ops) sample-pair
                      (cdr (assq (list-ref missing-ops (modulo attempts (length missing-ops))) root-samplers))))
                (match-define (list c raw-doc) (sampler size))
                (define doc (unique-keys raw-doc))
                (list (list "Redex sample" c doc (evaluate c doc)))]))
           (loop saved i candidates)]
          [else
           (match-define (list name c doc expected) (car pending))
           (set! attempts (add1 attempts))
           (define-values (result retained?) (consider-case! coverage c doc #:only-new? #t))
           (unless (and (member result '(#t #f error)) (equal? result expected))
             (error 'generate-tests "~a failed for ~s on ~s: expected ~s, got ~s"
                    name c doc expected result))
           (cond
             [retained?
              (define entry
                (hasheq 'id (format "generated-~a-~a" seed (add1 i))
                        'description (format "~a; sample ~a from seed ~a" name (add1 i) seed)
                        'ast (condition->json c) 'subject (value->json doc)
                        'expected (outcome expected)))
              (if (= (add1 i) count) (reverse (cons entry saved))
                  (loop (cons entry saved) (add1 i) (cdr pending)))]
             [else (loop saved i (cdr pending))])]))))
  (values cases coverage attempts))
(define (generate seed count output)
  (define-values (cases coverage attempts) (generate-cases seed count))
  (write-suite output (hasheq 'version "1.0" 'cases cases))
  (printf "Saved ~a cases from ~a attempts.\n" count attempts)
  (print-coverage coverage))
(define (generate-all [output corpus] #:seed [seed 20261025]
                      #:case-count [case-count 100000]
                      #:determinism-count [determinism-count 1000])
  (unless (and (exact-nonnegative-integer? seed) (< seed (expt 2 31))
               (exact-positive-integer? case-count) (<= case-count 100000)
               (exact-positive-integer? determinism-count) (<= determinism-count 100000))
    (error 'generate-tests "seed must be 0..2^31-1 and both counts 1..100000"))
  (define staged (make-temporary-file "ucast-generated-~a" 'directory))
  (dynamic-wind
    void
    (lambda ()
      ;; Generate and replay both outputs before replacing either saved fixture.
      (define evaluator-file (build-path staged "evaluator.json"))
      (define determinism-file (build-path staged "determinism.json"))
      (generate seed case-count evaluator-file)
      (generate-determinism-file seed determinism-count determinism-file)
      (check-corpus staged)
      (define directory (build-path output "generated"))
      (make-directory* directory)
      (for ([source (list evaluator-file determinism-file)]
            [filename '("coverage-based.json" "determinism.json")])
        (copy-file source (build-path directory filename) #t)))
    (lambda () (delete-directory/files staged))))

(define (check-coverage path)
  (define coverage (make-generator-coverage))
  (define suite (call-with-input-file path read-json))
  (unless (equal? (hash-ref suite 'version) "1.0")
    (error 'coverage "unsupported suite version: ~a" path))
  (for ([entry (hash-ref suite 'cases)])
    (define c (json->condition (hash-ref entry 'ast)))
    (define doc (json->value (hash-ref entry 'subject)))
    (define-values (result _retained?) (consider-case! coverage c doc))
    (unless (equal? (outcome result) (hash-ref entry 'expected))
      (error 'coverage "model disagrees with ~a" (hash-ref entry 'id))))
  (print-coverage coverage)
  (unless (coverage-complete? coverage)
    (error 'coverage "incomplete evaluator coverage")))
(module+ main
  (match (vector->list (current-command-line-arguments))
    [(or '() (list "--generate")) (generate-all)]
    [(list "--generate" output) (generate-all output)]
    [(list "--check") (check-corpus)]
    [(list "--coverage" path) (check-coverage path)]
    [(list seed-text count-text output)
     (define seed (string->number seed-text))
     (define count (string->number count-text))
     (unless (and (exact-nonnegative-integer? seed) (< seed (expt 2 31))
                  (exact-positive-integer? count) (<= count 100000))
       (error 'generate-tests "seed must be 0..2^31-1 and count 1..100000"))
     (generate seed count output)]
    [_ (error 'generate-tests "usage: racket generate-tests.rkt [--generate [OUTPUT_DIRECTORY] | --check | --coverage SUITE.json | SEED COUNT OUTPUT.json]")]))

(module+ test
  (require rackunit (only-in "generate-determinism.rkt" generate-suite))
  (for ([v (list 'null 'missing #t 18 "null"
                 '(array null missing "missing")
                 '(object ("tag" "missing"))
                 '(object ("a" (array missing null)) ))])
    (check-equal? (json->value (value->json v)) v))
  (define c '(and (field eq "a" null)
                   (not (elemMatch "items" (field gt "__itself__" 1)))))
  (check-equal? (json->condition (condition->json c)) c)
  (define regex-condition '(field regex "a" (regexp "^a")))
  (check-equal? (json->condition (condition->json regex-condition)) regex-condition)
  (check-equal? (json->value (hasheq '$ucast "undefined")) 'missing)
  (check-equal? (map car root-samplers) operators)
  ;; Exercise the real selection loop, including discarded attempts, rather
  ;; than supplying curated witnesses to the coverage accumulator.
  (define-values (cases coverage attempts) (generate-cases 20261025 250))
  (check-equal? (length cases) 250)
  (check-equal? (missing-coverage coverage) '())
  (check-true (> attempts 250))
  (define-values (repeated repeated-coverage repeated-attempts) (generate-cases 20261025 250))
  (check-equal? repeated cases)
  (check-equal? repeated-attempts attempts)
  (check-equal? (missing-coverage repeated-coverage) '())
  ;; Replay the serialized representation and independently remeasure coverage.
  (define replay-coverage (make-generator-coverage))
  (for ([entry cases])
    (define decoded (string->jsexpr (jsexpr->string entry)))
    (define ast (json->condition (hash-ref decoded 'ast)))
    (define doc (json->value (hash-ref decoded 'subject)))
    (define-values (result _retained?) (consider-case! replay-coverage ast doc))
    (check-equal? (outcome result) (hash-ref decoded 'expected)))
  (check-equal? (missing-coverage replay-coverage) '())
  (check-equal? (with-output-to-string (lambda () (print-coverage replay-coverage)))
                (with-output-to-string (lambda () (print-coverage coverage))))
  ;; Small samples retain the requested size and truthfully report their gaps.
  (define-values (small small-coverage small-attempts) (generate-cases 0 1))
  (check-equal? (length small) 1)
  (check-false (coverage-complete? small-coverage))
  ;; The main corpus command must replay sequences, not merely skip their files.
  (define mixed-corpus (make-temporary-file "ucast-corpus-~a" 'directory))
  (dynamic-wind
    void
    (lambda ()
      (define (save name suite)
        (call-with-output-file (build-path mixed-corpus name) #:exists 'truncate/replace
          (lambda (out) (write-json suite out))))
      (save "single.json" (hasheq 'version "1.0" 'cases (list (car cases))))
      (define sequence-suite (generate-suite 20261025 1))
      (save "sequence.json" sequence-suite)
      (check-regexp-match #rx"2 corpus cases.*1 determinism sequences.*13 ordered sequence calls"
                          (with-output-to-string (lambda () (check-corpus mixed-corpus))))
      (define entry (car (hash-ref sequence-suite 'cases)))
      (define steps (hash-ref entry 'steps))
      (define wrong-step
        (hash-set (car steps) 'expected (not (eq? (hash-ref (car steps) 'expected) #t))))
      (save "sequence.json"
            (hash-set sequence-suite 'cases
                      (list (hash-set entry 'steps (cons wrong-step (cdr steps))))))
      (check-exn #rx"step 1: expected" (lambda () (check-corpus mixed-corpus))))
    (lambda () (delete-directory/files mixed-corpus)))
  (define combined-output (make-temporary-file "ucast-combined-~a" 'directory))
  (dynamic-wind
    void
    (lambda ()
      (define handwritten (build-path combined-output "handwritten.json"))
      (call-with-output-file handwritten
        (lambda (out)
          (write-json (hasheq 'version "1.0" 'cases
                              (list (hash-set (car cases) 'id "handwritten-preserved"))) out)))
      (define before (file->bytes handwritten))
      (define summary
        (with-output-to-string
          (lambda () (generate-all combined-output #:case-count 250 #:determinism-count 20))))
      (check-regexp-match #rx"270 corpus cases.*20 determinism sequences.*260 ordered sequence calls" summary)
      (check-equal? (length (hash-ref (call-with-input-file
                                    (build-path combined-output "generated" "coverage-based.json") read-json)
                                   'cases)) 250)
      (check-equal? (length (hash-ref (call-with-input-file
                                    (build-path combined-output "generated" "determinism.json") read-json)
                                   'cases)) 20)
      (check-equal? (file->bytes handwritten) before)
      (check-not-exn (lambda () (with-output-to-string (lambda () (check-corpus combined-output))))))
    (lambda () (delete-directory/files combined-output))))
