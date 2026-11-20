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
  "Walk LENS's property specs, rendering each slot of ENTITY
according to its display mode. Returns a list of Lexis subtrees,
in property order. A property usually gives one subtree; one whose
rendering is a list of blocks (a multi-block Markdown or Lexis body)
gives each block in turn.

Skips properties whose slot is unbound or NIL on the entity.
Handles sublens references for relation slots."
  (let ((property-specs (classic.schema:lens-properties lens))
        (entity-class (class-of entity))
        (results nil))
    (dolist (prop property-specs)
      (let* ((slot-name (getf prop :slot))
             (explicit-display (getf prop :display))
             (sublens-class (getf prop :sublens))
             (sublens-purpose (or (getf prop :purpose) :default)))
        ;; Skip if slot doesn't exist or isn't bound
        (when (and (slot-exists-p entity slot-name)
                   (slot-boundp entity slot-name))
          (let ((value (slot-value entity slot-name)))
            (when value
              (let ((rendered
                      (if sublens-class
                          ;; Relation slot with sublens
                          (apply-sublens context
                                         sublens-class sublens-purpose
                                         value)
                          ;; Regular slot
                          (let ((mode (compute-display-mode
                                       slot-name entity-class
                                       :explicit-mode explicit-display)))
                            (render-slot-via-display-mode
                             mode value
                             :label (when (eq mode :link)
                                      (classic.schema:label entity))
                             :context context
                             :entity entity
                             :slot-name slot-name)))))
                (cond
                  ((block-list-p rendered)
                   (dolist (block rendered)
                     (push block results)))
                  (rendered
                   (push rendered results)))))))))
    (nreverse results)))

;;; ============================================================
;;; Sublens resolution
;;; ============================================================

(defun apply-sublens (context sublens-class sublens-purpose value)
  "Handle a relation slot: retrieve the related entity and apply
the target lens.

VALUE is a URI string (or list of URI strings for multi-valued
relations).

Fallback chain:
  1. Lens for (sublens-class, sublens-purpose) in resolved theme
  2. Lens for (actual-class, :label) in resolved theme
  3. Built-in: the entity's label slot

Returns a Lexis subtree or NIL."
  (if (listp value)
      ;; Multi-valued relation: render each
      (let ((items (loop for uri in value
                         for result = (apply-sublens-single
                                       context sublens-class
                                       sublens-purpose uri)
                         when result collect result)))
        (when items
          `(unordered-list ,@(mapcar (lambda (item) `(item ,item))
                                     items))))
      ;; Single-valued relation
      (apply-sublens-single context sublens-class sublens-purpose value)))

(defun apply-sublens-single (context sublens-class sublens-purpose uri)
  "Apply a sublens to a single related entity identified by URI.
Returns a Lexis subtree or NIL."
  (let ((entity (context-retrieve context uri)))
    (when entity
      (let* ((lenses (context-theme-lenses context))
             (actual-class (class-name (class-of entity)))
             ;; Try the declared sublens class/purpose
             (lens (classic.schema:find-lens
                    lenses sublens-class :purpose sublens-purpose)))
        (cond
          ;; Found target lens
          (lens
           (let ((parts (apply-lens context lens entity)))
             (when parts
               (if (= 1 (length parts))
                   (first parts)
                   `(section ,@parts)))))
          ;; Fallback: :label purpose for actual class
          ((setf lens (classic.schema:find-lens
                       lenses actual-class :purpose :label))
           (let ((parts (apply-lens context lens entity)))
             (when parts
               (if (= 1 (length parts))
                   (first parts)
                   `(section ,@parts)))))
          ;; Final fallback: entity's label slot
          (t
           (when (slot-boundp entity 'classic.schema:label)
             (classic.schema:label entity))))))))
