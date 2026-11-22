---
id:            CCOMPOSER-DRAFT-readonlydemos
title:         Read-Only Demos and Page Links Development Log
genre:         Log
scope:         component
project:       Classic Composer
component:     demo
language:      en
status:        Draft
provenance:
  assistant:          claude-opus-5-5
  original-assistant: claude-opus-5-5
  migrated-from:      doc/DevLog.ReadOnlyDemos.md@06ac6bb
relates-to:
  - CCOMPOSER-0001
  - CCOMPOSER-0005
  - CCOMPOSER-DRAFT-lexismarkdown
decisions:
  - CCOMPOSER-DRAFT-readonlydemos-D1
  - CCOMPOSER-DRAFT-readonlydemos-D2
  - CCOMPOSER-DRAFT-readonlydemos-D3
  - CCOMPOSER-DRAFT-readonlydemos-D4
  - CCOMPOSER-DRAFT-readonlydemos-D5
  - CCOMPOSER-DRAFT-readonlydemos-D6
---

# Read-Only Demos and Page Links: Development Log

This document records two changes to the Classic Composer. The first
adds the extension generics that let the three demos render their
publications without modifying them. The second adds links between
pages: each demo now writes a small static site of linked pages, not
one or two unconnected pages.

**Date:** 2026-11-20


## Problem

The composer is read-only with respect to Classic's data, but its
forum and wiki demos were not. Each rewrote stored entities so that
the composer's generic machinery would render them, because the
composer offered no way to compute the values instead:

Table: The demos' writes to stored data, and why each was made.

| Demo | Write | Why |
|---|---|---|
| Forum | Replaced every post's `author` (a person URI) with the member's nickname, and persisted it | A lens could not follow the reverse relation from a person to the forum account that names it (Bug D of [CCOMPOSER-0005](Log.ForumRenderDemo.md)) |
| Forum | Reordered the forum container's `contains` list, pinned threads first, and persisted it | The container walk read `contains` as stored, and `container-reading-order` could only keep or reverse it |
| Wiki | Replaced the anchors in typed slots (`computer-designer`, `computer-cpu`, `cpu-designer`) with page URIs, and persisted the pages | A sublens could only retrieve a URI, and the slots name pages by anchor |
| Wiki | Sorted the wiki container's `contains` alphabetically, and persisted it | The same limit as the forum's order |

Each demo was also missing its pages' links. The demos rendered one
entry page and one index page each. The index entries were plain
text, and the wiki's links pointed at `/wiki/<anchor>` paths that
kept their spaces and named pages the demo never wrote. The composer
had no notion of an entity's page.

The Markdown reader work ([CCOMPOSER-DRAFT-lexismarkdown](Log.LexisMarkdown.md)) removed a fifth
write, the wiki demo's conversion of page bodies to Lexis, and listed
these as outstanding.


## Design Decisions

### CCOMPOSER-DRAFT-readonlydemos-D1 — Extension generics, not a richer lens language

**Status:** Proposed
**Context:** Each write stood in for a computation the composer could not ask the
application for.

**Decision:** The composer already had two hooks of the right
kind, `container-reading-order` and `markdown-options`: a generic
function with a default that keeps the base behavior, which an
application specializes on its content classes. Four more follow the
same pattern, all in `src/protocol.lisp`:

- `lens-property-value (context entity property)` (`src/protocol.lisp:lens-property-value@7fa52ba`) gives the value a
  lens reads. The default reads the slot. A method, usually with an
  `eql` specializer on the property, defines a *computed property*: a
  name the lens uses like a slot, whose value is derived. Its display
  mode is `:text` unless the lens says otherwise, since there is no
  slot definition to consult.
- `resolve-reference (context entity property value)` (`src/protocol.lisp:resolve-reference@7fa52ba`) gives the
  entity a reference names. The default retrieves a URI string and
  passes an entity through. It is specialized on the class of the
  *referring* entity, since what a reference means depends on who
  holds it.
