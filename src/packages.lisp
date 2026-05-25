;;;; packages.lisp — Package definition for Classic Composer

(defpackage #:classic.composer
  (:use #:cl)
  (:export

   ;; ---- Composition Context ----
   #:composition-context
   #:context-strategy
   #:context-publication
   #:context-entity
   #:context-theme
   #:context-capabilities
   #:context-bindings
   #:make-context
   #:context-retrieve
   #:context-query
   #:context-bind
   #:context-binding

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
   #:context-collections

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
