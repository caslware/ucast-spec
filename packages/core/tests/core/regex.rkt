#lang racket

(require redex/reduction-semantics "../../tooling/adapter.rkt")
(provide tests)

(define (tests)
  (check-eval "regex-search"
              "search"
              (term (field regex "name" (regexp "cast")))
              (term (object ("name" "ucast")))
              #t)
  (check-eval "regex-no-match"
              "no match"
              (term (field regex "name" (regexp "^a")))
              (term (object ("name" "beta")))
              #f)
  (check-eval "regex-prefix"
              "prefix"
              (term (field regex "name" (regexp "^ucast")))
              (term (object ("name" "ucast-js")))
              #t)
  (check-eval "regex-suffix"
              "suffix"
              (term (field regex "name" (regexp "cast$")))
              (term (object ("name" "ucast")))
              #t)
  (check-eval "regex-alternation"
              "alternation"
              (term (field regex "name" (regexp "^(cat|dog)$")))
              (term (object ("name" "dog")))
              #t)
  (check-eval "regex-repetition"
              "repetition"
              (term (field regex "name" (regexp "^[ab]+$")))
              (term (object ("name" "abba")))
              #t)
  (check-eval "regex-nonstring"
              "nonstring"
              (term (field regex "name" (regexp "a")))
              (term (object ("name" 12)))
              #f)
  (check-eval "regex-null"
              "null"
              (term (field regex "name" (regexp "a")))
              (term (object ("name" null)))
              #f)
  (check-eval "regex-missing"
              "missing"
              (term (field regex "name" (regexp "a")))
              (term (object))
              #f)
  (check-eval "regex-empty-pattern"
              "empty pattern"
              (term (field regex "name" (regexp "")))
              (term (object ("name" "")))
              #t)
  (check-eval "regex-array"
              "array"
              (term (field regex "name" (regexp "^a")))
              (term (object ("name" (array null 3 "beta" "alpha"))))
              #t)
  (check-eval "regex-no-coercion"
              "no coercion"
              (term (field regex "name" (regexp "12")))
              (term (object ("name" (array 12 #t null))))
              #f)
  (check-eval "regex-no-recursive-flatten"
              "no recursive flatten"
              (term (field regex "name" (regexp "a")))
              (term (object ("name" (array (array "a")))))
              #f)
  (check-eval "regex-projection"
              "projection"
              (term (field regex "items.name" (regexp "^a")))
              (term (object ("items" (array (object ("name" "beta")) (object ("name" "alpha"))))))
              #t)
  (check-eval "regex-root"
              "root"
              (term (field regex "__itself__" (regexp "^a")))
              (term "alpha")
              #t)
  (check-eval "regex-falsy-root-error"
              "falsy root error"
              (term (field regex "name" (regexp "a")))
              (term null)
              'error)
  (check-eval "regex-nested"
              "nested"
              (term (elemMatch "items" (field regex "__itself__" (regexp "^a"))))
              (term (object ("items" (array "beta" "alpha"))))
              #t)
  (check-eval "regex-negation"
              "negation"
              (term (not (field regex "name" (regexp "^a"))))
              (term (object ("name" "beta")))
              #t)
  (check-eval "regex-numeric-root"
              "regex does not coerce a numeric root to a string"
              '(field regex "__itself__" (regexp "12")) 12 #f))
