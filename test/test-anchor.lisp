;;;; test-anchor.lisp — Tests for anchor handler registry and evaluation

(in-package #:classic.composer-tests)

(in-suite anchor)

;;; ============================================================
;;; Registry
;;; ============================================================

(def-test anchor-handler-register-and-find ()
  "Registering an anchor handler makes it findable by name."
  (with-fresh-registries
    (register-anchor-handler "test-anchor"
      (lambda (ctx entity params)
        (declare (ignore ctx entity params))
        '(paragraph "result")))
    (is (functionp (find-anchor-handler "test-anchor")))
    (is (null (find-anchor-handler "nonexistent")))))

(def-test define-anchor-handler-macro ()
  "define-anchor-handler registers a callable handler."
  (with-fresh-registries
    (define-anchor-handler "macro-test" (ctx entity params)
      (declare (ignore ctx entity))
      `(paragraph ,(getf params :message "default")))
    (is (functionp (find-anchor-handler "macro-test")))))

;;; ============================================================
;;; Detection
;;; ============================================================

(def-test anchor-p-detects-anchors ()
  "anchor-p recognizes compose.anchor nodes by symbol-name."
  (is-true (anchor-p '(compose.anchor (@ :name "test"))))
  (is-false (anchor-p '(paragraph "text")))
  (is-false (anchor-p "not a node")))

(def-test anchor-p-works-across-packages ()
  "compose.anchor nodes are detected regardless of interning package."
  (let ((foreign-sym (intern "COMPOSE.ANCHOR" :cl-user)))
    (is-true (anchor-p `(,foreign-sym (@ :name "foreign-test"))))))

(def-test anchor-params-excludes-name ()
  "anchor-params returns the parameter plist without :name."
  (let ((node '(compose.anchor (@ :name "test" :limit 5 :fallback nil))))
    (let ((params (anchor-params node)))
      (is (= 5 (getf params :limit)))
      (is (null (getf params :name))))))

;;; ============================================================
;;; Evaluation
;;; ============================================================

(def-test evaluate-anchor-calls-handler ()
  "evaluate-anchor invokes the registered handler with context, entity, params."
  (with-fresh-registries
    (with-clean-strategy ()
      (let* ((article (make-test-article))
             (ctx (make-minimal-context :entity article))
             (called-with nil))
        (define-anchor-handler "spy" (ctx entity params)
          (setf called-with (list ctx entity params))
          '(paragraph "spy-result"))
        (let ((result (evaluate-anchor
                       '(compose.anchor (@ :name "spy" :limit 3))
                       ctx)))
          (is (equal '(paragraph "spy-result") result))
          (is (not (null called-with)))
          (is (= 3 (getf (third called-with) :limit))))))))

(def-test evaluate-anchors-walks-tree ()
  "evaluate-anchors replaces anchor nodes in a tree."
  (with-fresh-registries
    (with-clean-strategy ()
      (let ((ctx (make-minimal-context)))
        (define-anchor-handler "greet" (ctx entity params)
          (declare (ignore ctx entity params))
          '(paragraph "Hello!"))
        (let ((result (evaluate-anchors
                       '(document
                          (section (@ :title "Test")
                            (compose.anchor (@ :name "greet"))))
                       ctx)))
          ;; The anchor should be replaced with the paragraph
          (let* ((section (first (node-children result)))
                 (child (first (node-children section))))
            (is (equal '(paragraph "Hello!") child))))))))

(def-test evaluate-anchor-nil-removes-node ()
  "An anchor handler returning NIL removes the anchor from the tree."
  (with-fresh-registries
    (with-clean-strategy ()
      (let ((ctx (make-minimal-context)))
        (define-anchor-handler "empty" (ctx entity params)
          (declare (ignore ctx entity params))
          nil)
        (let ((result (evaluate-anchors
                       '(document
                          (paragraph "keep")
                          (compose.anchor (@ :name "empty")))
                       ctx)))
          (is (= 1 (length (node-children result)))))))))
