#lang racket

(require rackunit json racket/runtime-path "../run-fixed-tests.rkt")

(module+ test
  (define-runtime-path tracer "../trace.rkt")
  (define temporary (make-temporary-file "ucast-fixed-runner-~a" 'directory))
  (dynamic-wind
    void
    (lambda ()
      (define package (build-path temporary "package"))
      (define source (build-path package "tests"))
      (define output (build-path temporary "output"))
      (make-directory* (build-path package "tooling"))
      ;; This adapter uses native numbers and equality, with no core imports.
      (call-with-output-file (build-path package "tooling" "adapter.rkt")
        (lambda (out)
          (display "#lang racket\n(provide evaluate condition->json value->json)\n(define evaluate equal?)\n(define condition->json values)\n(define value->json values)\n" out)))
      (define (author relative id expected)
        (define target (build-path source relative))
        (make-directory* (path-only target))
        (call-with-output-file target
          (lambda (out)
            (fprintf out "#lang racket\n(require (file ~s))\n(provide tests)\n(define (tests) (check-eval ~s ~s 1 1 ~s))\n"
                     (path->string tracer) id id expected))))
      (author "core/first.rkt" "first" #t)
      (author "runtime/second.rkt" "second" #t)
      (run-fixed-tests 'export package output)
      (check-true (file-exists? (build-path output "core" "first.json")))
      (check-true (file-exists? (build-path output "runtime" "second.json")))
      (check-not-exn (lambda () (run-fixed-tests 'check package output)))
      (author "runtime/duplicate.rkt" "first" #t)
      (check-exn #rx"duplicate case id" (lambda () (run-fixed-tests 'test package)))
      (delete-file (build-path source "runtime" "duplicate.rkt"))
      ;; An assertion failure in a later suite prevents all fixture writes.
      (author "runtime/wrong.rkt" "wrong" #f)
      (define blocked-output (build-path temporary "not-written"))
      (check-exn exn:fail? (lambda () (run-fixed-tests 'export package blocked-output)))
      (check-false (directory-exists? blocked-output)))
    (lambda () (delete-directory/files temporary))))
