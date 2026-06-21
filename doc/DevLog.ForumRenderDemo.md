# Forum Render Demo: Development Log

This document chronicles the addition of a forum rendering demo to
the Classic Composer. The demo parallels the existing blog demo,
exercising the same composition pipeline against a different content
profile: threaded forum posts with reactions, quotes, and member
profiles instead of authored blog articles.

**Date:** 2026-06-21


## Problem

The blog demo established that the composer could render HTML from
Classic content end-to-end. But the blog is one content profile. The
composer's five-tier model claims to be domain-agnostic -- the same
tiers, the same slot resolution, the same lens evaluation should work
for any publication type. Validating that claim requires a second
content profile.

The forum preset (completed in `classic.models.common` alongside the
blog) provides the second profile: `forum-thread` (a container of
posts), `forum-post` (a threaded, stateful, deletable content item),
and `forum-account` (members with nicknames, titles, and post counts).
The content classes inherit from the schema's universal primitives
and compose mixins the same way blog articles do, but the content
shape is fundamentally different: threaded posts rather than authored
articles, containers that are threads rather than chronological feeds.

The question was: does the composer handle this different shape
without modifications to the pipeline?


## What Was Required

### No production code changes to the composer

The forum demo required zero changes to the composer's pipeline,
protocols, or tier methods. `compose-aggregate`'s default container
walk (added in the blog demo iteration) worked out of the box: a
`forum-thread` is a `classic-container`; its `contains` list holds
post URIs; the walker retrieves each, applies a lens, and produces a
section per entry.

The theme system, slot-fills, passthrough asset surface, and lens
evaluation all operated identically. The only composer-adjacent
change was fixing the blog demo's API references to match the
General Model refactor's renamed functions (`write-article` instead
of `write-post`, `imprint-strategy` instead of `blog-strategy`, etc.).

### New demo file

`examples/forum-demo.lisp` (~220 lines) follows the same structure
as the blog demo:

1. **Setup.** `setup-forum` creates a forum imprint with three
   members (admin, regular member, moderator), three threads (one
   discussion with replies/reactions/quotes, one pinned rules thread,
   and one shorter discussion), and sample moderation actions.

2. **Theme.** `setup-theme` defines a single theme with:
   - A frame template with brand, content, aggregate, and footer slots
   - Slot-fills for the brand header and footer
   - An asset manifest pointing to `forum.css`
   - Lenses: `forum-thread` `:summary` (title + date), `forum-post`
     `:summary` (author via sublens, date, body, stickers as list),
     `classic-person` `:label` (name)

3. **Rendering.** Two page functions:
   - `render-index-page`: entity = forum's main container,
     `compose-aggregate` walks threads
   - `render-thread-page`: entity = a specific `forum-thread`,
     `compose-aggregate` walks posts

4. **Output.** `run-demo` writes both pages to `doc/demos/`.

### Reference stylesheet

