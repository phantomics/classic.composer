---
id:            CCOMPOSER-DRAFT-composerref
title:         Classic Composer Reference
genre:         Ref
scope:         project
project:       Classic Composer
language:      en
status:        Draft
api-version:   "0.2.0"
provenance:
  assistant:          claude-opus-5-5
  original-assistant: claude-opus-4-6
  migrated-from:      doc/Composer.md@7fa52ba
relates-to:
  - CCOMPOSER-DRAFT-composer
  - CCOMPOSER-DRAFT-lexismarkdown
  - CCOMPOSER-DRAFT-compass-migration
  - CLASSIC-0011
  - LEXIS-DRAFT-markdownref
---

# Classic Composer Reference

This reference describes the Classic Composer as it runs: the system
`classic.composer` at version 0.2.0, which assembles Classic content
into Lexis document trees. It covers the composition pipeline and its
tier generics, theme integration, lens evaluation, the extension
generics through which applications adapt composition to their
content, and template slots, anchors and collectors. The design
behind it, including the parts not yet built, is
[CCOMPOSER-DRAFT-composer](Arch.Composer.md); the theme ontology the
composer consumes is [CLASSIC-0011](../../classic/doc/theme/Ref.Theme.md).
Code references are pinned to commit `7fa52ba`. This reference was
split from the original architecture document, `doc/Composer.md`, as
[CCOMPOSER-DRAFT-compass-migration](Log.CompassMigration.md) records.


## Composition Pipeline

### `make-context`

