# Theme Resolution: Development Log

This document chronicles the design decisions and implementation of
the Classic Composer's theme resolution system. The work connects
Classic core's theme ontology (classes, chain resolution, lenses,
slot-fills, capability exclusion) to the composer's composition
pipeline, enabling theme-driven page assembly with lens-based entity
rendering, structural extension via slot-fills, and per-tier template
selection.

**Date:** 2026-06-05


## Problem

The Classic Composer existed as a working composition pipeline with
five content tiers (frame, feature, adjunct, aggregate, operative),
template slot resolution, anchor handlers, a collect phase, and a
capability registry. It could compose pages from entities and
templates. What it could not do was consume the theme ontology that
Classic core had built.

Classic core's theme system, completed across May--June 2026,
defined:

- `classic-theme` with parent-child inheritance, capabilities
  (with exclusion), tier templates, asset manifests, configuration
  bindings, slot-fills, and Fresnel-inspired lenses
- `classic-theme-override` for per-tier template replacement
- `classic-theme-bindings` for modular configuration overlays
- Resolution helpers: `resolve-theme-chain`,
  `resolve-theme-capabilities`, `resolve-theme-overrides`,
  `resolve-theme-bindings`, `resolve-theme-slot-fills`,
  `resolve-theme-lenses`, `find-lens`

None of this was wired into the composer. The `composition-context`
had a `theme` slot that held an opaque value. Tier methods used
hardcoded defaults. Feature composition extracted the entity's body
directly, with no property-level control. There was no mechanism to:

1. Resolve a theme chain and populate the context with merged state
2. Select tier templates from the theme (with override cascade)
3. Activate capabilities based on the theme's declaration
4. Use lenses to determine which entity properties to render and how
5. Apply slot-fills from child themes to parent frame templates
6. Collect asset references for downstream renderers
7. Validate that required capabilities are registered

The composer was functional but theme-blind.


## Concurrent Architectural Change: The Dist Factorization

This work coincided with Classic core's dist factorization, which
reorganized the framework into four layers:

- **Foundation (`classic`):** protocols, MOP, URI scheme
- **Schema (`classic.schema.alpha`):** ontological classes
- **Engine (`classic.engine.ref`):** runtime method implementations
- **Distribution (`classic.dist.alpha`):** meta-system for end users

The factorization introduced a package nickname mechanism: the alpha
schema declares `(:nicknames #:classic.schema)`, and engine code
references schema symbols through `classic.schema:symbol-name`. A
future beta schema declares the same nickname; the same engine source
compiles against it without modification.

The composer had to adopt the same convention. All schema references
that were previously `classic:label`, `classic:body`,
`classic:headline`, `classic:classic-article`, etc. needed to become
`classic.schema:label`, `classic.schema:body`, and so on. Foundation
symbols (persistence protocol, MOP annotations) remained accessible
as bare symbols via `:use #:classic` inheritance.

This was not a refactoring afterthought -- it was a prerequisite.
The composer could not depend on `classic.schema.alpha` and reference
schema symbols correctly until the nickname convention was adopted.


## Design Decisions

### 1. Eager theme resolution at context creation

**Question:** Should the theme chain be resolved lazily (on first
access by a tier method) or eagerly (at context creation time)?

**Decision: Eager.** `make-context` resolves the full chain when a
theme is available. Rationale:

- Theme resolution queries the persistence layer (following
  parent-theme links, scanning for overrides and bindings). These
  queries should happen once upfront, not scattered across tier
  methods.
- The resolved state is immutable for the duration of composition.
  Storing it on the context makes all tier methods' access O(1).
- Eager resolution surfaces theme configuration errors (missing
  parents, broken chains) before composition begins, not partway
  through a page render.

### 2. Theme source priority

