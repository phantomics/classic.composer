# Markdown Reader: Development Log

This document records the replacement of the composer's placeholder
Markdown handling with the Lexis Markdown reader, `lexis.markdown`.
The `:markdown` display mode now reads a slot's text into Lexis blocks.
Applications pass options to the reader through a new generic,
`markdown-options`. A body of several blocks is spliced into the page
rather than wrapped in a section of its own. The wiki demo now keeps
its page bodies as Markdown and resolves their wiki links while the
page is composed.

**Date:** 2026-11-20


## Problem

Classic stores the bodies of articles, forum posts and wiki pages as
strings declared `:format :markdown`, so the lens display mode
cascade gives them the `:markdown` mode. That mode was a stub,
`render-markdown-stub` in `src/lens.lisp`. It split the text on
blank lines, made a paragraph of each block, and recognised one
construct, a block quote, which it added for forum quotes (see the
addendum of `DevLog.ForumRenderDemo.md`). It did not read headings,
lists, code blocks, links or wiki links.

Lexis now has a Markdown reader, the `lexis.markdown` module
(Lexis's `doc/Plan.RenderMarkdown.md`, LEXIS-0002, and
`doc/Ref.Markdown.md`). The last step of that plan's roadmap hands
the reader over to the composer: replace the stub, and supply a wiki
link resolver where wiki links name pages. The plan's open question
LEXIS-O3 also concerns the composer. The stub wrapped a body of
several blocks in an untitled `(section (@ :class "body") ...)`,
which pushes the body's own sections one level deeper when rendered.

Two demos worked around the stub:

- **Blog.** The demo stores bodies as Lexis forms and overrides the
  cascade with `:display :html`. Its list-of-sections bodies got the
  same untitled wrapper from `render-html-passthrough`.
- **Wiki.** The demo rewrote each page's body into Lexis before
  composing (`convert-wiki-body-to-lexis` and three helpers, ~80
  lines), replacing stored Markdown with Lexis forms and persisting
  the result. That is a write to Classic data, which the composer's
  read-only principle forbids.


## Design Decisions

### 1. A direct dependency on `lexis.markdown`

`classic.composer` now depends on `lexis.markdown`. This brings in
the Lexis core, `cl-ppcre` and 3bmd with four of its extension
systems. The alternative was a separate system,
`classic.composer.markdown`, in the capability-extension style
described in `Composer.md`. It was not adopted: Markdown is Classic's
default body format, so a composer without the reader would render
most content badly. The composer still depends on no renderer.

### 2. Reader options through a `markdown-options` generic

The reader takes options: a wiki link resolver, the raw HTML policy
and the allowed URI schemes. Only the application knows the right
values for its content. A wiki's resolver looks pages up with
`find-page-by-anchor`, which needs the wiki imprint, and the composer
depends on neither the content models nor the imprint.

The new exported generic `markdown-options (context entity
slot-name)` returns the keyword list passed to `markdown->lexis`. Its
default method returns `nil`, which keeps the reader's safe defaults:
raw HTML is escaped, and links keep only the `http`, `https`, `mailto`
and `classic` schemes. This follows the pattern of
`container-reading-order`: a content type declares its needs by
specializing a generic, and themes never set the options. A theme is
not the right place to switch on `:raw-html :passthrough`.

To reach the generic, `render-slot-via-display-mode` gained
`:context`, `:entity` and `:slot-name` keywords, which `apply-lens`
supplies. Callers that omit them get the default options.

### 3. Multi-block bodies are spliced, not wrapped (LEXIS-O3, in part)

The reader returns a list of blocks. A display mode may now return
such a list instead of one node (the predicate is `block-list-p`), and
`apply-lens` splices its blocks into the lens's result in property
order. `render-markdown` returns the single block when the text gives
one, the list when it gives several, and `nil` when it gives none. The
list case of `render-html-passthrough` now returns the list too, so the
blog demo's bodies lose their wrapper as well.

This settles the composer's side of LEXIS-O3 as that plan's current
thinking proposed: the composer stops wrapping. It removes one of the
two extra heading levels. The other remains: `compose-feature` wraps
lens output in `(section (@ :class "feature") ...)`, and
`compose-container-entry` wraps each entry in
`(section (@ :class "aggregate-entry") ...)`. Both are untitled
sections, and Lexis counts every section when it computes depth. A
Markdown `##` heading in a feature therefore still renders as `<h3>`,
not `<h2>`. This is accepted for now. The steward will fix it in
Lexis, for example by not counting untitled sections. Recording
LEXIS-O3's outcome in the Lexis repository is left to that work.

### 4. The body fallback reads Markdown too

Without a lens, `compose-feature-from-body` wrapped a string body in a
single paragraph. It now reads the body as Markdown when the body slot
is declared `:format :markdown`, using the same options. A string
body in any other format keeps the paragraph. The function now takes
the context as its first argument; it is internal, and
`compose-feature` is its only caller.

