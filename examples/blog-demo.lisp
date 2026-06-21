;;;; blog-demo.lisp -- Self-contained Classic Composer demo
;;;;
;;;; Renders two HTML pages from blog content using a single theme:
;;;;
;;;;   1. An individual blog post page
;;;;   2. A blog post index page (list of recent posts)
;;;;
;;;; To run from a fresh REPL:
;;;;
;;;;   (ql:quickload "classic.composer.dist.alpha")
;;;;   (ql:quickload "lexis.html")
;;;;   (load "examples/blog-demo.lisp")
;;;;   (classic.composer.demo:run-demo)
;;;;
;;;; The demo writes two HTML files under doc/demos/:
;;;;   blog-post-output.html  -- single-post page
;;;;   blog-list-output.html  -- index page
;;;;
;;;; A reference stylesheet is shipped at examples/static/blog.css.

(defpackage #:classic.composer.demo
  (:use #:cl
        #:classic
        #:classic.composer
        #:classic.dist.alpha
        #:classic.models.common)
  (:shadow #:label #:description #:body)
  (:export #:run-demo
           #:setup-blog
           #:setup-theme
           #:render-post-page
           #:render-list-page))

(in-package #:classic.composer.demo)

;;; ============================================================
;;; Source-relative paths
;;; ============================================================
;;;
;;; Capture this file's directory at load time so RUN-DEMO can write
;;; output files relative to the project root regardless of the
;;; calling environment.

(defparameter *demo-source-directory*
  (make-pathname
   :directory (pathname-directory
               (or *load-pathname*
                   *compile-file-pathname*
                   #.(or *compile-file-pathname* *load-pathname*)))))

;;; ============================================================
;;; Step 1: Build a blog with three posts
;;; ============================================================
;;;
;;; The blog model from classic.models.common provides workflow,
;;; accounts, and a posts container. We bypass the publish workflow
;;; for the demo (writer-only mode) and store Lexis-formatted bodies
;;; directly on the article entities.

(defvar *blog* nil
  "The demo blog struct, populated by SETUP-BLOG.")

(defvar *theme* nil
  "The demo theme entity, populated by SETUP-THEME.")

;; Three sample post bodies as Lexis s-expressions. In production
;; these would be authored through a Lexis-aware editor (Seed) or
;; transformed from Markdown. Here we hand-write them.

(defparameter +post-bodies+
  '(("Why Lisp Endures"
     ((:keywords ("lisp" "history" "programming"))
      (:body
       (section (@ :title "Homoiconicity" :id "homoiconicity")
         (paragraph "Lisp's code-as-data property means the language can "
                    (emphasis "transform itself") ". Macros are not text "
                    "substitution -- they are programs that write programs, "
                    "operating on the same data structures the runtime uses."))
       (section (@ :title "CLOS" :id "clos")
         (paragraph "The Common Lisp Object System provides "
                    (strong "multiple dispatch") ", method combination, and "
                    "a metaobject protocol that lets you redefine the rules "
                    "of object orientation itself."))
       (section (@ :title "The Condition System" :id "conditions")
         (paragraph "Unlike exception systems that unwind the stack, "
                    "Common Lisp's condition system lets the "
                    (emphasis "caller") " decide how to handle errors "
                    "without destroying the context where the error "
                    "occurred.")))))
    ("On Composable Architecture"
     ((:keywords ("architecture" "design" "composition"))
      (:body
       (section (@ :title "Building from Pieces" :id "pieces")
         (paragraph "A composable system gives you small parts with "
                    "well-defined interfaces. The whole becomes whatever "
                    "you assemble. The Classic framework treats publication "
                    "structure this way: blogs, forums, and wikis are "
                    "different arrangements of the same primitives."))
       (section (@ :title "Why It Matters" :id "matters")
         (paragraph "Composition over configuration. When the system can "
                    "express your specific case as a combination of "
                    "general-purpose pieces, you stop fighting the "
                    "framework. You build with it instead.")))))
    ("Notes on Reading Old Code"
     ((:keywords ("learning" "code-review"))
      (:body
       (section (@ :title "Patience" :id "patience")
         (paragraph "Old code carries decisions you didn't make for "
                    "reasons no longer documented. The path to "
                    "understanding starts with assuming the original "
                    "author was sensible -- usually they were."))
       (section (@ :title "Active Reading" :id "reading")
         (paragraph "Trace what calls what. Follow the data. Look for "
                    "comments that explain why, not what. The shape of "
                    "the code holds clues that the syntax does not.")))))))

(defun setup-blog ()
  "Create the demo blog, accounts, and three posts. Stores the blog
in *BLOG*. Returns the blog struct."
  (let ((blog (make-blog :name "Demo Blog"
                         :authority "demo.composer"
                         :authority-date "2026")))
    (let ((alice (create-account blog :name "Alice" :role :writer)))
      (dolist (entry +post-bodies+)
        (let* ((title (first entry))
               (data (second entry))
               (keywords (cadr (assoc :keywords data)))
               ;; The body assoc entry is (:body section1 section2 ...);
               ;; we want the list of sections after the keyword.
               (body-sections (cdr (assoc :body data))))
          ;; write-article stores the post; it accepts a string text
          ;; argument, so we pass a placeholder and overwrite the body.
          (write-article blog
                         :account alice
                         :title title
                         :text "(placeholder)"
                         :categories keywords)
          (let ((post (first (get-articles blog))))
            ;; Replace the body with the structured Lexis form. In a
            ;; production system this happens at write time; the demo
            ;; does it explicitly so the data flow is visible.
            ;; The body is stored as a list of top-level sections;
            ;; the lens body property with :display :html knows how
            ;; to render a list of nodes.
            (setf (classic.schema:body post) body-sections)
            (persist-entity (imprint-strategy blog) post)))))
    (setf *blog* blog)
    blog))

;;; ============================================================
;;; Step 2: Define the demo theme
;;; ============================================================
;;;
;;; A single theme handles both pages. It provides:
;;;
;;;   - A frame template with header + main-content slot + footer.
;;;     The frame includes a (template.slot :name "theme.assets")
;;;     in the document where stylesheet/script passthrough nodes
;;;     will be spliced.
;;;
;;;   - An asset manifest pointing to the reference stylesheet.
;;;
;;;   - Lenses for blog-article (:default for the post page,
;;;     :summary for index entries) and classic-person (:label
;;;     for inline author references).

(defun setup-theme (blog)
  "Create the demo theme, attach it to the blog's publication, and
return the theme entity. Stores in *THEME*."
  (let* ((strategy (imprint-strategy blog))
         (frame-template
           '(document (@ :title (template.slot (@ :name "page-title")))
              (template.slot (@ :name "theme.assets"))
              (template.slot (@ :name "theme.brand"))
              (template.slot (@ :name "main-content"))
              (template.slot (@ :name "aggregate-content"))
              (template.slot (@ :name "theme.footer"))))
         (slot-fills
           '(("theme.brand"
              . (section (@ :class "site-header")
                  (paragraph (strong "Demo Blog"))
                  (paragraph "A Classic Composer demonstration.")))
             ("theme.footer"
              . (section (@ :class "site-footer")
                  (paragraph "(c) 2026 Demo Blog. "
                             "Powered by "
                             (web-link (@ :uri "https://example.com/classic")
                                       "Classic")
                             "."))))))
    (let ((theme (make-instance 'classic.schema:classic-theme
                   :uri (mint-uri 'classic.schema:classic-theme
                                  "demo.composer" "2026"
                                  :slug "demo-theme")
                   :label "Demo Theme"
                   :theme-version "1.0"
                   :tier-templates `((:frame . ,frame-template))
                   :slot-fills slot-fills
                   :asset-base-uri "/static/"
                   :asset-manifest '((:stylesheets ("blog.css")))
                   :lenses
                   '(;; Full article view for the single-post page.
                     ;; Body uses :display :html because the demo
                     ;; stores Lexis s-expressions there directly;
                     ;; without the override the cascade would pick
                     ;; up the schema's :format :markdown annotation.
                     (:class classic.schema:classic-article
                      :purpose :default
                      :properties (classic.schema:headline
                                   (classic.schema:author
                                    :sublens classic.schema:classic-person
                                    :purpose :label)
                                   (classic.schema:date-created
                                    :display :date)
                                   (classic.schema:body
                                    :display :html)
                                   (classic.schema:keywords
                                    :display :list)))
                     ;; Compact entry for the index page
                     (:class classic.schema:classic-article
                      :purpose :summary
                      :properties (classic.schema:headline
                                   (classic.schema:date-created
                                    :display :date)))
                     ;; Inline author reference
                     (:class classic.schema:classic-person
                      :purpose :label
                      :properties (classic.schema:agent-name))))))
      (persist-entity strategy theme)
      ;; Attach to publication
      (setf (classic.schema:ui-theme (imprint-publication blog))
            (uri-string theme))
      (persist-entity strategy (imprint-publication blog))
      (setf *theme* theme)
      theme)))

;;; ============================================================
;;; Step 3: Render the two pages
;;; ============================================================

(defun render-post-page (blog post-index)
  "Compose and render a single blog post page. POST-INDEX is the
1-based position of the post in the blog's container (newest first).
Returns the rendered HTML string."
  (let* ((posts (get-articles blog))
         (post (nth (1- post-index) posts))
         (ctx (make-context
               :strategy (imprint-strategy blog)
               :publication (imprint-publication blog)
               :entity post)))
    (let ((page (compose-page ctx)))
      (lexis.html:render-html page :standalone t))))

(defun render-list-page (blog)
  "Compose and render the blog's index page. The entity is the blog's
post container; the default compose-aggregate walks its contents and
renders each entry with the :summary lens."
  (let* ((container (imprint-container blog))
         (ctx (make-context
               :strategy (imprint-strategy blog)
               :publication (imprint-publication blog)
               :entity container)))
    (let ((page (compose-page ctx)))
      (lexis.html:render-html page :standalone t))))

;;; ============================================================
;;; Step 4: End-to-end demo
;;; ============================================================

(defun output-pathname (filename)
  "Return the absolute pathname for an output file under doc/demos/.
Resolved relative to the captured demo source directory."
  (merge-pathnames
   (make-pathname :directory '(:relative :up "doc" "demos")
                  :name (pathname-name filename)
                  :type (pathname-type filename))
   *demo-source-directory*))

(defun run-demo ()
  "End-to-end demo. Builds a blog, creates a theme, composes two
pages, and writes them to doc/demos/. Returns the list of output
file paths."
  (setup-blog)
  (setup-theme *blog*)
  (let ((post-html (render-post-page *blog* 1))
        (list-html (render-list-page *blog*))
        (post-path (output-pathname "blog-post-output.html"))
        (list-path (output-pathname "blog-list-output.html")))
    (with-open-file (out post-path
                         :direction :output
                         :if-exists :supersede
                         :if-does-not-exist :create)
      (write-string post-html out))
    (with-open-file (out list-path
                         :direction :output
                         :if-exists :supersede
                         :if-does-not-exist :create)
      (write-string list-html out))
    (format t "~&Wrote post page to ~A~%" post-path)
    (format t "~&Wrote list page to ~A~%" list-path)
    (list post-path list-path)))
