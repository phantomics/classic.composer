---
id:            CCOMPOSER-DRAFT-compass-migration
title:         Compass Migration Development Log
genre:         Log
scope:         project
project:       Classic Composer
language:      en
status:        Draft
provenance:
  assistant:   claude-opus-5-5
relates-to:
  - CCOMPOSER-0001
  - CCOMPOSER-0003
  - CCOMPOSER-0004
  - CCOMPOSER-0005
  - CCOMPOSER-0006
  - CCOMPOSER-DRAFT-lexismarkdown
  - CCOMPOSER-0007
  - CLASSIC-0034
  - CLASSIC-0036
decisions:
  - CCOMPOSER-DRAFT-compass-migration-D1
  - CCOMPOSER-DRAFT-compass-migration-D2
  - CCOMPOSER-DRAFT-compass-migration-D3
  - CCOMPOSER-DRAFT-compass-migration-D4
---

# Compass Migration: Development Log

This document chronicles the migration of the Classic Composer's
documentation to the Compass standard: the repository's adoption of
Compass (commit `d226fc4`), and the migration of each document written
before it, one at a time. The migration began from commit `7ccacd3`.
The body records the adoption and the first migration, of the
architecture document into
[CCOMPOSER-0001](Arch.Composer.md). Each later document is
recorded in an `## Update` section, with its original path, its
`migrated-from` revision, its move and reshape commits, and the notes
on stale content that its migration left for the revision after it.

## Problem

Until `d226fc4`, the repository had seven documents in `doc/`, none in
Compass form: the architecture document, `Composer.md`, and six
development logs named `DevLog.*.md`. They had no front-matter, no
identifiers and no decision records, and the composer's code
references in them were bare file names. The repository had no
manifest, no ledger, no index and no `.mailmap`, so Git showed its
author as the account name `phantomics`. Its parent project, Classic,
and the Lexis project it depends on both keep their documents in
Compass, and federating with them needed this repository to be a
Compass corpus too.

## Design Decisions

The migration follows the Compass repository's migration plan,
COMPASS-0016, as the `compass-migrate` skill carries it out: one
document per request, a form-only reshape, and the move and the
reshape committed separately. The records below are the choices made
for this repository.

### CCOMPOSER-DRAFT-compass-migration-D1 — This Log is the migration's record, with no Plan of its own

**Status:** Proposed
**Context:** Six documents were still unmarked when the first migration
began, more than the three below which the standard lets the
`AGENTS.md` migration line serve as the backlog record. Classic wrote
a migration Plan, CLASSIC-0032, before migrating its twenty-six
documents written before Compass in phases, and recorded the work in a Log,
[CLASSIC-0036](../../classic/doc/Log.CompassMigration.md).
**Decision:** The repository has no migration Plan. COMPASS-0016's
decisions apply unchanged, and this Log records the migration: the
adoption and the first migration in its body, and each later document
in an `## Update` section. The `AGENTS.md` migration line names the
documents still unmarked and points here.
**Alternatives:** A Plan in the manner of CLASSIC-0032 was not written:
with six documents, migrated one at a time, the plan's decisions would
repeat COMPASS-0016's. Keeping the `AGENTS.md` line as the only record
would leave no account of each migration's commits and notes.

### CCOMPOSER-DRAFT-compass-migration-D2 — A document replaced by a native one is deleted, not migrated

**Status:** Proposed
**Context:** `DevLog.MarkdownReader.md` recorded the integration of the
Lexis Markdown reader, written in the same session as the work, a day
before the adoption. Migrating it would have kept its unpinned prose
and its numbered design decisions without alternatives.
**Decision:** The work was recorded afresh in a native Log,
[CCOMPOSER-DRAFT-lexismarkdown](Log.LexisMarkdown.md), written with
`compass-author` from the DevLog's account and pinned to the work's
commit, `ac700d0`. The DevLog was deleted, and the links to it were
pointed at the new Log. The deletion is committed in `d226fc4`; the
new Log in `06ac6bb` and its revision after review in `7ccacd3`.
**Alternatives:** Migrating the DevLog and then marking it `Superseded`
by the new Log would have kept two accounts of one piece of work in
the corpus. Migrating it alone, without a new Log, would have kept
decisions whose alternatives were never recorded.

### CCOMPOSER-DRAFT-compass-migration-D3 — The architecture document becomes an Architecture now and a Ref is split from it afterwards

