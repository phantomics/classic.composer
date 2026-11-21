---
id:            CCOMPOSER-DRAFT-lexismarkdown
title:         Lexis Markdown Integration Development Log
genre:         Log
scope:         component
project:       Classic Composer
component:     lens
language:      en
status:        Draft
provenance:
  assistant:   claude-opus-5-5
relates-to:
  - LEXIS-0002
  - LEXIS-DRAFT-markdownref
  - LEXIS-DRAFT-markdown
  - CLASSIC-0011
decisions:
  - CCOMPOSER-DRAFT-lexismarkdown-D1
  - CCOMPOSER-DRAFT-lexismarkdown-D2
  - CCOMPOSER-DRAFT-lexismarkdown-D3
  - CCOMPOSER-DRAFT-lexismarkdown-D4
  - CCOMPOSER-DRAFT-lexismarkdown-D5
  - CCOMPOSER-DRAFT-lexismarkdown-D6
---

# Lexis Markdown Integration: Development Log

This document chronicles the replacement of the composer's placeholder
Markdown handling with the Lexis Markdown reader, `lexis.markdown`. The
`:markdown` display mode now reads a slot's text into Lexis blocks, and
applications pass options to the reader through a new generic,
`markdown-options`. A body of several blocks is spliced into the page
rather than wrapped in a section of its own. The wiki demo keeps its
page bodies as Markdown and resolves their wiki links while each page
is composed. The work is commit `ac700d0`, built against Lexis
`31dd926` and Classic `807640b`.


## Problem

Classic stores the bodies of articles, forum posts and wiki pages as
strings declared `:format :markdown`, and the lens display-mode
cascade of the theme ontology ([CLASSIC-0011](../../classic/doc/theme/Ref.Theme.md))
gives such a slot the `:markdown` mode. That mode was a stub,
`src/lens.lisp:render-markdown-stub@fb3ebed`. It split the text on
blank lines and made each block a paragraph. Its one other construct
was a block quote, added for the forum demo's quoted posts. Headings,
lists, code blocks and links were not recognised.

Lexis now has a Markdown reader, planned in
[LEXIS-0002](../../lexis/doc/Plan.RenderMarkdown.md) and described in
[LEXIS-DRAFT-markdownref](../../lexis/doc/Ref.Markdown.md). The last
step of that plan's roadmap hands the reader over to the composer:
replace the stub, and supply a wiki link resolver where wiki links
name pages. The plan's open question LEXIS-O3 also concerns the
composer. The stub wrapped a body of several blocks in an untitled
`(section (@ :class "body") ...)`. Lexis counts every section when it
computes heading depth (`LEXIS:src/parse.lisp:compute-depths@31dd926`),
so the wrapper pushed the body's own sections one level deeper when
rendered.

Two demos worked around the stub:

- **Blog.** The demo stores its bodies as Lexis forms and overrides
  the cascade with `:display :html`. Its bodies are lists of sections,
  and `src/lens.lisp:render-html-passthrough@fb3ebed` wrapped such a
  list in the same untitled section. The posts' section headings
  rendered as `<h4>`.
- **Wiki.** Before composing, the demo rewrote each page's body into
  Lexis, replacing the stored Markdown with Lexis forms and persisting
  them (`examples/wiki-demo.lisp:convert-wiki-body-to-lexis@fb3ebed`
  and three helpers). That is a write to Classic data, which the
  composer's read-only principle forbids.


## Design Decisions

### CCOMPOSER-DRAFT-lexismarkdown-D1 — The composer depends on lexis.markdown directly

**Status:** Proposed
**Context:** The reader is a Lexis module that brings in the Lexis
core, `cl-ppcre`, and 3bmd with four of its extension systems.
Markdown is Classic's default body format, so most content reaches
the composer through the `:markdown` mode.
**Decision:** `classic.composer` lists `lexis.markdown` in its
`:depends-on`. The composer still depends on no renderer: it uses
Lexis only to read Markdown.
**Alternatives:** A separate system, `classic.composer.markdown`, in
the capability-extension style of the architecture document, keeping
3bmd out of the base composer. Not adopted: a composer without it
would render most content badly, so nearly every user would load it.

