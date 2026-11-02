#lang racket

(require redex/reduction-semantics "../../tooling/adapter.rkt")
(provide tests)

;; Author tests in Redex terms with explicit expected outcomes. The same calls
;; run as assertions and, when tracing is enabled, become conformance JSON.
(define (tests)
  (check-eval "fixed-004"
              "null matches an absent field"
              (term (field eq "a" null))
              (term (object))
              #t)
  (check-eval "fixed-006"
              "null matches an array containing null"
              (term (field eq "a" null))
              (term (object ("a" (array null))))
              #t)
  (check-eval "fixed-007"
              "Boolean true differs from number one"
              (term (field eq "a" #t))
              (term (object ("a" 1)))
              #f)
  (check-eval "fixed-008"
              "number zero differs from Boolean false"
              (term (field eq "a" 0))
              (term (object ("a" #f)))
              #f)
  (check-eval "fixed-009"
              "string zero differs from number zero"
              (term (field eq "a" "0"))
              (term (object ("a" 0)))
              #f)
  (check-eval "fixed-010"
              "null on ITSELF rejects an object"
              (term (field eq "__itself__" null))
              (term (object))
              #f)
  (check-eval "fixed-014"
              "projection concatenates nested arrays one level"
              (term (field eq "items.a" 2))
              (term (object ("items" (array (object ("a" (array 1 2))) (object)))))
              #t)
  (check-eval "fixed-015"
              "numeric index selects an array element"
              (term (field eq "items.0.a" 1))
              (term (object ("items" (array (object ("a" 1))))))
              #t)
  (check-eval "eq-001"
              "age eq 18 with age 18"
              (term (field eq "age" 18))
              (term (object ("age" 18)))
              #t)
  (check-eval "eq-002"
              "age eq 18 with age 19"
              (term (field eq "age" 18))
              (term (object ("age" 19)))
              #f)
  (check-eval "ne-003"
              "age ne 18 with age 19"
              (term (field ne "age" 18))
              (term (object ("age" 19)))
              #t)
  (check-eval "ne-004"
              "age ne 18 with age 18"
              (term (field ne "age" 18))
              (term (object ("age" 18)))
              #f)
  (check-eval "itself-eq-null"
              "eq null on ITSELF matches a null root"
              (term (field eq "__itself__" null))
              (term null)
              #t)
  (check-eval "itself-ne-null"
              "ne negates null equality on ITSELF for null"
              (term (field ne "__itself__" null))
              (term null)
              #f)
  (check-eval "itself-eq-undefined"
              "eq null on ITSELF rejects an undefined root"
              (term (field eq "__itself__" null))
              (term missing)
              #f)
  (check-eval "itself-ne-undefined"
              "ne negates null equality on ITSELF for undefined"
              (term (field ne "__itself__" null))
              (term missing)
              #t)
  (check-eval "itself-eq-scalar"
              "eq null on ITSELF rejects a string root"
              (term (field eq "__itself__" null))
              (term "test")
              #f)
  (check-eval "itself-ne-scalar"
              "ne negates null equality on ITSELF for scalar"
              (term (field ne "__itself__" null))
              (term "test")
              #t)
  (check-eval "itself-eq-array"
              "eq null on ITSELF matches a direct null array element"
              (term (field eq "__itself__" null))
              (term (array null))
              #t)
  (check-eval "itself-ne-array"
              "ne negates null equality on ITSELF for array"
              (term (field ne "__itself__" null))
              (term (array null))
              #f)
  (check-eval "itself-eq-nested-array"
              "eq null on ITSELF rejects a nested null array element"
              (term (field eq "__itself__" null))
              (term (array (array null)))
              #f)
  (check-eval "itself-ne-nested-array"
              "ne negates null equality on ITSELF for nested-array"
              (term (field ne "__itself__" null))
              (term (array (array null)))
              #t)
  (check-eval "itself-eq-object-array"
              "eq null on ITSELF rejects an object array element"
              (term (field eq "__itself__" null))
              (term (array (object)))
              #f)
  (check-eval "itself-ne-object-array"
              "ne negates null equality on ITSELF for object-array"
              (term (field ne "__itself__" null))
              (term (array (object)))
              #t)
  (check-eval "itself-eq-own-key"
              "eq null on ITSELF compares the root rather than an own ITSELF property"
              (term (field eq "__itself__" null))
              (term (object ("__itself__" null)))
              #f)
  (check-eval "itself-ne-own-key"
              "ne negates null equality on ITSELF for own-key"
              (term (field ne "__itself__" null))
              (term (object ("__itself__" null)))
              #t)
  (for ([entry '((false #f) (zero 0) (empty-string ""))])
    (define name (car entry))
    (define doc (cadr entry))
    (check-eval (format "itself-eq-null-~a" name)
                (format "null equality rejects the ~a root" name)
                '(field eq "__itself__" null) doc #f)
    (check-eval (format "itself-ne-null-~a" name)
                (format "null inequality accepts the ~a root" name)
                '(field ne "__itself__" null) doc #t))
  (check-eval "itself-eq-null-mixed-array"
              "null equality finds null after a nonmatching array element"
              '(field eq "__itself__" null) '(array 0 null) #t)
  (check-eval "itself-ne-null-mixed-array"
              "null inequality rejects an array with a direct null element"
              '(field ne "__itself__" null) '(array 0 null) #f)
  (check-eval "itself-eq-number-array"
              "numeric equality matches a direct root array element"
              '(field eq "__itself__" 1) '(array 1) #t)
  (check-eval "itself-eq-number-nested-array"
              "numeric equality does not recursively flatten root arrays"
              '(field eq "__itself__" 1) '(array (array 1)) #f))
