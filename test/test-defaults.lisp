;;;; test-defaults.lisp — Tests for default compose-page pipeline and tier methods

(in-package #:classic.composer-tests)

(in-suite defaults)

;;; ============================================================
;;; compose-frame
;;; ============================================================

(def-test compose-frame-default-produces-document ()
  "Default compose-frame produces a document node with template slots."
  (with-clean-strategy ()
    (let* ((article (make-test-article :headline "Test"))
           (ctx (make-minimal-context :entity article)))
      (let ((frame (compose-frame ctx)))
        (is (tagged-node-p frame))
        (is (eq 'document (node-tag frame)))))))

(def-test compose-frame-uses-theme-template ()
  "compose-frame uses the theme's :frame tier-template when available."
  (with-clean-strategy ()
    (let* ((frame-tmpl '(document (@ :title "Themed Page")
                          (navigation "Nav")
                          (template.slot (@ :name "main-content"))
                          (footer "Foot")))
           (theme (make-test-theme :name "Framed"
                    :tier-templates `((:frame . ,frame-tmpl))))
           (ctx (make-themed-context :theme-uri (uri-string theme))))
      (let ((result (compose-frame ctx)))
        (is (equal "Themed Page" (get-attr result :title)))))))

;;; ============================================================
;;; compose-feature
;;; ============================================================

(def-test compose-feature-body-extraction ()
  "compose-feature extracts body from entity when no lens available."
  (with-clean-strategy ()
    (let* ((article (make-test-article :headline "Post"
                                        :body-text "Body content."))
           (ctx (make-minimal-context :entity article)))
      (let ((feature (compose-feature ctx)))
        (is (not (null feature)))
        (is (tagged-node-p feature))))))

(def-test compose-feature-lexis-body-passthrough ()
  "compose-feature passes through a Lexis s-expression body directly."
  (with-clean-strategy ()
    (let* ((article (make-test-article :headline "Lexis Post"))
           (ctx (make-minimal-context :entity article)))
      ;; Set body to a Lexis tree
      (setf (classic.schema:body article)
            '(section (@ :title "Content")
               (paragraph "Structured.")))
      (let ((feature (compose-feature ctx)))
        (is (eq 'section (node-tag feature)))))))

(def-test compose-feature-nil-without-entity ()
  "compose-feature returns NIL when no entity is set."
  (with-clean-strategy ()
    (let ((ctx (make-minimal-context)))
      (is (null (compose-feature ctx))))))

(def-test compose-feature-lens-driven ()
  "compose-feature uses a lens when the theme provides one."
  (with-clean-strategy ()
    (let* ((article (make-test-article :headline "Lensed Post"
                                        :body-text "Content."
                                        :keywords '("lisp")))
           (theme (make-test-theme
                   :name "Lens Theme"
                   :lenses `((:class classic.schema:classic-article
                              :purpose :default
                              :properties (classic.schema:headline
                                           classic.schema:body)))))
           (ctx (make-themed-context
                 :entity article
                 :theme-uri (uri-string theme))))
      (let ((feature (compose-feature ctx)))
        ;; Lens-driven: should produce a section wrapping lens output
        (is (not (null feature)))
        (is (tagged-node-p feature))
        ;; Should have children from the lens properties
        (is (>= (length (node-children feature)) 1))))))

;;; ============================================================
;;; compose-aggregate
;;; ============================================================

(def-test compose-aggregate-walks-container ()
  "Default compose-aggregate walks a classic-container's contents."
  (with-clean-strategy ()
    (let* ((a1 (make-test-article :headline "First Post"))
           (a2 (make-test-article :headline "Second Post"))
           (container (make-instance 'classic.schema:classic-container
                        :uri (mint-uri 'classic.schema:classic-container
                                       "test.example" "2026"
                                       :slug "posts")
                        :label "Posts"
                        :contains (list (uri-string a1)
                                        (uri-string a2)))))
      (persist-entity *test-strategy* container)
      (let* ((ctx (make-minimal-context :entity container))
             (result (compose-aggregate ctx)))
        ;; Should produce a section wrapping the entries
        (is (tagged-node-p result))
        (is (string= "SECTION" (symbol-name (node-tag result))))
        ;; Two entries -- each wrapped in a section
        (let ((children (node-children result)))
          (is (= 2 (length children))))))))

(def-test compose-aggregate-uses-summary-lens ()
  "Default compose-aggregate uses :summary lens when available."
  (with-clean-strategy ()
    (let* ((a1 (make-test-article :headline "Lensed Post"))
           (container (make-instance 'classic.schema:classic-container
                        :uri (mint-uri 'classic.schema:classic-container
                                       "test.example" "2026"
                                       :slug "lens-posts")
                        :label "Lens Posts"
                        :contains (list (uri-string a1))))
           (theme (make-test-theme
                   :name "Summary Theme"
                   :lenses `((:class classic.schema:classic-article
                              :purpose :summary
                              :properties (classic.schema:headline))))))
      (persist-entity *test-strategy* container)
      (let* ((ctx (make-themed-context
                   :entity container
                   :theme-uri (uri-string theme)))
             (result (compose-aggregate ctx)))
        (is (tagged-node-p result))
        ;; The entry should contain something rendered from the lens
        (let* ((entry (first (node-children result)))
               (entry-content (node-children entry)))
          (is (not (null entry-content))))))))

(def-test compose-aggregate-nil-without-container ()
  "compose-aggregate returns NIL when entity is not a container
and no theme template is provided."
  (with-clean-strategy ()
    (let* ((article (make-test-article :headline "Just an article"))
           (ctx (make-minimal-context :entity article)))
      (is (null (compose-aggregate ctx))))))

;;; ============================================================
;;; compose-page pipeline
;;; ============================================================

(def-test compose-page-produces-document ()
  "compose-page returns a Lexis document s-expression."
  (with-fresh-registries
    (with-clean-strategy ()
      (let* ((article (make-test-article :headline "Pipeline Test"
                                          :body-text "Content."))
             (ctx (make-minimal-context :entity article)))
        (let ((page (compose-page ctx)))
          (is (tagged-node-p page))
          (is (eq 'document (node-tag page))))))))

(def-test compose-page-integrates-feature ()
  "compose-page embeds feature content into the frame."
  (with-fresh-registries
    (with-clean-strategy ()
      (let* ((article (make-test-article :headline "Integrated"
                                          :body-text "Body here."))
             (ctx (make-minimal-context :entity article)))
        (let ((page (compose-page ctx)))
          ;; The page should contain the article content somewhere
          ;; in its tree (feature was bound to main-content slot)
          (let ((found nil))
            (walk-tree (lambda (node)
                         (when (and (text-node-p node)
                                    (equal "Body here." node))
                           (setf found t)))
                       page)
            (is-true found)))))))

(def-test compose-page-without-entity ()
  "compose-page works without an entity (empty page with frame only)."
  (with-fresh-registries
    (with-clean-strategy ()
      (let ((ctx (make-minimal-context)))
        (finishes (compose-page ctx))))))

(def-test compose-page-with-theme ()
  "compose-page uses theme templates and binds theme state."
  (with-fresh-registries
    (with-clean-strategy ()
      (let* ((frame-tmpl '(document (@ :title "Themed")
                            (template.slot (@ :name "main-content"))
                            (footer "themed footer")))
             (theme (make-test-theme :name "Page Theme"
                      :tier-templates `((:frame . ,frame-tmpl))))
             (article (make-test-article :headline "Themed Post"
                                          :body-text "Content."))
             (ctx (make-themed-context
                   :entity article
                   :theme-uri (uri-string theme))))
        (let ((page (compose-page ctx)))
          ;; Should have the themed footer
          (let ((found nil))
            (walk-tree (lambda (node)
                         (when (and (text-node-p node)
                                    (equal "themed footer" node))
                           (setf found t)))
                       page)
            (is-true found)))))))

(def-test compose-page-anchors-evaluated ()
  "compose-page evaluates anchors in the composed tree."
  (with-fresh-registries
    (with-clean-strategy ()
      (let ((ctx (make-minimal-context)))
        (define-anchor-handler "test-inject" (ctx entity params)
          (declare (ignore ctx entity params))
          '(paragraph "injected"))
        ;; Override frame to include an anchor
        ;; (defmethod compose-frame ((context composition-context))
        ;;   '(document
        ;;     (compose.anchor (@ :name "test-inject"))))
        (context-bind ctx "main-content"
                      '(document (compose.anchor (@ :name "test-inject"))))
        (let ((page (compose-page ctx)))
          (let ((found nil))
            (walk-tree (lambda (node)
                         (when (and (text-node-p node)
                                    (equal "injected" node))
                           (setf found t)))
                       page)
            (is-true found)))
        ;; Clean up the method override
        ;; (remove-method #'compose-frame
        ;;                (find-method #'compose-frame nil
        ;;                             (list (find-class 'composition-context))))

        ))))

(def-test compose-page-collectors-run ()
  "compose-page runs collectors before anchor evaluation."
  (with-fresh-registries
    (with-clean-strategy ()
      (let* ((article (make-test-article :headline "Collected"))
             (ctx (make-minimal-context :entity article)))
        (define-collector "test-sections" (ctx node)
          (when (and (tagged-node-p node)
                     (string= "SECTION" (symbol-name (node-tag node))))
            (collect-into ctx "test-sections" t)))
        (compose-page ctx)
        ;; The feature wraps body in a section, so at least 1 section
        (is (>= (length (context-collected ctx "test-sections")) 1))))))
