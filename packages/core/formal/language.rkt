#lang racket

(require redex/reduction-semantics)
(provide Core UCast)

;; The core syntax has no built-in operator meanings. Values and operator names
;; are extension points. CompoundCondition is also a DocumentCondition in TS.
(define-language Core
  [payload ::= any]
  [operator-name ::= string]
  [ast ::= (document operator-name payload)
           (compound operator-name (ast ...))
           (field operator-name string payload)])

;; Core is an open AST algebra. This language instantiates its operator signature
;; with the pure, JSON-oriented fragment of @ucast/js (see README.md).
(define-language UCast
  [val ::= missing null boolean integer string
        (array val ...)
        (object (string val) ...)]
  [op ::= eq ne lt lte gt gte exists mod size within in nin all]
  [pattern ::= string]
  [condition ::= (and condition ...)
                 (or condition ...)
                 (nor condition ...)
                 (not condition)
                 (field op string val)
                 (field regex string (regexp pattern))
                 (elemMatch string condition)]
  [result ::= #t #f error])