`examples/static/forum.css` (~85 lines) provides minimal styling
for the forum pages using the same CSS variable scheme as the blog
stylesheet. Uses a sans-serif font stack (vs. the blog's serif) to
visually distinguish the two content profiles.


## Design Decisions

### 1. Both pages are aggregate views

In the five-tier model, a thread page showing all posts as peers is
an aggregate view -- it presents a collection of entities (posts)
from a container (the thread). This matches the architectural
discussion where forum posts were classified as feature-tier content
within a thread, but at the page level the thread view is an
aggregate of those features.

The same `compose-aggregate` default handles both:
- Forum index: entity = forum container, entries = threads
- Thread view: entity = thread (a container), entries = posts

No forum-specific `defmethod` was needed.

### 2. Thread ordering uses internal API

`ordered-threads` (which sorts pinned threads first) is not exported
from `classic.models.common`. The demo accesses it via the double-
colon convention (`classic.models.common::ordered-threads`). This is
acceptable for a demo; a production integration would either export
the function or provide a higher-level routing API.

### 3. Forum-thread uses `created-at` not `date-created`

`forum-thread` extends `classic-container`, not `classic-creative-work`.
It has `created-at` (from `classic-resource`) but not `date-created`
(from `creative-work`). The thread summary lens references
`created-at` accordingly. This surfaced a real schema distinction
that the lens system handles correctly: the property just gets
skipped if it doesn't exist on the class.

### 4. Post bodies are plain strings, not Lexis subtrees

Unlike the blog demo (which stores Lexis subtrees and uses
`:display :html`), forum post bodies are stored as plain strings
(including markdown-formatted blockquotes for quoted posts). The
lens omits `:display` on the body property, so the cascade hits
`:format :markdown` from the schema and the markdown stub wraps it
in a paragraph. This is correct for the demo -- forum posts are
typically short prose, not structured documents.

### 5. Stickers render as a plain list

The post lens includes `post-stickers` with `:display :list`. The
sticker strings ("heart", "star") render as bare list items. A
production forum would map these to emoji or SVG glyphs via a
capability extension -- the data is there, the rendering just needs
a fancier handler.


## Blog Demo API Update

The blog demo's API references were updated to match the General
Model refactor:

| Old | New |
|-----|-----|
| `write-post` | `write-article` |
| `get-posts` | `get-articles` |
| `blog-strategy` | `imprint-strategy` |
| `blog-publication` | `imprint-publication` |
| `blog-container` | `imprint-container` |

These renames happened during Classic core's generalization of the
blog-specific vocabulary into content-neutral universals. The
composer's production code was already updated (it references schema
symbols via `classic.schema:`); only the demo file needed fixing.


## Verification

- Test suite: 181/181 checks pass (no production code changes)
- Blog demo: produces `blog-post-output.html` and
  `blog-list-output.html`
- Forum demo: produces `forum-thread-output.html` and
  `forum-index-output.html`

The forum thread page shows:
- Title "Favorite macro?" in document title and `<h1>`
- Stylesheet linked via passthrough
- Forum header from slot-fill
- Four posts (oldest first): Alice's OP with heart reaction, Bob's
  reply with two star reactions, Carol's quote-reply with blockquote,
  Alice's reply to Bob's thread
- Forum footer from slot-fill

The forum index page shows:
- Three thread entries (title + date)
- Forum header and footer


## Files

| Action | File | Description |
|---|---|---|
| Created | `examples/forum-demo.lisp` | Self-contained forum demo (~250 lines) |
| Created | `examples/static/forum.css` | Reference stylesheet (~85 lines) |
| Created | `doc/demos/forum-thread-output.html` | Rendered thread page |
| Created | `doc/demos/forum-index-output.html` | Rendered index page |
| Modified | `examples/blog-demo.lisp` | Updated API references for General Model refactor |
| Modified | `README.md` | Added demos table, forum demo references, updated structure |
| Created | this file | |


## Addendum: Post Ordering and Index Stability

Two bugs were found and fixed after the initial forum demo was built.

### Bug A: Misplaced reply from unstable thread indices

**Symptom.** Alice's "SBCL for production..." reply, intended for the
"Best CL implementation" thread, appeared in the "Favorite macro?"
thread. The thread view showed 4 posts instead of 3.

**Cause.** The demo interleaved thread creation, replies, and
pinning. `ordered-threads` returns pinned threads first; pinning
reordered the thread list, invalidating index assumptions made by
subsequent `post-reply` calls.

Specifically: after creating "Favorite macro?" and "Forum rules",
the demo pinned "Forum rules" at index 1. Then "Best CL" was created
(pushing to head), making the container [Best CL, Forum rules,
Favorite macro?]. After pinning, `ordered-threads` returned [Forum
rules (pinned), Best CL, Favorite]. `(post-reply forum 3 ...)` then
added the reply to index 3 = Favorite macro? instead of the intended
Best CL.

**Fix.** Reordered the demo's setup sequence: all three threads are
created first, then all replies target stable pre-pin indices, then
pinning happens last. The comment block at the top of the setup
function documents the resulting index layout.

### Bug B: Thread posts displayed in reverse chronological order

