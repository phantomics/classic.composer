;;;; forum-demo.lisp -- Self-contained Classic Composer forum demo
;;;;
;;;; Renders two HTML pages from forum content using a single theme:
;;;;
;;;;   1. A thread list page (forum index)
;;;;   2. A thread view page (all posts in a thread)
;;;;
;;;; To run from a fresh REPL:
;;;;
;;;;   (ql:quickload "classic.composer.dist.alpha")
;;;;   (ql:quickload "lexis.html")
;;;;   (load "examples/forum-demo.lisp")
;;;;   (classic.composer.forum-demo:run-demo)
;;;;
;;;; The demo writes two HTML files under doc/demos/:
;;;;   forum-index-output.html  -- thread listing
;;;;   forum-thread-output.html -- single thread with posts

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
           #:render-index-page))

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
(defvar *theme* nil "The demo theme, populated by SETUP-THEME.")

(defun setup-forum ()
  "Create the demo forum with members, threads, posts, reactions,
and a quote. Stores in *FORUM*. Returns the forum imprint."
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

      ;; Reorder the forum container's contains list to match the
      ;; display order (pinned threads first). The composer's generic
      ;; container walk reads contains as-stored; the forum model's
      ;; ordered-threads sorts at query time, but the composer does
      ;; not call it. In production, a forum-container subclass with
      ;; its own container-reading-order method would handle this.
      (let ((sorted (mapcar #'uri-string
                            (classic.models.common::ordered-threads forum))))
        (setf (classic.schema:contains (imprint-container forum)) sorted)
        (persist-entity (imprint-strategy forum) (imprint-container forum)))

      ;; Resolve author URIs to member nicknames for display. The
      ;; lens renders the author slot as :text; this step replaces
      ;; the person URI with the human-readable nickname string.
      ;; In production, a capability or custom lens handler would
      ;; navigate the person -> account -> nickname relationship
      ;; at render time. For the demo we resolve upfront.
      (resolve-authors-to-nicknames forum))
    (setf *forum* forum)
    forum))

(defun resolve-authors-to-nicknames (forum)
  "Walk all posts in all threads and replace each post's author URI
with the member's nickname string for display."
  (let ((strategy (imprint-strategy forum)))
    (dolist (thread-uri (classic.schema:contains (imprint-container forum)))
      (let ((thread (retrieve-entity strategy thread-uri nil)))
        (when (typep thread 'classic.models.common:forum-thread)
          (dolist (post-uri (classic.schema:contains thread))
            (let ((post (retrieve-entity strategy post-uri nil)))
              (when (and (typep post 'classic.models.common:forum-post)
                         (classic.schema:author post))
                (let ((nick (classic.models.common:resolve-member-nickname
                             forum (classic.schema:author post))))
                  (when nick
                    (setf (classic.schema:author post) nick)
                    (persist-entity strategy post)))))))))))

;;; ============================================================
;;; Step 2: Define the forum theme
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
                  (paragraph (strong "CL Watercooler"))
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
                   :asset-base-uri "/static/"
                   :asset-manifest '((:stylesheets ("forum.css")))
                   :lenses
                   '(;; Thread listing entry: title + creation date.
                     ;; forum-thread extends classic-container (not
                     ;; creative-work), so it has created-at from
                     ;; classic-resource, not date-created.
                     (:class classic.models.common:forum-thread
                      :purpose :summary
                      :properties (classic.schema:label
                                   (classic.schema:created-at
                                    :display :date)))

                     ;; Post in a thread view: author nickname,
                     ;; date, body, stickers.
                     ;; Author uses :display :text because the demo
                     ;; resolves person URIs to nickname strings
                     ;; upfront (see resolve-authors-to-nicknames).
                     ;; A production forum would use a capability or
                     ;; custom lens handler for this navigation.
                     (:class classic.models.common:forum-post
                      :purpose :summary
                      :properties ((classic.schema:author
                                    :display :text)
                                   (classic.schema:date-created
                                    :display :date)
                                   classic.schema:body
                                   (classic.models.common:post-stickers
                                    :display :list)))

                     ;; Person inline reference
                     (:class classic.schema:classic-person
                      :purpose :label
                      :properties (classic.schema:agent-name))))))
      (persist-entity strategy theme)
      ;; Attach to publication
      (setf (classic.schema:ui-theme (imprint-publication forum))
            (uri-string theme))
      (persist-entity strategy (imprint-publication forum))
      (setf *theme* theme)
      theme)))

;;; ============================================================
;;; Container reading order for forum threads
;;; ============================================================
;;;
;;; Forum threads store posts newest-first (via push) but should
;;; read oldest-first (chronological). The composer's
;;; container-reading-order generic lets content types declare their
;;; natural reading order without specializing compose-aggregate.

(defmethod container-reading-order
    ((entity classic.models.common:forum-thread))
  :reverse)

;;; ============================================================
;;; Step 3: Render the two pages
;;; ============================================================

(defun render-index-page (forum)
  "Compose and render the forum's thread listing page.
The entity is the forum's main container; the default compose-aggregate
walks it and renders each thread entry with the :summary lens."
  (let* ((container (imprint-container forum))
         (ctx (make-context
               :strategy (imprint-strategy forum)
               :publication (imprint-publication forum)
               :entity container)))
    (let ((page (compose-page ctx)))
      (lexis.html:render-html page :standalone t))))

(defun render-thread-page (forum thread-index)
  "Compose and render a single thread's post listing.
The entity is the forum-thread (a classic-container); compose-aggregate
walks its posts and renders each with the :summary lens."
  (let* ((threads (classic.models.common::ordered-threads forum))
         (thread (nth (1- thread-index) threads))
         (ctx (make-context
               :strategy (imprint-strategy forum)
               :publication (imprint-publication forum)
               :entity thread)))
    (let ((page (compose-page ctx)))
      (lexis.html:render-html page :standalone t))))

;;; ============================================================
;;; Step 4: End-to-end demo
;;; ============================================================

(defun output-pathname (filename)
  "Return the absolute pathname for an output file under doc/demos/."
  (merge-pathnames
   (make-pathname :directory '(:relative :up "doc" "demos")
                  :name (pathname-name filename)
                  :type (pathname-type filename))
   *demo-source-directory*))

(defun run-demo ()
  "End-to-end demo. Builds a forum, creates a theme, composes two
pages, and writes them to doc/demos/. Returns the list of output
file paths."
  (setup-forum)
  (setup-theme *forum*)
    ;; After pinning, ordered-threads returns:
    ;; 1. Forum rules (pinned)
    ;; 2. Best CL implementation (newest unpinned)
    ;; 3. Favorite macro? (oldest unpinned, has 3 posts + reactions)
    (let ((thread-html (render-thread-page *forum* 3))
        (index-html (render-index-page *forum*))
        (thread-path (output-pathname "forum-thread-output.html"))
        (index-path (output-pathname "forum-index-output.html")))
    (with-open-file (out thread-path
                         :direction :output
                         :if-exists :supersede
                         :if-does-not-exist :create)
      (write-string thread-html out))
    (with-open-file (out index-path
                         :direction :output
                         :if-exists :supersede
                         :if-does-not-exist :create)
      (write-string index-html out))
    (format t "~&Wrote thread page to ~A~%" thread-path)
    (format t "~&Wrote index page to ~A~%" index-path)
    (list thread-path index-path)))
