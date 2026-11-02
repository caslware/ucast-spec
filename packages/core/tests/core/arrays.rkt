#lang racket

(require redex/reduction-semantics "../../tooling/adapter.rkt")
(provide tests)

(define (tests)
  (check-eval "fixed-011"
              "exists false on ITSELF rejects a defined root"
              (term (field exists "__itself__" #f))
              (term (object))
              #f)
  (check-eval "fixed-013"
              "projected exists false rejects an array with any present field"
              (term (field exists "items.a" #f))
              (term (object ("items" (array (object ("a" 1)) (object)))))
              #f)
  (check-eval "fixed-020"
              "negative modulo keeps the dividend sign"
              (term (field mod "a" (array 2 -1)))
              (term (object ("a" -3)))
              #t)
  (check-eval "fixed-021"
              "zero modulo divisor returns false"
              (term (field mod "a" (array 0 0)))
              (term (object ("a" 1)))
              #f)
  (check-eval "fixed-022"
              "size tests arrays on projected parents"
              (term (field size "items.a" 2))
              (term (object ("items" (array (object ("a" (array 1 2)))))))
              #t)
  (check-eval "fixed-023"
              "Boolean true does not equal an array length of one"
              (term (field size "a" #t))
              (term (object ("a" (array 0))))
              #f)
  (check-eval "fixed-024"
              "within accepts any matching array element"
              (term (field within "a" (array 1 2)))
              (term (object ("a" (array 0 2))))
              #t)
  (check-eval "fixed-025"
              "in accepts scalar membership"
              (term (field in "a" (array 1)))
              (term (object ("a" 1)))
              #t)
  (check-eval "fixed-026"
              "nin accepts an array without the operand"
              (term (field nin "a" (array 1)))
              (term (object ("a" (array 2))))
              #t)
  (check-eval "fixed-027"
              "all with an empty operand accepts an empty array"
              (term (field all "a" (array)))
              (term (object ("a" (array))))
              #t)
  (check-eval "fixed-028"
              "all ignores element order"
              (term (field all "a" (array 1 2)))
              (term (object ("a" (array 2 1))))
              #t)
  (check-eval "fixed-029"
              "elemMatch evaluates against individual elements"
              (term (elemMatch "a" (field eq "__itself__" 1)))
              (term (object ("a" (array 0 1))))
              #t)
  (check-eval "itself-exists-true-undefined"
              "exists true on ITSELF with undefined root"
              (term (field exists "__itself__" #t))
              (term missing)
              #f)
  (check-eval "itself-exists-false-undefined"
              "exists false on ITSELF with undefined root"
              (term (field exists "__itself__" #f))
              (term missing)
              #t)
  (check-eval "itself-exists-true-null"
              "exists true on ITSELF with null root"
              (term (field exists "__itself__" #t))
              (term null)
              #t)
  (check-eval "itself-exists-false-null"
              "exists false on ITSELF with null root"
              (term (field exists "__itself__" #f))
              (term null)
              #f)
  (check-eval "itself-exists-true-false"
              "exists true on ITSELF with false root"
              (term (field exists "__itself__" #t))
              (term #f)
              #t)
  (check-eval "itself-exists-false-false"
              "exists false on ITSELF with false root"
              (term (field exists "__itself__" #f))
              (term #f)
              #f)
  (check-eval "itself-exists-true-zero"
              "exists true on ITSELF with zero root"
              (term (field exists "__itself__" #t))
              (term 0)
              #t)
  (check-eval "itself-exists-false-zero"
              "exists false on ITSELF with zero root"
              (term (field exists "__itself__" #f))
              (term 0)
              #f)
  (check-eval "itself-exists-true-empty-string"
              "exists true on ITSELF with empty-string root"
              (term (field exists "__itself__" #t))
              (term "")
              #t)
  (check-eval "itself-exists-false-empty-string"
              "exists false on ITSELF with empty-string root"
              (term (field exists "__itself__" #f))
              (term "")
              #f)
  (check-eval "itself-exists-true-array"
              "exists true on ITSELF with array root"
              (term (field exists "__itself__" #t))
              (term (array))
              #t)
  (check-eval "itself-exists-false-array"
              "exists false on ITSELF with array root"
              (term (field exists "__itself__" #f))
              (term (array))
              #f)
  (check-eval "projected-exists-false-empty"
              "projected exists false with empty"
              (term (field exists "items.a" #f))
              (term (object ("items" (array))))
              #t)
  (check-eval "projected-exists-false-absent"
              "projected exists false with absent"
              (term (field exists "items.a" #f))
              (term (object ("items" (array (object) (object)))))
              #t)
  (check-eval "projected-exists-false-null-value"
              "projected exists false with null-value"
              (term (field exists "items.a" #f))
              (term (object ("items" (array (object ("a" null)) (object)))))
              #f)
  (check-eval "projected-exists-false-undefined-value"
              "projected exists false with undefined-value"
              (term (field exists "items.a" #f))
              (term (object ("items" (array (object ("a" missing)) (object)))))
              #f)
  (check-eval "projected-exists-false-null-element"
              "projected exists false with null-element"
              (term (field exists "items.a" #f))
              (term (object ("items" (array null (object)))))
              #t)
  (check-eval "fixed-033"
              "projection skips null elements and finds no match"
              (term (field within "items.a" (array 1)))
              (term (object ("items" (array null))))
              #f)
  (check-eval "projection-nullish-match"
              "equality skips null and undefined array elements: match"
              (term (field eq "items.a" 2))
              (term (object ("items" (array null missing (object) (object ("a" 2))))))
              #t)
  (check-eval "projection-nullish-no-match"
              "equality skips null and undefined array elements: no-match"
              (term (field eq "items.a" 2))
              (term (object ("items" (array null missing (object) (object ("a" 1))))))
              #f)
  (check-eval "projection-nullish-only-missing"
              "equality skips null and undefined array elements: only-missing"
              (term (field eq "items.a" 2))
              (term (object ("items" (array null missing (object)))))
              #f)
  (check-eval "projection-nullish-intermediate"
              "null and undefined elements are skipped at intermediate path segments"
              (term (field eq "groups.items.a" 2))
              (term (object ("groups" (array null missing (object) (object ("items" (array null (object) (object ("a" 2)))))))))
              #t)
  (check-eval "itself-exists-true-object"
              "an object root exists"
              '(field exists "__itself__" #t) '(object) #t)
  (check-eval "itself-exists-true-undefined-element"
              "an array root exists even when its element is undefined"
              '(field exists "__itself__" #t) '(array missing) #t)
  (check-eval "itself-exists-false-undefined-element"
              "an undefined array element does not make its root absent"
              '(field exists "__itself__" #f) '(array missing) #f)
  (for ([entry '((present (array (object ("a" 1)) (object)) #t)
                (null-value (array (object) (object ("a" null))) #t)
                (empty (array) #f)
                (absent (array (object) (object)) #f))])
    (check-eval (format "projected-exists-true-~a" (car entry))
                (format "projected existence with ~a elements" (car entry))
                '(field exists "items.a" #t)
                `(object ("items" ,(cadr entry))) (caddr entry))))
