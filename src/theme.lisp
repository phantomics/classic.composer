;;;; theme.lisp — Theme resolution glue
;;;;
;;;; Bridges Classic core's theme ontology with the composer's
;;;; composition pipeline. The core defines what themes *are*
;;;; (classes, chain resolution, merging); this file defines how
;;;; the composer *consumes* them: populating the context with
;;;; resolved theme state, selecting tier templates, validating
;;;; capabilities, and collecting assets.
;;;;
;;;; All schema references use the classic.schema nickname.

(in-package #:classic.composer)

;;; ============================================================
;;; Configuration
;;; ============================================================

(defvar *strict-capabilities* nil
  "When T, validate-theme-capabilities signals an error if any
required capability is not registered. When NIL (default), signals
a warning instead.")

;;; ============================================================
;;; Theme resolution — populate context from theme chain
;;; ============================================================

(defun resolve-theme-for-context (context)
  "Given a context with a theme entity set, resolve the full theme
chain and populate all resolved-theme slots on the context.

Calls the schema's resolution functions:
  - resolve-theme-chain
  - resolve-theme-capabilities
  - resolve-theme-overrides (on the most specific theme)
  - resolve-theme-bindings
  - resolve-theme-slot-fills
  - resolve-theme-lenses

Also gathers the asset manifest chain.

This function is called during make-context when a theme is found.
It is idempotent — calling it again re-resolves from the current theme."
  (let* ((theme (context-theme context))
         (strategy (context-strategy context))
         (chain (classic.schema:resolve-theme-chain theme strategy)))
    (setf (context-theme-chain context) chain)
    (setf (context-theme-capabilities context)
          (classic.schema:resolve-theme-capabilities chain))
    ;; Overrides are per-theme (most specific in chain)
    (setf (context-theme-overrides context)
          (when theme
            (classic.schema:resolve-theme-overrides theme strategy)))
    (setf (context-theme-config context)
          (classic.schema:resolve-theme-bindings chain strategy))
    (setf (context-theme-slot-fills context)
          (classic.schema:resolve-theme-slot-fills chain))
    (setf (context-theme-lenses context)
          (classic.schema:resolve-theme-lenses chain))
    (setf (context-theme-assets context)
          (collect-theme-assets chain))
    context))

;;; ============================================================
;;; Tier template cascade
;;; ============================================================

(defun theme-tier-template (context tier)
  "Return the Lexis template for TIER from the resolved theme.

Cascade:
  1. Per-tier override (classic-theme-override for TIER) -> use its template
  2. Theme's tier-templates alist entry for TIER -> use that
  3. NIL (no theme template for this tier)

TIER is a keyword: :frame, :feature, :adjunct, :aggregate, :operative."
  (let ((overrides (context-theme-overrides context))
        (theme (context-theme context)))
    (or
     ;; 1. Override for this tier
     (let ((override (cdr (assoc tier overrides))))
       (when override
         (classic.schema:override-template override)))
     ;; 2. Tier-templates alist on the theme
     (when theme
       (cdr (assoc tier (classic.schema:tier-templates theme))))
     ;; 3. No template
     nil)))

;;; ============================================================
;;; Theme config -> context bindings
;;; ============================================================

(defun apply-theme-config-to-context (context)
  "Bind scalar theme configuration entries into the context's
bindings with a \"theme.config.\" prefix. This makes theme settings
available to template slots.

A theme config entry (\"primary-color\" . \"#2a5db0\") becomes a
context binding keyed \"theme.config.primary-color\"."
  (dolist (entry (context-theme-config context))
    (let ((key (format nil "theme.config.~A" (car entry)))
          (value (cdr entry)))
      (context-bind context key value)))
  context)

;;; ============================================================
;;; Theme slot-fills -> context bindings
;;; ============================================================

(defun apply-theme-slot-fills-to-context (context)
  "Bind resolved theme slot-fills into the context's bindings.
Each slot-fill (\"theme.brand\" . <lexis-subtree>) is bound directly
by its slot name, making it available for template slot resolution.

A NIL fill value is treated as 'no contribution' and not bound,
which causes the template slot to be removed during resolution
(the default remove-unresolved behavior)."
  (dolist (entry (context-theme-slot-fills context))
    (let ((name (car entry))
          (value (cdr entry)))
      (when value
        (context-bind context name value))))
  context)

;;; ============================================================
;;; Capability validation
;;; ============================================================

(defun validate-theme-capabilities (context)
  "Check that all capabilities declared in the theme's activation set
are registered with the composer's capability registry. Also check
that any required-capabilities declared by the theme are present in
the activation set.

Behavior depends on *strict-capabilities*:
  T   -> signal an error on any missing capability
  NIL -> signal a warning (default)"
  ;; Check activation set against registry
  (dolist (cap-name (context-theme-capabilities context))
    (unless (find-capability cap-name)
      (let ((msg (format nil "Theme declares capability ~S but no ~
                              handler is registered" cap-name)))
        (if *strict-capabilities*
            (error msg)
            (warn msg)))))
  ;; Check required-capabilities against activation set
  (let ((theme (context-theme context)))
    (when theme
      (let ((required (classic.schema:required-capabilities theme))
            (active (context-theme-capabilities context)))
        (dolist (req required)
          (unless (member req active :test #'equal)
            (let ((msg (format nil "Theme requires capability ~S but ~
                                    it is not in the activation set" req)))
              (if *strict-capabilities*
                  (error msg)
                  (warn msg))))))))
  context)

;;; ============================================================
;;; Asset collection
;;; ============================================================

(defun collect-theme-assets (theme-chain)
  "Walk the theme chain (root to child) and collect all asset
references. Returns a flat list of plists:
  ((:type :stylesheet :uri \"base/main.css\")
   (:type :script :uri \"base/nav.js\")
   ...)

Assets from ancestor themes appear first; child theme assets
appear last (child CSS loads after parent CSS for override semantics)."
  (let ((assets nil))
    (dolist (theme (reverse theme-chain))
      (let ((base (or (classic.schema:asset-base-uri theme) ""))
            (manifest (classic.schema:asset-manifest theme)))
        (when manifest
          (dolist (group manifest)
            (let ((asset-type (car group))
                  (files (cadr group)))
              (dolist (file files)
                (push (list :type (normalize-asset-type asset-type)
                            :uri (concatenate 'string base file))
                      assets)))))))
    (nreverse assets)))

(defun normalize-asset-type (type-keyword)
  "Normalize asset manifest group keywords to singular form."
  (case type-keyword
    (:stylesheets :stylesheet)
    (:scripts :script)
    (:fonts :font)
    (:images :image)
    (t type-keyword)))

(defun theme-asset-list (context)
  "Return the collected assets from the context as a Lexis subtree
suitable for binding to a template.slot. Produces stylesheet and
script reference nodes."
  (let ((assets (context-theme-assets context)))
    (when assets
      (let ((nodes nil))
        (dolist (asset assets)
          (let ((type (getf asset :type))
                (uri (getf asset :uri)))
            (case type
              (:stylesheet
               (push `(stylesheet (@ :uri ,uri)) nodes))
              (:script
               (push `(script (@ :uri ,uri)) nodes))
              ;; Other asset types don't produce Lexis nodes
              ;; (fonts and images are referenced from CSS/content)
              (t nil))))
        (nreverse nodes)))))
