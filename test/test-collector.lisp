;;;; test-collector.lisp — Tests for collector registry and collect phase

(in-package #:classic.composer-tests)

(in-suite collector)

;;; ============================================================
;;; Registry
;;; ============================================================

(def-test collector-register-and-find ()
  "Registering a collector makes it findable by name."
  (with-fresh-registries
    (register-collector "test-collector"
      (lambda (ctx node)
        (declare (ignore ctx node))))
    (is (functionp (find-collector "test-collector")))
    (is (null (find-collector "nonexistent")))))

(def-test define-collector-macro ()
  "define-collector registers a callable collector."
  (with-fresh-registries
    (define-collector "macro-test" (ctx node)
      (declare (ignore ctx node)))
    (is (functionp (find-collector "macro-test")))))

(def-test list-collectors-preserves-order ()
  "list-collectors returns names in registration order."
  (with-fresh-registries
    (define-collector "first" (ctx node) (declare (ignore ctx node)))
    (define-collector "second" (ctx node) (declare (ignore ctx node)))
    (let ((names (list-collectors)))
      (is (= 2 (length names)))
      (is (equal "first" (first names)))
      (is (equal "second" (second names))))))

;;; ============================================================
;;; Collect phase execution
;;; ============================================================

(def-test run-collectors-visits-all-nodes ()
  "run-collectors walks the tree and invokes collectors in document order."
  (with-fresh-registries
    (with-clean-strategy ()
      (let ((ctx (make-minimal-context)))
        (define-collector "sections" (ctx node)
          (when (and (tagged-node-p node)
                     (string= "SECTION" (symbol-name (node-tag node))))
            (collect-into ctx "sections" (get-attr node :title))))
        (run-collectors
         '(document
            (section (@ :title "First")
              (paragraph "text"))
            (section (@ :title "Second")
              (paragraph "more")))
         ctx)
        (let ((result (context-collected ctx "sections")))
          (is (= 2 (length result)))
          ;; Document order
          (is (equal "First" (first result)))
          (is (equal "Second" (second result))))))))

(def-test run-collectors-multiple-collectors ()
  "Multiple collectors compose: each sees every node independently."
  (with-fresh-registries
    (with-clean-strategy ()
      (let ((ctx (make-minimal-context)))
        (define-collector "sections" (ctx node)
          (when (and (tagged-node-p node)
                     (string= "SECTION" (symbol-name (node-tag node))))
            (collect-into ctx "sections" (get-attr node :title))))
        (define-collector "paragraphs" (ctx node)
          (when (and (tagged-node-p node)
                     (string= "PARAGRAPH" (symbol-name (node-tag node))))
            (collect-into ctx "paragraphs" t)))
        (run-collectors
         '(document
            (section (@ :title "S1")
              (paragraph "p1")
              (paragraph "p2"))
            (section (@ :title "S2")))
         ctx)
        (is (= 2 (length (context-collected ctx "sections"))))
        (is (= 2 (length (context-collected ctx "paragraphs"))))))))

(def-test run-collectors-returns-tree-unchanged ()
  "run-collectors returns the original tree (side-effect only on context)."
  (with-fresh-registries
    (with-clean-strategy ()
      (let ((ctx (make-minimal-context))
            (tree '(document (paragraph "hello"))))
        (define-collector "noop" (ctx node) (declare (ignore ctx node)))
        (let ((result (run-collectors tree ctx)))
          (is (eq tree result)))))))