- `entity-href (context entity)` (`src/protocol.lisp:entity-href@7fa52ba`) gives the URL of the entity's page.
  The default is `nil`, so nothing links until a site says how its
  pages are addressed.
- `container-entries (context container)` (`src/protocol.lisp:container-entries@7fa52ba`) gives the entities an
  aggregate view lists, in order. The default is the old container
  walk: `contains` in `container-reading-order`, skipping URIs that
  do not resolve.

**Alternatives:** A more declarative alternative, such as property paths in the lens
spec (`author / ^sioc:account_of / member-nickname`), was considered
and not adopted. It would add a small query language to lens specs
and still not cover the wiki's anchors or the forum's pinning rule,
which are rules of the content types rather than paths through the
data. Lens specs stay data, and the rules live in code.

Every generic takes the composition context, so a method reads
through the persistence protocol (`context-query`,
`context-retrieve`). The forum's author lookup uses the relation index
of `sioc:account_of` rather than scanning the store, as the forum
model's `resolve-member-nickname` does.

### CCOMPOSER-DRAFT-readonlydemos-D2 — Two orders: content-type rules and presentation choices

**Status:** Proposed
**Context:** The forum's pinned-first order and the wiki's alphabetical order look
alike but differ in kind.

**Decision:** Pinning is a rule of forums: the forum
model's own `ordered-threads` applies it, and every view of the
forum's threads should respect it. That rule is a `container-entries`
method on `classic-forum`, the class of the forum's root container.

Alphabetical order is a choice of one view. A "recent changes" page
over the same container would list by date. The wiki's container is
also a plain `classic-container`, like the blog's, so a method on its
class would reorder every publication's container. The order
therefore belongs to the theme, as an *aggregate lens*: a lens with
purpose `:aggregate` on the container's class, whose `:sort-by` names
the property to sort by. `:sort-order :descending` reverses it.
Themes are per publication, so the wiki's theme orders only the
wiki. The default `container-entries` applies the aggregate lens.
The sort is stable, compares numbers numerically and other values by
printed form, and puts entries without a value last.

Lens specs carry extra keys through `classic.schema:lens-properties`
and `find-lens` unchanged, so neither the aggregate lens nor the
property options below needed a change to Classic's schema.

**Alternatives:** See the Decision.

### CCOMPOSER-DRAFT-readonlydemos-D3 — Property options: `:link :self` and `:label`

**Status:** Proposed
**Context:** Not recorded in the original.

**Decision:** `:link :self` on a lens property links its rendered value to the page
of the entity it belongs to. This is how index entries link to their
pages, and how a sublens on a member account links the nickname to
the profile. Blocks, which a link cannot hold, are left unlinked, and
so is everything when `entity-href` gives no page.

`:label "Text"` captions a value: an inline value becomes
`(paragraph (strong "Text:") " " value)`, and a block value is
preceded by a paragraph holding the caption. It was added for the
forum's profile pages, which without it were a run of unlabeled
values ("cQ Moderator moderator 2026-11-20 2"). It corresponds to
Fresnel's property labels.

**Alternatives:** Not recorded in the original.

### CCOMPOSER-DRAFT-readonlydemos-D4 — References follow `resolve-reference` everywhere

**Status:** Proposed
**Context:** Not recorded in the original.

