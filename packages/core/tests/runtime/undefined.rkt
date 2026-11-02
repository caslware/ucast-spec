#lang racket

(require redex/reduction-semantics "../../tooling/adapter.rkt")
(provide tests)

(define (tests)
  (check-eval "fixed-005"
              "null does not match an own undefined field"
              (term (field eq "a" null))
              (term (object ("a" missing)))
              #f)
  (check-eval "fixed-012"
              "undefined root does not exist"
              (term (field exists "__itself__" #t))
              (term missing)
              #f)
  (check-eval "null-undefined-eq-direct"
              "eq null for direct undefined value"
              (term (field eq "a" null))
              (term (object ("a" missing)))
              #f)
  (check-eval "null-undefined-ne-direct"
              "ne null for direct undefined value"
              (term (field ne "a" null))
              (term (object ("a" missing)))
              #t)
  (check-eval "null-undefined-eq-nested"
              "eq null for nested undefined value"
              (term (field eq "items.a" null))
              (term (object ("items" (object ("a" missing)))))
              #f)
  (check-eval "null-undefined-ne-nested"
              "ne null for nested undefined value"
              (term (field ne "items.a" null))
              (term (object ("items" (object ("a" missing)))))
              #t)
  (check-eval "null-undefined-eq-projected"
              "eq null for projected undefined value"
              (term (field eq "items.a" null))
              (term (object ("items" (array (object ("a" missing))))))
              #f)
  (check-eval "null-undefined-ne-projected"
              "ne null for projected undefined value"
              (term (field ne "items.a" null))
              (term (object ("items" (array (object ("a" missing))))))
              #t)
  (check-eval "null-undefined-eq-array-element"
              "eq null for array-element undefined value"
              (term (field eq "a" null))
              (term (object ("a" (array missing))))
              #f)
  (check-eval "null-undefined-ne-array-element"
              "ne null for array-element undefined value"
              (term (field ne "a" null))
              (term (object ("a" (array missing))))
              #t))
