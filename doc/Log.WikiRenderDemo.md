---
id:            CCOMPOSER-DRAFT-wikirenderdemo
title:         Wiki Render Demo Development Log
genre:         Log
scope:         component
project:       Classic Composer
component:     demo
language:      en
status:        Implemented
authors:
  - Andrew Sengul
approved-by:   Andrew Sengul
reviewed:      2026-11-21
provenance:
  assistant:          claude-opus-5-5
  original-assistant: claude-opus-4-6
  migrated-from:      doc/DevLog.WikiRenderDemo.md@b9ad8c1
decisions:
  - CCOMPOSER-DRAFT-wikirenderdemo-D1
  - CCOMPOSER-DRAFT-wikirenderdemo-D2
  - CCOMPOSER-DRAFT-wikirenderdemo-D3
  - CCOMPOSER-DRAFT-wikirenderdemo-D4
  - CCOMPOSER-DRAFT-wikirenderdemo-D5
  - CCOMPOSER-DRAFT-wikirenderdemo-D6
  - CCOMPOSER-DRAFT-wikirenderdemo-D7
  - CCOMPOSER-DRAFT-wikirenderdemo-D8
---

# Wiki Render Demo: Development Log

This document chronicles the addition of a wiki rendering demo to
the Classic Composer. The demo is the first to exercise child theme
inheritance with lenses, multi-purpose lens rendering on a single
page, sublens chains through typed page classes, and the adjunct
tier for page metadata. It renders the same typed-page wiki content
that Classic core's REPL demo displays, but as HTML through the
full composition pipeline.

**Date:** 2026-06-22


## Problem

The blog and forum demos proved the composer's pipeline against two
content profiles: authored articles and threaded discussions. Neither
exercised the lens system's full capabilities:

- **No child theme inheritance.** Both demos used single-theme
  configurations. The wiki's built-in theme (created by `make-wiki`)
  already carries `:infobox` and `:label` lenses for typed page
  classes. A second theme adding HTML-specific lenses and a frame
  template on top is the natural child theme use case.

- **No multi-purpose lens rendering.** The blog and forum demos used
  one lens purpose per page. A wiki article page needs three: the
  infobox sidebar (`:infobox`), the main body (`:default`), and
  index entries (`:summary`). These coexist on the same entity class.

- **No sublens chains.** The blog demo sublensed person names for
  author bylines. The wiki's typed page classes create a deeper
  chain: a computer's CPU field references a `wiki-cpu` entity,
  whose `:label` lens produces "Motorola 68000 (7.16 MHz)".

- **No adjunct content.** Backlinks, broken links, and influence
  lineage are genuine adjunct content — metadata that annotates the
  featured article without being part of it. Neither prior demo
  exercised the adjunct tier.

- **No alist infobox fallback.** The wiki has both typed page classes
  (with MOP-annotated slots) and generic pages (with alist infoboxes).
  Rendering both from the same pipeline demonstrates graceful
  degradation.


## Design Decisions

### CCOMPOSER-DRAFT-wikirenderdemo-D1 — Child theme inheriting parent lenses

