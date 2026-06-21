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
  ;; Standard entity-derived bindings. When an entity is present,
  ;; provide its headline-or-label as "page-title" so generic frame
  ;; templates can use (template.slot (@ :name "page-title")) without
  ;; per-page boilerplate.
  (let ((entity (context-entity context)))
    (when entity
      (let ((title (entity-title entity)))
        (when (and title (null (context-binding context "page-title")))
          (context-bind context "page-title" title)))))
  ;; Theme integration: validate, bind config and slot-fills
  (when (context-theme context)
    (validate-theme-capabilities context)
    (apply-theme-config-to-context context)
    (apply-theme-slot-fills-to-context context)
    ;; Bind assets for template inclusion. The asset list is a list
    ;; of passthrough nodes; binding the list directly lets the slot
    ;; resolver splice the entries at the slot's position rather than
    ;; wrapping them in a single container element.
    (let ((assets (theme-asset-list context)))
      (when assets
        (context-bind context "theme.assets" assets))))
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
       ;; Lens-driven composition. The lens controls what properties
       ;; appear and in what order; we wrap the result in a class-
       ;; tagged section without a title attribute, leaving title
       ;; placement entirely to the lens (typically via a headline
       ;; property at the start). This avoids duplicating the title
       ;; when the lens already includes it.
       (when (context-theme-lenses context)
         (let* ((entity-class (class-name (class-of entity)))
                (lens (classic.schema:find-lens
                       (context-theme-lenses context)
                       entity-class :purpose :default)))
           (when lens
             (let ((parts (apply-lens context lens entity)))
               (when parts
                 `(section (@ :class "feature") ,@parts))))))
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
;;; compose-aggregate — theme template, then container walk, then NIL
;;; ============================================================

(defmethod compose-aggregate ((context composition-context))
  "Default aggregate composition. Cascade:
1. If the theme provides an :aggregate tier-template, return it.
2. If the context entity is a classic-container, walk its contents
   and produce a section of entries rendered with a per-entry lens.
3. Otherwise NIL.

For container walk: each item in the container's `contains' list is
retrieved, then a lens is applied. The lens lookup prefers `:summary'
purpose for richer index entries, falling back to `:label' for terse
references. If neither lens is defined, the entry's label slot is
used as plain text. Each entry is wrapped in its own (section ...)."
  (or
   (theme-tier-template context :aggregate)
   (let ((entity (context-entity context)))
     (when (typep entity 'classic.schema:classic-container)
       (compose-container-entries context entity)))))

(defun compose-container-entries (context container)
  "Walk CONTAINER's contents and produce a Lexis section listing each
entry. Returns a (section ...) form, or NIL if the container is empty.

The iteration order is determined by CONTAINER-READING-ORDER:
  :AS-STORED -- iterate the contains list as-is (newest-first for
                containers built with push)
  :REVERSE   -- reverse the list for oldest-first reading (forum
                threads, chronological feeds)"
  (let* ((uris (classic.schema:contains container))
         (ordered (case (container-reading-order container)
                    (:reverse (reverse uris))
                    (t uris))))
    (when ordered
      (let ((entries (loop for uri in ordered
                           for entry = (compose-container-entry context uri)
                           when entry collect entry)))
        (when entries
          `(section (@ :class "aggregate")
             ,@entries))))))

(defun compose-container-entry (context uri)
  "Render a single container entry identified by URI as a Lexis
subtree. Tries the :summary lens, then :label, then falls back to
the entity's label slot. Returns a (section ...) wrapping the
rendered entry, or NIL if the entity cannot be retrieved."
  (let ((entity (context-retrieve context uri)))
    (when entity
      (let* ((entity-class (class-name (class-of entity)))
             (lenses (context-theme-lenses context))
             (lens (or (and lenses
                            (classic.schema:find-lens
                             lenses entity-class :purpose :summary))
                       (and lenses
                            (classic.schema:find-lens
                             lenses entity-class :purpose :label)))))
        (cond
          (lens
           (let ((parts (apply-lens context lens entity)))
             (when parts
               `(section (@ :class "aggregate-entry") ,@parts))))
          ;; Fallback: bare label
          ((slot-boundp entity 'classic.schema:label)
           `(section (@ :class "aggregate-entry")
              (paragraph ,(classic.schema:label entity))))
          (t nil))))))

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
