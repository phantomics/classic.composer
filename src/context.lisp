;;;; context.lisp — Composition context
;;;;
;;;; The composition context carries all state needed during a single
;;;; composition pass: the persistence strategy to query, the publication
;;;; being composed, the entity being rendered, theme configuration,
;;;; and the set of loaded capabilities.
;;;;
;;;; The context is threaded through all composition operations. It is
;;;; created per-request (or per-composition job in a rendering cluster)
;;;; and discarded after the composed Lexis tree is produced.

(in-package #:classic.composer)

;;; ============================================================
;;; Composition context class
;;; ============================================================

(defclass composition-context ()
  ((strategy
    :accessor context-strategy
    :initarg :strategy
    :type classic:classic-persistence-strategy
    :documentation "The persistence strategy to query for entities
and relationships. The composer is read-only through this interface.")
   (publication
    :accessor context-publication
    :initarg :publication
    :initform nil
    :documentation "The classic-publication instance being composed.
Provides access to publication-level configuration: theme, URI base,
container structure.")
   (entity
    :accessor context-entity
    :initarg :entity
    :initform nil
    :documentation "The primary entity being composed (e.g., a
classic-article for a single-post page, or a classic-container for
an index page). May be NIL for pages that are not entity-centric.")
   (theme
    :accessor context-theme
    :initarg :theme
    :initform nil
    :documentation "Theme configuration object. Determines which frame
template is used, which capabilities are active, and provides
per-medium styling references.")
   (capabilities
    :accessor context-capabilities
    :initarg :capabilities
    :initform nil
    :type list
    :documentation "List of capability objects currently active for
this composition. Populated from loaded capability extensions and
theme configuration.")
   (bindings
    :accessor context-bindings
    :initarg :bindings
    :initform nil
    :type list
    :documentation "Alist of named values available for template slot
resolution. Keys are strings (slot names), values are Lexis subtrees
or strings.")
   (collections
    :accessor context-collections
    :initform (make-hash-table :test 'equal)
    :documentation "Hash table of named collections accumulated during
the collect phase. Keys are collection names (strings), values are
lists of collected items (newest first, reversed after collection).
Collectors append data here; anchor handlers read from it."))
  (:documentation
   "Carries all state for a single composition pass. Created per-request,
threaded through all tier composition functions, and discarded after
producing the output Lexis tree."))

;;; ============================================================
;;; Constructor
;;; ============================================================

(defun make-context (&key strategy publication entity theme
                          capabilities bindings)
  "Create a composition context. STRATEGY is required (the persistence
backend to query). Other arguments configure the composition pass."
  (check-type strategy classic:classic-persistence-strategy)
  (make-instance 'composition-context
                 :strategy strategy
                 :publication publication
                 :entity entity
                 :theme theme
                 :capabilities (or capabilities nil)
                 :bindings (or bindings nil)))

;;; ============================================================
;;; Context query helpers
;;; ============================================================

(defun context-retrieve (context uri &optional class)
  "Retrieve an entity from the persistence layer via the context.
Convenience wrapper around classic:retrieve-entity."
  (classic:retrieve-entity (context-strategy context) uri class))

(defun context-query (context predicate object &rest args)
  "Query relationships via the context. Returns a list of subject URIs.
Convenience wrapper around classic:query-relation."
  (apply #'classic:query-relation (context-strategy context)
         predicate object args))

(defun context-bind (context name value)
  "Add a named binding to the context for template slot resolution.
NAME is a string. VALUE is a Lexis subtree or string. Returns CONTEXT
(mutates in place for convenience during composition setup)."
  (push (cons name value) (context-bindings context))
  context)

(defun context-binding (context name)
  "Look up a named binding by NAME (string). Returns the bound value
or NIL if no binding exists."
  (cdr (assoc name (context-bindings context) :test #'equal)))

;;; ============================================================
;;; Collection helpers (for the collect phase)
;;; ============================================================

(defun collect-into (context collection-name item)
  "Append ITEM to the named collection in CONTEXT.
COLLECTION-NAME is a string. Items are accumulated in push order
(newest first) during the collect phase; call CONTEXT-COLLECTED to
retrieve them in document order (reversed)."
  (push item (gethash collection-name (context-collections context)))
  item)

(defun context-collected (context collection-name)
  "Retrieve all items in the named collection, in document order.
Returns a list of items accumulated by collectors during the collect
phase, or NIL if the collection is empty or doesn't exist."
  (reverse (gethash collection-name (context-collections context))))

(defun context-collected-raw (context collection-name)
  "Retrieve all items in the named collection in accumulation order
(newest first). Useful when document order is not needed."
  (gethash collection-name (context-collections context)))

;;; ============================================================
;;; Print
;;; ============================================================

(defmethod print-object ((ctx composition-context) stream)
  (print-unreadable-object (ctx stream :type t)
    (format stream "~@[pub:~A ~]~@[entity:~A ~](~D bindings, ~D collections)"
            (when (context-publication ctx)
              (classic:label (context-publication ctx)))
            (when (context-entity ctx)
              (classic:label (context-entity ctx)))
            (length (context-bindings ctx))
            (hash-table-count (context-collections ctx)))))
