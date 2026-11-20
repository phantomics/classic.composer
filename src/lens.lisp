;;;; lens.lisp — Lens evaluation: display mode cascade and sublens recursion
;;;;
;;;; Consumes Fresnel-inspired lens specs from the resolved theme to
;;;; drive feature-tier composition. A lens declares which slots of an
;;;; entity class to display, in what order, with what display modes,
;;;; and how relation slots reference sublenses for related entities.
;;;;
;;;; The display mode cascade determines how a slot value becomes a
;;;; Lexis subtree. Explicit :display annotations in the lens win;
;;;; otherwise the MOP slot metadata (:format, :persistence) guides
;;;; the fallback.
;;;;
;;;; All schema references use the classic.schema nickname.

(in-package #:classic.composer)

;;; ============================================================
;;; Display mode cascade
;;; ============================================================

(defun compute-display-mode (slot-name entity-class
                             &key explicit-mode sublens-class)
  "Determine the display mode for SLOT-NAME on ENTITY-CLASS.

Cascade:
  1. EXPLICIT-MODE from the lens property spec (:display keyword)
  2. Slot's MOP :format annotation (:markdown -> :markdown, :html -> :html)
  3. Slot's MOP :persistence is :relation AND no SUBLENS-CLASS -> :link
  4. :text (universal fallback)

Returns a keyword: :text, :image, :link, :uri, :html, :markdown, :date, :list."
  (or explicit-mode
      (let ((slot-def (find-slot-def entity-class slot-name)))
        (when slot-def
          (let ((fmt (slot-format slot-def))
                (pers (slot-persistence slot-def)))
            (cond
              ((member fmt '(:markdown :html)) fmt)
              ((and (eq pers :relation) (null sublens-class)) :link)
              (t nil)))))
      :text))

(defun find-slot-def (class-designator slot-name)
  "Find the effective slot definition for SLOT-NAME on CLASS-DESIGNATOR.
CLASS-DESIGNATOR is a class symbol or class object.
Returns the slot definition or NIL."
  (let ((class-obj (if (symbolp class-designator)
                       (find-class class-designator nil)
                       class-designator)))
    (when class-obj
      (let ((finalized (c2mop:ensure-finalized class-obj)))
        (find slot-name (c2mop:class-slots finalized)
              :key #'c2mop:slot-definition-name)))))

;;; ============================================================
;;; Per-mode renderers
;;; ============================================================

(defun render-slot-via-display-mode (mode value
                                     &key alt-text label
                                          context entity slot-name)
  "Dispatch on MODE to render VALUE as a Lexis subtree.

Returns a Lexis s-expression node, a list of Lexis block nodes (see
BLOCK-LIST-P), or NIL if value is NIL/empty.

Modes:
  :text      -> text node or (paragraph ...)
  :image     -> (image (@ :src ... :alt ...))
  :link      -> (web-link (@ :uri ...) label)
  :uri       -> plain text of the URI
  :html      -> pass-through (value is already a Lexis subtree or a
                list of them)
  :markdown  -> the Lexis blocks read from the Markdown text
  :date      -> formatted date string
  :list      -> (unordered-list ...)

CONTEXT, ENTITY and SLOT-NAME identify what is rendered; the :markdown
mode passes them to MARKDOWN-OPTIONS to get the reader's options."
  (when (null value) (return-from render-slot-via-display-mode nil))
  (case mode
    (:text      (render-text value))
    (:image     (render-image value alt-text))
    (:link      (render-link value label))
    (:uri       (render-uri value))
    (:html      (render-html-passthrough value))
    (:markdown  (render-markdown
                 value (markdown-options context entity slot-name)))
    (:date      (render-date value))
    (:list      (render-list value))
    (t          (render-text value))))

(defun block-list-p (value)
  "Return T if VALUE is a list of Lexis nodes rather than a single node.
A display mode returns such a list when the slot holds several blocks;
APPLY-LENS splices them into its result instead of wrapping them in an
untitled section, which would push their sections one level deeper."
  (and (consp value)
       (consp (car value))
       (symbolp (caar value))))

(defun render-text (value)
  "Render VALUE as text. Strings become text nodes; other types
are coerced to string via PRINC-TO-STRING."
  (let ((s (if (stringp value) value (princ-to-string value))))
    (if (find #\Newline s)
        `(paragraph ,s)
        s)))

(defun render-image (uri alt-text)
  "Render an image reference."
  `(image (@ :src ,(princ-to-string uri)
              ,@(when alt-text (list :alt alt-text)))))

(defun render-link (uri label)
  "Render a hyperlink."
  (let ((uri-str (princ-to-string uri))
        (display (or label (princ-to-string uri))))
    `(web-link (@ :uri ,uri-str) ,display)))

(defun render-uri (value)
  "Render a URI as plain text."
  (princ-to-string value))

(defun render-html-passthrough (value)
  "Pass through a value that is already a Lexis s-expression.

Handles three shapes:
  - A single tagged node (cons whose car is a symbol): returned as-is.
  - A list of tagged nodes (cons whose car is itself a cons): returned
    as-is, for the caller to splice (see BLOCK-LIST-P).
  - Anything else: coerced to a string and wrapped in a paragraph."
  (cond
    ;; Single tagged node
    ((and (consp value) (symbolp (car value)))
     value)
    ;; List of tagged nodes -- returned for splicing
    ((block-list-p value)
     value)
    ;; Fallback: coerce to string and wrap
    (t `(paragraph ,(princ-to-string value)))))

(defun render-markdown (value &optional options)
  "Read VALUE as Markdown with the Lexis Markdown reader.

OPTIONS is a list of keyword arguments for
LEXIS.MARKDOWN:MARKDOWN->LEXIS, as returned by MARKDOWN-OPTIONS.
Returns the single block the text yields, a list of blocks for the
caller to splice (see BLOCK-LIST-P), or NIL when the text holds no
blocks. A value that is not a string is read as its printed form.

The reader's output uses the LEXIS package's tag symbols; the composer
compares tags by symbol name, so they mix freely with its own."
  (let* ((text (if (stringp value) value (princ-to-string value)))
         (blocks (apply #'lexis.markdown:markdown->lexis text options)))
    (if (rest blocks)
        blocks
        (first blocks))))

(defun render-date (value)
  "Render a timestamp value as a formatted date string.
Handles local-time timestamps, strings, and other printable values."
  (cond
    ;; local-time timestamp
    ((and (find-package :local-time)
          (typep value (find-class
                        (find-symbol "TIMESTAMP"
                                     (find-package :local-time))
                        nil)))
     (funcall (find-symbol "FORMAT-TIMESTRING"
                           (find-package :local-time))
              nil value
              :format '(:year #\- (:month 2) #\- (:day 2))))
    ;; Already a string
    ((stringp value) value)
    ;; Fallback
    (t (princ-to-string value))))

(defun render-list (value)
  "Render a list value as an unordered-list."
  (if (listp value)
      `(unordered-list
        ,@(mapcar (lambda (item)
                    `(item ,(if (stringp item)
                                item
                                (princ-to-string item))))
                  value))
      ;; Single value, wrap in a list
      `(unordered-list (item ,(princ-to-string value)))))

(defun find-symbol-safe (name package-name)
  "Find a symbol by NAME in PACKAGE-NAME, returning NIL if the
package or symbol doesn't exist."
  (let ((pkg (find-package package-name)))
    (when pkg (find-symbol name pkg))))

;;; ============================================================
;;; Lens application
;;; ============================================================

(defun apply-lens (context lens entity)
  "Walk LENS's property specs, rendering each property of ENTITY with
RENDER-LENS-PROPERTY. Returns a list of Lexis subtrees, in property
order. A property usually gives one subtree; one whose rendering is a
list of blocks (a multi-block Markdown or Lexis body) gives each block
in turn. Properties with no value are skipped."
  (let ((results nil))
    (dolist (prop (classic.schema:lens-properties lens))
      (let ((rendered (render-lens-property context entity prop)))
        (cond
          ((block-list-p rendered)
           (dolist (block rendered)
             (push block results)))
          (rendered
           (push rendered results)))))
    (nreverse results)))

(defun render-lens-property (context entity prop)
  "Render one property of ENTITY as a Lexis subtree, or a list of
blocks, or return NIL when the property has no value.

PROP is a normalized property spec, as CLASSIC.SCHEMA:LENS-PROPERTIES
returns: (:slot NAME &key display sublens purpose link label). The
value is read with LENS-PROPERTY-VALUE, so NAME may be a slot or a
computed property. Then:

  - With :SUBLENS, the value is a reference (or a list of them),
    rendered by APPLY-SUBLENS through the target entity's lens.
  - In the :LINK display mode, the value is a reference rendered by
    RENDER-REFERENCE-LINK.
  - Otherwise the value is rendered in its display mode.

:LINK :SELF links the rendered value to ENTITY's page, when
ENTITY-HREF gives one; use it on inline values such as a title.
:LABEL, a string, captions the value: an inline value becomes
(paragraph (strong \"Label:\") \" \" value), and a block value is
preceded by a paragraph holding the caption."
  (let* ((property (getf prop :slot))
         (value (lens-property-value context entity property)))
    (when value
      (let* ((sublens-class (getf prop :sublens))
             (mode (unless sublens-class
                     (compute-display-mode property (class-of entity)
                                           :explicit-mode (getf prop :display))))
             (rendered
               (cond
                 (sublens-class
                  (apply-sublens context sublens-class
                                 (or (getf prop :purpose) :default)
                                 value
                                 :entity entity :property property))
                 ((eq mode :link)
                  (render-reference-link context entity property value))
                 (t
                  (render-slot-via-display-mode mode value
                                                :context context
                                                :entity entity
                                                :slot-name property)))))
        (when rendered
          (label-rendered-value (getf prop :label)
                                (link-rendered-value context entity
                                                     (getf prop :link)
                                                     rendered)))))))

(defun link-rendered-value (context entity link rendered)
  "Wrap RENDERED in a web-link to ENTITY's page when LINK is :SELF and
ENTITY-HREF gives one. Blocks, which a link cannot hold, are not
linked."
  (let ((href (when (and (eq link :self)
                         (not (block-list-p rendered))
                         (not (block-node-p rendered)))
                (entity-href context entity))))
    (if href
        `(web-link (@ :uri ,href) ,rendered)
        rendered)))

(defun label-rendered-value (label rendered)
  "Caption RENDERED with LABEL, a string, when LABEL is given."
  (cond
    ((null label) rendered)
    ((block-list-p rendered)
     `((paragraph (strong ,label)) ,@rendered))
    ((block-node-p rendered)
     `((paragraph (strong ,label)) ,rendered))
    (t
     `(paragraph (strong ,(format nil "~A:" label)) " " ,rendered))))

(defparameter *block-tag-names*
  '("PARAGRAPH" "SECTION" "BLOCKQUOTE" "CODE-BLOCK" "UNORDERED-LIST"
    "ORDERED-LIST" "DEFINITION-LIST" "TABLE" "FIGURE" "PASSTHROUGH")
  "Names of the Lexis tags that are blocks rather than inline content.")

(defun block-node-p (value)
  "Return T if VALUE is a single Lexis node with a block-level tag."
  (and (tagged-node-p value)
       (member (symbol-name (node-tag value)) *block-tag-names*
               :test #'string=)
       t))

;;; ============================================================
;;; References
;;; ============================================================

(defun render-reference-link (context entity property value)
  "Render VALUE, a reference held by PROPERTY of ENTITY, as a link.

The reference is resolved with RESOLVE-REFERENCE. A resolved target
is linked to its page (ENTITY-HREF) or, when it has none, to VALUE if
VALUE is a URI, and shown by its title. An unresolved VALUE that is a
URI is linked to directly, shown by ENTITY's label; anything else,
such as the name of a page that does not exist, is rendered as text."
  (let ((target (resolve-reference context entity property value)))
    (cond
      (target
       (let ((href (or (entity-href context target)
                       (when (uri-like-p value) value))))
         (if href
             (render-link href (entity-title target))
             (render-text (entity-title target)))))
      ((uri-like-p value)
       (render-link value (when (slot-boundp entity 'classic.schema:label)
                            (classic.schema:label entity))))
      (t (render-text value)))))

(defun uri-like-p (value)
  "Return T if VALUE is a string that reads as a URI or URI reference:
it holds no whitespace, and has a scheme or begins with /, #, ./ or
../."
  (and (stringp value)
       (plusp (length value))
       (notany (lambda (c) (member c '(#\Space #\Tab #\Newline))) value)
       (or (find #\: value)
           (member (char value 0) '(#\/ #\#))
           (eql 0 (search "./" value))
           (eql 0 (search "../" value)))
       t))

;;; ============================================================
;;; Sublens resolution
;;; ============================================================

(defun apply-sublens (context sublens-class sublens-purpose value
                      &key entity property)
  "Handle a reference property: resolve the related entity and apply
the target lens.

VALUE is a reference, or a list of references for multi-valued
relations. A reference is usually a URI string; RESOLVE-REFERENCE,
called with ENTITY and PROPERTY (the referring entity and property),
turns it into an entity.

Fallback chain:
  1. Lens for (sublens-class, sublens-purpose) in resolved theme
  2. Lens for (actual-class, :label) in resolved theme
  3. Built-in: the entity's label slot

Returns a Lexis subtree or NIL."
  (if (listp value)
      ;; Multi-valued relation: render each
      (let ((items (loop for reference in value
                         for result = (apply-sublens-single
                                       context sublens-class
                                       sublens-purpose reference
                                       :entity entity :property property)
                         when result collect result)))
        (when items
          `(unordered-list ,@(mapcar (lambda (item) `(item ,item))
                                     items))))
      ;; Single-valued relation
      (apply-sublens-single context sublens-class sublens-purpose value
                            :entity entity :property property)))

(defun apply-sublens-single (context sublens-class sublens-purpose reference
                             &key entity property)
  "Apply a sublens to the single entity REFERENCE refers to.
ENTITY and PROPERTY are passed to RESOLVE-REFERENCE.
Returns a Lexis subtree or NIL."
  (let ((target (resolve-reference context entity property reference)))
    (when target
      (let* ((lenses (context-theme-lenses context))
             (lens (or (classic.schema:find-lens
                        lenses sublens-class :purpose sublens-purpose)
                       (classic.schema:find-lens
                        lenses (class-name (class-of target))
                        :purpose :label))))
        (if lens
            (let ((parts (apply-lens context lens target)))
              (when parts
                (if (= 1 (length parts))
                    (first parts)
                    `(section ,@parts))))
            ;; Final fallback: the target's label slot
            (when (slot-boundp target 'classic.schema:label)
              (classic.schema:label target)))))))
