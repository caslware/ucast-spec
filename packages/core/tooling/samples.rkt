#lang racket
(require redex/reduction-semantics "../formal/language.rkt" "../formal/semantics.rkt")

;; Typed payloads ensure generated conditions are well formed. The profile uses
;; ASCII names/strings and small integers, avoiding JS number/Unicode ambiguities.
(provide Sample unique-keys logical-variants generate-determinism-inputs)
(define-extended-language Sample UCast
  [s ::= "" "a" "b" "0" "1" "-1" "x"]
  [key ::= "a" "b" "items"]
  [path ::= "a" "b" "items" "a.b" "items.a" "items.a.b" "items.0" "items.0.a" "length" "__itself__"]
  [n ::= -2 -1 0 1 2]
  [pattern ::= "" "a" "^a" "a$" "^a$" "[ab]+" "a|b"]
  [val ::= missing null boolean n s (array val ...) (object (key val) ...)]
  [scalar ::= missing null boolean n s]
  [condition ::= (and condition ...) (or condition ...) (nor condition ...) (not condition)
         (field eq path scalar) (field ne path scalar)
         (field lt path scalar) (field lte path scalar)
         (field gt path scalar) (field gte path scalar)
         (field exists path boolean) (field size path n)
         (field mod path (array n n))
         (field within path (array scalar ...)) (field in path (array scalar ...))
         (field nin path (array scalar ...)) (field all path (array scalar ...))
         (field regex path (regexp pattern))
         (elemMatch path condition)])

(define (unique-keys v)
  (match v
    [`(object ,pairs ...)
     `(object ,@(remove-duplicates
                 (map (lambda (p) (list (car p) (unique-keys (cadr p)))) pairs)
                 #:key car))]
    [`(array ,xs ...) `(array ,@(map unique-keys xs))]
    [_ v]))

(define (generate-determinism-inputs seed count)
  (define sample (generate-term Sample (condition_1 val_1 condition_2 val_2)))
  (parameterize ([redex-pseudo-random-generator (make-pseudo-random-generator)])
    (parameterize ([current-pseudo-random-generator (redex-pseudo-random-generator)])
      (random-seed seed))
    (for/list ([i (in-range count)])
      (match-define (list c doc other other-doc) (sample (+ 1 (modulo i 6))))
      (list c (unique-keys doc) other (unique-keys other-doc)))))

;; An independent outcome algebra supplies expectations for generated logical
;; families. Evaluate the operands once; do not derive these expectations by
;; running the compound expression being checked.
(define (logical-variants a b doc)
  (define ra (evaluate a doc))
  (define rb (evaluate b doc))
  (unless (and (member ra '(#t #f error)) (member rb '(#t #f error)))
    (error 'logical-variants "condition result is not Boolean/error: ~s ~s" ra rb))
  (define (negate-result r) (if (eq? r 'error) 'error (not r)))
  (define conjunction (case ra [(#f) #f] [(error) 'error] [else rb]))
  (define disjunction (case ra [(#t) #t] [(error) 'error] [else rb]))
  (list (list "Boolean conjunction, short circuiting, and error propagation" `(and ,a ,b) conjunction)
        (list "Boolean disjunction, short circuiting, and error propagation" `(or ,a ,b) disjunction)
        (list "nor preserves errors" `(nor ,a ,b) (negate-result disjunction))
        (list "not preserves errors" `(not ,a) (negate-result ra))
        (list "double negation and Boolean/error closure" `(not (not ,a)) ra)
        (list "De Morgan not-and left" `(not (and ,a ,b)) (negate-result conjunction))
        (list "De Morgan not-and right" `(or (not ,a) (not ,b)) (negate-result conjunction))
        (list "De Morgan not-or left" `(not (or ,a ,b)) (negate-result disjunction))
        (list "De Morgan not-or right" `(and (not ,a) (not ,b)) (negate-result disjunction))))

(module+ test
  (require rackunit)
  ;; Explicit true/false/error outcomes validate the generator's expectation
  ;; algebra independently. Evaluator examples live in tests/core/logical.rkt.
  (define witnesses (hash #t '(and) #f '(or) 'error '(field within "a" (array 1))))
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
    (define variants (logical-variants (hash-ref witnesses ra) (hash-ref witnesses rb) 'null))
    (check-equal? (map caddr variants)
                  (list conjunction disjunction not-or not-a ra not-and not-and not-or not-or)
                  (format "logical expectations for ~s then ~s" ra rb))))
