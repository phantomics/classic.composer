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
    :type classic-persistence-strategy
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
    :documentation "The resolved classic-theme entity, or NIL if no
theme is active. Set during context construction from :theme-uri,
:theme, or the publication's ui-theme slot.")
   (capabilities
    :accessor context-capabilities
    :initarg :capabilities
    :initform nil
    :type list
    :documentation "List of capability objects currently active for
this composition. Populated from the resolved theme's capability set
matched against the global capability registry.")
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
Collectors append data here; anchor handlers read from it.")

   ;; ---- Resolved theme state ----
   (theme-chain
    :accessor context-theme-chain
    :initform nil
    :documentation "List of classic-theme instances from child to root,
as returned by resolve-theme-chain. Populated during context construction.")
   (theme-capabilities
    :accessor context-theme-capabilities
    :initform nil
    :documentation "Merged capability identifier strings after exclusion
resolution. The activation set for this composition.")
   (theme-overrides
    :accessor context-theme-overrides
    :initform nil
    :documentation "Alist of (tier-keyword . override-instance) pairs
from resolve-theme-overrides.")
   (theme-config
    :accessor context-theme-config
    :initform nil
    :documentation "Merged scalar configuration bindings from
resolve-theme-bindings. Alist of (key . value) pairs.")
   (theme-slot-fills
    :accessor context-theme-slot-fills
    :initform nil
    :documentation "Merged slot-fills from resolve-theme-slot-fills.
Alist of (slot-name . lexis-subtree) pairs.")
   (theme-lenses
    :accessor context-theme-lenses
    :initform nil
    :documentation "Resolved lens alist of ((class . purpose) . lens-spec)
entries from resolve-theme-lenses.")
   (theme-assets
    :accessor context-theme-assets
    :initform nil
    :documentation "Flat list of asset references gathered from the
theme chain, each with its base URI."))
  (:documentation
   "Carries all state for a single composition pass. Created per-request,
threaded through all tier composition functions, and discarded after
producing the output Lexis tree."))

;;; ============================================================
;;; Constructor
;;; ============================================================

(defun make-context (&key strategy publication entity theme theme-uri
                          capabilities bindings)
  "Create a composition context. STRATEGY is required (the persistence
backend to query).

Theme resolution priority:
  1. THEME-URI (explicit URI string) -- wins if provided
  2. THEME (a classic-theme entity) -- used directly
  3. Publication's ui-theme slot -- automatic from publication
  4. NIL -- no theme active

When a theme is resolved, all theme state (chain, capabilities,
overrides, config, slot-fills, lenses, assets) is populated eagerly."
  (check-type strategy classic-persistence-strategy)
  (let ((ctx (make-instance 'composition-context
                            :strategy strategy
                            :publication publication
                            :entity entity
                            :capabilities (or capabilities nil)
                            :bindings (or bindings nil))))
    ;; Resolve theme
    (let ((resolved-theme
            (cond
              ;; Explicit URI wins
              (theme-uri
               (retrieve-entity strategy theme-uri nil))
              ;; Explicit entity
              (theme theme)
              ;; From publication
              ((and publication
                    (slot-boundp publication
                                 'classic.schema:ui-theme)
                    (classic.schema:ui-theme publication))
               (retrieve-entity strategy
                                (classic.schema:ui-theme publication)
                                nil))
              (t nil))))
      (when resolved-theme
        (setf (context-theme ctx) resolved-theme)
        (resolve-theme-for-context ctx)))
    ctx))

;;; ============================================================
;;; Context query helpers
;;; ============================================================

(defun context-retrieve (context uri &optional class)
  "Retrieve an entity from the persistence layer via the context.
Convenience wrapper around retrieve-entity."
  (retrieve-entity (context-strategy context) uri class))

(defun context-query (context predicate object &rest args)
  "Query relationships via the context. Returns a list of subject URIs.
Convenience wrapper around query-relation."
  (apply #'query-relation (context-strategy context)
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
              (classic.schema:label (context-publication ctx)))
            (when (context-entity ctx)
              (classic.schema:label (context-entity ctx)))
            (length (context-bindings ctx))
            (hash-table-count (context-collections ctx)))))
