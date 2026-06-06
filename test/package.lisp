;;;; package.lisp — Test package for Classic Composer
;;;;
;;;; Uses FiveAM for test definition/running and cl-hamcrest for
;;;; composable assertions. Mirrors Classic core's test conventions.

(defpackage #:classic.composer-tests
  (:use #:cl #:classic #:classic.composer #:classic.dist.alpha)
  ;; Import FiveAM symbols explicitly
  (:import-from #:fiveam
                #:def-suite #:in-suite #:def-test #:test
                #:is #:is-true #:is-false #:signals #:finishes
                #:explain! #:results-status)
  (:import-from #:hamcrest/fiveam
                #:assert-that)
  (:import-from #:hamcrest/matchers
                #:has-all
                #:has-plist-entries
                #:has-alist-entries
                #:has-hash-entries
                #:has-slots
                #:has-type
                #:instance-of
                #:has-length
                #:contains-in-any-order
                #:any
                #:_)
  ;; Shadow symbols that conflict between classic.schema.alpha and cl
  (:shadow #:label #:description #:body)
  (:shadowing-import-from #:classic.composer #:document)
  (:export
   #:run-all-tests
   #:run-suite))
