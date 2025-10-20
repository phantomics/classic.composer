;;; compass.sexp — Compass project manifest
;;;
;;; Written by compass init. Read with a restricted reader: strings, integers,
;;; keywords, and lists only. Other keys, such as :commands, may be added by
;;; hand (Compass §5, §22).

(:namespaces ("CCOMPOSER")
 :doc-directory "doc/"
 :federation ((:namespace "CLASSIC" :path "../classic")
              (:namespace "LEXIS" :path "../lexis"))
 :commands ((:name :test
             :repl "(progn (ql:quickload \"classic.composer/tests\") (classic.composer-tests::run-all-tests))"
             :doc "Run the Classic Composer test suite"))
 :stewards ((:namespace "CCOMPOSER" :steward "Andrew Sengul" :approval :solo)))
