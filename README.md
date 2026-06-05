# Classic Composer

The Classic Composer assembles content for display. It sits between
Classic's persistence layer (where content entities live) and Lexis
renderers (which produce HTML, PDF, terminal output, etc.). Given a
content entity, a theme, and a page template, the composer resolves
the theme's inheritance chain, fills template slots, evaluates
conditional anchors, applies lens-driven entity rendering, and
produces a complete Lexis s-expression tree ready for rendering.

The composer is read-only with respect to Classic's data. It does not
modify entities, create relationships, or trigger workflow transitions.
It only reads.

## A Blog Post, End to End

Here is the composer producing an HTML page for a blog post. We will
set up a blog, write a post, compose a page, and render it.

### Setup

Load the systems:

```lisp
(ql:quickload '("classic.composer.dist.alpha" "lexis.html"))
```

Create a blog and write a post:

```lisp
(defvar *blog* (classic.models.common:make-blog
                :name "Demo Blog"
                :authority "demo.blog"
                :authority-date "2026"))

(defvar *alice* (classic.models.common:create-account *blog*
                  :name "Alice" :role :writer))

(classic.models.common:write-post *blog*
  :account *alice*
  :title "Why Lisp Endures"
  :text "placeholder"
  :categories '("lisp" "programming"))
```

Now set the post body to a Lexis s-expression. In production, a
Lexis-aware editor (Seed) would store structured content directly.
Here we set it manually:

```lisp
(defvar *post* (first (classic.models.common:get-posts *blog*)))

(setf (classic.schema:body *post*)
  '(section (@ :title "Why Lisp Endures")
     (section (@ :title "Homoiconicity" :id "homoiconicity")
       (paragraph "Lisp's code-as-data property means the language can
*transform itself*. Macros are not text substitution — they are
programs that write programs, operating on the same data structures
the runtime uses."))
     (section (@ :title "CLOS" :id "clos")
       (paragraph "The Common Lisp Object System provides **multiple
dispatch**, method combination, and a metaobject protocol that lets
you redefine the rules of object orientation itself."))
     (section (@ :title "The Condition System" :id "conditions")
       (paragraph "Unlike exception systems that unwind the stack, CL's
condition system lets the *caller* decide how to handle errors without
destroying the context where the error occurred."))))
```

The body is now a Lexis s-expression -- a list that the composer
handles directly as structured content.

### Composing the Page

Create a composition context and a custom frame template with header
and footer:

```lisp
(use-package :classic.composer)

;; Build the composition context
(defvar *ctx* (make-context
               :strategy (classic.models.common:blog-strategy *blog*)
               :publication (classic.models.common:blog-publication *blog*)
               :entity *post*))

;; Override the default frame with a richer template
(defmethod compose-frame ((context composition-context))
  (let ((title (classic.schema:headline (context-entity context))))
    `(document (@ :title ,title)
       (navigation
         (web-link (@ :uri "/") "Home")
         (web-link (@ :uri "/posts") "Posts")
         (web-link (@ :uri "/about") "About"))
       (template.slot (@ :name "main-content"))
       (footer
         (paragraph "\u00A9 2026 Classic Demo Blog. Powered by Classic.")))))

