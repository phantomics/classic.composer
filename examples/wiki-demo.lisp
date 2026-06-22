;;;; wiki-demo.lisp -- Self-contained Classic Composer wiki demo
;;;;
;;;; Renders two HTML pages from a wiki with typed page classes and
;;;; lens-driven infobox rendering:
;;;;
;;;;   1. A wiki article page (Amiga 1000) with typed infobox sidebar,
;;;;      body with resolved/broken wiki links, and metadata sections
;;;;   2. An alphabetical wiki index page
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
;;;   - :default lenses for wiki-page (headline + body as :html)
;;;   - :summary lenses for the index page
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
                  (paragraph (strong "Classic Computers Wiki"))
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
                   :asset-base-uri "/static/"
                   :asset-manifest '((:stylesheets ("wiki.css")))
                   :lenses
                   `(;; Full page view: headline + body as Lexis
                     (:class wiki-page
                      :purpose :default
                      :properties (classic.schema:headline
                                   (classic.schema:body :display :html)))
                     ;; Index page entries
                     (:class wiki-page
                      :purpose :summary
                      :properties (classic.schema:headline
                                   (classic.schema:created-at
                                    :display :date)))))))
      (persist-entity strategy theme)
      ;; Attach child theme to publication (replaces parent)
      (setf (classic.schema:ui-theme (imprint-publication wiki))
            (uri-string theme))
      (persist-entity strategy (imprint-publication wiki))
      (setf *child-theme* theme)
      theme)))

;;; ============================================================
;;; Step 3: Pre-process wiki content for HTML rendering
;;; ============================================================

(defun convert-wiki-body-to-lexis (wiki page)
  "Parse [[refs]] in PAGE's body and produce a Lexis subtree.
Resolved refs become (web-link ...) nodes; broken refs become
(emphasis (@ :class \"broken-link\") \"Name\") nodes.
Paragraph breaks on double-newlines are preserved."
  (let* ((text (classic.schema:body page))
         (result (when text (wikify-text wiki text))))
    (when result
      (setf (classic.schema:body page) result)
      (persist-entity (imprint-strategy wiki) page))))

(defun wikify-text (wiki text)
  "Convert wiki-markup text to a Lexis subtree. Handles [[refs]]
and paragraph breaks."
  (let ((paragraphs (split-on-double-newlines text)))
    (if (= 1 (length paragraphs))
        `(paragraph ,@(wikify-inline wiki (first paragraphs)))
        `(section (@ :class "body")
           ,@(mapcar (lambda (p)
                       `(paragraph ,@(wikify-inline wiki p)))
                     paragraphs)))))