### 5. Resolver forms use the LEXIS package's symbols

The reader's passes run over the resolver's form as well, and they
recognise tags and the `@` attribute marker by `eq` against `lexis`
symbols. A resolver that built its form from another package's
symbols would have its attribute list treated as a child. The wiki
demo's resolver therefore builds `lexis::web-link` and `lexis::@`
forms, as the reader's reference does in its example. The composer
itself is unaffected: it compares tags by symbol name, so the reader's
`lexis::` tags mix with its own.

### 6. The wiki demo resolves links during composition

The wiki demo's body conversion is gone. The `:default` lens lists
`classic.schema:body` without `:display :html`, so the slot's
`:format :markdown` selects the Markdown mode. A `markdown-options`
method on `wiki-page` supplies a resolver. It links a found page to
`/wiki/<anchor>` and marks a missing one with
`(emphasis (@ :class "broken-link") ...)`, as the old conversion did.
The rendered page is byte-for-byte the same as before.

The composition context carries no wiki imprint, so the demo's
resolver uses the `*wiki*` global. A production wiki would find its
pages through the context's strategy or publication instead.


## Implementation

- **`src/lens.lisp`.** `render-markdown` replaces
  `render-markdown-stub`. Its helpers, `split-markdown-blocks`,
  `split-on-blank-lines`, `blockquote-chunk-p` and
  `parse-blockquote-chunk`, are deleted (none was exported or tested).
  The new `block-list-p` predicate is added, `render-html-passthrough`
  returns lists unwrapped, and `apply-lens` passes the context and
  splices block lists.
- **`src/protocol.lisp`.** The `markdown-options` generic and its
  default method.
- **`src/defaults.lisp`.** The Markdown case in
  `compose-feature-from-body`.
- **Tests.** Twelve new tests cover:
  - single and multi-block Markdown, and the absence of a wrapper;
  - lists, code blocks and block quotes;
  - a forum quote body;
  - escaped raw HTML and the removal of a `javascript:` link;
  - empty text;
  - the default and a specialized `markdown-options`, the latter with
    a custom wiki link resolver;
  - `:html` list passthrough;
  - splicing in `apply-lens`;
  - the Markdown body fallback.

  A `find-nodes` helper searches trees by tag name.


## Verification

- Test suite: 225/225 checks pass (181 before), with
  `(asdf:load-system "classic.composer/tests")` and
  `(5am:run! 'classic.composer-tests::classic.composer)`. A forced
  recompile of `classic.composer` gives no warnings.
- Demos, regenerated in `doc/demos/`. Apart from the dates:
  - **Blog post.** The body's sections lose their wrapper, and their
    headings rise from `<h4>` to `<h3>`.
  - **Forum thread.** The quoting post renders as a `<blockquote>`,
    with the attribution in `<strong>`, followed by a `<p>` reply,
    with no wrapper section.
  - **Wiki page.** Unchanged, links included.
  - **Index pages.** Change only in their dates.


## Files

| Action | File | Description |
|---|---|---|
| Modified | `classic.composer.asd` | Depends on `lexis.markdown` |
| Modified | `src/lens.lisp` | `render-markdown`, `block-list-p`, splicing in `apply-lens`; stub and helpers removed |
| Modified | `src/protocol.lisp` | `markdown-options` generic and default method |
| Modified | `src/packages.lisp` | Exported `markdown-options` |
| Modified | `src/defaults.lisp` | Markdown string bodies in `compose-feature-from-body` |
| Modified | `test/helpers.lisp` | `find-nodes` tree search helper |
| Modified | `test/test-lens.lisp` | Markdown mode, options, passthrough list and splicing tests |
| Modified | `test/test-defaults.lisp` | Markdown body fallback test |
| Modified | `examples/wiki-demo.lisp` | Body conversion replaced by a `markdown-options` method and resolver |
| Modified | `doc/demos/*.html` | Regenerated |
| Modified | `README.md`, `doc/Composer.md` | The `:markdown` mode, `markdown-options`, the dependency |
| Created | this file | |


## Outstanding Work

- **Heading depth.** The `feature` and `aggregate-entry` wrappers
  still push headings one level deeper (decision 3). This awaits a
  Lexis change, and LEXIS-O3's outcome is to be recorded in the Lexis
  repository.
- **Wiki infobox.** The demo still builds the infobox as an HTML
  passthrough, because Lexis lacked definition lists when it was
  written. Lexis now implements `definition-list` and `definition`, so
  the infobox can become plain Lexis.
- **Wiki link URIs.** Links are `/wiki/<anchor>` with the anchor's
  spaces kept, as before. A routing scheme, or `classic-link` to the
  page's URI, would replace them.
- **Other writes in the demos.** The wiki demo still resolves typed
  slots to URIs and re-sorts its container before composing. The forum
  demo still rewrites authors to nicknames and reorders its container.
