(define (odd? n)
	(if (= n 0)
		0
		(not (even? (- n 1)))))

(define (even n)
	(if (= n 0)
		1
		(not (odd (- n 1)))))

(if (even? 2)
	 (display "two is even")
	 (error "oops"))
(newline)
(if (odd? 3)
	(display "three is odd")
	(error "oops"))
(newline)
