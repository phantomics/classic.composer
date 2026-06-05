# Classic Composer Architecture

## Overview

The Classic Composer is an accessory system to Classic's core. It
assembles content for display by querying Classic's persistence layer,
combining content from multiple sources, applying templates, resolving
cross-references, and producing Lexis document trees ready for rendering.

The composer is read-only with respect to Classic's data -- it consumes
the persistence protocol (`retrieve-entity`, `query-relation`, blob
access) but does not write to it. The only write path it triggers is
downstream: rendered artifacts flowing to distribution (CDN, file cache,
search index).

**Classic foundation** owns: protocols, MOP, URI scheme, conditions.
**Classic schema** owns: ontological class definitions, theme resolution.
**Classic engine** owns: persistence backends, workflow runner, federation.
**The composer** owns: content assembly, template application, page
composition, lens evaluation.

The composer depends on the foundation (for protocol generics) and the
schema (for entity classes and theme resolution). It uses the
`classic.schema` package nickname so the same source works against any
schema that declares the nickname.


## The Five-Tier Content Model

The composer organizes content into five tiers based on the structural
role content plays on a page, not the application domain it belongs to.
This makes the tiers domain-agnostic -- a blog, wiki, forum, and social
network all use the same tiers with different composition decisions.

### 1. Frame

Page-level structure: the document skeleton, navigation, header, footer,
sidebar containers. The frame provides slots that other tiers fill. It
is the outermost layer of composition.

A frame does not know what content fills its slots. It provides the
structural context.

### 2. Feature

Primary content -- the thing the page exists to present. An article body,
a wiki article, a forum post, a product listing. Typically one per page
(the entity the URL resolves to).

In a forum context, all posts in a thread are feature content -- there is
no structural subordination between the opening post and replies.

### 3. Adjunct

Content that exists in relation to featured content: comments on a blog
post, review scores, related-article lists, author bio cards, tag clouds,
infoboxes. Multiple adjunct elements may appear on a single page,
typically positioned below or beside the feature.

### 4. Aggregate

Content that presents collections: blog index pages, forum thread
listings, search results, tag archive pages, feeds. These compose
multiple entities into a single view.

Distinct from feature because no single entity is primary -- the page
presents a query result or a container's contents.

### 5. Operative

Placement and specification of interactive controls: comment entry forms,
rating widgets, search dialogs, vote buttons, content editors. These are
not content -- they are interfaces for producing or modifying content.

The operative tier specifies *what control goes where* and *what it
targets*. The actual control implementation is delegated to a separate
system (such as Seed) which determines the control's behavior and
appearance.

The operative tier is the write-path surface. Tiers 1-4 are read-path
(content flows from Classic through the composer to the renderer). Tier 5
provides the interface through which user actions flow back into Classic's
persistence and workflow protocols.

## Tier Relationships

| Tier | Reads from Classic | Writes to Classic | Content Source |
|------|-------------------|-------------------|----------------|
| Frame | Publication metadata, navigation | No | Theme templates |
| Feature | Content entities (body blobs) | No | Lexis documents, lenses |
| Adjunct | Related entities, metadata | No | Lexis documents, queries |
| Aggregate | Container contents, query results | No | Query results |
| Operative | Workflow state (available actions) | Yes (via controls) | Interaction specs |


## Theme Integration

Themes are first-class Classic resources (`classic-theme`) stored
through the persistence protocol. The core ontology defines what
themes are; the composer consumes them for rendering.

### Theme Resolution

At context creation, the composer resolves the full theme chain:

1. Walk `parent-theme` links from child to root
2. Merge capabilities (union, with exclusion support)
3. Collect per-tier overrides
4. Merge configuration bindings (child overrides parent keys)
5. Merge slot-fills (child overrides parent slot names)
6. Merge lenses (child overrides parent on (class, purpose) pairs)
7. Collect asset manifests (parent first, child last for CSS stacking)

All resolved state is stored on the composition context for consumption
by tier methods.

### Tier Template Cascade

For each composition tier, the composer selects a template via:

1. Per-tier override (`classic-theme-override` for this tier) -- wins
2. Theme's `tier-templates` alist entry for the tier
3. Built-in default (minimal frame, body extraction, etc.)

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

### Capability Activation

The theme's resolved capability set (after exclusion processing)
determines which registered composer capabilities participate in
dispatch during this composition. The composer validates:

- All capabilities in the activation set are registered (warn or error)
- All `required-capabilities` are present in the set

Validation strictness is controlled by `*strict-capabilities*`.


## Lens-Driven Feature Composition

When a theme provides Fresnel-inspired lenses, the feature tier uses
them to determine which entity slots to render and how.

### Display Mode Cascade

For each property in a lens:

1. Explicit `:display` from the lens property spec
2. Slot's MOP `:format` annotation (`:markdown` -> `:markdown`, etc.)
3. Slot's `:persistence :relation` with no sublens -> `:link`
4. `:text` (universal fallback)

### Display Modes

