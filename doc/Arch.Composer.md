---
id:            CCOMPOSER-0001
title:         The Classic Composer Architecture
genre:         Architecture
scope:         project
project:       Classic Composer
language:      en
status:        Accepted
authors:
  - Andrew Sengul
approved-by:   Andrew Sengul
reviewed:      2026-11-21
provenance:
  assistant:          claude-opus-5-5
  original-assistant: claude-opus-4-6
  migrated-from:      doc/Composer.md@7fa52ba
relates-to:
  - CCOMPOSER-0002
  - CCOMPOSER-DRAFT-lexismarkdown
  - CCOMPOSER-DRAFT-compass-migration
  - CLASSIC-0010
  - CLASSIC-0011
  - LEXIS-0002
cites:
  - title:     "Fresnel — Display Vocabulary for RDF"
    locator:   "https://www.w3.org/2005/04/fresnel-info/"
    external:  true
  - title:     "Scribble: The Racket Documentation Tool"
    locator:   "https://docs.racket-lang.org/scribble/"
    external:  true
  - title:     "Shortcode — Common APIs Handbook, WordPress Developer Resources"
    locator:   "https://developer.wordpress.org/apis/shortcode/"
    external:  true
decisions:
  - CCOMPOSER-D1
  - CCOMPOSER-D2
  - CCOMPOSER-D3
  - CCOMPOSER-D4
  - CCOMPOSER-D5
  - CCOMPOSER-D6
open-questions:
  - CCOMPOSER-O1
  - CCOMPOSER-O2
  - CCOMPOSER-O3
  - CCOMPOSER-O4
  - CCOMPOSER-O5
  - CCOMPOSER-O6
---

# The Classic Composer Architecture

This record is the design of the Classic Composer, the system that
assembles Classic content into Lexis documents for display. It sets
out the composer's boundaries, the five-tier content model it
composes pages with, the decisions that shape it, and the parts of
the design not yet built: the capability extensions, complex
templates, the operative tier and its hand-off to Seed, and
distribution. The parts that run are described in
[CCOMPOSER-0002](Ref.Composer.md), which this record
links to rather than repeats.

## Canonical Terms

Table: Terms used in this design, with their definitions.