**Symptom.** Posts in the thread view appeared newest-first (Carol's
quote-reply at top, Alice's OP at bottom). Forum threads should read
oldest-first for chronological conversation flow.

**Cause.** The `contains` slot on containers is built by `push`
(newest at head). The forum model's own `thread-posts` function
reverses the list for reading, but the composer's generic
`compose-container-entries` iterated it as-stored. The default
ordering was newest-first, correct for blog indexes but wrong for
forum threads.

**Fix.** A production-side `container-reading-order` generic was
added to the composer's protocol layer:

```lisp
(defgeneric container-reading-order (entity)
  (:documentation "Return the natural reading order for ENTITY's
contents. Returns :AS-STORED (default) or :REVERSE."))
```

`compose-container-entries` calls this and reverses the `contains`
list when the entity returns `:REVERSE`. The default method returns
`:AS-STORED` for backward compatibility.

The forum demo specializes it for `forum-thread`:

```lisp
(defmethod container-reading-order
    ((entity forum-thread))
  :reverse)
```

This is the right level of abstraction: the ordering convention is a
property of the content type, not of the composer or the theme. A
blog container keeps newest-first; a forum thread reverses to
oldest-first; a future wiki section index might sort alphabetically.
Each declares its intent via the generic; the composer respects it.

### Files changed in this addendum

| Action | File | Description |
|---|---|---|
| Modified | `examples/forum-demo.lisp` | Reordered setup; added `container-reading-order` method for `forum-thread` |
| Modified | `src/protocol.lisp` | Added `container-reading-order` generic with `:as-stored` default |
| Modified | `src/defaults.lisp` | `compose-container-entries` uses `container-reading-order` |
| Modified | `src/packages.lisp` | Exported `container-reading-order` |


### Bug C: Blockquote not separated from reply text

**Symptom.** Carol's quoted post rendered inline with her reply in a
single `<p>` tag. The `>` characters appeared as literal `&gt;`
entities with no visual separation.

**Cause.** The `body` slot on forum posts has `:format :markdown` in
the schema. The markdown stub (`render-markdown-stub`) wrapped the
entire string in a single `(paragraph ...)`, treating `>` prefixed
lines as literal text.

**Fix.** Enhanced the markdown stub to handle two features:

1. **Paragraph breaks on double-newlines.** Text is split into
   blocks; each block becomes its own `(paragraph ...)`.
2. **Blockquote detection.** Blocks where every line starts with
   `> ` are wrapped in `(blockquote (paragraph ...))` with the
   prefix stripped.

This is still a stub -- not a full Markdown parser -- but it handles
the two features most visible in forum post bodies. The split
produces correct output for Carol's post: the quoted text renders in
a `<blockquote>` and her reply renders in a separate `<p>`.

### Bug D: Real names shown instead of member nicknames

**Symptom.** Posts were attributed to "Alice Hong", "Bob Park",
"Carol Q" instead of "alice42", "bobcat", "cQ".

**Cause.** The post lens used `(:sublens classic-person :purpose
:label)` on the `author` property. The `author` slot holds a person
URI; the sublens retrieved the person entity and displayed its
`agent-name`. But forums display member nicknames, which live on the
`forum-account`, not the person.

The lens system navigates entity -> slot value -> retrieve related
entity -> apply sublens. It does not support reverse-relationship
navigation (person -> find account with `account-of` = person ->
get `member-nickname`). This navigation requires a persistence
query that the lens evaluator does not perform.

**Fix (demo-side).** Two changes:

1. The forum post lens declares `(:display :text)` on the author
   property instead of using a sublens. The explicit `:display`
   overrides the cascade, which would otherwise pick `:link` from
   the slot's `:persistence :relation` annotation.

2. A `resolve-authors-to-nicknames` helper runs after all posts are
   created, replacing each post's author URI with the member's
   nickname string. The resolution uses `resolve-member-nickname`
   from the forum model.

This is a demo-level workaround. A production forum would handle
the navigation at render time, either through a custom capability
that intercepts the `author` property and performs the reverse
lookup, or through a lens extension that supports relationship
traversal.

### Files changed in this addendum

| Action | File | Description |
|---|---|---|
| Modified | `src/lens.lisp` | Enhanced `render-markdown-stub` with paragraph splitting and blockquote detection (~75 new lines) |
| Modified | `examples/forum-demo.lisp` | Author lens uses `:display :text`; added `resolve-authors-to-nicknames` helper |