**Status:** Proposed
**Context:** `Composer.md` mixes two genres. About half of it describes
code that runs: theme integration, lens composition, the Markdown
mode and the extension generics, which read as a `Ref`. The rest is
design not yet built: the capability extension systems, the operative
tier and Seed, complex templates, distribution and a future
`classic.composer.dist.beta`, which read as an `Architecture`. A
migration changes only a document's form and never splits it.
**Decision:** `Composer.md` is migrated whole, as the Architecture
[CCOMPOSER-0001](Arch.Composer.md), the genre of its title
and its overview role. After the reshape, a `Ref.Composer.md` is
written with `compass-author`, carrying the running-code sections and
`provenance.migrated-from` naming the same original, and the
Architecture is revised to link to it in their place. This is the path
the standard gives a document split from a migrated original.
**Alternatives:** Writing the Ref first and migrating the remainder was
not adopted: the migrated Architecture would lack text its original
has, which a form-only migration forbids, or would hold the Ref's text
twice until a later edit. Migrating it as a Ref was not adopted: its
unbuilt design has no place in a Ref, which describes running code.

### CCOMPOSER-DRAFT-compass-migration-D4 — Decision records are not extracted from prose during a reshape

**Status:** Proposed
**Context:** `Composer.md` has no decision records, but its prose states
several decisions with their reasons: the composer is read-only; the
tiers are defined by structural role rather than domain; capability
extensions only add; the composer places controls and Seed implements
them; and the `classic.schema` nickname keeps the source independent
of one schema. The Architecture spine has a Settled Decisions section.
**Decision:** The reshape writes "Not recorded in the original." in
Settled Decisions, and lists the candidates in this Log. They become
records in the content revision that follows the Ref split, where
their alternatives can be recorded as well.
**Alternatives:** Extracting them during the reshape, filled only with
the original's sentences, was not adopted: it would move sentences out
of the design sections, a heavier change to the form, and every
record's Alternatives would read "Not recorded in the original."

## Implementation

### Adoption (`d226fc4`)

Compass was adopted with the `compass-adopt` skill and the toolchain,
version 0.2.0:

- `.mailmap` maps the Git identity `phantomics <andrew@foldspace.tech>`
  to `Andrew Sengul`, as Classic's and Lexis's do.
- `compass.sexp`, written by `compass init`, declares the namespace
  CCOMPOSER, the document directory `doc/`, the steward Andrew Sengul
  with solo approval, and federation with CLASSIC (`../classic`) and
  LEXIS (`../lexis`). A `:test` command was added by hand.
- `doc/REGISTRY.sexp`, the ledger, was created empty by
  `compass init --ledger`: no document had a number.
- `AGENTS.md` holds the Compass block, with the repository's facts and
  a migration line.

The commit also deletes `DevLog.MarkdownReader.md`
(CCOMPOSER-DRAFT-compass-migration-D2).

### The native Lexis Markdown Log (`06ac6bb`, `7ccacd3`)

[CCOMPOSER-DRAFT-lexismarkdown](Log.LexisMarkdown.md) was written with
`compass-author` and reviewed with `compass-review`. The review's two
warnings were fixed in `7ccacd3`: one decision diverged from LEXIS-D10
without saying so, and another recorded a constraint rather than a
choice, so it became a note in Implementation. `doc/INDEX.md` was first
generated in `06ac6bb`.

### `doc/Composer.md` to `doc/Arch.Composer.md`

- **Original:** `doc/Composer.md`, at `migrated-from` revision
  `7fa52ba`, the last commit that changed it.
- **Move** (`3249062`): `git mv` to `doc/Arch.Composer.md`, with the
  link in `AGENTS.md`, the `AGENTS.md` migration line and the
  `README.md` structure listing updated. The Files tables of three
  Logs that name `doc/Composer.md` were left as history.
- **Reshape** (`139e180`), form only:
  - front-matter as CCOMPOSER-0001: genre `Architecture`,
    scope `project`, status `Draft`, and `provenance` naming the
    original's assistant, claude-opus-4-6;
  - the H1 in the Architecture form; "Overview" renamed `Thesis`;
  - Canonical Terms and Influences point to the sections that give
    them; Settled Decisions, Open Questions and Roadmap read "Not
    recorded in the original." (CCOMPOSER-DRAFT-compass-migration-D4);
  - `Table:` captions on four tables and `Description:` paragraphs
    after three diagrams.

  The ten design sections kept their order, and their tier numbers,
  which the text cites. The original names no file with a symbol, so
  there were no code references to pin. As in
  [CLASSIC-0034](../../classic/doc/persistence/Arch.PersistenceBackends.md),
  the spine's Appendices section is omitted, and `Thesis` stands for
  "Thesis / Concerns".
- **Dates:** Git dates the document from the repository's first
  commit, `f5a0560` (2026-05-25), through the rename. There is no
  earlier evidence, so `created` is left to Git.
- **Notes on stale content,** for the content revision:
  - Not built: the seven capability extension systems (the repository
    defines only `classic.composer` and `classic.composer.dist.alpha`);
    complex templates; the operative tier
    (`src/defaults.lisp:compose-operative@139e180` returns `nil`);
    Seed integration; distribution; and `classic.composer.dist.beta`.
  - "In a forum context, all posts in a thread are feature content"
    contradicts the forum demo, which composes a thread page with the
    thread as a container, through the aggregate tier
    (`examples/forum-demo.lisp:render-thread-page@139e180`).
  - The decision candidates of CCOMPOSER-DRAFT-compass-migration-D4.
  - The mix of genres, to be resolved by the Ref split
    (CCOMPOSER-DRAFT-compass-migration-D3).

