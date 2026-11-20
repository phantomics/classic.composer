;;;; forum-demo.lisp -- Self-contained Classic Composer forum demo
;;;;
;;;; Renders a small static site from forum content using a single theme:
;;;;
;;;;   1. A thread list page (forum index), pinned threads first, whose
;;;;      entries link to the threads
;;;;   2. A thread view page for each thread (all posts in the thread),
;;;;      whose post authors link to their profiles
;;;;   3. A profile page for each member
;;;;
;;;; The demo does not modify the forum to render it. Thread order,
;;;; post authors' nicknames and members' roles are computed while the
;;;; pages are composed, through the composer's extension generics:
;;;; CONTAINER-ENTRIES, LENS-PROPERTY-VALUE and ENTITY-HREF.
;;;;
;;;; To run from a fresh REPL:
;;;;
;;;;   (ql:quickload "classic.composer.dist.alpha")
;;;;   (ql:quickload "lexis.html")
;;;;   (load "examples/forum-demo.lisp")
;;;;   (classic.composer.forum-demo:run-demo)
;;;;
;;;; The demo writes its pages under doc/demos/forum/:
;;;;   index.html             -- thread listing
;;;;   thread-<title>.html    -- one page per thread
;;;;   member-<nickname>.html -- one profile page per member

(defpackage #:classic.composer.forum-demo
  (:use #:cl
        #:classic
        #:classic.composer
        #:classic.dist.alpha
        #:classic.models.common)
  (:shadow #:label #:description #:body)
  (:export #:run-demo
           #:setup-forum
           #:setup-theme
           #:render-thread-page
           #:render-index-page
           #:render-member-page))

(in-package #:classic.composer.forum-demo)

;;; ============================================================
;;; Source-relative paths
;;; ============================================================

(defparameter *demo-source-directory*
  (make-pathname
   :directory (pathname-directory
               (or *load-pathname*
                   *compile-file-pathname*
                   #.(or *compile-file-pathname* *load-pathname*)))))

;;; ============================================================
;;; Step 1: Build a forum with threads and posts
;;; ============================================================

(defvar *forum* nil "The demo forum, populated by SETUP-FORUM.")
(defvar *members* nil "The demo forum's accounts, populated by SETUP-FORUM.")
(defvar *theme* nil "The demo theme, populated by SETUP-THEME.")

(defun setup-forum ()
  "Create the demo forum with members, threads, posts, reactions,
and a quote. Stores the forum in *FORUM* and its accounts in
*MEMBERS*. Returns the forum imprint."
  (let ((forum (make-forum :name "CL Watercooler"
                           :authority "wc.demo"
                           :authority-date "2026")))
    (let ((alice (create-member forum :name "Alice Hong"
                                :nickname "alice42"
                                :title "Founder" :role :admin))
          (bob (create-member forum :name "Bob Park"
                              :nickname "bobcat"
                              :title "Hacker" :role :member))
          (carol (create-member forum :name "Carol Q"
                                :nickname "cQ"
                                :title "Moderator" :role :moderator)))
      ;; Create all three threads first, then add replies and reactions.
      ;; This keeps thread indices stable during the setup phase.
      ;;
      ;; After creation, container holds (newest-first):
      ;;   [Best CL, Forum rules, Favorite macro?]
      ;; ordered-threads (no pins yet) returns the same order:
      ;;   Index 1 = Best CL
      ;;   Index 2 = Forum rules
      ;;   Index 3 = Favorite macro?

      ;; Thread creation
      (start-thread forum :account alice
                    :title "Favorite macro?"
                    :body "What macro do you reach for most? I keep going back to DEFMETHOD for its simplicity.")
      (start-thread forum :account carol
                    :title "Forum rules (read first)"
                    :body "Welcome to CL Watercooler. Be kind, quote your sources, and keep it constructive.")
      (start-thread forum :account bob
                    :title "Best CL implementation in 2026?"
                    :body "SBCL seems to be the default these days, but CCL has its strengths. What do you use?")

      ;; Replies and quotes on "Favorite macro?" (index 3)
      (post-reply forum 3 :account bob
                  :body "DEFCLASS, for the metaobject leverage. Being able to annotate slots with persistence metadata is what Classic is built on.")
      (quote-post forum 3 2 :account carol
                  :body "Agreed, especially with MOP extensions. The introspection capabilities are underappreciated.")

      ;; Reactions on "Favorite macro?" posts
      (react forum 3 1 :account bob :sticker "heart")
      (react forum 3 2 :account alice :sticker "star")
      (react forum 3 2 :account carol :sticker "star")

      ;; Reply on "Best CL implementation" (index 1)
      (post-reply forum 1 :account alice
                  :body "SBCL for production, ECL when I need to embed. The ecosystem convergence around SBCL is real though.")

      ;; Pin "Forum rules" (index 2) last, so all prior operations
      ;; used stable pre-pin indices.
      (pin-thread forum 2 :account carol)
      (setf *members* (list alice bob carol)))
    (setf *forum* forum)
    forum))

;;; ============================================================
;;; Step 2: Composition rules for forum content
;;; ============================================================
;;;
;;; These methods tell the composer how forum content reads. Each
;;; computes what a page shows from the stored forum; none changes it.

;; Threads store posts newest-first (via push) but read oldest-first.
(defmethod container-reading-order
    ((entity classic.models.common:forum-thread))
  :reverse)

;; The forum lists pinned threads first, as the forum model's own
;; ORDERED-THREADS does: a rule of the content type, so it is a method
;; on the forum's container class rather than a theme setting.
(defmethod container-entries (context (container classic.schema:classic-forum))
  (stable-sort (copy-list (call-next-method))
               (lambda (a b)
                 (and (typep a 'forum-thread) (thread-pinned-p a)
                      (not (and (typep b 'forum-thread)
                                (thread-pinned-p b)))))))

;; A post's author slot holds the member's person, but a forum shows
;; the member's account. POST-AUTHOR-ACCOUNT is a computed property
;; giving the URI of the account whose sioc:account_of is the author:
;; a reverse relation, found through the persistence layer's
;; relation index.
(defmethod lens-property-value (context (entity forum-post)
                                (property (eql 'post-author-account)))
  (let ((person (classic.schema:author entity)))
    (when person
      (first (context-query context "sioc:account_of" person)))))

;; A member's role is an object on the account; MEMBER-ROLE gives its
;; label for display.
(defmethod lens-property-value (context (entity forum-account)
                                (property (eql 'member-role)))
  (declare (ignore context))
  (actor-role-label entity))

;;; ============================================================
;;; Step 3: Page links
;;; ============================================================
;;;
;;; The demo writes a static site, one file per page. ENTITY-HREF
;;; tells the composer each page's file name, so lens properties
;;; marked :link :self link to it.

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

(defun page-filename (entity)
  "The file name of ENTITY's page, or NIL if it has none."
  (typecase entity
    (forum-thread (format nil "thread-~A.html"
                          (slugify (classic.schema:label entity))))
    (forum-account (format nil "member-~A.html"
                           (slugify (member-nickname entity))))
    (classic.schema:classic-forum "index.html")))

(defmethod entity-href (context (entity forum-thread))
  (declare (ignore context))
  (page-filename entity))

(defmethod entity-href (context (entity forum-account))
  (declare (ignore context))
  (page-filename entity))

(defmethod entity-href (context (entity classic.schema:classic-forum))
  (declare (ignore context))
  (page-filename entity))

;;; ============================================================
;;; Step 4: Define the forum theme
;;; ============================================================

(defun setup-theme (forum)
  "Create the forum theme, attach it to the publication, and return it.
Stores in *THEME*."
  (let* ((strategy (imprint-strategy forum))
         (frame-template
           '(document (@ :title (template.slot (@ :name "page-title")))
              (template.slot (@ :name "theme.assets"))
              (template.slot (@ :name "theme.brand"))
              (template.slot (@ :name "main-content"))
              (template.slot (@ :name "aggregate-content"))
              (template.slot (@ :name "theme.footer"))))
         (slot-fills
           '(("theme.brand"
              . (section (@ :class "forum-header")
                  (paragraph (strong (web-link (@ :uri "index.html")
                                               "CL Watercooler")))
                  (paragraph "A Classic-powered discussion forum.")))
             ("theme.footer"
              . (section (@ :class "forum-footer")
                  (paragraph "(c) 2026 CL Watercooler. "
                             "Powered by "
                             (web-link (@ :uri "https://example.com/classic")
                                       "Classic")
                             "."))))))
    (let ((theme (make-instance 'classic.schema:classic-theme
                   :uri (mint-uri 'classic.schema:classic-theme
                                  "wc.demo" "2026" :slug "forum-theme")
                   :label "Forum Theme"
                   :theme-version "1.0"
                   :tier-templates `((:frame . ,frame-template))
                   :slot-fills slot-fills
                   :asset-base-uri "../../../examples/static/"
                   :asset-manifest '((:stylesheets ("forum.css")))
                   :lenses
                   '(;; Thread listing entry: title, linked to the
                     ;; thread's page, and creation date.
                     ;; forum-thread extends classic-container (not
                     ;; creative-work), so it has created-at from
                     ;; classic-resource, not date-created.
                     (:class classic.models.common:forum-thread
                      :purpose :summary
                      :properties ((classic.schema:label
                                    :link :self)
                                   (classic.schema:created-at
                                    :display :date)))

                     ;; Post in a thread view: the author's account
                     ;; (a computed property, see above) through its
                     ;; :label lens, date, body, stickers.
                     (:class classic.models.common:forum-post
                      :purpose :summary
                      :properties ((post-author-account
                                    :sublens classic.models.common:forum-account
                                    :purpose :label)
                                   (classic.schema:date-created
                                    :display :date)
                                   classic.schema:body
                                   (classic.models.common:post-stickers
                                    :display :list)))

                     ;; Member inline reference: the nickname, linked
                     ;; to the member's profile page.
                     (:class classic.models.common:forum-account
                      :purpose :label
                      :properties ((classic.models.common:member-nickname
                                    :link :self)))

                     ;; Member profile page.
                     (:class classic.models.common:forum-account
                      :purpose :default
                      :properties (classic.models.common:member-nickname
                                   (classic.models.common:member-title
                                    :label "Title")
                                   (member-role
                                    :label "Role")
                                   (classic.models.common:member-joined-at
                                    :display :date :label "Joined")
                                   (classic.models.common:member-post-count
                                    :label "Posts")))))))
      (persist-entity strategy theme)
      ;; Attach to publication
      (setf (classic.schema:ui-theme (imprint-publication forum))
            (uri-string theme))
      (persist-entity strategy (imprint-publication forum))
      (setf *theme* theme)
      theme)))

;;; ============================================================
;;; Step 5: Render the pages
;;; ============================================================

(defun render-entity-page (forum entity)
  "Compose and render the page whose primary entity is ENTITY."
  (let ((ctx (make-context
              :strategy (imprint-strategy forum)
              :publication (imprint-publication forum)
              :entity entity)))
    (lexis.html:render-html (compose-page ctx) :standalone t)))

(defun render-index-page (forum)
  "Compose and render the forum's thread listing page.
The entity is the forum's main container; the default compose-aggregate
lists the threads CONTAINER-ENTRIES gives, with the :summary lens."
  (render-entity-page forum (imprint-container forum)))

(defun render-thread-page (forum thread)
  "Compose and render THREAD's post listing.
The entity is the forum-thread (a classic-container); compose-aggregate
walks its posts and renders each with the :summary lens."
  (render-entity-page forum thread))

(defun render-member-page (forum account)
  "Compose and render ACCOUNT's profile page, through the :default
lens for forum-account."
  (render-entity-page forum account))

;;; ============================================================
;;; Step 6: End-to-end demo
;;; ============================================================

(defun output-pathname (filename)
  "Return the absolute pathname for an output file under doc/demos/forum/."
  (merge-pathnames
   (make-pathname :directory '(:relative :up "doc" "demos" "forum")
                  :name (pathname-name filename)
                  :type (pathname-type filename))
   *demo-source-directory*))

(defun write-page (filename html)
  "Write HTML to FILENAME under doc/demos/forum/. Returns the pathname."
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
  "End-to-end demo. Builds a forum, creates a theme, composes the
index page, a page for each thread and a profile for each member, and
writes them to doc/demos/forum/. Returns the list of output file
paths."
  (setup-forum)
  (setup-theme *forum*)
  (append
   (list (write-page "index.html" (render-index-page *forum*)))
   (mapcar (lambda (uri)
             (let ((thread (retrieve-entity (imprint-strategy *forum*) uri nil)))
               (write-page (page-filename thread)
                           (render-thread-page *forum* thread))))
           (classic.schema:contains (imprint-container *forum*)))
   (mapcar (lambda (account)
             (write-page (page-filename account)
                         (render-member-page *forum* account)))
           *members*)))
