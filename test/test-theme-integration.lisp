;;;; test-theme-integration.lisp — Tests for theme resolution integration

(in-package #:classic.composer-tests)

(in-suite theme-integration)

;;; ============================================================
;;; resolve-theme-for-context
;;; ============================================================

(def-test theme-resolution-populates-chain ()
  "resolve-theme-for-context populates the theme-chain slot."
  (with-clean-strategy ()
    (let* ((theme (make-test-theme :name "Root" :capabilities '("frame.hero")))
           (ctx (make-themed-context :theme-uri (uri-string theme))))
      (is (= 1 (length (context-theme-chain ctx))))
      (is (eq theme (first (context-theme-chain ctx)))))))

(def-test theme-resolution-child-chain ()
  "Theme chain includes parent when child has parent-theme."
  (with-clean-strategy ()
    (let* ((parent (make-test-theme :name "Parent"))
           (child (make-test-theme :name "Child"
                    :parent-uri (uri-string parent))))
      (let ((ctx (make-themed-context :theme-uri (uri-string child))))
        (is (= 2 (length (context-theme-chain ctx))))
        ;; Most specific first
        (is (equal "Child" (classic.schema:label
                            (first (context-theme-chain ctx)))))))))

(def-test theme-resolution-populates-capabilities ()
  "Resolved capabilities are merged and stored on context."
  (with-clean-strategy ()
    (let* ((parent (make-test-theme :name "Parent"
                     :capabilities '("frame.hero")))
           (child (make-test-theme :name "Child"
                    :parent-uri (uri-string parent)
                    :capabilities '("frame.sidebar"))))
      (let ((ctx (make-themed-context :theme-uri (uri-string child))))
        (is (= 2 (length (context-theme-capabilities ctx))))
        (is (member "frame.hero" (context-theme-capabilities ctx)
                    :test #'equal))
        (is (member "frame.sidebar" (context-theme-capabilities ctx)
                    :test #'equal))))))

(def-test theme-resolution-capability-exclusion ()
  "Excluded capabilities are removed from the resolved set."
  (with-clean-strategy ()
    (let* ((parent (make-test-theme :name "Parent"
                     :capabilities '("frame.hero" "frame.sidebar")))
           (child (make-test-theme :name "Child"
                    :parent-uri (uri-string parent)
                    :excluded-capabilities '("frame.hero"))))
      (let ((ctx (make-themed-context :theme-uri (uri-string child))))
        (is (= 1 (length (context-theme-capabilities ctx))))
        (is (not (member "frame.hero" (context-theme-capabilities ctx)
                         :test #'equal)))))))

(def-test theme-resolution-populates-lenses ()
  "Resolved lenses are stored on context."
  (with-clean-strategy ()
    (let* ((theme (make-test-theme :name "Lensed"
                    :lenses '((:class classic.schema:classic-article
                               :purpose :default
                               :properties (classic.schema:headline
                                            classic.schema:body))))))
      (let ((ctx (make-themed-context :theme-uri (uri-string theme))))
        (is (not (null (context-theme-lenses ctx))))))))

;;; ============================================================
;;; Tier template cascade
;;; ============================================================

(def-test tier-template-from-tier-templates ()
  "theme-tier-template returns the theme's tier-templates entry."
  (with-clean-strategy ()
    (let* ((frame-tmpl '(document (@ :title "Themed")
                          (template.slot (@ :name "main-content"))))
           (theme (make-test-theme :name "Tmpl"
                    :tier-templates `((:frame . ,frame-tmpl)))))
      (let ((ctx (make-themed-context :theme-uri (uri-string theme))))
        (let ((result (theme-tier-template ctx :frame)))
          (is (not (null result)))
          (is (eq 'document (node-tag result))))))))

(def-test tier-template-override-wins ()
  "A per-tier override takes precedence over tier-templates."
  (with-clean-strategy ()
    (let* ((theme (make-test-theme :name "Base"
                    :tier-templates '((:frame . (document "base")))))
           (override-tmpl '(document "override")))
      (make-test-override :theme-uri (uri-string theme)
                          :tier :frame
                          :template override-tmpl)
      ;; Re-create context to pick up override
      (let* ((ctx (make-themed-context :theme-uri (uri-string theme)))
             (result (theme-tier-template ctx :frame)))
        (is (equal "override" (first (node-children result))))))))

(def-test tier-template-nil-when-no-theme ()
  "theme-tier-template returns NIL when no theme is active."
  (with-clean-strategy ()
    (let ((ctx (make-minimal-context)))
      (is (null (theme-tier-template ctx :frame))))))

;;; ============================================================
;;; Config binding
;;; ============================================================

(def-test apply-theme-config-prefixes-keys ()
  "apply-theme-config-to-context binds config entries with theme.config. prefix."
  (with-clean-strategy ()
    (let* ((theme (make-test-theme :name "Conf")))
      ;; Create bindings resource
      (let ((bindings (make-instance 'classic.schema:classic-theme-bindings
                        :uri (mint-uri 'classic.schema:classic-theme-bindings
                                       "test.example" "2026"
                                       :slug "test-conf")
                        :label "Test Config"
                        :bindings-theme (uri-string theme)
                        :bindings-entries '(("primary-color" . "#ff0000")))))
        (persist-entity *test-strategy* bindings))
      (let ((ctx (make-themed-context :theme-uri (uri-string theme))))
        (apply-theme-config-to-context ctx) ;; must call to apply config
        (is (equal "#ff0000"
                   (context-binding ctx "theme.config.primary-color")))))))

;;; ============================================================
;;; Slot-fills binding
;;; ============================================================

(def-test apply-slot-fills-binds-to-context ()
  "apply-theme-slot-fills-to-context binds fills as context bindings."
  (with-clean-strategy ()
    (let* ((theme (make-test-theme :name "Filled"
                    :slot-fills '(("theme.brand"
                                   . (heading "My Site"))))))
      (let ((ctx (make-themed-context :theme-uri (uri-string theme))))
        (apply-theme-slot-fills-to-context ctx) ;; must call to apply slot-fills
        (let ((fill (context-binding ctx "theme.brand")))
          (is (not (null fill)))
          (is (eq 'heading (node-tag fill))))))))

(def-test apply-slot-fills-nil-skipped ()
  "NIL slot-fill values are not bound (slot remains unfilled)."
  (with-clean-strategy ()
    (let* ((theme (make-test-theme :name "NilFill"
                    :slot-fills '(("theme.empty" . nil)))))
      (let ((ctx (make-themed-context :theme-uri (uri-string theme))))
        (is (null (context-binding ctx "theme.empty")))))))

;;; ============================================================
;;; Capability validation
;;; ============================================================

(def-test validate-warns-on-missing-capability ()
  "validate-theme-capabilities warns when a declared capability is unregistered."
  (with-fresh-registries
    (with-clean-strategy ()
      (let* ((theme (make-test-theme :name "Strict"
                      :capabilities '("nonexistent.capability")))
             (ctx (make-themed-context :theme-uri (uri-string theme))))
        ;; Should warn, not error
        (let ((warned nil))
          (handler-bind ((warning (lambda (c)
                                   (setf warned t)
                                   (muffle-warning c))))
            (validate-theme-capabilities ctx))
          (is-true warned))))))

(def-test validate-errors-in-strict-mode ()
  "validate-theme-capabilities errors in strict mode for missing capabilities."
  (with-fresh-registries
    (with-clean-strategy ()
      (let* ((theme (make-test-theme :name "Strict"
                      :capabilities '("nonexistent.capability")))
             (ctx (make-themed-context :theme-uri (uri-string theme)))
             (*strict-capabilities* t))
        (signals simple-error
          (validate-theme-capabilities ctx))))))

;;; ============================================================
;;; Asset collection
;;; ============================================================

(def-test assets-ordered-parent-first ()
  "Assets from parent themes appear before child theme assets."
  (with-clean-strategy ()
    (let* ((parent (make-test-theme :name "Parent"
                     :asset-base-uri "/parent/"
                     :asset-manifest '((:stylesheets ("base.css")))))
           (child (make-test-theme :name "Child"
                    :parent-uri (uri-string parent)
                    :asset-base-uri "/child/"
                    :asset-manifest '((:stylesheets ("override.css"))))))
      (let ((ctx (make-themed-context :theme-uri (uri-string child))))
        (let ((assets (context-theme-assets ctx)))
          (is (= 2 (length assets)))
          ;; Parent first
          (is (equal "/parent/base.css" (getf (first assets) :uri)))
          (is (equal "/child/override.css" (getf (second assets) :uri))))))))

(def-test theme-asset-list-produces-passthrough-nodes ()
  "theme-asset-list converts asset plists into Lexis passthrough nodes
carrying Spinneret-style HTML link and script forms."
  (with-clean-strategy ()
    (let* ((theme (make-test-theme :name "Assets"
                    :asset-base-uri "/static/"
                    :asset-manifest '((:stylesheets ("main.css"))
                                      (:scripts ("nav.js")))))
           (ctx (make-themed-context :theme-uri (uri-string theme)))
           (nodes (theme-asset-list ctx)))
      (is (= 2 (length nodes)))
      ;; Each node is a passthrough
      (is (string= "PASSTHROUGH"
                   (symbol-name (node-tag (first nodes)))))
      (is (string= "PASSTHROUGH"
                   (symbol-name (node-tag (second nodes)))))
      ;; The :medium attribute targets HTML
      (is (eq :html (get-attr (first nodes) :medium)))
      ;; The :kind attribute distinguishes stylesheet vs script
      (is (eq :stylesheet (get-attr (first nodes) :kind)))
      (is (eq :script (get-attr (second nodes) :kind))))))