## Verification

Each step was checked with the Compass toolchain, version 0.2.0
(`~/src/lisp/compass/bin/compass`):

- **Adoption.** `compass manifest --json` showed the manifest as
  intended; `compass check --skip-unmarked` and
  `compass check --skip-unmarked --federation` reported 0 errors and 0
  warnings, with 7 files skipped.
- **The Lexis Markdown Log.** `compass check --skip-unmarked
  --federation` reported 0 errors and 0 warnings, with every reference
  into CLASSIC and LEXIS verified.
- **The move.** `compass check --skip-unmarked` reported 0 errors and 0
  warnings.
- **The reshape.** `compass check --skip-unmarked --federation`
  reported 0 errors and 0 warnings over the corpus, with
  `ref/migrated-from` silent, so the original's path and revision
  resolve. `compass index --check` reported the index current. A
  word diff against the original showed only the "Overview" heading
  removed, and every addition was front-matter, a heading, a pointer,
  "Not recorded in the original.", a caption or a description.

## Files

Table: Files added, changed, moved or deleted by the migration, in commits `d226fc4` to `139e180`.

| File | Action | Description |
|------|--------|-------------|
| `.mailmap` | **New** | The canonical name for the repository's Git identity |
| `compass.sexp` | **New** | The Compass manifest |
| `doc/REGISTRY.sexp` | **New** | The ledger, empty |
| `AGENTS.md` | **New** | The agent guide, with the Compass block and migration line |
| `doc/DevLog.MarkdownReader.md` | Deleted | Replaced by `doc/Log.LexisMarkdown.md` |
| `doc/Log.LexisMarkdown.md` | **New** | The native Log of the Lexis Markdown integration |
| `doc/INDEX.md` | **New** | The generated index |
| `doc/Composer.md` | Moved | To `doc/Arch.Composer.md`, then reshaped |
| `README.md` | Modified | Structure listing: the new and renamed documents |
| `doc/DevLog.ReadOnlyDemos.md` | Modified | Two links pointed at `doc/Log.LexisMarkdown.md` |

## Outstanding Work

- **The Ref split** (CCOMPOSER-DRAFT-compass-migration-D3): write
  `Ref.Composer.md`, and revise
  [CCOMPOSER-0001](Arch.Composer.md) to link to it, with the
  decision records, open questions and roadmap its notes call for.
- **Five documents still unmarked**, to be migrated one at a time, each
  recorded in an `## Update` section:
  - `doc/DevLog.ThemeResolution.md` (now `doc/Log.ThemeResolution.md`)
  - `doc/DevLog.FullRenderDemo.md` (now `doc/Log.FullRenderDemo.md`)
  - `doc/DevLog.ForumRenderDemo.md` (now `doc/Log.ForumRenderDemo.md`)
  - `doc/DevLog.WikiRenderDemo.md` (now `doc/Log.WikiRenderDemo.md`)
  - `doc/DevLog.ReadOnlyDemos.md` (now `doc/Log.ReadOnlyDemos.md`)
- **Acceptance and numbering.** Every document and record keeps its
  provisional identifier until the steward sets an accepted status and
  asks for `compass assign`.
- **Mentions by description.** CCOMPOSER-DRAFT-lexismarkdown-D1 refers
  to "the architecture document" in prose, without a link; it may link
  to CCOMPOSER-0001 when that Log is next revised.

## Update 2026-11-21 — The Ref split and the Architecture's revision

This installment completes the migration of the architecture document
(CCOMPOSER-DRAFT-compass-migration-D3): the running-code sections were
split into a Ref, and the Architecture was revised to link to it.

### The Ref (`46d0707`)

[CCOMPOSER-0002](Ref.Composer.md) was written with
`compass-author`, with `api-version` "0.2.0" and
`provenance.migrated-from` naming the same original as the
Architecture, `doc/Composer.md@7fa52ba`. It carries the original's
Theme Integration, Lens-Driven Feature Composition, Extension Generics,
and its simple templates, anchors and collect phase, checked against
the code and pinned to `7fa52ba`, the last commit to change `src/`. It
adds a Composition Pipeline section and a Project Structure. Checking
the original's claims against the code corrected four:

- the theme's capability set does not decide dispatch: `compose-page`
  validates it, and no default tier method calls `dispatch-capability`;
- an anchor's fallback is used only when no handler is registered, and
  a warning is signalled then;
- lenses serve container entries and sublenses as well as the feature
  tier;
- the composer registers no collectors or anchor handlers of its own.

### The Architecture's revision

[CCOMPOSER-0001](Arch.Composer.md) was revised as an ordinary
edit, committed with this Update:

