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

## Demos

Three self-contained demos exercise the full pipeline. Each builds a
publication, defines a theme, composes pages, and renders a small
static site of linked HTML pages:

| Demo | Pages | Run |
|------|-------|-----|
| [Blog demo](examples/blog-demo.lisp) | Index + a page per post | `(classic.composer.demo:run-demo)` |
| [Forum demo](examples/forum-demo.lisp) | Thread list + a page per thread + a profile per member | `(classic.composer.forum-demo:run-demo)` |
| [Wiki demo](examples/wiki-demo.lisp) | Alphabetical index + a page per article, with typed infoboxes | `(classic.composer.wiki-demo:run-demo)` |

Rendered output is written to [doc/demos/](doc/demos/), one directory
per demo, each starting at its `index.html`. The demos only read
their publications: thread order, member nicknames, page references
and index order are all computed while the pages are composed.

## A Blog, End to End

A complete, runnable demo lives at [examples/blog-demo.lisp]
(examples/blog-demo.lisp). It builds a blog with three sample posts,
defines a single theme covering both an individual post page and an
index page, and renders the index and every post as HTML files in
`doc/demos/blog/`.

To run from a fresh REPL:

```lisp
(ql:quickload "classic.composer.dist.alpha")
(ql:quickload "lexis.html")
(load "examples/blog-demo.lisp")
(classic.composer.demo:run-demo)
```

This writes:

- [doc/demos/blog/index.html](doc/demos/blog/index.html)
  -- an index page listing all posts with title and date, each title
  linked to the post's page
- a page per post, such as
  [doc/demos/blog/why-lisp-endures.html](doc/demos/blog/why-lisp-endures.html)
  -- header, full article body, author byline, date, and tag list

The reference stylesheet at [examples/static/blog.css]
(examples/static/blog.css) provides minimal visual styling.

### What the Demo Shows

The demo exercises every layer of the pipeline:

```
Classic persistence  ->  Composer  ->  Lexis renderer  ->  HTML
  (blog model,           (theme         (render-html)        ^
   classic-theme)        chain +                             |
                         lenses +                            |
                         tier templates +                    |
                         slot-fills +                        |
                         capabilities)                       |
                                                             |
                       passthrough nodes carry stylesheet ---+
                       and script references through to
                       the HTML <head>
```

Specifically:

- **Theme resolution.** The publication's `ui-theme` slot points to a
  `classic-theme` resource. The composer walks the chain, merges
  capabilities, applies bindings and slot-fills, and resolves lenses
  before composition begins.
- **Frame template.** A single `:frame` tier-template includes named
  `template.slot` placeholders for the page title, brand area, main
  content, aggregate content, theme assets, and footer.
- **Slot-fills.** The brand and footer subtrees are theme-supplied
  slot-fills bound at composition time.
- **Asset surface.** The theme's `asset-manifest` lists `blog.css`;
  the composer emits a `(passthrough (@ :medium :html ...) ...)`
  node that the Lexis HTML renderer transcribes verbatim into a
  `<link rel="stylesheet">` tag.
- **Lens-driven feature composition.** The post page's article body
  is rendered through a `:default` lens that selects headline,
  author (via a `:label` sublens on `classic-person`), date, body,
  and keywords -- in that order, with display modes chosen per-slot.
- **Default container walk.** The index page sets the entity to the
  blog's post container; the default `compose-aggregate` walks the
  container's contents and applies the `:summary` lens to each
  entry, producing a `(section ...)` of compact post references.
- **Page links.** An `entity-href` method names each post's page,
  and the `:summary` lens marks the headline `:link :self`, so each
  index entry links to its post.

The demo is self-contained -- no shell scripts, no fixture files,
no extra configuration. Everything runs from one Lisp file.

### Snapshot of the Composed Tree

The post page's composed Lexis tree (before HTML rendering) looks
roughly like this:

```lisp
(document (@ :title "Notes on Reading Old Code")
  (passthrough (@ :medium :html :kind :stylesheet)
    (:link :rel "stylesheet" :href "/static/blog.css"))
  (section (@ :class "site-header")
    (paragraph (strong "Demo Blog"))
    (paragraph "A Classic Composer demonstration."))
  (section (@ :class "feature")
    "Notes on Reading Old Code"
    "Alice"
    "2026-06-05"
    (section (@ :class "body")
      (section (@ :title "Patience" :id "patience")
        (paragraph "Old code carries decisions ..."))
      (section (@ :title "Active Reading" :id "reading")
        (paragraph "Trace what calls what ...")))
    (unordered-list (item "learning") (item "code-review")))
  (section (@ :class "site-footer")
    (paragraph "(c) 2026 Demo Blog. Powered by "
               (web-link (@ :uri "https://example.com/classic")
                         "Classic") ".")))
```

Each stage is a pure transformation. The composer produced this Lexis
tree; the Lexis renderer produced the HTML. Neither stage knows about
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
`:markdown`, `:date`, `:list`.

The `:markdown` mode reads the slot's text with the Lexis Markdown
reader (`lexis.markdown`): headings become nested titled sections, and
lists, code blocks, block quotes, links, images, tables, definition
lists and wiki links become their Lexis tags. The reader is safe by
default: raw HTML is kept as text, and links keep only the `http`,
`https`, `mailto` and `classic` URI schemes. A body of several blocks
is spliced into the surrounding content rather than wrapped in a
section of its own.

