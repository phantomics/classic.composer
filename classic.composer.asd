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
;;;;
;;;; Schema references use the classic.schema nickname so the same source
;;;; works against any schema variant. The ASDF dependency names the alpha
;;;; schema explicitly; a future classic.composer.dist.beta would substitute
;;;; classic.schema.beta here.

(asdf:defsystem "classic.composer"
  :description "Content composition engine for the Classic publishing framework"
  :version "0.2.0"
  :license "BSD-3"
  :depends-on ("classic" "classic.schema.alpha" "closer-mop")
  :pathname "src/"
  :serial t
  :components
  ((:file "packages")
   (:file "context")
   (:file "protocol")
   (:file "capability")
   (:file "template")
   (:file "anchor")
   (:file "collector")
   (:file "theme")
   (:file "lens")
    (:file "defaults")))

(asdf:defsystem "classic.composer/tests"
  :description "Test suite for Classic Composer"
  :depends-on ("classic.composer"
               "classic.composer.dist.alpha"
               "fiveam"
               "hamcrest/fiveam")
  :pathname "test/"
  :serial t
  :components
  ((:file "package")
   (:file "helpers")
   (:file "test-tree-utils")
   (:file "test-context")
   (:file "test-template")
   (:file "test-anchor")
   (:file "test-collector")
   (:file "test-capability")
   (:file "test-theme-integration")
   (:file "test-lens")
   (:file "test-defaults")))