| Term | Definition |
|---|---|
| Tier | One of five structural roles content plays on a page: frame, feature, adjunct, aggregate, operative (see [The Five-Tier Content Model](#the-five-tier-content-model)) |
| Composition context | The state of one composition: persistence strategy, publication, primary entity, resolved theme, slot bindings and collections |
| Theme | A `classic-theme` resource: tier templates, slot-fills, lenses, capabilities and assets, inherited along a chain of parent themes |
| Lens | A Fresnel-inspired spec, held by a theme, naming which properties of an entity class to render, in what order and how, for a purpose such as `:default` or `:summary` |
| Display mode | How a lens renders one property value, such as `:text`, `:link` or `:markdown` |
| Template slot | A `template.slot` placeholder in a Lexis template, filled by name from the context's bindings |
| Slot-fill | A Lexis subtree a theme supplies for a named template slot of a parent theme's template |
| Anchor | A `compose.anchor` node whose registered handler produces query-driven content |
| Collector | A function run over the resolved tree before anchors evaluate, gathering metadata for them |
| Capability | A named, additive extension registered for a tier |
| Extension generic | A generic function an application specializes to adapt composition to its content, such as `entity-href` |

## Thesis

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

This division follows CLASSIC-D29, in Classic's theme ontology Log
[CLASSIC-0010](../../classic/doc/theme/Log.ThemeOntology.md): Classic's
core defines what a theme is, and the composer consumes themes for
rendering.

The composer depends on the foundation (for protocol generics) and the
schema (for entity classes and theme resolution). It uses the
`classic.schema` package nickname so the same source works against any
schema that declares the nickname.

## Influences

- **Fresnel**, the W3C display vocabulary for RDF, gives the lens: a
  per-class selection of properties, in order, with formatting hints
  and sublenses for related resources, chosen by purpose. Its format
  vocabulary is replaced by a small fixed set of display modes, and
  lenses are plists held by themes rather than RDF resources.
- **Scribble**, the Racket documentation system, gives "collect then
  render": a pass that gathers metadata from the whole document
  before any dependent content is produced, so anchors need not
  depend on one another.
- **Seed**, or another control system, takes the implementation of
  interactive controls, leaving the composer only their placement
  (CCOMPOSER-D4).
- **WordPress shortcodes** are the counterexample. The shortcode
  parser makes a single pass, but a handler may call `do_shortcode()`
  on its own content to expand the shortcodes nested in it, so how far
  expansion recurses, and what it costs, is left to each handler's
  code. The composer's fixed sequence of single passes keeps that
  recursion out of templates (CCOMPOSER-D6).

## Settled Decisions

### CCOMPOSER-D1 — The composer is read-only with respect to Classic's data

**Status:** Proposed
**Context:** Composition reads publications, entities, relations and
themes. Rendering is tempting to optimize by writing back: caching
resolved values, denormalizing display fields, or reordering
containers for display.
**Decision:** The composer consumes the persistence protocol and never
writes to it. Values a page needs that are not stored are computed
while composing, through the extension generics. The only writes the
composer causes are downstream, as rendered artifacts reach
distribution; interactive controls, which write, are placed by the
composer and implemented elsewhere (CCOMPOSER-D4).
**Alternatives:** Writing derived values back was not adopted: the
composer would need write access to the store, the read path of
composition would become a write path, and a display choice would
change the data for every other reader. The forum and wiki demos once wrote such values; they
were rewritten to compute them, as
[DevLog.ReadOnlyDemos.md](Log.ReadOnlyDemos.md) records.

### CCOMPOSER-D2 — Tiers are defined by structural role, not application domain

**Status:** Proposed
**Context:** The composer serves blogs, wikis, forums and other
publication types, each with its own page kinds.
**Decision:** The composer organizes content into five tiers based on
the structural role content plays on a page, not the application
domain it belongs to. A blog, wiki, forum and social network all use
the same tiers with different composition decisions.
**Alternatives:** Page types per domain (a blog post page, a forum
thread page) were not adopted: each new publication type would need
its own composition code, and nothing would be shared between them.
The blog, forum and wiki demos compose all their pages with the same
tier methods.

### CCOMPOSER-D3 — Extensions only add; none excludes another

**Status:** Proposed
**Context:** Publications need features the base composer does not
have: hero banners, sidebars, feeds, comment threads, forms.
**Decision:** The composer is organized as a base package with additive
capability extensions. Every extension adds a feature to the base
rather than replacing it. Each augments a specific content pattern,
so capabilities compose without conflict, and content that matches no
loaded capability passes through the base rendering unchanged. Freedom
from conflict depends on capabilities claiming distinct content
patterns: what happens when two accept the same node is not decided
(CCOMPOSER-O1). The registry's dispatch takes the first
capability that accepts a node and returns content, most recently
registered first, so load order decides between them.
**Alternatives:** Mutually exclusive alternatives, such as one of
several frame engines or aggregate renderers chosen per publication,
were not adopted: they make features conflict, and a publication
could not combine two that replace the same part.

### CCOMPOSER-D4 — The composer places controls; Seed implements them

**Status:** Proposed
**Context:** Pages hold interactive controls: comment forms, rating
widgets, search dialogs, editors. They are the write path back into
Classic, and their behavior depends on the client.
**Decision:** The operative tier specifies control placement; Seed (or
another control system) implements the controls. The composer decides
what control goes where, what it targets and what permission it
requires; Seed decides how the control looks and behaves.
**Alternatives:** Rendering controls in the composer was not adopted:
it would tie composition to one client technology and bring the write
path into a read-only system. The separation means the composer can
place controls without knowing how they're implemented, and Seed can
implement controls without knowing where they're placed.

### CCOMPOSER-D5 — Schema references go through the classic.schema nickname

**Status:** Proposed
**Context:** Classic's schema is versioned: the composer is built
against `classic.schema.alpha`, and later schemas are expected.
**Decision:** Schema references throughout the composer use the
`classic.schema` package nickname, never a schema package's own name.
Only the ASDF dependency names the alpha schema. A future
`classic.composer.dist.beta` would load the same composer source
against a beta schema.
**Alternatives:** Naming `classic.schema.alpha` in the source was not
adopted: each schema would need its own copy of the composer.

### CCOMPOSER-D6 — Composition is a fixed sequence of single passes

**Status:** Proposed
**Context:** Templates nest: a frame holds slots, slots hold composed
content, and anchors produce content from queries. Where expanding a
placeholder may expand the placeholders in its output again, the cost
of a page depends on how deep the expansion goes, which no stage of
the framework bounds.
**Decision:** A page is composed in a fixed sequence of stages, each one
pass over the tree: tiers composed, slots resolved, metadata collected,
anchors evaluated. Inner content is composed before it is bound into
outer templates, a resolved slot's value is not searched for further
slots, and anchors depend on the collected metadata rather than on one
another. The framework's own passes are therefore linear in the size
of the page. What runs inside them is not bounded by the framework:
anchor handlers and extension-generic methods cost what their code
costs, an aggregate lens's sort is O(n log n) in the entries, and
sublenses recurse with no depth limit
(CCOMPOSER-O6).
**Alternatives:** Expansion that handlers may repeat on their own
output, as a WordPress shortcode handler may by calling
`do_shortcode()` on its content, was not adopted: it leaves the depth
of expansion, and its cost, to each handler's code. Ordering anchors
by their dependencies was not adopted: it would need dependency
resolution and cycle detection, where the collect phase gives every
anchor what it needs.


## The Five-Tier Content Model

The composer organizes content into five tiers based on the structural
role content plays on a page, not the application domain it belongs to
(CCOMPOSER-D2). This makes the tiers domain-agnostic --
a blog, wiki, forum, and social network all use the same tiers with
different composition decisions.

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
no structural subordination between the opening post and replies. A
thread page presents them through the aggregate tier, as an aggregate of
those features: the thread is a container, and its posts are its
entries, each rendered as feature content would be.

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
appearance (CCOMPOSER-D4).

The operative tier is the write-path surface. Tiers 1-4 are read-path
(content flows from Classic through the composer to the renderer). Tier 5
provides the interface through which user actions flow back into Classic's
persistence and workflow protocols. Tiers 1-4 are built; the operative
tier is not (CCOMPOSER-O3).

## Tier Relationships

Table: What each tier reads from and writes to Classic, and where its content comes from.

| Tier | Reads from Classic | Writes to Classic | Content Source |
|------|-------------------|-------------------|----------------|
| Frame | Publication metadata, navigation | No | Theme templates |
| Feature | Content entities (body blobs) | No | Lexis documents, lenses |
| Adjunct | Related entities, metadata | No | Lexis documents, queries |
| Aggregate | Container contents, query results | No | Query results |
| Operative | Workflow state (available actions) | Yes (via controls) | Interaction specs |

Each tier is a generic function with a default method; the defaults
are described in
[CCOMPOSER-0002](Ref.Composer.md#tier-generics).


## Theme Integration

Themes are first-class Classic resources (`classic-theme`) stored
through the persistence protocol. The core ontology defines what
themes are; the composer consumes them for rendering. At context
creation the composer resolves a theme's chain of parents and merges
what the chain declares: capabilities, overrides, configuration,
slot-fills, lenses and assets. A child theme extends its parent
through slot-fills and lenses without replacing its templates. The
resolution, the tier template cascade, slot-fills, configuration,
assets and capability validation are described in
[CCOMPOSER-0002](Ref.Composer.md#theme-integration), and
the ontology in [CLASSIC-0011](../../classic/doc/theme/Ref.Theme.md).


## Lens-Driven Feature Composition

When a theme provides Fresnel-inspired lenses, the composer uses them
to determine which entity properties to render and how: the feature
through a `:default` lens, container entries through `:summary` or
`:label` lenses, and related entities through sublenses. A display
mode cascade chooses how each value renders, from the lens's explicit
choice, then the slot's declared format, then its persistence. Lenses
are data in themes; what is not stored is computed through the
extension generics below. The modes, Markdown bodies, sublenses,
property options and aggregate lenses are described in
[CCOMPOSER-0002](Ref.Composer.md#lens-evaluation).

Without lenses, the feature tier falls back to direct body extraction.


## Extension Generics

Applications adapt composition to their content by specializing
generic functions on their content classes, not by changing their data
before composing (CCOMPOSER-D1). Each generic has a
default that keeps the composer's base behavior. They supply computed
properties for lenses, resolve references that are not URIs, give the
URLs of entities' pages, order containers' entries, and set the
Markdown reader's options. Each is described in
[CCOMPOSER-0002](Ref.Composer.md#extension-generics).

An order that is a rule of the content type, such as a forum listing
pinned threads first, is a method on the container class. An order
that is a presentation choice, such as an alphabetical index, is an
aggregate lens in the theme, and so belongs to one publication.


## Capability-Addition Model

The composer is organized as a base package with additive capability
extensions. Every extension adds a feature to the base rather than
replacing it. There are no mutually exclusive alternatives
(CCOMPOSER-D3).

### Base Package

`classic.composer` provides:

- Generic protocols for each tier
- Default implementations consuming theme templates and lenses
- Template slot resolution (`template.slot` substitution)
- Anchor evaluation (`compose.anchor` dispatch to registered handlers)
- Collect phase (metadata gathering between resolution and evaluation)
- Theme resolution and lens evaluation

The base package alone produces working output. Extensions enhance it.
The base package also holds the capability registry, and validates a
theme's capabilities against it; the default tier methods do not yet
dispatch to capabilities (CCOMPOSER-O1).

### Capability Extensions

Each extension is an ASDF system that registers itself with the base
composer, declaring what content patterns it can handle. The theme's
resolved capability set, after exclusions, is to determine which
registered capabilities take part in a composition; how it does is
open (CCOMPOSER-O1). These systems are planned; none
exists yet.

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

Description: A list of ASDF systems. First the base system,
`classic.composer`, with the base protocols and defaults. Then seven
capability extensions, each named for its tier: `frame.hero` for hero
image and banner support, `frame.sidebar` for a configurable sidebar,
`aggregate.tabular` for sortable and filterable tables,
`aggregate.feed` for a timeline or feed-style listing,
`adjunct.threaded` for threaded comment display, `operative.forms`
for standard form controls, and `operative.search` for search dialog
placement, each prefixed `classic.composer.`.

Content that doesn't match any loaded capability passes through the
base rendering unchanged.


## Templates and Anchors

Simple templates are Lexis documents with `template.slot` placeholder
nodes, filled by name. Anchors are `compose.anchor` nodes whose
registered handlers produce query-driven, conditional content, and
the collect phase gathers the metadata they need before any of them
runs (CCOMPOSER-D6). Anchors keep query logic in CL
where it belongs while keeping the template declarative. All three
are described in
[CCOMPOSER-0002](Ref.Composer.md#templates-anchors-and-collectors).

### Complex Templates

CL functions that receive a content entity and persistence context and
return a Lexis tree. Used when composition requires triplestore queries,
conditional sections, or dynamic content assembly. Complex templates are
not built (CCOMPOSER-O2); anchors and the extension
generics cover some of their uses.


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

Description: A vertical flow of ten stages, each feeding the next:
theme resolution (chain, capabilities, overrides, lenses,
slot-fills); capability validation with config and slot-fill
binding; composing the tiers (the frame from the theme template, the
feature from a lens or the body); binding tier outputs to slot names;
template slot resolution, a single O(n) pass; the collect phase, a
single O(n) pass gathering metadata; anchor evaluation, a single O(n)
pass in document order; the composed Lexis document tree; the
renderers, from Lexis to HTML, PDF, terminal, Markdown and JSON-LD;
and distribution to a CDN, a file cache, a search index and
notifications.

The composer performs the stages through the composed Lexis tree, as
[CCOMPOSER-0002](Ref.Composer.md#composition-pipeline)
describes. Renderers are separate systems, of which Lexis's HTML
renderer exists; distribution is not built
(CCOMPOSER-O4).

The composer and renderers are stateless services that scale
independently from Classic's logic layer and persistence backend.


## Operative Tier and Seed

The operative tier specifies control placement; Seed (or another
control system) implements the controls
(CCOMPOSER-D4). The boundary:

- **Composer decides:** "a comment form goes here, targeting this
  container, requiring the :write permission"
- **Seed decides:** "this comment form has a text area, a submit button,
  uses htmx for submission, and validates input client-side"

This separation means the composer can place controls without knowing
how they're implemented, and Seed can implement controls without knowing
where they're placed. The composer turns an operative spec into a
`compose.operative` placeholder node carrying the spec as attributes;
no tier produces specs yet, and the hand-off to Seed is undefined
(CCOMPOSER-O3).


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
        +-- lexis.markdown         -- Markdown reader for :markdown mode
```

Description: A dependency tree. `classic.composer.dist.alpha`, the
distribution shim for end users, depends on `classic.dist.alpha`
(foundation, schema and engine), `classic.models.common` (the blog,
forum and wiki content types) and `classic.composer` (this system).
`classic.composer` depends on `classic` (the foundation: protocols
and MOP), `classic.schema.alpha` (the schema: classes and theme
resolution), `closer-mop` (MOP access for the lens cascade) and
`lexis.markdown` (the Markdown reader for the `:markdown` mode).

Schema references throughout the composer use the `classic.schema`
package nickname (CCOMPOSER-D5). A future
`classic.composer.dist.beta` would load the same composer source
against a beta schema. The repository's files are listed in
[CCOMPOSER-0002](Ref.Composer.md#project-structure).


## Open Questions

### CCOMPOSER-O1 — How do capabilities take part in composition?

The registry, `define-capability` and `dispatch-capability` exist, and
`compose-page` validates a theme's capabilities against the registry,
but no tier method dispatches to a capability. Which tiers dispatch,
at which nodes (each node of a theme template, or only nodes whose tag
no other method handles), and how does the theme's activation set
limit which registered capabilities may answer? And when two
capabilities accept the same node, which applies: the first by load
order, as the registry's dispatch now decides, one the theme ranks
higher, or both in turn?

### CCOMPOSER-O2 — How is a complex template declared?

Themes are persisted resources, and their tier templates are Lexis
data, but a complex template is a CL function. How does a theme name
one: by a registered name, resolved like an anchor handler, or by a
generic function specialized on the entity's class, as the extension
generics are? And what may it do that an anchor or an extension
generic cannot?

### CCOMPOSER-O3 — What is the operative spec, and how does Seed receive it?

`compose-operative` returns no specs, and the `compose.operative`
placeholder's attributes are whatever a spec holds. What does a spec
name (the control, its target, its placement, the permission and
workflow transition it needs), where does the composer learn which
actions the reader may take, and how does Seed find and expand the
placeholders in a rendered page?

### CCOMPOSER-O4 — How do rendered artifacts reach distribution?

The composer's only write path is downstream, to a CDN, a file cache,
a search index and notifications, but nothing carries composed pages
there, and nothing decides when a page must be composed again after
its content changes. Is distribution a service of its own, fed by
Classic's workflow and federation events, and what does it need from
the composer to know which pages an entity appears on?

### CCOMPOSER-O5 — Should the composer's wrapper sections raise heading levels?

`compose-feature` wraps lens output in `(section (@ :class "feature")
...)`, and container entries are wrapped the same way. Lexis counts
every section when it computes heading depth, so a feature's Markdown
`##` heading renders as `<h3>`. The composer's side of LEXIS-O3, in
[LEXIS-0002](../../lexis/doc/Plan.RenderMarkdown.md), was settled by
splicing bodies instead of wrapping them
(CCOMPOSER-DRAFT-lexismarkdown-D3); the remaining level awaits a
change in Lexis, such as not counting untitled sections, or a
container tag that is not a section.

### CCOMPOSER-O6 — How are sublens cycles bounded?

A sublens applies the target entity's lens, which may itself declare
sublenses. `src/lens.lisp:apply-sublens@v0.2.0` sets no depth limit
and keeps no record of the entities it has visited, so two lenses
that refer to each other, such as an article's author shown through
a person lens that lists the person's articles, recurse without end.
Should the composer limit sublens depth, stop at an entity already
being rendered, or leave lenses to the theme author to keep acyclic?

## Roadmap

1. **Sublens cycles** (CCOMPOSER-O6): bound sublens
   recursion before themes with richer lenses are written.
2. **Capability dispatch** (CCOMPOSER-O1): wire
   dispatch into the tier methods and limit it to the theme's
   activation set, then build the first extension systems, such as
   `classic.composer.frame.hero` and `classic.composer.aggregate.feed`.
3. **The operative tier** (CCOMPOSER-O3): define the
   operative spec and its placeholder with Seed, and build
   `classic.composer.operative.forms`.
4. **Complex templates** (CCOMPOSER-O2), once the uses
   anchors and extension generics leave uncovered are known.
5. **Distribution** (CCOMPOSER-O4), with the services
   that consume composed pages.
6. **`classic.composer.dist.beta`** (CCOMPOSER-D5), when
   Classic publishes a beta schema.