**Question:** When multiple theme sources are available (explicit
URI argument, explicit entity, publication's `ui-theme` slot), which
wins?

**Decision:** Priority order:
1. Explicit `:theme-uri` argument to `make-context`
2. Explicit `:theme` entity argument
3. `(classic.schema:ui-theme publication)` if set
4. NIL -- no theme active

This lets callers override the publication's default theme for
preview, testing, or per-request theme switching, while the common
case (use the publication's configured theme) requires no explicit
argument.

### 3. Tier template cascade: override -> tier-templates -> default

**Question:** When a theme provides both a `tier-templates` entry
and a `classic-theme-override` for the same tier, which wins?

**Decision:** The override wins. The cascade for each tier is:

1. Per-tier override (`classic-theme-override`) -- most specific
2. Theme's `tier-templates` alist entry -- general
3. Built-in default -- fallback

This matches the intent of the override system: overrides are
targeted modifications that should take precedence over the theme's
general template for that tier.

### 4. Capability activation set from theme

**Question:** Should the composer activate all registered
capabilities globally, or only those declared by the theme?

**Decision:** Theme's resolved capabilities are the activation set.
Only capabilities listed by the theme (after exclusion resolution)
participate in dispatch during this composition. Capabilities
registered globally but not listed by the theme remain in the
registry but are inactive.

This prevents a loaded capability extension from affecting
compositions that didn't opt into it. A theme author controls
exactly which capabilities are active for their theme.

### 5. Capability validation: warn by default, strict mode optional

**Question:** What happens when a theme declares a capability that
isn't registered, or requires one that isn't in the activation set?

**Decision:** Default behavior is to warn. Setting
`*strict-capabilities*` to T escalates to an error. This balances
developer experience (warnings during development help identify
missing extensions) with robustness (production systems can enable
strict mode to catch misconfiguration early).

### 6. Lens-driven feature composition with body fallback

**Question:** How should `compose-feature` choose between lens-driven
rendering and direct body extraction?

**Decision:** If the resolved theme provides a lens matching the
entity's class with `:default` purpose, use it. Otherwise fall back
to extracting the entity's body slot directly (the pre-theme
behavior).

This means:
- Themes with lenses get declarative, property-level control over
  entity rendering
- Themes without lenses (or compositions without themes) get the
  same behavior as before
- The fallback is the same code path that existed pre-theme-integration

### 7. Display mode cascade mirrors Fresnel, extended with MOP

**Question:** How should the display mode for a slot be determined
when the lens doesn't declare an explicit `:display`?

**Decision:** The cascade:

1. Explicit `:display` from the lens property spec
2. Slot's MOP `:format` annotation (`:markdown` -> `:markdown`,
   `:html` -> `:html`)
3. Slot's MOP `:persistence` is `:relation` and no sublens -> `:link`
4. `:text` universal fallback

Steps 2 and 3 use Classic's MOP slot annotations (`slot-format`,
`slot-persistence` exported by the foundation) to make intelligent
defaults without requiring lens authors to annotate every property.
A body slot with `:format :html` renders as pass-through Lexis
without the lens needing to say so.

### 8. Markdown display mode stubbed

**Question:** The `:markdown` display mode requires a Markdown
parser. Should the composer depend on a Markdown library?

**Decision:** Stub for now. `:markdown` wraps the string value in a
`(paragraph ...)` node. Adding a real parser (e.g., `3bmd` or
`cl-markdown`) is a future dependency that can be added without
changing the lens or display mode interface.

### 9. Silent skip for absent slots, warn for nonexistent slots

**Question:** What should lens evaluation do when a property
references a slot that is unbound or NIL on the entity?

**Decision:** Skip silently. This is the common case for optional
slots (an article without keywords, a person without an email). The
lens declares the maximum set of properties to display; the entity
determines which are actually present.

If the slot doesn't exist on the entity's class at all, that's a
lens authoring bug and warrants investigation, but the current
implementation skips it rather than erroring (robustness over
strictness for the prototype).

### 10. Asset collection with CSS stacking order

**Question:** When collecting assets from a theme chain, what order
should they appear in?

**Decision:** Parent assets first, child assets last. This produces
the correct CSS cascade: parent stylesheet establishes the visual
foundation, child stylesheet overrides specific rules. The same
ordering applies to scripts and other asset types.

### 11. Schema-agnostic via nickname pattern

**Question:** How should the composer reference schema symbols?

**Decision:** Follow the engine's convention. The composer's ASDF
system depends on `classic.schema.alpha` explicitly, but all source
code references use the `classic.schema:` nickname. A future
`classic.composer.dist.beta` would load the same composer source
against `classic.schema.beta`.

