;;;; capability.lisp — Capability registration mechanism
;;;;
;;;; Capabilities are additive extensions to the composer. Each capability
;;;; registers itself with the base system, declaring which tier it extends
;;;; and what content patterns it handles. The composer dispatches to
;;;; registered capabilities when it encounters matching content.
;;;;
;;;; There are no mutually exclusive alternatives -- capabilities compose
;;;; without conflict because they augment different aspects of the
;;;; composition process. A publication loads whichever capabilities it
;;;; needs, and content that doesn't match any loaded capability passes
;;;; through the base rendering unchanged.

(in-package #:classic.composer)

;;; ============================================================
;;; Capability class
;;; ============================================================

(defclass capability ()
  ((name
    :accessor capability-name
    :initarg :name
    :type string
    :documentation "Unique name identifying this capability.
Example: \"frame.hero\", \"aggregate.tabular\".")
   (tier
    :accessor capability-tier
    :initarg :tier
    :type keyword
    :documentation "Which tier this capability extends.
One of :FRAME, :FEATURE, :ADJUNCT, :AGGREGATE, :OPERATIVE.")
   (description
    :accessor capability-description
    :initarg :description
    :initform ""
    :type string
    :documentation "Human-readable description of what this capability adds.")
   (handler
    :accessor capability-handler
    :initarg :handler
    :type (or function symbol)
    :documentation "Function called when this capability is invoked.
Signature: (handler context node) => Lexis subtree or NIL.
CONTEXT is the composition-context. NODE is the Lexis node that
triggered dispatch to this capability.")
   (predicate
    :accessor capability-predicate
    :initarg :predicate
    :initform nil
    :documentation "Optional predicate function for fine-grained matching.
Signature: (predicate context node) => boolean.
When non-NIL, the capability only handles nodes for which this
returns T. When NIL, the capability handles all nodes dispatched
to its tier."))
  (:documentation
   "A registered composer capability. Extensions create capability
instances and register them with the global registry. The composer
dispatches to matching capabilities during composition."))

(defmethod print-object ((cap capability) stream)
  (print-unreadable-object (cap stream :type t)
    (format stream "~A (~A)" (capability-name cap) (capability-tier cap))))

;;; ============================================================
;;; Global registry
;;; ============================================================

(defvar *capabilities* (make-hash-table :test 'equal)
  "Global registry: capability name (string) -> capability instance.")

(defvar *tier-capabilities* (make-hash-table :test 'eq)
  "Per-tier index: tier keyword -> list of capability instances.
Used for fast dispatch during composition.")

(defun register-capability (capability)
  "Register a capability instance with the global registry.
If a capability with the same name already exists, it is replaced."
  (let ((name (capability-name capability))
        (tier (capability-tier capability)))
    ;; Remove from tier list if replacing
    (let ((existing (gethash name *capabilities*)))
      (when existing
        (let ((old-tier (capability-tier existing)))
          (setf (gethash old-tier *tier-capabilities*)
                (remove existing (gethash old-tier *tier-capabilities*))))))
    ;; Register
    (setf (gethash name *capabilities*) capability)
    (push capability (gethash tier *tier-capabilities*))
    capability))

(defun find-capability (name)
  "Look up a capability by name. Returns the capability or NIL."
  (gethash name *capabilities*))

(defun list-capabilities (&optional tier)
  "List all registered capabilities. If TIER is provided (a keyword),
list only capabilities for that tier."
  (if tier
      (copy-list (gethash tier *tier-capabilities*))
      (loop for cap being the hash-values of *capabilities*
            collect cap)))

(defun tier-capabilities (tier)
  "Return the list of capabilities registered for TIER (keyword)."
  (gethash tier *tier-capabilities*))

;;; ============================================================
;;; Capability dispatch
;;; ============================================================

(defun dispatch-capability (context tier node)
  "Find and invoke the first matching capability for TIER on NODE.
Returns the capability's output (a Lexis subtree), or NIL if no
capability matches.

Capabilities are tested in registration order. The first whose
predicate returns T (or which has no predicate) is invoked."
  (let ((caps (tier-capabilities tier)))
    (dolist (cap caps)
      (when (or (null (capability-predicate cap))
                (funcall (capability-predicate cap) context node))
        (let ((result (funcall (capability-handler cap) context node)))
          (when result
            (return-from dispatch-capability result))))))
  nil)

;;; ============================================================
;;; Definition macro
;;; ============================================================

(defmacro define-capability (name (&key tier description predicate)
                             (context-var node-var) &body body)
  "Define and register a composer capability.

NAME is a string identifying the capability (e.g., \"frame.hero\").
TIER is a keyword (:frame, :feature, :adjunct, :aggregate, :operative).
DESCRIPTION is an optional documentation string.
PREDICATE is an optional form evaluating to a predicate function.

The body receives CONTEXT-VAR (a composition-context) and NODE-VAR
(the Lexis node being processed), and should return a Lexis subtree
or NIL.

Example:
  (define-capability \"frame.hero\"
      (:tier :frame
       :description \"Adds hero image/banner support to frames\"
       :predicate (lambda (ctx node)
                    (declare (ignore ctx))
                    (eq 'hero-image (node-tag node))))
    (context node)
    (let ((src (get-attr node :src))
          (alt (get-attr node :alt \"\")))
      `(figure (@ :class \"hero\")
         (image (@ :src ,src :alt ,alt)))))"
  `(register-capability
    (make-instance 'capability
                   :name ,name
                   :tier ,tier
                   :description ,(or description "")
                   :handler (lambda (,context-var ,node-var)
                              ,@body)
                   :predicate ,predicate)))
