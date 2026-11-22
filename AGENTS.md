# Classic Composer — Agent Guide

The Classic Composer assembles Classic content for display, producing Lexis
document trees for Lexis renderers. It is a derivative project of Classic
(`../classic`). See [README.md](README.md) for an overview and
[doc/Arch.Composer.md](doc/Arch.Composer.md) for the architecture.

## Documentation — Compass

Project documentation follows **Compass** (Common Ontological Model for Prose
Artifacts by Structural Standard). Use the `compass-*` skills rather than
improvising documents:

- `compass-author` — scaffold a new document (Survey/Eval/Plan/Log/Ref/Guide/
  Spec/Arch/Glossary/Memo) with correct front-matter and per-genre section
  shape.
- `compass-review` — the toolchain's checks plus a judgment-level review before
  accepting a doc.
- `compass-lookup` — resolve identifiers, sections, records, and references.
- `compass-migrate` — bring a document written before Compass into the corpus,
  one at a time, changing only its form.

The skills carry the standard and its reference bundle. Load @Compass.md on
demand only if you need the source text — do not preload it.

Run `compass check` before finishing any change to the documentation, and fix
the errors it reports in the files you changed. `compass help` lists the other
commands (`show`, `outline`, `refs`, `index`, `next`, `rules`, and others).
Numbers are assigned with `compass assign` only when a person asks for it; never
edit the ledger, `doc/REGISTRY.sexp`, by hand. After changing documents, run
`compass index` to regenerate `doc/INDEX.md`; never edit it by hand.

Project-specific facts the skills cannot infer:

- Compass namespace: CCOMPOSER (declared in `compass.sexp`)
- Docs directory: doc/ (flat; grouping via front-matter)
- The `compass` command: `compass` on the PATH after `make install` in
  `~/src/lisp/compass`; otherwise `~/src/lisp/compass/bin/compass`
- Federated repositories: CLASSIC (`../classic`) and LEXIS (`../lexis`), as
  listed in `compass.sexp`
- Migration: recorded in `doc/Log.CompassMigration.md`
  (CCOMPOSER-DRAFT-compass-migration), which takes an `## Update` section
  for each document migrated. The one document still without front-matter
  is `Log.ReadOnlyDemos.md` in `doc/` (formerly `DevLog.ReadOnlyDemos.md`),
  which is being migrated with `compass-migrate`; until it is, checks run
  with `--skip-unmarked`. `README.md` is not a Compass document.

Essentials (full rules in Compass.md): every document opens with a §7 YAML
front-matter block; genre and status use the controlled vocabularies; decision
records are ADR-shaped (`D`-records); new documents and their records keep
provisional `<NAMESPACE>-DRAFT-<slug>` identifiers until a steward assigns
numbers; code references in Log/Plan are commit-pinned (`path:symbol@revision`),
never bare line numbers; documents authored with LLM help carry `provenance:`;
an assistant never sets `approved-by` or an authoritative status.
