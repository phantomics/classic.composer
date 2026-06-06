;;;; anchor.lisp — Anchor registry and dispatch
;;;;
;;;; Anchors are named hooks in Lexis templates that the composer
;;;; evaluates to produce conditional, query-driven content. An anchor
;;;; carries a name and parameters; a registered CL handler function
;;;; determines what content (if any) to produce.
;;;;
;;;; Anchor nodes have the form:
;;;;   (compose.anchor (@ :name "handler-name" :param1 val1 ...))
;;;;
;;;; The handler receives the composition context, the entity being
;;;; composed, and a plist of the anchor's parameters. It returns a
;;;; Lexis subtree to splice in place of the anchor, or NIL to remove
;;;; the anchor from the output.
;;;;
;;;; This keeps query logic in CL where it belongs (full triplestore
;;;; access, CLOS dispatch, arbitrary computation) while keeping
;;;; templates declarative.

(in-package #:classic.composer)

;;; ============================================================
;;; Anchor detection
;;; ============================================================

(defun anchor-p (node)
  "Return T if NODE is a compose.anchor node."
  (and (tagged-node-p node)
       (string= "COMPOSE.ANCHOR" (symbol-name (node-tag node)))))

(defun anchor-name (node)
  "Extract the handler name (a string) from a compose.anchor node."
  (get-attr node :name))

(defun anchor-params (node)
  "Extract the parameter plist from a compose.anchor node.
Returns the full attribute plist with :name removed."
  (let ((attrs (node-attrs node)))
    (when attrs
      (if (keywordp (car attrs))
          ;; Remove :name from keyword plist
          (loop for (key val) on attrs by #'cddr
                unless (eq key :name)
                  collect key and collect val)
          ;; Alist form -- remove name entry
          (loop for pair in attrs
                unless (eq (car pair) :name)
                  collect pair)))))

;;; ============================================================
;;; Handler registry
;;; ============================================================

(defvar *anchor-handlers* (make-hash-table :test 'equal)
  "Global registry: handler name (string) -> handler function.
Handler signature: (function context entity params) -> Lexis subtree or NIL.")

(defun register-anchor-handler (name function)
  "Register FUNCTION as the handler for anchors named NAME.
FUNCTION should accept (context entity params) and return a Lexis
subtree or NIL."
  (setf (gethash name *anchor-handlers*) function)
  name)

(defun find-anchor-handler (name)
  "Look up the handler function for anchor NAME. Returns the function or NIL."
  (gethash name *anchor-handlers*))

;;; ============================================================
;;; Definition macro
;;; ============================================================

(defmacro define-anchor-handler (name (context-var entity-var params-var)
                                 &body body)
  "Define and register an anchor handler.

NAME is a string identifying the anchor (e.g., \"related-by-tags\").
CONTEXT-VAR is bound to the composition-context.
ENTITY-VAR is bound to the primary entity being composed.
PARAMS-VAR is bound to the anchor's parameter plist (attributes
minus :name).

The body should return a Lexis subtree to splice in place of the
anchor, or NIL to remove the anchor entirely.

Example:
  (define-anchor-handler \"related-by-tags\" (ctx entity params)
    (let ((tags (classic.schema:keywords entity))
          (limit (getf params :limit 5)))
      (when tags
        (let ((related (context-query ctx \"schema:keywords\" (first tags))))
          (render-related-list related limit)))))"
  `(register-anchor-handler ,name
    (lambda (,context-var ,entity-var ,params-var)
      ,@body)))

;;; ============================================================
;;; Anchor evaluation
;;; ============================================================

(defun evaluate-anchor (node context)
  "Evaluate a single compose.anchor node. Looks up the handler by name,
calls it with the context, entity, and params. Returns the handler's
result (a Lexis subtree or NIL).

If no handler is found for the anchor name, checks for a :fallback
attribute:
  - :fallback NIL -> returns NIL (anchor is removed)
  - :fallback <lexis-subtree> -> returns the fallback content
  - no :fallback specified -> returns NIL with a warning"
  (let* ((name (anchor-name node))
         (handler (find-anchor-handler name))
         (entity (context-entity context))
         (params (anchor-params node)))
    (if handler
        (funcall handler context entity params)
        ;; No handler registered
        (let ((fallback (get-attr node :fallback)))
          (when (null handler)
            (warn "No anchor handler registered for ~S" name))
          (if (eq fallback nil)
              nil
              fallback)))))

(defun evaluate-anchors (tree context)
  "Walk TREE and evaluate all compose.anchor nodes, replacing them
with their handler output or removing them if the handler returns NIL.

Returns the transformed tree."
  (cond
    ((text-node-p tree) tree)
    ((anchor-p tree)
     (evaluate-anchor tree context))
    ((tagged-node-p tree)
     (let ((tag (node-tag tree))
           (has-attrs (and (consp (cadr tree))
                           (string= "@" (symbol-name (caadr tree)))))
           (children (node-children tree)))
       (let ((new-children
               (loop for child in children
                     for result = (evaluate-anchors child context)
                     when result
                       ;; Handle splice from anchor returning list
                       if (and (consp result)
                               (not (symbolp (car result))))
                         append result
                       else
                         collect result)))
         (if has-attrs
             (list* tag (cadr tree) new-children)
             (cons tag new-children)))))
    (t tree)))