`src/context.lisp:make-context@7fa52ba` creates a
`composition-context`, which carries the state of one composition: the
persistence strategy (required), the publication, the primary entity,
the theme, the bindings for template slots, and the collections the
collect phase fills. The theme is the entity at `:theme-uri` if given,
else `:theme`, else the one the publication's `ui-theme` names. When a
theme is found, its resolved state is computed at once (see
[Theme Resolution](#theme-resolution)).

The context reads Classic's data and never writes it:

- `context-retrieve` retrieves an entity by URI.
- `context-query` returns the subjects of a relation, as
  `query-relation` does: `(context-query ctx "sioc:account_of" uri)`.
- `context-bind` and `context-binding` set and read named bindings for
  template slots.
- `collect-into` and `context-collected` add to and read the
  collections of the collect phase.

### `compose-page`

`src/defaults.lisp:compose-page@7fa52ba` composes a page and returns a
Lexis `document` s-expression. In order:

1. Binds `page-title` to the entity's headline, or else its label,
   unless the binding exists already.
2. With a theme: validates its capabilities, binds its configuration
   entries as `theme.config.<key>`, binds its slot-fills by name, and
   binds its assets as `theme.assets`.
3. Composes the five tiers, each with its generic below.
4. Binds the tier outputs to the slots `main-content`,
   `adjunct-content`, `aggregate-content` and `operative-content`.
5. Resolves the frame's template slots (see
   [Template Slots](#template-slots)).
6. Runs the collect phase (see [Collect Phase](#collect-phase)).
7. Evaluates the anchors (see [Anchors](#anchors)).

Each step is one pass over the tree. The composed tree goes to a Lexis
renderer, such as the HTML renderer's `render-html`
(`LEXIS:mod/html/render.lisp:render-html@31dd926`), which the composer
does not load.

### Tier generics

Each tier is a generic function of the context, with a default method
in `src/defaults.lisp`. Applications specialize them for their content
types.

Table: The tier generics and what their default methods return.

| Generic | Default method returns |
|---------|------------------------|
| `compose-frame` | The theme's template for `:frame` (see [Tier Template Cascade](#tier-template-cascade)), or a minimal `document` holding the four content slots |
| `compose-feature` | The entity rendered through the theme's `:default` lens for its class, wrapped in `(section (@ :class "feature") ...)`; without a lens, the entity's body (see [The body fallback](#the-body-fallback)) |
| `compose-adjunct` | The theme's template for `:adjunct`, as a one-item list, or `nil` |
| `compose-aggregate` | The theme's template for `:aggregate`; otherwise, for a `classic-container` entity, a `(section (@ :class "aggregate") ...)` of its entries (see [Container entries](#container-entries)); otherwise `nil` |
| `compose-operative` | `nil` (`src/defaults.lisp:compose-operative@7fa52ba`); an application's method returns operative specs, plists that `compose-page` turns into `compose.operative` placeholder nodes |

#### The body fallback

Without a lens, `src/defaults.lisp:compose-feature-from-body@7fa52ba`
returns the entity's body:

- a Lexis form, as it is;
- a list of Lexis forms, in a section titled with the entity's title;
- a string, when the body slot is declared `:format :markdown`, read
  as Markdown into a titled section (see
  [Markdown Bodies](#markdown-bodies));
- any other string, as a paragraph in a titled section.

#### Container entries

The aggregate tier lists the entities `container-entries` gives for
the container (see [Extension Generics](#extension-generics)). Each
entry is rendered through the theme's `:summary` lens for its class,
or else its `:label` lens, and wrapped in
`(section (@ :class "aggregate-entry") ...)`. Without either lens, the
entry is its label, linked to its page when `entity-href` gives one.


## Theme Integration

Themes are first-class Classic resources (`classic-theme`) stored
through the persistence protocol. The core ontology defines what
themes are; the composer consumes them for rendering.

### Theme Resolution

At context creation, `src/theme.lisp:resolve-theme-for-context@7fa52ba`
resolves the full theme chain with the schema's resolution functions,
and stores the result on the context for the tier methods:

1. Walk `parent-theme` links from child to root
2. Merge capabilities (union, with exclusion support)
3. Collect the per-tier overrides of the most specific theme
4. Merge configuration bindings (child overrides parent keys)
5. Merge slot-fills (child overrides parent slot names)
6. Merge lenses (child overrides parent on (class, purpose) pairs)
7. Collect asset manifests (parent first, child last for CSS stacking)

### Tier Template Cascade

For each composition tier, `src/theme.lisp:theme-tier-template@7fa52ba`
selects a template via:

1. Per-tier override (`classic-theme-override` for this tier) -- wins
2. Theme's `tier-templates` alist entry for the tier

When neither gives one, the tier's default method supplies its
built-in default (a minimal frame, body extraction, etc.).

### Slot-Fills: Structural Extension Points

Parent themes designate extension points via `template.slot` nodes:

```lisp
(document (@ :title (template.slot (@ :name "page-title")))
  (header (template.slot (@ :name "theme.brand")))
  (template.slot (@ :name "main-content"))
  (template.slot (@ :name "theme.footer-extras"))
  (footer ...))
```

Child themes supply Lexis subtrees for these slots via the `slot-fills`
slot on `classic-theme`, without replacing the parent's template.
Slot-fills compose through inheritance: child entries override parent
entries on matching slot-name; unmatched parent entries pass through.
`src/theme.lisp:apply-theme-slot-fills-to-context@7fa52ba` binds each
fill by its slot name; a fill of `nil` is not bound, so its slot is
removed.

### Configuration and Assets

- **Configuration.** `src/theme.lisp:apply-theme-config-to-context@7fa52ba`
  binds each merged configuration entry, such as
  `("primary-color" . "#2a5db0")`, as a template binding named
  `theme.config.primary-color`.
- **Assets.** `src/theme.lisp:theme-asset-list@7fa52ba` turns the
  collected asset manifests, each file prefixed with its theme's
  `asset-base-uri`, into HTML passthrough nodes, which `compose-page`
  binds as `theme.assets`. Stylesheets become
  `(passthrough (@ :medium :html :kind :stylesheet) (:link :rel "stylesheet" :href ...))`
  and scripts a `<script>` element. Fonts and images give no node:
  they are referenced from stylesheets or content. Renderers for other
  media omit passthrough nodes.

### Capabilities

A capability is a named extension registered for a tier, with an
optional predicate on nodes and a handler that returns a Lexis subtree:
`src/capability.lisp:define-capability@7fa52ba`. `register-capability`,
`find-capability` and `list-capabilities` manage the registry, and
`src/capability.lisp:dispatch-capability@7fa52ba` calls the first
capability of a tier whose predicate accepts a node.

`compose-page` validates the theme with
`src/theme.lisp:validate-theme-capabilities@7fa52ba`: every capability
in the theme's activation set must be registered, and every one in its
`required-capabilities` must be in the activation set. A failure
signals a warning, or an error when `*strict-capabilities*` is true.
The default tier methods do not call `dispatch-capability`; a tier
method that supports capabilities calls it.


## Lens Evaluation

When a theme provides Fresnel-inspired lenses, the composer uses them
to determine which entity slots to render and how: the feature tier
through the `:default` lens of the entity's class, container entries
through `:summary` or `:label` lenses, and sublenses through the lens
they name. A lens is found for a class or its nearest superclass.

### Display Mode Cascade

For each property in a lens, `src/lens.lisp:compute-display-mode@7fa52ba`
chooses:

1. Explicit `:display` from the lens property spec
2. Slot's MOP `:format` annotation (`:markdown` -> `:markdown`, etc.)
3. Slot's `:persistence :relation` with no sublens -> `:link`
4. `:text` (universal fallback)

### Display Modes

`src/lens.lisp:render-slot-via-display-mode@7fa52ba` renders a value in
its mode; a `nil` value renders as nothing.

Table: The display modes, what each produces, and its use case.

| Mode | Produces | Use case |
|------|----------|----------|
| `:text` | The string, or a `(paragraph ...)` when it holds a newline; other values printed | Plain string slots |
| `:image` | `(image (@ :src ...))` | URI slots pointing to images |
| `:link` | A `web-link` to the referenced entity's page (see [Sublens References](#sublens-references)) | References shown as clickable links |
| `:uri` | Plain text of the URI | URI slots displayed as URIs |
| `:html` | Pass-through (already Lexis) | Body slots in Lexis form |
| `:markdown` | Blocks read by `lexis.markdown`, spliced in place | Body slots in Markdown |
| `:date` | A date as `YYYY-MM-DD` for a timestamp; a string as it is | Timestamp slots |
| `:list` | `(unordered-list ...)` | List-valued slots |

A mode may produce a list of blocks rather than one node: a Markdown
body of several blocks, or an `:html` slot holding a list of Lexis
forms. The lens evaluator splices such a list into the surrounding
content. Wrapping it in an untitled `section` instead would push its
sections one level deeper.

### Markdown Bodies

The `:markdown` mode reads text with the Lexis Markdown reader,
`lexis.markdown:markdown->lexis`, in
`src/lens.lisp:render-markdown@7fa52ba`. Markdown headings become
nested titled sections, and the reader's safe defaults apply: raw HTML
stays text, and links keep only the `http`, `https`, `mailto` and
`classic` URI schemes. The reader is described in
[LEXIS-DRAFT-markdownref](../../lexis/doc/Ref.Markdown.md).

The reader's options come from the `markdown-options` generic, called
with the composition context, the entity and the slot name. Its
default method returns no options. Application models specialize it
on their content classes. A wiki supplies a `:wiki-link-resolver` that
looks pages up by anchor, which the composer cannot do itself, since
it does not depend on the content models. Only content from a trusted
source should get `:raw-html :passthrough`.

The body fallback (no lens) reads a string body as Markdown when the
body slot is declared `:format :markdown`.

### Sublens References

Relation slots can declare a sublens: `(author :sublens classic-person
:purpose :label)`. `src/lens.lisp:apply-sublens@7fa52ba` resolves the
related entity, finds the target lens, and recursively applies it. A
list of references renders as an `unordered-list`, one item each.
Fallback chain:

1. Lens for (sublens-class, sublens-purpose)
2. Lens for (actual-class, :label)
3. Entity's `label` slot as plain text

The related entity is found with `resolve-reference`, so a reference
need not be a URI (see [Extension Generics](#extension-generics)).
The `:link` mode follows references the same way, in
`src/lens.lisp:render-reference-link@7fa52ba`. A resolved target
is linked to its page, or to the reference when that is a URI, and
shown by its title. An unresolved reference that is not a URI, such
as the name of a missing wiki page, is shown as text.

### Property Options

A lens property is a slot name, or a list of a slot name and options:
`(classic.schema:headline :link :self)`. Besides `:display`,
`:sublens` and `:purpose`:

Table: The lens property options and their effects.

| Option | Effect |
|--------|--------|
| `:link :self` | Link the rendered value to the page of the entity it belongs to (`entity-href`); for inline values such as titles |
| `:label "Text"` | Caption the value: an inline value becomes `(paragraph (strong "Text:") " " value)`; a block value is preceded by a paragraph holding the caption |

### Aggregate Lenses

A lens with purpose `:aggregate` on a container class orders that
container's entries in aggregate views. `:sort-by` names the property
to sort by, read like any lens property. `:sort-order :descending`
reverses the order. The sort is stable, numbers compare numerically,
other values compare by printed form without regard to case, and
entries without a value go last
(`src/defaults.lisp:sort-entities@7fa52ba`). Like every lens, an
aggregate lens belongs to a theme. It orders only the publications
that use the theme, and it changes the view, not the container.

```lisp
(:class classic-container :purpose :aggregate :sort-by headline)
```

### Lens functions

- `apply-lens` renders every property of a lens for an entity, and
  returns the rendered subtrees in property order, splicing block
  lists and skipping properties without a value.
- `src/lens.lisp:render-lens-property@7fa52ba` renders one property
  spec the way a lens does, for code that lays out properties itself,
  such as an infobox.
- `apply-sublens`, `compute-display-mode` and
  `render-slot-via-display-mode` are the steps above, exported for
  such code.


## Extension Generics

Applications adapt composition to their content by specializing
generic functions on their content classes. The composer is
read-only, so these are read paths: a method computes what a page
shows and must not change the publication. Each default keeps the
composer's base behavior. They are defined in `src/protocol.lisp`.

Table: The extension generics, what each returns, and its default.

| Generic | Returns | Default |
|---------|---------|---------|
| `lens-property-value (context entity property)` | The value a lens reads for `property` | The slot's bound value |
| `resolve-reference (context entity property value)` | The entity a reference names | Retrieve `value` as a URI |
| `entity-href (context entity)` | The URL of the entity's page | `nil`: no link |
| `container-entries (context container)` | The entities an aggregate view lists, in order | `contains`, in `container-reading-order`, sorted by an aggregate lens |
| `container-reading-order (container)` | `:as-stored` or `:reverse` | `:as-stored` |
| `markdown-options (context entity slot-name)` | Options for the Markdown reader | None |

- **Computed properties.** A lens names a property that is not a slot,
  and a `lens-property-value` method (usually with an `eql`
  specializer on the property) supplies its value. The forum demo's
  `post-author-account` finds a post's author account through the
  reverse relation `sioc:account_of`, with `context-query`.
- **References.** A wiki's typed slots name pages by anchor. A
  `resolve-reference` method on the wiki page class looks the anchor
  up, so sublenses and `:link` properties reach the pages.
- **Page links.** `entity-href` gives the URL scheme, which is the
  site's choice: file names for a static site, routes for a server.
  The composer links through `:link :self`, through `:link`
  references, and in container entries rendered without a lens.
- **Ordering.** An order that is a rule of the content type, such as
  a forum listing pinned threads first, is a `container-entries`
  method on the container class. An order that is a presentation
  choice, such as an alphabetical index, is an aggregate lens in the
  theme.


## Templates, Anchors and Collectors

### Template Slots

Templates are Lexis documents with `template.slot` placeholder nodes.
The composer substitutes content into slots by name:

```lisp
(document (@ :title (template.slot (@ :name "page-title")))
  (navigation ...)
  (section (@ :title (template.slot (@ :name "page-title")))
    (template.slot (@ :name "main-content")))
  (footer ...))
```

`src/template.lisp:resolve-slots@7fa52ba` replaces each slot with the
context binding of its name, in one pass. A binding may be a string, a
Lexis node, or a list of nodes, which is spliced in the slot's place.
Slots may also stand as attribute values, such as `:title`. A slot
with no binding is removed, unless `:remove-unresolved` is `nil`. A
resolved value is not searched for further slots.

### Anchors

`compose.anchor` nodes specify query-driven, conditional content
insertion:

```lisp
(compose.anchor
  (@ :name "related-by-tags"
     :limit 5
     :fallback nil))
```

`src/anchor.lisp:define-anchor-handler@7fa52ba` registers a handler for
an anchor name, a function of the context, the primary entity and the
anchor's other attributes as a plist. Anchor handlers return Lexis
trees that are spliced into the composed document; a handler that
returns `nil` removes its anchor. When no handler is registered for
the name, `src/anchor.lisp:evaluate-anchor@7fa52ba` signals a warning
and uses the anchor's `:fallback` attribute, so that `:fallback nil`
or no fallback removes the anchor. Anchors are evaluated in document
order, after the collect phase. Anchors keep query logic in CL where
it belongs while keeping the template declarative.

### Collect Phase

Before anchors evaluate, the collect phase walks the resolved tree
and gathers structural metadata (section headings, link targets,
entity counts). This is the Scribble-style "collect then render"
pattern that avoids cross-dependencies between anchors.

`src/collector.lisp:define-collector@7fa52ba` registers a collector, a
function of the context and a node. `src/collector.lisp:run-collectors@7fa52ba`
calls every registered collector on every node, in document order
(depth-first, pre-order). Collectors add to named collections with
`collect-into`, and anchor handlers read them with
`context-collected`, in document order.

The composer registers no collectors or anchor handlers itself;
applications and themes define them.

### Lexis tree utilities

The composer works on Lexis s-expressions, not parsed node objects,
and compares tags by symbol name, so trees built from any package's
symbols mix. `tagged-node-p`, `text-node-p`, `node-tag`, `node-attrs`,
`node-children`, `get-attr`, `walk-tree` and `transform-tree` read and
walk such trees.


## Project Structure

```
classic.composer.asd              -- the composer system; its test system
classic.composer.dist.alpha.asd   -- distribution shim (composer + alpha dist + models)
src/
  packages.lisp     -- package definition and exports
  context.lisp      -- composition-context class, query helpers, collections
  protocol.lisp     -- tier and extension generic functions, Lexis tree utilities
  capability.lisp   -- capability registry, dispatch, define-capability
  template.lisp     -- template.slot resolution
  anchor.lisp       -- compose.anchor registry, handler dispatch
  collector.lisp    -- collect phase: metadata gathering
  theme.lisp        -- theme resolution glue, tier template cascade, assets
  lens.lisp         -- lens evaluation, display modes, references, sublenses
  defaults.lisp     -- default compose-page and tier methods, container entries
test/
  package.lisp, helpers.lisp, and nine test-*.lisp files, one per subsystem
examples/
  blog-demo.lisp, forum-demo.lisp, wiki-demo.lisp -- demos writing static sites
  static/           -- their stylesheets
doc/
  demos/            -- the demos' rendered pages
```

Description: The repository's layout. Two system definitions sit at
the root. `src/` holds the composer's ten source files, loaded in the
order listed, from the package definition to the default tier
methods. `test/` holds the test package, its helpers, and a test file
for each subsystem. `examples/` holds the three demos and their
stylesheets, and `doc/demos/` the pages they render.

The test suite runs with the manifest's `:test` command,
`(progn (ql:quickload "classic.composer/tests") (classic.composer-tests::run-all-tests))`.

See also [CCOMPOSER-DRAFT-composer](Arch.Composer.md) for the design,
[CCOMPOSER-DRAFT-lexismarkdown](Log.LexisMarkdown.md) for the
Markdown integration, and
[CLASSIC-0011](../../classic/doc/theme/Ref.Theme.md) for the theme
ontology.