The composer package `:use`s `#:classic` for foundation symbols
(which become bare in the source) but does NOT `:use` the schema
package. All schema references are explicitly qualified as
`classic.schema:symbol-name`, keeping the schema dependency visible
at every call site.

### 12. Distribution shim for end users

**Question:** How should end users load the composer with a complete
Classic installation?

**Decision:** A thin `classic.composer.dist.alpha` meta-system that
depends on `classic.dist.alpha`, `classic.models.common`, and
`classic.composer`. Users load one system:

```lisp
(ql:quickload "classic.composer.dist.alpha")
```

This parallels Classic core's dist pattern. A future beta variant
would be `classic.composer.dist.beta`.


## Implementation

### New file: `src/theme.lisp` (~180 lines)

Theme resolution glue connecting Classic core's theme ontology to
the composer's pipeline.

- `resolve-theme-for-context` -- populates all resolved-theme slots
  on the context by calling the schema's resolution functions
  (chain, capabilities, overrides, bindings, slot-fills, lenses,
  assets). Called during `make-context`.
- `theme-tier-template` -- the three-level cascade (override ->
  tier-templates -> NIL) for selecting a tier's template.
- `apply-theme-config-to-context` -- binds scalar config entries
  into context with `theme.config.` prefix.
- `apply-theme-slot-fills-to-context` -- binds slot-fills directly
  by name, treating NIL fills as "no contribution" (slot removed
  during resolution).
- `validate-theme-capabilities` -- checks activation set against
  registry and required-capabilities against activation set. Warns
  by default; errors when `*strict-capabilities*` is T.
- `collect-theme-assets` -- walks chain root-to-child, building a
  flat list of asset plists with resolved URIs.
- `theme-asset-list` -- converts collected assets into Lexis subtree
  nodes (stylesheet, script) for template slot binding.

### New file: `src/lens.lisp` (~230 lines)

Fresnel-inspired lens evaluation.

- `compute-display-mode` -- the four-level cascade using MOP
  introspection (`slot-format`, `slot-persistence`).
- `find-slot-def` -- MOP helper to locate an effective slot
  definition on a class.
- `render-slot-via-display-mode` -- dispatcher to per-mode renderers.
- Eight per-mode renderer functions: `render-text`, `render-image`,
  `render-link`, `render-uri`, `render-html-passthrough`,
  `render-markdown-stub`, `render-date`, `render-list`.
- `apply-lens` -- walks a lens's property specs, rendering each
  slot according to its display mode, skipping unbound/NIL slots.
- `apply-sublens` -- handles relation slots: retrieves the related
  entity, finds the target lens in the resolved theme, recursively
  applies it. Fallback: target purpose -> `:label` purpose for
  actual class -> entity's `label` slot.
- `apply-sublens-single` -- single-entity version of sublens
  application, handling the fallback chain.

### Modified: `src/context.lisp`

Seven new slots on `composition-context` for resolved theme state:
`theme-chain`, `theme-capabilities`, `theme-overrides`,
`theme-config`, `theme-slot-fills`, `theme-lenses`, `theme-assets`.

`make-context` gains `:theme-uri` keyword argument and eager theme
resolution. Priority: explicit URI > explicit entity > publication's
`ui-theme` > NIL.

All `classic:label` references changed to `classic.schema:label`.

### Modified: `src/defaults.lisp`

`compose-page` now runs theme validation, config binding, slot-fill
binding, and asset binding before tier composition. Pipeline steps
increased from 8 to 11.

`compose-frame` uses the tier template cascade: theme override ->
tier-templates -> hardcoded default.

