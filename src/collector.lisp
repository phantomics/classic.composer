;;;; collector.lisp — Collect phase: metadata gathering before anchor evaluation
;;;;
;;;; The collect phase walks the resolved Lexis tree (after slot
;;;; resolution, before anchor evaluation) and gathers structural
;;;; metadata that anchor handlers may need. This implements the
;;;; Scribble-style "collect then render" pattern that avoids
;;;; cross-dependencies between anchors.
;;;;
;;;; Collectors are named functions registered globally. Each collector
;;;; inspects nodes during the tree walk and accumulates data into the
;;;; context's collections store. After the collect phase completes,
;;;; anchor handlers can read collected data via CONTEXT-COLLECTED.
;;;;
;;;; Performance: The collect phase is a single O(n) tree walk. All
;;;; registered collectors are called on each node (typically 5-10
;;;; collectors with cheap predicate checks). No recursion, no retry
;;;; loops, no dependency resolution.

(in-package #:classic.composer)

;;; ============================================================
;;; Collector registry
;;; ============================================================

(defvar *collectors* (make-hash-table :test 'equal)
  "Global registry: collector name (string) -> collector function.
Collector signature: (function context node) -> ignored.
Side effects: calls COLLECT-INTO to accumulate data.")

(defvar *collector-order* nil
  "List of collector names in registration order.
Determines the order collectors are called on each node.")

(defun register-collector (name function)
  "Register FUNCTION as a collector under NAME.
FUNCTION should accept (context node) and call COLLECT-INTO to
accumulate data. Its return value is ignored.
If a collector with NAME already exists, it is replaced."
  (unless (gethash name *collectors*)
    (push name *collector-order*))
  (setf (gethash name *collectors*) function)
  name)

(defun find-collector (name)
  "Look up the collector function for NAME. Returns the function or NIL."
  (gethash name *collectors*))

(defun list-collectors ()
  "Return a list of all registered collector names in registration order."
  (reverse *collector-order*))

;;; ============================================================
;;; Definition macro
;;; ============================================================

(defmacro define-collector (name (context-var node-var) &body body)
  "Define and register a collector.

NAME is a string identifying the collector (e.g., \"sections\").
CONTEXT-VAR is bound to the composition-context.
NODE-VAR is bound to each node visited during the collect walk.

The body should inspect NODE-VAR and conditionally call COLLECT-INTO
to accumulate data. The return value is ignored.

Example:
  (define-collector \"sections\" (context node)
    (when (and (tagged-node-p node)
               (string= \"SECTION\" (symbol-name (node-tag node))))
      (let ((title (get-attr node :title))
            (id (get-attr node :id)))
        (when title
          (collect-into context \"sections\"
                        (list :title title :id id :depth 1))))))"
  `(register-collector ,name
    (lambda (,context-var ,node-var)
      ,@body)))

;;; ============================================================
;;; Collect phase execution
;;; ============================================================

(defun run-collectors (tree context)
  "Walk TREE and invoke all registered collectors on each node.

This is the collect phase of the composition pipeline. It runs after
slot resolution and before anchor evaluation. Collectors accumulate
metadata into the context's collections store via COLLECT-INTO.

The walk visits nodes in document order (depth-first, pre-order).
Each node is passed to every registered collector. Collectors decide
internally whether to act on a given node (typically via a tag name
check).

Returns TREE unchanged (the collect phase is side-effect-only on
the context's collections)."
  (let ((collectors (mapcar #'find-collector (list-collectors))))
    (when collectors
      (collect-walk collectors tree context)))
  tree)

(defun collect-walk (collectors tree context)
  "Internal: recursively walk TREE, calling each collector on each node."
  (dolist (collector collectors)
    (funcall collector context tree))
  (when (tagged-node-p tree)
    (dolist (child (node-children tree))
      (collect-walk collectors child context)))
  nil)
