;;;; classic.composer.asd — ASDF system definition for Classic Composer
;;;;
;;;; The composer is an accessory system to Classic's core. It assembles
;;;; content for display by querying Classic's persistence layer, applying
;;;; templates, evaluating anchors, and producing Lexis s-expression trees
;;;; ready for rendering.
;;;;
;;;; The composer is read-only with respect to Classic's data. It consumes
;;;; the persistence protocol (retrieve-entity, query-relation, blob access)
;;;; but does not write to it.

(asdf:defsystem "classic.composer"
  :description "Content composition engine for the Classic publishing framework"
  :version "0.1.0"
  :license "BSD-3"
  :depends-on ("classic")
  :pathname "src/"
  :serial t
  :components
  ((:file "packages")
   (:file "context")
   (:file "protocol")
   (:file "capability")
   (:file "template")
   (:file "anchor")
   (:file "defaults")))
