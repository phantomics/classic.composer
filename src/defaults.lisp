;;;; defaults.lisp — Default implementations for all composition tiers
;;;;
;;;; These provide functional behavior for each tier, consuming theme
;;;; configuration when available and falling back to minimal defaults
;;;; when no theme is active.
;;;;
;;;; Application models (blog, wiki, forum) specialize these generics
;;;; for their content types. Capability extensions augment them.
;;;;
;;;; All schema references use the classic.schema nickname.

(in-package #:classic.composer)

;;; ============================================================
;;; compose-page — top-level orchestration
;;; ============================================================

(defmethod compose-page ((context composition-context))
  "Default page composition pipeline:
1. Validate theme capabilities (warn or error per *strict-capabilities*)
2. Apply theme config and slot-fills to context bindings
3. Build the frame (page skeleton)
4. Compose the feature (primary content) and bind it
5. Compose adjunct content and bind it
6. Compose aggregate content (if applicable) and bind it
7. Compose operative specs and bind them
8. Bind theme assets
9. Resolve all template slots in the frame
10. Run collectors (gather structural metadata)
11. Evaluate all anchors in the resolved tree

Returns a complete Lexis document s-expression."
  ;; Theme integration: validate, bind config and slot-fills
  (when (context-theme context)
    (validate-theme-capabilities context)
    (apply-theme-config-to-context context)
    (apply-theme-slot-fills-to-context context)
    ;; Bind assets for template inclusion
    (let ((assets (theme-asset-list context)))
      (when assets
        (context-bind context "theme.assets"
                      `(section (@ :class "theme-assets") ,@assets)))))
  ;; Compose tiers
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
      ;; Collect phase: gather structural metadata
      (run-collectors resolved context)
      ;; Evaluate anchors (handlers can read collected metadata)
      (evaluate-anchors resolved context))))

;;; ============================================================
;;; compose-frame — theme-aware frame selection
;;; ============================================================

(defmethod compose-frame ((context composition-context))
  "Produce the page frame. Cascade:
1. Theme override for :frame tier -> use its template
2. Theme tier-templates entry for :frame -> use that
3. Minimal default frame (document with main-content slot)

Application models and themes override this with richer frames."
  (or
   ;; Theme-provided frame
   (theme-tier-template context :frame)
   ;; Minimal default
   (let ((title (or (when (context-entity context)
                      (classic.schema:label (context-entity context)))
                    (when (context-publication context)
                      (classic.schema:label (context-publication context)))
                    "Untitled")))
     `(document (@ :title ,title)
        (template.slot (@ :name "main-content"))
        (template.slot (@ :name "adjunct-content"))
        (template.slot (@ :name "aggregate-content"))
        (template.slot (@ :name "operative-content"))))))

;;; ============================================================
;;; compose-feature — lens-driven or body extraction
;;; ============================================================

(defmethod compose-feature ((context composition-context))
  "Produce the primary content. If the resolved theme provides a
lens for the entity's class, use lens-driven composition. Otherwise
fall back to direct body extraction.

Returns a Lexis subtree or NIL if no entity is set."
  (let ((entity (context-entity context)))
    (when entity
      (or
       ;; Lens-driven composition
       (when (context-theme-lenses context)
         (let* ((entity-class (class-name (class-of entity)))
                (lens (classic.schema:find-lens
                       (context-theme-lenses context)
                       entity-class :purpose :default)))
           (when lens
             (let ((parts (apply-lens context lens entity)))
               (when parts
                 (let ((title (entity-title entity)))
                   `(section (@ :title ,title)
                      ,@parts)))))))
       ;; Fallback: direct body extraction
       (compose-feature-from-body entity)))))

(defun entity-title (entity)
  "Extract a title from an entity, trying headline then label."
  (or (when (and (slot-exists-p entity 'classic.schema:headline)
                 (slot-boundp entity 'classic.schema:headline))
        (classic.schema:headline entity))
      (when (slot-boundp entity 'classic.schema:label)
        (classic.schema:label entity))
      "Untitled"))

(defun compose-feature-from-body (entity)
  "Extract body content from an entity without lens guidance.
If body is a Lexis s-expression, return it directly. If it's a
string, wrap in a section with paragraph."
  (let ((body (when (and (slot-exists-p entity 'classic.schema:body)
                         (slot-boundp entity 'classic.schema:body))
                (classic.schema:body entity))))
    (cond
      ;; Body is already a Lexis s-expression
      ((and (consp body) (symbolp (car body)))
       body)
      ;; Body is a list of Lexis nodes (multiple top-level forms)
      ((and (consp body) (consp (car body)) (symbolp (caar body)))
       (let ((title (entity-title entity)))
         `(section (@ :title ,title) ,@body)))
      ;; Body is a plain string -- wrap in paragraph
      ((stringp body)
       (let ((title (entity-title entity)))
         `(section (@ :title ,title)
            (paragraph ,body))))
      ;; No body
      (t nil))))

;;; ============================================================
;;; compose-adjunct — theme-aware with default no-op
;;; ============================================================

(defmethod compose-adjunct ((context composition-context))
  "Default: check for a theme adjunct template, otherwise NIL.
Application models override this to provide comments, related links,
author cards, etc."
  (let ((tmpl (theme-tier-template context :adjunct)))
    (when tmpl (list tmpl))))

;;; ============================================================
;;; compose-aggregate — theme-aware with default no-op
;;; ============================================================

(defmethod compose-aggregate ((context composition-context))
  "Default: check for a theme aggregate template, otherwise NIL.
Application models override this for index pages, search results,
and collection views."
  (theme-tier-template context :aggregate))

;;; ============================================================
;;; compose-operative — theme-aware with default no-op
;;; ============================================================

(defmethod compose-operative ((context composition-context))
  "Default: check for a theme operative template, otherwise NIL.
Application models override this to place comment forms, editors,
search dialogs, etc."
  ;; Operative tier returns spec plists, not Lexis subtrees.
  ;; Theme operative templates are not typical here; this is a
  ;; placeholder for future theme-driven operative placement.
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
