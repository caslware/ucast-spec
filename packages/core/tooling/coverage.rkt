#lang racket

(require redex/reduction-semantics "../formal/semantics.rkt")
(provide make-generator-coverage consider-case! missing-coverage missing-root-operators
         logical-coverage-complete? coverage-complete? print-coverage operators)

;; Fresh records for each run; callers parameterize relation-coverage and disable
;; caching so recursive calls are measured even after a previous evaluation.
(define (make-evaluation-coverage)
  (list (cons 'run (make-coverage run))
        (cons 'and-result (make-coverage and-result))
        (cons 'or-result (make-coverage or-result))
        (cons 'negate (make-coverage negate))))

;; Redex distinguishes semantic clauses, but the Racket leaf dispatcher shares
;; one clause. Root operator/outcome counts complement (not replace) rule coverage.
(define operators '(and or nor not eq ne lt lte gt gte exists size mod within in nin all regex elemMatch))
(struct generator-coverage (rules outcomes logic) #:transparent)
(define logical-goals
  (append
   (for*/list ([op '(and or nor)] [a '(#t #f error)] [b '(#t #f error)])
     (list 'binary op a b))
   (for*/list ([op '(and or)] [side '(left right)] [a '(#t #f error)] [b '(#t #f error)])
     (list 'de-morgan op side a b))))
(define (rule-counts records)
  (for*/hash ([record records] [entry (covered-cases (cdr record))])
    (values (format "~a/~a" (car record) (car entry)) (cdr entry))))
(define (make-generator-coverage)
  (generator-coverage
   (hash-copy (rule-counts (make-evaluation-coverage)))
   (make-hash (for*/list ([op operators] [result '(#t #f error)])
                (cons (list op result) 0)))
   (make-hash (map (lambda (key) (cons key 0)) logical-goals))))
(define (root-operator c) (if (eq? (car c) 'field) (cadr c) (car c)))
(define (evaluate/coverage c v)
  (define records (make-evaluation-coverage))
  (define result
    (parameterize ([relation-coverage (map cdr records)] [caching-enabled? #f])
      (evaluate c v)))
  (values result (rule-counts records)))
(define (logical-keys c doc)
  ;; These are independent operand outcomes for a coverage classification only.
  ;; Their evaluation does not contribute to native execution-clause coverage.
  (define (key prefix a b) (append prefix (list (evaluate a doc) (evaluate b doc))))
  (append
   (match c
     [`(,(and op (or 'and 'or 'nor)) ,a ,b) (list (key (list 'binary op) a b))]
     [_ '()])
   (match c
     [`(not (,(and op (or 'and 'or)) ,a ,b))
      (list (key (list 'de-morgan op 'left) a b))]
     [`(or (not ,a) (not ,b)) (list (key '(de-morgan and right) a b))]
     [`(and (not ,a) (not ,b)) (list (key '(de-morgan or right) a b))]
     [_ '()])))
(define (consider-case! coverage c doc #:only-new? [only-new? #f])
  (define-values (result rules) (evaluate/coverage c doc))
  (unless (member result '(#t #f error))
    (error 'coverage "invalid evaluation result: ~s" result))
  ;; Classify once, outside the measured evaluation. Discarded candidates must
  ;; not contribute either execution counts or logical coverage.
  (define outcome-key (list (root-operator c) result))
  (define logic-keys (logical-keys c doc))
  (define retain?
    (or (not only-new?)
        (coverage-complete? coverage)
        (zero? (hash-ref (generator-coverage-outcomes coverage) outcome-key))
        (for/or ([key logic-keys])
          (zero? (hash-ref (generator-coverage-logic coverage) key)))
        (for/or ([(key hits) (in-hash rules)])
          (and (positive? hits) (zero? (hash-ref (generator-coverage-rules coverage) key))))))
  (when retain?
    (for ([(key hits) (in-hash rules)] #:when (positive? hits))
      (hash-update! (generator-coverage-rules coverage) key (lambda (n) (+ n hits))))
    (hash-update! (generator-coverage-outcomes coverage) outcome-key add1)
    (for ([key logic-keys])
      (hash-update! (generator-coverage-logic coverage) key add1)))
  ;; Once complete, generation retains ordinary samples to fill its requested size.
  ;; Replay omits #:only-new? so every saved case contributes to the report.
  (values result retain?))
(define (missing-root-operators coverage)
  (for/list ([op operators]
             #:when (for/or ([result '(#t #f error)])
                      (zero? (hash-ref (generator-coverage-outcomes coverage) (list op result)))))
    op))
(define (logical-coverage-complete? coverage)
  (andmap positive? (hash-values (generator-coverage-logic coverage))))
(define (missing-coverage coverage)
  (append
   (for/list ([key (sort (hash-keys (generator-coverage-rules coverage)) string<?)]
              #:when (zero? (hash-ref (generator-coverage-rules coverage) key)))
     key)
   (for*/list ([op operators] [result '(#t #f error)]
               #:when (zero? (hash-ref (generator-coverage-outcomes coverage) (list op result))))
     (list op result))
   (filter (lambda (key) (zero? (hash-ref (generator-coverage-logic coverage) key))) logical-goals)))
(define (coverage-complete? coverage) (null? (missing-coverage coverage)))
(define (print-coverage coverage [out (current-output-port)])
  (define rules (generator-coverage-rules coverage))
  (fprintf out "Redex clauses covered: ~a/~a\n"
           (count positive? (hash-values rules)) (hash-count rules))
  (fprintf out "Root operator outcomes (true / false / error):\n")
  (for ([op operators])
    (fprintf out "  ~a: ~a\n" op
             (string-join
              (for/list ([result '(#t #f error)])
                (number->string (hash-ref (generator-coverage-outcomes coverage) (list op result))))
              " / ")))
  (define logic (generator-coverage-logic coverage))
  (fprintf out "Ordered binary and/or/nor outcomes covered: ~a/27\n"
           (count (lambda (key) (positive? (hash-ref logic key))) (take logical-goals 27)))
  (fprintf out "De Morgan sides/operand outcomes covered: ~a/36\n"
           (count (lambda (key) (positive? (hash-ref logic key))) (drop logical-goals 27)))
  (fprintf out "Missing coverage: ~s\n" (missing-coverage coverage)))

(module+ test
  (require rackunit)
  (define regex '(field regex "__itself__" (regexp "a")))
  ;; Warm the evaluator's normal cache before measuring. Coverage must still
  ;; include recursive calls on each repeated measurement.
  (define c `(and (and) ,regex))
  (check-true (evaluate c "a"))
  (define-values (result rules) (evaluate/coverage c "a"))
  (define-values (again repeated-rules) (evaluate/coverage c "a"))
  (check-equal? result #t)
  (check-equal? rules repeated-rules)
  (define-values (_ regex-rules) (evaluate/coverage regex "a"))
  (define-values (short-result short-rules) (evaluate/coverage `(and (or) ,regex) "a"))
  (check-false short-result)
  ;; Find the regex clause through actual Redex coverage, not source line numbers.
  (define regex-clause
    (for/first ([(key hits) (in-hash regex-rules)] #:when (positive? hits)) key))
  (check-not-false regex-clause)
  (check-true (positive? (hash-ref rules regex-clause)))
  (check-equal? (hash-ref short-rules regex-clause) 0)
  (define coverage (make-generator-coverage))
  (check-false (coverage-complete? coverage))
  (define-values (first-result retained?) (consider-case! coverage c "a" #:only-new? #t))
  (check-equal? first-result result)
  (check-true retained?)
  (define report (with-output-to-string (lambda () (print-coverage coverage))))
  (define-values (_result repeated?) (consider-case! coverage c "a" #:only-new? #t))
  (check-false repeated?)
  (check-equal? (with-output-to-string (lambda () (print-coverage coverage))) report)
  (check-false (member '(binary and #t #t) (missing-coverage coverage)))
  (check-not-false (member '(binary and #t error) (missing-coverage coverage)))
  (check-not-false (member '(de-morgan and left #t #t) (missing-coverage coverage)))
  (check-not-false (member '(de-morgan and right #t #t) (missing-coverage coverage)))
  (check-not-false (member '(regex #t) (missing-coverage coverage)))
  ;; A nested regex is not credited as a root regex result.
  (check-false (member '(and #t) (missing-coverage coverage))))
