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

(def-test render-html-passthrough-list ()
  ":html returns a list of Lexis nodes unchanged, for the caller to
splice, rather than wrapping it in an untitled section."
  (let* ((forms '((section (@ :title "One") (paragraph "a"))
                  (section (@ :title "Two") (paragraph "b"))))
         (result (render-slot-via-display-mode :html forms)))
    (is (equal forms result))))

(def-test render-nil-returns-nil ()
  "All modes return NIL for NIL values."
  (is (null (render-slot-via-display-mode :text nil)))
  (is (null (render-slot-via-display-mode :image nil)))
  (is (null (render-slot-via-display-mode :link nil)))
  (is (null (render-slot-via-display-mode :markdown nil))))

;;; ============================================================
;;; :markdown display mode
;;; ============================================================

(def-test render-markdown-single-block ()
  "Markdown text that yields one block renders as that block, with its
inline markup read by the Markdown reader."
  (let ((result (render-slot-via-display-mode :markdown "Some *text*.")))
    (is (tagged-node-p result))
    (is (string= "PARAGRAPH" (symbol-name (node-tag result))))
    (is (= 1 (length (find-nodes "EMPHASIS" result))))))

(def-test render-markdown-blocks-are-spliceable ()
  "Markdown text that yields several blocks renders as a list of them,
with headings as titled sections, and no untitled wrapper section."
  (let ((result (render-slot-via-display-mode
                 :markdown
                 (format nil "Intro.~%~%## Details~%~%More text."))))
    (is-true (classic.composer::block-list-p result))
    (is (= 2 (length result)))
    (is (string= "PARAGRAPH" (symbol-name (node-tag (first result)))))
    (let ((section (second result)))
      (is (string= "SECTION" (symbol-name (node-tag section))))
      (is (equal "Details" (get-attr section :title)))
      (is (equal "details" (get-attr section :id))))
    (is (null (remove-if-not (lambda (s) (get-attr s :class))
                             (find-nodes "SECTION" result))))))

(def-test render-markdown-block-constructs ()
  "Lists, fenced code blocks and block quotes become their Lexis tags."
  (let ((result (render-slot-via-display-mode
                 :markdown
                 (format nil "- one~%- two~%~%```lisp~%(car x)~%```~%~%> quoted"))))
    (is (= 1 (length (find-nodes "UNORDERED-LIST" result))))
    (is (= 2 (length (find-nodes "ITEM" result))))
    (let ((code (find-nodes "CODE-BLOCK" result)))
      (is (= 1 (length code)))
      (is (equal "lisp" (get-attr (first code) :language))))
    (is (= 1 (length (find-nodes "BLOCKQUOTE" result))))))

(def-test render-markdown-forum-quote ()
  "A forum quote body -- a quoted attribution and text, then a reply --
gives a block quote holding the attribution in strong, then a paragraph."
  (let ((result (render-slot-via-display-mode
                 :markdown
                 (format nil "> **bobcat wrote:**~%> DEFCLASS.~%~%Agreed."))))
    (is (= 2 (length result)))
    (is (string= "BLOCKQUOTE" (symbol-name (node-tag (first result)))))
    (is (equal '("bobcat wrote:")
               (node-children (first (find-nodes "STRONG" (first result))))))
    (is (string= "PARAGRAPH" (symbol-name (node-tag (second result)))))))

(def-test render-markdown-escapes-raw-html ()
  "Raw HTML in Markdown is kept as text by default, never passed through."
  (let ((result (render-slot-via-display-mode
                 :markdown "Hello <script>alert(1)</script> world.")))
    (is (null (find-nodes "PASSTHROUGH" result)))
    (let ((text (with-output-to-string (s)
                  (walk-tree (lambda (n) (when (stringp n) (write-string n s)))
                             result))))
      (is-true (search "<script>" text)))))