### CCOMPOSER-DRAFT-lexismarkdown-D2 — Reader options come from a markdown-options generic

**Status:** Proposed
**Context:** The reader takes options: the raw HTML policy (LEXIS-D8),
the allowed URI schemes (LEXIS-D9), and a wiki link resolver
(LEXIS-D10). Only the application knows the right values. A wiki's
resolver looks pages up by anchor, with
`CLASSIC:mod/classic.models.common/wiki.lisp:find-page-by-anchor@807640b`,
which needs the wiki imprint. The composer depends on neither the
content models nor the imprint.
**Decision:** An exported generic, `markdown-options (context entity
slot-name)`, returns the keyword arguments passed to
`LEXIS:mod/markdown/markdown.lisp:markdown->lexis@31dd926`. Its default
method returns `nil`, which keeps the reader's safe defaults: raw HTML
is escaped, and links keep only the `http`, `https`, `mailto` and
`classic` schemes. Applications specialize it on their content
classes, as `container-reading-order` is specialized. The options must
not include `:document`, since the composer splices the reader's
blocks into its own tree. `render-slot-via-display-mode` gained
`:context`, `:entity` and `:slot-name` keywords to reach the generic,
and `apply-lens` supplies them.
**Alternatives:** Theme configuration was not adopted: a theme is not
the place to switch on `:raw-html :passthrough`, which only trusted
content may use. A dynamic variable was not adopted, since its value
would hold for every entity on a page rather than for each content
type. Options in the lens spec were not adopted for the same reason
as theme configuration.

### CCOMPOSER-DRAFT-lexismarkdown-D3 — Multi-block bodies are spliced, not wrapped

**Status:** Proposed
**Context:** The reader returns a list of blocks. Wrapping a list in
an untitled section pushes its headings one level deeper (LEXIS-O3),
and the plan's current thinking is that the composer should stop
wrapping, since an untitled section is not a real section.
**Decision:** A display mode may return a list of block nodes instead
of one node, and `apply-lens` splices the blocks into its result in
property order. `render-markdown` returns the single block when the
text gives one, the list when it gives several, and `nil` when it
gives none. The list case of `:html` passthrough returns its list
unwrapped too. This settles the composer's side of LEXIS-O3 in part:
`compose-feature` still wraps lens output in
`(section (@ :class "feature") ...)`, and `compose-container-entry`
wraps each entry in an untitled section. Both are counted by Lexis,
so a Markdown `##` heading in a feature renders as `<h3>`, not
`<h2>`. That remaining level is accepted for now, to be fixed in
Lexis, for example by not counting untitled sections.
**Alternatives:** A starting depth for the reader, the plan's other
option, was not adopted: the depth would have to match whatever
wrappers the composer and the theme add. Keeping the wrapper was not
adopted: it was the cause.

### CCOMPOSER-DRAFT-lexismarkdown-D4 — The body fallback reads Markdown bodies

**Status:** Proposed
**Context:** Without a lens, `compose-feature` falls back to
extracting the entity's body, and that fallback wrapped a string body
in a single paragraph whatever its format.
**Decision:** The fallback reads a string body as Markdown, with the
same options, when the body slot is declared `:format :markdown`. A
string body in any other format keeps the single paragraph.
**Alternatives:** Leaving the fallback as it was would render
Markdown bodies differently with and without a lens.

### CCOMPOSER-DRAFT-lexismarkdown-D5 — Wiki link resolvers build their forms from LEXIS symbols