- an abstract, and a Canonical Terms table in place of the pointer;
- Influences: Fresnel, Scribble, Seed, and WordPress shortcodes as the
  counterexample, with the outside sources in `cites:`;
- the Thesis cites CLASSIC-D29, which put the theme ontology in
  Classic and rendering in the composer;
- six decision records: the five candidates the reshape listed
  (CCOMPOSER-DRAFT-compass-migration-D4), and a sixth, composition as
  a fixed sequence of single passes, from the original's workflow and
  the README's account of it, each with its alternatives;
- the running-code sections reduced to summaries linking to the Ref;
- the unbuilt parts marked as such, with five open questions:
  capability dispatch, complex templates, the operative spec and Seed,
  distribution, and the heading level the wrapper sections add;
- a Roadmap ordered by those questions;
- the forum claim reconciled with the forum demo: a thread's posts are
  feature content, which a thread page presents as an aggregate, as
  [CCOMPOSER-0005](Log.ForumRenderDemo.md) records.

`compass check --skip-unmarked --federation` reported 0 errors and 0
warnings over the corpus, with every reference verified, and
`compass index --check` the index current.

With this installment, the Ref split of Outstanding Work is done. The
Architecture and the Ref remain `Draft`, and their records `Proposed`,
until the steward sets their statuses.

A `compass-review` of both documents followed, and its fixes were
committed after `3a95f57`, the commit the release tag `v0.2.0` marks:

- the Ref's code references were repinned from `7fa52ba` to `v0.2.0`,
  which holds the same `src/`;
- the Ref describes `dispatch-capability` as the code behaves: each
  accepting capability in turn, most recently registered first, until
  one returns content;
- the Architecture's account of WordPress shortcodes was corrected
  against the cited documentation, which describes a single-pass
  parser whose handlers may expand nested shortcodes themselves, and
  the citation's locator updated;
- CCOMPOSER-D3 notes that capabilities conflict when two
  accept the same node, a question added to
  CCOMPOSER-O1;
- CCOMPOSER-D6 limits its linear-cost claim to the
  framework's passes, and a sixth open question,
  CCOMPOSER-O6, asks how sublens cycles are bounded,
  first on the Roadmap.

## Update 2026-11-21 — doc/DevLog.ThemeResolution.md

The second migration: the log of the theme resolution work, migrated
whole as the Log
[CCOMPOSER-0003](Log.ThemeResolution.md).

- **Original:** `doc/DevLog.ThemeResolution.md`, at `migrated-from`
  revision `3e9068e`, the only commit to touch it, which is also the
  commit of the work it records.
- **Move** (`5929753`): `git mv` to `doc/Log.ThemeResolution.md`, with
  the `README.md` structure listing and the `AGENTS.md` migration line
  updated. This Log's own backlog list keeps the old path, as history,
  with the new path noted after it.
- **Reshape** (`a44422f`), form only:
  - front-matter as CCOMPOSER-0003: genre `Log`, scope
    `component`, component `theme`, status `Draft`, `provenance` naming
    the original's assistant, claude-opus-4-6, and `relates-to`
    CCOMPOSER-0001, the document the original names as
    `doc/Composer.md`;
  - the twelve numbered decisions as records `-D1` to `-D12`, keeping
    their numbers and titles. Each original "Question" became the
    record's Context. Alternatives point to the Context where the
    question names the rejected option
    (CCOMPOSER-D7,
    CCOMPOSER-D9,
    CCOMPOSER-D10 and
    CCOMPOSER-D14), to the Decision where it does
    (CCOMPOSER-D15), and read "Not recorded in
    the original." for the other seven;
  - 27 symbols and 8 file headings in Implementation pinned to the
    work's commit, `3e9068e`; the Files table's paths left as history,
    and `doc/Composer.md` noted as now `doc/Arch.Composer.md`;
  - a Verification section pointing to Outstanding Work, which says no
    test suite existed;
  - a `Table:` caption on the Files table, its columns put in the
    spine's order.

  The original's background section on the dist factorization, and
  its Design Properties Preserved and Metrics sections, stay where
  they were. Its date line, 2026-06-05, matches Git's, so `created` is
  left to Git.
- **Check:** `compass check --skip-unmarked --federation` reported 0
  errors and 0 warnings over the corpus; a word diff against the
  original removed only the decision numbers, kept in the identifiers,
  the "Question" labels, the bold of "Decision: Eager.", bare symbol
  names, reappearing in their pins, and table cells, moved between
  columns.
