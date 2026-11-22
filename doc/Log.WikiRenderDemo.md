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

### 1. Child theme inheriting parent lenses

The wiki's built-in theme (from `make-wiki`) provides six lens specs:
`:infobox` and `:label` for `wiki-computer`, `wiki-cpu`, and
`wiki-person`. The demo's child theme adds four more: `:default` and
`:summary` for `wiki-page` (the common superclass). The composer
resolves both via `resolve-theme-lenses`, which merges the chain
child-first.

The child doesn't need to redeclare the parent's lenses. Lens
resolution walks the chain and preserves parent lenses for
`(class, purpose)` pairs the child doesn't override. This is the
first time the demo suite exercises this inheritance.

### 2. Infobox as separate slot-fill, not part of the :default lens

The infobox (sidebar with typed fields) is rendered from the
`:infobox` lens and bound to the `"page.infobox"` template slot.
The main article body is rendered from the `:default` lens and bound
to `"main-content"`. This respects the tier model: the infobox is
structurally positioned by the frame template, not embedded in the
body.

The alternative (a single `:default` lens containing both infobox
and body properties) would conflate two distinct page regions that
need independent positioning in the frame.

### 3. Pre-processing body wiki-links to Lexis nodes

Wiki bodies contain `[[Page Name]]` references that need to become
HTML links. The demo pre-processes bodies during setup, converting
`[[refs]]` to `(web-link ...)` nodes for resolved links and
`(emphasis (@ :class "broken-link") "Name")` for broken links. The
processed body is stored as a Lexis subtree and rendered via
`:display :html` in the `:default` lens.

A production wiki would handle this at render time via a capability
that intercepts the body property and performs link resolution. The
demo pre-processes for consistency with the other demos.

### 4. Typed-slot anchors resolved to URIs before composition

Wiki typed slots (`computer-designer`, `computer-cpu`) store anchor
strings. The composer's `apply-sublens` retrieves entities by URI.
The demo resolves anchors to URIs during pre-processing so the
sublens chain works with the generic composer machinery.

### 5. Definition-list via HTML passthrough

The Lexis spec defines `definition-list` and `definition` tags
(Section 4.3) but they are not yet implemented in the Lexis HTML
renderer. The demo uses `(passthrough (@ :medium :html) (:dl ...))` 
to emit proper `<dl>/<dt>/<dd>` HTML directly. When Lexis adds
native `definition-list` support, the passthrough can be replaced
with semantic Lexis nodes.

### 6. Metadata as adjunct content

Backlinks ("what links here"), broken links, and influence lineage
are assembled during pre-processing and bound to `"adjunct-content"`.
The frame template positions this below the main content. This is
the intended use of the adjunct tier: content subordinate to or
annotating the feature.

### 7. Alphabetical index via pre-sorted container

The wiki index page sorts alphabetically by page anchor. The demo
pre-sorts the container's `contains` list before composition,
matching the approach used in the forum demo for pin ordering.

### 8. Amiga-era content

Pages: Jay Miner (wiki-person), Motorola 68000 (wiki-cpu), Amiga
1000 (wiki-computer), AmigaOS (generic wiki-page with alist
infobox). The Amiga 1000 references both Jay Miner (via
`computer-designer` typed slot) and Motorola 68000 (via
`computer-cpu` sublens), plus AmigaOS via `[[wiki-link]]` in the
body. This exercises all three cross-reference mechanisms: typed
slot `:link`, sublens chain, and body wiki-link.


## Implementation

### `examples/wiki-demo.lisp` (~500 lines)

**`setup-wiki`** creates the wiki with 4 pages in dependency order
(person first, then CPU, then computer, then generic OS page).
Pages are published via the editorial workflow.

**`setup-child-theme`** creates a child theme:
- Parent: the wiki's built-in theme URI
- Frame template with 8 slots (title, assets, brand, infobox,
  main-content, aggregate-content, adjunct-content, footer)
- Slot fills for brand header and footer
- Asset manifest pointing to wiki.css
- `:default` lens for `wiki-page` (headline + body as `:html`)
- `:summary` lens for `wiki-page` (headline + created-at as `:date`)

**`pre-process-all-pages`** runs two passes over all pages:
1. `resolve-typed-slots-to-uris` — converts anchor strings to URIs
   for sublens resolution
2. `convert-wiki-body-to-lexis` — parses `[[refs]]` and produces
   Lexis subtrees with `(web-link ...)` and broken-link markers

**`render-infobox-to-lexis`** walks the `:infobox` lens for the
page's class, renders each property (with display modes and sublens
resolution), and assembles a `<dl>` via HTML passthrough. For
generic pages, renders the alist infobox as `<dl>` entries.

**`assemble-page-metadata`** builds adjunct content sections:
backlinks as a linked list, broken links as text, influence lineage.

**`render-page-view`** composes the Amiga 1000 article:
1. Creates composition context (theme resolves automatically)
2. Renders infobox via `:infobox` lens and binds to `"page.infobox"`
3. Assembles metadata and binds as `"adjunct-content"`
4. Calls `compose-page` (which uses `:default` lens for the feature)

**`render-index-page`** sets entity to the wiki container,
pre-sorts alphabetically, and composes. `compose-aggregate`
walks the container and applies `:summary` lenses to each entry.

### `examples/static/wiki.css` (~120 lines)

Styles for infobox (`<dl>` with gray background, uppercase labels),
broken links (red), wiki header/footer, and aggregate entries.


## What This Exercises for the First Time

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

| Action | File | Description |
|---|---|---|
| Created | `examples/wiki-demo.lisp` | Self-contained demo (~500 lines) |
| Created | `examples/static/wiki.css` | Reference stylesheet (~120 lines) |
| Created | `doc/demos/wiki-page-output.html` | Rendered Amiga 1000 article page |
| Created | `doc/demos/wiki-index-output.html` | Rendered alphabetical index |
| Modified | `README.md` | Added wiki demo to demos table and structure |
| Created | this file | |
