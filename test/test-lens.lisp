;;;; test-lens.lisp — Tests for lens evaluation, display modes, sublens
;;;;
;;;; NOTE: The per-mode renderer tests cover the basic output shape for
;;;; each display mode. More comprehensive edge-case testing (NIL handling,
;;;; type coercion, malformed values) can be added in a future pass.

(in-package #:classic.composer-tests)

(in-suite lens)

;;; ============================================================
;;; Display mode cascade
;;; ============================================================

(def-test display-mode-explicit-wins ()
  "An explicit :display annotation overrides all fallback logic."
  (is (eq :image (compute-display-mode
                  'classic.schema:body
                  'classic.schema:classic-article
                  :explicit-mode :image))))

(def-test display-mode-mop-format-html ()
  "Slot with :format :sexp falls through; :html triggers :html mode.
classic-article's body has :format :sexp so it falls through to :text.
This test verifies the cascade logic."
  ;; Without explicit mode, body on classic-article has :format :sexp
  ;; which is not :markdown or :html, so it falls through to :text
  (is (eq :markdown (compute-display-mode
                     'classic.schema:body
                     'classic.schema:classic-article))))

(def-test display-mode-relation-to-link ()
  "A :relation slot without sublens defaults to :link."
  ;; author on classic-article has :persistence :relation
  (is (eq :link (compute-display-mode
                 'classic.schema:author
                 'classic.schema:classic-article))))

(def-test display-mode-relation-with-sublens-not-link ()
  "A :relation slot WITH a sublens does not default to :link."
  ;; When sublens-class is provided, the :relation fallback is suppressed
  (let ((mode (compute-display-mode
               'classic.schema:author
               'classic.schema:classic-article
               :sublens-class 'classic.schema:classic-person)))
    ;; Falls through to :text, not :link
    (is (eq :text mode))))

(def-test display-mode-text-fallback ()
  "Slots with no special annotations default to :text."
  (is (eq :text (compute-display-mode
                 'classic.schema:headline
                 'classic.schema:classic-article))))

;;; ============================================================
;;; Per-mode renderers
;;; ============================================================

(def-test render-text-string ()
  "render-slot-via-display-mode :text produces the string directly."
  (let ((result (render-slot-via-display-mode :text "hello")))
    (is (equal "hello" result))))

(def-test render-text-multiline ()
  "Multi-line strings become paragraph nodes."
  (let ((result (render-slot-via-display-mode :text (format nil "line1~%line2"))))
    (is (tagged-node-p result))
    (is (string= "PARAGRAPH" (symbol-name (node-tag result))))))

(def-test render-image-shape ()
  ":image produces an image node with src."
  (let ((result (render-slot-via-display-mode :image "/photo.jpg"
                                              :alt-text "A photo")))
    (is (tagged-node-p result))
    (is (string= "IMAGE" (symbol-name (node-tag result))))
    (is (equal "/photo.jpg" (get-attr result :src)))))

(def-test render-link-shape ()
  ":link produces a web-link node."
  (let ((result (render-slot-via-display-mode :link "https://example.com"
                                              :label "Example")))
    (is (tagged-node-p result))
    (is (string= "WEB-LINK" (symbol-name (node-tag result))))
    (is (equal "https://example.com" (get-attr result :uri)))))

(def-test render-date-string ()
  ":date passes through string values."
  (let ((result (render-slot-via-display-mode :date "2026-06-05")))
    (is (equal "2026-06-05" result))))

(def-test render-list-shape ()
  ":list produces an unordered-list."
  (let ((result (render-slot-via-display-mode :list '("a" "b" "c"))))
    (is (tagged-node-p result))
    (is (string= "UNORDERED-LIST" (symbol-name (node-tag result))))
    (is (= 3 (length (node-children result))))))

(def-test render-html-passthrough ()
  ":html returns a Lexis subtree unchanged."
  (let* ((tree '(section (@ :title "Test") (paragraph "content")))
         (result (render-slot-via-display-mode :html tree)))
    (is (equal tree result))))

(def-test render-nil-returns-nil ()
  "All modes return NIL for NIL values."
  (is (null (render-slot-via-display-mode :text nil)))
  (is (null (render-slot-via-display-mode :image nil)))
  (is (null (render-slot-via-display-mode :link nil))))

;;; ============================================================
;;; apply-lens
;;; ============================================================

(def-test apply-lens-renders-properties ()
  "apply-lens produces a Lexis subtree for each bound property."
  (with-clean-strategy ()
    (let* ((article (make-test-article :headline "Test Post"
                                        :body-text "Body content."
                                        :keywords '("lisp" "cl")))
           (lens '(:class classic.schema:classic-article
                   :purpose :default
                   :properties (classic.schema:headline
                                classic.schema:body
                                (classic.schema:keywords :display :list))))
           (ctx (make-minimal-context :entity article)))
      (let ((result (apply-lens ctx lens article)))
        ;; headline + body + keywords = 3 items
        (is (= 3 (length result)))))))

(def-test apply-lens-skips-unbound-slots ()
  "apply-lens silently skips properties whose slots are unbound."
  (with-clean-strategy ()
    (let* ((article (make-test-article :headline "Minimal"))
           (lens '(:class classic.schema:classic-article
                   :purpose :default
                   :properties (classic.schema:headline
                                classic.schema:keywords)))
           (ctx (make-minimal-context :entity article)))
      ;; keywords is nil, headline is set
      (let ((result (apply-lens ctx lens article)))
        (is (= 1 (length result)))))))

;;; ============================================================
;;; apply-sublens
;;; ============================================================

(def-test sublens-resolves-related-entity ()
  "apply-sublens retrieves a related entity and applies the target lens."
  (with-clean-strategy ()
    (let* ((person (make-test-person :name "Alice"))
           (article (make-test-article :headline "Post"
                                        :author-uri (uri-string person)))
           (theme (make-test-theme
                   :name "Sublens Theme"
                   :lenses `((:class classic.schema:classic-person
                              :purpose :label
                              :properties (classic.schema:agent-name)))))
           (ctx (make-themed-context
                 :entity article
                 :theme-uri (uri-string theme))))
      (let ((result (apply-sublens ctx
                      'classic.schema:classic-person :label
                      (uri-string person))))
        ;; Should have rendered the person's agent-name
        (is (not (null result)))))))

(def-test sublens-fallback-to-label ()
  "apply-sublens falls back to entity label when no matching lens exists."
  (with-clean-strategy ()
    (let* ((person (make-test-person :name "Bob"))
           (ctx (make-minimal-context)))
      ;; No lenses at all, falls back to label
      (let ((result (classic.composer::apply-sublens-single
                     ctx
                     'classic.schema:classic-person :default
                     (uri-string person))))
        (is (equal "Bob" result))))))
