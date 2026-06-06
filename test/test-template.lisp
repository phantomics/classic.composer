;;;; test-template.lisp — Tests for template slot detection and resolution

(in-package #:classic.composer-tests)

(in-suite template)

;;; ============================================================
;;; Slot detection
;;; ============================================================

(def-test template-slot-p-detects-slot ()
  "template-slot-p recognizes template.slot nodes by symbol-name."
  (is-true (template-slot-p
            `(,(intern "TEMPLATE.SLOT" :classic.composer)
              (@ :name "main-content"))))
  ;; Also works with symbols from other packages (symbol-name match)
  (is-true (template-slot-p
            (let ((sym (intern "TEMPLATE.SLOT" :keyword)))
              `(,sym (@ :name "test"))))))

(def-test template-slot-p-rejects-non-slots ()
  "template-slot-p returns NIL for non-slot nodes."
  (is-false (template-slot-p '(paragraph "text")))
  (is-false (template-slot-p '(section (@ :title "Hi"))))
  (is-false (template-slot-p "just a string")))

(def-test slot-name-extracts-name ()
  "slot-name returns the :name attribute from a template.slot node."
  (is (equal "main-content"
             (slot-name `(template.slot (@ :name "main-content"))))))

;;; ============================================================
;;; Slot resolution
;;; ============================================================

(def-test resolve-slots-substitutes-binding ()
  "resolve-slots replaces a template.slot with the bound value."
  (with-clean-strategy ()
    (let ((ctx (make-minimal-context)))
      (context-bind ctx "greeting" "Hello, world!")
      (let ((result (resolve-slots
                     '(document (template.slot (@ :name "greeting")))
                     ctx)))
        (is (equal '(document "Hello, world!") result))))))

(def-test resolve-slots-substitutes-subtree ()
  "resolve-slots can substitute a Lexis subtree."
  (with-clean-strategy ()
    (let ((ctx (make-minimal-context)))
      (context-bind ctx "content" '(paragraph "Body text."))
      (let ((result (resolve-slots
                     '(document (template.slot (@ :name "content")))
                     ctx)))
        (is (equal '(document (paragraph "Body text.")) result))))))

(def-test resolve-slots-removes-unresolved ()
  "resolve-slots removes unresolved slots by default."
  (with-clean-strategy ()
    (let ((ctx (make-minimal-context)))
      (let ((result (resolve-slots
                     '(document
                        (paragraph "keep")
                        (template.slot (@ :name "missing")))
                     ctx)))
        ;; Only the paragraph remains
        (is (= 1 (length (node-children result))))
        (is (equal "keep" (first (node-children
                                  (first (node-children result))))))))))

(def-test resolve-slots-preserves-unresolved-when-configured ()
  "resolve-slots keeps unresolved slots when remove-unresolved is NIL."
  (with-clean-strategy ()
    (let ((ctx (make-minimal-context)))
      (let ((result (resolve-slots
                     '(document (template.slot (@ :name "missing")))
                     ctx
                     :remove-unresolved nil)))
        ;; The template.slot remains
        (is (= 1 (length (node-children result))))
        (is-true (template-slot-p (first (node-children result))))))))

(def-test resolve-slots-in-attributes ()
  "resolve-slots substitutes slots that appear as attribute values."
  (with-clean-strategy ()
    (let ((ctx (make-minimal-context)))
      (context-bind ctx "page-title" "My Page")
      (let ((result (resolve-slots
                     '(document (@ :title (template.slot (@ :name "page-title"))))
                     ctx)))
        (is (equal "My Page" (get-attr result :title)))))))

;;; ============================================================
;;; Cross-package symbol-name detection
;;; ============================================================

(def-test template-slot-works-across-packages ()
  "template.slot nodes are detected regardless of what package the
symbol is interned in, because detection uses symbol-name comparison."
  (let* ((foreign-sym (intern "TEMPLATE.SLOT" :cl-user))
         (node `(,foreign-sym (@ :name "test-slot"))))
    (is-true (template-slot-p node))
    (is (equal "test-slot" (slot-name node)))))