(defun split-on-double-newlines (text)
  "Split TEXT into paragraph chunks on double-newline boundaries."
  (let ((chunks nil) (current (make-string-output-stream)))
    (with-input-from-string (in text)
      (let ((prev-blank nil))
        (loop for line = (read-line in nil nil)
              while line
              do (let ((blank (every (lambda (c) (member c '(#\Space #\Tab)))
                                     line)))
                   (cond
                     ((and blank (not prev-blank))
                      (let ((s (string-trim '(#\Space #\Tab #\Newline)
                                            (get-output-stream-string current))))
                        (when (plusp (length s)) (push s chunks)))
                      (setf current (make-string-output-stream)
                            prev-blank t))
                     (blank (setf prev-blank t))
                     (t (when prev-blank (setf prev-blank nil))
                        (write-string (string-trim '(#\Space #\Tab) line) current)
                        (write-char #\Space current)))))))
    (let ((s (string-trim '(#\Space #\Tab #\Newline)
                          (get-output-stream-string current))))
      (when (plusp (length s)) (push s chunks)))
    (nreverse chunks)))

(defun wikify-inline (wiki text)
  "Process a paragraph string, replacing [[refs]] with Lexis nodes.
Returns a list of strings and Lexis inline nodes."
  (let ((result nil) (pos 0) (len (length text)))
    (declare (ignore len))
    (loop
      (let ((open (search "[[" text :start2 pos)))
        (unless open
          (let ((rest (subseq text pos)))
            (when (plusp (length rest)) (push rest result)))
          (return (nreverse result)))
        ;; Text before the ref
        (when (> open pos)
          (push (subseq text pos open) result))
        (let ((close (search "]]" text :start2 (+ open 2))))
          (unless close
            (push (subseq text open) result)
            (return (nreverse result)))
          (let* ((inner (subseq text (+ open 2) close))
                 (pipe (position #\| inner))
                 (anchor (string-trim " " (if pipe (subseq inner 0 pipe) inner)))
                 (display (if pipe (string-trim " " (subseq inner (1+ pipe))) anchor))
                 (target (classic.models.common::find-page-by-anchor wiki anchor)))
            (push (if target
                      `(web-link (@ :uri ,(format nil "/wiki/~A"
                                                  (classic.models.common:page-anchor target)))
                                 ,display)
                      `(emphasis (@ :class "broken-link") ,display))
                  result)
            (setf pos (+ close 2))))))))

(defun resolve-typed-slots-to-uris (wiki page)
  "For typed-slot values that are anchor strings, resolve to page URIs
so the composer's apply-sublens can retrieve the entities."
  (let ((strategy (imprint-strategy wiki)))
    (flet ((resolve-anchor-slot (accessor)
             (when (and (slot-exists-p page accessor)
                        (slot-boundp page accessor))
               (let* ((anchor (funcall accessor page))
                      (target (when (stringp anchor)
                                (classic.models.common::find-page-by-anchor
                                 wiki anchor))))
                 (when target
                   (setf (slot-value page accessor) (uri-string target)))))))
      ;; Computer slots
      (when (typep page 'wiki-computer)
        (resolve-anchor-slot 'classic.models.common:computer-designer)
        (resolve-anchor-slot 'classic.models.common:computer-cpu))
      ;; CPU slots
      (when (typep page 'wiki-cpu)
        (resolve-anchor-slot 'classic.models.common:cpu-designer)))
    (persist-entity strategy page)))

(defun render-infobox-to-lexis (wiki page resolved-lenses)
  "Render the page's infobox as a Lexis (definition-list ...) subtree.
For typed pages: walks the :infobox lens, reads each slot, renders
with display modes, and assembles label/value pairs.
For generic pages: renders the alist infobox.
Returns the Lexis subtree or NIL."
  (let* ((entity-class (class-name (class-of page)))
         (lens (classic.schema:find-lens resolved-lenses entity-class
                                         :purpose :infobox)))
    (cond
      ;; Typed page with an :infobox lens
      (lens
       (let ((props (classic.schema:lens-properties lens))
             (entries nil))
         (dolist (prop props)
           (let* ((slot-name (getf prop :slot))
                  (display (getf prop :display))
                  (sublens-class (getf prop :sublens))
                  (sublens-purpose (or (getf prop :purpose) :label)))
             (when (and (slot-exists-p page slot-name)
                        (slot-boundp page slot-name))
               (let ((value (slot-value page slot-name)))
                 (when value
                   (let ((label (classic.models.common::slot-display-label
                                 slot-name))
                         (rendered
                           (cond
                             ;; Sublens reference
                             (sublens-class
                              (let ((result (apply-sublens
                                            (make-minimal-sublens-context wiki)
                                            sublens-class sublens-purpose
                                            value)))
                                (or result (princ-to-string value))))
                             ;; Display :link -> web-link
                             ((eq display :link)
                              (let ((target (retrieve-entity
                                            (imprint-strategy wiki) value nil)))
                                (if target
                                    `(web-link
                                      (@ :uri ,(format nil "/wiki/~A"
                                                       (classic.models.common:page-anchor target)))
                                      ,(classic.schema:label target))
                                    (princ-to-string value))))
                             ;; Display :list
                             ((eq display :list)
                              (if (listp value)
                                  (format nil "~{~A~^, ~}" value)
                                  (princ-to-string value)))
                             ;; Default :text
                             (t (princ-to-string value)))))
                     (push `(definition (@ :term ,label) ,rendered)
                           entries)))))))
         (when entries
           ;; Use passthrough with Spinneret HTML forms since Lexis
           ;; doesn't have definition-list tags implemented yet.
           `(passthrough (@ :medium :html)
             (:dl :class "infobox"
               ,@(loop for entry in (nreverse entries)
                       for term = (get-attr entry :term)
                       for value = (first (node-children entry))
                       collect `(:dt ,term)
                       collect `(:dd ,@(if (tagged-node-p value)
                                           (list (render-infobox-value-to-html value))
                                           (list (or value ""))))))))))
      ;; Generic page with alist infobox
      ((and (slot-boundp page 'classic.models.common:page-infobox)
            (classic.models.common:page-infobox page))
       (let ((entries nil))
         (dolist (pair (classic.models.common:page-infobox page))
           (push (list (car pair) (cdr pair)) entries))
         `(passthrough (@ :medium :html)
           (:dl :class "infobox"
             ,@(loop for (term value) in (nreverse entries)
                     collect `(:dt ,term)
                     collect `(:dd ,value))))))
      (t nil))))

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
     `(:span ,@(node-children node)))
    (t (if (stringp node) node (princ-to-string node)))))

(defun make-minimal-sublens-context (wiki)
  "Create a composition context for sublens resolution in the
infobox renderer."
  (make-context :strategy (imprint-strategy wiki)
                :publication (imprint-publication wiki)))

(defun assemble-page-metadata (wiki page)
  "Build a (section (@ :class \"page-metadata\") ...) Lexis subtree
from backlinks, broken links, and influenced-by data."
  (let ((sections nil))
    ;; Backlinks
    (let ((backlinks (classic.models.common:page-linked-from page)))
      (when backlinks
        (let ((names (loop for uri in backlinks
                           for entity = (retrieve-entity
                                         (imprint-strategy wiki) uri nil)
                           when (typep entity 'wiki-page)
                             collect `(item
                                       (web-link
                                        (@ :uri ,(format nil "/wiki/~A"
                                                         (classic.models.common:page-anchor entity)))
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

(defun pre-process-all-pages (wiki)
  "Pre-process all wiki pages for HTML rendering:
1. Resolve typed-slot anchors to URIs for sublens
2. Convert body [[refs]] to Lexis nodes
Runs after all pages are created and published."
  (dolist (page (classic.models.common::all-wiki-pages wiki))
    (resolve-typed-slots-to-uris wiki page)
    (convert-wiki-body-to-lexis wiki page)))

;;; ============================================================
;;; Step 4: Render pages
;;; ============================================================

(defun render-page-view (wiki anchor)
  "Compose and render a single wiki page. Returns the HTML string."
  (let* ((page (classic.models.common:find-page wiki anchor))
         (strategy (imprint-strategy wiki))
         (ctx (make-context :strategy strategy
                            :publication (imprint-publication wiki)
                            :entity page)))
    ;; Render infobox via :infobox lens and bind to slot
    (let ((resolved-lenses (context-theme-lenses ctx)))
      (let ((infobox (render-infobox-to-lexis wiki page resolved-lenses)))
        (when infobox
          (context-bind ctx "page.infobox" infobox))))
    ;; Assemble metadata as adjunct content
    (let ((metadata (assemble-page-metadata wiki page)))
      (when metadata
        (context-bind ctx "adjunct-content" metadata)))
    ;; Compose and render
    (let ((page-tree (compose-page ctx)))
      (lexis.html:render-html page-tree :standalone t))))

(defun render-index-page (wiki)
  "Compose and render the wiki's alphabetical page index."
  ;; Sort the container alphabetically by anchor
  (let* ((strategy (imprint-strategy wiki))
         (container (imprint-container wiki))
         (pages (classic.models.common::all-wiki-pages wiki))
         (sorted (sort (copy-list pages) #'string-lessp
                       :key #'classic.models.common:page-anchor))
         (sorted-uris (mapcar #'uri-string sorted)))
    (setf (classic.schema:contains container) sorted-uris)
    (persist-entity strategy container)
    (let ((ctx (make-context :strategy strategy
                             :publication (imprint-publication wiki)
                             :entity container)))
      (let ((page-tree (compose-page ctx)))
        (lexis.html:render-html page-tree :standalone t)))))

;;; ============================================================
;;; Step 5: End-to-end demo
;;; ============================================================

(defun output-pathname (filename)
  "Return the absolute pathname for an output file under doc/demos/."
  (merge-pathnames
   (make-pathname :directory '(:relative :up "doc" "demos")
                  :name (pathname-name filename)
                  :type (pathname-type filename))
   *demo-source-directory*))

(defun run-demo ()
  "End-to-end demo. Builds a wiki with typed pages, creates a child
theme, pre-processes content, and renders two HTML pages."
  (setup-wiki)
  (setup-child-theme *wiki*)
  (pre-process-all-pages *wiki*)
  (let ((page-html (render-page-view *wiki* "Amiga 1000"))
        (index-html (render-index-page *wiki*))
        (page-path (output-pathname "wiki-page-output.html"))
        (index-path (output-pathname "wiki-index-output.html")))
    (with-open-file (out page-path
                         :direction :output
                         :if-exists :supersede
                         :if-does-not-exist :create)
      (write-string page-html out))
    (with-open-file (out index-path
                         :direction :output
                         :if-exists :supersede
                         :if-does-not-exist :create)
      (write-string index-html out))
    (format t "~&Wrote page view to ~A~%" page-path)
    (format t "~&Wrote index page to ~A~%" index-path)
    (list page-path index-path)))
