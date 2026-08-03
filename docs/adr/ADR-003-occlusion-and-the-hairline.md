# ADR-003 — Occlusion and the hairline

- **Status:** Accepted
- **Date:** 2026-08-04
- **Serves:** R-LIVE

## Context and problem statement

Hair that floats in front of an ear, or cuts across a forehead, reads as broken instantly. It
is the fastest way to lose a customer's trust in the render, and no amount of texture quality
recovers from it. This ADR decides how head geometry is used to occlude correctly.

## The specific difficulty

ARKit's `ARFaceGeometry` is 1220 vertices of **face**. It is not a head. It does not model the
skull above the hairline, and it does not model ears usefully. So the geometry ARKit hands us
is exactly the geometry that cannot, on its own, decide whether a lock of hair is in front of
an ear or behind it.

Separately, the **hairline** is not a geometric feature. It is a soft, per-person, irregular
transition that no fitted mesh will ever match. Chasing it geometrically is a trap.

## Decision outcome

Three mechanisms, each solving a different part.

### 1. Head proxy, depth-only

A **skull-and-ear cap** proxy mesh, rigidly parented to the ARKit face anchor and scaled from
inter-landmark distances (inter-pupillary distance, face width, chin-to-brow). It is rendered
**depth-only, colour write off**: it draws nothing visible and occludes everything behind it.

This is what stops hair appearing through a head, and it is why the proxy must include ears —
the ear is where the failure is most visible and where ARKit's own geometry is least useful.

On TrueDepth devices, the depth map refines the proxy fit. On A12 non-TrueDepth devices the fit
comes from landmarks alone and is slightly looser, which is an accepted difference rather than a
separate code path.

### 2. Hairline by feathering, not by geometry

The style's own **root cards** feather over the boundary with an alpha ramp, so there is no hard
edge to misplace. We do not attempt to locate the customer's true hairline in live mode.

### 3. Segmentation mask as a soft occlusion hint

The hair segmentation model already required by ADR-001 runs at low resolution in live mode and
its mask is used as a soft occlusion term. One model, two jobs: freeze mode needs it at full
resolution, live mode gets a cheap hint from the same weights.

This is the mechanism that keeps the customer's own flyaway strands reading as being *in front
of* the added style where they should be, which is what separates a composite from a hat.

### 4. Deliberate degradation of the synthetic layer

Borrowed from Apple's own AR Quick Look, which does this on purpose: **sample ambient light for
colour and intensity, then add matching grain, motion blur and depth of field to the render.**

A perfectly clean, perfectly sharp render against a noisy, slightly motion-blurred camera feed
is *precisely* what "pasted on" looks like. The synthetic layer must be made worse to look real.
This is cheap, it is a shader change rather than a research problem, and it is likely the single
highest-leverage realism technique available to us.

## Considered and rejected

- **ARKit people occlusion.** Segments people from background. Useless here: the hair and the
  head are both "person", so it draws no line where we need one.
- **Depth-map-only occlusion.** Excludes every non-TrueDepth A12 device, contradicting ADR-002,
  and TrueDepth depth is too coarse at hair-strand scale regardless.
- **Locating the true hairline geometrically.** Rejected. Per-person, soft, irregular. Any mesh
  fit to it is wrong for most faces, and wrong at the most visible point on the render.

## Consequences

- **Good:** occlusion correctness does not depend on TrueDepth, so it holds across the whole
  ADR-002 matrix.
- **Good:** the segmentation model earns its cost twice.
- **Bad:** the proxy is an approximation. Unusual head shapes, and anyone whose ears sit outside
  the fitted range, will show artefacts. Accepted for v1, and the yaw-sweep test below is what
  keeps it from getting quietly worse.
- **Bad:** deliberate degradation is subjective and needs a human eye at every gate. It cannot
  be fully automated, which is why `ux-critic` walks the real render rather than trusting the
  pixel tests.

## Confirmation

| Check | Command | Asserts |
|---|---|---|
| Occlusion at angle | `xcodebuild test -only-testing:ARTests/OcclusionSweepTests -destination 'platform=iOS,name=AG'` | Renders a known head across a yaw and pitch sweep, captures each frame, and asserts **zero hair-coloured pixels inside the face-mesh silhouette and inside the ear regions**. Fails the build on regression rather than being noticed by a customer. |
| No visual regression | `scripts/verify-render-baselines.sh` | Sweep frames diffed against approved baselines above a perceptual threshold. |
| Proxy fit range | `xcodebuild test -only-testing:ARTests/HeadProxyFitTests` | Proxy scaling stays within bounds across a landmark corpus spanning head sizes, so an extreme face cannot silently produce a proxy that occludes the face itself. |
| Degradation is applied | `scripts/verify-camera-match.sh` | Rendered layer's grain and blur parameters are non-zero and tracked to the measured camera values, so the "make it worse" step cannot be optimised away by someone tidying the shader. |
