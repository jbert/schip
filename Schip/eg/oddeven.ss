;; even? defined in terms off odd?
(define (even? n)
  (if (= n 0)
   1
   (odd? (- n 1))))

;; odd? defined in terms off even?
(define (odd? n)
  (if (= n 0)
   0
   (even? (- n 1))))

(if (odd? 3)
	(display "three is odd")
	(error "oops - odd"))
(newline)
(if (even? 2)
	 (display "two is even")
	 (error "oops - even"))
(newline)
