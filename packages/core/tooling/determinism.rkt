#lang racket

(require redex/reduction-semantics "../formal/semantics.rkt")
(provide determinism-schedule run-determinism-schedule deterministic-evaluation?)

;; Shared by determinism checks and the portable JSON exporter.
;; Each call selects one of two conditions and one of two subjects. Keep those
;; inputs alive throughout a sequence so caches see repeated inputs.
(define determinism-schedule
  (cons '(#f primary primary)
        (append-map
         (lambda (cache?)
           (for/list ([pair '((primary primary) (primary primary)
                             (interference interference) (primary interference)
                             (interference primary) (primary primary))])
             (cons cache? pair)))
         '(#t #f))))

(define (run-determinism-schedule eval conditions subjects check-result)
  ;; Look up existing inputs rather than rebuilding them: identity-based caches
  ;; must see the same objects throughout the sequence. Stop at the first failure.
  (for/and ([call determinism-schedule])
    (match-define (list cache? cid sid) call)
    (define actual
      (parameterize ([caching-enabled? cache?])
        (eval (hash-ref conditions cid) (hash-ref subjects sid))))
    (check-result call actual)))

(define (deterministic-evaluation? eval c doc other other-doc)
  (define expected 'unset)
  (run-determinism-schedule
   eval (hasheq 'primary c 'interference other)
   (hasheq 'primary doc 'interference other-doc)
   (lambda (call actual)
     (match-define (list _cache? cid sid) call)
     (cond
       ;; The first scheduled call is the uncached primary baseline.
       [(eq? expected 'unset)
        (set! expected actual)
        (and (member expected '(#t #f error)) #t)]
       [else
        (or (not (and (eq? cid 'primary) (eq? sid 'primary)))
            (equal? actual expected))]))))

(module+ test
  (require rackunit)
  ;; All three outcomes must survive the same protocol, including an error that
  ;; would be lost by an adapter that incorrectly normalizes errors to false.
  (for ([c '((and) (or) (field within "a" (array 1)))])
    (check-true (deterministic-evaluation? evaluate c 'null
                                         '(field regex "__itself__" (regexp "a")) "a")))
  (define calls 0)
  (check-false
   (deterministic-evaluation?
    (lambda (_c _doc) (set! calls (add1 calls)) (odd? calls))
    '(and) 'null '(or) "a")
   "reject a changing result")
  (define disturbed? #f)
  (check-false
   (deterministic-evaluation?
    (lambda (c _doc)
      (if (equal? c '(or)) (begin (set! disturbed? #t) #f) (not disturbed?)))
    '(and) 'null '(or) "a")
   "reject interference from unrelated calls")
  (check-false
   (deterministic-evaluation? (lambda (_c _doc) (caching-enabled?))
                              '(and) 'null '(or) "a")
   "reject cache-dependent results")
)
