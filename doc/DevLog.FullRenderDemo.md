# Full Render Demo: Development Log

This document chronicles the construction of the Classic Composer's
end-to-end HTML rendering demo. The demo runs the complete pipeline
from Classic content entities through theme resolution, lens
evaluation, template slot resolution, and the Lexis HTML renderer to
finished HTML files. It is the first piece of work that exercises
every piece of composer machinery against a real schema and produces
output a browser can display.

**Date:** 2026-06-05


## Problem

The composer had been built up through several rounds of design and
implementation: the five-tier model, capability registry, anchor
handlers, the collect phase, theme integration with chain resolution
and lens evaluation, and a complete test suite. The pieces all worked
in isolation. Each was covered by tests against synthetic inputs.

What had not happened was a full end-to-end run from a real Classic
publication through the composer to rendered HTML. The integration
points between layers -- particularly the asset surface (theme manifest
to Lexis renderer) and the aggregate tier (no working default) -- were
either underspecified or stubbed. Without a working demo:

- The asset surface was a sketch. The composer produced
  `(stylesheet ...)` and `(script ...)` nodes; the Lexis HTML renderer
  had no methods for those tags. Stylesheets would silently fall
  through pass-through rendering as generic divs.
- The default `compose-aggregate` returned NIL when no theme template
  was provided. The natural use case -- "show this container's
  contents as an index" -- required application code to specialize
  the generic.
- The README's earlier inline "demo" was paper-only. It described
  what would happen rather than something the reader could run.
- Several integration choices that looked clean on paper had not been
  validated against actual rendering output. The shape of a rendered
  page reveals decisions that are invisible at the protocol level.

This iteration produced a runnable, self-contained demo that turns
three blog posts into two HTML pages -- a single-post page and a
listing page -- through the full composition stack. Building it
surfaced the gaps and forced their resolution.


## Concurrent Lexis Change: Passthrough

In parallel with this work, Lexis gained a `passthrough` tag (Lexis
spec Section 5.4). A passthrough node carries opaque verbatim content
labeled for one or more target media:

```lisp
(passthrough (@ :medium :html)
  (:link :rel "stylesheet" :href "main.css"))
```

The HTML renderer recognizes the passthrough mechanism. When its
`:medium` attribute names HTML, the renderer emits the children
directly as Spinneret-style HTML forms or raw strings. Other media
omit the node. This is the right tool for stylesheets, scripts, JSON-LD
blocks, and other content that is intelligible only to one rendering
target.

The composer's asset surface is the natural first consumer of
passthrough. Theme asset manifests list stylesheets and scripts; the
composer needs to emit references that land in the rendered output's
`<head>` or `<body>`. Without passthrough, the composer would have had
to invent its own tag vocabulary for these references and the Lexis
HTML renderer would have grown methods to handle each. With
passthrough, the composer wraps each asset reference in a generic
medium-tagged shell and the renderer's existing passthrough method
emits it.


## Design Decisions

### 1. Asset surface uses Lexis passthrough

**Question:** How should the composer surface stylesheet and script
references for the HTML renderer to emit as `<link>` and `<script>`
tags?

**Decision:** Wrap each asset reference in a `(passthrough (@ :medium
:html ...) (:link ...))` form. The `:medium :html` attribute targets
the HTML renderer; the inner `(:link ...)` is a Spinneret-style native
HTML form that the renderer's passthrough method emits verbatim.

```lisp
(passthrough (@ :medium :html :kind :stylesheet)
  (:link :rel "stylesheet" :href "/static/blog.css"))

(passthrough (@ :medium :html :kind :script)
  (:script :src "/static/nav.js"))
```

The `:kind` attribute is a hint for renderers that want to group or
re-position assets (e.g., move all stylesheets to `<head>` regardless
of where they appear in the source). The HTML renderer ignores it
today; the data is there when a future renderer wants it.

This choice preserves Classic's core principle of being medium-
independent at the data layer. The composer doesn't care about HTML
specifically -- it produces a Lexis tree containing passthrough nodes
labeled for HTML. A PDF or terminal renderer would simply omit them.

### 2. Asset list binds to a slot via splice

**Question:** Where does the asset list get inserted into the page?

**Decision:** Bind the asset list to a slot named `theme.assets` and
let frame templates include `(template.slot (@ :name "theme.assets"))`
where they want the assets to appear -- typically near the top of the
document, since browsers process `<link>` and `<script>` tags from any
position and the renderer's `<head>` placement is template-driven.

The slot resolver already supports splice semantics: when a slot
binding is a list whose first element is itself a list (a Lexis
subtree), the list is spliced into the parent rather than wrapped in
a container. The asset list is exactly that shape -- a list of
passthrough nodes -- so the existing mechanism handles placement
without new machinery.

