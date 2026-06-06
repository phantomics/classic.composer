;;;; test-tree-utils.lisp — Tests for Lexis s-expression tree utilities

(in-package #:classic.composer-tests)

(in-suite tree-utils)

;;; ============================================================
;;; tagged-node-p / text-node-p
;;; ============================================================

(def-test tagged-node-p-recognizes-tagged ()
  "A list with a symbol car is a tagged node."
  (is-true (tagged-node-p '(section (@ :id "intro") "text")))
  (is-true (tagged-node-p '(paragraph "hello")))
  (is-true (tagged-node-p '(emphasis))))

(def-test tagged-node-p-rejects-non-tagged ()
  "Strings, NIL, and lists with non-symbol car are not tagged nodes."
  (is-false (tagged-node-p "hello"))
  (is-false (tagged-node-p nil))
  (is-false (tagged-node-p '("not" "a" "tag")))
  (is-false (tagged-node-p 42)))

(def-test text-node-p-recognizes-strings ()
  "Strings are text nodes."
  (is-true (text-node-p "hello"))
  (is-true (text-node-p ""))
  (is-false (text-node-p '(paragraph "x")))
  (is-false (text-node-p nil)))

;;; ============================================================
;;; node-tag / node-attrs / node-children
;;; ============================================================

(def-test node-tag-extracts-tag ()
  "node-tag returns the symbol from the car of a tagged node."
  (is (eq 'section (node-tag '(section (@ :id "x") "text"))))
  (is (eq 'paragraph (node-tag '(paragraph "hello")))))

(def-test node-attrs-keyword-plist ()
  "node-attrs returns the plist from a keyword-style attribute list."
  (let ((attrs (node-attrs '(section (@ :id "intro" :title "Hi") "text"))))
    (is (equal "intro" (getf attrs :id)))
    (is (equal "Hi" (getf attrs :title)))))

(def-test node-attrs-returns-nil-when-absent ()
  "node-attrs returns NIL when no (@ ...) is present."
  (is (null (node-attrs '(paragraph "hello"))))
  (is (null (node-attrs '(emphasis "text")))))

(def-test node-children-skips-attrs ()
  "node-children returns children after the attribute list."
  (let ((children (node-children '(section (@ :id "x") "one" "two"))))
    (is (= 2 (length children)))
    (is (equal "one" (first children)))))

(def-test node-children-without-attrs ()
  "node-children works correctly when there are no attributes."
  (let ((children (node-children '(paragraph "hello" (emphasis "world")))))
    (is (= 2 (length children)))
    (is (equal "hello" (first children)))))

;;; ============================================================
;;; get-attr
;;; ============================================================

(def-test get-attr-keyword-plist ()
  "get-attr retrieves from keyword plist form."
  (let ((node '(section (@ :id "intro" :title "Hello"))))
    (is (equal "intro" (get-attr node :id)))
    (is (equal "Hello" (get-attr node :title)))
    (is (null (get-attr node :missing)))))

(def-test get-attr-alist-form ()
  "get-attr retrieves from alist attribute form."
  (let ((node '(image (@ (src "photo.jpg") (alt "A photo")))))
    (is (equal "photo.jpg" (get-attr node 'src)))
    (is (equal "A photo" (get-attr node 'alt)))))

;;; ============================================================
;;; walk-tree
;;; ============================================================

(def-test walk-tree-visits-all-nodes ()
  "walk-tree visits every node in depth-first pre-order."
  (let ((visited nil))
    (walk-tree (lambda (node) (push node visited))
               '(section (@ :id "x")
                  "text"
                  (paragraph "inner")))
    ;; Should visit: section, "text", paragraph, "inner"
    (is (= 4 (length visited)))))

;;; ============================================================
;;; transform-tree
;;; ============================================================

(def-test transform-tree-replaces-node ()
  "transform-tree can replace a node."
  (let ((result (transform-tree
                 (lambda (node)
                   (if (and (text-node-p node) (equal node "old"))
                       "new"
                       :keep))
                 '(paragraph "old"))))
    (is (equal '(paragraph "new") result))))

(def-test transform-tree-removes-node ()
  "transform-tree removes nodes when handler returns NIL."
  (let ((result (transform-tree
                 (lambda (node)
                   (if (and (text-node-p node) (equal node "remove-me"))
                       nil
                       :keep))
                 '(paragraph "keep" "remove-me" "also-keep"))))
    (is (= 2 (length (node-children result))))
    (is (equal "keep" (first (node-children result))))))
