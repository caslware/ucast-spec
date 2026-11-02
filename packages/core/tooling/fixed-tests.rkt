#lang racket

(require racket/runtime-path "../../../tooling/run-fixed-tests.rkt")
(define-runtime-path package "..")

(module+ test
  (run-fixed-tests 'check package))
