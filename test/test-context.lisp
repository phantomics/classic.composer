;;;; test-context.lisp — Tests for composition context

(in-package #:classic.composer-tests)

(in-suite context)

;;; ============================================================
;;; Construction
;;; ============================================================

(def-test context-requires-strategy ()
  "make-context signals an error when no strategy is provided."
  (signals type-error
    (make-context :strategy nil)))

(def-test context-minimal-construction ()
  "make-context with only a strategy succeeds."
  (with-clean-strategy ()
    (let ((ctx (make-minimal-context)))
      (is (typep ctx 'composition-context))
      (is (null (context-entity ctx)))
      (is (null (context-theme ctx))))))

(def-test context-with-entity ()
  "make-context stores the entity."
  (with-clean-strategy ()
    (let* ((article (make-test-article))
           (ctx (make-minimal-context :entity article)))
      (is (eq article (context-entity ctx))))))

;;; ============================================================
;;; Bindings
;;; ============================================================

(def-test context-bind-and-retrieve ()
  "context-bind stores a value, context-binding retrieves it."
  (with-clean-strategy ()
    (let ((ctx (make-minimal-context)))
      (context-bind ctx "title" "Hello World")
      (is (equal "Hello World" (context-binding ctx "title"))))))

(def-test context-binding-returns-nil-for-missing ()
  "context-binding returns NIL for unbound names."
  (with-clean-strategy ()
    (let ((ctx (make-minimal-context)))
      (is (null (context-binding ctx "nonexistent"))))))

(def-test context-bind-overwrites ()
  "context-bind with the same name shadows the earlier binding."
  (with-clean-strategy ()
    (let ((ctx (make-minimal-context)))
      (context-bind ctx "key" "old")
      (context-bind ctx "key" "new")
      (is (equal "new" (context-binding ctx "key"))))))

;;; ============================================================
;;; Collections
;;; ============================================================

(def-test collect-into-and-context-collected ()
  "collect-into stores items; context-collected returns in document order."
  (with-clean-strategy ()
    (let ((ctx (make-minimal-context)))
      (collect-into ctx "sections" '(:title "A" :id "a"))
      (collect-into ctx "sections" '(:title "B" :id "b"))
      (let ((result (context-collected ctx "sections")))
        (is (= 2 (length result)))
        ;; Document order: A first, B second
        (is (equal "A" (getf (first result) :title)))
        (is (equal "B" (getf (second result) :title)))))))

(def-test context-collected-empty ()
  "context-collected returns NIL for nonexistent collection."
  (with-clean-strategy ()
    (let ((ctx (make-minimal-context)))
      (is (null (context-collected ctx "nonexistent"))))))

;;; ============================================================
;;; Theme resolution priority
;;; ============================================================

(def-test context-theme-from-explicit-uri ()
  "Explicit :theme-uri takes highest priority."
  (with-clean-strategy ()
    (let* ((theme (make-test-theme :name "Explicit Theme"))
           (ctx (make-context :strategy *test-strategy*
                              :theme-uri (uri-string theme))))
      (is (not (null (context-theme ctx))))
      (is (equal "Explicit Theme"
                 (classic.schema:label (context-theme ctx)))))))

(def-test context-theme-from-publication ()
  "Publication's ui-theme is used when no explicit theme is provided."
  (with-clean-strategy ()
    (let* ((theme (make-test-theme :name "Pub Theme"))
           (pub (make-test-publication :theme-uri (uri-string theme))))
      (let ((ctx (make-context :strategy *test-strategy*
                               :publication pub)))
        (is (not (null (context-theme ctx))))
        (is (equal "Pub Theme"
                   (classic.schema:label (context-theme ctx))))))))

(def-test context-no-theme ()
  "Context without any theme source has NIL theme."
  (with-clean-strategy ()
    (let ((ctx (make-minimal-context)))
      (is (null (context-theme ctx)))
      (is (null (context-theme-chain ctx))))))