- **Notes on stale content,** for a revision:
  - CCOMPOSER-D10, the theme's capabilities as the
    activation set for dispatch, was never built: no tier method calls
    `src/capability.lisp:dispatch-capability@a44422f`, as
    CCOMPOSER-0001 records in its open question on capability
    dispatch.
  - CCOMPOSER-D14, the stubbed Markdown mode, was
    replaced by the Lexis Markdown reader
    (`src/lens.lisp:render-markdown@a44422f`), as
    [CCOMPOSER-DRAFT-lexismarkdown](Log.LexisMarkdown.md) records.
  - Design Properties Preserved says sublens recursion is bounded by
    the depth of the relationship graph, but
    `src/lens.lisp:apply-sublens@a44422f` follows lenses that refer to
    each other without end, as CCOMPOSER-0001 records in its open
    question on sublens cycles.
  - Outstanding Work is partly done since: a test suite was added in
    `ce26e78`, the Markdown mode is real, and assets reach the HTML
    renderer as passthrough nodes
    (`src/theme.lisp:theme-asset-list@a44422f`). Capability dispatch
    and cross-reference resolution remain.
  - The file sizes are approximate: "~180 lines" for `src/theme.lisp`,
    which had 214 lines at `3e9068e`.
  - The Lexis specification ("Section 7.3") and Classic's theme
    ontology are mentioned without links; they are LEXIS-0001, and
    CLASSIC-0010 and CLASSIC-0011.

Four documents remain unmarked: `doc/DevLog.FullRenderDemo.md` (now
`doc/Log.FullRenderDemo.md`), `doc/DevLog.ForumRenderDemo.md` (now
`doc/Log.ForumRenderDemo.md`), `doc/DevLog.WikiRenderDemo.md` (now
`doc/Log.WikiRenderDemo.md`) and `doc/DevLog.ReadOnlyDemos.md` (now
`doc/Log.ReadOnlyDemos.md`).

## Update 2026-11-21 — doc/DevLog.FullRenderDemo.md

The third migration: the log of the first end-to-end render demo,
migrated whole as the Log
[CCOMPOSER-0004](Log.FullRenderDemo.md).

- **Original:** `doc/DevLog.FullRenderDemo.md`, at `migrated-from`
  revision `0f8183f`, the only commit to touch it, which is also the
  commit of the work it records.
- **Move** (`446f2ef`): `git mv` to `doc/Log.FullRenderDemo.md`, with
  the `README.md` structure listing and the `AGENTS.md` migration line
  updated, and the two mentions of the old path in this Log, both
  history, given the new path after them.
- **Reshape** (`3eba656`), form only:
  - front-matter as CCOMPOSER-0004: genre `Log`, scope
    `component`, component `demo`, status `Draft`, and `provenance`
    naming the original's assistant, claude-opus-4-6;
  - `created: 2026-06-05`, from the document's own date line. Git dates
    it from `0f8183f`, committed at 00:05 on 2026-06-06, six minutes
    after the day the date line names;
  - the nine numbered decisions as records `-D1` to `-D9`, keeping
    their numbers and titles, each "Question" as the record's Context.
    CCOMPOSER-D19's Alternatives point to the
    background section on Lexis passthrough, which says what the
    composer would have done without it. Those of
    CCOMPOSER-D20,
    CCOMPOSER-D21,
    CCOMPOSER-D23,
    CCOMPOSER-D24 and
    CCOMPOSER-D26 point to the Decision, whose text
    names the option rejected; that of
    CCOMPOSER-D27 points to the Context. The other
    two read "Not recorded in the original.";
  - 5 file headings and 16 symbol references in Implementation pinned
    to the work's commit, `0f8183f`. Symbols named only in headings or
    code blocks, a test the work renamed away, and the output paths
    were left as they were;
  - a `Table:` caption on the Files table, its columns put in the
    spine's order.

  The original's background section on Lexis passthrough, and its
  Design Properties Preserved, Issues Encountered and Metrics sections,
  stay where they were; it already had a Verification section.
- **Check:** `compass check --skip-unmarked --federation` reported 0
  errors and 0 warnings over the corpus; a word diff against the
  original removed only the decision numbers, kept in the identifiers,
  the "Question" labels, bare names, reappearing in their pins, and
  table cells, moved between columns.
- **Notes on stale content,** for a revision:
  - CCOMPOSER-D25, wrapping a list of body sections
    in an untitled section, was replaced by splicing in `ac700d0`
    (`src/lens.lisp:render-html-passthrough@3eba656`), as
    CCOMPOSER-DRAFT-lexismarkdown-D3 records.
  - The Files table and Verification name
    `doc/demos/blog-post-output.html` and
    `doc/demos/blog-list-output.html` as created by the work, but
    `0f8183f` does not hold them: they were first committed in
    `ad3fe3c`, and replaced by the pages in `doc/demos/blog/` in
    `7fa52ba`.
  - Outstanding Work names a `:placement` attribute as the hook for
    putting assets in `<head>`, where
    CCOMPOSER-D19 says the composer emits `:kind`.
    The Markdown mode it lists as stubbed is real, child themes are
    exercised by the wiki demo, and the blog model's `write-post` is
    now `write-article`; asset placement in `<head>` is still open, on
    Lexis's side.
  - The default container walk has changed:
    `src/defaults.lisp:compose-container-entry@3eba656` takes an entity,
    and the entries come from
    `src/defaults.lisp:container-entries@3eba656`, since `7fa52ba`.
  - "Lexis spec Section 5.4" names LEXIS-0001 without a link.