The earlier sketch wrapped the asset list in a `(section (@ :class
"theme-assets") ...)`. That added a meaningless container element to
the output. Removing the wrapper and letting splice do its work
produces cleaner HTML.

### 3. Default `compose-aggregate` walks `classic-container` entities

**Question:** When no theme provides an `:aggregate` tier-template,
what should the default `compose-aggregate` do?

**Decision:** If the context entity is a `classic-container`, walk its
`contains` slot, retrieve each item, and apply a lens (preferring
`:summary` purpose, falling back to `:label`). Each entry becomes a
`(section (@ :class "aggregate-entry") ...)`. The whole list is
wrapped in `(section (@ :class "aggregate") ...)`.

The alternative was to leave it NIL and require application models to
specialize `compose-aggregate` for every use case. That made even the
trivial "list this container's contents" case require a `defmethod`.
Since walking a container and applying a lens is genuinely generic --
it works for any container of any entity type, given appropriate
lenses -- pushing it into the default reduces boilerplate and makes
index pages work out of the box.

The cascade is: theme `:aggregate` template -> container walk -> NIL.
Application models that want different aggregate behavior still
specialize, but the common case is now covered.

### 4. Lens preference: `:summary` then `:label`

**Question:** Which lens purpose should the default container walk
use to render entries?

**Decision:** Try `:summary` first; fall back to `:label`.

`:summary` is a richer view than `:label` (typically headline + date
+ excerpt) intended for index entries. `:label` is the minimal terse
reference. A theme that wants a richer index defines a `:summary`
lens; a theme that defines only `:label` still gets a working index
with bare titles.

### 5. `compose-feature` no longer adds a title attribute to the wrapper

**Question:** Should the section wrapping the lens output carry a
`:title` attribute derived from the entity?

**Decision:** No. The wrapper is now `(section (@ :class "feature")
...)` -- class-tagged, no title.

Earlier, `compose-feature` wrapped lens output in `(section (@ :title
,title) ...)`. When the lens included `headline` as a property, the
title appeared twice in the rendered output -- once from the section's
`:title` attribute (rendered as `<h2>`) and once from the lens
property (rendered as bare text).

The lens already controls property selection and ordering. If the
lens author wants the headline shown, they include it; if they don't,
they don't. Having `compose-feature` independently inject the title
fights the lens's intent. Removing the title from the wrapper makes
the lens fully responsible for what appears at the top of the
feature.

### 6. Standard `page-title` binding from the entity

**Question:** Themes naturally want the page's `<title>` element to
carry the entity's title. How should this flow without per-page
boilerplate?

**Decision:** When the context has an entity, `compose-page` binds
`page-title` to the entity's headline-or-label automatically (unless
already bound). Frame templates that need the title use
`(template.slot (@ :name "page-title"))` either as document attribute
or as element content.

This is a small but real ergonomic win. Without the auto-binding,
every consumer would have to call `(context-bind ctx "page-title"
...)` before `compose-page` -- a step that has only one sensible
answer in the common case.

The binding is conditional on the slot not already being bound, so
explicit overrides still win.

### 7. Body sections as a list, with passthrough rendering handling both

**Question:** What shape should an article body have when stored as
Lexis s-expressions?

**Decision:** Allow either a single tagged subtree or a list of
sibling tagged subtrees. The `:html` display mode's renderer (
`render-html-passthrough`) detects the shape and wraps a list in
`(section (@ :class "body") ...)` while passing a single tree through
unchanged.

This matches authoring practice: a short article is one section; a
longer one may have several top-level sections. Both should "just
work" without authors having to add a top-level wrapper.

### 8. Demo body data uses an alist with `:body` key

**Question:** How should the demo data express bodies that have
multiple sections?

**Decision:** Each post entry is `(title (alist))` where the alist
has `(:keywords ...)` and `(:body section1 section2 ...)`. The body
sections are spliced after the `:body` keyword. Extracting them is
`(cdr (assoc :body data))`.

This matches Lisp's natural alist convention: a key followed by zero
or more values. It avoided introducing a separate field for "list of
sections" and keeps each post entry compact.

### 9. Self-contained demo file, no fixtures

**Question:** Should the demo load fixture files for blog posts, the
theme, and the stylesheet? Or contain everything inline?

**Decision:** Contain everything inline. The post bodies are a
parameter at the top of the file; the theme and stylesheet are
constructed by the demo's setup functions. The only external file is
`blog.css`, which is referenced by URL and not required for the demo
to run successfully (the HTML still renders correctly even if the
CSS file is missing -- the page just looks unstyled).

