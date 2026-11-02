#lang racket

(require rackunit "../trace.rkt")

(module+ test
  ;; A small fake evaluator keeps tooling tests independent of any formal model.
  (define (evaluate condition subject)
    (if (equal? condition "error") 'error (equal? condition subject)))
  (define (trace tests) (call-with-evaluation-trace tests #:evaluate evaluate))
  (define suite
    (trace
     (lambda ()
       (check-eval "equal" "equal values" 1 1 #t)
       (check-eval "unequal" "different values" 1 2 #f)
       (check-eval "error" "modeled error" "error" 1 'error))))
  (check-equal? (map (lambda (entry) (hash-ref entry 'expected)) (hash-ref suite 'cases))
                '(#t #f "error"))
  (define encoded
    (call-with-evaluation-trace
     (lambda () (check-eval "encoded" "adapter encoding" 1 1 #t))
     #:evaluate evaluate
     #:condition->json (lambda (value) (hasheq 'condition value))
     #:subject->json (lambda (value) (hasheq 'subject value))))
  (check-equal? (hash-ref (car (hash-ref encoded 'cases)) 'ast) (hasheq 'condition 1))
  (check-equal? (hash-ref (car (hash-ref encoded 'cases)) 'subject) (hasheq 'subject 1))
  (check-exn exn:fail?
             (lambda ()
               (trace (lambda () (check-eval "wrong" "wrong expectation" 1 1 #f)))))
  (check-exn #rx"duplicate case id"
             (lambda ()
               (trace (lambda ()
                        (check-eval "same" "first" 1 1 #t)
                        (check-eval "same" "second" 1 2 #f)))))
  (check-exn #rx"no evaluator calls recorded" (lambda () (trace void))))
