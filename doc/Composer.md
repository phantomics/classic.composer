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

**Classic core** owns: ontology, persistence, workflow.
**The composer** owns: content assembly, template application, page
composition.

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
| Frame | Publication metadata, navigation | No | Templates |
| Feature | Content entities (body blobs) | No | Lexis documents |
| Adjunct | Related entities, metadata | No | Lexis documents, queries |
| Aggregate | Container contents, query results | No | Query results |
| Operative | Workflow state (available actions) | Yes (via controls) | Interaction specs |

## Capability-Addition Model

The composer is organized as a base package with additive capability
extensions. Every extension adds a feature to the base rather than
replacing it. There are no mutually exclusive alternatives -- extensions
compose without conflict because they augment different aspects of the
composition process.

### Base Package

`classic.composer` provides:

- Generic protocols for each tier (how frame, feature, adjunct,
  aggregate, and operative components are composed)
- Default implementations that are functional but minimal
- Infrastructure for registering and dispatching to capability extensions
- Template slot resolution (`template:slot` substitution)
- Anchor evaluation (`compose:anchor` dispatch to registered handlers)

The base package alone produces working output. Extensions enhance it.

### Capability Extensions

Each extension is an ASDF system that registers itself with the base
composer, declaring what content patterns it can handle. The composer
dispatches to registered capabilities when it encounters matching
content.

Examples:

```
classic.composer                          -- base protocols + defaults
classic.composer.frame.hero               -- hero image/banner support
classic.composer.frame.slider             -- content slider/carousel
classic.composer.frame.sidebar            -- configurable sidebar
classic.composer.aggregate.tabular        -- sortable/filterable tables
classic.composer.aggregate.feed           -- timeline/feed-style listing
classic.composer.adjunct.threaded         -- threaded comment display
classic.composer.operative.forms          -- standard form controls
classic.composer.operative.search         -- search dialog placement
```

A publication loads whichever capabilities it needs:

```lisp
(ql:quickload '("classic.composer"
                "classic.composer.frame.hero"
                "classic.composer.frame.sidebar"
                "classic.composer.aggregate.tabular"))
```

Content that doesn't match any loaded capability passes through the
base rendering unchanged.

## Templates and Anchors

### Simple Templates

Lexis documents with `template:slot` placeholder nodes. The composer
substitutes content into slots by name:

```lisp
(document (@ :title (template:slot :name "page-title"))
  (navigation (@ :classic:uri "classic:site,2026:nav/main"))
  (section (@ :title (template:slot :name "page-title"))
    (template:slot :name "main-content"))
  (footer (@ :classic:uri "classic:site,2026:nav/footer")))
```

### Complex Templates

CL functions that receive a content entity and persistence context and
return a Lexis tree. Used when composition requires triplestore queries,
conditional sections, or dynamic content assembly.

### Anchors

`compose:anchor` nodes specify query-driven, conditional content
insertion. The anchor carries a name and parameters; a registered CL
handler function determines what content (if any) to produce:

```lisp
(compose:anchor
  (@ :name "related-by-tags"
     :limit 5
     :fallback nil))
```

The handler is a CL function registered by the application model:

```lisp
(define-anchor-handler "related-by-tags" (entity strategy params)
  (let ((tags (keywords entity)))
    (when tags
      (let ((related (query-posts-by-tags strategy tags
                       :limit (getf params :limit 5))))
        (render-related-list related)))))
```

Anchor handlers return Lexis trees that are spliced into the composed
document. A `:fallback nil` anchor that produces no content is removed
entirely. Anchors keep query logic in CL where it belongs while keeping
the template declarative.

## Theming

Themes operate above the composer. A theme selects which capability
extensions to use and provides visual styling.

### Theme Structure

Theme metadata is a Classic resource stored in the triplestore. The
actual theme material (templates, CSS, typography configs) lives in a
CL ASDF system on the filesystem.

```
classic-theme-example/
  classic-theme-example.asd
  theme.lisp                    -- registers theme metadata with Classic
  frame/
    page.lexis                  -- page skeleton template
    navigation.lexis
  feature/
    article.lisp                -- article arrangement config
  web/
    style.css
  pdf/
    typography.sexp
  terminal/
    palette.sexp
```

The `theme.lisp` file registers the theme:

```lisp
(classic:register-theme
  :name "example"
  :label "Example Theme"
  :version "1.0"
  :media-support '(:web :pdf :terminal)
  :frame-template #p"frame/page.lexis"
  :web-stylesheet #p"web/style.css"
  :pdf-config #p"pdf/typography.sexp"
  :terminal-config #p"terminal/palette.sexp")
```

### Relationship Between Tiers, Capabilities, and Themes

```
Theme (visual appearance + extension selection)
  |
  +-- selects composer capabilities
  |     classic.composer.frame.hero
  |     classic.composer.aggregate.tabular
  |
  +-- provides visual styling per medium
        web/style.css
        pdf/typography.sexp
        terminal/palette.sexp

Composer capabilities (structural behavior)
  |
  +-- frame.hero: supports hero image areas in frames
  +-- aggregate.tabular: supports sortable table rendering
  +-- (base defaults handle everything else)

Classic core (ontology + persistence + workflow)
  |
  +-- provides content entities and relationships
  +-- composer queries this via persistence protocol
```

Capabilities determine *what structural features are available*.
Themes determine *which capabilities are active and how they look*.
Classic core determines *what content exists and how it relates*.

### Fallback Chain

A publication specifies a primary theme with fallbacks for media types
the primary theme doesn't cover:

```lisp
(configure-theme publication
  :primary "magazine-theme"
  :fallbacks '(("pdf" . "classic-default-pdf")
               ("terminal" . "classic-default-terminal")))
```

### Feature Arrangement

Beyond CSS, themes can influence how content is structurally arranged
within the feature tier. This is abstract rearrangement -- metadata
placement, section ordering, which adjunct content appears inline vs.
sidebar -- operating on the Lexis tree before rendering rather than
on CSS after rendering.

This is the level at which WordPress themes use PHP template files
to restructure content. In Classic's model, it is explicitly separated
from visual styling and operates on the Lexis document structure.

## Composition Workflow

```
Content entity in Classic persistence
  |
  v
Composer: query persistence, select template
  |
  v
Template slot resolution (substitute content into frame)
  |
  v
Anchor evaluation (query-driven conditional content)
  |
  v
Cross-reference resolution (Lexis Section 7.3)
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
independently from Classic's logic layer and triplestore.

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
