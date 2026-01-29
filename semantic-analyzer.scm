
(define (cs-defs cs) (car cs))
(define (cs-cals cs) (cadr cs))

(define builtin-ops '(+ - * / ^))

(define (def-name d) (car d))          
(define (def-params d) (cadr d))       


(define (def-rhs d)
  (let ((eqpart (caddr d)))
    (if (and (pair? eqpart) (eq? (car eqpart) '=) (pair? (cdr eqpart)))
        (cadr eqpart)
        '())))

(define (defined-fnames defs)
  (map def-name defs))

(define (fname->arity-alist defs)
  (map (lambda (d) (cons (def-name d) (length (def-params d))))
       defs))

(define (lookup-arity alist f)
  (let ((p (assq f alist)))
    (if p (cdr p) #f)))


(define find-redefined-functions
  (lambda (cs)
    (let loop ((defs (cs-defs cs)) (seen '()) (out '()))
      (if (null? defs)
          (reverse out)
          (let ((f (def-name (car defs))))
            (if (memq f seen)
                (loop (cdr defs) seen (cons f out))
                (loop (cdr defs) (cons f seen) out)))))))


(define (collect-vars expr)
  (cond
    ((symbol? expr) (list expr))
    ((pair? expr)
    
     (collect-vars-list (cdr expr)))
    (else '())))

(define (collect-vars-list xs)
  (if (null? xs)
      '()
      (append (collect-vars (car xs))
              (collect-vars-list (cdr xs)))))

(define (filter-not-in vars allowed)
  (cond ((null? vars) '())
        ((memq (car vars) allowed) (filter-not-in (cdr vars) allowed))
        (else (cons (car vars) (filter-not-in (cdr vars) allowed)))))

(define find-undefined-parameters
  (lambda (cs)
    (let loop ((defs (cs-defs cs)) (out '()))
      (if (null? defs)
          (reverse out)
          (let* ((d (car defs))
                 (params (def-params d))
                 (rhs (def-rhs d))
                 (vars (collect-vars rhs))
                 (bad (filter-not-in vars params)))
        
            (loop (cdr defs) (append (reverse bad) out)))))))


(define (calc-expr calc-stmt)

  (cadr calc-stmt))

(define (collect-lists expr)
  (cond ((pair? expr)
         (cons expr (collect-lists-list expr)))
        (else '())))

(define (collect-lists-list xs)
  (if (null? xs)
      '()
      (append (collect-lists (car xs))
              (collect-lists-list (cdr xs)))))


(define (collect-call-sites expr)
  (cond
    ((pair? expr)
     (let ((h (car expr))
           (rest (cdr expr)))
       (if (symbol? h)
           (cons expr (collect-call-sites-list rest))
           (collect-call-sites-list rest))))
    (else '())))

(define (collect-call-sites-list xs)
  (if (null? xs)
      '()
      (append (collect-call-sites (car xs))
              (collect-call-sites-list (cdr xs)))))

(define (call-like? node)

  (and (pair? node)
       (symbol? (car node))
       (not (memq (car node) builtin-ops))))

(define find-arity-contradictions
  (lambda (cs)
    (let* ((defs (cs-defs cs))
           (arity (fname->arity-alist defs))
           (calcs (cs-cals cs)))
      (let loopc ((cals calcs) (out '()))
        (if (null? cals)
            (reverse out)
            (let* ((e (calc-expr (car cals)))
                   (sites (collect-call-sites e))
                   (bad
                    (let loopn ((ns sites) (acc '()))
                      (if (null? ns)
                          (reverse acc)
                          (let ((n (car ns)))
                            (if (call-like? n)
                                (let* ((f (car n))
                                       (expected (lookup-arity arity f)))
                              
                                  (if expected
                                      (let ((given (length (cdr n))))
                                        (if (= given expected)
                                            (loopn (cdr ns) acc)
                                            (loopn (cdr ns) (cons f acc))))
                                      (loopn (cdr ns) acc)))
                                (loopn (cdr ns) acc)))))))
              (loopc (cdr cals) (append (reverse bad) out))))))))


(define (missing-name? node)
  (and (pair? node)
       (not (symbol? (car node)))))

(define find-missing-function-names
  (lambda (cs)
    (let ((calcs (cs-cals cs)))
      (let loopc ((cals calcs) (out '()))
        (if (null? cals)
            (reverse out)
            (let* ((e (calc-expr (car cals)))
                   (nodes (collect-lists e))
                   (bad
                    (let loopn ((ns nodes) (acc '()))
                      (if (null? ns)
                          (reverse acc)
                          (let ((n (car ns)))
                            (if (missing-name? n)
                                (loopn (cdr ns) (cons n acc))
                                (loopn (cdr ns) acc)))))))
              (loopc (cdr cals) (append (reverse bad) out))))))))


(define find-undefined-functions
  (lambda (cs)
    (let* ((defs (cs-defs cs))
           (known (defined-fnames defs))
           (calcs (cs-cals cs)))
      (let loopc ((cals calcs) (out '()))
        (if (null? cals)
            (reverse out)
            (let* ((e (calc-expr (car cals)))
                   (sites (collect-call-sites e))
                   (bad
                    (let loopn ((ns sites) (acc '()))
                      (if (null? ns)
                          (reverse acc)
                          (let ((n (car ns)))
                            (if (call-like? n)
                                (let ((f (car n)))
                                  (if (memq f known)
                                      (loopn (cdr ns) acc)
                                      (loopn (cdr ns) (cons f acc))))
                                (loopn (cdr ns) acc)))))))
              (loopc (cdr cals) (append (reverse bad) out))))))))
