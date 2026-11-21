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
  - CCOMPOSER-DRAFT-composer
  - CCOMPOSER-DRAFT-lexismarkdown
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
[CCOMPOSER-DRAFT-composer](Arch.Composer.md). Each later document is
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
[CCOMPOSER-DRAFT-composer](Arch.Composer.md), the genre of its title
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
  - front-matter as CCOMPOSER-DRAFT-composer: genre `Architecture`,
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
  [CCOMPOSER-DRAFT-composer](Arch.Composer.md) to link to it, with the
  decision records, open questions and roadmap its notes call for.
- **Five documents still unmarked**, to be migrated one at a time, each
  recorded in an `## Update` section:
  - `doc/DevLog.ThemeResolution.md`
  - `doc/DevLog.FullRenderDemo.md`
  - `doc/DevLog.ForumRenderDemo.md`
  - `doc/DevLog.WikiRenderDemo.md`
  - `doc/DevLog.ReadOnlyDemos.md`
- **Acceptance and numbering.** Every document and record keeps its
  provisional identifier until the steward sets an accepted status and
  asks for `compass assign`.
- **Mentions by description.** CCOMPOSER-DRAFT-lexismarkdown-D1 refers
  to "the architecture document" in prose, without a link; it may link
  to CCOMPOSER-DRAFT-composer when that Log is next revised.
