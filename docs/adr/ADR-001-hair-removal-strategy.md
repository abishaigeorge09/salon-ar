# ADR-001 — Hair removal strategy

- **Status:** Accepted
- **Date:** 2026-08-04
- **Deciders:** Founder (decision), architecture (options and costing)
- **Serves:** R-LIVE, R-SHORTER, R-HONEST

## Context and problem statement

An overlay can add hair. It cannot remove it. A customer with long hair asking to see a bob or
a buzz cut is the most common thing a salon is asked, and a 3D mesh anchored to a head fails it
completely, because their real hair is still in frame.

Solving it needs hair segmentation and inpainting, which is a different and much harder
problem. This ADR exists specifically so that it is not discovered during build.

## Decision drivers

- The most common salon request is going **shorter**. A product that cannot answer it is a toy.
- A bad result rendered on someone's face is worse than no result. The quality bar is set by a
  paying customer's feelings, not by a metric.
- Nothing may leave the device (ADR-005), so every option is bounded by on-device compute.
- The founder's stated preference: *"I would rather ship (a) knowing its limit than ship (b)
  badly."*

## Research that constrains the options

Established before any option was preferred:

1. **Mobile hair segmentation is solved.** Published work reports 30–100fps on mobile GPUs at
   roughly 0.89 IoU. This is engineering, with libraries and prior art.
2. **Real-time high-resolution inpainting on edge devices is not solved.** The 2025 edge
   inpainting literature states plainly that essentially no work exists for real-time
   high-resolution image inpainting on edge devices, and that few works treat inference latency
   as a constraint at all.
3. **No shipping product does removal.** Across ModiFace, L'Oréal Style My Hair, Perfect Corp
   YouCam, Banuba's SDK and the consumer AI-hairstyle apps, the documented ceiling is
   segmentation plus edge-refined overlay. Style My Hair — stylist-operated on a seated client,
   the closest precedent that exists to this product — avoids the problem entirely by doing
   **colour only, never silhouette**.
4. **Identity drift is the failure mode users hate most.** The recurring review complaint about
   generative hairstyle apps is not "it looks pasted on", it is *"it turns me into a whole new
   person"*. Users notice a changed face far more bitterly than a visible seam, and the
   complaint is specific to generative pipelines that regenerate pixels across the whole image.

Finding 2 removes option (b) as originally framed. Finding 4 constrains the option chosen.

## Considered options

### (a) Additive only for v1

Ship styles that add length or volume and be honest about the limit.

- **Cost:** 6–8 weeks.
- **Fails at:** the most common question a salon is asked. Every short cut, every bob, every
  buzz, every undercut. Possibly useless for the actual use case.

### (b) Segment and inpaint, live

Real-time removal and replacement in the live feed.

- **Cost:** 4–6 months, with a material chance of never reaching the quality bar.
- **Fails at:** existing as engineering. Per finding 2 this is a research programme with a
  schedule attached to it. Rejected.

### (c) Two-mode hybrid — **chosen**

Live mode is additive and honest. A separate freeze mode does removal on a single frame.

## Decision outcome

**Chosen: (c), the two-mode hybrid.**

### Live mode

ARKit face-anchored additive hair at 30–60fps. The customer's real hair remains in frame, and
the UI says so in plain language (R-HONEST) rather than hoping nobody notices. Serves: added
length, added volume, fringe, layers, styling.

### Freeze mode

One button. Captures a single high-resolution frame, spends 2–4 seconds, and does what live
cannot: segments the real hair, removes it, composites the target style. Serves bob, buzz,
undercut, crop — precisely the requests live mode structurally cannot answer.

The salon setting is what makes the pause acceptable. Two people are already looking at one
screen together and talking; a short pause reads as the machine working, not as the machine
failing. This assumption is listed as Open in the brief and is tested at the salon visit. **If
stylists report it reads as broken, freeze mode is cut and the product falls back to option (a)
knowingly**, which is the outcome the founder said they would accept.

### The constraint that finding 4 forces

**Freeze mode must not be a face-regenerating model.** Identity drift is a worse product
failure than a visible seam, because a seam is a quality complaint and a changed face is an
insult, delivered to someone sitting in a chair paying to be made to feel good.

Therefore the generative pass is **masked-region-only**. Pixels outside the dilated
hair-and-adjacent-background mask are carried through **byte-identical** from the source frame.
The customer's face is not "preserved well", it is not touched.

This is also why the whole product stays overlay-based rather than generative: an overlay
architecture structurally *cannot* alter the customer's face, because the face is the live
camera feed. That property is worth protecting.

## Consequences

### What this fails at, stated now rather than discovered later

- **Anything behind the head.** A front camera has never seen the back of anyone. No style can
  be shown from behind, and the UI must not imply otherwise.
- **Dark hair against a dark salon wall.** Segmentation needs an edge to find. This is a real
  salon condition, not a corner case.
- **Tightly coiled and textured hair.** Flagged repeatedly in the literature as the weak point
  of every shipped hair model. Deliberately included in the week-one test set rather than
  avoided.
- **Salon lighting.** Directional, warm, and nothing like the diffuse light these models are
  trained under. This is the single reason the realism test happens in a real salon and not at
  a desk.

### Good

- Option (a) is the first milestone rather than a retreat, so the fallback is already built.
- Segmentation is built once and used twice: freeze mode needs it, and ADR-003 reuses the
  low-resolution mask as a live occlusion hint.
- It is the only known product that attempts removal at all, which is white space rather than
  catch-up.

### Bad

- Two rendering paths, two quality bars, two sets of failure modes.
- Freeze mode's 4–6 weeks buy a feature that may be rejected by stylists on ergonomics alone.

## Confirmation

Runnable. Collected into `dod.sh` and executed at every subsequent gate.

| Check | Command | Asserts |
|---|---|---|
| Identity preservation | `scripts/verify-identity-preservation.sh` | Over a fixed corpus of freeze-mode frames, output outside the dilated hair mask is **bit-identical** to input. Not "similar". A single changed pixel on a cheek fails the build. |
| Segmentation quality | `scripts/verify-segmentation-iou.sh` | Mean IoU over a held-out set is at or above the recorded threshold, including the textured-hair and dark-on-dark subsets scored separately so a good average cannot hide a broken subset. |
| Live frame budget | `xcodebuild test -only-testing:ARTests/LiveFrameBudgetTests -destination 'platform=iOS,name=AG'` | On-device p95 frame time within budget. Device only; the simulator has no face tracking and a green simulator run here is worse than no run. |
| Honesty | `scripts/verify-honesty-copy.sh` | The live-mode limitation string is present and reachable in the built UI, so R-HONEST cannot be quietly dropped in a redesign. |