Self-contained means a reader can clone the repo, load the systems,
load the demo, and see results. No environmental setup, no fixture
loading, no path manipulation beyond what's needed to find the demo
file itself.


## Implementation

### Composer changes

#### `src/theme.lisp`: passthrough asset nodes

`theme-asset-list` was rewritten to produce passthrough nodes:

```lisp
(:stylesheet
 (push `(passthrough (@ :medium :html :kind :stylesheet)
         (:link :rel "stylesheet" :href ,uri))
       nodes))
(:script
 (push `(passthrough (@ :medium :html :kind :script)
         (:script :src ,uri))
       nodes))
```

The previous version produced custom `(stylesheet ...)` and
`(script ...)` tags that had no Lexis renderer methods.

#### `src/defaults.lisp`: `compose-page` enhancements

Two additions:

1. Standard entity-derived bindings: when an entity is set,
   `page-title` is bound to its title (if not already bound).
2. Asset binding now binds the bare list (for splice) instead of
   wrapping in a `(section ...)` container.

`compose-feature` lost the `:title` attribute on its wrapper section,
delegating title placement entirely to the lens.

#### `src/defaults.lisp`: default `compose-aggregate` container walk

A new default for `compose-aggregate` plus two helpers:

```lisp
(defmethod compose-aggregate ((context composition-context))
  (or (theme-tier-template context :aggregate)
      (let ((entity (context-entity context)))
        (when (typep entity 'classic.schema:classic-container)
          (compose-container-entries context entity)))))

(defun compose-container-entries (context container) ...)
(defun compose-container-entry (context uri) ...)
```

The entry function applies a lens (`:summary` then `:label`) and
falls back to bare label text if no lens matches.

#### `src/lens.lisp`: `render-html-passthrough` handles list values

Extended to handle three shapes: single tagged node, list of tagged
nodes (wraps in a containing section), other (coerces to string).

### Demo files

#### `examples/blog-demo.lisp` (~225 lines)

A self-contained Common Lisp file that:

- Defines a `classic.composer.demo` package using all the right
  systems
- Captures its own load directory via `*demo-source-directory*` so
  output paths resolve regardless of caller environment
- Provides `setup-blog`, `setup-theme`, `render-post-page`,
  `render-list-page`, and `run-demo` as the public entry points
- Stores three sample posts as Lexis s-expressions inline in
  `+post-bodies+`
- Constructs and persists a single `classic-theme` with a frame
  template, slot-fills, asset manifest, and three lenses (article
  default + summary, person label)
- Writes both rendered pages to `doc/demos/` when `run-demo` is
  called

#### `examples/static/blog.css` (~85 lines)

A reference stylesheet that styles the demo's class-tagged sections:
`.site-header`, `.site-footer`, `.aggregate`, `.aggregate-entry`,
`.feature`. Minimal; intended as a starting point readers can replace.

### Test changes

`test/test-theme-integration.lisp` updated:
`theme-asset-list-produces-lexis-nodes` renamed to
`theme-asset-list-produces-passthrough-nodes` and updated to verify
the new shape (`PASSTHROUGH` tag, `:medium :html` attribute,
`:kind` distinguishing stylesheet vs script).

`test/test-defaults.lisp` gained three tests for the new
`compose-aggregate` default:

- `compose-aggregate-walks-container` -- two-entry container produces
  two entries
- `compose-aggregate-uses-summary-lens` -- summary lens applied when
  available
- `compose-aggregate-nil-without-container` -- non-container entity
  with no theme template returns NIL

### Documentation changes

`README.md`'s demo section was rewritten to reference the new
self-contained demo and link to the rendered output files. The
inline narrative was replaced with a structural overview of what the
demo exercises.


## Design Properties Preserved

The demo work did not weaken the composer's existing guarantees:

- **O(n) pipeline.** The new entity-derived `page-title` binding
  is O(1). The asset list construction is O(assets). The container
  walk in default `compose-aggregate` is O(N) in the container size,
  with each entry O(L) in the lens property count. The full
  composition remains a fixed number of linear passes.
- **No registry pollution.** The demo runs end-to-end without
  registering global capabilities, anchor handlers, or collectors.
  It exercises the data path only.
- **Schema-agnostic via nickname.** The demo references schema
  symbols through `classic.schema:`. The same demo source could be
  paired with a future schema variant by loading a different
  distribution.


## Issues Encountered

### Source-relative paths

The first version of the demo used `*load-pathname*` to anchor output
paths. When `run-demo` was called from the REPL after the demo file
was loaded, `*load-pathname*` had been overwritten by whatever was
loaded most recently (typically NIL or a script file in `/tmp`).
Output paths resolved to nonexistent directories.

The fix was to capture the demo's source directory at load time into
a `defparameter` and use that for all output path resolution.

### Body slot format collision with Lexis content

The `classic-article` body slot has `:format :markdown` in the
schema. The display mode cascade reads MOP annotations, so without an
override the cascade returns `:markdown` for the body property -- and
the markdown stub coerces non-string values to a `princ-to-string`
representation, which produces unreadable raw s-expression output.

The fix was to add `:display :html` explicitly to the lens's body
property. The schema's annotation reflects what most production blog
posts will store (Markdown text); the demo overrides because it stores
Lexis s-expressions directly.

This surfaces a real design choice: when the body slot's intended
format and the actual stored format differ, the lens has to declare
the override. That's the right place for it -- the lens is theme-
specific and explicit, while the schema's `:format` is a general
default.

### Test failure from package-qualified `eq`

After adding the `compose-aggregate` container walk and its tests, one
test failed because the assertion used `(eq 'section (node-tag
result))`. The composer constructs the section symbol in its own
package; the test's `'section` is in the test package. Same printed
name, different symbols.

The fix was the same pattern used elsewhere in the test suite:
`(string= "SECTION" (symbol-name (node-tag result)))`. Package-
independent and consistent with how the composer itself detects tag
identities.


## Verification

Test suite: 181 checks, 100% passing. The new
`compose-aggregate-walks-container` test exercises the new default;
the renamed asset list test verifies the passthrough shape.

End-to-end: running `(classic.composer.demo:run-demo)` produces
`doc/demos/blog-post-output.html` and `doc/demos/blog-list-output.html`
with no errors. The post page contains:

- Document title in `<head>` and as `<h1>`
- Stylesheet link emitted via passthrough
- Site header from theme slot-fill
- Article body with two nested sections, each with its own heading
  and paragraph
- Author byline rendered through sublens
- Date rendered through `:date` display mode
- Tag list rendered through `:list` display mode
- Site footer from theme slot-fill, with a working web-link

The list page contains:

- Document title bound from the container's label ("Demo Blog Posts")
- Same site header / footer as the post page
- Three entries, each a section with the post title and date


## Files

| Action | File | Description |
|---|---|---|
| Modified | `src/theme.lisp` | `theme-asset-list` produces passthrough nodes |
| Modified | `src/defaults.lisp` | `compose-page` `page-title` binding; asset splice; `compose-feature` no title; default `compose-aggregate` for containers; helpers `compose-container-entries`, `compose-container-entry` |
| Modified | `src/lens.lisp` | `render-html-passthrough` handles list-of-nodes shape |
| Modified | `test/test-theme-integration.lisp` | renamed test, verifies passthrough shape |
| Modified | `test/test-defaults.lisp` | three new tests for default `compose-aggregate` |
| Modified | `README.md` | demo section rewritten to point to runnable demo |
| Created | `examples/blog-demo.lisp` | self-contained end-to-end demo |
| Created | `examples/static/blog.css` | reference stylesheet |
| Created | `doc/demos/blog-post-output.html` | rendered output |
| Created | `doc/demos/blog-list-output.html` | rendered output |
| Created | this file | |


## Metrics

- New source files: 2 (`examples/blog-demo.lisp`,
  `examples/static/blog.css`)
- New rendered output files: 2 (regenerated by `run-demo`)
- Source line changes: ~80 in production code, ~50 in tests
- Test count: 181 (up from 178), all passing


## Outstanding Work

- **Asset placement in `<head>`.** The HTML renderer currently emits
  passthrough nodes wherever they appear in the source tree. For
  stylesheets and scripts, the natural target is `<head>`. The
  `:placement` attribute on passthrough nodes (`:head` vs `:body`)
  is a hook for this; making the renderer honor it is a Lexis-side
  enhancement.
- **Author URI to person resolution.** The demo's `write-post` stores
  the post with `author` set to a person URI. The lens correctly
  resolves the person via sublens. But the demo doesn't show
  multi-author posts or comment threading -- those would extend the
  demo without changing the composer.
- **Markdown display mode.** Still stubbed. The demo works around
  this by setting `:display :html` on the body lens property. A real
  Markdown parser dependency would let blog content stored as
  Markdown render without lens overrides.
- **Capability extensions.** No capability extension is exercised by
  the demo. A follow-up demo could load `classic.composer.frame.hero`
  (when it exists) and show capability dispatch in action.
- **Child themes.** The demo uses one theme. A follow-up could show
  a parent + child theme pair with capability exclusion and slot-fill
  overrides.
- **Workflow integration.** The demo skips the publish workflow
  (writer-only). A real-world demo could show the
  draft -> published transition gating which posts appear on the
  index.

These extensions are additive. The current demo establishes the
end-to-end pipeline; everything else is an example of what fits on
top of it.
