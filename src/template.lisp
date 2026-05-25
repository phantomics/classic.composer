;;;; template.lisp — Template slot resolution
;;;;
;;;; Templates are Lexis documents containing (template.slot ...) nodes
;;;; that act as placeholders. The composer fills these slots with content
;;;; from the composition context's bindings.
;;;;
;;;; A template.slot node has the form:
;;;;   (template.slot (@ :name "slot-name"))
;;;;
;;;; The resolver walks the Lexis tree, finds template.slot nodes, looks
;;;; up the slot name in the context bindings, and substitutes the bound
;;;; value. Unresolved slots (no binding found) are either removed or
;;;; left as-is depending on configuration.

(in-package #:classic.composer)

;;; ============================================================
;;; Slot detection
;;; ============================================================

(defun template-slot-p (node)
  "Return T if NODE is a template.slot placeholder node."
  (and (tagged-node-p node)
       (string= "TEMPLATE.SLOT" (symbol-name (node-tag node)))))

(defun slot-name (node)
  "Extract the slot name (a string) from a template.slot node."
  (get-attr node :name))

;;; ============================================================
;;; Slot resolution
;;; ============================================================

(defun resolve-slots (tree context &key (remove-unresolved t))
  "Walk TREE and replace all template.slot nodes with their bound values
from CONTEXT.

Each template.slot is looked up by its :name attribute in the context's
bindings alist. If found, the slot is replaced with the bound value
(a string, a Lexis subtree, or a list of nodes to splice). If not
found:
  - When REMOVE-UNRESOLVED is T (default), the slot is removed.
  - When REMOVE-UNRESOLVED is NIL, the slot is left in place.

Returns the transformed tree."
  (resolve-slots-recursive tree context remove-unresolved))

(defun resolve-slots-recursive (tree context remove-unresolved)
  "Internal recursive implementation of slot resolution."
  (cond
    ;; Text node -- pass through
    ((text-node-p tree) tree)
    ;; Template slot -- resolve or remove
    ((template-slot-p tree)
     (let* ((name (slot-name tree))
            (value (context-binding context name)))
       (cond
         ;; Found a binding -- substitute
         (value
          (if (and (consp value) (not (symbolp (car value))))
              ;; Value is a list of nodes -- return as splice marker
              ;; (the parent reconstruction handles this)
              value
              ;; Value is a single node or string
              value))
         ;; No binding -- remove or keep
         (remove-unresolved nil)
         (t tree))))
    ;; Tagged node -- recurse into children
    ((tagged-node-p tree)
     (let ((tag (node-tag tree))
           (has-attrs (and (consp (cadr tree))
                           (eq '@ (caadr tree))))
           (children (node-children tree)))
       (let ((new-children
               (loop for child in children
                     for resolved = (resolve-slots-recursive
                                     child context remove-unresolved)
                     when resolved
                       ;; Handle splice: value is a list of non-tagged items
                       if (and (consp resolved)
                               (not (symbolp (car resolved))))
                         append resolved
                       else
                         collect resolved)))
         ;; Also check if attr values contain slots (for :title etc.)
         (let ((new-attrs (if has-attrs
                              (resolve-attr-slots (cadr tree) context)
                              nil)))
           (if has-attrs
               (list* tag new-attrs new-children)
               (cons tag new-children))))))
    ;; Unknown form -- pass through
    (t tree)))

(defun resolve-attr-slots (attr-form context)
  "Resolve template.slot references within an attribute list.
Handles the case where an attribute value is itself a template.slot
form (e.g., :title (template.slot (@ :name \"page-title\"))).
Returns the attribute form with slots resolved."
  ;; attr-form is (@ :key val :key val ...) or (@ (key val) ...)
  (let ((items (cdr attr-form)))  ; skip the @
    (if (keywordp (car items))
        ;; Keyword plist form
        (cons '@
              (loop for (key val . nil) on items by #'cddr
                    collect key
                    collect (if (and (consp val) (template-slot-p val))
                                (let ((bound (context-binding
                                              context (slot-name val))))
                                  (or bound val))
                                val)))
        ;; Alist form -- less common for slots, but handle it
        (cons '@
              (loop for pair in items
                    collect (if (and (consp (cadr pair))
                                    (template-slot-p (cadr pair)))
                                (list (car pair)
                                      (let ((bound (context-binding
                                                    context
                                                    (slot-name (cadr pair)))))
                                        (or bound (cadr pair))))
                                pair))))))