**Status:** Proposed
**Context:** The reader's passes run over the form a wiki link
resolver returns. They recognise tags and the `@` attribute marker
by `eq` against the `lexis` package's symbols
(`LEXIS:mod/markdown/passes.lisp:form-parts@31dd926`,
`LEXIS:mod/markdown/passes.lisp:filter-uris@31dd926`). A form built
from another package's symbols would have its attribute list taken
for a child.
**Decision:** A resolver builds `lexis::web-link`, `lexis::@` and
similar forms, as the reader's reference does in its example. The
generic's documentation says so. The composer is unaffected by the
mixture: it compares tags by symbol name.
**Alternatives:** Having the composer re-intern the resolver's form
in the `lexis` package was not adopted, since the reader's convention
is already documented and a resolver can follow it.

### CCOMPOSER-DRAFT-lexismarkdown-D6 — The wiki demo resolves wiki links during composition

**Status:** Proposed
**Context:** The wiki demo's body conversion wrote Lexis forms over
the stored Markdown, both to resolve `[[Anchor]]` links and to break
paragraphs.
**Decision:** The bodies stay Markdown strings. The `:default` lens
for `wiki-page` lists the body without `:display :html`, so the slot's
`:format :markdown` selects the Markdown mode. A `markdown-options`
method on `wiki-page` supplies a resolver
(`examples/wiki-demo.lisp:resolve-wiki-link@ac700d0`) that links a
found page and marks a missing one with
`(emphasis (@ :class "broken-link") ...)`, as the conversion did. The
composition context carries no wiki imprint, so the resolver finds
pages through the demo's `*wiki*` global.
**Alternatives:** Keeping the conversion would keep the write.
Resolving wiki links in a pass of the composer's own would duplicate
the reader's resolver option.


## Implementation

### `classic.composer.asd`

The system's `:depends-on` names `lexis.markdown`
(CCOMPOSER-DRAFT-lexismarkdown-D1).

### `src/lens.lisp`

- `src/lens.lisp:render-markdown@ac700d0` replaces the stub. It reads a
  string, or the printed form of another value, with `markdown->lexis`
  and the options `markdown-options` gives.
- The stub and its four helpers are deleted:
  `src/lens.lisp:render-markdown-stub@fb3ebed`,
  `src/lens.lisp:split-markdown-blocks@fb3ebed`,
  `src/lens.lisp:split-on-blank-lines@fb3ebed`,
  `src/lens.lisp:blockquote-chunk-p@fb3ebed` and
  `src/lens.lisp:parse-blockquote-chunk@fb3ebed`. None was exported or
  tested.
- `src/lens.lisp:block-list-p@ac700d0` tells a list of nodes from a
  single node.
- `src/lens.lisp:render-html-passthrough@ac700d0` returns a list of
  nodes unwrapped.
- `src/lens.lisp:apply-lens@ac700d0` passes the context, entity and
  slot name to `src/lens.lisp:render-slot-via-display-mode@ac700d0`,
  and splices block lists (CCOMPOSER-DRAFT-lexismarkdown-D3).

### `src/protocol.lisp` and `src/packages.lisp`

`src/protocol.lisp:markdown-options@ac700d0` is the generic and its
default method (CCOMPOSER-DRAFT-lexismarkdown-D2); the package
exports it.

### `src/defaults.lisp`

`src/defaults.lisp:compose-feature-from-body@ac700d0` takes the context
as its first argument and reads Markdown string bodies
(CCOMPOSER-DRAFT-lexismarkdown-D4). It is internal, and
`compose-feature` is its only caller.

### `examples/wiki-demo.lisp`

The body conversion is replaced by `resolve-wiki-link` and a
`markdown-options` method on `wiki-page`
(CCOMPOSER-DRAFT-lexismarkdown-D6).

### Tests

`test/helpers.lisp:find-nodes@ac700d0` searches a tree for nodes by
tag name, so that tests can find nodes built from the `lexis`
package's symbols. Twelve tests are added, in `test/test-lens.lisp@ac700d0`
and `test/test-defaults.lisp@ac700d0`. They cover:

