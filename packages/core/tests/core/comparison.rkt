#lang racket

(require redex/reduction-semantics "../../tooling/adapter.rkt")
(provide tests)

(define (tests)
  (check-eval "fixed-016"
              "missing field does not match a numeric comparison"
              (term (field lt "a" 0))
              (term (object))
              #f)
  (check-eval "fixed-017"
              "string zero does not match a numeric lte comparison"
              (term (field lte "a" 0))
              (term (object ("a" "0")))
              #f)
  (check-eval "fixed-018"
              "string zero does not compare greater than or equal to number zero"
              (term (field gte "a" 0))
              (term (object ("a" "0")))
              #f)
  (check-eval "fixed-019"
              "strings compare lexicographically"
              (term (field gt "a" "1"))
              (term (object ("a" "2")))
              #t)
  (check-eval "lt-005"
              "age lt 18 with age 17"
              (term (field lt "age" 18))
              (term (object ("age" 17)))
              #t)
  (check-eval "lte-006"
              "age lte 18 with age 18"
              (term (field lte "age" 18))
              (term (object ("age" 18)))
              #t)
  (check-eval "gt-007"
              "age gt 18 with age 19"
              (term (field gt "age" 18))
              (term (object ("age" 19)))
              #t)
  (check-eval "gte-008"
              "age gte 18 with age 18"
              (term (field gte "age" 18))
              (term (object ("age" 18)))
              #t)
  (check-eval "bracket-lt-missing"
              "lt type bracketing: missing"
              (term (field lt "a" 0))
              (term (object))
              #f)
  (check-eval "bracket-lt-undefined"
              "lt type bracketing: undefined"
              (term (field lt "a" 0))
              (term (object ("a" missing)))
              #f)
  (check-eval "bracket-lt-null"
              "lt type bracketing: null"
              (term (field lt "a" 0))
              (term (object ("a" null)))
              #f)
  (check-eval "bracket-lt-boolean"
              "lt type bracketing: boolean"
              (term (field lt "a" 0))
              (term (object ("a" #f)))
              #f)
  (check-eval "bracket-lt-string"
              "lt type bracketing: string"
              (term (field lt "a" 0))
              (term (object ("a" "0")))
              #f)
  (check-eval "bracket-lt-number-to-string"
              "lt type bracketing: number-to-string"
              (term (field lt "a" "0"))
              (term (object ("a" 0)))
              #f)
  (check-eval "bracket-lt-object"
              "lt type bracketing: object"
              (term (field lt "a" 0))
              (term (object ("a" (object))))
              #f)
  (check-eval "bracket-lt-nested-array"
              "lt type bracketing: nested-array"
              (term (field lt "a" 0))
              (term (object ("a" (array (array -1)))))
              #f)
  (check-eval "bracket-lt-mixed-no-match"
              "lt type bracketing: mixed-no-match"
              (term (field lt "a" 0))
              (term (object ("a" (array null #f "0"))))
              #f)
  (check-eval "bracket-lt-mixed-match"
              "lt type bracketing: mixed-match"
              (term (field lt "a" 0))
              (term (object ("a" (array null "0" -1))))
              #t)
  (check-eval "bracket-lt-equality"
              "lt type bracketing: equality"
              (term (field lt "a" 0))
              (term (object ("a" 0)))
              #f)
  (check-eval "bracket-lte-missing"
              "lte type bracketing: missing"
              (term (field lte "a" 0))
              (term (object))
              #f)
  (check-eval "bracket-lte-undefined"
              "lte type bracketing: undefined"
              (term (field lte "a" 0))
              (term (object ("a" missing)))
              #f)
  (check-eval "bracket-lte-null"
              "lte type bracketing: null"
              (term (field lte "a" 0))
              (term (object ("a" null)))
              #f)
  (check-eval "bracket-lte-boolean"
              "lte type bracketing: boolean"
              (term (field lte "a" 0))
              (term (object ("a" #f)))
              #f)
  (check-eval "bracket-lte-string"
              "lte type bracketing: string"
              (term (field lte "a" 0))
              (term (object ("a" "0")))
              #f)
  (check-eval "bracket-lte-number-to-string"
              "lte type bracketing: number-to-string"
              (term (field lte "a" "0"))
              (term (object ("a" 0)))
              #f)
  (check-eval "bracket-lte-object"
              "lte type bracketing: object"
              (term (field lte "a" 0))
              (term (object ("a" (object))))
              #f)
  (check-eval "bracket-lte-nested-array"
              "lte type bracketing: nested-array"
              (term (field lte "a" 0))
              (term (object ("a" (array (array -1)))))
              #f)
  (check-eval "bracket-lte-mixed-no-match"
              "lte type bracketing: mixed-no-match"
              (term (field lte "a" 0))
              (term (object ("a" (array null #f "0"))))
              #f)
  (check-eval "bracket-lte-mixed-match"
              "lte type bracketing: mixed-match"
              (term (field lte "a" 0))
              (term (object ("a" (array null "0" -1))))
              #t)
  (check-eval "bracket-lte-equality"
              "lte type bracketing: equality"
              (term (field lte "a" 0))
              (term (object ("a" 0)))
              #t)
  (check-eval "bracket-gt-missing"
              "gt type bracketing: missing"
              (term (field gt "a" 0))
              (term (object))
              #f)
  (check-eval "bracket-gt-undefined"
              "gt type bracketing: undefined"
              (term (field gt "a" 0))
              (term (object ("a" missing)))
              #f)
  (check-eval "bracket-gt-null"
              "gt type bracketing: null"
              (term (field gt "a" 0))
              (term (object ("a" null)))
              #f)
  (check-eval "bracket-gt-boolean"
              "gt type bracketing: boolean"
              (term (field gt "a" 0))
              (term (object ("a" #f)))
              #f)
  (check-eval "bracket-gt-string"
              "gt type bracketing: string"
              (term (field gt "a" 0))
              (term (object ("a" "0")))
              #f)
  (check-eval "bracket-gt-number-to-string"
              "gt type bracketing: number-to-string"
              (term (field gt "a" "0"))
              (term (object ("a" 0)))
              #f)
  (check-eval "bracket-gt-object"
              "gt type bracketing: object"
              (term (field gt "a" 0))
              (term (object ("a" (object))))
              #f)
  (check-eval "bracket-gt-nested-array"
              "gt type bracketing: nested-array"
              (term (field gt "a" 0))
              (term (object ("a" (array (array 1)))))
              #f)
  (check-eval "bracket-gt-mixed-no-match"
              "gt type bracketing: mixed-no-match"
              (term (field gt "a" 0))
              (term (object ("a" (array null #f "0"))))
              #f)
  (check-eval "bracket-gt-mixed-match"
              "gt type bracketing: mixed-match"
              (term (field gt "a" 0))
              (term (object ("a" (array null "0" 1))))
              #t)
  (check-eval "bracket-gt-equality"
              "gt type bracketing: equality"
              (term (field gt "a" 0))
              (term (object ("a" 0)))
              #f)
  (check-eval "bracket-gte-missing"
              "gte type bracketing: missing"
              (term (field gte "a" 0))
              (term (object))
              #f)
  (check-eval "bracket-gte-undefined"
              "gte type bracketing: undefined"
              (term (field gte "a" 0))
              (term (object ("a" missing)))
              #f)
  (check-eval "bracket-gte-null"
              "gte type bracketing: null"
              (term (field gte "a" 0))
              (term (object ("a" null)))
              #f)
  (check-eval "bracket-gte-boolean"
              "gte type bracketing: boolean"
              (term (field gte "a" 0))
              (term (object ("a" #f)))
              #f)
  (check-eval "bracket-gte-string"
              "gte type bracketing: string"
              (term (field gte "a" 0))
              (term (object ("a" "0")))
              #f)
  (check-eval "bracket-gte-number-to-string"
              "gte type bracketing: number-to-string"
              (term (field gte "a" "0"))
              (term (object ("a" 0)))
              #f)
  (check-eval "bracket-gte-object"
              "gte type bracketing: object"
              (term (field gte "a" 0))
              (term (object ("a" (object))))
              #f)
  (check-eval "bracket-gte-nested-array"
              "gte type bracketing: nested-array"
              (term (field gte "a" 0))
              (term (object ("a" (array (array 1)))))
              #f)
  (check-eval "bracket-gte-mixed-no-match"
              "gte type bracketing: mixed-no-match"
              (term (field gte "a" 0))
              (term (object ("a" (array null #f "0"))))
              #f)
  (check-eval "bracket-gte-mixed-match"
              "gte type bracketing: mixed-match"
              (term (field gte "a" 0))
              (term (object ("a" (array null "0" 1))))
              #t)
  (check-eval "bracket-gte-equality"
              "gte type bracketing: equality"
              (term (field gte "a" 0))
              (term (object ("a" 0)))
              #t)
  (for ([op '(lt lte gt gte)])
    (check-eval (format "bracket-~a-mixed-nested-no-match" op)
                (format "~a ignores null, Boolean, string, and nested-array values in a mixed array" op)
                `(field ,op "a" 0)
                '(object ("a" (array null #f "0" (array 0)))) #f)))
