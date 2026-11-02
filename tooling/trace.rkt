#lang racket

(require rackunit)
(provide check-eval call-with-evaluation-trace)

(define current-recorder (make-parameter #f))
(define current-evaluator (make-parameter #f))

;; This is the observable evaluator boundary. The authored expected outcome is
;; asserted before an observed call can enter the exported conformance suite.
(define (check-eval id description condition subject expected)
  (define evaluate (current-evaluator))
  (unless evaluate (error 'trace "run fixed tests through the configured runner"))
  (define actual (evaluate condition subject))
  ;; RackUnit normally reports a failure and continues. Export must abort on a
  ;; failed assertion, so a model regression cannot become a new golden answer.
  (parameterize ([current-check-handler raise])
    (check-equal? actual expected (format "~a: ~a" id description)))
  (define record (current-recorder))
  (when record
    (record id description condition subject actual)))

(define (call-with-evaluation-trace tests #:evaluate evaluate
                                    #:condition->json [condition->json values]
                                    #:subject->json [subject->json values])
  (define cases '())
  (define ids (make-hash))
  (parameterize ([current-evaluator evaluate]
                 [current-recorder
                  (lambda (id description condition subject actual)
                    (when (hash-has-key? ids id)
                      (error 'trace "duplicate case id: ~a" id))
                    (hash-set! ids id #t)
                    (set! cases
                          (cons (hasheq 'id id 'description description
                                        'ast (condition->json condition)
                                        'subject (subject->json subject)
                                        'expected (if (eq? actual 'error) "error" actual)) cases)))])
    (tests))
  (when (null? cases) (error 'trace "no evaluator calls recorded"))
  (hasheq 'version "1.0" 'cases (reverse cases)))