- single and multi-block Markdown, and the absence of a wrapper;
- lists, fenced code blocks and block quotes;
- a forum quote body;
- escaped raw HTML, and the removal of a `javascript:` link;
- empty text;
- the default `markdown-options`, and a specialized one with a custom
  wiki link resolver;
- `:html` list passthrough;
- splicing in `apply-lens`;
- the Markdown body fallback.


## Verification

- **Tests.** The suite was run with
  `(5am:run! 'classic.composer-tests::classic.composer)`, the root
  suite that the manifest's `:test` command,
  `(classic.composer-tests::run-all-tests)`, runs. Result: 225 checks,
  100% pass; 181 checks before the change, with no regressions. A
  forced recompile of `classic.composer` gave no warnings.
- **Demos.** All three were rerun and their output regenerated in
  `doc/demos/`:
  - **Blog post.** The body's sections lose their wrapper, and their
    headings rise from `<h4>` to `<h3>`.
  - **Forum thread.** The quoting post renders as a `<blockquote>`,
    with the attribution in `<strong>`, followed by a `<p>` reply,
    with no wrapper section.
  - **Wiki page.** Byte-for-byte the same as before, links included,
    so the resolver reproduces the old conversion.
  - **Index pages.** Change only in their dates.


## Files

Table: Files added or changed in commit `ac700d0`.

| File | Action | Description |
|------|--------|-------------|
| `classic.composer.asd` | Modified | Depends on `lexis.markdown` |
| `src/lens.lisp` | Modified | `render-markdown`, `block-list-p`, splicing in `apply-lens`; the stub and its helpers removed |
| `src/protocol.lisp` | Modified | The `markdown-options` generic and its default method |
| `src/packages.lisp` | Modified | Exports `markdown-options` |
| `src/defaults.lisp` | Modified | Markdown string bodies in `compose-feature-from-body` |
| `test/helpers.lisp` | Modified | The `find-nodes` tree search helper |
| `test/test-lens.lisp` | Modified | Markdown mode, options, passthrough list and splicing tests |
| `test/test-defaults.lisp` | Modified | The Markdown body fallback test |
| `examples/wiki-demo.lisp` | Modified | Body conversion replaced by a `markdown-options` method and resolver |
| `doc/demos/blog-post-output.html` | Modified | Regenerated: unwrapped body sections |
| `doc/demos/blog-list-output.html` | Modified | Regenerated: dates only |
| `doc/demos/forum-thread-output.html` | Modified | Regenerated: the quote as a block quote |
| `doc/demos/forum-index-output.html` | Modified | Regenerated: dates only |
| `doc/demos/wiki-index-output.html` | Modified | Regenerated: dates only |
| `README.md` | Modified | The `:markdown` mode, `markdown-options`, and the dependency |
| `doc/Composer.md` | Modified | The `:markdown` mode, block splicing, and Markdown bodies |
| `doc/DevLog.MarkdownReader.md` | **New** | The record of this work before Compass, which this Log replaces |


## Outstanding Work

- **Heading depth.** The `feature` and `aggregate-entry` wrappers still
  push headings one level deeper
  (CCOMPOSER-DRAFT-lexismarkdown-D3). This awaits a change in Lexis.
  LEXIS-O3's outcome is to be recorded in the Lexis repository with
  that change.
- **Wiki infobox.** The wiki demo still builds its infobox as an HTML
  passthrough. Lexis now implements `definition-list` and `definition`
  (LEXIS-D11), but its HTML renderer gives them no class, and the
  demo's stylesheet styles the infobox by its class.
- **Resolved since.** This work also left the wiki's link URIs
  (`/wiki/<anchor>`, with spaces) and the forum and wiki demos' other
  writes to stored data outstanding. Commit `7fa52ba` resolved both:
  the composer's extension generics replaced the writes, and each demo
  became a site of linked pages. That work is recorded in
  [DevLog.ReadOnlyDemos.md](DevLog.ReadOnlyDemos.md), not yet
  migrated.
