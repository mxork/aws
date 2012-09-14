#lang racket

(require racket/generator)

(provide in-take
         filter-take)

(module+ test
  (require rackunit))

;; Background: Functions like `hash', `hash-set*', `dict-set*' and so
;; on take argument couples as alternating arguments rather than a
;; cons pair. Using such functions can be refreshing, as you can type
;; simply (hash k0 v0 k1 v1) instead of all the dots and parens with
;; #hash([k0 . v0][k1 v2]). Using such functions is nice, but defining
;; them is a bit awkward -- unless you have in-take.  It lets you
;; sequence a flat list of items in groups of N, much like using
;; `take' and `drop'.
;;
;; Likewise, this makes it easy to write simple flat wrappers. for example
;; here is a `hash'-like initializer for association lists:
;;
;; (define (alist . xs)
;;   (for/list ([(k v) (in-take xs 2)])
;;     (cons k v)))
;;
;; Generalizing:
;;
;; 1. At first I wrote this for couples in lists.
;;
;; 2. Then I generalized it to any group size -- couples, triples,
;; whatever -- in lists.
;;
;; 3. Then I generalized it to work with any single-valued sequence:
;; list, vector, string, etc.


(define (make-fill who n)
  (lambda (_)
    (error who "list not multiple of ~a items" n)))

(define fill/c (exact-nonnegative-integer? . -> . any/c))

;; (in-take seq n fill) is a way to take `n' elements at a time from
;; `seq'. For instance with n=2 you will get successive couples of
;; elements, with n=3 you get triples, and so on.  `n' defaults to 2.
;; If there aren't exactly `n' elements at the end of the list, `fill'
;; is called with an index from 0 to (sub1 n). `fill' defaults to a
;; procedure that raises an error, but you may supply a procedure that
;; "fills in missing values".

(define/contract (in-take seq [n 2] [fill (make-fill 'in-take n)])
  ((sequence?) (exact-positive-integer? fill/c) . ->* . sequence?)
  (define the-end (gensym))
  (define (stop? . xs)
    (equal? (car xs) the-end))
  (in-producer
   (generator ()
              (define s (sequence->stream seq))
              (unless (stream-empty? s)
                (let produce ([s (sequence->stream seq)])
                  (let consume ([s s]
                                [i 0]
                                [xs '()])
                    (cond [(= i n)
                           (apply yield xs)
                           (unless (stream-empty? s)
                             (produce s))]
                          [(stream-empty? s)
                           (apply yield (append xs
                                                (for/list ([i (in-range i n)])
                                                  (fill i))))]
                          [else
                           (consume (stream-rest s)
                                    (add1 i)
                                    (append xs (list (stream-first s))))]))))
              (apply yield (make-list n the-end)))
   stop?))

(module+ test
  (test-case
   "in-take"
   ;; Take from an empty sequence is '() (not an error)
   (check-equal? (for/list ([(k v) (in-take (list))])
                   (cons k v))
                 '())
   (check-equal? (for/list ([(k v) (in-take (vector))])
                   (cons k v))
                 '())
   (check-equal? (for/list ([(k v) (in-take "")])
                   (cons k v))
                 '())
   ;; Sequence is multiple of take size
   (check-equal? (for/list ([(k v) (in-take (list 'a "1" 'b "2"))])
                   (cons k v))
                 '([a . "1"][b . "2"]))
   (check-equal? (for/list ([(k v) (in-take (vector 'a "1" 'b "2"))])
                   (cons k v))
                 '([a . "1"][b . "2"]))
   (check-equal? (for/list ([(k v) (in-take "a1b2")])
                   (cons k v))
                 '([#\a . #\1][#\b . #\2]))
   ;; Missing values raising an error (the default `fill')
   (check-exn exn:fail?
              (lambda () (for/list ([(k v) (in-take '(a "1" b "2" c) 2)])
                      (cons k v))))
   ;; Missing values filled in
   (check-equal? (for/list ([(k v) (in-take '(a "1" b "2" c) 2
                                            (const "FILL"))])
                   (cons k v))
                 '([a . "1"][b . "2"][c . "FILL"]))
   ;; Fill function is passed expected "index"
   (check-equal? (for/list ([(a b c d e) (in-take '(0 1) 5 values)])
                   (list a b c d e))
                 '((0 1 2 3 4))) ;fill was called with 2 3 4
   ;; Taking the same list with different take-sizes.
   (define test-xs (list 0 1 2 3 4 5 6 7 8 9))
   (define (test-take n)
     (for/list ([ts (in-values-sequence (in-take test-xs n))])
       ts))
   (check-equal? (test-take 1)
                 '((0) (1) (2) (3) (4) (5) (6) (7) (8) (9)))
   (check-equal? (test-take 2)
                 '((0 1) (2 3) (4 5) (6 7) (8 9)))
   (check-equal? (test-take 5)
                 '((0 1 2 3 4) (5 6 7 8 9)))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Given a sequence, return a sequence containing only each group of `n'
;; elements for which `pred?' is true.

;;; ======= TO-DO ========
;;;
;;; Hmmm. This now takes a sequence but still returns a list.
;;;
;;; Should it return the same kind of sequence it was given?

(define/contract (filter-take pred? seq [n 2] [fill (make-fill 'filter-take n)])
  ((procedure? sequence?) (exact-positive-integer? fill/c) . ->* . list?)
  (for/fold ([ys '()])
            ([ts (in-values-sequence (in-take seq n fill))])
    (cond [(apply pred? ts) (append ys ts)]
          [else ys])))

(module+ test
  (test-case
   "filter-take"
   (check-equal? (filter-take (lambda (a b) b) '(a 1 b #f c 3) 2)
                 '(a 1 c 3))
   (check-equal? (filter-take (const #f) '(1 2 3 4) 2) '())
   (check-equal? (filter-take (const #t) '() 2) '())))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
