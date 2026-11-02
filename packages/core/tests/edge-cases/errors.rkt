#lang racket

(require redex/reduction-semantics "../../tooling/adapter.rkt")
(provide tests)

(define (tests)
  (check-eval "fixed-032"
              "an evaluated lookup error propagates through and"
              (term (and (field within "a" (array 1)) (or)))
              (term null)
              'error)
  (check-eval "logic-error-witness"
              "the child skipped by the logical short-circuit fixtures errors when evaluated alone"
              (term (field within "a" (array 1)))
              (term null)
              'error))
