#lang racket

(require redex/reduction-semantics "language.rkt")
(provide evaluate Eval run lookup strict=? compare-values and-result or-result negate)

;; Short circuiting and errors are observable; these rules evaluate left to right.
(define-metafunction UCast
  run : condition val -> result
  [(run (and) val) #t]
  [(run (and condition_0 condition_rest ...) val)
   (and-result (run condition_0 val) (and condition_rest ...) val)]
  [(run (or) val) #f]
  [(run (or condition_0 condition_rest ...) val)
   (or-result (run condition_0 val) (or condition_rest ...) val)]
  [(run (nor condition ...) val) (negate (run (or condition ...) val))]
  [(run (not condition) val) (negate (run condition val))]
  [(run (field regex string (regexp pattern)) val)
   ,(regex-field (term string) (term pattern) (term val))]
  [(run (field op string val_rhs) val) ,(leaf (term op) (term string) (term val_rhs) (term val))]
  [(run (elemMatch string condition) val) ,(element-match (term string) (term condition) (term val))])

(define-metafunction UCast
  and-result : result condition val -> result
  [(and-result #f condition val) #f]
  [(and-result error condition val) error]
  [(and-result #t condition val) (run condition val)])
(define-metafunction UCast
  or-result : result condition val -> result
  [(or-result #t condition val) #t]
  [(or-result error condition val) error]
  [(or-result #f condition val) (run condition val)])
(define-metafunction UCast
  negate : result -> result
  [(negate #t) #f]
  [(negate #f) #t]
  [(negate error) error])

(define-judgment-form UCast
  #:mode (Eval I I O)
  #:contract (Eval condition val result)
  [(where result (run condition val))
   ------------------- "evaluate"
   (Eval condition val result)])

(define (array? v) (and (pair? v) (eq? (car v) 'array)))
(define (object? v) (and (pair? v) (eq? (car v) 'object)))
(define (aggregate? v) (or (array? v) (object? v)))
(define (nullish? v) (memq v '(null missing)))
(define (falsy? v) (or (nullish? v) (eq? v #f) (equal? v 0) (equal? v "")))
(define (numeric-key? key) (or (equal? key "") (string->number key)))
(define (index-key key)
  (and (regexp-match? #px"^(0|[1-9][0-9]*)$" key) (string->number key)))
(define (own? v key)
  (cond [(object? v) (and (assoc key (cdr v)) #t)]
        [(or (array? v) (string? v))
         (or (equal? key "length")
             (let ([i (index-key key)] [n (if (string? v) (string-length v) (length (cdr v)))])
               (and i (< i n))))]
        [else #f]))
(define (raw-get v key)
  (when (nullish? v) (error 'lookup "nullish receiver"))
  (cond [(object? v) (match (assoc key (cdr v)) [#f 'missing] [(list _ value) value])]
        [(or (array? v) (string? v))
         (define xs (if (string? v) (map string (string->list v)) (cdr v)))
         (cond [(equal? key "length") (length xs)]
               [(and (index-key key) (< (index-key key) (length xs))) (list-ref xs (index-key key))]
               [else 'missing])]
        [else 'missing]))

;; Projection drops absent values and concatenates arrays by one level at each
;; path segment. It does not recursively flatten arbitrary nested arrays.
(define (segment v key)
  (if (and (array? v) (not (numeric-key? key)))
      `(array ,@(append-map
                 (lambda (item)
                   (define x (if (nullish? item) 'missing (raw-get item key)))
                   (cond [(eq? x 'missing) '()] [(array? x) (cdr x)] [else (list x)]))
                 (cdr v)))
      (raw-get v key)))
(define (lookup v path)
  (cond [(equal? path "__itself__") v]
        [(falsy? v) (error 'lookup "falsy receiver")]
        [else
         (let loop ([value v] [keys (string-split path "." #:trim? #f)])
           (define next (segment value (car keys)))
           (cond [(null? (cdr keys)) next]
                 [(not (aggregate? next)) 'missing]
                 [else (loop next (cdr keys))]))]))
(define (cursor v path)
  (define keys (string-split path "." #:trim? #f))
  (values (if (= (length keys) 1) v (lookup v (string-join (drop-right keys 1) ".")))
          (last keys)))
(define (safe-get v key)
  (if (or (equal? key "__itself__") (aggregate? v)) (lookup v key) 'missing))

;; Condition literals and input documents are separate JSON trees, so aggregate
;; identity is never equal. Primitive equality is type-sensitive (JS ===).
(define (strict=? a b) (and (not (aggregate? a)) (not (aggregate? b)) (equal? a b)))
(define (compare-values a b)
  (cond [(or (eq? a 'missing) (eq? b 'missing)) #f]
        [(and (number? a) (number? b)) (cond [(= a b) 0] [(> a b) 1] [else -1])]
        [(and (string? a) (string? b)) (cond [(string=? a b) 0] [(string>? a b) 1] [else -1])]
        [(and (boolean? a) (boolean? b)) (cond [(eq? a b) 0] [a 1] [else -1])]
        [(and (eq? a 'null) (eq? b 'null)) 0]
        [else #f]))
(define (contains? xs rhs) (ormap (lambda (x) (strict=? x rhs)) xs))
(define (some-value v test) (if (array? v) (ormap test (cdr v)) (test v)))
(define (guard thunk) (with-handlers ([exn:fail? (lambda (_) 'error)]) (thunk)))

;; Simple shared patterns exercise regex integration, not dialect equivalence.
(define (regex-field path pattern doc)
  (guard (lambda ()
           (define compiled (pregexp pattern))
           (some-value (lookup doc path)
                       (lambda (value)
                         (and (string? value) (regexp-match? compiled value)))))))

(define (equal-field path rhs doc)
  (define-values (parent key) (cursor doc path))
  (cond [(equal? path "__itself__")
         (some-value doc (lambda (item) (strict=? item rhs)))]
        [(eq? rhs 'null)
         (define (test item)
           (and (aggregate? item)
                (or (not (own? item key))
                    (let ([v (lookup item key)])
                      (or (eq? v 'null)
                          (and (array? v) (contains? (cdr v) 'null)))))))
         (if (and (array? parent) (not (numeric-key? key))) (ormap test (cdr parent)) (test parent))]
        [else
         (define value (safe-get parent key))
         (if (array? value) (contains? (cdr value) rhs) (strict=? value rhs))]))
(define (leaf op path rhs doc)
  (guard
   (lambda ()
     (case op
       [(eq) (equal-field path rhs doc)]
       [(ne) (not (equal-field path rhs doc))]
       [(exists)
        (if (equal? path "__itself__") (equal? (not (eq? doc 'missing)) rhs)
            (let-values ([(parent key) (cursor doc path)])
              (define present
                (if (and (array? parent) (not (numeric-key? key)))
                    (ormap (lambda (item) (own? item key)) (cdr parent))
                    (own? parent key)))
              (equal? present rhs)))]
       [(size)
        (define-values (parent key) (cursor doc path))
        (define (test item) (define v (safe-get item key)) (and (array? v) (equal? (length (cdr v)) rhs)))
        (if (and (not (equal? path "__itself__")) (array? parent) (not (numeric-key? key)))
            (ormap test (cdr parent)) (test parent))]
       [(all)
        (define v (lookup doc path))
        (and (array? v) (andmap (lambda (x) (contains? (cdr v) x)) (cdr rhs)))]
       [else
        (define v (lookup doc path))
        (define (test x)
          (case op
            [(lt lte gt gte)
             (define result (compare-values x rhs))
             (and result
                  (case op
                    [(lt) (= result -1)] [(lte) (<= result 0)]
                    [(gt) (= result 1)] [(gte) (>= result 0)]))]
            [(mod) (and (number? x) (not (zero? (cadr rhs)))
                        (= (remainder x (cadr rhs)) (caddr rhs)))]
            [(within in nin) (contains? (cdr rhs) x)]))
        (define result (some-value v test))
        (if (eq? op 'nin) (not result) result)]))))
(define (element-match path condition doc)
  (guard (lambda ()
           (define v (lookup doc path))
           (if (array? v)
               ;; Use the Boolean rules to retain error propagation and short circuiting.
               (let loop ([xs (cdr v)])
                 (if (null? xs) #f
                     (let ([r (term (run ,condition ,(car xs)))])
                       (if (eq? r #f) (loop (cdr xs)) r))))
               #f))))
(define (evaluate condition document)
  (unless (and (redex-match? UCast condition condition) (redex-match? UCast val document))
    (error 'evaluate "outside UCast grammar: ~s ~s" condition document))
  (term (run ,condition ,document)))

(module+ test
  (require rackunit)
  (check-equal? (lookup '(object ("items" (array null missing (object) (object ("a" 2)))))
                        "items.a")
                '(array 2))
  (check-equal? (lookup '(object ("items" (array (object ("a" (array 1 2))) (object))))
                        "items.a")
                '(array 1 2)))
