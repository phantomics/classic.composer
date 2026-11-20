;;;; helpers.lisp — Test fixtures and utilities for Composer tests
;;;;
;;;; Provides clean-state wrappers, convenience constructors, and
;;;; registry isolation following Classic core's test conventions.

(in-package #:classic.composer-tests)

;;; ============================================================
;;; Suite hierarchy
;;; ============================================================

(def-suite classic.composer
  :description "Root suite for all Classic Composer tests")

(def-suite tree-utils
  :description "Lexis s-expression tree utility functions"
  :in classic.composer)

(def-suite context
  :description "Composition context construction and helpers"
  :in classic.composer)

(def-suite template
  :description "Template slot detection and resolution"
  :in classic.composer)

(def-suite anchor
  :description "Anchor handler registry and evaluation"
  :in classic.composer)

(def-suite collector
  :description "Collector registry and collect phase"
  :in classic.composer)

(def-suite capability
  :description "Capability registration and dispatch"
  :in classic.composer)

(def-suite theme-integration
  :description "Theme resolution, tier cascade, capability validation"
  :in classic.composer)

(def-suite lens
  :description "Lens evaluation, display modes, sublens recursion"
  :in classic.composer)

(def-suite defaults
  :description "Default compose-page pipeline and tier methods"
  :in classic.composer)

;;; ============================================================
;;; Test runner
;;; ============================================================

(defun run-all-tests ()
  "Run all Classic Composer test suites. Returns T if all pass."
  (let ((results (5am:run 'classic.composer)))
    (explain! results)
    (results-status results)))

(defun run-suite (suite-name)
  "Run a single test suite by name. Returns T if all pass."
  (let ((results (5am:run suite-name)))
    (explain! results)
    (results-status results)))

;;; ============================================================
;;; Persistence fixtures
;;; ============================================================

(defvar *test-strategy* nil
  "Bound to a fresh memory-persistence-strategy within with-clean-strategy.")

(defmacro with-clean-strategy ((&optional (var '*test-strategy*)) &body body)
  "Execute BODY with a fresh in-memory persistence strategy bound to VAR.
Ensures complete isolation between tests."
  `(let ((,var (make-instance 'memory-persistence-strategy)))
     ,@body))

;;; ============================================================
;;; Registry isolation
;;; ============================================================
;;; The composer has three global registries that tests must not pollute.
;;; This macro saves and restores them around test bodies.

(defmacro with-fresh-registries (&body body)
  "Execute BODY with fresh, empty composer registries for capabilities,
anchor handlers, and collectors. Restores the original registries
after BODY completes (even on non-local exit)."
  `(let ((classic.composer::*capabilities*
           (make-hash-table :test 'equal))
         (classic.composer::*tier-capabilities*
           (make-hash-table :test 'eq))
         (classic.composer::*anchor-handlers*
           (make-hash-table :test 'equal))
         (classic.composer::*collectors*
           (make-hash-table :test 'equal))
         (classic.composer::*collector-order* nil))
     ,@body))

;;; ============================================================
;;; Entity constructors
;;; ============================================================

(defun make-test-article (&key (strategy *test-strategy*)
                                (authority "test.example")
                                (authority-date "2026")
                                (headline "Test Article")
                                (body-text "Test body content.")
                                (keywords nil)
                                (author-uri nil))
  "Create and persist a classic-article with sensible defaults."
  (let* ((uri (mint-uri 'classic.schema:classic-article authority authority-date
                        :slug headline
                        :date (local-time:now)))
         (article (make-instance 'classic.schema:classic-article
                                 :uri uri
                                 :label headline
                                 :headline headline
                                 :body body-text
                                 :keywords keywords
                                 :author author-uri
                                 :rdf-type "schema:Article")))
    (when strategy
      (persist-entity strategy article))
    article))

(defun make-test-person (&key (strategy *test-strategy*)
                               (authority "test.example")
                               (authority-date "2026")
                               (name "Test Author"))
  "Create and persist a classic-person with sensible defaults."
  (let* ((uri (mint-uri 'classic.schema:classic-person authority authority-date
                        :slug name))
         (person (make-instance 'classic.schema:classic-person
                                :uri uri
                                :label name
                                :agent-name name)))
    (when strategy
      (persist-entity strategy person))
    person))

(defun make-test-theme (&key (strategy *test-strategy*)
                              (name "Test Theme")
                              (authority "test.example")
                              (authority-date "2026")
                              parent-uri
                              capabilities
                              excluded-capabilities
                              tier-templates
                              slot-fills
                              lenses
                              asset-base-uri
                              asset-manifest)
  "Create and persist a classic-theme with sensible defaults."
  (let ((theme (make-instance 'classic.schema:classic-theme
                :uri (mint-uri 'classic.schema:classic-theme
                               authority authority-date :slug name)
                :label name
                :parent-theme parent-uri
                :capabilities capabilities
                :excluded-capabilities excluded-capabilities
                :tier-templates tier-templates
                :slot-fills slot-fills
                :lenses lenses
                :asset-base-uri asset-base-uri
                :asset-manifest asset-manifest
                :theme-version "1.0")))
    (when strategy
      (persist-entity strategy theme))
    theme))

(defun make-test-override (&key (strategy *test-strategy*)
                                 theme-uri tier template
                                 (authority "test.example")
                                 (authority-date "2026"))
  "Create and persist a classic-theme-override."
  (let ((override (make-instance 'classic.schema:classic-theme-override
                    :uri (mint-uri 'classic.schema:classic-theme-override
                                   authority authority-date
                                   :slug (format nil "override-~(~A~)" tier))
                    :label (format nil "~A override" tier)
                    :base-theme theme-uri
                    :override-tier tier
                    :override-template template)))
    (when strategy
      (persist-entity strategy override))
    override))

(defun make-test-publication (&key (strategy *test-strategy*)
                                    (name "Test Publication")
                                    (authority "test.example")
                                    (authority-date "2026")
                                    theme-uri)
  "Create and persist a classic-publication."
  (let ((pub (make-instance 'classic.schema:classic-publication
               :uri (mint-uri 'classic.schema:classic-publication
                              authority authority-date :slug name)
               :label name
               :pub-host authority
               :persistence-strategy strategy
               :uri-base-authority authority
               :ui-theme theme-uri)))
    (when strategy
      (persist-entity strategy pub))
    pub))

;;; ============================================================
;;; Context constructors
;;; ============================================================

(defun make-minimal-context (&key (strategy *test-strategy*)
                                   entity publication)
  "Create a context without theme resolution."
  (make-context :strategy strategy
                :entity entity
                :publication publication))

(defun make-themed-context (&key (strategy *test-strategy*)
                                  entity publication theme-uri theme)
  "Create a context with theme resolution."
  (make-context :strategy strategy
                :entity entity
                :publication publication
                :theme-uri theme-uri
                :theme theme))

(defun make-test-container (&key (strategy *test-strategy*)
                                  (name "Test Container")
                                  entries)
  "Create and persist a classic-container holding ENTRIES (entities),
in the order given."
  (let ((container (make-instance 'classic.schema:classic-container
                     :uri (mint-uri 'classic.schema:classic-container
                                    "test.example" "2026" :slug name)
                     :label name
                     :contains (mapcar #'uri-string entries))))
    (when strategy
      (persist-entity strategy container))
    container))

;;; ============================================================
;;; Hook-driven context
;;; ============================================================
;;; The composer's extension generics (ENTITY-HREF, LENS-PROPERTY-VALUE,
;;; RESOLVE-REFERENCE, CONTAINER-ENTRIES) are specialized here on a
;;; context subclass, so a test drives them through the context's slots
;;; and no method affects any other context.

(defclass hooks-test-context (composition-context)
  ((hrefs :initform nil :accessor test-hrefs
          :documentation "Alist of (entity-uri . href).")
   (computed :initform nil :accessor test-computed
             :documentation "Alist of (property . function of the entity).")
   (references :initform nil :accessor test-references
               :documentation "Alist of (reference-value . entity).")
   (entries :initform nil :accessor test-entries
            :documentation "Function of the container giving its entries,
or NIL for the default."))
  (:documentation "A composition context whose hook methods read its slots."))

(defun make-hooks-context (&key (strategy *test-strategy*)
                                entity theme-uri
                                hrefs computed references entries)
  "Create a hooks-test-context, with theme resolution when THEME-URI
is given. HREFS, COMPUTED, REFERENCES and ENTRIES fill its slots."
  (let ((ctx (make-themed-context :strategy strategy
                                  :entity entity
                                  :theme-uri theme-uri)))
    (change-class ctx 'hooks-test-context)
    (setf (test-hrefs ctx) hrefs
          (test-computed ctx) computed
          (test-references ctx) references
          (test-entries ctx) entries)
    ctx))

(defmethod entity-href ((context hooks-test-context) entity)
  (cdr (assoc (uri-string entity) (test-hrefs context) :test #'equal)))

(defmethod lens-property-value ((context hooks-test-context) entity property)
  (let ((function (cdr (assoc property (test-computed context)))))
    (if function
        (funcall function entity)
        (call-next-method))))

(defmethod resolve-reference ((context hooks-test-context) entity property value)
  (let ((hit (assoc value (test-references context) :test #'equal)))
    (if hit
        (cdr hit)
        (call-next-method))))

(defmethod container-entries ((context hooks-test-context) container)
  (let ((function (test-entries context)))
    (if function
        (funcall function container)
        (call-next-method))))

;;; ============================================================
;;; Tree search
;;; ============================================================

(defun find-nodes (tag-name forms)
  "Return every node in FORMS whose tag's symbol name is TAG-NAME, in
document order. FORMS is a Lexis tree or a list of them. Tags compare
by name, so nodes built from the LEXIS package's symbols are found
too."
  (let ((found nil))
    (dolist (form (if (classic.composer::block-list-p forms) forms (list forms)))
      (walk-tree (lambda (node)
                   (when (and (tagged-node-p node)
                              (string= tag-name (symbol-name (node-tag node))))
                     (push node found)))
                 form))
    (nreverse found)))
