;;;; test-capability.lisp — Tests for capability registration and dispatch

(in-package #:classic.composer-tests)

(in-suite capability)

;;; ============================================================
;;; Registration
;;; ============================================================

(def-test capability-register-and-find ()
  "register-capability stores a capability; find-capability retrieves it."
  (with-fresh-registries
    (let ((cap (make-instance 'capability
                 :name "frame.hero"
                 :tier :frame
                 :handler (lambda (ctx node)
                            (declare (ignore ctx node))
                            nil))))
      (register-capability cap)
      (is (eq cap (find-capability "frame.hero")))
      (is (null (find-capability "nonexistent"))))))

(def-test define-capability-macro ()
  "define-capability registers a working capability."
  (with-fresh-registries
    (define-capability "test.cap"
        (:tier :feature :description "A test capability")
      (ctx node)
      (declare (ignore ctx node))
      '(paragraph "capability output"))
    (let ((cap (find-capability "test.cap")))
      (is (not (null cap)))
      (is (equal "test.cap" (capability-name cap)))
      (is (eq :feature (capability-tier cap))))))

(def-test list-capabilities-all ()
  "list-capabilities with no argument returns all registered."
  (with-fresh-registries
    (define-capability "a" (:tier :frame) (ctx node)
      (declare (ignore ctx node)) nil)
    (define-capability "b" (:tier :feature) (ctx node)
      (declare (ignore ctx node)) nil)
    (is (= 2 (length (list-capabilities))))))

(def-test list-capabilities-by-tier ()
  "list-capabilities with a tier argument filters correctly."
  (with-fresh-registries
    (define-capability "frame-cap" (:tier :frame) (ctx node)
      (declare (ignore ctx node)) nil)
    (define-capability "feature-cap" (:tier :feature) (ctx node)
      (declare (ignore ctx node)) nil)
    (is (= 1 (length (list-capabilities :frame))))
    (is (= 1 (length (list-capabilities :feature))))
    (is (= 0 (length (list-capabilities :adjunct))))))

;;; ============================================================
;;; Dispatch
;;; ============================================================

(def-test dispatch-capability-invokes-handler ()
  "dispatch-capability calls the matching capability's handler."
  (with-fresh-registries
    (with-clean-strategy ()
      (let ((ctx (make-minimal-context)))
        (define-capability "frame.test"
            (:tier :frame)
          (ctx node)
          (declare (ignore ctx))
          `(section (@ :class "from-capability")
             ,@(node-children node)))
        (let ((result (dispatch-capability ctx :frame
                        '(test-element "content"))))
          (is (not (null result)))
          (is (eq 'section (node-tag result))))))))

(def-test dispatch-capability-predicate-filtering ()
  "dispatch-capability respects the predicate: only matching nodes dispatch."
  (with-fresh-registries
    (with-clean-strategy ()
      (let ((ctx (make-minimal-context)))
        (define-capability "hero-only"
            (:tier :frame
             :predicate (lambda (ctx node)
                          (declare (ignore ctx))
                          (and (tagged-node-p node)
                               (string= "HERO" (symbol-name
                                                 (node-tag node))))))
          (ctx node)
          (declare (ignore ctx))
          `(figure (@ :class "hero") ,@(node-children node)))
        ;; Hero node matches
        (is (not (null (dispatch-capability ctx :frame
                         '(hero (image (@ :src "x.jpg")))))))
        ;; Non-hero node does not match
        (is (null (dispatch-capability ctx :frame
                    '(navigation "home"))))))))

(def-test dispatch-capability-nil-when-no-match ()
  "dispatch-capability returns NIL when no capability matches."
  (with-fresh-registries
    (with-clean-strategy ()
      (let ((ctx (make-minimal-context)))
        (is (null (dispatch-capability ctx :frame
                    '(test-node "content"))))))))
