; INFORMAL UNIT TESTS
;; be sure to define the functions from play.lisp

;; this test builds the regex from the provided input and asks
;; "does the resulting pattern match the entire word?"
(multiple-value-bind
    (match-start match-end)
    (cl-ppcre:scan (build-regex "ocean" #(0 0 0 0 0) (mapcar #'copy-seq *abc*)) "ocean")
  (and (= match-start 0) (= match-end *num-characters*)))

;; a grab bag of tests to see whether the remaining words are correct for the given an inputs.
(=
 (gethash "ocean" (guess-filter "ocean" #(0 0 0 0 0) (copy-hash-table *words*) (mapcar #'copy-seq *abc*)))
 (gethash "ocean" *words*))
(=
 (gethash "octan" (guess-filter "ocean" #(0 0 2 0 0) (copy-hash-table *words*) (mapcar #'copy-seq *abc*)))
 (gethash "octan" *words*))
(=
 (hash-table-count (guess-filter "ocean" #(0 0 1 0 0) (copy-hash-table *words*) (mapcar #'copy-seq *abc*)))
 0)
(=
 (sum-hash-values
  (guess-filter
   "ocean"
   #(:grey :grey :grey :grey :grey)
   (copy-hash-table *words*)
   (mapcar #'copy-seq *abc*)))
 3850108070)

;; these answers match the guess_filter call in play.R
(let ((test-dict (make-hash-table :test #'equal)))
  (setf (gethash "aahed" test-dict) (gethash "aahed" *words*))
  (setf (gethash "aalii" test-dict) (gethash "aalii" *words*))
  (setf (gethash "aargh" test-dict) (gethash "aargh" *words*))
  (setf (gethash "aarti" test-dict) (gethash "aarti" *words*))
  (setf (gethash "abaca" test-dict) (gethash "abaca" *words*))
  (let ((output (calculate-scores-internal
                  (get-hash-keys test-dict)
                  test-dict
                  *abc*)))
    (and
      (= (round-to (gethash "aahed" output) 1) 1.6)
      (= (round-to (gethash "aalii" output) 1) 1.6)
      (= (round-to (gethash "aargh" output) 1) 1.6)
      (= (round-to (gethash "aarti" output) 1) 1.6)
      (= (round-to (gethash "abaca" output) 1) 1.0))))
