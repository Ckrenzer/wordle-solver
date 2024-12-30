(ql:quickload "cl-ppcre")
(ql:quickload "local-time")
;; bordeaux-threads does not guarantee threads will run on different cores--that
;; decision is left to the os and task scheduler.
(ql:quickload "bordeaux-threads")
(when (not bordeaux-threads:*supports-threads-p*)
  (error "This implementation does not support multi-threading!"))



; HELPER FUNCTIONS/MACROS
(defun generate-log-file-name (&optional (thread (bordeaux-threads:current-thread)))
  "Create a file path string string tied to the name of the input thread. This function is used
  to create a dedicated file for each thread to send its output during the multi-threaded section
  of the score calculation."
  (format nil "log/scores_~a.tsv" (remove #\: (bordeaux-threads:thread-name thread))))

(defun file-read-lines (filename)
  "Read a file, storing each line in its own element of a list." ;; Is a list really the right choice here?
  (with-open-file (instream filename)
    (with-standard-io-syntax
      (loop for line = (read-line instream nil)
            while line
            collect line))))

(defun get-hash-keys (hash-map)
  "Return the keys of a hash table in a list." ;; revisit whether using a list is a good data structure here.
  (let ((keys nil))
    (maphash #'(lambda (k v)
                 (declare (ignore v))
                 (push k keys))
             hash-map)
    keys))

;; you know, you could use alexandria:copy-hash-table and get close to the
;; same thing, but is that really the point of this exercise?
(defun copy-hash-table (hash-table)
  "Create a new hash table with the same key-value pairs that uses the same
  test and size as the input hash table."
  (let ((new-hash-table (make-hash-table
                          :test (hash-table-test hash-table)
                          :size (hash-table-size hash-table))))
    (maphash #'(lambda (key value)
                 (setf (gethash key new-hash-table) value))
             hash-table)
    new-hash-table))

(defun fast-intersection (list1 list2)
  "Quickly compare values between two lists (store values of first list as
  hash table keys and then see if values in the second are found).
  This function was made specifically to work with strings so that
  the word frequency table would be easy to construct
  (knowledge of the unigrams file is baked into this function)."
  (let ((lookup (make-hash-table :size (length list1) :test #'equal)))
    (dolist (item list1)
      (setf (gethash item lookup) t))
    (delete-if-not #'(lambda (item) (gethash (subseq item 0 *NUM-CHARACTERS*) lookup)) list2)))

;; this should probably be a function...
(defmacro sum-hash-values (hash-table)
  "Compute the sum of values in a hash table. Undefined when all values are not numeric."
  `(let ((total 0))
     (maphash
       #'(lambda (k v) (declare (ignore k)) (incf total v))
       ,hash-table)
     total))

(defun round-to (num &optional (digits 0))
  "Wrapper for the round function to round to specific decimal points
  (risks overflowing on large numbers or values of digits)."
  (let ((scale-factor (expt 10.0 digits)))
    (multiple-value-bind (integer-part decimal-part) (round (* num scale-factor))
      (declare (ignore decimal-part))
      (/ integer-part scale-factor))))

(defun get-formatted-time ()
  "Get the current time using *LOG-FILE-DATE-STAMP-FORMAT*'s format."
  (local-time:format-timestring nil (local-time:now) :format *log-file-date-stamp-format*))



; GLOBAL VARIABLES
(defparameter *num-cores* 8
  "Number of CPU cores on machine (used for the number of threads to spawn).")

(defparameter *log-file-date-stamp-format*
  '(:year #\- :month #\- :day #\space :hour #\: :min #\: :sec " " :timezone)
  "The date format to be used when writing compute times to files.")

(defparameter *letters*
  "abcdefghijklmnopqrstuvwxyz"
  "Every lowercase letter in the latin alphabet.")

(defparameter *num-characters* 5 "The number of letters in a guess.")

(defparameter *abc*
  (let (abc)
    (dotimes (i *num-characters*)
      (push *letters* abc))
    abc)
  "A list with all letters in the latin alphabet, one for each character in
  the input guess.")

(defparameter *colors*
  (let ((tbl (make-hash-table)))
    (setf (gethash :green tbl) 0)
    (setf (gethash :yellow tbl) 1)
    (setf (gethash :grey tbl) 2)
    tbl)
  "Stores encoding for the game's guess feedback (green, yellow, or grey).")

(defparameter *color-combos*
  ;;; a challenge that remains is to rewrite this as a macro to generate this code
  ;;; rather than having all the loops written out in this manner.
  ;;; this macro will require tools like gensym and will,
  ;;; perhaps, require you to build up a list?  Regardless, the loop variable meme names
  ;;; will have to suffice for now.
  (let (lst (colors (get-hash-keys *colors*)))
    (dolist (i colors)
      (dolist (ii colors)
        (dolist (iii colors)
          (dolist (iv colors)
            (dolist (v colors)
              (push (vector
                      (gethash i *colors*)
                      (gethash ii *colors*)
                      (gethash iii *colors*)
                      (gethash iv *colors*)
                      (gethash v *colors*))
                    lst))))))
    (reverse lst))
  "Every possible color combination in: (expt (hash-table-count *COLORS*) *NUM-CHARACTERS*).")

;; I would like to simplify the definition of this variable...it can definitely be made simpler.
(defparameter *words*
  (let* ((acceptable-answers (file-read-lines "data/wordle_list.txt"))
         ;; making the initial size bigger would reduce collisions...but how much bigger should it be?
         (tbl (make-hash-table :size (length acceptable-answers) :test #'equal))
         ;; filter down to only those words in the acceptable answers file
         ;; (the length-checking is to ensure there aren't false/duplicate matches)
         (unigrams (fast-intersection
                     acceptable-answers
                     (delete-if-not #'(lambda (str) (eql (position #\, str) *num-characters*))
                      (file-read-lines "data/unigram_freq.csv"))))
         ;; we will assume terms that are distinct to the acceptable answers file to have a frequency of zero
         (unused-terms (set-difference
                         acceptable-answers
                         unigrams
                         :test #'(lambda (s1 s2) (string= s1 s2 :end2 *num-characters*)))))
    ;; assign the frequency for each word
    (dolist (unigram unigrams)
      (let ((word      (subseq unigram 0 *num-characters*))
            (frequency (parse-integer (subseq unigram (1+ *num-characters*)))))
        (setf (gethash word tbl) frequency)))
    (dolist (unused-term unused-terms)
      (setf (gethash unused-term tbl) 0))
    tbl)
  "A hash table whose keys are words *NUM-CHARACTERS* in length and whose values
  are their frequency of use in literature or however Google (I think it was Google)
  defines it.")



; FUNCTIONS FOR THE MAIN PROGRAM
;; this function can definitely be optimized or at least be made clearer.
;; One place to fix up would be to see if you
;; can do tests with objects other than strings. Further, :grey is never used in the *colors*
;; object, so you could perhaps remove it from the hash table. Would a plist be more efficient
;; in that case? Well, if there are really only two values, what's the point of a helper object?
;; I think the purpose of a lookup table is readability.
(defun build-regex (guess combo remaining-letters)
  "Builds a regular expression to subset the word list to possible remaining words.
  NOTE: this function edits remaining-letters in-place."
  (let (yellow-letters greys nongreys)
    (dotimes (i *NUM-CHARACTERS*)
      (let ((current-letter (string (aref guess i)))
            (current-combo-val (aref combo i)))
        (cond
          ;; green letters are set
          ((equal current-combo-val (gethash :green *colors*))
           (push current-letter nongreys)
           (setf (elt remaining-letters i) current-letter))
          ;; yellow letters are removed from the index at which they are found
          ((equal current-combo-val (gethash :yellow *colors*))
           (push current-letter nongreys)
           (push current-letter yellow-letters)
           (setf (elt remaining-letters i) (delete current-letter (elt remaining-letters i) :test #'string=)))
          ;; grey letters are removed from each index
          (t
           (push current-letter greys)
           (dotimes (j *num-characters*)
             (setf (elt remaining-letters j) (delete current-letter (elt remaining-letters j) :test #'string=)))))))
    (when (intersection greys nongreys :test #'string=)
      (error "Letters cannot be both grey and nongrey!"))
    (let (rgx-components)
      (dotimes (i *num-characters*)
        (when (= (length (elt remaining-letters i)) 0)
          (error "Out of letters available for regex!"))
        (push (concatenate 'string "[" (elt remaining-letters i) "]") rgx-components))
      (values (cl-ppcre:create-scanner (format nil "~{~a~}" (nreverse rgx-components)))
              (nreverse yellow-letters)))))

(defun guess-filter (guess combo remaining-words remaining-letters)
  "Take the user's guess and filter down to the remaining possible words based
  on the input and color combo for that input."
  (let ((subset (make-hash-table :test (hash-table-test remaining-words)))
        rgx
        yellow-letters)
    ;; you could just carry the multiple-value-bind values through the rest of the
    ;; function rather than doing the 'initialize in the let statement and then assign
    ;; them values from the multiple-value-bind' approach done here since
    ;; the subset object already has a default value. this function is getting
    ;; a bit too nested and complex, so a flattening out is welcome.
    (handler-case
        (multiple-value-bind
            (build-regex-rgx build-regex-yellow-letters)
            (build-regex guess combo remaining-letters)
          (setf rgx build-regex-rgx yellow-letters build-regex-yellow-letters))
      (error ()
        (return-from guess-filter subset)))
    (dolist (word (get-hash-keys remaining-words))
      (when (cl-ppcre:scan rgx word)
        (if yellow-letters
          ;; ensure results contain each of the yellow letters when yellow was in the combo
          (progn
            (let ((all-yellow-letters-found t))
              (dolist (yellow-letter yellow-letters)
                (setf
                  all-yellow-letters-found
                  (and all-yellow-letters-found
                       (search yellow-letter word))))
              (when all-yellow-letters-found
                (setf (gethash word subset) (gethash word remaining-words)))))
          (setf (gethash word subset) (gethash word remaining-words)))))
    subset))

;; it might make more sense to use an flet instead of a top-level function.
;; that would make it more difficult to test, so I think that using
;; this top-level function is the right approach.
(defun calculate-scores-internal
    (guesses
      remaining-words
      remaining-letters
      &optional
      (frequency-total (sum-hash-values remaining-words))
      (output-hash-table-size (length guesses)))
  "The multi-threaded part of calculate-scores."
  (let ((information (make-hash-table :test (hash-table-test remaining-words) :size output-hash-table-size)))
    (with-open-file ;; a log file to track progress in a thread-safe manner
        (thread-out-stream
          (generate-log-file-name)
          :direction :output
          :if-exists :supersede)
      (dolist (guess guesses)
        (let (
              (start-time (get-formatted-time))
              end-time
              remaining-words-by-combo
              (expected-information 0.0)
              )
          (dotimes (i (length *COLOR-COMBOS*)) ;; find word frequencies associated with each combo for the input guess
            (let ((filtered (guess-filter guess (elt *color-combos* i) remaining-words (mapcar #'copy-seq remaining-letters))))
              (when (> (hash-table-count filtered) 0)
                (push filtered remaining-words-by-combo))))
          ;; calculate expected bits of information gained
          (dolist (combo-words remaining-words-by-combo)
            (let* (
                   (combo-freq (sum-hash-values combo-words))
                   (proportion-of-words-remaining-for-this-combo (/ combo-freq frequency-total))
                   (entropy 0.0)
                   )
              (when (> proportion-of-words-remaining-for-this-combo 0.0)
                (setf entropy (log (/ 1.0 proportion-of-words-remaining-for-this-combo) 2)))
              (incf expected-information (* proportion-of-words-remaining-for-this-combo entropy))))
          (setf (gethash guess information) expected-information)
          (setf end-time (get-formatted-time)) ;; log the guess' compute time
            (format thread-out-stream
                    "word: ~a~astart: ~a~aend: ~a~%"
                    guess #\tab start-time #\tab end-time))))
    information))

(defun calculate-scores (remaining-words remaining-letters)
  "Calculate the bits of information gained for each guess after checking it
  against each color combination."
  (let* (
         (freq-total (sum-hash-values remaining-words))
         (words (get-hash-keys remaining-words))
         (num-words (length words))
         (num-words-per-process (ceiling (/ num-words *num-cores*)))
         (start 0)
         threads
         (full-output (copy-hash-table remaining-words)) ;; all values from remaining-words will be overwritten
         (log-file "log/progress_lisp.txt")
         )
    ;; spawn threads to do score calculation
    ;; (remember that you'll need to store the loop variable in a let
    ;; statement if you need to access it from within one of the spawned
    ;; threads).
    (dotimes (i *num-cores*)
      (let ( ;; a lovely algorithm to partition the words out to different threads
            (start-bound start)
            (end-bound (+ start num-words-per-process))
            )
        (when (> (+ start num-words-per-process) num-words)
          (setf end-bound num-words)) ;; remain in bounds
        (incf start num-words-per-process)
        (push (bordeaux-threads:make-thread
                #'(lambda ()
                    (calculate-scores-internal
                     (subseq words start-bound end-bound) ;; the words for which this thread is responsible for computing scores
                     remaining-words
                     remaining-letters
                     freq-total
                     (+ num-words-per-process)))
                :name (format nil "thread:~a" i))
              threads)))
    (with-open-file
        (out-stream
          log-file
          :direction :output
          :if-exists :supersede)
      (dolist (thread threads)
        (let ((thread-log-file (generate-log-file-name thread)))
          ;; collect results
          (maphash
            #'(lambda (k v) (setf (gethash k full-output) v))
            (bordeaux-threads:join-thread thread))
          ;; combine logs into a single file
          (dolist (line (file-read-lines thread-log-file))
            (format out-stream "~a~%" line))
          (delete-file thread-log-file))))
    full-output))



; EXECUTION
(let ((scores (calculate-scores *words* *abc*)))
  (with-open-file
      (out-stream
        "data/opening_word_scores.tsv"
        :direction :output
        :if-exists :supersede)
    (format out-stream "word~aexpected_entropy~afrequency~%" #\tab #\tab)
    (maphash
      #'(lambda
            (word score)
          (format out-stream "~a~a~a~a~a~%"
           word #\tab score #\tab (gethash word *words*)))
      scores)))
