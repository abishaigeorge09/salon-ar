# ADR-006 — The mirror version, and not foreclosing it

- **Status:** Accepted (nothing is built)
- **Date:** 2026-08-04

## Context and problem statement

Founder, stated: *"Later, not now: the same thing rendered into the salon mirror itself. Do not
build for that yet, but do not make a decision that forecloses it either. Note in the ADR where
the mirror version would diverge."*

This ADR builds nothing. It records the divergence point and installs the one cheap indirection
that keeps a port from becoming a rewrite.

## Where the mirror version diverges

Exactly one place: **the render viewpoint stops being the camera.**

In the handheld product, the front camera sits roughly where the customer is looking, so the
camera's viewpoint and the viewer's viewpoint are close enough to be treated as the same thing.
A salon mirror breaks that. The camera is mounted somewhere on or near the mirror; the viewer's
eyes are somewhere else entirely, and moving. The two are no longer interchangeable, and every
render that assumed they were is wrong by a parallax error that grows with distance.

What that specifically requires, none of which is needed now:

1. **Re-projection** of head pose from camera space into the mirror's virtual viewpoint.
2. **Viewer eye tracking**, because the correct viewpoint is where the customer's eyes are, and
   they move independently of their head.
3. **Per-installation display calibration** — the geometric relationship between camera, mirror
   plane, display, and chair, measured once per salon.
4. **A different consent posture.** An always-on display in a salon sees people who never sat
   down. ADR-005 flags this; it gets its own ADR.

Everything else carries over intact: face tracking (ADR-002), occlusion and the head proxy
(ADR-003), the asset pipeline (ADR-004), segmentation and freeze mode (ADR-001).

## The decision that would foreclose it

**Hard-coding "the camera is the viewpoint" through the render path.** It is the natural thing
to write, because in the handheld product it is true, and it is true implicitly in a dozen
places rather than explicitly in one.

## Decision outcome

A **`ViewpointProvider`** sits between the face anchor and the render camera from day one. The
render path asks it for the viewpoint transform and never reads the AR camera transform
directly.

In the handheld product it returns the camera transform, which is to say it does nothing at all.
That is the point: it is a few lines and one indirection now, and it is the difference between a
port and a rewrite later.

**Nothing else is built for the mirror.** No calibration UI, no eye tracking, no configuration
surface, no abstraction beyond this one. Speculative generality is its own cost, and the
instruction was to not foreclose it, not to prepare for it.

## Consequences

- **Good:** the expensive-to-reverse decision is neutralised for near-zero cost.
- **Good:** the divergence is documented while it is understood, rather than rediscovered by
  whoever picks up the mirror version.
- **Bad:** one indirection in the hot render path. Negligible, and it is a transform lookup.
- **Bad:** a single seam is not a guarantee. Other camera-is-viewpoint assumptions can still
  creep in elsewhere, which is why the Confirmation below tests the property rather than trusting
  the seam to be respected.

## Confirmation

| Check | Command | Asserts |
|---|---|---|
| Off-axis viewpoint works | `xcodebuild test -only-testing:ARTests/ViewpointProviderTests` | Substituting a synthetic **off-axis** `ViewpointProvider` produces a correctly re-projected frame with no change to tracking, occlusion, or assets. This is the actual test of "not foreclosed": if an off-axis viewpoint renders correctly today, the mirror is a port. |
| No direct camera reads | `scripts/verify-viewpoint-indirection.sh` | No code in the render path reads the AR camera transform directly, bypassing `ViewpointProvider`. Fails the build on a new direct reference, which is how the seam stays intact rather than eroding one commit at a time. |
