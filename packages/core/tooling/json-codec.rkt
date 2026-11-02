#lang racket

(provide value->json json->value condition->json json->condition)

(define (value->json v)
  (match v
    ['missing (hasheq '$ucast "undefined")]
    [`(array ,xs ...) (map value->json xs)]
    [`(object ,pairs ...) (for/hasheq ([p pairs])
                           (values (string->symbol (car p)) (value->json (cadr p))))]
    [_ v]))
(define (json->value v)
  (cond [(hash? v)
         (if (equal? v (hasheq '$ucast "undefined")) 'missing
             `(object ,@(for/list ([(k x) (in-hash v)]) (list (symbol->string k) (json->value x)))))]
        [(list? v) `(array ,@(map json->value v))]
        [else v]))
(define (condition->json c)
  (match c
    [`(field regex ,path (regexp ,pattern))
     (hasheq 'type "field" 'operator "regex" 'field path 'value (hasheq 'pattern pattern))]
    [`(field ,op ,path ,v)
     (hasheq 'type "field" 'operator (symbol->string op) 'field path 'value (value->json v))]
    [`(elemMatch ,path ,child)
     (hasheq 'type "field" 'operator "elemMatch" 'field path 'value (condition->json child))]
    [`(,op ,children ...)
     (hasheq 'type "compound" 'operator (symbol->string op) 'value (map condition->json children))]))
(define (json->condition c)
  (define op (string->symbol (hash-ref c 'operator)))
  (define v (hash-ref c 'value))
  (if (equal? (hash-ref c 'type) "compound")
      `(,op ,@(map json->condition v))
      (case op
        [(elemMatch) `(elemMatch ,(hash-ref c 'field) ,(json->condition v))]
        [(regex) `(field regex ,(hash-ref c 'field) (regexp ,(hash-ref v 'pattern)))]
        [else `(field ,op ,(hash-ref c 'field) ,(json->value v))])))
