#lang typed/racket

(require drbayes)

(provide (all-defined-out))

;; Single-precision floating-point epsilon
(define epsilon.f (expt 2.0 -24.0))

;; ===================================================================================================
;; A real-valued model of the floating point numbers

#|
A floating-point number is either a special value, or consists of

  1. A true real value
  2. An upper bound on the relative error, which is in [0,1)

Together, the real value `vx' and relative error `ex' define an interval:

  [(1-ex)*vx,(1+ex)*vx]    if vx is positive
  [(1+ex)*vx,(1-ex)*vx]    if vx is negative
  [0,0]                    if vx is zero

The actual floating-point number lies somewhere in this interval.
|#

(struct/drbayes float-any ())
(struct/drbayes float (value error))

(define/drbayes (fl x)
  (float x 0))

(define/drbayes (make-float vx ex)
  (cond
    [(negative? ex)  (fail)]
    [(ex . >= . 1)   (float-any)]
    [else  (float vx (if (zero? vx) 0 ex))]))

(define/drbayes (flneg x)
  (if (float-any? x) x (float (- (float-value x)) (float-error x))))

(define/drbayes (flabs x)
  (if (float-any? x) x (float (abs (float-value x)) (float-error x))))

(define/drbayes (fl*2 x)
  (if (float-any? x) x (float (* (float-value x) 2) (float-error x))))

(define/drbayes (fl/2 x)
  (if (float-any? x) x (float (/ (float-value x) 2) (float-error x))))

(define/drbayes (flnegative? x)
  (if (float-any? x) (boolean (const 0.5)) (negative? (float-value x))))

(define/drbayes (flpositive? x)
  (if (float-any? x) (boolean (const 0.5)) (positive? (float-value x))))

(define/drbayes (flzero? x)
  (if (float-any? x) (boolean (const 0.5)) (zero? (float-value x))))