(def-test render-markdown-removes-unsafe-links ()
  "A link with a javascript: URI is replaced by its text; an https
link is kept."
  (let ((unsafe (render-slot-via-display-mode
                 :markdown "Click [here](javascript:alert(1)) now."))
        (safe (render-slot-via-display-mode
               :markdown "See [docs](https://example.com).")))
    (is (null (find-nodes "WEB-LINK" unsafe)))
    (is (equal '("Click here now.") (node-children unsafe)))
    (let ((links (find-nodes "WEB-LINK" safe)))
      (is (= 1 (length links)))
      (is (equal "https://example.com" (get-attr (first links) :uri))))))

(def-test render-markdown-empty-text ()
  "Markdown text holding no blocks renders as NIL."
  (is (null (render-slot-via-display-mode :markdown ""))))

(def-test markdown-options-default ()
  "The default MARKDOWN-OPTIONS method supplies no options, so wiki
links get the reader's default resolver, a cross-ref."
  (is (null (markdown-options nil nil 'classic.schema:body)))
  (let ((result (render-slot-via-display-mode :markdown "See [[Home]].")))
    (is (= 1 (length (find-nodes "CROSS-REF" result))))
    (is (null (find-nodes "WEB-LINK" result)))))

(defmethod markdown-options (context entity
                             (slot-name (eql 'markdown-options-test-slot)))
  (declare (ignore context entity))
  (list :wiki-link-resolver
        (lambda (target display)
          `(lexis::web-link
            (lexis::@ :uri ,(format nil "/wiki/~(~A~)" target))
            ,display))))

(def-test markdown-options-specialized ()
  "A MARKDOWN-OPTIONS method's options reach the reader: its wiki link
resolver replaces the default."
  (let ((result (render-slot-via-display-mode
                 :markdown "See [[Home|the home page]]."
                 :slot-name 'markdown-options-test-slot)))
    (is (null (find-nodes "CROSS-REF" result)))
    (let ((links (find-nodes "WEB-LINK" result)))
      (is (= 1 (length links)))
      (is (equal "/wiki/home" (get-attr (first links) :uri)))
      (is (equal '("the home page") (node-children (first links)))))))

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

(def-test apply-lens-splices-markdown-blocks ()
  "apply-lens splices the blocks of a multi-block Markdown body into its
result, after the properties before it, with no wrapper section."
  (with-clean-strategy ()
    (let* ((article (make-test-article
                     :headline "Spliced"
                     :body-text (format nil "First.~%~%## Part~%~%Second.")))
           (lens '(:class classic.schema:classic-article
                   :purpose :default
                   :properties (classic.schema:headline
                                classic.schema:body)))
           (ctx (make-minimal-context :entity article)))
      (let ((result (apply-lens ctx lens article)))
        ;; headline + paragraph + titled section
        (is (= 3 (length result)))
        (is (equal "Spliced" (first result)))
        (is (string= "PARAGRAPH" (symbol-name (node-tag (second result)))))
        (is (equal "Part" (get-attr (third result) :title)))))))

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

(def-test sublens-follows-resolve-reference ()
  "A sublens follows a reference through RESOLVE-REFERENCE, so a value
that is not a URI, such as a name, reaches its entity when a method
resolves it."
  (with-clean-strategy ()
    (let* ((person (make-test-person :name "Alice"))
           (article (make-test-article :headline "Post"
                                       :author-uri "alice-by-name"))
           (theme (make-test-theme
                   :name "Reference Theme"
                   :lenses `((:class classic.schema:classic-person
                              :purpose :label
                              :properties (classic.schema:agent-name)))))
           (ctx (make-hooks-context
                 :entity article
                 :theme-uri (uri-string theme)
                 :references `(("alice-by-name" . ,person))))
           (prop '(:slot classic.schema:author
                   :sublens classic.schema:classic-person :purpose :label)))
      (is (equal "Alice" (render-lens-property ctx article prop))))))

;;; ============================================================
;;; Lens property values
;;; ============================================================

(def-test lens-property-value-reads-slots ()
  "The default LENS-PROPERTY-VALUE reads a bound slot, and gives NIL
for a property that is not a slot."
  (with-clean-strategy ()
    (let ((article (make-test-article :headline "Slots"))
          (ctx (make-minimal-context)))
      (is (equal "Slots" (lens-property-value ctx article
                                              'classic.schema:headline)))
      (is (null (lens-property-value ctx article 'no-such-property))))))

(def-test computed-property-in-lens ()
  "A lens names a computed property as it names a slot; a
LENS-PROPERTY-VALUE method supplies its value, rendered as text."
  (with-clean-strategy ()
    (let* ((article (make-test-article :headline "Counted"
                                       :body-text "three short words"))
           (lens '(:class classic.schema:classic-article
                   :properties (classic.schema:headline word-count)))
           (ctx (make-hooks-context
                 :computed `((word-count
                              . ,(lambda (entity)
                                   (1+ (count #\Space
                                              (classic.schema:body entity)))))))))
      (is (equal '("Counted" "3") (apply-lens ctx lens article))))))

;;; ============================================================
;;; Property options: :link :self and :label
;;; ============================================================

(def-test link-self-links-to-entity-page ()
  ":LINK :SELF links a property's value to the page ENTITY-HREF gives
for its entity."
  (with-clean-strategy ()
    (let* ((article (make-test-article :headline "Linked"))
           (ctx (make-hooks-context
                 :hrefs `((,(uri-string article) . "linked.html"))))
           (result (render-lens-property
                    ctx article '(:slot classic.schema:headline :link :self))))
      (is (string= "WEB-LINK" (symbol-name (node-tag result))))
      (is (equal "linked.html" (get-attr result :uri)))
      (is (equal '("Linked") (node-children result))))))

(def-test link-self-without-page-is-plain ()
  ":LINK :SELF leaves the value unlinked when the entity has no page."
  (with-clean-strategy ()
    (let ((article (make-test-article :headline "Unlinked"))
          (ctx (make-minimal-context)))
      (is (equal "Unlinked"
                 (render-lens-property
                  ctx article '(:slot classic.schema:headline :link :self)))))))

(def-test label-captions-inline-and-block-values ()
  ":LABEL captions an inline value in one paragraph, and puts the
caption in a paragraph before a block value."
  (with-clean-strategy ()
    (let ((article (make-test-article :headline "Captioned"
                                      :keywords '("a" "b")))
          (ctx (make-minimal-context)))
      (let ((inline (render-lens-property
                     ctx article '(:slot classic.schema:headline :label "Title"))))
        (is (string= "PARAGRAPH" (symbol-name (node-tag inline))))
        (is (equal '("Title:") (node-children (first (node-children inline)))))
        (is (equal '(" " "Captioned") (rest (node-children inline)))))
      (let ((block (render-lens-property
                    ctx article '(:slot classic.schema:keywords
                                  :display :list :label "Keywords"))))
        (is-true (classic.composer::block-list-p block))
        (is (string= "PARAGRAPH" (symbol-name (node-tag (first block)))))
        (is (equal '("Keywords")
                   (node-children (first (find-nodes "STRONG" (first block))))))
        (is (string= "UNORDERED-LIST"
                     (symbol-name (node-tag (second block)))))))))

;;; ============================================================
;;; The :link display mode follows references
;;; ============================================================

(def-test link-mode-links-to-referenced-page ()
  "In the :link mode a resolved reference links to the target's page,
shown by the target's title."
  (with-clean-strategy ()
    (let* ((person (make-test-person :name "Alice"))
           (article (make-test-article :headline "Post"
                                       :author-uri (uri-string person)))
           (ctx (make-hooks-context
                 :hrefs `((,(uri-string person) . "alice.html"))))
           (result (render-lens-property
                    ctx article '(:slot classic.schema:author :display :link))))
      (is (equal "alice.html" (get-attr result :uri)))
      (is (equal '("Alice") (node-children result))))))

(def-test link-mode-without-page-links-to-uri ()
  "In the :link mode a resolved reference with no page links to the
reference's URI, still shown by the target's title."
  (with-clean-strategy ()
    (let* ((person (make-test-person :name "Alice"))
           (article (make-test-article :headline "Post"
                                       :author-uri (uri-string person)))
           (ctx (make-minimal-context))
           (result (render-lens-property
                    ctx article '(:slot classic.schema:author :display :link))))
      (is (equal (uri-string person) (get-attr result :uri)))
      (is (equal '("Alice") (node-children result))))))

(def-test link-mode-unresolved-name-is-text ()
  "In the :link mode a reference that resolves to nothing and is not a
URI, such as the name of a missing page, renders as text."
  (with-clean-strategy ()
    (let ((article (make-test-article :headline "Post"
                                      :author-uri "Nobody Here"))
          (ctx (make-minimal-context)))
      (is (equal "Nobody Here"
                 (render-lens-property
                  ctx article '(:slot classic.schema:author :display :link)))))))

(def-test uri-like-values ()
  "URIs and URI references read as URIs; names with spaces do not."
  (is-true (classic.composer::uri-like-p "classic:x,2026:pages/a"))
  (is-true (classic.composer::uri-like-p "https://example.com/"))
  (is-true (classic.composer::uri-like-p "/wiki/a"))
  (is-true (classic.composer::uri-like-p "#top"))
  (is-true (classic.composer::uri-like-p "../a.html"))
  (is-false (classic.composer::uri-like-p "Jay Miner"))
  (is-false (classic.composer::uri-like-p "page.html"))
  (is-false (classic.composer::uri-like-p "")))
