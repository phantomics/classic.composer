;;;; packages.lisp — Package definition for Classic Composer
;;;;
;;;; The composer uses the classic.schema nickname for schema references,
;;;; keeping source compatible with any schema that declares the nickname.
;;;; Foundation symbols (protocols, MOP annotations) are inherited via
;;;; :use #:classic. Schema symbols are explicitly qualified as
;;;; classic.schema:symbol-name throughout the source.

(defpackage #:classic.composer
  (:use #:cl #:classic)
  (:export

   ;; ---- Composition Context ----
   #:composition-context
   #:context-strategy
   #:context-publication
   #:context-entity
   #:context-theme
   #:context-capabilities
   #:context-bindings
   #:context-collections
   #:make-context
   #:context-retrieve
   #:context-query
   #:context-bind
   #:context-binding

   ;; ---- Resolved Theme State (on context) ----
   #:context-theme-chain
   #:context-theme-capabilities
   #:context-theme-overrides
   #:context-theme-config
   #:context-theme-slot-fills
   #:context-theme-lenses
   #:context-theme-assets

   ;; ---- Core Composition Protocol ----
   #:compose-page
   #:compose-frame
   #:compose-feature
   #:compose-adjunct
   #:compose-aggregate
   #:compose-operative

   ;; ---- Template Resolution ----
   #:resolve-slots
   #:template-slot-p
   #:slot-name

   ;; ---- Anchor Registry ----
   #:define-anchor-handler
   #:register-anchor-handler
   #:evaluate-anchors
   #:evaluate-anchor
   #:find-anchor-handler
   #:anchor-p
   #:anchor-name
   #:anchor-params

   ;; ---- Capability Registration ----
   #:define-capability
   #:register-capability
   #:find-capability
   #:list-capabilities
   #:dispatch-capability
   #:capability
   #:capability-name
   #:capability-tier
   #:capability-handler

   ;; ---- Collector Registry (Collect Phase) ----
   #:define-collector
   #:register-collector
   #:find-collector
   #:list-collectors
   #:run-collectors
   #:collect-into
   #:context-collected
   #:context-collected-raw

   ;; ---- Theme Integration ----
   #:resolve-theme-for-context
   #:theme-tier-template
   #:apply-theme-config-to-context
   #:apply-theme-slot-fills-to-context
   #:theme-asset-list
   #:validate-theme-capabilities
   #:*strict-capabilities*

   ;; ---- Lens Evaluation ----
   #:apply-lens
   #:apply-sublens
   #:compute-display-mode
   #:render-slot-via-display-mode

   ;; ---- Lexis Tree Utilities ----
   #:tagged-node-p
   #:node-tag
   #:node-attrs
   #:node-children
   #:text-node-p
   #:get-attr
   #:walk-tree
   #:transform-tree

   ;; ---- Lexis Extension Tag Symbols ----
   ;; Dotted names used as Lexis tags in composer templates.
   ;; Detection uses symbol-name comparison (package-independent).
   #:template.slot
   #:compose.anchor
   #:compose.operative))