Three documents remain unmarked: `doc/DevLog.ForumRenderDemo.md` (now
`doc/Log.ForumRenderDemo.md`), `doc/DevLog.WikiRenderDemo.md` (now
`doc/Log.WikiRenderDemo.md`) and `doc/DevLog.ReadOnlyDemos.md` (now
`doc/Log.ReadOnlyDemos.md`).

## Update 2026-11-21 — doc/DevLog.ForumRenderDemo.md

The fourth migration: the log of the forum render demo, migrated whole
as the Log [CCOMPOSER-0005](Log.ForumRenderDemo.md).

- **Original:** `doc/DevLog.ForumRenderDemo.md`, at `migrated-from`
  revision `ad3fe3c`, the only commit to touch it, which is also the
  commit of the work it records, including the fixes its addendum
  describes.
- **Move** (`48eb93d`): `git mv` to `doc/Log.ForumRenderDemo.md`, with
  the `README.md` structure listing and the `AGENTS.md` migration line
  updated. The link to it in this Log's Update on the Architecture's
  revision was pointed at the new path, and after the reshape given
  the document's identifier as its text; the three mentions in this
  Log that record history were given the new path after them. The
  unmigrated `doc/DevLog.ReadOnlyDemos.md` (now `doc/Log.ReadOnlyDemos.md`)
  names it by file name, and
  that name was updated too.
- **Reshape** (`4c8012a`), form only:
  - front-matter as CCOMPOSER-0005: genre `Log`, scope
    `component`, component `demo`, status `Draft`, and `provenance`
    naming the original's assistant, claude-opus-4-6;
  - the five numbered decisions, written as prose without field
    labels, as records `-D1` to `-D5`, keeping their numbers and
    titles. Each record's sentences were divided among its fields in
    their original order: the opening sentences that state the
    situation became the Context, for
    CCOMPOSER-D29 and
    CCOMPOSER-D30; CCOMPOSER-D28's
    Context points to the Problem's question; and the Context of the
    other two reads "Not recorded in the original." The Alternatives of
    CCOMPOSER-D29,
    CCOMPOSER-D31 and
    CCOMPOSER-D32 point to the Decision, which
    names the other option; the other two read "Not recorded in the
    original.";
  - an Implementation section pointing to the original's "What Was
    Required" and "Blog Demo API Update", which stay where they were,
    the first as background before the decisions, and an Outstanding
    Work section reading "Not recorded in the original.";
  - the demo file and stylesheet paths, and the demo's five entry
    points, pinned to the work's commit, `ad3fe3c`;
  - `Table:` captions on the four tables, and the three Files tables'
    columns put in the spine's order.

  The original's "Addendum: Post Ordering and Index Stability" keeps
  its heading as written, rather than the spine's dated `## Update`
  form, since the addendum gives no date of its own. Its date line,
  2026-06-21, matches Git's, so `created` is left to Git.
- **Check:** `compass check --skip-unmarked --federation` reported 0
  errors and 0 warnings over the corpus; a word diff against the
  original removed only the decision numbers, kept in the identifiers,
  bare names, reappearing in their pins, and table cells, moved between
  columns.
- **Notes on stale content,** for a revision:
  - The addendum's workarounds were replaced by read-only composition
    in `7fa52ba`: Bug D's rewriting of post authors to nicknames, by a
    computed property (`examples/forum-demo.lisp:lens-property-value@4c8012a`),
    and the reordering of the forum's container, which the body
    describes, by a method that orders the entries for display
    (`examples/forum-demo.lisp:container-entries@4c8012a`). The demo no
    longer uses `ordered-threads`, the subject of
    CCOMPOSER-D29.
  - The Markdown stub of CCOMPOSER-D31 and Bug C
    was replaced by the Lexis reader
    (`src/lens.lisp:render-markdown@4c8012a`) in `ac700d0`.
  - "No production code changes to the composer" describes the demo as
    first built: the addendum's fixes, in the same commit, changed
    `src/protocol.lisp`, `src/defaults.lisp`, `src/packages.lisp` and
    `src/lens.lisp`.
  - The addendum opens "Two bugs were found and fixed" and describes
    four; the demo is "~220 lines" in one place and "~250 lines" in the
    Files table, and had 301.
  - The output paths it names were replaced by the pages in
    `doc/demos/forum/` in `7fa52ba`.
  - Classic's forum preset is described without links to its
    documents, CLASSIC-0019 and CLASSIC-0020.

Two documents remain unmarked: `doc/DevLog.WikiRenderDemo.md` (now
`doc/Log.WikiRenderDemo.md`) and `doc/DevLog.ReadOnlyDemos.md` (now
`doc/Log.ReadOnlyDemos.md`).

