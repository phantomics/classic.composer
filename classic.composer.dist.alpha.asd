;;;; classic.composer.dist.alpha.asd — Distribution shim for Composer + Alpha
;;;;
;;;; A thin meta-system that bundles the Classic Composer with the alpha
;;;; distribution and common content models. This is the user-facing entry
;;;; point: load one system to get a complete composition environment.
;;;;
;;;; A future classic.composer.dist.beta would substitute the beta schema
;;;; and distribution, loading the same composer source against different
;;;; ontological vocabulary.

(asdf:defsystem "classic.composer.dist.alpha"
  :description "Classic Composer bundled with the alpha distribution"
  :version "0.2.0"
  :license "BSD-3"
  :depends-on ("classic.dist.alpha"
               "classic.models.common"
               "classic.composer"))