`compose-feature` attempts lens-driven composition first (via
`apply-lens` with the entity's class and `:default` purpose), falling
back to direct body extraction when no lens is found.

`compose-adjunct` and `compose-aggregate` check for theme tier
templates before returning NIL.

All schema references qualified as `classic.schema:`.

### Modified: `src/packages.lisp`

Package now `:use`s `#:classic` for foundation symbol inheritance.
Added ~25 new exports across theme integration and lens evaluation
sections. Removed the stub `template` and `compose` packages
(replaced by dotted symbols in earlier work).

### Modified: `classic.composer.asd`

Dependencies updated from `("classic")` to `("classic"
"classic.schema.alpha" "closer-mop")`. Components gain `theme` and
`lens` files. Version bumped to 0.2.0.

### New file: `classic.composer.dist.alpha.asd`

Thin meta-system: depends on `classic.dist.alpha`,
`classic.models.common`, and `classic.composer`.

### Modified: `src/anchor.lisp`

Single reference: `classic:keywords` -> `classic.schema:keywords`.

### Modified: `README.md`

Updated demo to load `classic.composer.dist.alpha` and use
`classic.models.common:` references. Added sections on theme
integration, lens-driven feature composition, and the layered
architecture. Updated system structure and dependency listings.

### Modified: `doc/Composer.md`

Rewritten to reflect the full architecture: four-layer dependency
structure, theme resolution workflow, tier template cascade,
slot-fills, capability activation, lens-driven composition with
display mode cascade and sublens references, and the updated
composition pipeline.


## Design Properties Preserved

The theme integration maintains the composer's core performance
guarantees:

- **O(n) pipeline.** Theme resolution is upfront (one call during
  `make-context`), not per-node. The composition pipeline remains a
  fixed number of sequential O(n) passes over the tree.
- **No recursion between stages.** Theme data is resolved once and
  stored immutably on the context. Tier methods read it; nothing
  triggers re-resolution.
- **Single-pass slot resolution.** Theme slot-fills are bound into
  the context before slot resolution runs. The resolution pass sees
  them as normal bindings.
- **Lens evaluation is bounded.** Each property in a lens is
  processed once. Sublens recursion follows entity relationships and
  is bounded by the depth of the relationship graph, not by tree
  structure.


## Files

| Action | File | Description |
|---|---|---|
| Created | `src/theme.lisp` | Theme resolution glue (~180 lines) |
| Created | `src/lens.lisp` | Lens evaluation, display modes, sublens (~230 lines) |
| Created | `classic.composer.dist.alpha.asd` | Distribution shim |
| Modified | `classic.composer.asd` | Dependencies, components, version |
| Modified | `src/packages.lisp` | Foundation `:use`, ~25 new exports |
| Modified | `src/context.lisp` | 7 theme slots, eager resolution, schema qualification |
| Modified | `src/defaults.lisp` | Theme-aware pipeline, lens-driven feature, tier cascade |
| Modified | `src/anchor.lisp` | Schema qualification (1 reference) |
| Modified | `README.md` | Updated demo, theme/lens docs, architecture |
| Modified | `doc/Composer.md` | Full rewrite for layered architecture |
| Created | this file | |


## Metrics

- New source files: 2 (theme.lisp, lens.lisp)
- New ASDF system: 1 (classic.composer.dist.alpha)
- Total composer source lines: ~1765
- Schema references migrated: ~15 (classic: -> classic.schema:)
- New exports: ~25


## Outstanding Work

- **Tests.** No test suite exists for the composer yet. Priority
  areas: template slot resolution, anchor dispatch, lens evaluation
  (display mode cascade, sublens fallback), theme tier template
  cascade, capability validation. A `classic.composer/tests` ASDF
  system following Classic core's `fiveam` + `hamcrest` pattern is
  the natural next step.

- **Markdown display mode.** Currently stubbed (wraps in paragraph).
  Adding a real Markdown parser dependency would make `:markdown`
  functional.

- **Capability dispatch integration.** The capability registry exists
  and capabilities can be defined and registered, but the composition
  pipeline does not yet dispatch to capabilities during tree
  traversal. This requires connecting `dispatch-capability` calls
  at the appropriate points in the tier methods.

- **Cross-reference resolution.** The Lexis spec (Section 7.3)
  describes a resolution pass for `cross-ref` and `classic-link`
  nodes. This pass is not yet implemented in the composer.

- **Asset surface in HTML renderer.** The `theme.assets` slot
  binding produces Lexis `(stylesheet ...)` and `(script ...)` nodes,
  but the Lexis HTML renderer does not yet have methods for these
  tags. Either Lexis gains these methods or the composer produces
  raw HTML-equivalent nodes.
