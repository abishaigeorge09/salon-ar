# Week-one prototype: is salon-acceptable realism achievable at all?

**This is the only risk that can make every other decision worthless.** A style that looks
pasted on is worth nothing. Architecture, device matrix, asset pipeline and biometric posture
are all correct and all irrelevant if the render does not read as hair.

So week one buys one answer, before anyone has built a product to find it out in.

## The question

> Can a hairstyle be composited onto a real customer, in real salon light, at a quality a
> paying salon would show to a paying customer?

Not "can we build it in real time". That comes second and it is engineering. This is the prior
question, and it is the one that can kill the product.

## The test: an offline composite, not a build

**The cheapest test of realism is not code.** Give the problem every advantage it will never
have in production — no frame budget, no real-time constraint, no tracking, no device limits,
unlimited time per image — and see whether the result is good enough even then.

The logic runs one way only, and that is exactly what makes it cheap:

- **If the unconstrained offline result does not look like a haircut, the real-time version
  certainly will not.** The product is dead for the price of one day rather than one quarter.
- **If it does look good**, the remaining question is only how much survives the frame budget.
  That is engineering with a known shape, not research.

There is no version of this where the offline result fails and the on-device result succeeds.
That asymmetry is the whole design of the test.

### Procedure

1. **Capture in the salon, on the real iPhone (`AG`), under the salon's real lighting.** Not at
   a desk, not by a window. Directional warm salon light is a named failure mode in ADR-001 and
   testing without it tests nothing.
2. Twenty subjects. Stills plus a short clip each, the clip because a still hides temporal
   artefacts that a moving head exposes.
3. Produce the **best hairstyle composite achievable by any means** for each. Any tool, any
   amount of time. This is deliberately not the production pipeline.
4. Present each result beside a real photograph of a real person with that cut.

### The 20 must include the known failure modes

A test set that avoids the hard cases is a test set designed to pass. Mandatory inclusions,
from ADR-001:

- **Dark hair against a dark salon wall.** Segmentation has no edge to find.
- **Tightly coiled and textured hair.** Flagged repeatedly in the literature as where every
  shipped hair model breaks, and the population most often failed by this category.
- **Very long hair, asked to see a bob.** The single most common salon request and the one live
  mode cannot answer. This is the freeze-mode test.
- At least one subject with a **high or receding hairline**, where the added style's root cards
  have the least to hide behind.
- At least one **profile-ish angle**, to expose ear occlusion (ADR-003).

If any of these are missing from the 20, the test has not run.

## The bar is set by someone who is not us

Put the best composite next to the real photograph and ask the salon partner one question:

> **Would you show this to a paying customer?**

That is the quality bar. It is acquired for the cost of a conversation and it is worth more
than any metric we would invent, because they are the ones who lose the customer.

**The threshold is pre-registered.** `Q-BAR` in `docs/BRIEF.md` is filled in by the salon
partner **before they see any result**, and it is blank until then, deliberately. A bar set
after seeing the output is not a bar, it is a rationalisation, and it will be a generous one
because by then we will be attached to the work.

## Second question, same visit, free

While the salon partner is there, answer the Open item that decides whether ADR-001 keeps freeze
mode: **show a stylist a 3-second pause mid-consult and ask whether it reads as the machine
working or the machine failing.** Costs nothing extra, and it either saves or spends four to six
weeks.

## Exit

Three outcomes. All three are acceptable in week one. Only discovering them in month three is not.

| Outcome | Meaning | What happens |
|---|---|---|
| **GO** | Composites meet Q-BAR, including the hard subsets | Build proceeds per plan, live mode then freeze mode |
| **GO-ADDITIVE-ONLY** | Additive composites pass, removal composites fail, **or** stylists reject the freeze pause | ADR-001 falls back to option (a) **knowingly**, which is the outcome the founder said they would accept. Freeze mode is cut, not deferred. |
| **NO-GO** | Even unconstrained offline results do not read as hair on real customers in real light | Stop. Report why, with the images. One day spent instead of one quarter. |

Scored per subset, not as an average. A good mean that hides total failure on textured hair is
not a pass — it is a product that works for some customers and insults others.

## What this test explicitly does not tell us

Stated so nobody over-reads a GO:

- Nothing about frame rate, tracking stability, or thermal behaviour on a salon iPad running
  all day.
- Nothing about whether the parameterised card pipeline (ADR-004) can reach the quality the
  offline composite reached by other means. **This is the most important gap.** A GO says the
  quality ceiling is high enough; it does not say our pipeline reaches it. That is the first
  thing phase one must prove, and it is the second-largest risk in the project.
- Nothing about occlusion correctness, which needs the real render path.