(define/drbayes (fl< x y)
  (cond
    [(float-any? x)  (boolean (const 0.5))]
    [(float-any? y)  (boolean (const 0.5))]
    [else
     (let ([vx  (float-value x)]
           [vy  (float-value y)]
           [ex  (float-error x)]
           [ey  (float-error y)])
       (cond
         [(negative? vx)
          (cond
            [(nonnegative? vy)  #t]
            [((* (- 1 ex) vx) . < . (* (+ 1 ey) vy))  #t]
            [((* (- 1 ey) vy) . < . (* (+ 1 ex) vx))  #f]
            [else  (boolean (const 0.5))])]
         [(positive? vx)
          (cond
            [(nonpositive? vy)  #f]
            [((* (+ 1 ex) vx) . < . (* (- 1 ey) vy))  #t]
            [((* (+ 1 ey) vy) . < . (* (- 1 ex) vx))  #f]
            [else  (boolean (const 0.5))])]
         [else
          (positive? vy)]))]))

(define/drbayes (fl= x y)
  (cond
    [(float-any? x)  (boolean (const 0.5))]
    [(float-any? y)  (boolean (const 0.5))]
    [else
     (let ([vx  (float-value x)]
           [vy  (float-value y)]
           [ex  (float-error x)]
           [ey  (float-error y)])
       (cond
         [(and (zero? ex) (zero? ey) (= vx vy))  #t]
         [(negative? vx)
          (cond
            [(nonnegative? vy)  #f]
            [((* (- 1 ex) vx) . < . (* (+ 1 ey) vy))  #f]
            [((* (- 1 ey) vy) . < . (* (+ 1 ex) vx))  #f]
            [else  (boolean (const 0.5))])]
         [(positive? vx)
          (cond
            [(nonpositive? vy)  #f]
            [((* (+ 1 ex) vx) . < . (* (- 1 ey) vy))  #f]
            [((* (+ 1 ey) vy) . < . (* (- 1 ex) vx))  #f]
            [else  (boolean (const 0.5))])]
         [else
          (zero? vy)]))]))

(define/drbayes (fl>= x y)
  (not (fl< x y)))

(define/drbayes (fl> x y)
  (fl< y x))

(define/drbayes (fl<= x y)
  (not (fl> x y)))

(define/drbayes (flmin x y)
  (if (fl< x y) x y))

(define/drbayes (flmax x y)
  (if (fl< x y) y x))

(define/drbayes (flsqrt x)
  (cond
    [(float-any? x)  x]
    [else
     (let ([vx  (float-value x)]
           [ex  (float-error x)])
       (cond
         [(negative? vx)  (float-any)]
         [(zero? vx)  (fl 0)]
         [else
          (make-float (sqrt vx)
                      (+ (const (* 0.5 epsilon.f))
                         (- 1 (sqrt (- 1 ex)))))]))]))

(define/drbayes (flsqr x)
  (cond
    [(float-any? x)  x]
    [else
     (let ([vx  (float-value x)]
           [ex  (float-error x)])
       (cond
         [(zero? vx)  (fl 0)]
         [else
          (make-float (sqr vx)
                      (+ (const (* 0.5 epsilon.f))
                         (- (sqr (+ ex 1)) 1)))]))]))

(define/drbayes (fllog x)
  (cond
    [(float-any? x)  x]
    [else
     (let ([vx  (float-value x)]
           [ex  (float-error x)])
       (cond
         [(vx . = . 1)
          (if (zero? ex) (fl 0) (float-any))]
         [(vx . > . 1)
          (make-float (log vx)
                      (+ (const (* 0.5 epsilon.f))
                         ;; Exact upper bound
                         (- (/ (log1p (- ex)) (log vx)))
                         #;; Loose upper bound
                         (/ ex (- 1 (/ 1 vx)))))]
         [(positive? vx)
          (make-float (log vx)
                      (+ (const (* 0.5 epsilon.f))
                         ;; Exact upper bound
                         (/ (log1p (- ex)) (log vx))
                         #;; Loose upper bound
                         (/ ex (- 1 vx))))]
         [else
          (float-any)]))]))

(define/drbayes (flexp x)
  (cond
    [(float-any? x)  x]
    [else
     (let ([vx  (float-value x)]
           [ex  (float-error x)])
       (cond
         [(zero? vx)  (fl 1)]
         [(positive? vx)
          (make-float (exp vx)
                      (+ (const (* 0.5 epsilon.f))
                         ;; Exact upper bound
                         (expm1 (* ex vx))
                         #;; Loose upper bound
                         (* ex (/ vx (log 2)))))]
         [else
          (make-float (exp vx)
                      (+ (const (* 0.5 epsilon.f))
                         ;; Exact upper bound
                         (expm1 (- (* ex vx)))
                         #;; Loose upper bound
                         (* ex (/ vx (log 0.5)))))]))]))

(define/drbayes (fllog1p x)
  (cond
    [(float-any? x)  x]
    [else
     (let ([vx  (float-value x)]
           [ex  (float-error x)])
       (cond
         [(zero? vx)  (fl 0)]
         [(positive? vx)
          (make-float (log1p vx)
                      (+ (const (* 0.5 epsilon.f))
                         #;; Exact upper bound
                         (- 1 (/ (log1p (* (- 1 ex) vx)) (log1p vx)))
                         #;; Loose upper bound (gets looser as vx increases)
                         ex
                         ;; Loose upper bound (gets tighter as vx increases)
                         (if (vx . < . 3) ex (- (/ (log1p (- ex)) (log1p vx))))))]
         ;; Only needed for the exact upper bound
         [((* (+ 1 ex) vx) . <= . -1)
          (float-any)]
         [else
          (make-float (log1p vx)
                      (+ (const (* 0.5 epsilon.f))
                         #;; Exact upper bound
                         (- (/ (log1p (* (+ 1 ex) vx)) (log1p vx)) 1)
                         ;; Loose upper bound
                         (/ ex (+ vx 1))))]))]))

(define/drbayes (flexpm1 x)
  (cond
    [(float-any? x)  x]
    [else
     (let ([vx  (float-value x)]
           [ex  (float-error x)])
       (cond
         [(zero? vx)  (fl 0)]
         [(positive? vx)
          (make-float (expm1 vx)
                      (+ (const (* 0.5 epsilon.f))
                         #;; Exact upper bound
                         (- (/ (expm1 (* (+ 1 ex) vx)) (expm1 vx)) 1)
                         ;; Loose upper bound
                         (* ex (+ 1 (/ vx (log 2))))))]
         [else
          (make-float (expm1 vx)
                      (+ (const (* 0.5 epsilon.f))
                         #;; Exact upper bound
                         (- 1 (/ (expm1 (* (- 1 ex) vx)) (expm1 vx)))
                         ;; Loose upper bound
                         ex))]))]))

;; Assumes vx and vy are nonzero
(define/drbayes (fladd-error vx ex vy ey)
  (cond
    [(positive? vx)
     (cond
       [(positive? vy)
        #;; Exact upper bound
        (/ (+ (* vx ex) (* vy ey)) (+ vx vy))
        ;; Looser bound
        (if (> ex ey) ex ey)]
       [else
        (let ([z  (+ 1 (/ vy vx))])
          (cond [(nonnegative? z)
                 #;; Exact upper bound
                 (- (/ (+ ex ey) z) ey)
                 ;; Looser bound
                 (/ (+ ex ey) z)]
                [else
                 (let ([z  (+ 1 (/ vx vy))])
                   (cond [(nonnegative? z)
                          #;; Exact upper bound
                          (- (/ (+ ey ex) z) ex)
                          ;; Looser bound
                          (/ (+ ey ex) z)]
                         [else
                          ;; Unreachable
                          (fail)]))]))])]
    [else
     (cond
       [(negative? vy)
        #;; Exact upper bound
        (/ (+ (* vx ex) (* vy ey)) (+ vx vy))
        ;; Looser bound
        (if (> ex ey) ex ey)]
       [else
        (let ([z  (+ 1 (/ vx vy))])
          (cond [(nonnegative? z)
                 #;; Exact upper bound
                 (- (/ (+ ex ey) z) ex)
                 ;; Looser bound
                 (/ (+ ex ey) z)]
                [else
                 (let ([z  (+ 1 (/ vy vx))])
                   (cond [(nonnegative? z)
                          #;; Exact upper bound
                          (- (/ (+ ex ey) z) ey)
                          ;; Looser bound
                          (/ (+ ex ey) z)]
                         [else
                          ;; Unreachable
                          (fail)]))]))])]))

(define/drbayes (fl+ x y)
  (cond
    [(float-any? x)  x]
    [(float-any? y)  y]
    [else
     (let ([vx  (float-value x)]
           [vy  (float-value y)]
           [ex  (float-error x)]
           [ey  (float-error y)])
       (cond [(and (zero? vx) (zero? vy))  (fl 0)]
             [(zero? vx)  y]
             [(zero? vy)  x]
             [(vx . = . (- vy))
              (if (and (zero? ex) (zero? ey)) (fl 0) (float-any))]
             [else
              (make-float (+ vx vy)
                          (+ (const (* 0.5 epsilon.f))
                             (fladd-error vx ex vy ey)))]))]))

(define/drbayes (fl- x y)
  (fl+ x (flneg y)))

(define/drbayes (fl* x y)
  (cond
    [(float-any? x)  x]
    [(float-any? y)  y]
    [else
     (let ([vx  (float-value x)]
           [ex  (float-error x)]
           [vy  (float-value y)]
           [ey  (float-error y)])
       (cond
         [(or (zero? vx) (zero? vy))  (fl 0)]
         [else
          (make-float (* vx vy)
                      (+ (const (* 0.5 epsilon.f))
                         (- (* (+ 1 ex) (+ 1 ey)) 1)))]))]))

(define/drbayes (fl/ x y)
  (cond
    [(float-any? x)  x]
    [(float-any? y)  y]
    [else
     (let ([vx  (float-value x)]
           [vy  (float-value y)]
           [ex  (float-error x)]
           [ey  (float-error y)])
       (cond [(zero? vx)  (fl 0)]
             [(zero? vy)  (float-any)]
             [else
              (make-float (/ vx vy)
                          (+ (const (* 0.5 epsilon.f))
                             (- (/ (+ 1 ex) (- 1 ey)) 1)))]))]))

#|
(define gamma-crit #e1.46163214496836234126265954232572132846819620400644635129598840860)
(define gamma-crit-val #e0.885603194410888700278815900582588733207951533669903448871200)

(define/drbayes (flgamma x)
  (cond
    [(float-any? x)  x]
    [else
     (let ([vx  (float-value x)]
           [ex  (float-error x)])
       (cond [(nonpositive? vx)  (float-any)]
             [((* (+ 1 ex) vx) . <= . (const gamma-crit))
              ;; All floats on the left side of the critical value
              (make-float (gamma vx)
                          (+ (const (* 0.5 epsilon.f))
                             #;; Exact upper bound
                             (- (/ (gamma (* (- 1 ex) vx)) (gamma vx)) 1)
                             ;; Looser bound
                             (/ ex 0.45)))]
             [((* (- 1 ex) vx) . >= . (const gamma-crit))
              ;; All floats on the right side of the critical value
              (make-float (gamma vx)
                          (+ (const (* 0.5 epsilon.f))
                             #;; Exact upper bound
                             (- (/ (gamma (* (+ 1 ex) vx)) (gamma vx)) 1)
                             ;; Looser bound
                             (/ ex (+ -0.000224 (/ 0.157 (+ vx -1.23))))))]
             [else
              ;; Floats on each side of the critical value
              (make-float (gamma vx)
                          (+ (const (* 0.5 epsilon.f))
                             #;; Exact upper bound
                             (max (max (- (/ (gamma (* (- 1 ex) vx)) (gamma vx)) 1)
                                       (- (/ (gamma (* (+ 1 ex) vx)) (gamma vx)) 1))
                                  (- 1 (/ (const gamma-crit-val) (gamma vx))))
                             ;; Looser bound
                             (max (max (/ ex 0.45)
                                       (/ ex (+ -0.000224 (/ 0.157 (+ vx -1.23)))))
                                  (- 1 (/ (const gamma-crit-val) (gamma vx))))))]))]))
|#