| Mode | Produces | Use case |
|------|----------|----------|
| `:text` | Text node or `(paragraph ...)` | Plain string slots |
| `:image` | `(image (@ :src ... :alt ...))` | URI slots pointing to images |
| `:link` | `(web-link (@ :uri ...) label)` | URI slots as clickable links |
| `:uri` | Plain text of the URI | URI slots displayed as URIs |
| `:html` | Pass-through (already Lexis) | Body slots in Lexis form |
| `:markdown` | Stubbed: wraps in paragraph | Body slots in Markdown |
| `:date` | Formatted date string | Timestamp slots |
| `:list` | `(unordered-list ...)` | List-valued slots |

### Sublens References

Relation slots can declare a sublens: `(author :sublens classic-person
:purpose :label)`. The composer retrieves the related entity, finds
the target lens, and recursively applies it. Fallback chain:

1. Lens for (sublens-class, sublens-purpose)
2. Lens for (actual-class, :label)
3. Entity's `label` slot as plain text

Without lenses, the feature tier falls back to direct body extraction.


## Capability-Addition Model

The composer is organized as a base package with additive capability
extensions. Every extension adds a feature to the base rather than
replacing it. There are no mutually exclusive alternatives.

### Base Package

`classic.composer` provides:

- Generic protocols for each tier
- Default implementations consuming theme templates and lenses
- Template slot resolution (`template.slot` substitution)
- Anchor evaluation (`compose.anchor` dispatch to registered handlers)
- Collect phase (metadata gathering between resolution and evaluation)
- Theme resolution and lens evaluation

The base package alone produces working output. Extensions enhance it.

### Capability Extensions

Each extension is an ASDF system that registers itself with the base
composer, declaring what content patterns it can handle.

```
classic.composer                          -- base protocols + defaults
classic.composer.frame.hero               -- hero image/banner support
classic.composer.frame.sidebar            -- configurable sidebar
classic.composer.aggregate.tabular        -- sortable/filterable tables
classic.composer.aggregate.feed           -- timeline/feed-style listing
classic.composer.adjunct.threaded         -- threaded comment display
classic.composer.operative.forms          -- standard form controls
classic.composer.operative.search         -- search dialog placement
```

Content that doesn't match any loaded capability passes through the
base rendering unchanged.


## Templates and Anchors

### Simple Templates

Lexis documents with `template.slot` placeholder nodes. The composer
substitutes content into slots by name:

```lisp
(document (@ :title (template.slot (@ :name "page-title")))
  (navigation ...)
  (section (@ :title (template.slot (@ :name "page-title")))
    (template.slot (@ :name "main-content")))
  (footer ...))
```

### Complex Templates

CL functions that receive a content entity and persistence context and
return a Lexis tree. Used when composition requires triplestore queries,
conditional sections, or dynamic content assembly.

### Anchors

`compose.anchor` nodes specify query-driven, conditional content
insertion:

```lisp
(compose.anchor
  (@ :name "related-by-tags"
     :limit 5
     :fallback nil))
```

Anchor handlers return Lexis trees that are spliced into the composed
document. A `:fallback nil` anchor that produces no content is removed
entirely. Anchors keep query logic in CL where it belongs while keeping
the template declarative.

### Collect Phase

Before anchors evaluate, the collect phase walks the resolved tree
and gathers structural metadata (section headings, link targets,
entity counts). This is the Scribble-style "collect then render"
pattern that avoids cross-dependencies between anchors.


## Composition Workflow

```
Theme resolution (chain, capabilities, overrides, lenses, slot-fills)
  |
  v
Capability validation + config/slot-fill binding
  |
  v
Compose tiers (frame from theme template, feature from lens or body)
  |
  v
Bind tier outputs to slot names
  |
  v
Template slot resolution (single O(n) pass)
  |
  v
Collect phase (single O(n) pass, metadata gathering)
  |
  v
Anchor evaluation (single O(n) pass, document order)
  |
  v
Composed Lexis document tree
  |
  v
Renderer(s): Lexis -> HTML, PDF, terminal, Markdown, JSON-LD
  |
  v
Distribution: CDN, file cache, search index, notifications
```

The composer and renderers are stateless services that scale
independently from Classic's logic layer and persistence backend.


## Operative Tier and Seed

The operative tier specifies control placement; Seed (or another
control system) implements the controls. The boundary:

- **Composer decides:** "a comment form goes here, targeting this
  container, requiring the :write permission"
- **Seed decides:** "this comment form has a text area, a submit button,
  uses htmx for submission, and validates input client-side"

This separation means the composer can place controls without knowing
how they're implemented, and Seed can implement controls without knowing
where they're placed.


## Layered Architecture

The composer follows Classic's four-layer architecture:

```
classic.composer.dist.alpha        -- distribution shim for end users
  |
  +-- classic.dist.alpha           -- foundation + schema + engine
  +-- classic.models.common        -- blog, forum, wiki content types
  +-- classic.composer             -- this system
        |
        +-- classic                -- foundation (protocols, MOP)
        +-- classic.schema.alpha   -- schema (classes, theme resolution)
        +-- closer-mop             -- MOP access for lens cascade
```

Schema references throughout the composer use the `classic.schema`
package nickname. A future `classic.composer.dist.beta` would load
the same composer source against a beta schema.
