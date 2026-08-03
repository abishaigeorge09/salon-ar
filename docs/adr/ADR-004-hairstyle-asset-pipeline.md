# ADR-004 — Where the hairstyle assets come from

- **Status:** Accepted
- **Date:** 2026-08-04
- **Serves:** R-STYLES

## Context and problem statement

This is a content pipeline problem as much as a rendering one. Who makes them, in what format,
how many for v1, and what it costs to add the hundredth one.

The last question is the one that decides the architecture. A pipeline where the hundredth
style costs the same as the first is a product. A pipeline where it costs hours of hand work is
a business that cannot grow its catalogue, which in this category is the whole moat.

## The constraint that decides it

**Founder, stated: no artist, no budget. The pipeline must be one I can run.**

That single fact eliminates the entire high-realism branch and makes the decision short.

## Considered options

| Option | Verdict |
|---|---|
| Strand-based grooms | Rejected. Needs a groom artist we do not have and a frame budget we cannot spare on a phone. |
| Hand-placed hair cards | Rejected on the hundredth-style test. Hours per style, forever. |
| Licensed asset pack | Rejected for v1. Typically game-styled rather than photoreal, and commercial AR licensing needs checking we cannot fund. Reconsider if a partner appears. |
| **Parameterised hair cards** | **Chosen.** |

## Decision outcome

**Hair cards — textured alpha planes laid over one shared skull-cap base mesh — placed by a
scripted, parameterised layout driven by one config row per style.**

### The pipeline

1. **One shared base cap.** A single skull-cap mesh, the same one for every style, aligned to
   the ADR-003 head proxy so occlusion and hair share a coordinate frame by construction.
2. **Texture sheets, generated.** Hair texture sheets with alpha, produced generatively rather
   than painted. This is the step that no longer needs an artist.
3. **Parameterised card layout.** A script places cards over the base cap from a config row:
   length, volume, part, curl, layering, fringe. **No hand placement anywhere in the pipeline.**
4. **Export to USDZ** for RealityKit, under a per-style size budget.

### v1 catalogue

**8–12 styles, all additive**, because additive is what live mode can honestly render
(ADR-001). Curated rather than comprehensive: the brief's non-goal is explicit that this is not
a catalogue, and eight good styles beat forty half-broken ones in a conversation that lasts four
minutes.

Freeze mode's short styles are drawn from the same config, since a bob is a length parameter,
not a different kind of asset.

### The hundredth style

**One config row and one texture sheet.** No code change, no mesh work, no artist.

This is the property the whole ADR exists to buy, so it is asserted by the build rather than
claimed in a document: the style count is derived from the config, and a test asserts they
match. If someone adds a style by hand-editing a mesh, the build tells us the pipeline has
failed before the debt compounds.

## Consequences

- **Good:** catalogue growth is a data problem, not an engineering or hiring one.
- **Good:** shared base cap means a fix to occlusion fits every style at once.
- **Bad:** cards have a realism ceiling below strand grooms. Notably on high-motion silhouettes,
  fine flyaways, and any style that needs strands to separate. Accepted knowingly, and
  substantially mitigated by the ADR-003 degradation step, which narrows the gap between a card
  render and a camera frame more than extra geometry would.
- **Bad:** parameterisation constrains expressible styles to what the parameter space covers.
  Styles outside it are not "hard", they are impossible without extending the space. That is the
  price of the hundredth style being free.
- **Risk:** generated texture sheets must be checked for provenance and commercial usability
  before ship. Carried in `docs/DEBT.md`.

## Confirmation

| Check | Command | Asserts |
|---|---|---|
| Styles build from config | `scripts/build-styles.sh` | Every style builds from its config row, produces a valid USDZ, and lands under the size budget. |
| The hundredth style is free | `scripts/verify-style-parity.sh` | `styles built == config rows`, and no style asset exists that is not derived from a config row. Hand-placed assets fail the build. |
| No hand-authored meshes | `scripts/verify-no-orphan-assets.sh` | No USDZ or mesh file in the asset tree lacks a generating config entry. |
| Shared frame holds | `xcodebuild test -only-testing:ARTests/StyleAlignmentTests` | Every style aligns to the ADR-003 head proxy origin within tolerance, so occlusion correctness proven for one style holds for all of them. |