**Decision:** Sublenses and the `:link` display mode both resolve their values
through `resolve-reference`. A resolved target in the `:link` mode is
linked to its page, or to the reference itself when that is a URI,
and shown by its title. An unresolved reference that is a URI is
linked as before. Anything else, such as the anchor of a page that
does not exist ("Tom Gunter", the 68000's designer), is shown as text
rather than as a link to a non-URI. The old `:link` rendering of a
relation slot showed the *referring* entity's label, so an author
link read as the article's title. A resolved target now shows its own
title.

**Alternatives:** See the Decision.

### CCOMPOSER-DRAFT-readonlydemos-D5 — `render-lens-property` is exported

**Status:** Proposed
**Context:** Not recorded in the original.

**Decision:** `apply-lens`'s per-property body is now `render-lens-property`,
exported for code that lays properties out itself. The wiki demo's
infobox, which pairs each property with a caption in a definition
list, is the first user. Before, it re-implemented sublens and link
rendering and relied on the rewritten slots.

**Alternatives:** See the Decision.

### CCOMPOSER-DRAFT-readonlydemos-D6 — Each demo writes a linked static site

**Status:** Proposed
**Context:** See [Problem](#problem).

**Decision:** Each demo now renders every page its links reach, under its own
directory: `doc/demos/blog/`, `doc/demos/forum/` and
`doc/demos/wiki/`, each starting at `index.html`. Its `entity-href`
methods name pages from labels, nicknames or anchors (`thread-favorite-macro.html`,
`member-cq.html`, `amiga-1000.html`), not from URIs, because minted
URIs carry a random component and the file names would change on
every run. Each brand header links back to the index. The six
single-page output files of earlier logs are removed. The asset base
is one directory deeper, `../../../examples/static/`.

Each demo carries its own `slugify`, keeping it self-contained.

**Alternatives:** See the Decision.


## Implementation

- **`src/protocol.lisp@7fa52ba`.** The four generics, with defaults for
  `src/protocol.lisp:lens-property-value@7fa52ba`, `src/protocol.lisp:resolve-reference@7fa52ba` and `src/protocol.lisp:entity-href@7fa52ba`.
- **`src/lens.lisp@7fa52ba`.**
  - `src/lens.lisp:apply-lens@7fa52ba` delegates to `src/lens.lisp:render-lens-property@7fa52ba`, which reads
    values with `lens-property-value` and applies `:link :self` and
    `:label`.
  - `src/lens.lisp:render-reference-link@7fa52ba` renders the `:link` mode, and
    `src/lens.lisp:uri-like-p@7fa52ba` decides whether a value is a URI.
  - `src/lens.lisp:apply-sublens@7fa52ba` and `src/lens.lisp:apply-sublens-single@7fa52ba` take `:entity` and
    `:property` and resolve through `resolve-reference`.
  - `src/lens.lisp:block-node-p@7fa52ba` tells block nodes from inline ones.
- **`src/defaults.lisp@7fa52ba`.**
  - The default `src/defaults.lisp:container-entries@7fa52ba` and `src/defaults.lisp:sort-entities@7fa52ba`.
  - `src/defaults.lisp:compose-container-entries@7fa52ba` lists what `src/defaults.lisp:container-entries@7fa52ba`
    gives, and `src/defaults.lisp:compose-container-entry@7fa52ba` takes an entity.
  - The label fallback for entries without a lens links to the
    entry's page.
- **`examples/forum-demo.lisp@7fa52ba`.**
  - `examples/forum-demo.lisp:container-entries@7fa52ba` on `classic-forum` puts pinned threads first.
  - Two computed properties: `post-author-account` (the reverse
    relation) and `member-role`.
  - `examples/forum-demo.lisp:entity-href@7fa52ba` for threads, accounts and the forum.
  - A `:label` lens on `forum-account` links nicknames, and a
    `:default` lens makes the profile page.
  - The pages are the index, every thread and every member's
    profile.
  - `resolve-authors-to-nicknames` and the container reordering are
    removed.
- **`examples/wiki-demo.lisp@7fa52ba`.**
  - `examples/wiki-demo.lisp:resolve-reference@7fa52ba` on `wiki-page` looks anchors up.
  - `examples/wiki-demo.lisp:entity-href@7fa52ba` names page files, and the Markdown link resolver
    and the backlinks use it.
  - The child theme gets an aggregate lens.
  - The infobox renders its values with `render-lens-property`.
  - The pages are the index and every article.
  - `resolve-typed-slots-to-uris`, `pre-process-all-pages`,
    `make-minimal-sublens-context` and the container sort are
    removed.
- **`examples/blog-demo.lisp@7fa52ba`.** `examples/blog-demo.lisp:entity-href@7fa52ba` for posts, a linked
  summary headline, and pages for the index and every post.
- **Tests.**
  - `test/helpers.lisp@7fa52ba` gains `test/helpers.lisp:hooks-test-context@7fa52ba`, a context
    subclass whose methods for the four generics read its slots. A
    test drives the generics through the context, and no method
    leaks into other contexts.
  - Fifteen new tests cover computed properties, `:link :self`,
    `:label`, the `:link` mode's three cases, references followed by
    a sublens, `uri-like-p`, stored order, aggregate-lens sorting in
    both directions, number keys and missing values, a
    `container-entries` method, and linked container entries.


## Verification

- **Test suite.** 266/266 checks pass (225 before). Forced
  recompiles of `classic.composer` and its tests give no warnings.
- **No writes.** A check run built the forum, rendered every page,
  and confirmed that the forum container's `contains` list was
  unchanged and every post's `author` was still a person URI. After
  the wiki demo ran, the Amiga 1000 page's `computer-designer` was
  still the anchor `"Jay Miner"` and its body still a Markdown
  string.
- **Output.**
  - **Forum.** The index lists the pinned rules thread first, and its
    titles link to the thread pages. Posts show nicknames linked to
    profiles, and each profile shows the title, role, join date and
    post count.
  - **Wiki.** The index lists Amiga 1000, AmigaOS, Jay Miner and
    Motorola 68000 in that order. The Amiga 1000 page differs from
    the previous output only in its links and stylesheet path: the
    infobox's designer links to `jay-miner.html`, and the body's
    links go to page files. The 68000's unknown designer is plain
    text.
  - **Blog.** The index titles link to the posts. The post pages
    differ from the previous output only in the brand link and the
    stylesheet path.


## Files

Table: Files created, modified or deleted by this work.

| File | Action | Description |
|---|---|---|
| `src/protocol.lisp` | Modified | `lens-property-value`, `resolve-reference`, `entity-href`, `container-entries` |
| `src/lens.lisp` | Modified | `render-lens-property`, property options, reference links, sublens resolution |
| `src/defaults.lisp` | Modified | Default `container-entries`, aggregate-lens sorting, entity-based container entries |
| `src/packages.lisp` | Modified | Exported the generics and `render-lens-property` |
| `test/helpers.lisp` | Modified | `make-test-container`, `hooks-test-context` |
| `test/test-lens.lisp` | Modified | Property value, option, link-mode and reference tests |
| `test/test-defaults.lisp` | Modified | Container entry order, sorting and linking tests |
| `examples/blog-demo.lisp` | Modified | Page links; pages for the index and every post |
| `examples/forum-demo.lisp` | Modified | Read-only composition rules; page links; thread and profile pages |
| `examples/wiki-demo.lisp` | Modified | Read-only references and order; page links; a page per article |
| `doc/demos/blog/`, `doc/demos/forum/`, `doc/demos/wiki/` | Created | The rendered sites |
| `doc/demos/*-output.html` | Deleted | The six single-page outputs, superseded |
| `README.md`, `doc/Composer.md` | Modified | Extension generics, property options, aggregate lenses, demo output |
| this file | Created | |


## Outstanding Work

- **The blog demo's setup** still overwrites each post's body with
  Lexis forms after `write-article` stores a placeholder. This is
  authoring rather than composition, since it happens once while the
  sample content is built, but a `write-article` that accepted a
  Lexis body, or Markdown bodies, would remove it.
- **The wiki's anchor lookups** go through the `*wiki*` global,
  because the composition context carries no wiki imprint.
- **Forum views.** Post numbers, the "(quoting)" marker, sticker
  glyph counts, thread starter and counts on the index, hidden-post
  placeholders and lock notices are not yet shown. Computed
  properties now make each of these a method and a lens entry.
- **Heading depth** (LEXIS-O3) and the **wiki infobox as Lexis**
  remain as [CCOMPOSER-DRAFT-lexismarkdown](Log.LexisMarkdown.md) describes them. The infobox
  stays a passthrough because the Lexis HTML renderer drops classes.