;; Compose the page
(defvar *page* (compose-page *ctx*))
```

The result in `*page*` is a Lexis s-expression:

```lisp
(document (@ :title "Why Lisp Endures")
  (navigation
    (web-link (@ :uri "/") "Home")
    (web-link (@ :uri "/posts") "Posts")
    (web-link (@ :uri "/about") "About"))
  (section (@ :title "Why Lisp Endures")
    (section (@ :title "Homoiconicity" :id "homoiconicity")
      (paragraph "Lisp's code-as-data property means the language can
*transform itself*. Macros are not text substitution ..."))
    (section (@ :title "CLOS" :id "clos")
      (paragraph "The Common Lisp Object System provides **multiple
dispatch**, method combination ..."))
    (section (@ :title "The Condition System" :id "conditions")
      (paragraph "Unlike exception systems that unwind the stack ...")))
  (footer
    (paragraph "\u00A9 2026 Classic Demo Blog. Powered by Classic.")))
```

### Rendering to HTML

Pass the composed tree to Lexis for rendering:

```lisp
(defvar *html* (lexis.html:render-html *page* :standalone t))
```

This produces a complete HTML page. See
[doc/demo-output.html](doc/demo-output.html) for the rendered result.

The pipeline was:

```
Classic persistence  ->  Composer  ->  Lexis renderer  ->  HTML
   (blog-article)      (theme +       (render-html)
                        templates +
                        lenses)
```

Each stage is a pure transformation. The composer produced Lexis
s-expressions; the renderer produced HTML. Neither stage knows about
the other's internals.


## Architecture

### The Composition Pipeline

Every page composition follows this sequence:

```
 1. Resolve theme (chain, capabilities, overrides, lenses, slot-fills)
 2. Validate theme capabilities against registry
 3. Bind theme config and slot-fills to context
 4. Compose tiers (frame, feature, adjunct, aggregate, operative)
 5. Bind tier outputs to named slots
 6. Resolve template slots (substitute bindings into frame)
 7. Run collectors (gather structural metadata)
 8. Evaluate anchors (query-driven conditional content)
         |
    Lexis s-expression tree (ready for rendering)
```

Each step is a single O(n) pass over the tree. The full pipeline is
O(n) with a small constant factor -- no recursion between stages, no
retry loops, no dependency resolution.

### The Five Content Tiers

The composer organizes page content by structural role, not by
application domain. This makes the tiers reusable across blogs,
wikis, forums, and any other publication type.

| Tier | Role | Example |
|------|------|---------|
| **Frame** | Page skeleton -- nav, header, footer, sidebar structure | The HTML `<body>` layout |
| **Feature** | Primary content the page exists to present | A blog article's body |
| **Adjunct** | Content subordinate to or annotating the feature | Comments, author cards, related posts |
| **Aggregate** | Collection views -- listings, search results, feeds | A blog index page |
| **Operative** | Interactive control placement | Comment form, search dialog |

Application models specialize `compose-feature`, `compose-adjunct`,
etc. for their content types. The base package provides working
defaults for all tiers.

### Theme Integration

The composer consumes Classic core's theme ontology. A theme
(`classic-theme`) declares capabilities, provides tier templates
(Lexis fragments), and carries Fresnel-inspired lenses for
property-level entity rendering.

Child themes inherit from parents via the `parent-theme` slot.
The composer resolves the full inheritance chain at context creation
and merges capabilities (with exclusion support), configuration
bindings, slot-fills, tier templates, and lenses.

**Tier template cascade:** For each tier, the composer checks:
1. Per-tier override (`classic-theme-override`) -- wins if present
2. Theme's `tier-templates` entry for the tier
3. Built-in default

**Slot-fills:** Parent themes designate extension points via
`template.slot` nodes in their templates. Child themes supply
Lexis subtrees for those named slots without replacing the entire
template. This provides fine-grained structural extension.

**Capability activation:** The theme's resolved capability set
(after exclusion) determines which registered composer capabilities
participate in dispatch. Unregistered capabilities produce warnings
(or errors in strict mode via `*strict-capabilities*`).

### Lens-Driven Feature Composition

When a theme provides lenses (Fresnel-inspired property specs),
the feature tier uses them to determine which entity slots to render
and how. The display mode cascade:

1. Explicit `:display` from the lens property spec
2. Slot's MOP `:format` annotation (`:markdown` or `:html`)
3. Slot's `:persistence :relation` with no sublens -> `:link`
4. `:text` (universal fallback)

Display modes: `:text`, `:image`, `:link`, `:uri`, `:html`,
`:markdown` (stubbed), `:date`, `:list`.

Sublens references handle relation slots: the composer retrieves
the related entity, finds the target lens, and recursively applies
it. Fallback chain: target purpose -> `:label` purpose for actual
class -> entity's `label` slot.

Without lenses, the feature tier falls back to direct body
extraction from the entity.

### Template Slot Resolution

Templates are Lexis documents with `template.slot` placeholder nodes:

```lisp
(document (@ :title (template.slot (@ :name "page-title")))
  (navigation ...)
  (template.slot (@ :name "main-content"))
  (sidebar
    (template.slot (@ :name "sidebar-content")))
  (footer ...))
```

The composer binds values to slot names via `context-bind`, then
`resolve-slots` substitutes them in a single tree walk. Slots can
appear as element children or as attribute values.

Resolution is single-pass by convention. Inner content is composed
before being bound to outer templates. This eliminates the recursive
template expansion that causes exponential blowup in other systems.

### Collect Phase and Anchor Handlers

Anchors are named hooks in templates that produce conditional,
query-driven content:

```lisp
(compose.anchor (@ :name "table-of-contents"))
(compose.anchor (@ :name "related-by-tags" :limit 5 :fallback nil))
```

Before anchors evaluate, the **collect phase** walks the resolved tree
and gathers structural metadata (section headings, link targets,
entity counts). Collectors register globally:

```lisp
(define-collector "sections" (context node)
  (when (and (tagged-node-p node)
             (string= "SECTION" (symbol-name (node-tag node))))
    (let ((title (get-attr node :title))
          (id (get-attr node :id)))
      (when title
        (collect-into context "sections"
                      (list :title title :id id))))))
```

Anchor handlers then read collected data:

```lisp
(define-anchor-handler "table-of-contents" (ctx entity params)
  (let ((sections (context-collected ctx "sections")))
    (when sections
      `(unordered-list
         ,@(mapcar (lambda (s)
                     `(item (web-link (@ :uri ,(format nil "#~A" (getf s :id)))
                              ,(getf s :title))))
                   sections)))))
```

This is the Scribble-style "collect then render" pattern. No anchor
depends on another anchor's output -- they all depend on the content
structure, which is fully determined before any anchor evaluates.
Strategic ordering (document order) determines evaluation sequence.

### Capability Extensions

Capabilities are additive extensions. Each registers a handler for
specific content patterns within a tier:

```lisp
(define-capability "frame.hero"
    (:tier :frame
     :description "Hero image/banner support for frames"
     :predicate (lambda (ctx node)
                  (declare (ignore ctx))
                  (string= "HERO-IMAGE" (symbol-name (node-tag node)))))
  (context node)
  (let ((src (get-attr node :src))
        (alt (get-attr node :alt)))
    `(figure (@ :class "hero")
       (image (@ :src ,src :alt ,alt)))))
```

No capability is mutually exclusive with another. They compose
without conflict because each augments a specific content pattern
rather than replacing a tier wholesale.

### Performance Characteristics

The composer is designed for predictable, linear-time composition
suitable for large hosting clusters processing thousands of pages
concurrently.

**Guaranteed O(n) composition.** The pipeline makes a fixed number
of sequential passes over the tree (compose, resolve, collect,
evaluate). No pass triggers re-execution of a previous pass. No
recursion between stages. Tree size is the only variable -- doubling
the page's content exactly doubles composition time.

**No exponential template expansion.** Slot resolution is single-pass.
A resolved slot's value is not re-scanned for further slots. This
eliminates the pathological case seen in WordPress shortcode
processing, where nested shortcodes can trigger exponential
re-parsing.

**No dependency resolution between anchors.** Anchors are evaluated in
document order. There is no topological sort, no cycle detection, no
"run until stable" retry loop. The collect phase provides all the
metadata anchors need without requiring anchor-to-anchor communication.

**No unbounded recursion.** The convention that inner content is
composed before outer templates means the framework never recurses
into already-resolved content. Each tier composes independently,
producing its output in bounded time.

**Embarrassingly parallel at the page level.** Each page's composition
is independent -- no shared mutable state between pages. A rendering
cluster can process pages concurrently with no coordination beyond
the persistence layer's read path.

These properties mean that composition time is predictable and
proportional to page complexity. No pathological input can trigger
super-linear behavior from the framework. The only variable cost is
in anchor handler bodies (persistence queries), which are bounded by
the handler's own logic and the persistence layer's read performance.


## System Structure

```
classic.composer.asd              -- composer system (depends on classic + schema)
classic.composer.dist.alpha.asd   -- distribution shim (composer + alpha dist + models)
src/
  packages.lisp     -- package definition + Lexis tag symbol exports
  context.lisp      -- composition-context class, query helpers, collections
  protocol.lisp     -- tier generic functions, Lexis tree utilities
  capability.lisp   -- capability registry, dispatch, define-capability
  template.lisp     -- template.slot resolution
  anchor.lisp       -- compose.anchor registry, handler dispatch
  collector.lisp    -- collect phase: metadata gathering
  theme.lisp        -- theme resolution glue, tier template cascade, asset collection
  lens.lisp         -- Fresnel-style lens evaluation, display modes, sublens recursion
  defaults.lisp     -- default compose-page + tier method implementations
doc/
  Composer.md       -- detailed architecture document
  demo-output.html  -- sample rendered output from the demo above
```

## Dependencies

- `classic` -- the Classic foundation (MOP, persistence protocol, URI scheme)
- `classic.schema.alpha` -- the alpha schema (ontological classes, theme resolution)
- `closer-mop` -- MOP access for lens display mode cascade

For the complete user experience, load `classic.composer.dist.alpha`:

```lisp
(ql:quickload "classic.composer.dist.alpha")
```

This pulls in the full alpha distribution (foundation, schema, engine,
common content models) plus the composer.

The composer produces Lexis s-expressions as output. To render them,
load a Lexis renderer (`lexis.html` for HTML, others for PDF,
terminal, etc.). The composer itself has no dependency on Lexis -- it
produces the s-expression format directly.

## License

BSD-3
