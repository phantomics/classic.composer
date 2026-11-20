;;;; wiki-demo.lisp -- Self-contained Classic Composer wiki demo
;;;;
;;;; Renders a small static site from a wiki with typed page classes and
;;;; lens-driven infobox rendering:
;;;;
;;;;   1. An alphabetical wiki index page, whose entries link to the
;;;;      pages
;;;;   2. A page for each wiki article, with typed infobox sidebar,
;;;;      body with resolved/broken wiki links, and metadata sections
;;;;
;;;; The demo does not modify the wiki to render it: page anchors in
;;;; typed slots and wiki links are resolved while the pages are
;;;; composed, through RESOLVE-REFERENCE and MARKDOWN-OPTIONS, and the
;;;; index order comes from the theme.
;;;;
;;;; This is the first demo to exercise:
;;;;   - Child theme inheritance (child adds :default/:summary lenses
;;;;     on top of parent's :infobox/:label lenses)
;;;;   - Multi-purpose lens rendering on a single page (:infobox for
;;;;     sidebar, :default for body, :summary for index entries)
;;;;   - Sublens chain through typed classes (computer → CPU :label)
;;;;   - Alist infobox fallback for generic pages
;;;;   - Adjunct tier for page metadata (backlinks, broken links)
;;;;
;;;; To run from a fresh REPL:
;;;;
;;;;   (ql:quickload "classic.composer.dist.alpha")
;;;;   (ql:quickload "lexis.html")
;;;;   (load "examples/wiki-demo.lisp")
;;;;   (classic.composer.wiki-demo:run-demo)
;;;;
;;;; The demo writes its pages under doc/demos/wiki/:
;;;;   index.html    -- page index
;;;;   <page>.html   -- one page per wiki article, named from its anchor

(defpackage #:classic.composer.wiki-demo
  (:use #:cl
        #:classic
        #:classic.composer
        #:classic.dist.alpha
        #:classic.models.common)
  (:shadow #:label #:description #:body)
  (:export #:run-demo
           #:setup-wiki
           #:setup-child-theme
           #:render-page-view
           #:render-index-page))

(in-package #:classic.composer.wiki-demo)

;;; ============================================================
;;; Source-relative paths
;;; ============================================================

(defparameter *demo-source-directory*
  (make-pathname
   :directory (pathname-directory
               (or *load-pathname*
                   *compile-file-pathname*
                   #.(or *compile-file-pathname* *load-pathname*)))))

(defvar *wiki* nil "The demo wiki, populated by SETUP-WIKI.")
(defvar *child-theme* nil "The demo child theme, populated by SETUP-CHILD-THEME.")

;;; ============================================================
;;; Step 1: Build the wiki with typed pages
;;; ============================================================

(defun setup-wiki ()
  "Create the wiki with 4 pages: 3 typed (person, CPU, computer)
and 1 generic (AmigaOS). Returns the wiki imprint."
  (let ((wiki (make-wiki :name "Classic Computers Wiki"
                         :authority "retro.wiki"
                         :authority-date "2026")))
    (let ((editor (create-account wiki :name "Alice" :role :editor))
          (writer (create-account wiki :name "Bob" :role :writer)))
      ;; Create pages in dependency order so cross-references resolve.
      ;; Person first (referenced by computer and CPU pages).
      (create-page wiki :account writer :class 'wiki-person
                   :title "Jay Miner"
                   :body "Jay Miner was an American integrated circuit designer and the lead architect of the [[Amiga 1000]]. He previously designed custom chips for Atari's game consoles."
                   :person-born "1932"
                   :person-nationality "American"
                   :person-known-for '("Amiga 1000" "Atari 2600"))
      (publish-page wiki "Jay Miner" :account editor)

      ;; CPU (referenced by the computer page)
      (create-page wiki :account writer :class 'wiki-cpu
                   :title "Motorola 68000"
                   :body "The [[Motorola 68000]] was a 16/32-bit CISC microprocessor. It powered the [[Amiga 1000]], the original [[Macintosh]], and many arcade systems."
                   :cpu-manufacturer "Motorola"
                   :cpu-released "1979"
                   :cpu-designer "Tom Gunter"
                   :cpu-clock-speed "7.16 MHz"
                   :cpu-word-size "16/32-bit")
      (publish-page wiki "Motorola 68000" :account editor)

      ;; Computer (references person and CPU via typed slots)
      (create-page wiki :account writer :class 'wiki-computer
                   :title "Amiga 1000"
                   :body "The [[Amiga 1000]] was the first model in the Amiga line by Commodore. It featured custom graphics and sound chips designed by [[Jay Miner]], running on the [[Motorola 68000]] CPU. It shipped with [[AmigaOS]]."
                   :computer-manufacturer "Commodore"
                   :computer-released "1985"
                   :computer-designer "Jay Miner"
                   :computer-cpu "Motorola 68000"
                   :computer-price "$1,295"
                   :influenced-by '("Atari 800"))
      (publish-page wiki "Amiga 1000" :account editor)

      ;; Generic page (no typed class -- demonstrates alist fallback)
      (create-page wiki :account writer
                   :title "AmigaOS"
                   :body "[[AmigaOS]] is the operating system for the [[Amiga 1000]] line of computers. It was notable for its preemptive multitasking and its [[Intuition]] windowing system."
                   :infobox '(("Type" . "Operating System")
                              ("Developer" . "Commodore")
                              ("Initial release" . "1985")
                              ("Written in" . "C, Assembly")))
      (publish-page wiki "AmigaOS" :account editor))
    (setf *wiki* wiki)
    wiki))

;;; ============================================================
;;; Step 2: Create the child theme
;;; ============================================================
;;;
;;; The wiki's built-in theme (created by make-wiki) carries
;;; :infobox and :label lenses for the typed page classes.
;;; The child theme adds:
;;;   - A frame template with slots for infobox, content, adjunct
;;;   - :default lenses for wiki-page (headline + Markdown body)
;;;   - :summary lenses for the index page, with headlines linked to
;;;     the pages
;;;   - An :aggregate lens on the page container, listing the index
;;;     alphabetically
;;;   - Slot fills for brand header and footer
;;;   - Asset manifest for wiki.css

(defun setup-child-theme (wiki)
  "Create a child theme extending the wiki's built-in theme.
Attaches it to the publication. Returns the child theme."
  (let* ((strategy (imprint-strategy wiki))
         (parent-uri (classic.schema:ui-theme (imprint-publication wiki)))
         (frame-template
           '(document (@ :title (template.slot (@ :name "page-title")))
              (template.slot (@ :name "theme.assets"))
              (template.slot (@ :name "theme.brand"))
              (template.slot (@ :name "page.infobox"))
              (template.slot (@ :name "main-content"))
              (template.slot (@ :name "aggregate-content"))
              (template.slot (@ :name "adjunct-content"))
              (template.slot (@ :name "theme.footer"))))
         (slot-fills
           '(("theme.brand"
              . (section (@ :class "wiki-header")
                  (paragraph (strong (web-link (@ :uri "index.html")
                                               "Classic Computers Wiki")))
                  (paragraph "A Classic-powered knowledge base.")))
             ("theme.footer"
              . (section (@ :class "wiki-footer")
                  (paragraph "(c) 2026 Classic Computers Wiki. "
                             "Powered by "
                             (web-link (@ :uri "https://example.com/classic")
                                       "Classic")
                             "."))))))
    (let ((theme (make-instance 'classic.schema:classic-theme
                   :uri (mint-uri 'classic.schema:classic-theme
                                  "retro.wiki" "2026"
                                  :slug "wiki-html-theme")
                   :label "Wiki HTML Theme"
                   :parent-theme parent-uri
                   :theme-version "1.0"
                   :tier-templates `((:frame . ,frame-template))
                   :slot-fills slot-fills
                   :asset-base-uri "../../../examples/static/"
                   :asset-manifest '((:stylesheets ("wiki.css")))
                   :lenses
                   `(;; Full page view: headline + body. The body
                     ;; slot's :format :markdown selects the
                     ;; :markdown display mode; MARKDOWN-OPTIONS below
                     ;; supplies the wiki link resolver.
                     (:class wiki-page
                      :purpose :default
                      :properties (classic.schema:headline
                                   classic.schema:body))
                     ;; Index page entries, linked to the pages
                     (:class wiki-page
                      :purpose :summary
                      :properties ((classic.schema:headline
                                    :link :self)
                                   (classic.schema:created-at
                                    :display :date)))
                     ;; The index lists pages alphabetically. The
                     ;; order belongs to this theme, so it applies to
                     ;; this wiki's container only.
                     (:class classic.schema:classic-container
                      :purpose :aggregate
                      :sort-by classic.schema:headline)))))
      (persist-entity strategy theme)
      ;; Attach child theme to publication (replaces parent)
      (setf (classic.schema:ui-theme (imprint-publication wiki))
            (uri-string theme))
      (persist-entity strategy (imprint-publication wiki))
      (setf *child-theme* theme)
      theme)))

;;; ============================================================
;;; Step 3: Page links and page references
;;; ============================================================
;;;
;;; The demo writes a static site: the index is index.html and each
;;; page is a file named from its anchor. ENTITY-HREF tells the
;;; composer where a page is.
;;;
;;; Typed slots such as computer-designer name pages by anchor, not
;;; by URI. RESOLVE-REFERENCE looks an anchor up, so the infobox's
;;; links and sublenses reach the pages without the slots being
;;; rewritten. The composition context carries no wiki imprint, so
;;; the lookups use *WIKI*.

(defun slugify (string)
  "Return STRING in lower case with each run of characters other than
letters and digits made a single hyphen, as a file name."
  (let ((words nil) (word (make-string-output-stream)))
    (flet ((flush ()
             (let ((w (get-output-stream-string word)))
               (when (plusp (length w)) (push w words)))))
      (loop for ch across string
            do (if (alphanumericp ch)
                   (write-char (char-downcase ch) word)
                   (flush)))
      (flush))
    (format nil "~{~A~^-~}" (nreverse words))))

(defun page-filename (page)
  "The file name of PAGE's page."
  (format nil "~A.html" (slugify (classic.models.common:page-anchor page))))

(defmethod entity-href (context (entity wiki-page))
  (declare (ignore context))
  (page-filename entity))

(defmethod resolve-reference (context (entity wiki-page) property value)
  "A wiki page's references are URIs or page anchors."
  (or (call-next-method)
      (when (stringp value)
        (classic.models.common::find-page-by-anchor *wiki* value))))

;;; ============================================================
;;; Step 4: Wiki links in Markdown bodies
;;; ============================================================
;;;
;;; Page bodies stay Markdown strings. The composer reads them with
;;; the Lexis Markdown reader when the page is rendered, and asks
;;; MARKDOWN-OPTIONS for the reader's options; this method supplies a
;;; resolver that turns [[Anchor]] and [[Anchor|Display]] into links
;;; to the named pages.

(defun resolve-wiki-link (context target display)
  "Return the Lexis form for a wiki link to TARGET shown as DISPLAY:
a web-link to the page's file when the wiki has a page with that
anchor, otherwise an emphasis marking the link as broken. The form is
built from LEXIS symbols, which the reader's passes recognise."
  (let ((page (classic.models.common::find-page-by-anchor *wiki* target)))
    (if page
        `(lexis::web-link (lexis::@ :uri ,(entity-href context page))
                          ,display)
        `(lexis::emphasis (lexis::@ :class "broken-link") ,display))))

(defmethod markdown-options (context (entity wiki-page) slot-name)
  "Resolve the wiki links in a page's body against the demo wiki."
  (declare (ignore slot-name))
  (list :wiki-link-resolver
        (lambda (target display)
          (resolve-wiki-link context target display))))

;;; ============================================================
;;; Step 5: Infobox and page metadata
;;; ============================================================

(defun render-infobox (context page)
  "Render PAGE's infobox as an HTML passthrough holding a definition
list, or return NIL if it has none.

For typed pages, each property of the :infobox lens is rendered with
the composer's RENDER-LENS-PROPERTY, so :link properties and sublenses
follow page anchors through RESOLVE-REFERENCE; list properties are
shown as comma-separated text. For generic pages, the alist infobox
is shown as it is.

The infobox is a passthrough because wiki.css styles it by its class,
which the Lexis HTML renderer does not give a Lexis definition list."
  (let ((lens (classic.schema:find-lens (context-theme-lenses context)
                                        (class-name (class-of page))
                                        :purpose :infobox)))
    (cond
      ;; Typed page with an :infobox lens
      (lens
       (let ((entries
               (loop for prop in (classic.schema:lens-properties lens)
                     for slot-name = (getf prop :slot)
                     for value = (lens-property-value context page slot-name)
                     when value
                       collect (cons (classic.models.common::slot-display-label
                                      slot-name)
                                     (if (eq (getf prop :display) :list)
                                         (format nil "~{~A~^, ~}"
                                                 (if (listp value)
                                                     value
                                                     (list value)))
                                         (or (render-lens-property
                                              context page prop)
                                             (princ-to-string value)))))))
         (when entries
           (infobox-passthrough entries))))
      ;; Generic page with alist infobox
      ((and (slot-boundp page 'classic.models.common:page-infobox)
            (classic.models.common:page-infobox page))
       (infobox-passthrough (classic.models.common:page-infobox page)))
      (t nil))))

(defun infobox-passthrough (entries)
  "Return an HTML passthrough holding ENTRIES, an alist of
(term . value), as the infobox's definition list."
  `(passthrough (@ :medium :html)
     (:dl :class "infobox"
       ,@(loop for (term . value) in entries
               collect `(:dt ,term)
               collect `(:dd ,(render-infobox-value-to-html value))))))

(defun render-infobox-value-to-html (node)
  "Convert a Lexis node from the infobox to a Spinneret HTML form
for use inside a passthrough. Handles web-link and section (sublens)."
  (cond
    ((and (tagged-node-p node)
          (string= "WEB-LINK" (symbol-name (node-tag node))))
     `(:a :href ,(get-attr node :uri)
          ,@(node-children node)))
    ((and (tagged-node-p node)
          (string= "SECTION" (symbol-name (node-tag node))))
     ;; Sublens output is a section of text items
     `(:span ,@(mapcar #'render-infobox-value-to-html (node-children node))))
    (t (if (stringp node) node (princ-to-string node)))))

(defun assemble-page-metadata (context page)
  "Build a (section (@ :class \"page-metadata\") ...) Lexis subtree
from backlinks, broken links, and influenced-by data."
  (let ((sections nil))
    ;; Backlinks
    (let ((backlinks (classic.models.common:page-linked-from page)))
      (when backlinks
        (let ((names (loop for uri in backlinks
                           for entity = (context-retrieve context uri)
                           when (typep entity 'wiki-page)
                             collect `(item
                                       (web-link
                                        (@ :uri ,(entity-href context entity))
                                        ,(classic.models.common:page-anchor entity))))))
          (when names
            (push `(section (@ :class "backlinks")
                     (paragraph (strong "What links here:"))
                     (unordered-list ,@names))
                  sections)))))
    ;; Broken links
    (let ((broken (classic.models.common:page-broken-links page)))
      (when broken
        (push `(section (@ :class "broken-links")
                 (paragraph (strong "Broken links: ")
                            ,(format nil "~{~A~^, ~}" broken)))
              sections)))
    ;; Influenced by
    (let ((influenced (classic.models.common:page-influenced-by page)))
      (when influenced
        (push `(section (@ :class "lineage")
                 (paragraph (strong "Influenced by: ")
                            ,(format nil "~{~A~^, ~}" influenced)))
              sections)))
    (when sections
      `(section (@ :class "page-metadata")
         ,@(nreverse sections)))))

;;; ============================================================
;;; Step 6: Render pages
;;; ============================================================

(defun render-page-view (wiki anchor)
  "Compose and render the wiki page with ANCHOR. Returns the HTML string."
  (let* ((page (classic.models.common:find-page wiki anchor))
         (ctx (make-context :strategy (imprint-strategy wiki)
                            :publication (imprint-publication wiki)
                            :entity page)))
    ;; Render the infobox and bind it to its slot
    (let ((infobox (render-infobox ctx page)))
      (when infobox
        (context-bind ctx "page.infobox" infobox)))
    ;; Assemble metadata as adjunct content
    (let ((metadata (assemble-page-metadata ctx page)))
      (when metadata
        (context-bind ctx "adjunct-content" metadata)))
    (lexis.html:render-html (compose-page ctx) :standalone t)))

(defun render-index-page (wiki)
  "Compose and render the wiki's page index. The theme's :aggregate
lens for the container lists the pages alphabetically."
  (let ((ctx (make-context :strategy (imprint-strategy wiki)
                           :publication (imprint-publication wiki)
                           :entity (imprint-container wiki))))
    (lexis.html:render-html (compose-page ctx) :standalone t)))

;;; ============================================================
;;; Step 7: End-to-end demo
;;; ============================================================

(defun output-pathname (filename)
  "Return the absolute pathname for an output file under doc/demos/wiki/."
  (merge-pathnames
   (make-pathname :directory '(:relative :up "doc" "demos" "wiki")
                  :name (pathname-name filename)
                  :type (pathname-type filename))
   *demo-source-directory*))

(defun write-page (filename html)
  "Write HTML to FILENAME under doc/demos/wiki/. Returns the pathname."
  (let ((path (output-pathname filename)))
    (ensure-directories-exist path)
    (with-open-file (out path
                         :direction :output
                         :if-exists :supersede
                         :if-does-not-exist :create)
      (write-string html out))
    (format t "~&Wrote ~A~%" path)
    path))

(defun run-demo ()
  "End-to-end demo. Builds a wiki with typed pages, creates a child
theme, and writes the index page and a page for each wiki page to
doc/demos/wiki/. Returns the list of output file paths."
  (setup-wiki)
  (setup-child-theme *wiki*)
  (cons (write-page "index.html" (render-index-page *wiki*))
        (mapcar (lambda (uri)
                  (let ((page (retrieve-entity (imprint-strategy *wiki*) uri nil)))
                    (write-page (page-filename page)
                                (render-page-view
                                 *wiki* (classic.models.common:page-anchor page)))))
                (classic.schema:contains (imprint-container *wiki*)))))
