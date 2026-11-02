#lang racket

(require redex/reduction-semantics "../../tooling/adapter.rkt")
(provide tests)

(define (tests)
  (check-eval "fixed-001"
              "empty conjunction is true"
              (term (and))
              (term (object))
              #t)
  (check-eval "fixed-002"
              "empty disjunction is false"
              (term (or))
              (term (object))
              #f)
  (check-eval "fixed-003"
              "empty nor is true"
              (term (nor))
              (term (object))
              #t)
  (check-eval "fixed-030"
              "false and child skips a later error"
              (term (and (or) (field within "a" (array 1))))
              (term null)
              #f)
  (check-eval "fixed-031"
              "true or child skips a later error"
              (term (or (and) (field within "a" (array 1))))
              (term null)
              #t)
  ;; Independent truth/error rows pin ordered evaluation and both De Morgan
  ;; rewrites. Keep these evaluator examples portable through the fixed runner.
  (define witnesses (hash #t '(and) #f '(or) 'error '(field within "a" (array 1))))
  (define (outcome-name r) (case r [(#t) "true"] [(#f) "false"] [else "error"]))
  (for ([row '((#t #t #t #t #f #f #f)
               (#t #f #f #t #t #f #f)
               (#t error error #t error #f #f)
               (#f #t #f #t #t #f #t)
               (#f #f #f #f #t #t #t)
               (#f error #f error #t error #t)
               (error #t error error error error error)
               (error #f error error error error error)
               (error error error error error error error))])
    (match-define (list ra rb conjunction disjunction not-and not-or not-a) row)
    (define a (hash-ref witnesses ra))
    (define b (hash-ref witnesses rb))
    (define pair-name (format "~a-~a" (outcome-name ra) (outcome-name rb)))
    (for ([entry (list (list 'and `(and ,a ,b) conjunction)
                       (list 'or `(or ,a ,b) disjunction)
                       (list 'nor `(nor ,a ,b) not-or)
                       (list 'de-morgan-and-left `(not (and ,a ,b)) not-and)
                       (list 'de-morgan-and-right `(or (not ,a) (not ,b)) not-and)
                       (list 'de-morgan-or-left `(not (or ,a ,b)) not-or)
                       (list 'de-morgan-or-right `(and (not ,a) (not ,b)) not-or))]
          ;; Existing fixtures already pin these exact condition/subject pairs.
          #:unless (member (list (car entry) ra rb)
                           '((and #f error) (or #t error) (and error #f))))
      (match-define (list name condition expected) entry)
      (check-eval (format "logic-~a-~a" name pair-name)
                  (format "~a with ordered ~a operands" name pair-name)
                  condition 'null expected))
    ;; Unary outcomes do not depend on the second operand.
    (when (eq? rb #t)
      (check-eval (format "logic-not-~a" (outcome-name ra))
                  (format "negation of the ~a outcome" (outcome-name ra))
                  `(not ,a) 'null not-a)
      (check-eval (format "logic-double-not-~a" (outcome-name ra))
                  (format "double negation preserves the ~a outcome" (outcome-name ra))
                  `(not (not ,a)) 'null ra))))