Applications pass options to the reader by specializing the
`markdown-options` generic on their content classes. A wiki, for
example, supplies a resolver that turns `[[Page]]` into a link to the
named page:

```lisp
(defmethod markdown-options (context (entity wiki-page) slot-name)
  (declare (ignore context slot-name))
  (list :wiki-link-resolver #'resolve-wiki-link))
```

Sublens references handle relation slots: the composer resolves
the related entity, finds the target lens, and recursively applies
it. Fallback chain: target purpose -> `:label` purpose for actual
class -> entity's `label` slot.

Besides `:display`, `:sublens` and `:purpose`, a property spec takes
two options:

- `:link :self` links the rendered value to the page of the entity
  it belongs to, such as an index entry's title.
- `:label "Joined"` captions the value: `Joined: 2026-11-20`.

An `:aggregate` lens on a container class orders the container's
entries in aggregate views: `:sort-by` names the property to sort by,
and `:sort-order :descending` reverses it. Like every lens, it belongs
to a theme, so it orders only the publications that use the theme.

Without lenses, the feature tier falls back to direct body
extraction from the entity.

### Extension Generics

Applications adapt the composer to their content by specializing
generic functions, not by changing their data before composing. Each
generic's default keeps the behavior described above:

| Generic | Returns | Default | Example use |
|---------|---------|---------|-------------|
| `lens-property-value (context entity property)` | The value a lens reads for `property` | The slot's value | A computed property: a forum post's author account, found through the reverse `sioc:account_of` relation |
| `resolve-reference (context entity property value)` | The entity a reference names | Retrieve `value` as a URI | A wiki page's typed slots naming pages by anchor |
| `entity-href (context entity)` | The URL of the entity's page | `nil` (no link) | A static site's file names |
| `container-entries (context container)` | The entities an aggregate view lists, in order | `contains` in `container-reading-order`, sorted by an `:aggregate` lens | A forum listing pinned threads first |
| `container-reading-order (container)` | `:as-stored` or `:reverse` | `:as-stored` | A forum thread reading oldest-first |
| `markdown-options (context entity slot-name)` | Options for the Markdown reader | None | A wiki link resolver |

These are read paths: a method computes what a page shows and must
not modify the publication.

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
  protocol.lisp     -- tier and extension generic functions, Lexis tree utilities
  capability.lisp   -- capability registry, dispatch, define-capability
  template.lisp     -- template.slot resolution
  anchor.lisp       -- compose.anchor registry, handler dispatch
  collector.lisp    -- collect phase: metadata gathering
  theme.lisp        -- theme resolution glue, tier template cascade, asset collection
  lens.lisp         -- Fresnel-style lens evaluation, display modes, references, sublens recursion
  defaults.lisp     -- default compose-page + tier method implementations
test/
  package.lisp + 9 test files  -- 100+ tests across all subsystems
examples/
  blog-demo.lisp    -- self-contained blog end-to-end demo
  forum-demo.lisp   -- self-contained forum end-to-end demo
  wiki-demo.lisp    -- self-contained wiki demo with typed pages + child theme
  static/blog.css   -- reference stylesheet for the blog demo
  static/forum.css  -- reference stylesheet for the forum demo
  static/wiki.css   -- reference stylesheet for the wiki demo
doc/
  Arch.Composer.md        -- detailed architecture document
  Log.ThemeResolution.md    -- theme resolution development log
  Log.FullRenderDemo.md     -- full render pipeline development log
  Log.ForumRenderDemo.md    -- forum demo development log
  DevLog.WikiRenderDemo.md  -- wiki demo development log
  Log.LexisMarkdown.md      -- Lexis Markdown reader integration log
  INDEX.md                  -- Compass document index (generated)
  REGISTRY.sexp             -- Compass allocation ledger
  DevLog.ReadOnlyDemos.md   -- extension generics and page links log
  demos/
    blog/    -- blog demo: index.html + a page per post
    forum/   -- forum demo: index.html + thread-*.html + member-*.html
    wiki/    -- wiki demo: index.html + a page per article
```

## Dependencies

- `classic` -- the Classic foundation (MOP, persistence protocol, URI scheme)
- `classic.schema.alpha` -- the alpha schema (ontological classes, theme resolution)
- `closer-mop` -- MOP access for lens display mode cascade
- `lexis.markdown` -- the Lexis Markdown reader, for the `:markdown`
  display mode (it brings in the Lexis core and 3bmd)

`lexis.markdown` is a module of Lexis, in its `mod/markdown/`
directory. With Lexis in Quicklisp's `local-projects`, run
`(ql:register-local-projects)` once so that Quicklisp finds it.

For the complete user experience, load `classic.composer.dist.alpha`:

```lisp
(ql:quickload "classic.composer.dist.alpha")
```

This pulls in the full alpha distribution (foundation, schema, engine,
common content models) plus the composer.

The composer produces Lexis s-expressions as output. To render them,
load a Lexis renderer (`lexis.html` for HTML, others for PDF,
terminal, etc.). The composer depends on no renderer: it produces the
s-expression format directly, and uses Lexis only to read Markdown.

## License

BSD-3