**Status:** Implemented
**Context:** See [Problem](#problem).

**Decision:** The wiki's built-in theme (from `make-wiki`) provides six lens specs:
`:infobox` and `:label` for `wiki-computer`, `wiki-cpu`, and
`wiki-person`. The demo's child theme adds four more: `:default` and
`:summary` for `wiki-page` (the common superclass). The composer
resolves both via `resolve-theme-lenses`, which merges the chain
child-first.

The child doesn't need to redeclare the parent's lenses. Lens
resolution walks the chain and preserves parent lenses for
`(class, purpose)` pairs the child doesn't override. This is the
first time the demo suite exercises this inheritance.

**Alternatives:** Not recorded in the original.

### CCOMPOSER-DRAFT-wikirenderdemo-D2 — Infobox as separate slot-fill, not part of the :default lens

**Status:** Implemented
**Context:** See [Problem](#problem).

**Decision:** The infobox (sidebar with typed fields) is rendered from the
`:infobox` lens and bound to the `"page.infobox"` template slot.
The main article body is rendered from the `:default` lens and bound
to `"main-content"`. This respects the tier model: the infobox is
structurally positioned by the frame template, not embedded in the
body.

**Alternatives:** The alternative (a single `:default` lens containing both infobox
and body properties) would conflate two distinct page regions that
need independent positioning in the frame.

### CCOMPOSER-DRAFT-wikirenderdemo-D3 — Pre-processing body wiki-links to Lexis nodes

**Status:** Superseded
**Context:** Wiki bodies contain `[[Page Name]]` references that need to become
HTML links.

**Decision:** The demo pre-processes bodies during setup, converting
`[[refs]]` to `(web-link ...)` nodes for resolved links and
`(emphasis (@ :class "broken-link") "Name")` for broken links. The
processed body is stored as a Lexis subtree and rendered via
`:display :html` in the `:default` lens.

**Alternatives:** A production wiki would handle this at render time via a capability
that intercepts the body property and performs link resolution. The
demo pre-processes for consistency with the other demos.

### CCOMPOSER-DRAFT-wikirenderdemo-D4 — Typed-slot anchors resolved to URIs before composition

**Status:** Superseded
**Context:** Wiki typed slots (`computer-designer`, `computer-cpu`) store anchor
strings. The composer's `apply-sublens` retrieves entities by URI.

**Decision:** The demo resolves anchors to URIs during pre-processing so the
sublens chain works with the generic composer machinery.

**Alternatives:** Not recorded in the original.

### CCOMPOSER-DRAFT-wikirenderdemo-D5 — Definition-list via HTML passthrough

**Status:** Implemented
**Context:** The Lexis spec defines `definition-list` and `definition` tags
(Section 4.3) but they are not yet implemented in the Lexis HTML
renderer.

**Decision:** The demo uses `(passthrough (@ :medium :html) (:dl ...))` 
to emit proper `<dl>/<dt>/<dd>` HTML directly. When Lexis adds
native `definition-list` support, the passthrough can be replaced
with semantic Lexis nodes.

**Alternatives:** Not recorded in the original.

### CCOMPOSER-DRAFT-wikirenderdemo-D6 — Metadata as adjunct content

**Status:** Implemented
**Context:** See [Problem](#problem).

**Decision:** Backlinks ("what links here"), broken links, and influence lineage
are assembled during pre-processing and bound to `"adjunct-content"`.
The frame template positions this below the main content. This is
the intended use of the adjunct tier: content subordinate to or
annotating the feature.

**Alternatives:** Not recorded in the original.

### CCOMPOSER-DRAFT-wikirenderdemo-D7 — Alphabetical index via pre-sorted container

**Status:** Superseded
**Context:** The wiki index page sorts alphabetically by page anchor.

**Decision:** The demo
pre-sorts the container's `contains` list before composition,
matching the approach used in the forum demo for pin ordering.

**Alternatives:** Not recorded in the original.

### CCOMPOSER-DRAFT-wikirenderdemo-D8 — Amiga-era content

**Status:** Implemented
**Context:** Not recorded in the original.

**Decision:** Pages: Jay Miner (wiki-person), Motorola 68000 (wiki-cpu), Amiga
1000 (wiki-computer), AmigaOS (generic wiki-page with alist
infobox). The Amiga 1000 references both Jay Miner (via
`computer-designer` typed slot) and Motorola 68000 (via
`computer-cpu` sublens), plus AmigaOS via `[[wiki-link]]` in the
body. This exercises all three cross-reference mechanisms: typed
slot `:link`, sublens chain, and body wiki-link.

**Alternatives:** Not recorded in the original.


## Implementation

### `examples/wiki-demo.lisp@b9ad8c1` (~500 lines)

**`examples/wiki-demo.lisp:setup-wiki@b9ad8c1`** creates the wiki with 4 pages in dependency order
(person first, then CPU, then computer, then generic OS page).
Pages are published via the editorial workflow.

**`examples/wiki-demo.lisp:setup-child-theme@b9ad8c1`** creates a child theme:
- Parent: the wiki's built-in theme URI
- Frame template with 8 slots (title, assets, brand, infobox,
  main-content, aggregate-content, adjunct-content, footer)
- Slot fills for brand header and footer
- Asset manifest pointing to wiki.css
- `:default` lens for `wiki-page` (headline + body as `:html`)
- `:summary` lens for `wiki-page` (headline + created-at as `:date`)

**`examples/wiki-demo.lisp:pre-process-all-pages@b9ad8c1`** runs two passes over all pages:
1. `examples/wiki-demo.lisp:resolve-typed-slots-to-uris@b9ad8c1` — converts anchor strings to URIs
   for sublens resolution
2. `examples/wiki-demo.lisp:convert-wiki-body-to-lexis@b9ad8c1` — parses `[[refs]]` and produces
   Lexis subtrees with `(web-link ...)` and broken-link markers

**`examples/wiki-demo.lisp:render-infobox-to-lexis@b9ad8c1`** walks the `:infobox` lens for the
page's class, renders each property (with display modes and sublens
resolution), and assembles a `<dl>` via HTML passthrough. For
generic pages, renders the alist infobox as `<dl>` entries.

**`examples/wiki-demo.lisp:assemble-page-metadata@b9ad8c1`** builds adjunct content sections:
backlinks as a linked list, broken links as text, influence lineage.

**`examples/wiki-demo.lisp:render-page-view@b9ad8c1`** composes the Amiga 1000 article:
1. Creates composition context (theme resolves automatically)
2. Renders infobox via `:infobox` lens and binds to `"page.infobox"`
3. Assembles metadata and binds as `"adjunct-content"`
4. Calls `compose-page` (which uses `:default` lens for the feature)

**`examples/wiki-demo.lisp:render-index-page@b9ad8c1`** sets entity to the wiki container,
pre-sorts alphabetically, and composes. `compose-aggregate`
walks the container and applies `:summary` lenses to each entry.

### `examples/static/wiki.css@b9ad8c1` (~120 lines)

Styles for infobox (`<dl>` with gray background, uppercase labels),
broken links (red), wiki header/footer, and aggregate entries.


## What This Exercises for the First Time

Table: Features this demo exercised for the first time, and their status before it.

| Feature | Status before this demo |
|---|---|
| Child theme with lens inheritance | Tested in unit tests; never in a demo |
| Multi-purpose lens rendering on one page | Never exercised |
| Sublens chain (computer → CPU :label) | REPL-only; first HTML rendering |
| Adjunct tier for page metadata | Never exercised in any demo |
| Alist infobox fallback alongside typed lenses | Never exercised |
| HTML passthrough for `<dl>` definition lists | First use in a demo |
| Wiki-link pre-processing to Lexis nodes | New |


## Pitfall: Missing `aggregate-content` slot in frame template

The initial frame template included `main-content` and
`adjunct-content` but omitted `aggregate-content`. The article page
rendered correctly (using `main-content` for the body). But the
index page was empty: `compose-aggregate` produced a section of
entries and bound it to `"aggregate-content"`, which had no matching
slot in the frame. The slot was present in the context bindings but
silently removed during `resolve-slots` (default behavior for
unmatched slots).

The fix was adding `(template.slot (@ :name "aggregate-content"))`
to the frame template. The article page ignores it (no aggregate
content); the index page fills it.

This is a useful lesson for theme authors: if a slot name is used
by the composer's standard binding logic (`main-content`,
`adjunct-content`, `aggregate-content`, `operative-content`,
`page-title`, `theme.assets`), the frame template should include
a matching `template.slot` node for each one the page type needs.


## Verification

- Test suite: 181/181 checks pass (no production code changes)
- Blog demo: produces 2 HTML files
- Forum demo: produces 2 HTML files
- Wiki demo: produces 2 HTML files

The wiki article page (Amiga 1000) contains:
- Title "Amiga 1000" in `<head>` and `<h1>`
- Stylesheet linked via passthrough
- Wiki header from slot-fill
- Infobox as `<dl>` with 5 entries: Manufacturer (text), Released
  (text), Designer (linked to Jay Miner's page), CPU (sublens:
  "Motorola 68000 7.16 MHz"), Price (text)
- Body with resolved wiki-links as `<a>` tags (Amiga 1000, Jay
  Miner, Motorola 68000, AmigaOS)
- Metadata: backlinks (AmigaOS, Jay Miner, Motorola 68000) as
  linked list, influenced-by (Atari 800)
- Wiki footer from slot-fill

The wiki index page shows 4 entries alphabetically: Amiga 1000,
AmigaOS, Jay Miner, Motorola 68000, each with a creation date.


## Files

Table: Files created or modified by this work.

| File | Action | Description |
|---|---|---|
| `examples/wiki-demo.lisp` | Created | Self-contained demo (~500 lines) |
| `examples/static/wiki.css` | Created | Reference stylesheet (~120 lines) |
| `doc/demos/wiki-page-output.html` | Created | Rendered Amiga 1000 article page |
| `doc/demos/wiki-index-output.html` | Created | Rendered alphabetical index |
| `README.md` | Modified | Added wiki demo to demos table and structure |
| this file | Created | |


## Outstanding Work

Deferred; see CCOMPOSER-DRAFT-wikirenderdemo-D3 and CCOMPOSER-DRAFT-wikirenderdemo-D5.
