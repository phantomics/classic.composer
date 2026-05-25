;;;; defaults.lisp — Default implementations for all composition tiers
;;;;
;;;; These provide functional but minimal behavior for each tier.
;;;; A publication using only the base classic.composer package (no
;;;; capability extensions) will still produce working output.
;;;;
;;;; Application models (blog, wiki, forum) specialize these generics
;;;; for their content types. Capability extensions augment them.

(in-package #:classic.composer)

;;; ============================================================
;;; compose-page — top-level orchestration
;;; ============================================================

(defmethod compose-page ((context composition-context))
  "Default page composition pipeline:
1. Build the frame (page skeleton)
2. Compose the feature (primary content) and bind it
3. Compose adjunct content and bind it
4. Compose aggregate content (if applicable) and bind it
5. Compose operative specs and bind them
6. Resolve all template slots in the frame
7. Evaluate all anchors in the resolved tree

Returns a complete Lexis document s-expression."
  (let ((frame (compose-frame context))
        (feature (compose-feature context))
        (adjuncts (compose-adjunct context))
        (aggregate (compose-aggregate context))
        (operatives (compose-operative context)))
    ;; Bind tier outputs to standard slot names
    (when feature
      (context-bind context "main-content" feature))
    (when adjuncts
      (context-bind context "adjunct-content"
                    (wrap-adjunct-content adjuncts)))
    (when aggregate
      (context-bind context "aggregate-content" aggregate))
    (when operatives
      (context-bind context "operative-content"
                    (wrap-operative-content operatives)))
    ;; Resolve template slots
    (let ((resolved (resolve-slots frame context)))
      ;; Evaluate anchors
      (evaluate-anchors resolved context))))

;;; ============================================================
;;; compose-frame — default frame
;;; ============================================================

(defmethod compose-frame ((context composition-context))
  "Default frame: a minimal document skeleton with a main-content slot.
Application models and themes override this with richer frames."
  (let ((title (or (when (context-entity context)
                     (classic:label (context-entity context)))
                   (when (context-publication context)
                     (classic:label (context-publication context)))
                   "Untitled")))
    `(document (@ :title ,title)
       (template.slot (@ :name "main-content"))
       (template.slot (@ :name "adjunct-content"))
       (template.slot (@ :name "aggregate-content"))
       (template.slot (@ :name "operative-content")))))

;;; ============================================================
;;; compose-feature — default feature extraction
;;; ============================================================

(defmethod compose-feature ((context composition-context))
  "Default feature composition: extract the body from the primary entity.
If the entity has a body slot containing a Lexis s-expression (a list
starting with a symbol), return it directly. If it's a string, wrap it
in a paragraph node.

Returns a Lexis subtree or NIL if no entity is set."
  (let ((entity (context-entity context)))
    (when entity
      (let ((body (when (slot-boundp entity 'classic:body)
                    (classic:body entity))))
        (cond
          ;; Body is already a Lexis s-expression
          ((and (consp body) (symbolp (car body)))
           body)
          ;; Body is a list of Lexis nodes (multiple top-level forms)
          ((and (consp body) (consp (car body)) (symbolp (caar body)))
           ;; Wrap in a section
           (let ((title (or (when (typep entity 'classic:classic-article)
                              (classic:headline entity))
                            (classic:label entity))))
             `(section (@ :title ,title)
                ,@body)))
          ;; Body is a plain string -- wrap in paragraph
          ((stringp body)
           `(section (@ :title ,(or (when (typep entity 'classic:classic-article)
                                      (classic:headline entity))
                                    (classic:label entity)))
              (paragraph ,body)))
          ;; No body
          (t nil))))))

;;; ============================================================
;;; compose-adjunct — default adjunct (no-op)
;;; ============================================================

(defmethod compose-adjunct ((context composition-context))
  "Default: no adjunct content. Application models override this to
provide comments, related links, author cards, etc."
  nil)

;;; ============================================================
;;; compose-aggregate — default aggregate (no-op)
;;; ============================================================

(defmethod compose-aggregate ((context composition-context))
  "Default: no aggregate content. Application models override this
for index pages, search results, and collection views."
  nil)

;;; ============================================================
;;; compose-operative — default operative (no-op)
;;; ============================================================

(defmethod compose-operative ((context composition-context))
  "Default: no operative controls. Application models override this
to place comment forms, editors, search dialogs, etc."
  nil)

;;; ============================================================
;;; Content wrapping helpers
;;; ============================================================

(defun wrap-adjunct-content (adjuncts)
  "Wrap a list of adjunct Lexis subtrees in a containing section.
ADJUNCTS is a list of Lexis subtrees, each representing one adjunct block."
  (when adjuncts
    `(section (@ :class "adjunct")
       ,@adjuncts)))

(defun wrap-operative-content (operatives)
  "Convert operative spec plists into placeholder Lexis nodes.
Each operative becomes a compose.operative node that a downstream
system (e.g., Seed) will expand into actual controls.

OPERATIVES is a list of plists as returned by compose-operative."
  (when operatives
    `(section (@ :class "operative")
       ,@(mapcar #'operative-spec-to-node operatives))))

(defun operative-spec-to-node (spec)
  "Convert a single operative spec plist into a Lexis placeholder node.
The node carries the spec as attributes for downstream processing."
  `(compose.operative (@ ,@spec)))