## Update 2026-11-21 — doc/DevLog.WikiRenderDemo.md

The fifth migration: the log of the wiki render demo, migrated whole as
the Log [CCOMPOSER-0006](Log.WikiRenderDemo.md).

- **Original:** `doc/DevLog.WikiRenderDemo.md`, at `migrated-from`
  revision `b9ad8c1`, the only commit to touch it, which is also the
  commit of the work it records.
- **Move** (`35c6b84`): `git mv` to `doc/Log.WikiRenderDemo.md`, with
  the `README.md` structure listing and the `AGENTS.md` migration line
  updated, and the four mentions of the old path in this Log, all
  history, given the new path after them.
- **Reshape** (`3ab78a0`), form only:
  - front-matter as CCOMPOSER-0006: genre `Log`, scope
    `component`, component `demo`, status `Draft`, and `provenance`
    naming the original's assistant, claude-opus-4-6;
  - the eight numbered decisions, written as prose, as records `-D1`
    to `-D8`, keeping their numbers and titles, with each record's
    sentences divided among its fields in their original order, as for
    CCOMPOSER-0005. Three records whose motivation the Problem's list
    gives point their Context to it: CCOMPOSER-D33,
    CCOMPOSER-D34 and
    CCOMPOSER-D38. Four take their opening
    sentences as Context. Two records end in a paragraph giving the
    alternative, which became their Alternatives field unchanged:
    CCOMPOSER-D34 and
    CCOMPOSER-D35;
  - the demo file and stylesheet paths, and the nine demo functions
    Implementation names, pinned to the work's commit, `b9ad8c1`;
  - `Table:` captions on the two tables, the Files table's columns put
    in the spine's order;
  - an Outstanding Work section, which the original lacked, reading
    "Deferred; see CCOMPOSER-D35 and
    CCOMPOSER-D37.", the two records that name
    work deferred to a production wiki and to Lexis.

  The original's "What This Exercises for the First Time" and
  "Pitfall" sections stay where they were, between Implementation and
  Verification. Its date line, 2026-06-22, matches Git's, so `created`
  is left to Git.
- **Check:** `compass check --skip-unmarked --federation` reported 0
  errors and 0 warnings over the corpus; a word diff against the
  original removed only the decision numbers, kept in the identifiers,
  bare names, reappearing in their pins, table cells, moved between
  columns, and the lines that a field label now opens.
- **Notes on stale content,** for a revision:
  - The demo's three writes to stored data were replaced:
    CCOMPOSER-D35's conversion of bodies to Lexis,
    by the Markdown reader and a wiki link resolver
    (`examples/wiki-demo.lisp:markdown-options@3ab78a0`), in `ac700d0`;
    CCOMPOSER-D36's rewriting of typed slots to
    URIs, by anchor lookup while composing
    (`examples/wiki-demo.lisp:resolve-reference@3ab78a0`), and
    CCOMPOSER-D39's sorting of the container, by
    an aggregate lens in the theme
    (`src/defaults.lisp:sort-entities@3ab78a0`), both in `7fa52ba`.
  - CCOMPOSER-D37 awaits a definition list in
    Lexis's HTML renderer. Lexis now implements `definition-list`
    (LEXIS-D11), but its renderer gives the element no class, which
    the demo's stylesheet styles the infobox by, so the passthrough
    remains (`examples/wiki-demo.lisp:render-infobox@3ab78a0`).
  - The output paths it names were replaced by the pages in
    `doc/demos/wiki/` in `7fa52ba`, and the demo now renders every
    page, not the Amiga 1000 alone.
  - "Lexis spec (Section 4.3)" names LEXIS-0001, and "Classic core's
    REPL demo" the Wiki Preset Guide, CLASSIC-0021, without links.

One document remains unmarked: `doc/DevLog.ReadOnlyDemos.md` (now
`doc/Log.ReadOnlyDemos.md`).

## Update 2026-11-21 — doc/DevLog.ReadOnlyDemos.md, and the migration's close

The sixth and last migration: the log of the read-only demos and page
links, migrated whole as the Log
[CCOMPOSER-0007](Log.ReadOnlyDemos.md). With it, every
document in `doc/` is in Compass form, and the migration is complete.

- **Original:** `doc/DevLog.ReadOnlyDemos.md`, at `migrated-from`
  revision `06ac6bb`, the last commit to change it up to `7ccacd3`, the
  commit this migration began from. It was written in `7fa52ba`, the
  commit of the work it records; `06ac6bb` pointed two of its links at
  [CCOMPOSER-DRAFT-lexismarkdown](Log.LexisMarkdown.md) when that Log
  replaced `DevLog.MarkdownReader.md`. The later change of a file name
  in it, made by the forum Log's move (`48eb93d`), is a migration move
  and does not count.
