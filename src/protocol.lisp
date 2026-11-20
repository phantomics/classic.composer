;;;; protocol.lisp — Core composition protocol
;;;;
;;;; Defines the generic functions that constitute the composer's public
;;;; interface. Each tier of content (frame, feature, adjunct, aggregate,
;;;; operative) has a corresponding generic function. Application models
;;;; and capability extensions specialize these.
;;;;
;;;; The top-level entry point is COMPOSE-PAGE, which orchestrates the
;;;; full composition pipeline: frame assembly, feature rendering,
;;;; adjunct attachment, aggregate formatting, and operative placement.
;;;; It produces a complete Lexis s-expression tree.

(in-package #:classic.composer)

;;; ============================================================
;;; Top-level composition
;;; ============================================================

(defgeneric compose-page (context)
  (:documentation
   "Compose a complete page as a Lexis s-expression tree.

CONTEXT is a composition-context carrying the persistence strategy,
publication, primary entity, theme, and active capabilities.

The default method orchestrates the full pipeline:
  1. Compose the frame (page skeleton with slots)
  2. Compose the feature (primary content)
  3. Compose adjunct content
  4. Compose aggregate content (if applicable)
  5. Place operative controls
  6. Resolve template slots
  7. Evaluate anchors

Returns a Lexis document s-expression ready for rendering."))

;;; ============================================================
;;; Tier protocols
;;; ============================================================

(defgeneric compose-frame (context)
  (:documentation
   "Produce the page-level frame as a Lexis s-expression tree.

The frame is the outermost structural layer: document skeleton,
navigation, header, footer, sidebar containers. It contains
template.slot nodes that other tiers fill.

Returns a Lexis document form (rooted at DOCUMENT) with template
slots for content insertion."))

(defgeneric compose-feature (context)
  (:documentation
   "Produce the primary content for the page as a Lexis subtree.

The feature is the content the page exists to present: an article
body, a wiki article, a forum post. It is derived from the entity
in the composition context.

Returns a Lexis subtree (typically a SECTION or list of block-level
nodes) to be inserted into the frame's main content slot."))

(defgeneric compose-adjunct (context)
  (:documentation
   "Produce adjunct content items as a list of Lexis subtrees.

Adjunct content exists in relation to the feature: comments, review
scores, related-article lists, author bio cards, infoboxes. Each
item in the returned list is a self-contained Lexis subtree.

Returns a list of Lexis s-expression subtrees, each representing
one adjunct content block. May return NIL if no adjunct content
applies."))

(defgeneric compose-aggregate (context)
  (:documentation
   "Produce a collection view as a Lexis subtree.

Aggregate content presents multiple entities: blog index pages,
forum thread listings, search results, tag archives. The entity
in the context is typically a classic-container or the context
carries query parameters.

Returns a Lexis subtree representing the collection view, or NIL
if the current page is not an aggregate page."))

(defgeneric compose-operative (context)
  (:documentation
   "Produce operative control specifications as a list of plists.

Operative elements are interactive controls: comment forms, rating
widgets, search dialogs. The composer specifies WHAT control goes
WHERE and what it targets; the actual control implementation is
delegated to a separate system (e.g., Seed).

Returns a list of operative specifications. Each spec is a plist:
  (:name \"comment-form\"
   :target \"classic:site,2026:containers/abc-comments\"
   :placement :after-feature
   :requires (:authenticated :write-permission)
   :params (:max-length 2000))

Returns NIL if no operative controls apply to this page."))

;;; ============================================================
;;; Container reading order
;;; ============================================================

(defgeneric container-reading-order (entity)
  (:documentation
   "Return the natural reading order for ENTITY's contents when
rendered as an aggregate view.

Returns one of:
  :AS-STORED  -- use the contains list as-is (default)
  :REVERSE    -- reverse the contains list for oldest-first reading
  :ALPHABETICAL -- sort entries alphabetically by label (future)

Application models specialize this for content types with specific
ordering semantics. For example, a forum thread stores posts
newest-first (via push) but reads oldest-first, so it returns
:REVERSE.

The default method returns :AS-STORED, which is newest-first for
containers built with push."))

(defmethod container-reading-order (entity)
  "Default: use the contains list as stored."
  (declare (ignore entity))
  :as-stored)

;;; ============================================================
;;; Markdown reader options
;;; ============================================================

(defgeneric markdown-options (context entity slot-name)
  (:documentation
   "Return the keyword arguments passed to LEXIS.MARKDOWN:MARKDOWN->LEXIS
when SLOT-NAME of ENTITY is rendered in the :markdown display mode.
CONTEXT is the composition context, or NIL when the renderer is called
without one.

The default method returns NIL, which keeps the reader's defaults: raw
HTML is escaped, links keep only the http, https, mailto and classic
URI schemes, and wiki links become cross-references to sections of the
same document.

Application models specialize this for their content types. A wiki
supplies :WIKI-LINK-RESOLVER, a function of a wiki link's target and
display text that returns a Lexis form built from LEXIS symbols. Only
content from a trusted source should get :RAW-HTML :PASSTHROUGH,
since HTML passed through is not checked by the URI filter. The
options must not include :DOCUMENT: the composer splices the reader's
blocks into its own tree."))

(defmethod markdown-options (context entity slot-name)
  "Default: no options, so the reader's safe defaults apply."
  (declare (ignore context entity slot-name))
  nil)

;;; ============================================================
;;; Lens property values and references
;;; ============================================================

(defgeneric lens-property-value (context entity property)
  (:documentation
   "Return the value of PROPERTY of ENTITY as a lens sees it, or NIL
when it has none, in which case the lens skips the property.

The default method returns the value of the slot named PROPERTY when
ENTITY has that slot and it is bound. Application models specialize
this, usually with an EQL specializer on PROPERTY, to give lenses
computed properties: values derived from other slots or found through
the persistence layer, which a lens names exactly as it names a slot.
A computed property has no slot definition, so its display mode is
:TEXT unless the lens declares one.

This is the composer's read path for property values: a computed
property must not modify ENTITY or anything else in persistence."))

(defmethod lens-property-value (context entity property)
  "Default: the bound value of the slot named PROPERTY, or NIL."
  (declare (ignore context))
  (when (and (slot-exists-p entity property)
             (slot-boundp entity property))
    (slot-value entity property)))

(defgeneric resolve-reference (context entity property value)
  (:documentation
   "Return the entity that VALUE, the value of PROPERTY of ENTITY,
refers to, or NIL when it refers to none that can be found.

Sublenses and the :LINK display mode call this to follow a
reference. The default method retrieves VALUE as a URI when it is a
string, and returns VALUE itself when it is already an entity.
Application models whose references are not URIs specialize it on
the referring ENTITY's class: a wiki whose typed slots name pages by
anchor looks the anchor up."))

(defmethod resolve-reference (context entity property value)
  "Default: retrieve a URI string; pass an entity through."
  (declare (ignore entity property))
  (typecase value
    (string (context-retrieve context value))
    (classic.schema:classic-resource value)
    (t nil)))

;;; ============================================================
;;; Page links
;;; ============================================================

(defgeneric entity-href (context entity)
  (:documentation
   "Return the URL of the page that presents ENTITY, as a string, or
NIL when no page does.

The composer links to an entity's page wherever a lens property says
:LINK :SELF, where a :LINK property refers to the entity, and in
container entries rendered without a lens. The default method returns
NIL, so nothing is linked. A site specializes this on the classes it
publishes pages for; the URL scheme -- relative file names for a
static site, routes for a server -- is the site's choice. CONTEXT
lets a method build URLs relative to the page being composed."))

(defmethod entity-href (context entity)
  "Default: no page, so no link."
  (declare (ignore context entity))
  nil)

;;; ============================================================
;;; Container entries
;;; ============================================================

(defgeneric container-entries (context container)
  (:documentation
   "Return the entities an aggregate view of CONTAINER lists, in
display order.

The default method retrieves the URIs in CONTAINER's contains list,
in the order CONTAINER-READING-ORDER gives, skipping any that cannot
be retrieved. When the theme has an :AGGREGATE lens for CONTAINER's
class with a :SORT-BY property, the entries are then sorted by that
property's value (read with LENS-PROPERTY-VALUE): ascending, or
descending when the lens says :SORT-ORDER :DESCENDING. The sort is
stable, and entries without a value go last.

Application models specialize this for containers whose order is a
rule of the content type, such as a forum listing pinned threads
first. The order is computed for display; the container is not
changed."))

;;; ============================================================
;;; Lexis tree utilities
;;; ============================================================
;;; These operate on raw s-expression Lexis trees (lists and strings),
;;; not on Lexis CLOS node objects.

(defun tagged-node-p (form)
  "Return T if FORM is a tagged Lexis node (a list whose CAR is a symbol)."
  (and (consp form)
       (symbolp (car form))))

(defun text-node-p (form)
  "Return T if FORM is a text node (a string)."
  (stringp form))

(defun node-tag (node)
  "Return the tag symbol of a tagged node."
  (car node))

(defun node-attrs (node)
  "Return the attribute plist of a tagged node, or NIL if none.
Attributes are signalled by (@ ...) as the first child."
  (let ((first-child (cadr node)))
    (when (and (consp first-child)
               (string= "@" (symbol-name (car first-child))))
      (cdr first-child))))

(defun node-children (node)
  "Return the children of a tagged node (excluding the @ attr list)."
  (let ((rest (cdr node)))
    (if (and (consp (car rest))
             (string= "@" (symbol-name (caar rest))))
        (cdr rest)
        rest)))

(defun get-attr (node key)
  "Get attribute value for KEY from a tagged node's attribute list.
Handles both keyword plist and alist attribute forms."
  (let ((attrs (node-attrs node)))
    (when attrs
      (if (keywordp (car attrs))
          ;; Keyword plist form: (@ :key val :key val ...)
          (getf attrs key)
          ;; Alist form: (@ (key val) (key val) ...)
          (cadr (assoc key attrs))))))

(defun walk-tree (function tree)
  "Walk a Lexis s-expression tree, calling FUNCTION on each node.
FUNCTION receives each node (tagged or text). Does not descend into
attribute lists. Returns NIL (side-effect only)."
  (funcall function tree)
  (when (tagged-node-p tree)
    (dolist (child (node-children tree))
      (walk-tree function child)))
  nil)

(defun transform-tree (function tree)
  "Transform a Lexis tree by applying FUNCTION to each node.
FUNCTION receives a node and returns its replacement (which may be
the same node, a new node, a list of nodes to splice, or NIL to
remove the node). Recurses into children of tagged nodes.

FUNCTION should return one of:
  - A single node (replacement)
  - A list starting with a symbol (a tagged node -- also a replacement)
  - A list starting with a non-symbol (splice these nodes in place)
  - NIL (remove this node)
  - The keyword :KEEP (leave unchanged, still recurse into children)"
  (let ((result (funcall function tree)))
    (cond
      ;; :KEEP means process children but keep this node's structure
      ((eq result :keep)
       (if (tagged-node-p tree)
           (let ((tag (node-tag tree))
                 (attrs-form (let ((r (cdr tree)))
                               (when (and (consp (car r))
                                          (eq '@ (caar r)))
                                 (car r))))
                 (children (node-children tree)))
             (let ((new-children
                     (loop for child in children
                           for transformed = (transform-tree function child)
                           when transformed
                             ;; Handle splice (list of non-symbol car)
                             if (and (consp transformed)
                                     (not (symbolp (car transformed))))
                               append transformed
                             else
                               collect transformed)))
               (if attrs-form
                   (list* tag attrs-form new-children)
                   (cons tag new-children))))
           tree))
      ;; NIL means remove
      ((null result) nil)
      ;; A tagged node or text node returned as-is (no further recursion
      ;; on the replacement -- caller controls depth)
      (t result))))