- **Move** (`b79c32b`): `git mv` to `doc/Log.ReadOnlyDemos.md`, with the
  `README.md` structure listing and the `AGENTS.md` migration line
  updated, the links to it in [CCOMPOSER-0001](Arch.Composer.md) and
  CCOMPOSER-DRAFT-lexismarkdown pointed at the new path, and the six
  mentions of the old path in this Log that record history given the
  new path after them.
- **Reshape** (`348b048`), form only:
  - front-matter as CCOMPOSER-0007: genre `Log`, scope
    `component`, component `demo`, status `Draft`, `provenance` naming
    the original's assistant, claude-opus-5-5, which wrote it in the
    session that carried out this migration, and `relates-to` the three
    documents it names;
  - the six numbered decisions, written as prose, as records `-D1` to
    `-D6`, each record's sentences divided among its fields in their
    original order. CCOMPOSER-D41's paragraph
    naming the alternative it rejected became its Alternatives field,
    and its last paragraph stays after the fields, as explanatory text;
  - its links to documents of the corpus given their identifiers as
    their text, and the file name of the forum Log, in the Problem's
    table, made a link with its identifier;
  - the generics its first decision lists, and the file paths and
    symbols its Implementation names, pinned to the work's commit,
    `7fa52ba`;
  - `Table:` captions on its two tables, the Files table's columns put
    in the spine's order.

  Its sections already followed the spine, so none was added or moved.
  Its date line, 2026-11-20, matches Git's, so `created` is left to
  Git.
- **After the reshape:** the links to it in CCOMPOSER-0001 and
  CCOMPOSER-DRAFT-lexismarkdown were given its identifier as their
  text, and it was added to their `relates-to` and to this Log's. The
  Lexis Markdown Log's phrase "not yet migrated", true when it was
  written, was left as it was.
- **Check:** `compass check --federation`, now without
  `--skip-unmarked`, reported 0 errors and 0 warnings over 9 documents,
  with none skipped; a word diff against the original removed only the
  decision numbers, kept in the identifiers, bare names, reappearing in
  their pins, table cells, moved between columns, link texts, now
  identifiers, and the lines that a field label now opens.
- **Notes on stale content:** none. The document is recent, and the
  four items of its Outstanding Work all remain open: the blog demo's
  setup still writes Lexis bodies after storing a placeholder
  (`examples/blog-demo.lisp:setup-blog@348b048`), the wiki demo's
  anchor lookups still go through a global
  (`examples/wiki-demo.lisp:resolve-reference@348b048`), the forum
  views it lists are not yet shown, and heading depth and the wiki
  infobox wait on Lexis.

### The migration in sum

Table: The documents written before Compass, what each became, and the commits that moved and reshaped it.

| Original | Document | Move | Reshape | Note |
|---|---|---|---|---|
| `doc/DevLog.MarkdownReader.md` | [CCOMPOSER-DRAFT-lexismarkdown](Log.LexisMarkdown.md) | — | — | Replaced by a native Log (`06ac6bb`) and deleted (`d226fc4`) |
| `doc/Composer.md` | [CCOMPOSER-0001](Arch.Composer.md) | `3249062` | `139e180` | Split: [CCOMPOSER-0002](Ref.Composer.md) (`46d0707`), and the Architecture revised (`3a95f57`) |
| `doc/DevLog.ThemeResolution.md` | [CCOMPOSER-0003](Log.ThemeResolution.md) | `5929753` | `a44422f` | |
| `doc/DevLog.FullRenderDemo.md` | [CCOMPOSER-0004](Log.FullRenderDemo.md) | `446f2ef` | `3eba656` | `created` written from its date line |
| `doc/DevLog.ForumRenderDemo.md` | [CCOMPOSER-0005](Log.ForumRenderDemo.md) | `48eb93d` | `4c8012a` | Prose decisions split into fields |
| `doc/DevLog.WikiRenderDemo.md` | [CCOMPOSER-0006](Log.WikiRenderDemo.md) | `35c6b84` | `3ab78a0` | Outstanding Work points to deferred records |
| `doc/DevLog.ReadOnlyDemos.md` | [CCOMPOSER-0007](Log.ReadOnlyDemos.md) | `b79c32b` | `348b048` | Written in the migrating session |

Each migration changed only its document's form; the notes on stale
content in each Update are for the revisions that follow. With no
document left unmarked, the `AGENTS.md` migration line no longer lists
a backlog, and checks run without `--skip-unmarked`.

What remains is not migration:

- **Acceptance and numbering** of CCOMPOSER-0007, of
  CCOMPOSER-DRAFT-lexismarkdown, and of this Log, which the steward
  accepts with the migration complete.
- **Content revisions** that the Updates' notes call for, in the
  migrated Logs, such as links to LEXIS-0001 and to Classic's theme,
  forum and wiki documents where the originals name them only in
  prose.
- **Mentions by description,** as in the body's Outstanding Work.
